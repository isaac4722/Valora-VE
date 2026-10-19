#!/usr/bin/env node
/**
 * ─── Valora-VE · Piloto por línea de comandos (v21.6) ────────────────────────
 * Consola del desarrollador para manejar el teléfono del dueño a través del
 * puente (server.js). Una conexión por invocación — ideal para automatizar:
 *
 *   node pilot_cli.js status
 *   node pilot_cli.js shot capturas/f.png
 *   node pilot_cli.js tap 200 400
 *   node pilot_cli.js swipe 100 800 100 300 350
 *   node pilot_cli.js text "Arroz"
 *   node pilot_cli.js key 4                (BACK=4 · HOME=3 · WAKEUP=224)
 *   node pilot_cli.js shell "dumpsys battery"
 *   node pilot_cli.js app /health
 *   node pilot_cli.js app /test?scenario=cart
 *   node pilot_cli.js app /erase --token <token-de-ajustes>
 *   node pilot_cli.js stream 8 capturas/   (graba N segundos de frames)
 *
 * Token: BRIDGE_TOKEN o el archivo .token que dejó server.js.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const { WebSocket } = require('ws');

const PORT = process.env.PORT || 3000;
const HOST = process.env.BRIDGE_HOST || '127.0.0.1';
const TOKEN =
  process.env.BRIDGE_TOKEN ||
  (() => {
    try {
      return fs.readFileSync(path.join(__dirname, '.token'), 'utf8').trim();
    } catch (_) {
      return '';
    }
  })();

const [, , cmd, ...rest] = process.argv;
if (!cmd) {
  console.error('uso: node pilot_cli.js <status|shot|tap|swipe|text|key|shell|app|stream|wake> …');
  process.exit(2);
}

let ws;
let seq = 0;
const pending = new Map();
let binaryWaiters = [];
let gotBinary = null;

function send(action, args, timeoutMs = 45000) {
  return new Promise((resolve, reject) => {
    const id = 'c' + (++seq);
    const timer = setTimeout(() => {
      pending.delete(id);
      reject(new Error(`timeout (${action})`));
    }, timeoutMs);
    pending.set(id, (m) => {
      clearTimeout(timer);
      if (m.ok) resolve(m.data || {});
      else reject(new Error(m.error || 'error del puente'));
    });
    ws.send(JSON.stringify({ type: 'cmd', id, action, args: args || {} }));
  });
}

function connect() {
  return new Promise((resolve, reject) => {
    ws = new WebSocket(`ws://${HOST}:${PORT}/api/ws?role=pilot&token=${TOKEN}`);
    ws.binaryType = 'nodebuffer';
    ws.on('open', resolve);
    ws.on('error', reject);
    ws.on('message', (data, isBinary) => {
      if (isBinary) {
        gotBinary = data;
        for (const w of binaryWaiters.splice(0)) w(data);
        return;
      }
      let m;
      try {
        m = JSON.parse(data.toString('utf8'));
      } catch (_) {
        return;
      }
      if (m.type === 'result' && pending.has(m.id)) {
        pending.get(m.id)(m);
        pending.delete(m.id);
      } else if (m.type === 'hello') {
        if (!m.bridge && cmd !== 'status') {
          console.error('✗ No hay puente conectado (el dueño debe abrir el cliente en su navegador).');
          process.exit(3);
        }
      }
    });
    ws.on('close', (code, reason) => {
      if (code === 4001) {
        console.error('✗ Token inválido.');
        process.exit(4);
      }
    });
  });
}

async function main() {
  await connect();

  switch (cmd) {
    case 'status': {
      // saluda: el hello ya verifica puente; pide un health del servidor HTTP
      const r = await fetch(`http://${HOST}:${PORT}/api/health`);
      console.log(JSON.stringify(await r.json(), null, 2));
      break;
    }
    case 'shot': {
      const file = rest[0] || `shot_${Date.now()}.png`;
      const p = (async () => {
        const buf = await new Promise((res) => binaryWaiters.push(res));
        fs.mkdirSync(path.dirname(file), { recursive: true });
        fs.writeFileSync(file, buf);
      })();
      const res = await send('shot');
      await p;
      console.log(`✓ captura → ${file} (${res.png ? 'png' : '?'})`);
      break;
    }
    case 'tap': {
      const [x, y] = rest.map(Number);
      if ([x, y].some(Number.isNaN)) throw new Error('tap <x> <y>');
      await send('tap', { x, y });
      console.log(`✓ tap ${x},${y}`);
      break;
    }
    case 'swipe': {
      const [x1, y1, x2, y2, ms = 350] = rest.map(Number);
      await send('swipe', { x1, y1, x2, y2, ms });
      console.log(`✓ swipe ${x1},${y1} → ${x2},${y2} (${ms} ms)`);
      break;
    }
    case 'text': {
      await send('text', { text: rest.join(' ') });
      console.log('✓ texto enviado');
      break;
    }
    case 'key': {
      const k = Number(rest[0]);
      await send('key', { keycode: k });
      console.log(`✓ keyevent ${k}`);
      break;
    }
    case 'wake': {
      await send('key', { keycode: 224 });
      console.log('✓ despertar (KEYCODE_WAKEUP)');
      break;
    }
    case 'shell': {
      const out = await send('shell', { cmd: rest.join(' ') });
      if (out.out) {
        console.log(Buffer.from(out.out, 'base64').toString('utf8'));
      }
      break;
    }
    case 'app': {
      const p = rest[0];
      if (!p) throw new Error('app <ruta>');
      let token;
      const ti = rest.indexOf('--token');
      if (ti >= 0) token = rest[ti + 1];
      const r = await send('appcmd', { path: p, token }, 30000);
      console.log(JSON.stringify(r.json, null, 2));
      break;
    }
    case 'stream': {
      const secs = Number(rest[0] || 8);
      const dir = rest[1] || '.';
      fs.mkdirSync(dir, { recursive: true });
      await send('stream', { on: true });
      console.log(`grabando ${secs}s…`);
      const t0 = Date.now();
      let n = 0;
      while ((Date.now() - t0) / 1000 < secs) {
        const buf = await new Promise((res) => {
          if (gotBinary) {
            const b = gotBinary;
            gotBinary = null;
            return res(b);
          }
          binaryWaiters.push(res);
        });
        const file = path.join(dir, `frame_${String(++n).padStart(3, '0')}.jpg`);
        fs.writeFileSync(file, buf);
        process.stdout.write(`  frame ${n} → ${file}\n`);
      }
      await send('stream', { on: false });
      console.log(`✓ ${n} frames en ${dir}`);
      break;
    }
    default:
      throw new Error('comando desconocido: ' + cmd);
  }
  process.exit(0);
}

main().catch((e) => {
  console.error('✗ ' + e.message);
  process.exit(1);
});
