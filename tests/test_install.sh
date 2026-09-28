#!/usr/bin/env bash
# install.sh links the package into the plasmoid dir, replaces a previous
# link, and refuses to clobber a real directory.
set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
# kwriteconfig6 and kbuildsycoca6 follow XDG paths before HOME; keep them in tmp.
export XDG_CONFIG_HOME="$tmp/.config" XDG_DATA_HOME="$tmp/.local/share" XDG_CACHE_HOME="$tmp/.cache"
target="$tmp/.local/share/plasma/plasmoids/io.github.clearcmos.ntfy"

fail() {
    echo "FAIL: $*" >&2
    exit 1
}

HOME="$tmp" "$REPO_ROOT/install.sh" >/dev/null
[[ -L "$target" && "$(readlink "$target")" == "$REPO_ROOT/package" ]] || fail "first install did not link the package"

desktop="$tmp/.local/share/applications/io.github.clearcmos.ntfy.desktop"
grep -qx 'NoDisplay=true' "$desktop" || fail "install did not write the desktop entry"
if command -v kwriteconfig6 >/dev/null; then
    rc="$tmp/.config/plasmanotifyrc"
    grep -qx 'ShowPopups=false' "$rc" || fail "install did not turn off popups"
    # A choice already made in System Settings survives a reinstall.
    sed -i 's/^ShowPopups=false$/ShowPopups=true/' "$rc"
    HOME="$tmp" "$REPO_ROOT/install.sh" >/dev/null
    grep -qx 'ShowPopups=true' "$rc" || fail "reinstall overwrote an existing ShowPopups"
fi

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
