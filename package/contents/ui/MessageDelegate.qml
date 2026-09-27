// One feed row on the Basalt panel: heading and time, body, topic chip.
import QtQuick
import QtQuick.Layouts
import "Emoji.js" as Emoji
import "Feed.js" as Feed

Rectangle {
    id: root

    property var msg
    property bool showDivider: true
    property bool renderMarkdown: true
    property bool highlighted: false
    property double nowMs: Date.now()
    readonly property bool urgent: (root.msg && root.msg.priority ? root.msg.priority : 3) >= 4
    readonly property string heading: {
        const title = root.msg.title || root.msg.topic || "";
        const tags = root.renderMarkdown ? Emoji.renderTags(root.msg.tags || []) : "";
        return tags ? tags + "  " + title : title;
    }
    // Row padding, so the text lines up with the panel header 29px in when
    // the row itself is inset 14px from the card edge.
    readonly property int inset: 15

    // True from a dismiss click until the row has swiped away.
    property bool dismissing: false

    signal copied
    signal dismissed
    signal hovered(bool inside)

    implicitHeight: layout.implicitHeight + 24
    radius: 7
    color: root.highlighted ? "#25252a" : "#1f1f23"
    border.width: root.urgent ? 1 : 0
    border.color: "#5c9ae6"
    Behavior on color {
        ColorAnimation {
            duration: 120
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.leftMargin: root.inset
        anchors.rightMargin: root.inset
        height: 1
        color: Qt.rgba(1, 1, 1, 0.08)
        visible: root.showDivider && !root.highlighted
    }

    ColumnLayout {
        id: layout
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        anchors.margins: 12
        anchors.leftMargin: root.inset
        anchors.rightMargin: root.inset
        spacing: 6

        RowLayout {
            Layout.fillWidth: true
            spacing: 14

            Text {
                Layout.fillWidth: true
                text: root.heading
                color: "#e6e6e6"
                font.family: "Hack"
                font.pixelSize: 16
                elide: Text.ElideRight
            }

            Text {
                text: Feed.stamp(root.msg.time, root.nowMs)
                color: "#86868d"
                font.family: "Hack"
                font.pixelSize: 13
            }
        }

        Text {
            Layout.fillWidth: true
            visible: text.length > 0
            text: root.msg.message || ""
            textFormat: root.renderMarkdown ? Text.MarkdownText : Text.PlainText
            color: "#a0a0a0"
            linkColor: "#5c9ae6"
            font.family: "Hack"
            font.pixelSize: 16
            wrapMode: Text.Wrap
            maximumLineCount: 8
            elide: Text.ElideRight
        }

        RowLayout {
            Layout.fillWidth: true
            visible: !!root.msg.topic || (!root.renderMarkdown && !!(root.msg.tags && root.msg.tags.length))
            spacing: 14

            Rectangle {
                visible: !!root.msg.topic
                implicitWidth: topicLabel.implicitWidth + 22
                implicitHeight: topicLabel.implicitHeight + 4
                radius: 7
                color: "#29292f"
                border.width: 1
                border.color: Qt.rgba(1, 1, 1, 0.09)
                Text {
                    id: topicLabel
                    anchors.centerIn: parent
                    text: root.msg.topic || ""
                    color: "#5c9ae6"
                    font.family: "Hack"
                    font.pixelSize: 14
                }
            }

            Text {
                Layout.fillWidth: true
                visible: !root.renderMarkdown && !!(root.msg.tags && root.msg.tags.length)
                text: root.msg.tags ? root.msg.tags.join(", ") : ""
                color: "#86868d"
                font.family: "Hack"
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }
    }

    // Hidden TextEdit used solely as a clipboard helper. TextEdit.copy()
    // writes the selection to the system clipboard; we never show this.
    TextEdit {
        id: clipboardHelper
        visible: false
        readOnly: true
    }

    function _composeCopy() {
        const lines = [];
        if (root.msg.title && root.msg.title.length)
            lines.push(root.msg.title);
        if (root.msg.message && root.msg.message.length)
            lines.push(root.msg.message);
        const meta = [];
        if (root.msg.topic)
            meta.push("#" + root.msg.topic);
        if (root.msg.tags && root.msg.tags.length)
            meta.push(root.msg.tags.join(", "));
        if (meta.length)
            lines.push(String.fromCharCode(0x2014) + " " + meta.join(" " + String.fromCharCode(0xb7) + " "));
        return lines.join("\n\n");
    }

    // Clear-all motion: after `delay` ms the row slides right and fades with
    // card-out's duration and easing, so a cleared feed reads as swiped away.
    function swipeAway(delay) {
        swipeDelay.duration = delay;
        swipe.start();
    }

    // Swipe this row away on its own, then report it dismissed.
    function dismiss() {
        if (root.dismissing)
            return;
        root.dismissing = true;
        root.swipeAway(0);
    }

    transform: Translate {
        id: slide
    }

    SequentialAnimation {
        id: swipe
        onFinished: if (root.dismissing)
            root.dismissed()
        PauseAnimation {
            id: swipeDelay
        }
        ParallelAnimation {
            NumberAnimation {
                target: root
                property: "opacity"
                to: 0
                duration: 400
                easing.type: Easing.InOutCubic
            }
            NumberAnimation {
                target: slide
                property: "x"
                to: root.width / 3
                duration: 400
                easing.type: Easing.InOutCubic
            }
        }
    }

    function copy() {
        clipboardHelper.text = root._composeCopy();
        clipboardHelper.selectAll();
        clipboardHelper.copy();
        root.copied();
    }

    MouseArea {
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.RightButton | Qt.MiddleButton
        onEntered: root.hovered(true)
        onExited: root.hovered(false)

        onClicked: function (mouse) {
            if (mouse.button === Qt.MiddleButton && root.msg.click && root.msg.click.length) {
                Qt.openUrlExternally(root.msg.click);
                return;
            }
            if (mouse.button === Qt.RightButton)
                root.copy();
            else if (mouse.button === Qt.LeftButton)
                root.dismiss();
        }
    }
}
