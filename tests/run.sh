#!/usr/bin/env bash
# Run the whole suite: the per-module test presence check, the QML tests
# (against tests/fake_ntfy.py on 127.0.0.1:38417), and the shell tests.
set -euo pipefail

QT_BIN="${QT_BIN:-/usr/lib/qt6/bin}"
PORT=38417  # also set in tests/tst_ntfyclient_live.qml
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$REPO_ROOT"

# Every module needs its own test file. Exempt, with the reason:
#   main.qml        PlasmoidItem only loads inside plasmashell; its logic
#                   lives in Feed.js, which is tested.
#   regen-emoji.sh  fetches from GitHub; its output is reviewed as a diff
#                   and exercised by tst_emoji.qml.
missing=0
for f in package/contents/ui/*.qml package/contents/ui/*.js; do
    name="$(basename "$f")"
    name="${name%.*}"
    [[ "$name" == main ]] && continue
    if ! compgen -G "tests/tst_${name,,}*.qml" >/dev/null; then
        echo "no test for $f (expected tests/tst_${name,,}.qml)" >&2
        missing=1
    fi
done
for f in install.sh scripts/*.sh; do
    name="$(basename "$f" .sh)"
    [[ "$name" == regen-emoji ]] && continue
    if [[ ! -f "tests/test_${name//-/_}.sh" ]]; then
        echo "no test for $f (expected tests/test_${name//-/_}.sh)" >&2
        missing=1
    fi
done
((missing == 0)) || exit 1

python3 tests/fake_ntfy.py --port "$PORT" &
server=$!
trap 'kill "$server" 2>/dev/null || true' EXIT
for _ in $(seq 50); do
    (echo >"/dev/tcp/127.0.0.1/$PORT") 2>/dev/null && break
    sleep 0.1
done

QT_QPA_PLATFORM="${QT_QPA_PLATFORM:-offscreen}" "$QT_BIN/qmltestrunner" -input tests
bash tests/test_install.sh
bash tests/test_lint_qml.sh
