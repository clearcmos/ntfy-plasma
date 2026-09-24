#!/usr/bin/env bash
# Lint every QML and JS file with the Qt 6 qmllint and fail on any warning,
# except unqualified calls to KDE's i18n functions: Plasma injects those
# through the applet's localized context, which qmllint cannot see.
set -euo pipefail

QT_BIN="${QT_BIN:-/usr/lib/qt6/bin}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

report="$(mktemp -t qmllint.XXXXXX.json)"
trap 'rm -f "$report"' EXIT

# With arguments, lint just those files (tests/test_lint_qml.sh uses this).
if (($#)); then
    files=("$@")
else
    mapfile -t files < <(find package tests -path tests/fixtures -prune -o \( -name '*.qml' -o -name '*.js' \) -print | sort)
fi

failed=0
for f in "${files[@]}"; do
    # qmllint's exit code only reflects its own thresholds; the JSON report
    # below is the verdict. Removing it first makes a qmllint that never ran
    # fail the jq read instead of re-reading the previous file's report.
    rm -f "$report"
    "$QT_BIN/qmllint" --json "$report" "$f" >/dev/null 2>&1 || true
    # charOffset counts UTF-16 units and jq slices by codepoint; the two
    # agree while QML sources stay free of characters outside the BMP.
    findings="$(jq -r --rawfile src "$f" --arg f "$f" '
        .files[].warnings[]
        | select(.type != "info")
        | select((.id == "unqualified" and .charOffset != null
                  and ($src[.charOffset:(.charOffset + .length)] | test("^i18n(c|p|cp)?$"))) | not)
        | "\($f):\(.line // 0):\(.column // 0): \(.message) [\(.id // "unknown")]"
    ' "$report")"
    if [[ -n "$findings" ]]; then
        printf '%s\n' "$findings"
        failed=1
    fi
done

exit "$failed"
