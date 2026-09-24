pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.components as PlasmaComponents
import org.kde.plasma.extras as PlasmaExtras
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
            if (!root.expanded)
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
        screenRect: Plasmoid.containment ? Plasmoid.containment.screenGeometry : Qt.rect(0, 0, 1920, 1080)
        onCardCountChanged: if (cardCount === 0)
            edgeFlash.stop()
    }

    EdgeFlash {
        id: edgeFlash
        screenRect: overlay.screenRect
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
        implicitWidth: Kirigami.Units.iconSizes.medium
        implicitHeight: Kirigami.Units.iconSizes.medium

        hoverEnabled: true
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: function (mouse) {
            if (mouse.button === Qt.MiddleButton) {
                root.markAllRead();
            } else {
                root.expanded = !root.expanded;
                if (root.expanded)
                    root.markAllRead();
            }
        }

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
            color: Kirigami.Theme.negativeTextColor
            border.color: Kirigami.Theme.backgroundColor
            border.width: 1

            Text {
                id: badgeText
                anchors.centerIn: parent
                text: root.unreadCount > 99 ? "99+" : String(root.unreadCount)
                color: "white"
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

    fullRepresentation: ColumnLayout {
        Layout.preferredWidth: Kirigami.Units.gridUnit * 24
        Layout.preferredHeight: Kirigami.Units.gridUnit * 22
        Layout.minimumWidth: Kirigami.Units.gridUnit * 18
        Layout.minimumHeight: Kirigami.Units.gridUnit * 14

        spacing: Kirigami.Units.smallSpacing

        RowLayout {
            Layout.fillWidth: true
            Layout.margins: Kirigami.Units.smallSpacing
            spacing: Kirigami.Units.smallSpacing

            PlasmaExtras.Heading {
                level: 4
                text: i18n("ntfy")
            }

            Rectangle {
                visible: !root.connected
                implicitWidth: 8
                implicitHeight: 8
                radius: 4
                color: Kirigami.Theme.neutralTextColor
            }

            PlasmaComponents.Label {
                text: root.connected ? i18n("%1 messages", root.messages.length) : i18n("disconnected")
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: Kirigami.Theme.smallFont.pointSize
            }

            Item {
                Layout.fillWidth: true
            }

            PlasmaComponents.ToolButton {
                icon.name: "view-refresh"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Reconnect")
                onClicked: root.reconnect()
            }

            PlasmaComponents.ToolButton {
                icon.name: "edit-clear-all"
                display: QQC2.AbstractButton.IconOnly
                QQC2.ToolTip.visible: hovered
                QQC2.ToolTip.text: i18n("Clear feed")
                enabled: root.messages.length > 0
                onClicked: root.clearMessages()
            }
        }

        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: 1
            color: Kirigami.Theme.disabledTextColor
            opacity: 0.2
        }

        ColumnLayout {
            Layout.alignment: Qt.AlignCenter
            Layout.topMargin: Kirigami.Units.gridUnit * 2
            Layout.fillWidth: true
            visible: root.messages.length === 0
            spacing: Kirigami.Units.largeSpacing

            PlasmaExtras.Heading {
                Layout.alignment: Qt.AlignHCenter
                level: 3
                visible: !root.isConfigured
                text: i18n("Welcome to ntfy Feed")
            }

            PlasmaComponents.Label {
                Layout.alignment: Qt.AlignHCenter
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.WordWrap
                color: Kirigami.Theme.disabledTextColor
                text: {
                    if (!root.isConfigured)
                        return i18n("Set a server URL and topic to start receiving notifications.");
                    if (root.connected)
                        return i18n("Waiting for messages on %1", root.topicSummary);
                    return i18n("Not connected. Retrying…");
                }
            }

            PlasmaComponents.Button {
                Layout.alignment: Qt.AlignHCenter
                visible: !root.isConfigured
                text: i18n("Configure")
                icon.name: "configure"
                onClicked: root.openConfig()
            }
        }

        QQC2.ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            visible: root.messages.length > 0

            ListView {
                id: feed
                model: root.messages
                spacing: Kirigami.Units.smallSpacing
                verticalLayoutDirection: ListView.BottomToTop
                // boundsBehavior alone allows residual overshoot when wrapped
                // in ScrollView; pairing it with boundsMovement prevents the
                // user from dragging or flicking past the content edges at
                // all. Both required.
                boundsBehavior: Flickable.StopAtBounds
                boundsMovement: Flickable.StopAtBounds

                delegate: MessageDelegate {
                    required property var modelData
                    required property int index

                    width: feed.width
                    msg: modelData
                    // BottomToTop: the highest index is the row drawn at the top.
                    isTopRow: index === feed.count - 1
                    textScale: Plasmoid.configuration.textScale || 1.0
                    showDivider: Plasmoid.configuration.showDividers
                    renderMarkdown: Plasmoid.configuration.renderMarkdown
                }
            }
        }
    }
}
