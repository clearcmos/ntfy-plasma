import QtQuick
import QtTest
import "../package/contents/ui/Emoji.js" as Emoji

TestCase {
    name: "Emoji"

    function test_lookup_data() {
        return [
            {
                tag: "known shortcode",
                name: "warning",
                expected: String.fromCodePoint(0x26a0, 0xfe0f)
            },
            {
                tag: "case and whitespace",
                name: " Tada ",
                expected: String.fromCodePoint(0x1f389)
            },
            {
                tag: "unknown",
                name: "no_such_shortcode",
                expected: ""
            },
            {
                tag: "empty",
                name: "",
                expected: ""
            },
            {
                tag: "inherited object key",
                name: "constructor",
                expected: ""
            }
        ];
    }

    function test_lookup(data) {
        compare(Emoji.lookup(data.name), data.expected);
    }

    function test_renderTags_mapsKnownAndPrefixesUnknown() {
        compare(Emoji.renderTags(["+1", "backup"]), String.fromCodePoint(0x1f44d) + " #backup");
    }

    function test_renderTags_empty() {
        compare(Emoji.renderTags([]), "");
        compare(Emoji.renderTags(undefined), "");
    }
}
