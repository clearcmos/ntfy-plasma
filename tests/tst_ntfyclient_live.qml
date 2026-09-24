import QtQuick
import QtTest
import "../package/contents/ui"

// Drives the real XHR streaming path against tests/fake_ntfy.py, which
// tests/run.sh starts on this port before the suite runs.
TestCase {
    id: tc
    name: "NtfyClientLive"

    NtfyClient {
        id: client
        // Trailing slash and padded topics: the fake server 404s unless the
        // client normalizes them into /alpha,beta/json?since=1h.
        serverUrl: "http://127.0.0.1:38417/"
        topics: " alpha , beta "
        historySince: "1h"
    }

    SignalSpy {
        id: received
        target: client
        signalName: "messageReceived"
    }

    SignalSpy {
        id: openState
        target: client
        signalName: "openChanged"
    }

    function opens() {
        return openState.signalArguments.filter(function (a) {
            return a[0];
        }).length;
    }

    function cleanup() {
        client.stop();
    }

    function test_streamsSplitLinesAndReconnects() {
        failOnWarning(/\.qml:\d+/);
        client.start();
        tryCompare(received, "count", 2, 5000);
        compare(received.signalArguments[0][0].message, "split across reads");
        compare(received.signalArguments[1][0].id, "m2");
        verify(opens() >= 1, "openChanged(true) on the 2xx headers");
        // The server closes the stream after two messages; the client must
        // come back on its own after the one-second backoff.
        tryVerify(function () {
            return tc.opens() >= 2;
        }, 5000, "reconnected after the server closed the stream");
    }
}
