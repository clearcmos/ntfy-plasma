import QtQuick
import QtTest
import "../package/contents/ui"
import "../package/contents/ui/Feed.js" as Feed

TestCase {
    id: tc
    name: "KdeMirror"

    Component {
        id: mirrorComponent
        KdeMirror {
            enabled: true
        }
    }

    SignalSpy {
        id: runSpy
        signalName: "run"
    }

    function init() {
        failOnWarning(/\.qml:\d+/);
    }

    function make() {
        const m = createTemporaryObject(mirrorComponent, tc);
        runSpy.clear();
        runSpy.target = m;
        return m;
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

    function test_disabledPostsNothing() {
        const m = make();
        m.enabled = false;
        m.post(msg("a"));
        compare(runSpy.count, 0);
    }

    function test_dismissClosesThePostedNotification() {
        const m = make();
        m.post(msg("a"));
        compare(runSpy.count, 1);
        const posted = runSpy.signalArguments[0][0];
        m.finished(posted, "17\n");
        m.close("a");
        compare(runSpy.count, 2);
        compare(runSpy.signalArguments[1][0], Feed.closeCommand(17));
        // A second dismiss has nothing left to close.
        m.close("a");
        compare(runSpy.count, 2);
    }

    function test_eachPostIsItsOwnCommand() {
        const m = make();
        m.post(msg("a"));
        m.post(msg("a"));
        verify(runSpy.signalArguments[0][0] !== runSpy.signalArguments[1][0]);
    }

    function test_dismissBeforeTheIdArrivesClosesOnArrival() {
        const m = make();
        m.post(msg("a"));
        m.close("a");
        compare(runSpy.count, 1);
        m.finished(runSpy.signalArguments[0][0], "9");
        compare(runSpy.count, 2);
        compare(runSpy.signalArguments[1][0], Feed.closeCommand(9));
    }

    function test_failedPostLeavesNothingToClose() {
        const m = make();
        m.post(msg("a"));
        m.finished(runSpy.signalArguments[0][0], "");
        m.close("a");
        compare(runSpy.count, 1);
    }

    function test_closeOutputIsIgnored() {
        const m = make();
        m.finished(Feed.closeCommand(3), "()");
        compare(runSpy.count, 0);
    }
}
