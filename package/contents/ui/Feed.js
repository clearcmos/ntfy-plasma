// Pure helpers behind the client and the feed. No QML types, so the tests in
// tests/tst_feed.qml exercise them directly.
.pragma library

// Split a comma-separated topic string into trimmed, non-empty names.
function parseTopics(s) {
    return String(s || "").split(",").map(function (t) {
        return t.trim();
    }).filter(function (t) {
        return t.length > 0;
    });
}

// Build the JSON-stream URL, or "" when the server or topics are missing.
// Users routinely paste the server URL with a trailing space or `/`, which
// silently breaks the XHR, so both are stripped.
function streamUrl(serverUrl, topics, since) {
    const t = parseTopics(topics).join(",");
    const s = String(serverUrl || "").trim().replace(/\/+$/, "");
    if (!s || !t)
        return "";
    const sinceRaw = String(since || "").trim();
    // /json streams JSON Lines; ?since=<dur> backfills history first
    return s + "/" + t + "/json?since=" + encodeURIComponent(sinceRaw.length ? sinceRaw : "0");
}

// Return the complete lines in text from offset `from`, plus the offset just
// past the last newline. A trailing partial line stays unconsumed until the
// read that completes it arrives.
function completeLines(text, from) {
    const end = text.lastIndexOf("\n");
    if (end < from)
        return { lines: [], next: from };
    return { lines: text.substring(from, end).split("\n"), next: end + 1 };
}

// Top-left of a width x height card beside its panel icon: centred on the
// icon along the panel, `gap` off the panel's inner edge, and kept `gap`
// inside the screen. edge is the panel's screen edge: "top", "bottom",
// "left" or "right"; anything else centres the card on the screen.
function panelPosition(edge, icon, panel, screen, width, height, gap) {
    function clamp(v, lo, hi) {
        return Math.max(lo, Math.min(v, hi));
    }
    const x = clamp(Math.round(icon.x + icon.width / 2 - width / 2), screen.x + gap, screen.x + screen.width - gap - width);
    const y = clamp(Math.round(icon.y + icon.height / 2 - height / 2), screen.y + gap, screen.y + screen.height - gap - height);
    switch (edge) {
    case "top":
        return { x: x, y: panel.y + panel.height + gap };
    case "bottom":
        return { x: x, y: panel.y - gap - height };
    case "left":
        return { x: panel.x + panel.width + gap, y: y };
    case "right":
        return { x: panel.x - gap - width, y: y };
    default:
        return { x: screen.x + Math.round((screen.width - width) / 2), y: screen.y + Math.round((screen.height - height) / 2) };
    }
}

// Append msg to a copy of list, dropping the oldest entries beyond max.
// Returns null when a message with the same id is already present: ntfy
// assigns a unique id per message, and reconnects backfill history the feed
// has already shown.
function appendMessage(list, msg, max) {
    if (msg.id) {
        for (let i = 0; i < list.length; i++) {
            if (list[i].id === msg.id)
                return null;
        }
    }
    const next = list.slice();
    next.push(msg);
    while (next.length > max)
        next.shift();
    return next;
}

// When a message arrived, from ntfy's unix-seconds `time`, relative to
// nowMs: the clock time today, then "Yesterday", the weekday within a week,
// the date, and the year once it differs. "" when the time is missing.
function stamp(sec, nowMs) {
    if (!sec)
        return "";
    const t = new Date(sec * 1000);
    const now = new Date(nowMs);
    const clock = Qt.formatTime(t, "h:mm AP");
    // Calendar days, rounded so a DST shift does not skew the count.
    const days = Math.round((new Date(now.getFullYear(), now.getMonth(), now.getDate()) - new Date(t.getFullYear(), t.getMonth(), t.getDate())) / 86400000);
    if (days === 0)
        return clock;
    if (days === 1)
        return "Yesterday, " + clock;
    if (days > 1 && days < 7)
        return Qt.formatDate(t, "ddd") + ", " + clock;
    if (t.getFullYear() === now.getFullYear())
        return Qt.formatDate(t, "MMM d") + ", " + clock;
    return Qt.formatDate(t, "MMM d, yyyy") + ", " + clock;
}

// The desktop entry install.sh deploys. Plasma keeps a notification in its
// history only when the notification names an installed desktop entry.
const desktopEntry = "io.github.clearcmos.ntfy";

// Quote s as one POSIX shell word.
function shellQuote(s) {
    return "'" + String(s).replace(/'/g, "'\\''") + "'";
}

// Plasma renders notification bodies as markup, so a message's own <, >
// and & must arrive as text.
function escapeMarkup(s) {
    return String(s).replace(/&/g, "&amp;").replace(/</g, "&lt;").replace(/>/g, "&gt;");
}

// The notify-send command that lists msg under Plasma's notification bell.
// Popups are off for the desktop entry (install.sh), so the only thing that
// marks the entry unread is the server's own expiry timer, which Plasma arms
// for 60 s plus the timeout given here. `seq` makes each command string
// unique, because the executable engine keys running commands by their text.
function notifyCommand(msg, seq) {
    const args = ["notify-send", "--print-id", "--app-name=ntfy", "--expire-time=1000", "--hint=string:desktop-entry:" + desktopEntry, "--hint=boolean:suppress-sound:true", "--", msg.title || msg.topic || "ntfy", escapeMarkup(msg.message || "")];
    return args.map(shellQuote).join(" ") + " # " + seq;
}

// The command that plays the chime at `fileUrl` (a file:// URL). `seq` makes
// each command string unique, because the executable engine keys running
// commands by their text. Oxygen "power-plug" chime (outcome-success.ogg from
// oxygen-sounds, LGPL-3.0-or-later, see ../sounds/power-plug.wav.license).
function chimeCommand(fileUrl, seq) {
    const path = decodeURIComponent(String(fileUrl).replace(/^file:\/\//, ""));
    return "pw-play " + shellQuote(path) + " # " + seq;
}

// The notification id notify-send --print-id wrote, or 0.
function notificationId(stdout) {
    const s = String(stdout || "").trim();
    return /^[1-9][0-9]*$/.test(s) ? Number(s) : 0;
}

// The command that removes notification `id` from Plasma's history. Closed
// by the app that sent it, Plasma drops a notification instead of keeping it.
function closeCommand(id) {
    return "gdbus call --session --dest org.freedesktop.Notifications --object-path /org/freedesktop/Notifications --method org.freedesktop.Notifications.CloseNotification " + Number(id);
}
