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

    // Regression: the window shrank on every dismissal, and resizing the
    // visible window flickered every remaining card for a frame. It now keeps
    // its height until the last card is gone.
    function test_windowKeepsItsHeightUntilTheLastCardGoes() {
        const o = make();
        o.push(msg("a"));
        o.push(msg("b"));
        o.push(msg("c"));
        const stack = findChild(o.mainItem, "stack");
        tryVerify(function () {
            return stack.height > 0 && o.frameHeight === stack.height;
        }, 2000);
        const tall = o.frameHeight;
        o.dismiss(0);
        tryVerify(function () {
            return stack.height < tall;
        }, 1000, "the stack is shorter");
        wait(700);
        compare(o.frameHeight, tall, "no resize while cards are on screen, even after the reflow");
        o.dismiss(0);
        o.dismiss(0);
        verify(!o.visible);
        compare(o.frameHeight, 0, "resets once the last card is gone");
        o.push(msg("d"));
        tryVerify(function () {
            return stack.height > 0 && o.frameHeight === stack.height;
        }, 2000, "the next card gets a window of its own height");
        verify(o.frameHeight < tall);
    }

    // Regression: dismissing the last card hid the window before the stack
    // laid out again, so it kept the old card's height. A next card of the
    // same height then changed nothing, the window never grew, and the card
    // showed cut off below its heading.
    function test_sameSizeCardAfterTheLastGoesGetsItsHeight() {
        const o = make();
        const stack = findChild(o.mainItem, "stack");
        o.push(msg("a"));
        tryVerify(function () {
            return stack.height > 0 && o.frameHeight === stack.height;
        }, 2000);
        const one = o.frameHeight;
        o.dismiss(0);
        compare(o.frameHeight, 0);
        o.push(msg("b"));
        tryVerify(function () {
            return o.frameHeight === one;
        }, 2000, "the window is tall enough for the card again");
    }

    // Regression: a card left on screen overnight kept its bare clock time,
    // so in the morning it read as if it had arrived that day.
    function test_cardStampFollowsTheClock() {
        const o = make();
        const sent = new Date(2026, 8, 26, 17, 4);
        o.nowMs = new Date(2026, 8, 26, 17, 5).getTime();
        o.push({
            id: "a",
            message: "body",
            time: sent.getTime() / 1000
        });
        const label = findChild(findChild(o.mainItem, "card-a"), "time");
        compare(label.text, "5:04 PM");
        o.nowMs = new Date(2026, 8, 27, 8, 0).getTime();
        compare(label.text, "Yesterday, 5:04 PM");
    }
}
