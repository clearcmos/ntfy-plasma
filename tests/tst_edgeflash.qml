import QtQuick
import QtTest
import "../package/contents/ui"

TestCase {
    id: tc
    name: "EdgeFlash"

    Component {
        id: flashComponent
        EdgeFlash {
            screenRect: Qt.rect(0, 0, 640, 480)
        }
    }

    function init() {
        failOnWarning(/\.qml:\d+/);
    }

    function glowing(f) {
        return function () {
            return f.mainItem.opacity > 0;
        };
    }

    function test_triggerShowsAndPulses() {
        const f = createTemporaryObject(flashComponent, tc);
        f.trigger();
        verify(f.visible);
        tryVerify(glowing(f), 2000, "pulse raises the glow");
    }

    function test_stopFadesOutThenHides() {
        const f = createTemporaryObject(flashComponent, tc);
        f.trigger();
        tryVerify(glowing(f), 2000);
        f.stop();
        verify(f.visible, "stays mapped while fading");
        tryCompare(f, "visible", false, 2000);
        compare(f.mainItem.opacity, 0);
    }

    function test_triggerDuringFadeOutRestarts() {
        const f = createTemporaryObject(flashComponent, tc);
        f.trigger();
        tryVerify(glowing(f), 2000);
        f.stop();
        f.trigger();
        wait(700);  // longer than the 400 ms fade-out
        verify(f.visible);
    }

    function test_stopWhileHiddenIsNoop() {
        const f = createTemporaryObject(flashComponent, tc);
        f.stop();
        verify(!f.visible);
    }
}
