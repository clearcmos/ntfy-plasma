// Lists overlay alerts under Plasma's notification bell as well, silently,
// and takes each one out again when its overlay card is dismissed. It only
// builds commands: main.qml runs them through Plasma5Support's executable
// engine and hands each one's output back through finished().
import QtQml
import "Feed.js" as Feed

QtObject {
    id: mirror

    property bool enabled: false

    // Command text to ntfy message id, for posts still waiting on their
    // notification id.
    property var pending: ({})
    // ntfy message id to Plasma notification id.
    property var ids: ({})
    // Messages dismissed before their notification id came back.
    property var closeOnArrival: ({})
    property int seq: 0

    signal run(string command)

    function post(msg) {
        if (!enabled || !msg.id)
            return;
        seq += 1;
        const command = Feed.notifyCommand(msg, seq);
        pending[command] = msg.id;
        run(command);
    }

    function close(msgId) {
        const id = ids[msgId];
        if (id) {
            delete ids[msgId];
            run(Feed.closeCommand(id));
            return;
        }
        for (const command in pending) {
            if (pending[command] === msgId)
                closeOnArrival[msgId] = true;
        }
    }

    function finished(command, stdout) {
        const msgId = pending[command];
        if (msgId === undefined)
            return;
        delete pending[command];
        const id = Feed.notificationId(stdout);
        if (!id) {
            delete closeOnArrival[msgId];
            return;
        }
        if (closeOnArrival[msgId]) {
            delete closeOnArrival[msgId];
            run(Feed.closeCommand(id));
            return;
        }
        ids[msgId] = id;
    }
}
