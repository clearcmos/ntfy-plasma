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

# For the optional "list alerts under the notification bell" setting. Plasma
# keeps a notification in its history only when it names an installed
# desktop entry, and popups are off for this one so the overlay stays the
# only thing on screen. A ShowPopups value already set is left alone.
APPS_DIR="${XDG_DATA_HOME:-$HOME/.local/share}/applications"
mkdir -p "$APPS_DIR"
cat >"$APPS_DIR/$PKG_ID.desktop" <<DESKTOP
[Desktop Entry]
Type=Application
Name=ntfy
Comment=Alerts from the ntfy Feed widget
Exec=true
Icon=network-wireless
NoDisplay=true
DESKTOP
echo "Wrote $APPS_DIR/$PKG_ID.desktop"
command -v kbuildsycoca6 >/dev/null && kbuildsycoca6 >/dev/null 2>&1 || true
if command -v kwriteconfig6 >/dev/null; then
    if [[ -z "$(kreadconfig6 --file plasmanotifyrc --group Applications --group "$PKG_ID" --key ShowPopups)" ]]; then
        kwriteconfig6 --file plasmanotifyrc --group Applications --group "$PKG_ID" --key ShowPopups --type bool --notify false
        echo "Turned off Plasma popups for the widget's own alerts only (used by the optional bell listing; other apps are unaffected)"
    fi
else
    echo "kwriteconfig6 not found: turn off popups for ntfy in System Settings > Notifications yourself"
fi

echo
echo "Next:"
echo "  1) Right-click panel > Add Widgets > search 'ntfy Feed'"
echo "  2) Right-click the widget > Configure to set server URL and topics"
echo "  3) After QML edits, run: kquitapp6 plasmashell && kstart plasmashell"
