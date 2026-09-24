// Subscribes to one or more ntfy topics over the /json streaming endpoint.
// Each line is a JSON object with the message envelope. Backfills via the
// `since` query param when (re)connecting, then keeps the connection open.
// Reconnects with capped exponential backoff on any error/close.
import QtQuick
import "Feed.js" as Feed

Item {
    id: root

    property string serverUrl: ""
    property string topics: ""
    property string historySince: "1h"

    signal messageReceived(var msg)
    signal openChanged(bool open)

    property var _xhr: null
    // Offset into the current response just past the last consumed newline.
    property int _consumed: 0
    property int _backoffMs: 1000
    readonly property int _backoffMaxMs: 30000

    Timer {
        id: reconnectTimer
        repeat: false
        onTriggered: root._connect()
    }

    function start() {
        stop();
        _connect();
    }

    function stop() {
        reconnectTimer.stop();
        if (_xhr) {
            try {
                _xhr.abort();
            } catch (e) {}
            _xhr = null;
        }
        _consumed = 0;
        openChanged(false);
    }

    function restart() {
        stop();
        _backoffMs = 1000;
        _connect();
    }

    function _connect() {
        const url = Feed.streamUrl(serverUrl, topics, historySince);
        if (!url)
            return;
        const xhr = new XMLHttpRequest();
        _xhr = xhr;
        _consumed = 0;

        xhr.open("GET", url);
        xhr.responseType = "text";

        xhr.onreadystatechange = function () {
            // stale request, ignore
            if (xhr !== root._xhr)
                return;
            if (xhr.readyState === XMLHttpRequest.HEADERS_RECEIVED) {
                if (xhr.status >= 200 && xhr.status < 300) {
                    root._backoffMs = 1000;
                    root.openChanged(true);
                }
            } else if (xhr.readyState === XMLHttpRequest.LOADING) {
                root._drainBuffer(xhr.responseText);
            } else if (xhr.readyState === XMLHttpRequest.DONE) {
                root._drainBuffer(xhr.responseText);
                root.openChanged(false);
                root._scheduleReconnect();
            }
        };

        try {
            xhr.send();
        } catch (e) {
            root._scheduleReconnect();
        }
    }

    function _drainBuffer(full) {
        // responseText is the cumulative response. Only complete lines are
        // consumed, so a line split across two reads waits for its newline
        // instead of failing to parse in both halves.
        const chunk = Feed.completeLines(full, _consumed);
        _consumed = chunk.next;

        for (let i = 0; i < chunk.lines.length; i++) {
            const line = chunk.lines[i].trim();
            if (!line)
                continue;
            let obj;
            try {
                obj = JSON.parse(line);
            } catch (e) {
                // Not ntfy output (an HTML error page from a proxy, say);
                // skip it rather than spam the log on every reconnect.
                continue;
            }
            // "open" and "keepalive" events only keep the connection alive;
            // HEADERS_RECEIVED already drives openChanged.
            if (obj && obj.event === "message") {
                messageReceived(obj);
            }
        }
    }

    function _scheduleReconnect() {
        // explicit stop, don't retry
        if (_xhr === null)
            return;
        _xhr = null;
        const delay = _backoffMs;
        _backoffMs = Math.min(_backoffMs * 2, _backoffMaxMs);
        reconnectTimer.interval = delay;
        reconnectTimer.start();
    }

    Component.onDestruction: stop()
}
