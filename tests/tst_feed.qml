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
}
