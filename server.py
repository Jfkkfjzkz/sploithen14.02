"""Static host for the console browser, with an append-only run log.

    python server.py            # port 8000
    python server.py 8080       # custom port

The folder this file lives in is the web root. Every request line and every
/ag_log?m=... line the page sends is appended to serve.log next to this file.
That matters after a freeze: the console's screen dies with the last [kp]
line on it, but each line was already fetched to this server, so serve.log
still has the trail when the console is rebooted.

serve.log is served as a plain file, so a tester can open
http://<host>:<port>/serve.log from any machine on the network.
"""
import os
import sys
import threading
import time
from http import HTTPStatus
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import parse_qs, urlparse

ROOT = os.path.dirname(os.path.abspath(__file__))
LOG = os.path.join(ROOT, "serve.log")
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

    def __init__(self, *a, **k):
        super().__init__(*a, directory=ROOT, **k)

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


def main():
    port = 8000
    if len(sys.argv) > 1:
        try:
            port = int(sys.argv[1])
        except ValueError:
            port = 8000
    elif os.environ.get("PORT"):
        port = int(os.environ["PORT"])
    print("SploitHen 14.02 on http://0.0.0.0:%d/  (ctrl-c to stop)" % port, flush=True)
    print("run log: %s" % LOG, flush=True)
    ThreadingHTTPServer(("0.0.0.0", port), Handler).serve_forever()


if __name__ == "__main__":
    main()
