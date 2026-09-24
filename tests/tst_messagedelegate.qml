import QtQuick
import QtTest
import org.kde.kirigami as Kirigami
import "../package/contents/ui"

TestCase {
    id: tc
    name: "MessageDelegate"
    width: 400
    height: 400

    Component {
        id: delegateComponent
        MessageDelegate {
            width: 300
        }
    }

    function init() {
        failOnWarning(/\.qml:\d+/);
    }

    function make(msg) {
        return createTemporaryObject(delegateComponent, tc, {
            msg: msg
        });
    }

    function test_priorityColor_data() {
        return [
            {
                tag: "max",
                priority: 5,
                color: Kirigami.Theme.negativeTextColor
            },
            {
                tag: "high",
                priority: 4,
                color: Kirigami.Theme.neutralTextColor
            },
            {
                tag: "default",
                priority: 3,
                color: Kirigami.Theme.linkColor
            },
            {
                tag: "low",
                priority: 2,
                color: Kirigami.Theme.disabledTextColor
            },
            {
                tag: "min",
                priority: 1,
                color: Kirigami.Theme.disabledTextColor
            },
            {
                tag: "missing",
                priority: undefined,
                color: Kirigami.Theme.linkColor
            }
        ];
    }

    function test_priorityColor(data) {
        const d = make({
            message: "x",
            priority: data.priority
        });
        verify(Qt.colorEqual(d.borderColor, data.color), "got " + d.borderColor + ", want " + data.color);
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
}
