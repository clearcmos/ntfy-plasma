# ntfy-plasma

KDE Plasma 6 widget for ntfy.sh: live notification feed in your panel.

## Features

- Subscribe to one or more ntfy topics, see new messages live in a feed panel that opens beside the panel icon, drawn in the Basalt style (see below). The newest message sits nearest the icon: at the bottom on a bottom panel, with older ones scrolling off the top
- Backfills history on connect/reconnect (`?since=...`)
- Messages published while the widget is running also appear as an overlay at the top centre of the panel's screen, one card per message, until each is clicked. Up to five cards show at once; older ones wait off screen and come back as you dismiss the newer ones. Each new card plays a short chime, and a glow pulses around the screen edges until the last card is dismissed
- Optional: the same live messages also listed under Plasma's notification bell (see below)
- Auto-reconnect with capped exponential backoff
- Compact panel icon with unread badge and disconnect indicator; middle-click it to mark everything read
- High and max priority messages get an accent outline
- Click a message to dismiss it, right-click to copy it; middle-click opens its `Click:` URL in the browser
- Keyboard on the feed panel: arrows select a row, Enter copies it, `r` reconnects, `c` clears, Esc closes. Reconnect and Clear Feed are also in the icon's right-click menu
- Markdown bodies and emoji tag shortcodes (optional)
- No account or auth required for public ntfy.sh; self-hosted servers also supported

## Install

Clone the repo, then:

```bash
./install.sh
kquitapp6 plasmashell && kstart plasmashell
```

Right-click your panel, Add Widgets, search "ntfy Feed". The first time you add it, the feed panel asks for configuration - press Enter there, or right-click the icon and choose Configure, to set:

| Field | Example |
|-----|---------|
| Server URL | `https://ntfy.sh` |
| Topics | `my-alerts,backups` (comma-separated) |
| Backfill on reconnect | `1h` (ntfy duration syntax) |
| Keep last | `100` messages in the in-memory feed |
| Also list alerts under the notification bell | off by default; see below |

For private notifications, self-host ntfy ([docs.ntfy.sh](https://docs.ntfy.sh)) and point the widget at it.

> **Public ntfy.sh:** anyone who knows your topic name can read it. Use something hard to guess.

## Plasma notification bell (optional)

The widget works on its own: its feed panel and overlay need nothing from Plasma's notification system, and with this setting off it sends nothing there. The setting adds a copy; it never replaces the widget's own display. Turning on "Also list alerts under the notification bell" in the settings adds each live message to Plasma's notification history as well:

- No popup and no sound of its own; the overlay card is still the only thing on screen
- The bell turns to its unread icon about a minute after the message arrives. Plasma marks a notification with popups off as unread only when its own expiry timer runs out, which it sets to 60 s plus the notification's timeout
- Dismissing the overlay card removes the entry from the bell. Clearing it from the bell does not dismiss the card, and dismissing a row in the feed panel does not touch the bell

It needs what `install.sh` sets up: a hidden desktop entry, `~/.local/share/applications/io.github.clearcmos.ntfy.desktop` (Plasma drops a notification from its history when it names no installed desktop entry), and popups turned off for it in `~/.config/plasmanotifyrc`. A popup setting already chosen in System Settings > Notifications is left alone. The commands run through Plasma5Support's executable engine: `notify-send` to post, `gdbus` to close.

## Layout

```
package/
  metadata.json
  contents/
    ui/
      main.qml                  PlasmoidItem root and panel icon
      NtfyClient.qml            XHR-based JSON Lines streamer w/ reconnect
      Feed.js                   URL building, line splitting, feed dedupe, timestamps
      FeedPanel.qml             feed panel beside the icon
      MessageDelegate.qml       single-message row
      OverlayPopup.qml          top-centre cards for live messages
      EdgeFlash.qml             screen-edge glow while cards are unread
      Emoji.js                  ntfy tag shortcodes (generated)
      KdeMirror.qml             optional copies under Plasma's notification bell
      ConfigGeneral.qml         settings page
    config/
      main.xml                  KConfig schema
      config.qml                ConfigModel
    icons/
      ntfy-tower.svg            radar tower mark (currentColor)
    sounds/
      power-plug.wav            overlay chime (LGPL-3.0-or-later, see below)
scripts/
  lint-qml.sh                   qmllint gate used by `make lint`
  regen-emoji.sh                regenerates Emoji.js from ntfy upstream
tests/                          qmltestrunner suite, fake ntfy server, shell tests
```

## Look

The feed panel, the message cards, and the edge glow follow Basalt, a fixed dark style with the Hack font and one blue accent. Colors and text sizes are fixed and do not follow the KDE color scheme.

## Dependencies

- KDE Plasma 6.0+
- Kirigami, libplasma, plasma5support, qt6-declarative, qt6-multimedia (already on a typical Plasma 6 system)
- For the optional notification bell listing: `notify-send` (libnotify) and `gdbus` (glib2)
- The Hack font (`ttf-hack` on Arch); without it the text falls back to a wider font and overflows the cards
- Network access to your ntfy server from the desktop

No native code. With the notification bell listing off, no D-Bus and no shell calls.

## Development

Needs the runtime dependencies above plus `jq`, `python3`, `shellcheck`, and `actionlint`. The Qt 6 tools are expected in `/usr/lib/qt6/bin`; override with `QT_BIN=...` elsewhere.

```bash
make check          # everything CI runs
make lint           # qmllint, shellcheck, bash -n, actionlint
make format         # qmlformat in place
make format-check   # fail on unformatted QML
make test           # QML tests (headless) and shell tests
```

The tests run headless under `qmltestrunner` and stream from a local fake ntfy server on port 38417. CI runs `make check` in an Arch container on every push and pull request.

## Status

Early. Single user, single ntfy instance tested. Known gaps:

- No bearer-token auth header (yet) - public/anonymous topics only
- Messages live in memory; panel restart empties the list (history backfills via `?since=` on reconnect). Dismissed or cleared messages inside that backfill window come back after a reconnect or restart

## License

MIT, except `package/contents/sounds/power-plug.wav`, the Oxygen sound theme's `outcome-success` sound by Nuno Filipe Povoa, which is LGPL-3.0-or-later. Its notice and license text sit next to it in `package/contents/sounds/`.
