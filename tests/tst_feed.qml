import QtQuick
import QtTest
import "../package/contents/ui/Feed.js" as Feed

TestCase {
    name: "Feed"

    function test_parseTopics_data() {
        return [
            {
                tag: "single",
                input: "alerts",
                expected: ["alerts"]
            },
            {
                tag: "trims and drops empties",
                input: " a , ,b,, ",
                expected: ["a", "b"]
            },
            {
                tag: "only commas",
                input: " , ,",
                expected: []
            },
            {
                tag: "empty",
                input: "",
                expected: []
            },
            {
                tag: "undefined",
                input: undefined,
                expected: []
            }
        ];
    }

    function test_parseTopics(data) {
        compare(Feed.parseTopics(data.input), data.expected);
    }

    function test_streamUrl_data() {
        return [
            {
                tag: "basic",
                server: "https://ntfy.sh",
                topics: "a,b",
                since: "1h",
                expected: "https://ntfy.sh/a,b/json?since=1h"
            },
            {
                tag: "trailing slashes and spaces",
                server: "  https://ntfy.sh//  ",
                topics: " a , b ",
                since: "1h",
                expected: "https://ntfy.sh/a,b/json?since=1h"
            },
            {
                tag: "empty since means 0",
                server: "https://ntfy.sh",
                topics: "a",
                since: " ",
                expected: "https://ntfy.sh/a/json?since=0"
            },
            {
                tag: "since is encoded",
                server: "https://ntfy.sh",
                topics: "a",
                since: "1h&x=y",
                expected: "https://ntfy.sh/a/json?since=1h%26x%3Dy"
            },
            {
                tag: "no server",
                server: "",
                topics: "a",
                since: "1h",
                expected: ""
            },
            {
                tag: "topics only commas",
                server: "https://ntfy.sh",
                topics: ",,",
                since: "1h",
                expected: ""
            }
        ];
    }

    function test_streamUrl(data) {
        compare(Feed.streamUrl(data.server, data.topics, data.since), data.expected);
    }

    function test_completeLines_keepsPartialTail() {
        const r = Feed.completeLines("one\ntwo\npar", 0);
        compare(r.lines, ["one", "two"]);
        compare(r.next, 8);
    }

    function test_completeLines_resumesFromOffset() {
        const text = "one\ntwo\npartial";
        const first = Feed.completeLines(text, 0);
        const second = Feed.completeLines(text + " done\n", first.next);
        compare(second.lines, ["partial done"]);
        compare(second.next, text.length + 6);
    }

    function test_completeLines_noNewNewline() {
        compare(Feed.completeLines("one\ntw", 4), {
            lines: [],
            next: 4
        });
        compare(Feed.completeLines("", 0), {
            lines: [],
            next: 0
        });
    }

    function test_appendMessage_dedupesById() {
        const list = [
            {
                id: "a"
            },
            {
                id: "b"
            }
        ];
        compare(Feed.appendMessage(list, {
            id: "a"
        }, 10), null);
    }

    function test_appendMessage_capsAndCopies() {
        const list = [
            {
                id: "a"
            },
            {
                id: "b"
            }
        ];
        const next = Feed.appendMessage(list, {
            id: "c"
        }, 2);
        compare(next.map(function (m) {
            return m.id;
        }), ["b", "c"]);
        compare(list.length, 2, "input list is not mutated");
    }

    function test_appendMessage_withoutIdAlwaysAppends() {
        const list = [
            {
                message: "x"
            }
        ];
        compare(Feed.appendMessage(list, {
            message: "x"
        }, 10).length, 2);
    }

    function test_panelPosition_data() {
        const screen = Qt.rect(0, 0, 1920, 1080);
        return [
            {
                tag: "bottom panel, icon mid-screen",
                edge: "bottom",
                icon: Qt.rect(1000, 1050, 22, 22),
                panel: Qt.rect(0, 1040, 1920, 40),
                x: 1011 - 280,
                y: 1040 - 10 - 300
            },
            {
                tag: "bottom panel, icon at the right edge",
                edge: "bottom",
                icon: Qt.rect(1890, 1050, 22, 22),
                panel: Qt.rect(0, 1040, 1920, 40),
                x: 1920 - 10 - 560,
                y: 730
            },
            {
                tag: "top panel",
                edge: "top",
                icon: Qt.rect(1000, 8, 22, 22),
                panel: Qt.rect(0, 0, 1920, 40),
                x: 731,
                y: 50
            },
            {
                tag: "left panel",
                edge: "left",
                icon: Qt.rect(10, 500, 22, 22),
                panel: Qt.rect(0, 0, 44, 1080),
                x: 54,
                y: 361
            },
            {
                tag: "right panel, icon near the bottom",
                edge: "right",
                icon: Qt.rect(1886, 1040, 22, 22),
                panel: Qt.rect(1876, 0, 44, 1080),
                x: 1876 - 10 - 560,
                y: 1080 - 10 - 300
            },
            {
                tag: "no edge centres on screen",
                edge: "",
                icon: Qt.rect(0, 0, 0, 0),
                panel: Qt.rect(0, 0, 0, 0),
                x: 680,
                y: 390
            }
        ].map(function (d) {
            d.screen = screen;
            return d;
        });
    }

    function test_panelPosition(data) {
        const p = Feed.panelPosition(data.edge, data.icon, data.panel, data.screen, 560, 300, 10);
        compare(p.x, data.x, "x");
        compare(p.y, data.y, "y");
    }

    function test_stamp_data() {
        const now = new Date(2026, 8, 27, 9, 0).getTime();
        function at(y, mo, d, h, mi) {
            return new Date(y, mo, d, h, mi).getTime() / 1000;
        }
        return [
            {
                tag: "today",
                sec: at(2026, 8, 27, 8, 5),
                expected: "8:05 AM"
            },
            {
                tag: "yesterday",
                sec: at(2026, 8, 26, 17, 4),
                expected: "Yesterday, 5:04 PM"
            },
            {
                tag: "this week",
                sec: at(2026, 8, 22, 17, 4),
                expected: "Tue, 5:04 PM"
            },
            {
                tag: "this year",
                sec: at(2026, 8, 19, 17, 4),
                expected: "Sep 19, 5:04 PM"
            },
            {
                tag: "last year",
                sec: at(2025, 8, 19, 17, 4),
                expected: "Sep 19, 2025, 5:04 PM"
            },
            {
                tag: "missing",
                sec: undefined,
                expected: ""
            }
        ].map(function (d) {
            d.now = now;
            return d;
        });
    }

    function test_stamp(data) {
        compare(Feed.stamp(data.sec, data.now), data.expected);
    }

    function test_shellQuoteKeepsQuotesInsideOneWord() {
        compare(Feed.shellQuote("it's $(x)"), "'it'\\''s $(x)'");
        compare(Feed.shellQuote(""), "''");
    }

    function test_escapeMarkup() {
        compare(Feed.escapeMarkup("a < b & c > d"), "a &lt; b &amp; c &gt; d");
    }

    function test_notifyCommandQuotesEveryField() {
        const cmd = Feed.notifyCommand({
            title: "it's up",
            message: "<b>$(rm -rf ~)</b>",
            topic: "ops"
        }, 7);
        compare(cmd, "'notify-send' '--print-id' '--app-name=ntfy' '--expire-time=1000' '--hint=string:desktop-entry:io.github.clearcmos.ntfy' '--hint=boolean:suppress-sound:true' '--' 'it'\\''s up' '&lt;b&gt;$(rm -rf ~)&lt;/b&gt;' # 7");
    }

    function test_notifyCommandFallsBackToTheTopic() {
        verify(Feed.notifyCommand({
            topic: "ops"
        }, 1).indexOf("'--' 'ops' ''") > 0);
    }

    function test_notificationId_data() {
        return [
            {
                tag: "id",
                input: "42\n",
                expected: 42
            },
            {
                tag: "empty",
                input: "",
                expected: 0
            },
            {
                tag: "error text",
                input: "Cannot connect",
                expected: 0
            },
            {
                tag: "zero",
                input: "0",
                expected: 0
            }
        ];
    }

    function test_notificationId(data) {
        compare(Feed.notificationId(data.input), data.expected);
    }

    function test_closeCommand() {
        compare(Feed.closeCommand(42), "gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.CloseNotification 42");
    }
}
