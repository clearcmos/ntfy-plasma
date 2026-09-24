import QtQuick

// Known-clean input for tests/test_lint_qml.sh: KDE's context-injected i18n
// calls are the one unqualified access the lint gate allows.
Item {
    property string a: i18n("Text")
    property string b: i18np("%1 item", "%1 items", 2)
    property string c: i18nc("context", "Text")
    property string d: i18ncp("context", "%1 item", "%1 items", 2)
}
