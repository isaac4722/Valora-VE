#!/usr/bin/env node
/**
 * ─── Valora-VE · Puente de depuración remota (v21.6) ─────────────────────────
 * Relay bidireccional entre el CLIENTE (navegador del dueño, WebADB/WebUSB
 * sobre su teléfono Android en red local) y el PILOTO (consola del
 * desarrollador: página /pilot o pilot_cli.js). Sin servicios de pago:
 * todo vive en este servidor Node con una sola dependencia (ws).
 *
 * Protocolo (WebSocket /api/ws?role=bridge|pilot&token=...):
 *   bridge → server : {type:'hello', device} · {type:'log',msg}
 *                     · binario = frame JPEG/PNG (orden: tras {type:'frame-meta'})
 *   pilot → bridge  : {type:'cmd', id, action, args} (tap|swipe|text|key|shot|
 *                     stream|shell|appcmd)
 *   bridge → pilot  : {type:'result', id, ok, data} · binarios reenviados
 *
 * Fallback sin WebSocket para pilotos: SSE GET /api/sse + POST /api/cmd.
 * El token (BRIDGE_TOKEN o autogenerado en .token) viaja inyectado en las
 * páginas servidas — la URL del preview es el portador. UN bridge ACTIVO:
 * la conexión más nueva TOMA EL CONTROL y la vieja se cierra (4003) — una
 * pestaña olvidada no bloquea al cliente real. N pilotos.
 */
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const { WebSocketServer } = require('ws');

const PORT = parseInt(process.env.PORT || '3000', 10);
const PUB = path.join(__dirname, 'public');
const TOKEN_FILE = path.join(__dirname, '.token');

// ── Token compartido ──────────────────────────────────────────────────────────
const TOKEN =
  process.env.BRIDGE_TOKEN ||
  (() => {
    try {
      return fs.readFileSync(TOKEN_FILE, 'utf8').trim();
    } catch (_) {
      const t = crypto.randomBytes(12).toString('hex');
      fs.writeFileSync(TOKEN_FILE, t);
      return t;
    }
  })();

// ── Estado del relay ──────────────────────────────────────────────────────────
const startedAt = Date.now();
let bridge = null; // socket WS del cliente del dueño
let bridgeInfo = null; // {device…}
const pilots = new Set(); // sockets WS de pilotos
const ssePilots = new Set(); // respuestas SSE de pilotos (fallback)

function now() {
  return new Date().toISOString().slice(11, 19);
}
function log(...a) {
  console.log(now(), ...a);
}

// ── HTTP ──────────────────────────────────────────────────────────────────────
function injectTemplate(file, res) {
  fs.readFile(file, 'utf8', (err, html) => {
    if (err) {
      res.writeHead(404);
      return res.end('no encontrado');
    }
    res.writeHead(200, {
      'Content-Type': 'text/html; charset=utf-8',
      'Cache-Control': 'no-store',
    });
    res.end(html.replace(/\{\{TOKEN\}\}/g, TOKEN).replace(/\{\{PORT\}\}/g, String(PORT)));
  });
}

function readBody(req, cb) {
  const chunks = [];
  req.on('data', (c) => chunks.push(c));
  req.on('end', () => cb(Buffer.concat(chunks)));
}

// CORS restringido a orígenes locales: la página servida por el helper
// (http://127.0.0.1:8790) consulta /api/health y /api/token del relay.
function localCors(req, headers) {
  const origin = req.headers.origin || '';
  if (/^https?:\/\/(127\.0\.0\.1|localhost|\[::1\])(:\d+)?$/i.test(origin)) {
    headers['Access-Control-Allow-Origin'] = origin;
    headers['Vary'] = 'Origin';
  }
  return headers;
}

const server = http.createServer((req, res) => {
  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const p = url.pathname;

  if (p === '/api/health') {
    const body = {
      ok: true,
      tool: 'valora-remote-bridge',
      version: '1.1.0',
      uptimeSec: Math.floor((Date.now() - startedAt) / 1000),
      bridge: bridge ? 'conectado' : 'sin puente',
      device: bridgeInfo,
      pilots: pilots.size + ssePilots.size,
    };
    res.writeHead(200, localCors(req, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }));
    return res.end(JSON.stringify(body));
  }

  if (p === '/api/token') {
    // El dueño consulta su token desde el propio cliente (la URL es el portador).
    res.writeHead(200, localCors(req, { 'Content-Type': 'application/json' }));
    return res.end(JSON.stringify({ token: TOKEN }));
  }

  // Fallback piloto sin WebSocket: SSE (frames + eventos) y POST de comandos.
  if (p === '/api/sse') {
    if (url.searchParams.get('token') !== TOKEN) {
      res.writeHead(403);
      return res.end('token inválido');
    }
    res.writeHead(200, {
      'Content-Type': 'text/event-stream',
      'Cache-Control': 'no-store',
      Connection: 'keep-alive',
    });
    res.write(`data: ${JSON.stringify({ type: 'hello', role: 'pilot-sse' })}\n\n`);
    ssePilots.add(res);
    req.on('close', () => ssePilots.delete(res));
    return;
  }

  if (p === '/api/cmd' && req.method === 'POST') {
    return readBody(req, (buf) => {
      let msg;
      try {
        msg = JSON.parse(buf.toString('utf8'));
      } catch (_) {
        res.writeHead(400);
        return res.end(JSON.stringify({ ok: false, error: 'JSON inválido' }));
      }
      if (msg.token !== TOKEN) {
        res.writeHead(403);
        return res.end(JSON.stringify({ ok: false, error: 'token inválido' }));
      }
      const id = msg.id || crypto.randomBytes(4).toString('hex');
      const ok = sendToBridge({ type: 'cmd', id, action: msg.action, args: msg.args || {} });
      res.writeHead(ok ? 202 : 409);
      res.end(JSON.stringify({ ok, queued: ok, id }));
    });
  }

  if (p === '/' || p === '/index.html') return injectTemplate(path.join(PUB, 'index.html'), res);
  if (p === '/pilot') return injectTemplate(path.join(PUB, 'pilot.html'), res);

  // Estáticos (adb.js, pilot.js, favicon…)
  const file = path.join(PUB, p);
  if (file.startsWith(PUB) && fs.existsSync(file) && fs.statSync(file).isFile()) {
    const ext = path.extname(file);
    const mime = { '.js': 'text/javascript', '.css': 'text/css', '.png': 'image/png', '.ico': 'image/x-icon', '.json': 'application/json' }[ext] || 'application/octet-stream';
    res.writeHead(200, { 'Content-Type': mime, 'Cache-Control': 'no-store' });
    return fs.createReadStream(file).pipe(res);
  }
  res.writeHead(404);
  res.end('no encontrado');
});

// ── WebSocket relay ───────────────────────────────────────────────────────────
function sendToBridge(msg) {
  if (bridge && bridge.readyState === 1) {
    bridge.send(JSON.stringify(msg));
    return true;
  }
  return false;
}
function sendToPilots(msg, exclude) {
  const text = JSON.stringify(msg);
  for (const w of pilots) if (w !== exclude && w.readyState === 1) w.send(text);
  for (const r of ssePilots) if (r !== exclude) r.write(`data: ${text}\n\n`);
}
function sendBinaryToPilots(buf) {
  for (const w of pilots) if (w.readyState === 1) w.send(buf);
  const b64 = buf.toString('base64');
  for (const r of ssePilots) r.write(`event: frame\ndata: ${b64}\n\n`);
}

const wss = new WebSocketServer({ server, path: '/api/ws' });

wss.on('connection', (ws, req) => {
  const url = new URL(req.url, `http://127.0.0.1:${PORT}`);
  const role = url.searchParams.get('role');
  if (url.searchParams.get('token') !== TOKEN) {
    ws.close(4001, 'token inválido');
    return log('WS rechazado: token inválido');
  }
  if (role === 'bridge') {
    if (bridge && bridge.readyState === 1) {
      // TOMA DE CONTROL: la conexión más nueva gana y la vieja se cierra con
      // 4003 — una pestaña olvidada (zombi, sin dispositivo) nunca debe
      // bloquear al cliente real del dueño.
      try {
        bridge.close(4003, 'reemplazado por otra pestaña del cliente');
      } catch (_) {}
      log('WS bridge anterior reemplazado (toma de control)');
    }
    bridge = ws;
    bridgeInfo = null;
    log('PUENTE conectado');
    ws.on('message', (data, isBinary) => {
      if (isBinary) return sendBinaryToPilots(data); // frame de video/shot
      let msg;
      try {
        msg = JSON.parse(data.toString('utf8'));
      } catch (_) {
        return;
      }
      if (msg.type === 'hello') {
        bridgeInfo = msg.device || {};
        log('Dispositivo:', JSON.stringify(bridgeInfo));
        sendToPilots({ type: 'bridge-hello', device: bridgeInfo }, null);
      } else if (msg.type === 'result') {
        sendToPilots(msg, null);
      } else if (msg.type === 'log') {
        log('[puente]', msg.msg);
      } else if (msg.type === 'stream') {
        // meta del frame entrante (dimensiones) — aviso a pilotos
        sendToPilots(msg, null);
      }
    });
    ws.on('close', () => {
      if (bridge === ws) {
        bridge = null;
        bridgeInfo = null;
        log('PUENTE desconectado');
        sendToPilots({ type: 'bridge-bye' }, null);
      }
    });
    return;
  }
  if (role === 'pilot') {
    pilots.add(ws);
    log('PILOTO conectado', `(total ${pilots.size})`);
    ws.send(JSON.stringify({ type: 'hello', role: 'pilot', bridge: !!bridge, device: bridgeInfo }));
    ws.on('message', (data, isBinary) => {
      if (isBinary) return; // los pilotos no envían binarios
      let msg;
      try {
        msg = JSON.parse(data.toString('utf8'));
      } catch (_) {
        return;
      }
      if (msg.type === 'cmd') {
        const ok = sendToBridge(msg);
        if (!ok) ws.send(JSON.stringify({ type: 'result', id: msg.id, ok: false, error: 'sin puente conectado' }));
      }
    });
    ws.on('close', () => {
      pilots.delete(ws);
      log('PILOTO salió', `(total ${pilots.size})`);
    });
    return;
  }
  ws.close(4003, 'rol desconocido');
});

server.listen(PORT, () => {
  log(`Puente Valora-VE escuchando en http://127.0.0.1:${PORT}`);
  log(`Token: ${TOKEN} (archivo ${TOKEN_FILE})`);
});
