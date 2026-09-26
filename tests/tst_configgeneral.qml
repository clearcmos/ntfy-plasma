import QtQuick
import QtTest
import "../package/contents/ui"

TestCase {
    id: tc
    name: "ConfigGeneral"

    // Plasma provides i18n through the applet's context; stand in for it.
    function i18n(s) {
        return s;
    }

    Component {
        id: configComponent
        ConfigGeneral {}
    }

    function init() {
        failOnWarning(/\.qml:\d+/);
    }

    function test_loadsAndWritesBackEveryKey() {
        const page = createTemporaryObject(configComponent, tc, {
            cfg_serverUrl: "https://ntfy.sh",
            cfg_topics: "a,b",
            cfg_maxMessages: 50,
            cfg_historySince: "12h",
            cfg_showDividers: false,
            cfg_renderMarkdown: false
        });
        compare(page.cfg_serverUrl, "https://ntfy.sh");
        compare(page.cfg_topics, "a,b");
        compare(page.cfg_maxMessages, 50);
        compare(page.cfg_historySince, "12h");
        compare(page.cfg_showDividers, false);
        compare(page.cfg_renderMarkdown, false);
    }
}
