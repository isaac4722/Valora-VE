'use strict';
/**
 * Servidor estático de la app web (build/web) en :3000 — hijo daemonizado
 * de web_preview_daemon.js. SPA: cualquier ruta desconocida cae a index.html
 * (la app usa usePathUrlStrategy). MIME completo (wasm/js/png/svg/ttf…).
 */
const HTTP = require('http');
const FS = require('fs');
const PATH = require('path');

const ROOT = '/home/z/my-project/Valora-VE/build/web';
const PORT = 3000;

const MIME = {
  '.html': 'text/html; charset=utf-8',
  '.js': 'application/javascript; charset=utf-8',
  '.mjs': 'application/javascript; charset=utf-8',
  '.wasm': 'application/wasm',
  '.json': 'application/json; charset=utf-8',
  '.css': 'text/css; charset=utf-8',
  '.png': 'image/png',
  '.jpg': 'image/jpeg',
  '.jpeg': 'image/jpeg',
  '.gif': 'image/gif',
  '.svg': 'image/svg+xml',
  '.ico': 'image/x-icon',
  '.ttf': 'font/ttf',
  '.otf': 'font/otf',
  '.woff': 'font/woff',
  '.woff2': 'font/woff2',
  '.txt': 'text/plain; charset=utf-8',
  '.map': 'application/json',
  '.webmanifest': 'application/manifest+json',
  '.xml': 'application/xml',
  '.version': 'application/json',
};

const server = HTTP.createServer((req, res) => {
  try {
    let urlPath = decodeURIComponent((req.url || '/').split('?')[0]);
    if (urlPath === '/health') {
      res.writeHead(200, { 'Content-Type': 'application/json' });
      res.end(JSON.stringify({ app: 'ValoraVE', version: 'web v22.1', ok: true }));
      return;
    }
    let file = PATH.normalize(PATH.join(ROOT, urlPath));
    if (!file.startsWith(ROOT)) {
      res.writeHead(403); res.end(); return;
    }
    if (!FS.existsSync(file) || FS.statSync(file).isDirectory()) {
      urlPath = '/index.html'; // SPA fallback (rutas de go_router)
      file = PATH.join(ROOT, 'index.html');
    }
    const ext = PATH.extname(file).toLowerCase();
    const body = FS.readFileSync(file);
    res.writeHead(200, {
      'Content-Type': MIME[ext] || 'application/octet-stream',
      'Content-Length': body.length,
      'Cache-Control': ext === '.html' ? 'no-cache' : 'public, max-age=3600',
    });
    res.end(body);
  } catch (e) {
    res.writeHead(500);
    res.end('error interno');
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`[web_preview] ValoraVE sirviendo ${ROOT} en :${PORT}`);
});
