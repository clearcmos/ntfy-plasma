// Top-centre overlay for live messages. Stays until each card is clicked.
// Styled after the hotkey-help / chatgpt-launcher panels in clearcmos/arch.
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.core as PlasmaCore
import "Emoji.js" as Emoji

PlasmaCore.Dialog {
    id: dialog

    property var queue: []
    property rect screenRect: Qt.rect(0, 0, 1920, 1080)
    readonly property int panelWidth: 560
    readonly property int topGap: 28
    readonly property int maxCards: 5

    signal dismissed(string id)

    type: PlasmaCore.Dialog.Notification
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    hideOnWindowDeactivate: false

    x: screenRect.x + Math.round((screenRect.width - panelWidth) / 2)
    y: screenRect.y + topGap

    function push(msg) {
        const next = queue.slice()
        next.push(msg)
        while (next.length > maxCards) next.shift()
        queue = next
        visible = true
    }

    function dismiss(i) {
        const next = queue.slice()
        const gone = next.splice(i, 1)[0]
        queue = next
        if (next.length === 0) visible = false
        if (gone && gone.id) dismissed(gone.id)
    }

    // The Column only lays out once it sits in a shown window, and Plasma
    // refuses to show a zero-size dialog, so the wrapper never reports 0.
    mainItem: Item {
        width: dialog.panelWidth
        height: Math.max(1, stack.height)

        Column {
            id: stack
            width: dialog.panelWidth
            spacing: 10

            Repeater {
                model: dialog.queue

                delegate: Rectangle {
                    id: card
                    required property var modelData
                    required property int index
                    readonly property var msg: modelData
                    readonly property bool urgent: (msg.priority || 3) >= 4

                    width: dialog.panelWidth
                    height: body.implicitHeight + 44
                    radius: 17
                    color: area.containsMouse ? "#1c1c1f" : "#161618"
                    border.width: 1
                    border.color: urgent ? "#5c9ae6" : Qt.rgba(1, 1, 1, 0.10)
                    opacity: 0
                    Component.onCompleted: opacity = 1
                    Behavior on opacity { NumberAnimation { duration: 140 } }
                    Behavior on color { ColorAnimation { duration: 120 } }

                    ColumnLayout {
                        id: body
                        anchors.left: parent.left
                        anchors.right: parent.right
                        anchors.top: parent.top
                        anchors.margins: 22
                        anchors.leftMargin: 29
                        anchors.rightMargin: 29
                        spacing: 12

                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 14

                            Text {
                                Layout.fillWidth: true
                                text: {
                                    const e = Emoji.renderTags(card.msg.tags || [])
                                    const t = card.msg.title || card.msg.topic || ""
                                    return e ? e + "  " + t : t
                                }
                                color: "#e6e6e6"
                                font.family: "Hack"
                                font.pixelSize: 18
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                implicitWidth: topic.implicitWidth + 22
                                implicitHeight: topic.implicitHeight + 4
                                radius: 7
                                color: "#202024"
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.09)
                                Text {
                                    id: topic
                                    anchors.centerIn: parent
                                    text: card.msg.topic || ""
                                    color: "#5c9ae6"
                                    font.family: "Hack"
                                    font.pixelSize: 14
                                }
                            }
                        }

                        Rectangle {
                            Layout.fillWidth: true
                            implicitHeight: 1
                            color: Qt.rgba(1, 1, 1, 0.08)
                        }

                        Text {
                            Layout.fillWidth: true
                            text: card.msg.message || ""
                            color: "#e6e6e6"
                            font.family: "Hack"
                            font.pixelSize: 16
                            wrapMode: Text.Wrap
                            visible: text.length > 0
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: card.msg.time ? Qt.formatTime(new Date(card.msg.time * 1000), "h:mm AP") : ""
                                color: "#55555c"
                                font.family: "Hack"
                                font.pixelSize: 13
                            }
                            Item { Layout.fillWidth: true }
                            Text {
                                text: "click to dismiss"
                                color: "#55555c"
                                font.family: "Hack"
                                font.pixelSize: 13
                            }
                        }
                    }

                    MouseArea {
                        id: area
                        anchors.fill: parent
                        hoverEnabled: true
                        cursorShape: Qt.PointingHandCursor
                        onClicked: dialog.dismiss(card.index)
                    }
                }
            }
        }
    }
}
