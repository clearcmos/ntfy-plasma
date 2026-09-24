#!/usr/bin/env python3
"""Minimal stand-in for an ntfy server, used by tests/tst_ntfyclient_live.qml.

GET on EXPECTED_PATH streams an open event and two messages, splitting the
first message line across two writes, then closes the connection so the
client has to reconnect. Any other path gets a 404, so a wrongly built URL
fails the test instead of passing unnoticed.
"""

import argparse
import json
import time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

# Matches the serverUrl, topics, and historySince set in the live test.
EXPECTED_PATH = "/alpha,beta/json?since=1h"


def line(obj):
    return (json.dumps(obj) + "\n").encode()


class Handler(BaseHTTPRequestHandler):
    def do_GET(self):
        if self.path != EXPECTED_PATH:
            self.send_error(404)
            return
        self.send_response(200)
        self.send_header("Content-Type", "application/x-ndjson")
        self.end_headers()
        split = line({"id": "m1", "event": "message", "topic": "alpha", "message": "split across reads"})
        chunks = [line({"event": "open"}), split[:25], split[25:], line({"id": "m2", "event": "message", "topic": "beta"})]
        try:
            for chunk in chunks:
                self.wfile.write(chunk)
                self.wfile.flush()
                # Long enough for the client to see each write as its own read.
                time.sleep(0.15)
        except (BrokenPipeError, ConnectionResetError):
            pass  # the client stopped mid-stream, which the test does on cleanup

    def log_message(self, format, *args):
        pass


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--port", type=int, required=True)
    args = parser.parse_args()
    server = ThreadingHTTPServer(("127.0.0.1", args.port), Handler)
    server.daemon_threads = True
    server.serve_forever()


if __name__ == "__main__":
    main()
