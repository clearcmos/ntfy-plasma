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

    function test_loadSelectsClosestPreset_data() {
        return [
            {
                tag: "exact default",
                scale: 1.0,
                index: 1
            },
            {
                tag: "hand-edited between presets",
                scale: 1.28,
                index: 3
            },
            {
                tag: "config minimum",
                scale: 0.7,
                index: 0
            },
            {
                tag: "config maximum",
                scale: 1.6,
                index: 4
            }
        ];
    }

    function test_loadSelectsClosestPreset(data) {
        const page = createTemporaryObject(configComponent, tc, {
            cfg_textScale: data.scale
        });
        compare(findChild(page, "textScaleCombo").currentIndex, data.index);
    }

    function test_choosingPresetWritesScale() {
        const page = createTemporaryObject(configComponent, tc, {
            cfg_textScale: 1.0
        });
        const combo = findChild(page, "textScaleCombo");
        combo.currentIndex = 4;
        combo.activated(4);
        compare(page.cfg_textScale, 1.5);
    }
}
