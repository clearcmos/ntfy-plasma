// Subscribes to one or more ntfy topics over the /json streaming endpoint.
// Each line is a JSON object with the message envelope. Backfills via the
// `since` query param when (re)connecting, then keeps the connection open.
// Reconnects with capped exponential backoff on any error/close.
import QtQuick

Item {
    id: root

    property string serverUrl: ""
    property string topics: ""
    property string historySince: "1h"

    signal messageReceived(var msg)
    signal openChanged(bool open)

    property var _xhr: null
    property string _buffer: ""
    property int _backoffMs: 1000
    readonly property int _backoffMaxMs: 30000

    Timer {
        id: reconnectTimer
        repeat: false
        onTriggered: root._connect()
    }

    function start() {
        stop()
        _connect()
    }

    function stop() {
        reconnectTimer.stop()
        if (_xhr) {
            try { _xhr.abort() } catch (e) {}
            _xhr = null
        }
        _buffer = ""
        openChanged(false)
    }

    function restart() {
        stop()
        _backoffMs = 1000
        _connect()
    }

    function _topicsClean() {
        return topics.split(",").map(function(t) { return t.trim() })
                     .filter(function(t) { return t.length > 0 }).join(",")
    }

    function _url() {
        const t = _topicsClean()
        // Trim and strip trailing slashes from the server URL. Users routinely
        // paste with a trailing space or `/`, which silently breaks the XHR.
        const s = (serverUrl || "").trim().replace(/\/+$/, "")
        if (!s || !t) return ""
        const sinceRaw = (historySince || "").trim()
        const since = sinceRaw.length ? sinceRaw : "0"
        // /json streams JSON Lines; ?since=<dur> backfills history first
        return s + "/" + t + "/json?since=" + encodeURIComponent(since)
    }

    function _connect() {
        const url = _url()
        if (!url) return

        const xhr = new XMLHttpRequest()
        _xhr = xhr
        _buffer = ""

        xhr.open("GET", url)
        xhr.responseType = "text"

        xhr.onreadystatechange = function() {
            if (xhr !== root._xhr) return  // stale request, ignore

            if (xhr.readyState === XMLHttpRequest.HEADERS_RECEIVED) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    root._backoffMs = 1000
                    root.openChanged(true)
                }
            } else if (xhr.readyState === XMLHttpRequest.LOADING) {
                root._drainBuffer(xhr.responseText)
            } else if (xhr.readyState === XMLHttpRequest.DONE) {
                root._drainBuffer(xhr.responseText)
                root.openChanged(false)
                root._scheduleReconnect()
            }
        }

        try {
            xhr.send()
        } catch (e) {
            root._scheduleReconnect()
        }
    }

    function _drainBuffer(full) {
        // responseText is the cumulative response. Slice off what we've
        // already seen and split on newlines.
        if (full.length <= _buffer.length) return
        const chunk = full.substring(_buffer.length)
        _buffer = full

        const lines = chunk.split("\n")
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i].trim()
            if (!line) continue
            try {
                const obj = JSON.parse(line)
                if (obj && obj.event === "message") {
                    messageReceived(obj)
                }
                // ignore "open" / "keepalive" events, they just keep the
                // connection alive; presence already drives openChanged.
            } catch (e) {
                // partial line at the end of chunk -- ntfy sends complete
                // JSON per line, so this is rare; swallow rather than spam.
            }
        }
    }

    function _scheduleReconnect() {
        if (_xhr === null) return  // explicit stop, don't retry
        _xhr = null
        const delay = _backoffMs
        _backoffMs = Math.min(_backoffMs * 2, _backoffMaxMs)
        reconnectTimer.interval = delay
        reconnectTimer.start()
    }

    Component.onDestruction: stop()
}
