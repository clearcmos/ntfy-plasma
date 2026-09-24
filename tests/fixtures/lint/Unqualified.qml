import QtQuick

// Known-bad input for tests/test_lint_qml.sh: the lint gate must reject it.
Item {
    property int value: notDefinedAnywhere
}
