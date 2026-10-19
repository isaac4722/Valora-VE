#!/usr/bin/env node
/**
 * ─── Test E2E del relay (v21.6) ──────────────────────────────────────────────
 * Verifica TODO el canal que no exige hardware real:
 *   1. Token: WS sin token válido es rechazado (4001).
 *   2. Rol: solo un bridge ACTIVO; el más nuevo toma el control (viejo 4003).
 *   3. Roundtrip: pilot → cmd tap → bridge recibe → result → pilot.
 *   4. Binarios: shot del bridge llega íntegro al piloto (PNG de prueba).
 *   5. Fallback: POST /api/cmd (HTTP puro) + frames vía SSE.
 * Corre: node test_relay.js  (levanta server.js en :3999 con token fijo)
 */
'use strict';

const { spawn } = require('child_process');
const path = require('path');
const { WebSocket } = require('ws');

const PORT = 3999;
const TOKEN = 'test-token-e2e';
const BASE = `http://127.0.0.1:${PORT}`;

let passed = 0;
let failed = 0;
function check(name, cond, extra = '') {
  if (cond) {
    passed++;
    console.log(`  ✓ ${name}`);
  } else {
    failed++;
    console.error(`  ✗ ${name} ${extra}`);
  }
}
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

function wsConnect(role, token) {
  return new Promise((resolve, reject) => {
    const ws = new WebSocket(
      `ws://127.0.0.1:${PORT}/api/ws?role=${role}&token=${token}`,
    );
    ws.binaryType = 'nodebuffer';
    const msgs = [];
    const bin = [];
    const waiters = [];
    ws.on('message', (data, isBinary) => {
      if (isBinary) {
        bin.push(Buffer.from(data));
        for (const w of waiters.splice(0)) w(Buffer.from(data));
        return;
      }
      let m;
      try {
        m = JSON.parse(data.toString('utf8'));
      } catch (_) {
        return;
      }
      msgs.push(m);
      for (const w of waiters.splice(0)) w(m);
    });
    ws.on('open', () => resolve({ ws, msgs, bin, waiters }));
    ws.on('error', reject);
    ws.on('close', (code) => {
      msgs.push({ type: '__closed', code });
      for (const w of waiters.splice(0)) w({ type: '__closed', code });
    });
  });
}

async function waitMsg(client, pred, timeoutMs = 5000) {
  const found = client.msgs.find(pred);
  if (found) return found;
  return new Promise((resolve, reject) => {
    const t = setTimeout(() => reject(new Error('timeout esperando mensaje')), timeoutMs);
    const w = (m) => {
      if (pred(m)) {
        clearTimeout(t);
        resolve(m);
      } else {
        client.waiters.push(w);
      }
    };
    client.waiters.push(w);
  });
}

async function main() {
  const server = spawn(process.execPath, [path.join(__dirname, 'server.js')], {
    env: { ...process.env, PORT: String(PORT), BRIDGE_TOKEN: TOKEN },
    stdio: 'pipe',
  });
  server.stderr.on('data', (d) => process.stderr.write('[server] ' + d));
  await sleep(700);

  try {
    console.log('— 1. token —');
    await new Promise((resolve) => {
      const ws = new WebSocket(`ws://127.0.0.1:${PORT}/api/ws?role=pilot&token=MALO`);
      // Nota: 'open' puede dispararse antes del cierre del servidor (el
      // handshake HTTP 101 completa antes) — lo que cuenta es el código 4001.
      let opened = false;
      ws.on('open', () => (opened = true));
      ws.on('close', (code) => {
        check('WS con token inválido cierra con 4001', code === 4001);
        resolve();
      });
    });

    const r = await fetch(`${BASE}/api/health`);
    const health = await r.json();
    check('health sin bridge = "sin puente"', health.bridge === 'sin puente');

    console.log('— 2/3/4. bridge + roundtrip + binarios —');
    const bridge = await wsConnect('bridge', TOKEN);
    await sleep(300);
    const pilot = await wsConnect('pilot', TOKEN);
    await sleep(300);
    check('pilot ve hello con bridge', pilot.msgs.some((m) => m.type === 'hello' && m.bridge));

    const h2 = await (await fetch(`${BASE}/api/health`)).json();
    check('health con bridge = "conectado"', h2.bridge === 'conectado');

    // toma de control: el segundo bridge REEMPLAZA al primero (el viejo, 4003)
    const bridge2 = await wsConnect('bridge', TOKEN);
    await sleep(400);
    check('segundo bridge toma el control (viejo cerrado 4003)', bridge.msgs.some((m) => m.type === '__closed' && m.code === 4003));
    check('nuevo bridge sigue activo', !bridge2.msgs.some((m) => m.type === '__closed'));

    // mock bridge responde cmds (el ACTIVO ahora es bridge2):
    // shot → binario falso + result; resto → result
    bridge2.ws.on('message', (data, isBinary) => {
      if (isBinary) return;
      const m = JSON.parse(data.toString('utf8'));
      if (m.type === 'cmd') {
        if (m.action === 'shot') {
          // PNG 1×1 real
          const png = Buffer.from(
            'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR4nGNgYGBgAAAABQABh6FO1AAAAABJRU5ErkJggg==',
            'base64',
          );
          bridge2.ws.send(png);
          bridge2.ws.send(JSON.stringify({ type: 'result', id: m.id, ok: true, data: { png: true } }));
        } else {
          bridge2.ws.send(JSON.stringify({ type: 'result', id: m.id, ok: true, data: { done: m.action, args: m.args } }));
        }
      }
    });

    // cmd roundtrip desde el piloto
    const tapResult = await new Promise((resolve) => {
      pilot.ws.send(JSON.stringify({ type: 'cmd', id: 't1', action: 'tap', args: { x: 5, y: 9 } }));
      pilot.ws.on('message', (data) => {
        if (data instanceof Buffer) {
          try {
            const m = JSON.parse(data.toString('utf8'));
            if (m.type === 'result' && m.id === 't1') resolve(m);
          } catch (_) { /* binario */ }
        }
      });
    });
    check('cmd tap viaja y regresa', tapResult.ok && tapResult.data.done === 'tap' && tapResult.data.args.x === 5);

    // shot: binario + result
    const shotPng = await new Promise((resolve) => {
      pilot.ws.on('message', (data, isBinary) => {
        if (isBinary) resolve(Buffer.from(data));
      });
      pilot.ws.send(JSON.stringify({ type: 'cmd', id: 't2', action: 'shot' }));
    });
    check('frame binario íntegro (PNG 1×1)', shotPng.length === 70 && shotPng[1] === 0x50 /* P de PNG */);

    // cmd sin puente → error honesto
    bridge2.ws.close();
    await sleep(400);
    const noBridge = await new Promise((resolve) => {
      pilot.ws.send(JSON.stringify({ type: 'cmd', id: 't3', action: 'tap', args: { x: 1, y: 1 } }));
      pilot.ws.on('message', (data) => {
        try {
          const m = JSON.parse(data.toString('utf8'));
          if (m.type === 'result' && m.id === 't3') resolve(m);
        } catch (_) { /* binario */ }
      });
    });
    check('cmd sin bridge da error honesto', noBridge.ok === false && /puente/.test(noBridge.error || ''));

    console.log('— 5. fallback SSE + POST —');
    // reconnect bridge para el POST
    const bridge3 = await wsConnect('bridge', TOKEN);
    bridge3.ws.on('message', (data) => {
      const m = JSON.parse(data.toString('utf8'));
      if (m.type === 'cmd') {
        bridge3.ws.send(JSON.stringify({ type: 'result', id: m.id, ok: true, data: { done: 'sse' } }));
      }
    });
    const sseRes = await fetch(`${BASE}/api/sse?token=${TOKEN}`);
    check('SSE abre con 200', sseRes.status === 200);
    const frames = [];
    const reader = sseRes.body.getReader();
    const dec = new TextDecoder();
    const sseTask = (async () => {
      for (;;) {
        const { done, value } = await reader.read();
        if (done) break;
        frames.push(dec.decode(value));
      }
    })();

    const post = await fetch(`${BASE}/api/cmd`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: TOKEN, action: 'tap', args: { x: 1, y: 2 } }),
    });
    const pj = await post.json();
    check('POST /api/cmd acepta (202)', post.status === 202 && pj.queued);
    await sleep(600);
    reader.cancel().catch(() => {});
    const gotResult = frames.some((f) => f.includes('"done":"sse"'));
    check('resultado llega por SSE', gotResult, JSON.stringify(frames).slice(0, 200));
    await sseTask.catch(() => {});

    const badPost = await fetch(`${BASE}/api/cmd`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ token: 'x', action: 'tap' }),
    });
    check('POST con token malo → 403', badPost.status === 403);
  } finally {
    server.kill();
  }

  console.log(`\n${passed} pasadas · ${failed} fallidas`);
  process.exit(failed ? 1 : 0);
}

main().catch((e) => {
  console.error('✗', e);
  process.exit(1);
});
