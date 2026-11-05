// Minimal read-only HTTP file server for moving installers between machines
// on the LAN. Serves files by basename from the directory given on the
// command line (default: current directory).
//
//   node tools/serve.js <dir> [port]
const http = require('http');
const fs = require('fs');
const path = require('path');

const dir = path.resolve(process.argv[2] || process.cwd());
const port = Number(process.argv[3] || 8000);

const server = http.createServer((req, res) => {
  const name = path.basename(decodeURIComponent(req.url.split('?')[0]));
  const file = path.join(dir, name);
  fs.stat(file, (err, st) => {
    if (err || !st.isFile()) {
      res.writeHead(404);
      res.end('not found');
      return;
    }
    res.writeHead(200, {
      'Content-Type': 'application/octet-stream',
      'Content-Length': st.size,
    });
    fs.createReadStream(file).pipe(res);
  });
});

server.listen(port, '0.0.0.0', () => {
  console.log(`serving ${dir} on 0.0.0.0:${port}`);
});
