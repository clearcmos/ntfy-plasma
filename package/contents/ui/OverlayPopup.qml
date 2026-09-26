// Top-centre overlay for live messages. Stays until each card is clicked.
pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Effects
import QtQuick.Layouts
import QtMultimedia
import org.kde.plasma.core as PlasmaCore
import "Emoji.js" as Emoji

PlasmaCore.Dialog {
    id: dialog

    // A ListModel rather than a JS array property: reassigning the array made
    // the Repeater rebuild every card, replaying the fade-in of cards already
    // on screen. Each row holds the display text, computed once at push.
    property alias cards: cardModel
    readonly property int cardCount: cardModel.count
    property rect screenRect: Qt.rect(0, 0, 1920, 1080)
    readonly property int panelWidth: 560
    readonly property int topGap: 28
    // Basalt shadow-space: transparent room around the cards so their
    // shadow is not clipped. topGap is measured to the card, not the window.
    readonly property int shadowSide: 30
    readonly property int shadowTop: 20
    readonly property int shadowBottom: 40
    readonly property int maxCards: 5
    // Off in the test suite so running it does not play the chime.
    property bool chimeEnabled: true
    // The height the window keeps for the cards. It grows with the stack but
    // never shrinks while cards are on screen: resizing the visible window
    // flickered every card for a frame on each dismissal. It resets once
    // the last card is gone and the window is hidden. The cost is that the
    // empty room below the remaining cards takes clicks until then.
    property real frameHeight: 0

    signal dismissed(string id)

    type: PlasmaCore.Dialog.Notification
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus
    hideOnWindowDeactivate: false

    x: screenRect.x + Math.round((screenRect.width - panelWidth) / 2) - shadowSide
    y: screenRect.y + topGap - shadowTop

    function push(msg) {
        if (chimeEnabled)
            chime.play();
        const tags = Emoji.renderTags(msg.tags || []);
        const title = msg.title || msg.topic || "";
        cardModel.append({
            msgId: msg.id || "",
            heading: tags ? tags + "  " + title : title,
            topicName: msg.topic || "",
            messageText: msg.message || "",
            sentAt: msg.time || 0,
            urgent: (msg.priority || 3) >= 4
        });
        while (cardModel.count > maxCards)
            cardModel.remove(0);
        visible = true;
    }

    function dismiss(i) {
        if (i < 0 || i >= cardModel.count)
            return;
        const id = cardModel.get(i).msgId;
        cardModel.remove(i);
        // A hidden window does not lay the stack out again, so its height
        // would never come down on its own.
        if (cardModel.count === 0) {
            visible = false;
            frameHeight = 0;
        }
        if (id)
            dismissed(id);
    }

    // The Column only lays out once it sits in a shown window, and Plasma
    // refuses to show a zero-size dialog, so the wrapper never reports 0.
    mainItem: Item {
        width: dialog.panelWidth + 2 * dialog.shadowSide
        height: dialog.frameHeight + dialog.shadowTop + dialog.shadowBottom

        // Oxygen "power-plug" chime (outcome-success.ogg from oxygen-sounds,
        // LGPL-3.0-or-later, see ../sounds/power-plug.wav.license), as WAV
        // because SoundEffect only plays uncompressed audio.
        SoundEffect {
            id: chime
            source: Qt.resolvedUrl("../sounds/power-plug.wav")
        }

        ListModel {
            id: cardModel
        }

        Column {
            id: stack
            objectName: "stack"
            x: dialog.shadowSide
            y: dialog.shadowTop
            width: dialog.panelWidth
            spacing: 10
            onHeightChanged: if (height > dialog.frameHeight)
                dialog.frameHeight = height
            move: Transition {
                NumberAnimation {
                    property: "y"
                    duration: 400
                    easing.type: Easing.OutCubic
                }
            }

            Repeater {
                model: cardModel

                delegate: Rectangle {
                    id: card
                    required property int index
                    required property string msgId
                    required property string heading
                    required property string topicName
                    required property string messageText
                    required property real sentAt
                    required property bool urgent

                    objectName: "card-" + msgId

                    width: dialog.panelWidth
                    height: body.implicitHeight + 44
                    opacity: 0
                    scale: 0.96
                    transformOrigin: Item.Top
                    radius: 17
                    color: area.containsMouse ? "#25252a" : "#1f1f23"
                    border.width: 1
                    border.color: card.urgent ? "#5c9ae6" : Qt.rgba(1, 1, 1, 0.10)
                    layer.enabled: true
                    layer.effect: MultiEffect {
                        shadowEnabled: true
                        shadowColor: Qt.rgba(0, 0, 0, 0.55)
                        shadowVerticalOffset: 10
                        shadowBlur: 1.0
                        blurMax: 30
                    }
                    transform: Translate {
                        id: shift
                        y: -10
                    }
                    Behavior on color {
                        ColorAnimation {
                            duration: 120
                        }
                    }

                    // Started a frame after creation so the window is mapped
                    // and the whole fade is actually on screen.
                    Timer {
                        interval: 30
                        running: true
                        onTriggered: enter.start()
                    }

                    ParallelAnimation {
                        id: enter
                        NumberAnimation {
                            target: card
                            property: "opacity"
                            to: 1
                            duration: 450
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: card
                            property: "scale"
                            to: 1
                            duration: 450
                            easing.type: Easing.OutCubic
                        }
                        NumberAnimation {
                            target: shift
                            property: "y"
                            to: 0
                            duration: 450
                            easing.type: Easing.OutCubic
                        }
                    }

                    ParallelAnimation {
                        id: leave
                        NumberAnimation {
                            target: card
                            property: "opacity"
                            to: 0
                            duration: 400
                            easing.type: Easing.InOutCubic
                        }
                        NumberAnimation {
                            target: card
                            property: "scale"
                            to: 0.94
                            duration: 400
                            easing.type: Easing.InOutCubic
                        }
                        NumberAnimation {
                            target: shift
                            property: "y"
                            to: -10
                            duration: 400
                            easing.type: Easing.InOutCubic
                        }
                        onFinished: dialog.dismiss(card.index)
                    }

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
                                text: card.heading
                                color: "#e6e6e6"
                                font.family: "Hack"
                                font.pixelSize: 18
                                font.bold: true
                                elide: Text.ElideRight
                            }

                            Rectangle {
                                implicitWidth: topicLabel.implicitWidth + 22
                                implicitHeight: topicLabel.implicitHeight + 4
                                radius: 7
                                color: "#29292f"
                                border.width: 1
                                border.color: Qt.rgba(1, 1, 1, 0.09)
                                Text {
                                    id: topicLabel
                                    anchors.centerIn: parent
                                    text: card.topicName
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
                            text: card.messageText
                            color: "#e6e6e6"
                            font.family: "Hack"
                            font.pixelSize: 16
                            wrapMode: Text.Wrap
                            visible: text.length > 0
                        }

                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                text: card.sentAt ? Qt.formatTime(new Date(card.sentAt * 1000), "h:mm AP") : ""
                                color: "#86868d"
                                font.family: "Hack"
                                font.pixelSize: 13
                            }
                            Item {
                                Layout.fillWidth: true
                            }
                            Text {
                                text: "click to dismiss"
                                color: "#86868d"
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
                        enabled: !leave.running
                        onClicked: {
                            enter.stop();
                            leave.start();
                        }
                    }
                }
            }
        }
    }
}
