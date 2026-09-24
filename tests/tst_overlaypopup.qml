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
        const out = [];
        for (let i = 0; i < o.cards.count; i++)
            out.push(o.cards.get(i).msgId);
        return out;
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

    // Regression: the queue was a JS array, so every push or dismiss rebuilt
    // all cards and replayed the fade-in of the ones already on screen.
    function test_existingCardsSurviveQueueChanges() {
        const o = make();
        o.push(msg("a"));
        const a = findChild(o.mainItem, "card-a");
        verify(a);
        tryCompare(a, "opacity", 1, 2000);
        o.push(msg("b"));
        verify(findChild(o.mainItem, "card-a") === a, "same card after a push");
        compare(a.opacity, 1, "no replayed fade-in after a push");
        o.dismiss(1);
        verify(findChild(o.mainItem, "card-a") === a, "same card after another is dismissed");
        compare(a.opacity, 1, "no replayed fade-in after a dismiss");
    }

    function test_clickDismissesAfterFade() {
        const o = make();
        o.push(msg("a"));
        const card = findChild(o.mainItem, "card-a");
        verify(card);
        mouseClick(card);
        compare(ids(o), ["a"], "the card stays until its fade finishes");
        tryCompare(o, "visible", false, 3000);
        compare(dismissedSpy.count, 1);
    }
}
