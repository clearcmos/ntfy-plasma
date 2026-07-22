#!/usr/bin/env bash
# Symlink the plasmoid into ~/.local/share/plasma/plasmoids/ for live editing.
# Run again after edits if you want to bump kpackagetool6's mtime check, but
# usually a `plasmashell --replace` (or plasma-restart) is enough.
set -euo pipefail

REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PKG_ID="io.github.clearcmos.ntfy"
TARGET_DIR="$HOME/.local/share/plasma/plasmoids/$PKG_ID"

mkdir -p "$(dirname "$TARGET_DIR")"

if [[ -L "$TARGET_DIR" ]]; then
    echo "Replacing existing symlink at $TARGET_DIR"
    rm "$TARGET_DIR"
elif [[ -e "$TARGET_DIR" ]]; then
    echo "ERROR: $TARGET_DIR exists and is not a symlink. Move it aside first." >&2
    exit 1
fi

ln -s "$REPO_DIR/package" "$TARGET_DIR"
echo "Linked $TARGET_DIR -> $REPO_DIR/package"

echo
echo "Next:"
echo "  1) Right-click panel > Add Widgets > search 'ntfy Feed'"
echo "  2) Right-click the widget > Configure to set server URL and topics"
echo "  3) After QML edits, run: kquitapp6 plasmashell && kstart plasmashell"
