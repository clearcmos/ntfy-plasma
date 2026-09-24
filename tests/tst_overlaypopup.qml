import QtQuick
import QtTest
import "../package/contents/ui"

TestCase {
    id: tc
    name: "OverlayPopup"
    when: windowShown

    Component {
        id: overlayComponent
        OverlayPopup {
            chimeEnabled: false
        }
    }

    SignalSpy {
        id: dismissedSpy
        signalName: "dismissed"
    }

    function init() {
        failOnWarning(/\.qml:\d+/);
    }

    function make() {
        const o = createTemporaryObject(overlayComponent, tc);
        dismissedSpy.clear();
        dismissedSpy.target = o;
        return o;
    }

    function msg(id) {
        return {
            id: id,
            title: "title " + id,
            message: "body",
            topic: "alerts",
            time: 1
        };
    }

    function ids(o) {
        return o.queue.map(function (m) {
            return m.id;
        });
    }

    function test_pushShowsCard() {
        const o = make();
        verify(!o.visible);
        o.push(msg("a"));
        verify(o.visible);
        compare(ids(o), ["a"]);
    }

    function test_pushKeepsNewestMaxCards() {
        const o = make();
        ["a", "b", "c", "d", "e", "f", "g"].forEach(function (id) {
            o.push(tc.msg(id));
        });
        compare(ids(o), ["c", "d", "e", "f", "g"]);
    }

    function test_dismissRemovesCardAndHidesWhenEmpty() {
        const o = make();
        o.push(msg("a"));
        o.push(msg("b"));
        o.dismiss(0);
        compare(ids(o), ["b"]);
        compare(dismissedSpy.signalArguments[0][0], "a");
        verify(o.visible);
        o.dismiss(0);
        verify(!o.visible);
    }

    function test_clickDismissesAfterFade() {
        const o = make();
        o.push(msg("a"));
        const card = findChild(o.mainItem, "card");
        verify(card);
        mouseClick(card);
        compare(ids(o), ["a"], "the card stays until its fade finishes");
        tryCompare(o, "visible", false, 3000);
        compare(dismissedSpy.count, 1);
    }
}
