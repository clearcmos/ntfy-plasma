#!/usr/bin/env bash
# install.sh links the package into the plasmoid dir, replaces a previous
# link, and refuses to clobber a real directory.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
target="$tmp/.local/share/plasma/plasmoids/io.github.clearcmos.ntfy"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

HOME="$tmp" "$REPO_ROOT/install.sh" >/dev/null
[[ -L "$target" && "$(readlink "$target")" == "$REPO_ROOT/package" ]] || fail "first install did not link the package"

ln -sfn /nonexistent "$target"
HOME="$tmp" "$REPO_ROOT/install.sh" >/dev/null
[[ "$(readlink "$target")" == "$REPO_ROOT/package" ]] || fail "reinstall did not replace the old link"

rm "$target"
mkdir "$target"
if HOME="$tmp" "$REPO_ROOT/install.sh" >/dev/null 2>&1; then
    fail "install.sh replaced a real directory"
fi
[[ -d "$target" && ! -L "$target" ]] || fail "the real directory was modified"

echo "test_install.sh: ok"
