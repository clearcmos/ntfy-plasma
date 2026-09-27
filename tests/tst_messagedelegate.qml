import QtQuick
import QtTest
import "../package/contents/ui"

TestCase {
    id: tc
    name: "MessageDelegate"
    when: windowShown
    // TestCase is hidden by default, and a hidden row takes no clicks.
    visible: true
    width: 600
    height: 400

    Component {
        id: delegateComponent
        MessageDelegate {
            width: 530
        }
    }

    SignalSpy {
        id: copiedSpy
        signalName: "copied"
    }

    SignalSpy {
        id: dismissedSpy
        signalName: "dismissed"
    }

    function init() {
        failOnWarning(/\.qml:\d+/);
    }

    function make(msg, props) {
        const d = createTemporaryObject(delegateComponent, tc, Object.assign({
            msg: msg
        }, props || {}));
        copiedSpy.clear();
        copiedSpy.target = d;
        dismissedSpy.clear();
        dismissedSpy.target = d;
        return d;
    }

    function test_urgentAtHighPriority_data() {
        return [
            {
                tag: "max",
                priority: 5,
                urgent: true
            },
            {
                tag: "high",
                priority: 4,
                urgent: true
            },
            {
                tag: "default",
                priority: 3,
                urgent: false
            },
            {
                tag: "min",
                priority: 1,
                urgent: false
            },
            {
                tag: "missing",
                priority: undefined,
                urgent: false
            }
        ];
    }

    function test_urgentAtHighPriority(data) {
        const d = make({
            message: "x",
            priority: data.priority
        });
        compare(d.urgent, data.urgent);
        compare(d.border.width, data.urgent ? 1 : 0);
    }

    function test_highlightUsesSurfaceHover() {
        const d = make({
            message: "x"
        }, {
            highlighted: true
        });
        tryVerify(function () {
            return Qt.colorEqual(d.color, "#25252a");
        }, 1000);
    }

    function test_headingPrefixesRenderedTags() {
        const d = make({
            title: "Backup",
            tags: ["nope-not-an-emoji"]
        });
        compare(d.heading, "#nope-not-an-emoji  Backup");
        d.renderMarkdown = false;
        compare(d.heading, "Backup");
    }

    function test_headingFallsBackToTopic() {
        compare(make({
            topic: "alerts",
            message: "x"
        }).heading, "alerts");
    }

    // Regression: a message with no tags or topic bound undefined to the
    // tag row's bool `visible`, logging a warning per message.
    function test_bodyOnlyMessageRendersCleanly() {
        verify(make({
            message: "only a body"
        }));
    }

    function test_copyTextIncludesTitleBodyAndMeta() {
        const d = make({
            title: "Backup",
            message: "done",
            topic: "alerts",
            tags: ["ok", "nightly"]
        });
        // The separators are an em dash and a middle dot.
        const expected = "Backup\n\ndone\n\n" + String.fromCharCode(0x2014) + " #alerts " + String.fromCharCode(0xb7) + " ok, nightly";
        compare(d._composeCopy(), expected);
    }

    function test_copyTextSkipsMissingParts() {
        compare(make({
            message: "just this"
        })._composeCopy(), "just this");
    }

    function test_copyEmitsCopied() {
        const d = make({
            message: "x"
        });
        d.copy();
        compare(copiedSpy.count, 1);
    }

    function test_leftClickDismissesAfterTheSwipe() {
        const d = make({
            message: "x"
        });
        mouseClick(d, 10, 10, Qt.LeftButton);
        verify(d.dismissing);
        compare(dismissedSpy.count, 0, "the row swipes away first");
        tryCompare(dismissedSpy, "count", 1, 2000);
        compare(copiedSpy.count, 0);
    }

    function test_rightClickCopies() {
        const d = make({
            message: "x"
        });
        mouseClick(d, 10, 10, Qt.RightButton);
        compare(copiedSpy.count, 1);
        verify(!d.dismissing);
    }
}
