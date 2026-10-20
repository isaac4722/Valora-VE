#!/usr/bin/env node
/**
 * ─── Valora-VE · Test del servidor v21.8 «Wi-Fi del servidor, sin helper» ────
 * Sin hardware: el ADB es FALSO (script que despacha por argv) y el «teléfono»
 * es un adbd MOCK que habla el protocolo real (CNXN/AUTH/OPEN/OKAY/WRTE/CLSE).
 *
 * Cubre:
 *   1. /api/health · /api/adb (devices parseados) · /api/adb/connect · /api/adb/meta
 *   2. /adb-ws: puente WS↔TCP — el CLIENTE REAL (ValoraAdb de adb.js sobre un
 *      transporte ws de Node) completa handshake + exec('wm size') contra el mock.
 *   3. /ws/input: tap (redondeo), text (escape %s + metacaracteres), key (nombre).
 *   4. /ws/video: video-start JSON + bytes binarios del screenrecord falso.
 *   5. Funciones PURAS del cliente extraídas de index.html: makeNalFeeder
 *      (NALUs partidas entre mensajes), makeChunkAssembler (SPS+PPS+IDR),
 *      avcCodecFromSps (avc1.640028) y mapToDevice.
 * Uso: node test_server_wifi.js
 */
'use strict';

const { spawn } = require('child_process');
const fs = require('fs');
const net = require('net');
const os = require('os');
const path = require('path');
const assert = require('assert');
const WebSocket = require('ws');

const HERE = __dirname;
const TMP = fs.mkdtempSync(path.join(os.tmpdir(), 'valora-v218-'));
const INPUT_LOG = path.join(TMP, 'input.log');
// Puertos aleatorios: un servidor huérfano de una corrida anterior no debe
// contaminar la siguiente (y el finally SIEMPRE mata el proceso).
const PORT_HTTP = 20000 + Math.floor(Math.random() * 20000);
const PORT_ADBD = 40000 + Math.floor(Math.random() * 20000);
const TOKEN = 'testtoken-v218';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
async function until(fn, ms = 8000, step = 50) {
  const t0 = Date.now();
  for (;;) {
    const v = await fn();
    if (v) return v;
    if (Date.now() - t0 > ms) throw new Error('until: timeout');
    await sleep(step);
  }
}

// ── adb FALSO (script ejecutable; el servidor lo lanza con spawn) ────────────
const FAKE_ADB = path.join(TMP, 'fake-adb.js');
fs.writeFileSync(
  FAKE_ADB,
  `#!/usr/bin/env node
const fs = require('fs');
const argv = process.argv.slice(2);
const j = JSON.stringify(argv);
if (argv[0] === 'version') { console.log('Android Debug Bridge version 1.0.41'); process.exit(0); }
if (argv[0] === 'devices' && argv[1] === '-l') {
  console.log('List of devices attached');
  console.log('R58N1234567           device product:BF6 model:TECNO_BF6 device:BF6 transport_id:3');
  process.exit(0);
}
if (argv[0] === 'connect') { console.log('connected to ' + argv[1]); process.exit(0); }
if (argv[0] === '-s') {
  const rest = argv.slice(2);
  if (rest[0] === 'shell' && rest[1] === 'wm' && rest[2] === 'size') { console.log('Physical size: 720x1600'); process.exit(0); }
  if (rest[0] === 'shell' && rest[1] === 'dumpsys') { console.log('INPUT (mock)'); console.log('  SurfaceOrientation: 0'); process.exit(0); }
  if (rest[0] === 'shell' && rest[1] === 'input') { fs.appendFileSync(process.env.INPUT_LOG, j + '\\n'); process.exit(0); }
  if (rest[0] === 'exec-out' && rest[1] === 'screenrecord') {
    const nal = (b) => Buffer.concat([Buffer.from([0, 0, 0, 1]), Buffer.from(b)]);
    process.stdout.write(Buffer.concat([
      nal([0x67, 0x64, 0x00, 0x28, 0xac, 0xd9, 0x40, 0x50]), // SPS  → avc1.640028
      nal([0x68, 0xeb, 0xec, 0xb2, 0x2c]),                   // PPS
      nal([0x65, 0x88, 0x84, 0x21, 0xa0]),                   // IDR
    ]));
    let t = 0;
    const iv = setInterval(() => process.stdout.write(nal([0x41, 0x9a, (t++) & 0xff])), 40); // deltas
    process.on('SIGINT', () => { clearInterval(iv); process.exit(0); });
    process.on('SIGTERM', () => { clearInterval(iv); process.exit(0); });
    return;
  }
}
process.exit(0);
`,
);
fs.chmodSync(FAKE_ADB, 0o755);

// ── adbd MOCK: protocolo ADB real, servicios mínimos ─────────────────────────
const ADB = { CNXN: 0x434e584e, AUTH: 0x41755448, OPEN: 0x4f50454e, OKAY: 0x4f4b4159, WRTE: 0x57525445, CLSE: 0x434c5345 };
const fakePng = Buffer.from(
  'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAYAAAAfFcSJAAAADUlEQVR42mNk+M9QDwADhgGAWjR9awAAAABJRU5ErkJggg==',
  'base64',
);
function adbFrame(cmd, arg0, arg1, data) {
  const d = data || Buffer.alloc(0);
  const h = Buffer.alloc(24);
  h.writeUInt32LE(cmd, 0);
  h.writeUInt32LE(arg0, 4);
  h.writeUInt32LE(arg1, 8);
  h.writeUInt32LE(d.length, 12);
  let sum = 0;
  for (const b of d) sum += b;
  h.writeUInt32LE(sum & 0xffffffff, 16);
  h.writeUInt32LE((cmd ^ 0xffffffff) >>> 0, 20);
  return Buffer.concat([h, d]);
}
const adbdServices = []; // registro de servicios pedidos por el cliente REAL
function startMockAdbd() {
  const server = net.createServer((sock) => {
    let buf = Buffer.alloc(0);
    let nextRemote = 900;
    const streams = new Map(); // hostLocalId → remoteId
    const send = (f) => sock.write(f);
    sock.on('data', (d) => {
      buf = Buffer.concat([buf, d]);
      while (buf.length >= 24) {
        const cmd = buf.readUInt32LE(0);
        const magic = buf.readUInt32LE(20);
        if ((cmd ^ 0xffffffff) >>> 0 !== magic) { buf = buf.subarray(1); continue; }
        const arg0 = buf.readUInt32LE(4);
        const arg1 = buf.readUInt32LE(8);
        const len = buf.readUInt32LE(12);
        if (buf.length < 24 + len) return;
        const data = buf.subarray(24, 24 + len);
        buf = buf.subarray(24 + len);
        if (cmd === ADB.CNXN) {
          send(adbFrame(ADB.CNXN, 0x01000001, 4096, Buffer.from('device::ro.product.model=TECNO BF6;\x00')));
        } else if (cmd === ADB.AUTH) {
          send(adbFrame(ADB.CNXN, 0x01000001, 4096, Buffer.from('device::'))); // clave aceptada
        } else if (cmd === ADB.OPEN) {
          const svc = data.toString().replace(/\0+$/, '');
          adbdServices.push(svc);
          const remote = ++nextRemote;
          streams.set(arg0, remote);
          send(adbFrame(ADB.OKAY, remote, arg0));
          if (/^exec:screenrecord/.test(svc)) {
            // v21.9: el CLIENTE hace screenrecord por su propia sesión ADB —
            // stream continuo hasta que el cliente cierre (A_CLSE → matamos el
            // «proceso», igual que adbd mata screenrecord).
            const nal = (b) => Buffer.concat([Buffer.from([0, 0, 0, 1]), Buffer.from(b)]);
            send(adbFrame(ADB.WRTE, remote, arg0, Buffer.concat([
              nal([0x67, 0x64, 0x00, 0x28, 0xac, 0xd9, 0x40, 0x50]), // SPS → avc1.640028
              nal([0x68, 0xeb, 0xec, 0xb2, 0x2c]),                   // PPS
              nal([0x65, 0x88, 0x84, 0x21, 0xa0]),                   // IDR
            ])));
            let tick = 0;
            const iv = setInterval(() => {
              try { send(adbFrame(ADB.WRTE, remote, arg0, nal([0x41, 0x9a, (tick++) & 0xff]))); }
              catch (_) { clearInterval(iv); }
            }, 15);
            streams.set('iv:' + arg0, iv);
          } else {
            let out = Buffer.from('mock: ' + svc + '\n');
            if (/wm size$/.test(svc)) out = Buffer.from('Physical size: 720x1600\n');
            else if (/dumpsys input/.test(svc)) out = Buffer.from('  SurfaceOrientation: 0\n');
            else if (/^shell:input /.test(svc)) out = Buffer.alloc(0);
            else if (/screencap/.test(svc)) out = fakePng;
            if (out.length) send(adbFrame(ADB.WRTE, remote, arg0, out));
            setTimeout(() => send(adbFrame(ADB.CLSE, remote, arg0)), 15);
          }
        } else if (cmd === ADB.CLSE) {
          // v21.9: CLSE del CLIENTE (arg0 = localId del cliente) — mata el
          // screenrecord que le estaba sirviendo ese stream.
          const iv = streams.get('iv:' + arg0);
          if (iv) { clearInterval(iv); streams.delete('iv:' + arg0); }
        } else if (cmd === ADB.OKAY || cmd === ADB.WRTE) {
          // el cliente acusa recibo; el mock no mantiene más estado
        }
      }
    });
  });
  return new Promise((res) => server.listen(PORT_ADBD, '127.0.0.1', () => res(server)));
}

// ── Servidor bajo test (env apuntando a los fakes) ────────────────────────────
function startServer() {
  const child = spawn(process.execPath, [path.join(HERE, 'server.js')], {
    env: {
      ...process.env,
      PORT: String(PORT_HTTP),
      BRIDGE_TOKEN: TOKEN,
      ADB_BIN: FAKE_ADB,
      ADB_SERIAL: 'R58N1234567',
      ADB_WIFI_HOST: '127.0.0.1',
      ADB_WIFI_PORT: String(PORT_ADBD),
      INPUT_LOG,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  });
  child.stdout.on('data', (d) => process.env.V218_VERBOSE && process.stdout.write('[srv] ' + d));
  child.stderr.on('data', (d) => process.stdout.write('[srv!]' + d));
  return child;
}

function httpJson(method, p, body) {
  return fetch(`http://127.0.0.1:${PORT_HTTP}${p}`, {
    method,
    headers: body ? { 'Content-Type': 'application/json' } : {},
    body: body ? JSON.stringify(body) : undefined,
  }).then(async (r) => ({ status: r.status, json: await r.json() }));
}

// ── ValoraAdb REAL (adb.js) sobre un transporte ws de Node ───────────────────
function makeClientTransport(wsUrl) {
  const ws = new WebSocket(wsUrl);
  const t = {
    ws,
    onMessage: null,
    onDisconnect: null,
    connect() {
      return new Promise((res, rej) => {
        ws.once('open', () => res({ model: 'Android (Wi-Fi)', serial: wsUrl }));
        ws.once('error', rej);
      });
    },
    async write(b) { ws.send(Buffer.from(b)); },
    async close() { try { ws.close(); } catch (_) {} },
  };
  ws.on('message', (d) => { if (t.onMessage) t.onMessage(new Uint8Array(d)); });
  ws.on('close', () => { if (t.onDisconnect) t.onDisconnect(); });
  return t;
}

// ── Utilidades puras del CLIENTE extraídas de index.html ─────────────────────
function extractClientFns() {
  const html = fs.readFileSync(path.join(HERE, 'public', 'index.html'), 'utf8');
  const beg = html.indexOf('// ── H.264 · utilidades puras');
  const end = html.indexOf('// ── fin utilidades puras H.264 ──');
  assert(beg > 0 && end > beg, 'sección de utilidades puras encontrada en index.html');
  const src = html.slice(beg, end);
  return new Function(src + '\nreturn { startCodeLenAt, makeNalFeeder, makeChunkAssembler, avcCodecFromSps, mapToDevice, h264Route };')();
}

// ── Suite ─────────────────────────────────────────────────────────────────────
(async () => {
  let n = 0;
  const ok = (m) => console.log(`  ok ${++n} · ${m}`);
  try {
  const adbd = await startMockAdbd();
  const srv = startServer();
  const BASE = `http://127.0.0.1:${PORT_HTTP}`;

  // 1. health + /api/adb
  await until(async () => {
    try { return (await httpJson('GET', '/api/health')).json.tool; } catch (_) { return null; }
  });
  const health = await httpJson('GET', '/api/health');
  assert.strictEqual(health.json.tool, 'valora-remote-bridge');
  assert.strictEqual(health.json.adb.bin, FAKE_ADB);
  ok('/api/health con bloque adb (bin falso, wifi del teléfono)');

  const adbInfo = await httpJson('GET', '/api/adb');
  assert.strictEqual(adbInfo.json.adb, true);
  assert.strictEqual(adbInfo.json.devices.length, 1);
  assert.strictEqual(adbInfo.json.devices[0].model, 'TECNO BF6');
  assert.strictEqual(adbInfo.json.devices[0].serial, 'R58N1234567');
  assert.strictEqual(adbInfo.json.wifi.host, '127.0.0.1');
  ok('/api/adb: devices -l parseado (TECNO BF6) + wifi');

  const conn = await httpJson('POST', '/api/adb/connect', { host: '192.168.0.229', port: 5555 });
  assert.strictEqual(conn.json.ok, true);
  assert(/connected to/.test(conn.json.output), 'salida de adb connect');
  ok('/api/adb/connect → ok (adb falso)');

  const meta = await httpJson('GET', '/api/adb/meta');
  assert.strictEqual(meta.json.ok, true);
  assert.deepStrictEqual(meta.json.size, { w: 720, h: 1600 });
  assert.strictEqual(meta.json.rotation, 0);
  assert.strictEqual(meta.json.model, 'TECNO BF6');
  ok('/api/adb/meta: wm size 720x1600 + rotación 0');

  // 2. /adb-ws con el CLIENTE REAL (ValoraAdb): handshake + shell + screencap
  const { ValoraAdb } = require(path.join(HERE, 'public', 'adb.js'));
  const t = makeClientTransport(`ws://127.0.0.1:${PORT_HTTP}/adb-ws?token=${TOKEN}`);
  const adbClient = new ValoraAdb(t, () => {});
  const info = await adbClient.connect();
  assert(info, 'handshake CNXN/AUTH completado por el puente');
  const wm = new TextDecoder().decode(await adbClient.shell('wm size'));
  assert.strictEqual(wm.trim(), 'Physical size: 720x1600');
  assert(adbdServices.some((s) => s === 'shell:wm size'), 'servicio llegó CON prefijo shell: (fix v21.8)');
  ok('/adb-ws: ValoraAdb real — handshake + shell(wm size) vía puente WS↔TCP');
  const shot = await adbClient.screenshot();
  assert.strictEqual(shot.length, fakePng.length, 'screencap binario intacto por el puente');
  ok('/adb-ws: screencap PNG (exec:) binario-seguro a través del puente');
  await adbClient.tap(360, 800);
  await sleep(60);
  assert(adbdServices.includes('shell:input tap 360 800'), 'tap del cliente → shell:input tap');
  ok('/adb-ws: tap del cliente REAL llega como shell:input tap 360 800');
  await t.close();

  // 3. /ws/input: redondeo, escape de texto y keycodes nombrados
  let wsIn = new WebSocket(`ws://127.0.0.1:${PORT_HTTP}/ws/input?token=${TOKEN}`);
  await new Promise((res, rej) => { wsIn.once('open', res); wsIn.once('error', rej); });
  const inputResult = (id) => until(async () => {
    // los resultados llegan por el MISMO socket; se resuelven en orden FIFO
  }).catch(() => null);
  const results = [];
  wsIn.on('message', (d) => { try { results.push(JSON.parse(d.toString())); } catch (_) {} });
  const waitResult = (id) => until(() => results.find((r) => r.id === id && r.type === 'input-result'));
  wsIn.send(JSON.stringify({ id: 'tap1', kind: 'tap', args: { x: 100.6, y: 200.4 } }));
  const r1 = await waitResult('tap1');
  assert.strictEqual(r1.ok, true);
  wsIn.send(JSON.stringify({ id: 'txt1', kind: 'text', args: { value: 'hola mundo&2' } }));
  const r2 = await waitResult('txt1');
  assert.strictEqual(r2.ok, true);
  wsIn.send(JSON.stringify({ id: 'key1', kind: 'key', args: { keycode: 'back' } }));
  const r3 = await waitResult('key1');
  assert.strictEqual(r3.ok, true);
  await sleep(80);
  const lines = fs.readFileSync(INPUT_LOG, 'utf8').trim().split('\n').map((l) => JSON.parse(l));
  assert(lines.some((a) => JSON.stringify(a) === JSON.stringify(['-s', 'R58N1234567', 'shell', 'input', 'tap', '101', '200'])), 'tap redondeado');
  assert(lines.some((a) => a[4] === 'text' && a[5] === 'hola%smundo\\&2'), 'texto: %s + metacaracteres escapados → ' + JSON.stringify(lines));
  assert(lines.some((a) => a[4] === 'keyevent' && a[5] === '4'), 'keycode back → 4');
  ok('/ws/input: tap (redondeo), text (%s + escape), key (back→4)');
  wsIn.close();

  // 4. /ws/video: video-start + binarios del screenrecord falso
  const wsV = new WebSocket(`ws://127.0.0.1:${PORT_HTTP}/ws/video?token=${TOKEN}`);
  wsV.binaryType = 'nodebuffer';
  const vmsg = [];
  wsV.on('message', (d, isBin) => vmsg.push({ d, isBin }));
  await new Promise((res, rej) => { wsV.once('open', res); wsV.once('error', rej); });
  await until(() => vmsg.some((m) => !m.isBin && JSON.parse(m.d.toString()).type === 'video-start'));
  const vstart = JSON.parse(vmsg.find((m) => !m.isBin).d.toString());
  assert.strictEqual(vstart.size, 'nativa');
  assert.strictEqual(vstart.bitRate, 4000000);
  await until(() => vmsg.filter((m) => m.isBin).length >= 3);
  const allBin = Buffer.concat(vmsg.filter((m) => m.isBin).map((m) => m.d));
  assert(allBin.includes(Buffer.from([0, 0, 0, 1, 0x67])), 'SPS annex-b presente');
  assert(allBin.includes(Buffer.from([0, 0, 0, 1, 0x65])), 'IDR presente');
  ok('/ws/video: video-start JSON + H.264 annex-b binario (SPS+PPS+IDR+delta)');
  wsV.close();

  // 4b. v21.9 · ruta «adb»: EL CLIENTE hace screenrecord por SU sesión ADB
  // (la pila de Vysor web, con la ruta A del informe — sin scrcpy).
  {
    const t2 = makeClientTransport(`ws://127.0.0.1:${PORT_HTTP}/adb-ws?token=${TOKEN}`);
    const adb2 = new ValoraAdb(t2, () => {});
    await adb2.connect();
    const video = [];
    let ghostCloses = 0;
    const sRec = await adb2.conn.open(
      'exec:screenrecord --output-format=h264 --size 1280x720 --bit-rate 4000000 --time-limit 170 -',
      { onData: (b) => video.push(Buffer.from(b)), onClose: () => ghostCloses++ },
    );
    await until(() => video.some((c) => c.includes(Buffer.from([0, 0, 0, 1, 0x67]))));
    await until(() => video.length >= 5); // SPS+PPS+IDR + deltas en vivo
    assert(video.some((c) => c.includes(Buffer.from([0, 0, 0, 1, 0x65]))), 'IDR por la sesión del cliente');
    ok('ruta adb: screenrecord por la SESIÓN del cliente — SPS/PPS/IDR + deltas en vivo');
    adb2.conn.closeStream(sRec.localId);
    const antes = video.length;
    await sleep(250);
    assert(video.length - antes <= 1, 'closeStream (A_CLSE) mata el screenrecord del teléfono');
    assert.strictEqual(ghostCloses, 0, 'sin onClose fantasma tras el stop propio');
    ok('ruta adb: ⏸ detiene el flujo de verdad (A_CLSE limpia el stream)');
    await t2.close();
  }

  // 5. token inválido → 4001 (el socket abre y el servidor lo cierra enseguida)
  const wsBad = new WebSocket(`ws://127.0.0.1:${PORT_HTTP}/adb-ws?token=equivocado`);
  const closeCode = await new Promise((res) => {
    const to = setTimeout(() => res(-2), 5000);
    wsBad.on('close', (code) => { clearTimeout(to); res(code); });
    wsBad.on('error', () => {});
  });
  assert.strictEqual(closeCode, 4001, 'close 4001 con token inválido');
  ok('/adb-ws sin token → close 4001');

  // 6. Funciones puras del cliente (extraídas del HTML real)
  const F = extractClientFns();
  // 6a. feeder: NALU partida ENTRE dos feeds
  const nals = [];
  const feeder = F.makeNalFeeder((type, full) => nals.push({ type, full: Buffer.from(full).toString('hex') }));
  const sc = Buffer.from([0, 0, 0, 1]);
  feeder.feed(new Uint8Array([...sc.subarray(0, 2)]));
  feeder.feed(new Uint8Array([...sc.subarray(2), 0x67, 0x64, 0x00, 0x28]));
  feeder.feed(new Uint8Array([...sc, 0x68, 0xeb]));
  assert.strictEqual(nals.length, 1, 'el SPS se emite al ver el SIGUIENTE start code');
  assert.strictEqual(nals[0].type, 7);
  feeder.feed(new Uint8Array([...sc, 0x65, 0x88]));
  assert.strictEqual(nals.length, 2, 'PPS emitido');
  assert.strictEqual(nals[1].type, 8);
  ok('makeNalFeeder: start code y NALUs partidas entre mensajes');

  // 6b. assembler: nada antes de SPS+PPS+IDR; key = SPS+PPS+IDR concatenados
  const chunks = [];
  const asm = F.makeChunkAssembler((c) => chunks.push(c));
  const nal = (b) => Buffer.concat([sc, Buffer.from(b)]);
  asm.nal(1, nal([0x41, 0x01])); // delta huérfano (mitad de GOP)
  asm.nal(7, nal([0x67, 0x64, 0x00, 0x28]));
  asm.nal(8, nal([0x68, 0xeb, 0xec]));
  assert.strictEqual(chunks.length, 0, 'aún nada: falta el IDR');
  asm.nal(5, nal([0x65, 0x88]));
  assert.strictEqual(chunks.length, 1);
  assert.strictEqual(chunks[0].type, 'key');
  assert(
    Buffer.from(chunks[0].bytes).equals(
      Buffer.concat([nal([0x67, 0x64, 0x00, 0x28]), nal([0x68, 0xeb, 0xec]), nal([0x65, 0x88])]),
    ),
    'key = SPS+PPS+IDR',
  );
  assert(Buffer.from(chunks[0].spsPayload).equals(Buffer.from([0x67, 0x64, 0x00, 0x28])), 'spsPayload sin start code');
  asm.nal(1, nal([0x41, 0x02]));
  assert.strictEqual(chunks[1].type, 'delta');
  ok('makeChunkAssembler: bufferiza a mitad de GOP y agrupa SPS+PPS+IDR');

  // 6c. codec string desde el SPS real
  assert.strictEqual(F.avcCodecFromSps(Buffer.from([0x67, 0x64, 0x00, 0x28])), 'avc1.640028');
  assert.strictEqual(F.avcCodecFromSps(Buffer.from([0x67, 0x42, 0xc0, 0x1e])), 'avc1.42c01e');
  assert.strictEqual(F.avcCodecFromSps(null), 'avc1.640028');
  ok('avcCodecFromSps: avc1.PPCCLL (High@4.0 / Baseline) + fallback');

  // 6d. mapeo canvas→display
  assert.deepStrictEqual(F.mapToDevice(180, 400, 360, 800, 720, 1600), { x: 360, y: 800 });
  assert.deepStrictEqual(F.mapToDevice(10, 10, 0, 0, 720, 1600), null);
  assert.deepStrictEqual(F.mapToDevice(1, 1, 100, 100, 0, 0), null);
  ok('mapToDevice: escala exacta y guards sin dimensiones');

  // 6e. v21.9: selección de ruta del espejo H.264 (pura)
  assert.strictEqual(F.h264Route(true, true), 'adb');  // con sesión ADB, el navegador manda
  assert.strictEqual(F.h264Route(true, false), 'adb'); // USB/helper: solo existe la ruta adb
  assert.strictEqual(F.h264Route(false, true), 'server');
  assert.strictEqual(F.h264Route(false, false), null);
  ok('h264Route: adb > server > null (el navegador ES el servidor si hay sesión)');

  srv.kill('SIGKILL');
  adbd.close();
  console.log(`\n${n} comprobaciones — server v21.9 OK`);
  process.exit(0);
  } catch (e) {
    console.error('FALLO:', e.message);
    process.exit(1);
  }
})();
