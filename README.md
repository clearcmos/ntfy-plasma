# ntfy-plasma

KDE Plasma 6 widget for ntfy.sh: live notification feed in your panel.

## Features

- Subscribe to one or more ntfy topics, see new messages live in a panel popup
- Backfills history on connect/reconnect (`?since=...`)
- Messages published while the widget is running also appear as an overlay at the top centre of the panel's screen, one card per message, until each is clicked. Up to five cards show at once; a sixth drops the oldest. Each new card plays a short chime, and a glow pulses around the screen edges until the last card is dismissed
- Auto-reconnect with capped exponential backoff
- Compact panel icon with unread badge and disconnect indicator; middle-click it to mark everything read
- Priority-coloured left border per message (info / warning / error)
- Click a message to copy it; middle-click opens its `Click:` URL in the browser
- Markdown bodies and emoji tag shortcodes (optional)
- No account or auth required for public ntfy.sh; self-hosted servers also supported

## Install

Clone the repo, then:

```bash
./install.sh
kquitapp6 plasmashell && kstart plasmashell
```

Right-click your panel, Add Widgets, search "ntfy Feed". The first time you add it, a "Configure" button appears in the popup - click it to set:

| Field | Example |
|-----|---------|
| Server URL | `https://ntfy.sh` |
| Topics | `my-alerts,backups` (comma-separated) |
| Backfill on reconnect | `1h` (ntfy duration syntax) |
| Keep last | `100` messages in the in-memory feed |

For private notifications, self-host ntfy ([docs.ntfy.sh](https://docs.ntfy.sh)) and point the widget at it.

> **Public ntfy.sh:** anyone who knows your topic name can read it. Use something hard to guess.

## Layout

```
package/
  metadata.json
  contents/
    ui/
      main.qml                  PlasmoidItem root, both representations
      NtfyClient.qml            XHR-based JSON Lines streamer w/ reconnect
      Feed.js                   URL building, line splitting, feed dedupe
      MessageDelegate.qml       single-message row
      OverlayPopup.qml          top-centre cards for live messages
      EdgeFlash.qml             screen-edge glow while cards are unread
      Emoji.js                  ntfy tag shortcodes (generated)
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

## Dependencies

- KDE Plasma 6.0+
- Kirigami, libplasma, qt6-declarative, qt6-multimedia (already on a typical Plasma 6 system)
- Network access to your ntfy server from the desktop

No native code, no D-Bus, no shell calls.

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
- No desktop notifications via `org.freedesktop.Notifications`; live messages use the widget's own overlay
- Messages live in memory; panel restart empties the list (history backfills via `?since=` on reconnect)

## License

MIT, except `package/contents/sounds/power-plug.wav`, the Oxygen sound theme's `outcome-success` sound by Nuno Filipe Povoa, which is LGPL-3.0-or-later. Its notice and license text sit next to it in `package/contents/sounds/`.
