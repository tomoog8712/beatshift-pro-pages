const http = require("http");
const fs = require("fs");
const path = require("path");

const root = process.argv[2];
const port = Number(process.argv[3] || 8765);

if (!root) {
  console.error("Usage: node static-server.js <root> [port]");
  process.exit(1);
}

const MIME = {
  ".html": "text/html; charset=utf-8",
  ".css": "text/css; charset=utf-8",
  ".js": "application/javascript; charset=utf-8",
  ".json": "application/json; charset=utf-8",
  ".svg": "image/svg+xml; charset=utf-8",
  ".png": "image/png",
  ".jpg": "image/jpeg",
  ".jpeg": "image/jpeg",
  ".gif": "image/gif",
  ".wav": "audio/wav",
  ".mp3": "audio/mpeg",
  ".ico": "image/x-icon",
  ".txt": "text/plain; charset=utf-8",
};

function safeResolve(reqPath) {
  const cleanPath = decodeURIComponent(reqPath.split("?")[0]);
  const relativePath = cleanPath === "/" ? "/index.html" : cleanPath;
  const normalized = path.normalize(relativePath).replace(/^(\.\.[\\/])+/, "");
  return path.join(root, normalized);
}

const server = http.createServer((req, res) => {
  try {
    const filePath = safeResolve(req.url || "/");
    if (!filePath.startsWith(path.resolve(root))) {
      res.writeHead(403, { "Content-Type": "text/plain; charset=utf-8" });
      res.end("403 Forbidden");
      return;
    }

    fs.stat(filePath, (err, stat) => {
      if (err || !stat.isFile()) {
        res.writeHead(404, { "Content-Type": "text/plain; charset=utf-8" });
        res.end("404 Not Found");
        return;
      }

      const ext = path.extname(filePath).toLowerCase();
      const contentType = MIME[ext] || "application/octet-stream";
      res.writeHead(200, { "Content-Type": contentType, "Content-Length": stat.size });
      if (req.method === "HEAD") {
        res.end();
        return;
      }
      fs.createReadStream(filePath).pipe(res);
    });
  } catch (e) {
    res.writeHead(500, { "Content-Type": "text/plain; charset=utf-8" });
    res.end("500 Internal Server Error");
  }
});

server.listen(port, "127.0.0.1");
