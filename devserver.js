// Simple static server with COOP/COEP for local testing
// Usage: node devserver.js [port] [dir]
const http = require('http');
const fs = require('fs');
const path = require('path');

const port = Number(process.argv[2] || 8080);
const root = path.resolve(process.argv[3] || path.join(__dirname, 'build', 'web'));

const server = http.createServer((req, res) => {
  let filePath = path.join(root, decodeURIComponent(req.url.split('?')[0]))
    .replace(/\/+$/, '');
  if (req.url === '/' || !path.extname(filePath)) {
    filePath = path.join(root, 'index.html');
  }
  fs.readFile(filePath, (err, data) => {
    if (err) {
      res.writeHead(404, { 'Content-Type': 'text/plain' });
      res.end('Not found');
      return;
    }
    const headers = {
      'Cross-Origin-Opener-Policy': 'same-origin',
      'Cross-Origin-Embedder-Policy': 'require-corp',
      'Cross-Origin-Resource-Policy': 'cross-origin',
      'X-Content-Type-Options': 'nosniff',
      'Content-Type': contentType(filePath),
    };
    // Allow corp for static assets
    if (/\.(js|mjs|wasm|json|png|jpg|jpeg|gif|svg|css|map)$/i.test(filePath)) {
      headers['Cross-Origin-Resource-Policy'] = 'cross-origin';
    }
    res.writeHead(200, headers);
    res.end(data);
  });
});

server.listen(port, () => {
  console.log(`Serving ${root} on http://localhost:${port} with COOP/COEP`);
});

function contentType(p) {
  const ext = path.extname(p).toLowerCase();
  return (
    {
      '.html': 'text/html',
      '.js': 'application/javascript',
      '.mjs': 'application/javascript',
      '.css': 'text/css',
      '.json': 'application/json',
      '.wasm': 'application/wasm',
      '.png': 'image/png',
      '.jpg': 'image/jpeg',
      '.jpeg': 'image/jpeg',
      '.svg': 'image/svg+xml',
      '.map': 'application/json',
    }[ext] || 'application/octet-stream'
  );
}
