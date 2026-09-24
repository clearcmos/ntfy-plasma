import QtQuick
import QtTest
import "../package/contents/ui"

TestCase {
    id: tc
    name: "NtfyClient"

    Component {
        id: clientComponent
        NtfyClient {}
    }

    SignalSpy {
        id: received
        signalName: "messageReceived"
    }

    function init() {
        failOnWarning(/\.qml:\d+/);
    }

    function makeClient() {
        const c = createTemporaryObject(clientComponent, tc);
        received.clear();
        received.target = c;
        return c;
    }

    function line(obj) {
        return JSON.stringify(obj) + "\n";
    }

    function test_emitsOnlyMessageEvents() {
        const c = makeClient();
        c._drainBuffer(line({
            event: "open"
        }) + line({
            event: "keepalive"
        }) + line({
            id: "m1",
            event: "message",
            message: "hi"
        }));
        compare(received.count, 1);
        compare(received.signalArguments[0][0].id, "m1");
    }

    // Regression: a JSON line split across two reads failed to parse in both
    // halves and the message was silently dropped.
    function test_messageSplitAcrossReads() {
        const c = makeClient();
        const whole = line({
            id: "m1",
            event: "message",
            message: "split"
        });
        const first = whole.substring(0, 20);
        c._drainBuffer(first);
        compare(received.count, 0);
        c._drainBuffer(whole + line({
            id: "m2",
            event: "message"
        }));
        compare(received.count, 2);
        compare(received.signalArguments[0][0].message, "split");
        compare(received.signalArguments[1][0].id, "m2");
    }

    function test_cumulativeTextIsNotReplayed() {
        const c = makeClient();
        const text = line({
            id: "m1",
            event: "message"
        });
        c._drainBuffer(text);
        c._drainBuffer(text);
        compare(received.count, 1);
    }

    function test_skipsMalformedLines() {
        const c = makeClient();
        c._drainBuffer("<html>502 Bad Gateway</html>\n" + line({
            id: "m1",
            event: "message"
        }));
        compare(received.count, 1);
    }

    function test_backoffDoublesUpToCap() {
        const c = makeClient();
        const seen = [];
        for (let i = 0; i < 7; i++) {
            c._xhr = {};  // stands in for a live request
            c._scheduleReconnect();
            seen.push(c._backoffMs);
        }
        compare(seen, [2000, 4000, 8000, 16000, 30000, 30000, 30000]);
    }

    function test_stopSuppressesReconnect() {
        const c = makeClient();
        c.stop();
        c._scheduleReconnect();
        compare(c._backoffMs, 1000);
    }

    function test_restartResetsBackoff() {
        const c = makeClient();
        c._backoffMs = 16000;
        c.restart();
        compare(c._backoffMs, 1000);
    }
}
