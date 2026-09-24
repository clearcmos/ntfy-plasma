#!/usr/bin/env bash
# scripts/lint-qml.sh must reject a real unqualified access and accept KDE's
# i18n calls. A lint gate that passes everything is worse than none: the
# qmllint on Arch's PATH is Qt 5's and silently accepts broken files.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
lint="$REPO_ROOT/scripts/lint-qml.sh"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

if "$lint" tests/fixtures/lint/Unqualified.qml >/dev/null; then
    fail "lint-qml.sh accepted an unqualified access"
fi
"$lint" tests/fixtures/lint/I18nOnly.qml >/dev/null || fail "lint-qml.sh flagged i18n calls"
if QT_BIN=/nonexistent "$lint" tests/fixtures/lint/I18nOnly.qml >/dev/null 2>&1; then
    fail "lint-qml.sh passed without a qmllint to run"
fi

echo "test_lint_qml.sh: ok"
