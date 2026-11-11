/* Serve this folder to the console on a machine that has node instead of
   python3. Same two rules as serve.sh: no-store on everything that is code or
   a payload, text/javascript for modules. Images may cache.

   Every request line and every ag_log?m=... line the page sends is appended
   to serve.log next to this file, so a run that ends in a console freeze
   still leaves its [kp]/[rw] trail behind. serve.log is served as a plain
   file; open http://<host>:<port>/serve.log to read it from another machine.

     node serve.js                 # port 8000
     PORT=8080 node serve.js
*/
const http = require("http");
const fs = require("fs");
const path = require("path");

const root = __dirname;
const port = Number(process.env.PORT || 8000);
const LOG = path.join(root, "serve.log");
const CACHEABLE = new Set([".png", ".jpg", ".jpeg", ".gif", ".webp", ".ico"]);
const TYPES = {
  ".html": "text/html; charset=utf-8",
  ".js": "text/javascript; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".bin": "application/octet-stream",
  ".json": "application/json",
  ".iso": "application/octet-stream",
  ".log": "text/plain; charset=utf-8",
};

function log(line) {
  fs.appendFile(LOG, new Date().toISOString() + " " + line + "\n", function () {});
}

http
  .createServer(function (req, res) {
    let url;
    try {
      url = new URL(req.url, "http://localhost");
    } catch (e) {
      res.writeHead(400);
      res.end();
      return;
    }
    const ip = (req.socket.remoteAddress || "?").replace(/^::ffff:/, "");
    if (url.pathname === "/ag_log") {
      log(ip + " " + (url.searchParams.get("m") || ""));
      res.writeHead(200, {
        "Content-Type": "text/plain; charset=utf-8",
        "Content-Length": 0,
        "Cache-Control": "no-store, must-revalidate",
      });
      res.end();
      return;
    }
    log(ip + " " + req.method + " " + req.url);
    let rel;
    try {
      rel = decodeURIComponent(url.pathname);
    } catch (e) {
      res.writeHead(400);
      res.end();
      return;
    }
    if (rel.endsWith("/")) rel += "index.html";
    const file = path.join(root, path.normalize(rel));
    if (!file.startsWith(root + path.sep)) {
      res.writeHead(403);
      res.end();
      return;
    }
    fs.readFile(file, function (err, body) {
      if (err) {
        res.writeHead(404);
        res.end("not found");
        return;
      }
      const ext = path.extname(file).toLowerCase();
      res.writeHead(200, {
        "Content-Type": TYPES[ext] || "application/octet-stream",
        "Cache-Control": CACHEABLE.has(ext)
          ? "public, max-age=604800"
          : "no-store, must-revalidate",
        Pragma: CACHEABLE.has(ext) ? "" : "no-cache",
        Expires: CACHEABLE.has(ext) ? "" : "0",
      });
      res.end(body);
    });
  })
  .listen(port, "0.0.0.0", function () {
    console.log("SploitHen 14.02 on http://0.0.0.0:" + port + "/  (ctrl-c to stop)");
    console.log("run log: " + LOG);
  });
