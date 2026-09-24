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
