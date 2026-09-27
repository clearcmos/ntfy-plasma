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

// Date and time a message arrived, from ntfy's unix-seconds `time`, or ""
// when it is missing. The feed holds backfill from past days, so a bare
// clock time cannot say when a row came in.
function stamp(sec) {
    if (!sec)
        return "";
    return Qt.formatDateTime(new Date(sec * 1000), "ddd MMM d, h:mm AP");
}
