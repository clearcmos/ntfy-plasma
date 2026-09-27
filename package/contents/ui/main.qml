pragma ComponentBehavior: Bound

import QtQuick
import org.kde.plasma.core as PlasmaCore
import org.kde.plasma.plasmoid
import org.kde.kirigami as Kirigami
import "Feed.js" as Feed

PlasmoidItem {
    id: root

    property var messages: []
    property int unreadCount: 0
    property bool connected: false
    // Only messages published after the widget loaded pop the overlay, so a
    // plasmashell restart does not replay the whole backfill on screen.
    readonly property double startedSec: Date.now() / 1000

    // One clock for every timestamp label, so labels roll over to
    // "Yesterday" and beyond while they sit on screen.
    property double nowMs: Date.now()

    Timer {
        interval: 60000
        running: true
        repeat: true
        onTriggered: root.nowMs = Date.now()
    }

    readonly property url iconSource: Qt.resolvedUrl("../icons/ntfy-tower.svg")

    // Same test the client uses, so a topics field of only commas does not
    // read as configured while the client refuses to connect.
    readonly property bool isConfigured: Feed.streamUrl(Plasmoid.configuration.serverUrl, Plasmoid.configuration.topics, "") !== ""

    function openConfig() {
        Plasmoid.internalAction("configure").trigger();
    }

    readonly property string topicSummary: {
        const t = Feed.parseTopics(Plasmoid.configuration.topics);
        if (t.length === 0)
            return i18n("(no topics)");
        if (t.length === 1)
            return t[0];
        return i18np("%1 topic", "%1 topics", t.length);
    }

    Plasmoid.icon: iconSource
    Plasmoid.title: i18n("ntfy Feed")

    toolTipMainText: i18n("ntfy Feed")
    toolTipSubText: {
        if (!isConfigured)
            return i18n("Click to set server and topics");
        if (!connected)
            return i18n("Disconnected from %1", topicSummary);
        if (unreadCount > 0)
            return i18np("%1 unread on %2", "%1 unread on %2", unreadCount, topicSummary);
        return i18n("Connected to %1", topicSummary);
    }

    preferredRepresentation: compactRepresentation

    property double _lastReconnectMs: 0

    function reconnect() {
        // Throttle manual reconnects. Each call aborts and reopens the
        // streaming XHR; faster than the abort actually closes server-side
        // makes ntfy see leaked subscribers and may trip its visitor limit.
        const now = Date.now();
        if (now - _lastReconnectMs < 2000)
            return;
        _lastReconnectMs = now;
        client.restart();
    }

    function clearMessages() {
        messages = [];
        unreadCount = 0;
    }

    function dismissMessage(id) {
        root.messages = root.messages.filter(function (m) {
            return m.id !== id;
        });
    }

    function markAllRead() {
        unreadCount = 0;
    }

    NtfyClient {
        id: client
        serverUrl: Plasmoid.configuration.serverUrl
        topics: Plasmoid.configuration.topics
        historySince: Plasmoid.configuration.historySince

        onMessageReceived: function (msg) {
            const next = Feed.appendMessage(root.messages, msg, Plasmoid.configuration.maxMessages || 100);
            // null: a backfill replay of a message already shown
            if (next === null)
                return;
            root.messages = next;
            if (!panel.shown)
                root.unreadCount += 1;
            if (msg.time && msg.time >= root.startedSec) {
                overlay.push(msg);
                edgeFlash.trigger();
            }
        }

        onOpenChanged: function (isOpen) {
            root.connected = isOpen;
        }
    }

    OverlayPopup {
        id: overlay
        nowMs: root.nowMs
        screenRect: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 1920, 1080)
        onCardCountChanged: if (cardCount === 0)
            edgeFlash.stop()
    }

    EdgeFlash {
        id: edgeFlash
        screenRect: overlay.screenRect
    }

    // The popup is a Basalt panel of its own, so Plasma's themed applet
    // popup never opens.
    FeedPanel {
        id: panel
        messages: root.messages
        connected: root.connected
        configured: root.isConfigured
        topicSummary: root.topicSummary
        showDividers: Plasmoid.configuration.showDividers
        renderMarkdown: Plasmoid.configuration.renderMarkdown
        nowMs: root.nowMs
        edge: Plasmoid.location
        screenRect: overlay.screenRect
        onShownChanged: if (shown)
            root.markAllRead()
        onReconnectRequested: root.reconnect()
        onClearRequested: root.clearMessages()
        onDismissRequested: function (id) {
            root.dismissMessage(id);
        }
        onConfigureRequested: root.openConfig()
    }

    Plasmoid.contextualActions: [
        PlasmaCore.Action {
            text: i18n("Reconnect")
            icon.name: "view-refresh"
            onTriggered: root.reconnect()
        },
        PlasmaCore.Action {
            text: i18n("Clear Feed")
            icon.name: "edit-clear-all"
            enabled: root.messages.length > 0
            onTriggered: root.clearMessages()
        }
    ]

    // Plasma creates no compact icon for a widget without a full
    // representation, so it gets an empty one that is never shown: anything
    // that expands the widget (its global shortcut, a system tray click)
    // opens the Basalt panel instead.
    fullRepresentation: Item {}
    onExpandedChanged: if (expanded) {
        expanded = false;
        panel.toggle();
    }

    Component.onCompleted: if (isConfigured)
        client.start()

    Connections {
        target: Plasmoid.configuration
        function onServerUrlChanged() {
            if (root.isConfigured)
                client.restart();
            else
                client.stop();
        }
        function onTopicsChanged() {
            // Topic set changed: prior messages reference old topics. Drop
            // them so the user isn't confused by stale entries.
            root.messages = [];
            root.unreadCount = 0;
            if (root.isConfigured)
                client.restart();
            else
                client.stop();
        }
        function onHistorySinceChanged() {
            if (root.isConfigured)
                client.restart();
        }
    }

    compactRepresentation: MouseArea {
        id: compact
        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: Kirigami.Units.iconSizes.medium

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: function (mouse) {
            if (mouse.button === Qt.MiddleButton) {
                root.markAllRead();
            } else {
                panel.toggle();
            }
        }

        Component.onCompleted: panel.anchorItem = compact

        Kirigami.Icon {
            anchors.fill: parent
            source: root.iconSource
            isMask: true
            color: Kirigami.Theme.textColor
            active: parent.containsMouse
            opacity: root.connected ? 1.0 : 0.55
        }

        Rectangle {
            visible: root.unreadCount > 0
            anchors.right: parent.right
            anchors.bottom: parent.bottom
            anchors.rightMargin: -2
            anchors.bottomMargin: -2
            implicitWidth: Math.max(badgeText.implicitWidth + 6, height)
            implicitHeight: Math.max(Kirigami.Units.iconSizes.small * 0.7, 14)
            radius: height / 2
            color: "#5c9ae6"
            border.color: Kirigami.Theme.backgroundColor
            border.width: 1

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.unreadCount > 99 ? "99+" : String(root.unreadCount)
                color: "#1f1f23"
                font.pointSize: Kirigami.Theme.smallFont.pointSize - 1
                font.bold: true
            }
        }

        // Status dot in the corner while not configured or disconnected.
        // Hidden when fully connected so the icon is uncluttered.
        Rectangle {
            visible: !root.isConfigured || !root.connected
            anchors.right: parent.right
            anchors.top: parent.top
            anchors.rightMargin: -1
            anchors.topMargin: -1
            implicitWidth: 8
            implicitHeight: 8
            radius: 4
            color: Kirigami.Theme.neutralTextColor
            border.color: Kirigami.Theme.backgroundColor
            border.width: 1
        }
    }
}
