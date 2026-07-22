import QtQuick
import QtQuick.Controls as QQC2
import QtQuick.Layouts
import org.kde.plasma.components as PlasmaComponents
import org.kde.kirigami as Kirigami
import "Emoji.js" as Emoji

Rectangle {
    id: root

    property var msg
    property real textScale: 1.0
    property bool showDivider: true
    property bool renderMarkdown: true
    property int priority: msg && msg.priority ? msg.priority : 3

    readonly property color borderColor: {
        switch (priority) {
            case 5: return Kirigami.Theme.negativeTextColor
            case 4: return Kirigami.Theme.neutralTextColor
            case 1:
            case 2: return Kirigami.Theme.disabledTextColor
            default: return Kirigami.Theme.linkColor
        }
    }

    readonly property real basePoint: Kirigami.Theme.defaultFont.pointSize
    readonly property real smallPoint: Kirigami.Theme.smallFont.pointSize
    readonly property real titlePoint: basePoint * textScale
    readonly property real bodyPoint: smallPoint * textScale
    readonly property real metaPoint: Math.max(smallPoint - 1, 7) * textScale

    color: "transparent"
    Layout.fillWidth: true
    implicitHeight: layout.implicitHeight + Kirigami.Units.smallSpacing * 2

    // Hairline divider above each row. Hidden on the topmost-displayed row
    // (highest model index in BottomToTop layout) so we don't double up
    // against the toolbar separator.
    Rectangle {
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        height: 1
        color: Kirigami.Theme.textColor
        opacity: 0.08
        visible: root.showDivider && index !== (ListView.view ? ListView.view.count - 1 : -1)
    }

    // Subtle hover wash, fades in/out.
    Rectangle {
        id: hoverWash
        anchors.fill: parent
        anchors.margins: 1
        radius: 4
        color: Kirigami.Theme.textColor
        opacity: hoverArea.containsMouse ? 0.06 : 0
        Behavior on opacity { NumberAnimation { duration: 140; easing.type: Easing.OutQuad } }
    }

    // Brief flash after a successful copy.
    Rectangle {
        id: copyFlash
        anchors.fill: parent
        anchors.margins: 1
        radius: 4
        color: Kirigami.Theme.positiveTextColor
        opacity: 0

        SequentialAnimation {
            id: flashAnim
            NumberAnimation { target: copyFlash; property: "opacity"; to: 0.18; duration: 100 }
            PauseAnimation { duration: 80 }
            NumberAnimation { target: copyFlash; property: "opacity"; to: 0; duration: 220 }
        }
    }

    Rectangle {
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.bottom: parent.bottom
        width: 3
        color: root.borderColor
        radius: 2
    }

    ColumnLayout {
        id: layout
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing + 8
        anchors.rightMargin: Kirigami.Units.smallSpacing
        anchors.topMargin: Kirigami.Units.smallSpacing
        anchors.bottomMargin: Kirigami.Units.smallSpacing
        spacing: 2

        RowLayout {
            Layout.fillWidth: true
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                Layout.fillWidth: true
                text: (msg.title && msg.title.length) ? msg.title : (msg.topic || "")
                font.bold: true
                font.pointSize: root.titlePoint
                elide: Text.ElideRight
            }

            PlasmaComponents.Label {
                text: Qt.formatDateTime(new Date((msg.time || 0) * 1000), "hh:mm")
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: root.metaPoint
            }
        }

        PlasmaComponents.Label {
            Layout.fillWidth: true
            text: msg.message || ""
            textFormat: root.renderMarkdown ? Text.MarkdownText : Text.PlainText
            wrapMode: Text.WordWrap
            maximumLineCount: 8
            elide: Text.ElideRight
            font.pointSize: root.bodyPoint
            onLinkActivated: function(url) { Qt.openUrlExternally(url) }
        }

        RowLayout {
            Layout.fillWidth: true
            visible: (msg.tags && msg.tags.length > 0) || (msg.topic && msg.topic.length > 0)
            spacing: Kirigami.Units.smallSpacing

            PlasmaComponents.Label {
                visible: !!msg.topic
                text: "#" + (msg.topic || "")
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: root.metaPoint
            }

            PlasmaComponents.Label {
                visible: msg.tags && msg.tags.length > 0
                text: root.renderMarkdown
                    ? Emoji.renderTags(msg.tags || [])
                    : (msg.tags ? msg.tags.join(", ") : "")
                color: Kirigami.Theme.disabledTextColor
                font.pointSize: root.metaPoint
                elide: Text.ElideRight
                Layout.fillWidth: true
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
        const lines = []
        if (msg.title && msg.title.length) lines.push(msg.title)
        if (msg.message && msg.message.length) lines.push(msg.message)
        const meta = []
        if (msg.topic) meta.push("#" + msg.topic)
        if (msg.tags && msg.tags.length) meta.push(msg.tags.join(", "))
        if (meta.length) lines.push("— " + meta.join(" · "))
        return lines.join("\n\n")
    }

    MouseArea {
        id: hoverArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: Qt.PointingHandCursor
        acceptedButtons: Qt.LeftButton | Qt.MiddleButton

        onClicked: function(mouse) {
            if (mouse.button === Qt.MiddleButton && msg.click && msg.click.length) {
                Qt.openUrlExternally(msg.click)
                return
            }
            clipboardHelper.text = root._composeCopy()
            clipboardHelper.selectAll()
            clipboardHelper.copy()
            flashAnim.restart()
        }
    }
}
