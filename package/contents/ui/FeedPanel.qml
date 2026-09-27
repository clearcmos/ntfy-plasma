// The feed as a Basalt panel beside the panel icon. Replaces Plasma's applet
// popup, whose themed frame is not Basalt, but keeps its KWin slide.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Effects
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import "Feed.js" as Feed

PlasmaCore.Dialog {
    id: dialog

    property var messages: []
    property bool connected: false
    property bool configured: false
    property string topicSummary: ""
    property bool showDividers: true
    property bool renderMarkdown: true
    // The clock the row timestamps are relative to.
    property double nowMs: Date.now()
    // The panel icon the card opens beside, and the panel edge it sits on.
    property Item anchorItem: null
    property int edge: PlasmaCore.Types.BottomEdge
    property rect screenRect: Qt.rect(0, 0, 1920, 1080)

    // KWin keeps drawing the window while it slides away, but to QML it is
    // gone the moment close() unmaps it.
    readonly property bool shown: visible
    readonly property int panelWidth: 560
    readonly property int maxListHeight: 480
    // Basalt shadow-space, as in OverlayPopup.
    readonly property int shadowSide: 30
    readonly property int shadowTop: 20
    readonly property int shadowBottom: 40
    // Newest first.
    readonly property var rows: dialog.messages.slice().reverse()
    property bool justCopied: false
    // True while the rows swipe away on a clear, before clearRequested.
    property bool clearing: false
    // Delay between one row's swipe and the next, top to bottom: long
    // enough that each row is mostly gone before the next one moves.
    readonly property int swipeStagger: 250
    // The card's content height, what it animates towards, and the room the
    // window keeps for it. A grow resizes the window first; a shrink only
    // animates the card, and the window keeps its size until the panel next
    // opens. Resizing the visible window flickers its content for a frame,
    // as it did the overlay cards.
    readonly property real targetHeight: column.implicitHeight + 22 + 14
    property real cardHeight: 0
    property real frameHeight: 0
    // Space between the card and the panel it opens from.
    readonly property int panelGap: 10
    // Transparent room around the card: shadow-space, except on the panel's
    // side, where it is only the gap. KWin clips the slide at the window's
    // own edge, so that edge has to sit on the panel line for the card to
    // come out from behind the panel; the shadow is cut there too.
    readonly property int marginTop: dialog.edge === PlasmaCore.Types.TopEdge ? dialog.panelGap : dialog.shadowTop
    readonly property int marginBottom: dialog.edge === PlasmaCore.Types.BottomEdge ? dialog.panelGap : dialog.shadowBottom
    readonly property int marginLeft: dialog.edge === PlasmaCore.Types.LeftEdge ? dialog.panelGap : dialog.shadowSide
    readonly property int marginRight: dialog.edge === PlasmaCore.Types.RightEdge ? dialog.panelGap : dialog.shadowSide

    signal reconnectRequested
    signal clearRequested
    signal configureRequested

    // A location on a panel edge makes Plasma ask KWin's Sliding Popups
    // effect to slide the window in and out of that edge, the same motion
    // as Plasma's own applet popups. KWin gives an undecorated plasmashell
    // DialogWindow no other open or close effect.
    type: PlasmaCore.Dialog.DialogWindow
    location: dialog.edge
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.WindowStaysOnTopHint
    hideOnWindowDeactivate: false

    function open() {
        if (dialog.shown)
            return;
        feed.currentIndex = -1;
        dialog.justCopied = false;
        dialog.fit();
        dialog.place();
        dialog.visible = true;
        dialog.requestActivate();
        keys.forceActiveFocus();
    }

    // KWin slides the unmapped window back into the panel.
    function close() {
        if (!dialog.shown)
            return;
        dialog.visible = false;
    }

    function toggle() {
        if (dialog.shown)
            dialog.close();
        else
            dialog.open();
    }

    function edgeName() {
        switch (dialog.edge) {
        case PlasmaCore.Types.TopEdge:
            return "top";
        case PlasmaCore.Types.BottomEdge:
            return "bottom";
        case PlasmaCore.Types.LeftEdge:
            return "left";
        case PlasmaCore.Types.RightEdge:
            return "right";
        }
        return "";
    }

    function place() {
        const a = dialog.anchorItem;
        const w = a ? a.Window.window : null;
        let pos;
        if (a && w) {
            const p = a.mapToGlobal(0, 0);
            pos = Feed.panelPosition(dialog.edgeName(), Qt.rect(p.x, p.y, a.width, a.height), Qt.rect(w.x, w.y, w.width, w.height), dialog.screenRect, dialog.panelWidth, dialog.frameHeight, dialog.panelGap);
        } else {
            pos = Feed.panelPosition("", Qt.rect(0, 0, 0, 0), Qt.rect(0, 0, 0, 0), dialog.screenRect, dialog.panelWidth, dialog.frameHeight, dialog.panelGap);
        }
        dialog.x = pos.x - dialog.marginLeft;
        dialog.y = pos.y - dialog.marginTop;
    }

    // Swipe the rows on screen away one after another, then ask for the
    // clear once the last has gone.
    function clearAll() {
        if (dialog.clearing || feed.count === 0)
            return;
        dialog.clearing = true;
        feed.currentIndex = -1;
        let n = 0;
        for (let i = 0; i < feed.count; i++) {
            const row = feed.itemAtIndex(i) as MessageDelegate;
            if (row && row.y + row.height > feed.contentY && row.y < feed.contentY + feed.height)
                row.swipeAway(n++ * dialog.swipeStagger);
        }
        clearDone.interval = 400 + Math.max(0, n - 1) * dialog.swipeStagger;
        clearDone.restart();
    }

    function fit() {
        const t = dialog.targetHeight;
        if (!dialog.visible) {
            resize.stop();
            dialog.frameHeight = t;
            dialog.cardHeight = t;
            return;
        }
        if (t > dialog.frameHeight) {
            dialog.frameHeight = t;
            dialog.place();
        }
        resize.to = t;
        resize.restart();
    }

    onTargetHeightChanged: dialog.fit()

    function copyCurrent() {
        if (feed.currentItem)
            (feed.currentItem as MessageDelegate).copy();
    }

    function step(delta) {
        const n = feed.count;
        if (n === 0)
            return;
        if (feed.currentIndex < 0)
            feed.currentIndex = delta > 0 ? 0 : n - 1;
        else
            feed.currentIndex = Math.max(0, Math.min(n - 1, feed.currentIndex + delta));
        feed.positionViewAtIndex(feed.currentIndex, ListView.Contain);
    }

    // Losing focus to another window closes the panel.
    onActiveChanged: if (!dialog.active && dialog.shown)
        dialog.close()

    mainItem: Item {
        width: dialog.panelWidth + dialog.marginLeft + dialog.marginRight
        height: dialog.frameHeight + dialog.marginTop + dialog.marginBottom

        // card-reflow
        NumberAnimation {
            id: resize
            target: dialog
            property: "cardHeight"
            duration: 400
            easing.type: Easing.OutCubic
        }

        // The room left above a shrunk card is still this window, so a
        // click there closes the panel, as a click outside it would.
        MouseArea {
            objectName: "outside"
            anchors.fill: parent
            onClicked: dialog.close()
        }

        Timer {
            id: clearDone
            onTriggered: {
                dialog.clearing = false;
                dialog.clearRequested();
            }
        }

        Timer {
            id: copiedReset
            interval: 1500
            onTriggered: dialog.justCopied = false
        }

        Item {
            id: keys
            focus: true
            Keys.onPressed: function (event) {
                switch (event.key) {
                case Qt.Key_Escape:
                    dialog.close();
                    break;
                case Qt.Key_Down:
                    dialog.step(1);
                    break;
                case Qt.Key_Up:
                    dialog.step(-1);
                    break;
                case Qt.Key_Return:
                case Qt.Key_Enter:
                    if (!dialog.configured) {
                        dialog.close();
                        dialog.configureRequested();
                    } else {
                        dialog.copyCurrent();
                    }
                    break;
                case Qt.Key_R:
                    dialog.reconnectRequested();
                    break;
                case Qt.Key_C:
                    dialog.clearAll();
                    break;
                default:
                    return;
                }
                event.accepted = true;
            }
        }

        // Holds the shadow layer at the window's size, so a resize animation
        // only redraws it. Resizing the layered item itself reallocated the
        // shadow's texture on every frame, which flickered.
        Item {
            id: shell
            objectName: "card"
            x: dialog.marginLeft
            y: dialog.marginTop
            width: dialog.panelWidth
            height: dialog.frameHeight
            layer.enabled: true
            layer.effect: MultiEffect {
                shadowEnabled: true
                shadowColor: Qt.rgba(0, 0, 0, 0.55)
                shadowVerticalOffset: 10
                shadowBlur: 1.0
                blurMax: 30
            }

            Rectangle {
                id: card
                // On a bottom panel the card keeps its bottom edge by the panel
                // while it shrinks; elsewhere it keeps its top edge.
                y: dialog.edge === PlasmaCore.Types.BottomEdge ? dialog.frameHeight - dialog.cardHeight : 0
                width: dialog.panelWidth
                height: dialog.cardHeight
                clip: true
                radius: 17
                color: "#1f1f23"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.10)

                // Keeps clicks on the card itself from reaching "outside".
                MouseArea {
                    objectName: "cardArea"
                    anchors.fill: parent
                }

                ColumnLayout {
                    id: column
                    anchors.left: parent.left
                    anchors.right: parent.right
                    anchors.top: parent.top
                    anchors.topMargin: 22
                    spacing: 0

                    RowLayout {
                        Layout.fillWidth: true
                        Layout.leftMargin: 29
                        Layout.rightMargin: 29
                        Layout.bottomMargin: 14
                        spacing: 14

                        Text {
                            Layout.fillWidth: true
                            text: i18n("ntfy")
                            color: "#e6e6e6"
                            font.family: "Hack"
                            font.pixelSize: 18
                            font.bold: true
                        }

                        Text {
                            objectName: "status"
                            text: {
                                if (!dialog.configured)
                                    return i18n("not configured");
                                if (!dialog.connected)
                                    return i18n("disconnected");
                                return i18np("%1 message", "%1 messages", dialog.messages.length);
                            }
                            color: "#86868d"
                            font.family: "Hack"
                            font.pixelSize: 14
                        }
                    }

                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 1
                        color: Qt.rgba(1, 1, 1, 0.08)
                    }

                    Text {
                        objectName: "emptyText"
                        Layout.fillWidth: true
                        Layout.leftMargin: 29
                        Layout.rightMargin: 29
                        Layout.topMargin: 17
                        Layout.bottomMargin: 17
                        visible: feed.count === 0
                        text: {
                            if (!dialog.configured)
                                return i18n("Set a server URL and topics to start receiving messages.");
                            if (dialog.connected)
                                return i18n("Waiting for messages on %1", dialog.topicSummary);
                            return i18n("Not connected. Retrying...");
                        }
                        color: "#a0a0a0"
                        font.family: "Hack"
                        font.pixelSize: 16
                        wrapMode: Text.Wrap
                    }

                    ListView {
                        id: feed
                        objectName: "feed"
                        Layout.fillWidth: true
                        Layout.leftMargin: 14
                        Layout.rightMargin: 14
                        Layout.topMargin: 8
                        Layout.bottomMargin: 8
                        Layout.preferredHeight: Math.min(contentHeight, dialog.maxListHeight)
                        visible: count > 0
                        clip: true
                        model: dialog.rows
                        currentIndex: -1
                        highlightFollowsCurrentItem: false
                        boundsBehavior: Flickable.StopAtBounds
                        boundsMovement: Flickable.StopAtBounds
                        QQC2.ScrollBar.vertical: QQC2.ScrollBar {
                            policy: feed.contentHeight > feed.height ? QQC2.ScrollBar.AsNeeded : QQC2.ScrollBar.AlwaysOff
                            background: null
                            contentItem: Rectangle {
                                implicitWidth: 10
                                implicitHeight: 10
                                radius: 5
                                color: Qt.rgba(1, 1, 1, 0.16)
                            }
                        }

                        delegate: MessageDelegate {
                            required property var modelData
                            required property int index

                            width: ListView.view.width
                            msg: modelData
                            highlighted: feed.currentIndex === index
                            showDivider: dialog.showDividers && index > 0
                            renderMarkdown: dialog.renderMarkdown
                            nowMs: dialog.nowMs
                            onHovered: function (inside) {
                                if (dialog.clearing)
                                    return;
                                if (inside)
                                    feed.currentIndex = index;
                                else if (feed.currentIndex === index)
                                    feed.currentIndex = -1;
                            }
                            onCopied: {
                                dialog.justCopied = true;
                                copiedReset.restart();
                            }
                        }
                    }

                    Text {
                        objectName: "hint"
                        Layout.alignment: Qt.AlignRight
                        Layout.rightMargin: 29
                        Layout.topMargin: 14
                        text: {
                            if (dialog.justCopied)
                                return i18n("copied to clipboard");
                            if (!dialog.configured)
                                return i18n("enter to configure, esc to close");
                            return i18n("click to copy, r reconnect, c clear, esc to close");
                        }
                        color: "#86868d"
                        font.family: "Hack"
                        font.pixelSize: 13
                    }
                }
            }
        }
    }
}
