#!/bin/sh
# Serve this folder to the console.
#
#   ./serve.sh                     # port 8000
#   AFTERGLOW_PORT=8080 ./serve.sh
#
# Two things this has to get right, and a plain `python3 -m http.server`
# gets one of them wrong:
#
#   * no-store on code. The console's browser holds on to modules, and a
#     corrected file would otherwise never arrive. That matters most for the
#     payloads: a cached .bin would keep running after you swapped it, and an
#     unpatched ps4-hen freezes the console. Images are cached, since a stale
#     picture harms nobody.
#   * text/javascript for .js, so the ES modules load as modules.
#
# Every request line and every /ag_log?m=... line the page sends is appended
# to serve.log next to this script, so a run that ends in a console freeze
# still leaves its [kp]/[rw] trail behind. Open
# http://<host>:<port>/serve.log from another machine to read it.
#
# Settings the pages remember (the payload choice, autostart) live in the
# browser's localStorage and are unaffected by any of this.
#
# Nothing else. There is no command channel and no auto-run endpoint: the
# pages are plain static files, and the run starts from a link on index.html.

set -eu

cd "$(dirname "$0")"
PORT="${AFTERGLOW_PORT:-8000}"

exec python3 - "$PORT" <<'PY'
import os
import sys
import threading
import time
from functools import partial
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

LOG = os.path.join(os.getcwd(), "serve.log")
LOCK = threading.Lock()


def log(line):
    try:
        with LOCK:
            with open(LOG, "a", encoding="utf-8", errors="replace") as f:
                f.write(time.strftime("%Y-%m-%d %H:%M:%S ") + line + "\n")
    except Exception:
        pass


class Handler(SimpleHTTPRequestHandler):
    extensions_map = {
        **SimpleHTTPRequestHandler.extensions_map,
        ".js": "text/javascript",
        ".css": "text/css",
        ".bin": "application/octet-stream",
        ".log": "text/plain; charset=utf-8",
    }

    CACHEABLE = (".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico")

    def end_headers(self):
        if urlparse(self.path).path.lower().endswith(self.CACHEABLE):
            self.send_header("Cache-Control", "public, max-age=604800")
        else:
            self.send_header("Cache-Control", "no-store, must-revalidate")
            self.send_header("Pragma", "no-cache")
            self.send_header("Expires", "0")
        super().end_headers()

    def log_message(self, fmt, *args):
        log("%s %s" % (self.address_string(), fmt % args))

    def do_GET(self):
        url = urlparse(self.path)
        if url.path == "/ag_log" or url.path.endswith("/ag_log"):
            msg = (parse_qs(url.query).get("m") or [""])[0]
            log("%s %s" % (self.address_string(), msg))
            self.send_response(HTTPStatus.OK)
            self.send_header("Content-Type", "text/plain; charset=utf-8")
            self.send_header("Content-Length", "0")
            self.end_headers()
            return
        super().do_GET()


port = int(sys.argv[1])
server = ThreadingHTTPServer(("0.0.0.0", port), partial(Handler, directory="."))
print("afterglow on http://0.0.0.0:%d/  (ctrl-c to stop)" % port, flush=True)
print("run log: %s" % LOG, flush=True)
try:
    server.serve_forever()
except KeyboardInterrupt:
    pass
PY
