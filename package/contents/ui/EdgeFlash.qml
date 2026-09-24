// Soft accent glow around the edges of the overlay's screen, pulsing while any
// card is unread. Click-through and never focused, so it only draws.
import QtQuick
import org.kde.plasma.core as PlasmaCore

PlasmaCore.Dialog {
    id: flash

    property rect screenRect: Qt.rect(0, 0, 1920, 1080)
    readonly property color accent: "#5c9ae6"
    readonly property int depth: 15
    readonly property real peak: 0.55

    type: PlasmaCore.Dialog.OnScreenDisplay
    location: PlasmaCore.Types.Floating
    backgroundHints: PlasmaCore.Dialog.NoBackground
    flags: Qt.WindowStaysOnTopHint | Qt.WindowDoesNotAcceptFocus | Qt.WindowTransparentForInput
    hideOnWindowDeactivate: false

    x: screenRect.x
    y: screenRect.y

    function trigger() {
        if (visible && !fadeOut.running) return
        fadeOut.stop()
        glow.opacity = 0
        visible = true
        // One frame after mapping, so the start of the fade is on screen.
        start.restart()
    }

    function stop() {
        if (!visible) return
        start.stop()
        pulse.stop()
        fadeOut.start()
    }

    mainItem: Item {
        id: glow
        width: flash.screenRect.width
        height: flash.screenRect.height
        opacity: 0

        Timer { id: start; interval: 30; onTriggered: pulse.start() }

        Rectangle {
            anchors { left: parent.left; right: parent.right; top: parent.top }
            height: flash.depth
            gradient: Gradient {
                GradientStop { position: 0; color: flash.accent }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {
            anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
            height: flash.depth
            gradient: Gradient {
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: flash.accent }
            }
        }
        Rectangle {
            anchors { left: parent.left; top: parent.top; bottom: parent.bottom }
            width: flash.depth
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: flash.accent }
                GradientStop { position: 1; color: "transparent" }
            }
        }
        Rectangle {
            anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
            width: flash.depth
            gradient: Gradient {
                orientation: Gradient.Horizontal
                GradientStop { position: 0; color: "transparent" }
                GradientStop { position: 1; color: flash.accent }
            }
        }

        SequentialAnimation {
            id: pulse
            loops: Animation.Infinite
            NumberAnimation { target: glow; property: "opacity"; to: flash.peak; duration: 700; easing.type: Easing.InOutCubic }
            NumberAnimation { target: glow; property: "opacity"; to: 0; duration: 900; easing.type: Easing.InOutCubic }
        }

        NumberAnimation {
            id: fadeOut
            target: glow; property: "opacity"; to: 0; duration: 400; easing.type: Easing.InOutCubic
            onFinished: flash.visible = false
        }
    }
}
