import QtQuick
import QtTest
import org.kde.plasma.core as PlasmaCore
import "../package/contents/ui"

TestCase {
    id: tc
    name: "FeedPanel"
    when: windowShown

    // Plasma provides i18n through the applet's context; stand in for it.
    function i18n(s, a) {
        return a === undefined ? s : s.replace("%1", a);
    }
    function i18np(one, many, n) {
        return (n === 1 ? one : many).replace("%1", n);
    }

    Component {
        id: panelComponent
        FeedPanel {
            configured: true
            connected: true
            screenRect: Qt.rect(0, 0, 1280, 800)
        }
    }

    SignalSpy {
        id: reconnectSpy
        signalName: "reconnectRequested"
    }

    SignalSpy {
        id: clearSpy
        signalName: "clearRequested"
    }

    SignalSpy {
        id: dismissSpy
        signalName: "dismissRequested"
    }

    SignalSpy {
        id: configureSpy
        signalName: "configureRequested"
    }

    function init() {
        failOnWarning(/\.qml:\d+/);
    }

    function make(props) {
        const p = createTemporaryObject(panelComponent, tc, props || {});
        reconnectSpy.clear();
        reconnectSpy.target = p;
        configureSpy.clear();
        configureSpy.target = p;
        clearSpy.clear();
        clearSpy.target = p;
        dismissSpy.clear();
        dismissSpy.target = p;
        return p;
    }

    function msgs(n) {
        const out = [];
        for (let i = 0; i < n; i++)
            out.push({
                id: "m" + i,
                title: "title " + i,
                message: "body",
                topic: "alerts",
                time: 1
            });
        return out;
    }

    // KWin slides the window in on map and out on unmap, so both are
    // immediate on this side.
    function test_openMapsAndCloseUnmaps() {
        const p = make();
        p.open();
        verify(p.visible);
        verify(p.shown);
        p.close();
        verify(!p.visible);
        verify(!p.shown);
    }

    function test_toggle() {
        const p = make();
        p.toggle();
        verify(p.shown);
        p.toggle();
        verify(!p.shown);
        tryCompare(p, "visible", false, 1000);
    }

    function test_newestFirst() {
        const p = make({
            messages: msgs(3)
        });
        compare(p.rows.map(function (m) {
            return m.id;
        }), ["m2", "m1", "m0"]);
    }

    function test_statusLine_data() {
        return [
            {
                tag: "unconfigured",
                configured: false,
                connected: false,
                text: "not configured"
            },
            {
                tag: "disconnected",
                configured: true,
                connected: false,
                text: "disconnected"
            },
            {
                tag: "connected",
                configured: true,
                connected: true,
                text: "2 messages"
            }
        ];
    }

    function test_statusLine(data) {
        const p = make({
            configured: data.configured,
            connected: data.connected,
            messages: msgs(2)
        });
        compare(findChild(p.mainItem, "status").text, data.text);
    }

    function test_arrowsHighlightFromNothing() {
        const p = make({
            messages: msgs(3)
        });
        p.open();
        const list = findChild(p.mainItem, "feed");
        compare(list.currentIndex, -1, "nothing highlighted on open");
        p.step(1);
        compare(list.currentIndex, 0, "first down picks the first row");
        p.step(1);
        p.step(1);
        p.step(1);
        compare(list.currentIndex, 2, "stops at the last row");
        list.currentIndex = -1;
        p.step(-1);
        compare(list.currentIndex, 2, "first up picks the last row");
    }

    function test_copyShowsHint() {
        const p = make({
            messages: msgs(1)
        });
        p.open();
        const list = findChild(p.mainItem, "feed");
        list.currentIndex = 0;
        p.copyCurrent();
        compare(findChild(p.mainItem, "hint").text, "copied to clipboard");
    }

    function test_clickDismissesThatRow() {
        const p = make({
            messages: msgs(3)
        });
        p.open();
        const list = findChild(p.mainItem, "feed");
        tryVerify(function () {
            return list.itemAtIndex(1) !== null;
        }, 1000);
        waitForRendering(p.mainItem);
        mouseClick(list.itemAtIndex(1), 20, 20);
        tryCompare(dismissSpy, "count", 1, 2000);
        // Rows are newest first, so the second row is m1.
        compare(dismissSpy.signalArguments[0][0], "m1");
        verify(p.shown);
    }

    function test_hintFitsTheCard() {
        const p = make();
        p.open();
        const hint = findChild(p.mainItem, "hint");
        verify(hint.implicitWidth + 29 * 2 <= p.panelWidth, "hint " + hint.implicitWidth + "px");
    }

    function test_keys() {
        const p = make({
            messages: msgs(1)
        });
        p.open();
        tryVerify(function () {
            return p.active;
        }, 1000);
        keyClick(Qt.Key_R);
        compare(reconnectSpy.count, 1);
        keyClick(Qt.Key_Escape);
        verify(!p.shown);
    }

    function test_enterConfiguresWhenUnconfigured() {
        const p = make({
            configured: false
        });
        p.open();
        tryVerify(function () {
            return p.active;
        }, 1000);
        keyClick(Qt.Key_Return);
        compare(configureSpy.count, 1);
        verify(!p.shown);
    }

    function test_clearSwipesRowsAwayBeforeRequesting() {
        const p = make({
            messages: msgs(3)
        });
        p.open();
        const list = findChild(p.mainItem, "feed");
        tryVerify(function () {
            return list.itemAtIndex(2) !== null;
        }, 1000, "rows are created");
        p.clearAll();
        verify(p.clearing);
        compare(clearSpy.count, 0, "rows animate before the feed empties");
        p.clearAll();
        tryCompare(clearSpy, "count", 1, 3000);
        verify(!p.clearing);
        for (let i = 0; i < list.count; i++)
            compare(list.itemAtIndex(i).opacity, 0, "row " + i + " faded out");
    }

    // Regression: the window snapped to the empty size the moment the feed
    // was cleared, and resizing it after the animation instead still flashed
    // the card see-through for a frame. The card now shrinks inside a window
    // that keeps its size until the panel next opens.
    function test_shrinkKeepsWindowUntilReopened() {
        const p = make({
            messages: msgs(3)
        });
        p.open();
        tryVerify(function () {
            return p.cardHeight === p.targetHeight && p.targetHeight > 200;
        }, 1000);
        const tall = p.frameHeight;
        p.messages = [];
        tryVerify(function () {
            return p.targetHeight < tall;
        }, 1000, "the empty feed is shorter");
        verify(p.cardHeight > p.targetHeight, "shrink is animated, not a snap");
        tryCompare(p, "cardHeight", p.targetHeight, 2000);
        compare(p.frameHeight, tall, "window keeps its size while open");
        p.close();
        tryCompare(p, "visible", false, 1000);
        p.open();
        compare(p.frameHeight, p.targetHeight, "reopening sizes the window to the card");
    }

    function test_clickAboveShrunkCardCloses() {
        const p = make();
        p.open();
        findChild(p.mainItem, "outside").clicked(null);
        verify(!p.shown);
    }

    function test_clickOnCardKeepsItOpen() {
        const p = make();
        p.open();
        waitForRendering(p.mainItem);
        const area = findChild(p.mainItem, "cardArea");
        mouseClick(area, 20, 20);
        verify(p.shown);
    }

    // Regression: the panel drew its own slide, which never matched Plasma's
    // applet popups. It now sits on the panel edge so Plasma hands it to
    // KWin's Sliding Popups, and since KWin clips the slide at the window's
    // own edge, the window keeps only the gap on the panel's side.
    function test_slidesWithKWinFromThePanelEdge_data() {
        return [
            {
                tag: "bottom",
                edge: PlasmaCore.Types.BottomEdge
            },
            {
                tag: "top",
                edge: PlasmaCore.Types.TopEdge
            },
            {
                tag: "left",
                edge: PlasmaCore.Types.LeftEdge
            },
            {
                tag: "right",
                edge: PlasmaCore.Types.RightEdge
            }
        ];
    }

    function test_slidesWithKWinFromThePanelEdge(data) {
        const p = make({
            edge: data.edge
        });
        p.open();
        compare(p.location, data.edge);
        const shell = findChild(p.mainItem, "card");
        const w = p.mainItem.width;
        const h = p.mainItem.height;
        const gaps = {
            top: shell.y,
            bottom: h - shell.y - shell.height,
            left: shell.x,
            right: w - shell.x - shell.width
        };
        compare(gaps[data.tag], p.panelGap, "window edge on the panel line");
    }
}
