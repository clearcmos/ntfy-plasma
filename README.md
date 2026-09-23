# ntfy-plasma

KDE Plasma 6 widget for ntfy.sh: live notification feed in your panel.

## Features

- Subscribe to one or more ntfy topics, see new messages live in a panel popup
- Backfills history on connect/reconnect (`?since=...`)
- Messages published while the widget is running also appear as an overlay at the top centre of the panel's screen, one card per message, until each is clicked
- Auto-reconnect with capped exponential backoff
- Compact panel icon with unread badge and disconnect indicator
- Priority-coloured left border per message (info / warning / error)
- Click-action support: messages with a `Click:` URL open in the browser
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
      MessageDelegate.qml       single-message row
      ConfigGeneral.qml         settings page
    config/
      main.xml                  KConfig schema
      config.qml                ConfigModel
    icons/
      ntfy-tower.svg            radar tower mark (currentColor)
```

## Dependencies

- KDE Plasma 6.0+
- Kirigami, plasma-framework, qt6-declarative (already on any Plasma 6 system)
- Network access to your ntfy server from the desktop

No native code, no D-Bus, no shell calls.

## Status

Early. Single user, single ntfy instance tested. Known gaps:

- No bearer-token auth header (yet) - public/anonymous topics only
- No desktop notifications via `org.freedesktop.Notifications` - the widget shows the feed; mobile push / sound is the ntfy app's job
- Messages live in memory; panel restart empties the list (history backfills via `?since=` on reconnect)

## License

MIT
