#!/usr/bin/env node
/**
 * ─── Valora-VE · Puente de depuración remota (v21.8) ─────────────────────────
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
 *
 * v21.8 — «Wi-Fi del servidor, sin helper» (informe del dueño, fases 0-2):
 * cuando ESTE servidor puede alcanzar el teléfono (LAN: PC del dueño con
 * platform-tools), la preview también sirve Wi-Fi completo:
 *   · WS /adb-ws        → puente WS↔TCP al adbd del teléfono (el navegador
 *                         habla ADB real con la MISMA pila de adb.js que USB).
 *   · WS /ws/video      → `adb exec-out screenrecord --output-format=h264`
 *                         en bruto (sin scrcpy); el cliente decodifica con
 *                         WebCodecs. Reinicio transparente cada
 *                         VIDEO_TIME_LIMIT (170 s < tope 180 s de API<34) y
 *                         backpressure: si el cliente va lento se mata el
 *                         proceso antes de acumular (bufferedAmount).
 *   · WS /ws/input      → tap|swipe|key|text vía `adb shell input` con cola
 *                         serial; coords llegan en PÍXELES DEL TELÉFONO (el
 *                         cliente mapea canvas→display con /api/adb/meta).
 *   · /api/adb[+/connect|/meta] → devices, connect y wm size/orientación.
 * El preview en la nube NO llega a la LAN: /api/adb lo dice honesto y la UI
 * degrada a USB / puente de la app. Toda esta ruta exige el token de sesión.
 */
'use strict';

const http = require('http');
const fs = require('fs');
const path = require('path');
const crypto = require('crypto');
const net = require('net');
const { spawn } = require('child_process');
const { WebSocketServer } = require('ws');

const PORT = parseInt(process.env.PORT || '3000', 10);
const PUB = path.join(__dirname, 'public');
const TOKEN_FILE = path.join(__dirname, '.token');

// ── Config ADB del servidor (v21.8) ──────────────────────────────────────────
const ADB_BIN = process.env.ADB_BIN || 'adb';
const ADB_SERIAL = process.env.ADB_SERIAL || ''; // vacío = primer `device` de adb devices
const WIFI_HOST = process.env.ADB_WIFI_HOST || '192.168.0.229'; // teléfono del dueño (TECNO BF6)
const WIFI_PORT = parseInt(process.env.ADB_WIFI_PORT || '5555', 10);
const VIDEO_BIT_RATE = parseInt(process.env.VIDEO_BIT_RATE || '4000000', 10);
const VIDEO_SIZE = process.env.VIDEO_SIZE || ''; // vacío = resolución nativa del display
const VIDEO_TIME_LIMIT = parseInt(process.env.VIDEO_TIME_LIMIT || '170', 10); // < tope 180 s (API<34)
const VIDEO_MAX_BACKLOG = 2 * 1024 * 1024; // informe: descartar si bufferedAmount > 2 MB

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

// ── ADB del servidor (v21.8): spawn + parsers puros ───────────────────────────
function adbRun(args, { timeoutMs = 15000 } = {}) {
  log('adb ' + args.join(' '));
  return new Promise((resolve) => {
    let child;
    try {
      child = spawn(ADB_BIN, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    } catch (e) {
      return resolve({ code: -1, out: Buffer.alloc(0), err: e.message });
    }
    const chunks = [];
    let err = '';
    let done = false;
    const finish = (code, errMsg) => {
      if (done) return;
      done = true;
      clearTimeout(timer);
      resolve({ code, out: Buffer.concat(chunks), err: errMsg });
    };
    const timer = setTimeout(() => {
      try { child.kill('SIGKILL'); } catch (_) {}
      finish(-1, 'timeout adb: ' + args.join(' '));
    }, timeoutMs);
    child.stdout.on('data', (b) => chunks.push(b));
    child.stderr.on('data', (b) => { err += b.toString(); });
    child.on('error', (e) => finish(-1, e.message)); // ENOENT: adb no instalado
    child.on('close', (code) => finish(code == null ? -1 : code, err));
  });
}

/** Fila de `adb devices -l`: serial, estado y modelo (guiones bajos → espacios). */
function parseDevicesLine(line) {
  const m = line.match(/^(\S+)\s+(device|offline|unauthorized|recovery|no permissions)(\s|$)/);
  if (!m) return null;
  const model = (line.match(/model:(\S+)/) || [])[1];
  return { serial: m[1], state: m[2], model: model ? model.replace(/_/g, ' ').trim() : '' };
}
function parseWmSize(out) {
  // «Physical size: 720x1600» (si hay Override, manda el Override)
  const ov = out.match(/Override size:\s*(\d+)x(\d+)/);
  const ph = out.match(/Physical size:\s*(\d+)x(\d+)/);
  const m = ov || ph;
  return m ? { w: +m[1], h: +m[2] } : null;
}
function parseOrientation(out) {
  // dumpsys input → «  SurfaceOrientation: 0..3» (0=0°, 1=90°, 2=180°, 3=270°)
  const m = out.match(/SurfaceOrientation:\s*(\d)/);
  return m ? +m[1] : 0;
}

let devicesCache = { at: 0, adb: false, devices: [] };
async function listDevices(force = false) {
  if (!force && Date.now() - devicesCache.at < 3000) return devicesCache;
  const r = await adbRun(['devices', '-l'], { timeoutMs: 8000 });
  const devices = [];
  if (r.code === 0) {
    for (const line of r.out.toString().split('\n').slice(1)) {
      const d = parseDevicesLine(line);
      if (d) devices.push(d);
    }
  }
  devicesCache = { at: Date.now(), adb: r.code === 0, devices };
  return devicesCache;
}
async function adbSerial() {
  if (ADB_SERIAL) return ADB_SERIAL;
  const { devices } = await listDevices();
  const d = devices.find((x) => x.state === 'device');
  return d ? d.serial : null;
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

const server = http.createServer(async (req, res) => {
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
      adb: { bin: ADB_BIN, wifi: `${WIFI_HOST}:${WIFI_PORT}`, serial: ADB_SERIAL || '(auto)' },
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

  if (p === '/api/adb') {
    // ¿Este servidor puede con ADB? Honestidad primero: el preview en la nube
    // no tiene adb ni alcance a la LAN — la UI degrada a USB / puente de app.
    const { adb, devices } = await listDevices();
    const body = {
      adb,
      bin: ADB_BIN,
      serial: await adbSerial(),
      devices,
      wifi: { host: WIFI_HOST, port: WIFI_PORT },
      video: { bitRate: VIDEO_BIT_RATE, size: VIDEO_SIZE || 'nativa', timeLimitSec: VIDEO_TIME_LIMIT },
    };
    res.writeHead(200, localCors(req, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }));
    return res.end(JSON.stringify(body));
  }

  if (p === '/api/adb/connect' && req.method === 'POST') {
    return readBody(req, (buf) => {
      let msg = {};
      try { msg = JSON.parse(buf.toString('utf8') || '{}'); } catch (_) {}
      const host = String(msg.host || WIFI_HOST).trim();
      const port = parseInt(msg.port || WIFI_PORT, 10);
      if (!/^[\w.:-]+$/.test(host + ':' + port)) {
        res.writeHead(400, { 'Content-Type': 'application/json' });
        return res.end(JSON.stringify({ ok: false, error: 'host:port inválido' }));
      }
      adbRun(['connect', `${host}:${port}`], { timeoutMs: 12000 }).then((r) => {
        const out = (r.out.toString() + ' ' + r.err).trim();
        const ok = r.code === 0 && /connected|already/i.test(out);
        listDevices(true); // refresca el cache
        res.writeHead(ok ? 200 : 502, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' });
        res.end(JSON.stringify({ ok, output: out || `adb connect ${host}:${port} → exit ${r.code}` }));
      });
    });
  }

  if (p === '/api/adb/meta') {
    const serial = await adbSerial();
    if (!serial) {
      res.writeHead(409, { 'Content-Type': 'application/json' });
      return res.end(JSON.stringify({ ok: false, error: 'sin dispositivo ADB en este servidor' }));
    }
    const { devices } = await listDevices();
    const dev = devices.find((d) => d.serial === serial) || {};
    const [size, orient] = await Promise.all([
      adbRun(['-s', serial, 'shell', 'wm', 'size'], { timeoutMs: 8000 }),
      adbRun(['-s', serial, 'shell', 'dumpsys', 'input'], { timeoutMs: 12000 }),
    ]);
    const body = {
      ok: true,
      serial,
      model: dev.model || '',
      size: parseWmSize(size.out.toString()),
      rotation: parseOrientation(orient.out.toString()),
    };
    res.writeHead(200, localCors(req, { 'Content-Type': 'application/json', 'Cache-Control': 'no-store' }));
    return res.end(JSON.stringify(body));
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

const wss = new WebSocketServer({ noServer: true }); // relay existente (/api/ws)
const wssAdb = new WebSocketServer({ noServer: true }); // puente WS↔TCP al adbd (/adb-ws)
const wssVideo = new WebSocketServer({ noServer: true }); // screenrecord H.264 (/ws/video)
const wssInput = new WebSocketServer({ noServer: true }); // inyección de entrada (/ws/input)

server.on('upgrade', (req, socket, head) => {
  let url;
  try { url = new URL(req.url, `http://127.0.0.1:${PORT}`); } catch (_) { return socket.destroy(); }
  const route =
    url.pathname === '/api/ws' ? wss :
    url.pathname === '/adb-ws' ? wssAdb :
    url.pathname === '/ws/video' ? wssVideo :
    url.pathname === '/ws/input' ? wssInput : null;
  if (!route) return socket.destroy();
  route.handleUpgrade(req, socket, head, (ws) => route.emit('connection', ws, req, url));
});

wss.on('connection', (ws, req, url) => {
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

// ── /adb-ws: puente WS↔TCP al adbd del teléfono (v21.8) ───────────────────────
// El navegador habla ADB REAL con la pila de adb.js (misma que USB); este
// servidor solo reenvía bytes. Patrón «server-client transport» de Tango ADB.
wssAdb.on('connection', (ws, req, url) => {
  if (url.searchParams.get('token') !== TOKEN) {
    ws.close(4001, 'token inválido');
    return log('WS /adb-ws rechazado: token inválido');
  }
  const phone = net.connect(WIFI_PORT, WIFI_HOST, () =>
    log(`[adb-ws] TCP establecido con ${WIFI_HOST}:${WIFI_PORT}`),
  );
  phone.setTimeout(8000, () => {
    log(`[adb-ws] timeout TCP con ${WIFI_HOST}:${WIFI_PORT} (¿misma red? ¿adb tcpip 5555 activo?)`);
    try { ws.close(1011, 'telefono no responde'); } catch (_) {}
    phone.destroy();
  });
  phone.on('error', (e) => {
    log(`[adb-ws] error TCP: ${e.message}`);
    try { ws.close(1011, 'tcp error'); } catch (_) {}
  });
  ws.on('message', (data, isBinary) => {
    if (isBinary) phone.write(data); // ADB solo viaja en binario
  });
  phone.on('data', (chunk) => {
    if (ws.readyState === 1) ws.send(chunk);
  });
  const tearDown = () => {
    phone.setTimeout(0);
    phone.destroy();
  };
  ws.on('close', tearDown);
  ws.on('error', tearDown);
  phone.on('close', () => {
    try { ws.close(); } catch (_) {}
  });
});

// ── /ws/video: screenrecord H.264 en bruto (v21.8, sin scrcpy) ────────────────
// Un proceso `adb exec-out screenrecord --output-format=h264 … -` POR cliente;
// muere solo (time-limit) → se reinicia en el MISMO WebSocket con nuevo IDR;
// si el cliente va lento (bufferedAmount) se mata antes de acumular memoria.
wssVideo.on('connection', (ws, req, url) => {
  if (url.searchParams.get('token') !== TOKEN) {
    ws.close(4001, 'token inválido');
    return log('WS /ws/video rechazado: token inválido');
  }
  let proc = null;
  let closed = false;
  let fails = 0;
  const json = (o) => {
    if (ws.readyState === 1) ws.send(JSON.stringify(o));
  };
  const start = async () => {
    if (closed) return;
    const serial = await adbSerial();
    if (closed) return;
    if (!serial) {
      json({ type: 'video-error', message: 'sin dispositivo ADB en este servidor (usa /api/adb/connect o adb connect)' });
      return;
    }
    const args = [
      '-s', serial, 'exec-out', 'screenrecord',
      '--output-format=h264',
      '--bit-rate', String(VIDEO_BIT_RATE),
      '--time-limit', String(VIDEO_TIME_LIMIT),
      ...(VIDEO_SIZE ? ['--size', VIDEO_SIZE] : []),
      '-',
    ];
    log('spawn adb ' + args.join(' '));
    try {
      proc = spawn(ADB_BIN, args, { stdio: ['ignore', 'pipe', 'pipe'] });
    } catch (e) {
      json({ type: 'video-error', message: 'no pude lanzar adb: ' + e.message });
      return;
    }
    let errTail = '';
    proc.stdout.on('data', (buf) => {
      fails = 0;
      if (ws.readyState !== 1) return proc.kill('SIGINT');
      // Backpressure (informe): si el navegador acumula > 2 MB, cortar; el
      // proceso muere y el ciclo de reinicio trae un IDR nuevo cuando drene.
      if (ws.bufferedAmount > VIDEO_MAX_BACKLOG) {
        log(`[video] backpressure (${ws.bufferedAmount} B) — reinicio del stream`);
        return proc.kill('SIGINT');
      }
      ws.send(buf);
    });
    proc.stderr.on('data', (b) => {
      errTail = (errTail + b.toString()).slice(-400);
    });
    proc.on('error', (e) => {
      json({ type: 'video-error', message: 'adb no disponible en el servidor: ' + e.message });
      closed = true; // sin adb no hay nada que reiniciar
    });
    proc.on('close', (code) => {
      proc = null;
      if (closed) return;
      if (code && errTail) json({ type: 'video-note', code, stderr: errTail.trim() });
      const delay = Math.min(500 * Math.pow(2, fails++), 8000);
      setTimeout(start, delay); // reinicio transparente (nuevo IDR en camino)
    });
    fails = Math.max(0, fails - 1); // el arranque sí nació: perdonar un fallo
  };
  json({ type: 'video-start', serial: ADB_SERIAL || '(auto)', size: VIDEO_SIZE || 'nativa', bitRate: VIDEO_BIT_RATE, timeLimitSec: VIDEO_TIME_LIMIT });
  start();
  ws.on('close', () => {
    closed = true;
    try { if (proc) proc.kill('SIGINT'); } catch (_) {}
  });
});

// ── /ws/input: tap|swipe|key|text vía `adb shell input` (v21.8) ───────────────
// Las coordenadas llegan en PÍXELES DEL DISPLAY ACTUAL (el cliente mapea
// canvas→display con /api/adb/meta). Cola serial: `input` tarda ~1 s y no
// admite ejecución concurrente limpia.
const KEYCODES = {
  back: 4, home: 3, recents: 187, power: 26, wake: 224, menu: 82,
  enter: 66, volume_up: 24, volume_down: 25, tab: 61, escape: 111,
};

/** Texto → argumento seguro para `input text`: espacios como %s y metacaracteres del shell escapados (informe §7). */
function inputTextArg(s) {
  return String(s || '')
    .replace(/ /g, '%s')
    .replace(/([()<>|;&$\\'"`*?\[\]{}#~!])/g, '\\$1');
}

wssInput.on('connection', (ws, req, url) => {
  if (url.searchParams.get('token') !== TOKEN) {
    ws.close(4001, 'token inválido');
    return log('WS /ws/input rechazado: token inválido');
  }
  let queue = Promise.resolve();
  const json = (o) => {
    if (ws.readyState === 1) ws.send(JSON.stringify(o));
  };
  const runOne = async (msg) => {
    const serial = await adbSerial();
    if (!serial) return json({ type: 'input-result', id: msg.id, ok: false, error: 'sin dispositivo ADB en este servidor' });
    const a = msg.args || {};
    let cmd = null;
    if (msg.kind === 'tap') {
      cmd = ['shell', 'input', 'tap', String(Math.round(a.x)), String(Math.round(a.y))];
    } else if (msg.kind === 'swipe') {
      cmd = ['shell', 'input', 'swipe', String(Math.round(a.x1)), String(Math.round(a.y1)), String(Math.round(a.x2)), String(Math.round(a.y2)), String(Math.round(a.ms == null ? 300 : a.ms))];
    } else if (msg.kind === 'key') {
      const code = typeof a.keycode === 'number' ? a.keycode : (KEYCODES[String(a.keycode).toLowerCase()] ?? parseInt(a.keycode, 10));
      if (!Number.isFinite(code)) return json({ type: 'input-result', id: msg.id, ok: false, error: 'keycode desconocido: ' + a.keycode });
      cmd = ['shell', 'input', 'keyevent', String(code)];
    } else if (msg.kind === 'text') {
      cmd = ['shell', 'input', 'text', inputTextArg(a.value)];
    } else {
      return json({ type: 'input-result', id: msg.id, ok: false, error: 'kind desconocido: ' + msg.kind });
    }
    const r = await adbRun(['-s', serial, ...cmd], { timeoutMs: 20000 });
    if (r.code !== 0) log(`[input] ${msg.kind} falló (exit ${r.code}): ${r.err || r.out}`.trim());
    json({ type: 'input-result', id: msg.id, ok: r.code === 0, error: r.code ? (r.err || r.out.toString() || 'adb exit ' + r.code).slice(0, 200) : undefined });
  };
  ws.on('message', (data) => {
    let msg;
    try { msg = JSON.parse(data.toString('utf8')); } catch (_) { return; }
    queue = queue.then(() => runOne(msg)).catch((e) => json({ type: 'input-result', id: msg && msg.id, ok: false, error: e.message }));
  });
});

server.listen(PORT, () => {
  log(`Puente Valora-VE escuchando en http://127.0.0.1:${PORT}`);
  log(`Token: ${TOKEN} (archivo ${TOKEN_FILE})`);
});
