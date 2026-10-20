#!/usr/bin/env node
/**
 * ─── Valora-VE · Test de muerte del transporte ADB (v21.8.1) ────────────────
 * Regresión de los errores REALES vistos en la consola del dueño:
 *   · «Uncaught (in promise) TypeError: Cannot read properties of null
 *     (reading 'transferOut')» — write() sobre WebUsbTransport muerto y
 *     nadie atrapando (el executor de open() dispara _send sin await).
 *   · «Uncaught (in promise) Error: Helper WebSocket cerrado» — lo mismo
 *     por el transporte WS a mitad de una reconexión.
 *   · streamLoop martillando cada 1.5 s para siempre con adb «zombi».
 * Verifica:
 *   1-3. Los writes sobre transporte muerto dan errores LIMPIOS (no TypeError
 *        de null) que el puente entiende y muestra.
 *   4.   Un write que falla durante el handshake mata la conexión UNA vez y
 *        connect() rechaza RÁPIDO con el error real (no cuelga 60 s).
 *   5-6. Un write que falla en OPEN rechaza exec()/open() con el error real
 *        y onDead dispara EXACTAMENTE una vez pese a seguir martillando.
 *   7.   open() sobre conexión muerta rechaza AL INSTANTE (no 15 s).
 *   8.   La desconexión del transporte con un exec pendiente lo despierta y
 *        ValoraAdb reenvía onDead a la página.
 *   9.   CENTINELA: cero «unhandledRejection» en todo el proceso — la
 *        regresión exacta de la consola del dueño, si vuelve, el test muere.
 */
'use strict';

const assert = require('assert');
const path = require('path');
const { ValoraAdb, AdbTransports } = require(path.join(__dirname, 'public', 'adb.js'));

let unhandled = 0;
process.on('unhandledRejection', (r) => {
  unhandled++;
  console.error('UNHANDLED #' + unhandled + ':', r && (r.stack || r.message || r));
});
const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

// ── Transporte falso: escribe bien hasta el write N (1-based; Infinity=siempre) ─
class FakeTransport {
  constructor(failWriteAt = Infinity) {
    this.onMessage = null;
    this.onDisconnect = null;
    this.writes = 0;
    this.failWriteAt = failWriteAt;
    this.writeErr = new Error('cable arrancado');
  }
  async connect() { return { model: 'Fake', serial: 'X' }; }
  async write() {
    this.writes++;
    if (this.writes >= this.failWriteAt) throw this.writeErr;
  }
  async close() {}
}

// ── Frames ADB mínimos (misma codificación de adb.js) ────────────────────────
const A_CNXN = 0x434e584e;
function adbFrame(cmd, arg0, arg1, data = new Uint8Array(0)) {
  const b = new ArrayBuffer(24 + data.length);
  const v = new DataView(b);
  const sum = [...data].reduce((a, x) => a + x, 0) >>> 0;
  v.setUint32(0, cmd, true);
  v.setUint32(4, arg0, true);
  v.setUint32(8, arg1, true);
  v.setUint32(12, data.length, true);
  v.setUint32(16, sum, true);
  v.setUint32(20, (cmd ^ 0xffffffff) >>> 0, true);
  new Uint8Array(b).set(data, 24);
  return new Uint8Array(b);
}

/** Conecta una AdbConnection contra un CNXN directo (sin AUTH, como adbd con
 *  clave ya autorizada): alimenta la respuesta justo tras el _send CNXN. */
async function connectFast(conn, t) {
  const origSend = conn._send.bind(conn);
  conn._send = (cmd, a0, a1, d) => {
    origSend(cmd, a0, a1, d);
    if (cmd === A_CNXN) {
      const max = 1024 * 1024;
      // arg1 de CNXN = maxdata del dispositivo (se lee de arg1 en el cliente)
      setImmediate(() => t.onMessage(adbFrame(A_CNXN, 0x01000001, max)));
    }
  };
  return conn.connect();
}

async function testWritesLimpios() {
  const usb = new AdbTransports.WebUsbTransport(() => {});
  usb.device = null;
  await assert.rejects(
    () => usb.write(new Uint8Array(8)),
    (e) => e.message.includes('Transporte USB cerrado'),
    'write USB con device null → error limpio (no TypeError)',
  );
  usb.device = { opened: false };
  await assert.rejects(
    () => usb.write(new Uint8Array(8)),
    (e) => e.message.includes('Transporte USB cerrado'),
    'write USB con device cerrado → error limpio',
  );
  const ws = new AdbTransports.WsTransport('ws://127.0.0.1:1', () => {});
  ws.ws = null;
  await assert.rejects(
    () => ws.write(new Uint8Array(8)),
    (e) => e.message.includes('Helper WebSocket cerrado'),
    'write WS con ws null → error limpio (no TypeError)',
  );
  ws.ws = { readyState: 0 };
  await assert.rejects(
    () => ws.write(new Uint8Array(8)),
    (e) => e.message.includes('Helper WebSocket cerrado'),
    'write WS en CONNECTING → error limpio',
  );
  console.log('1. Writes sobre transporte muerto → errores limpios — OK');
}

async function testMuerteEnHandshake() {
  const t = new FakeTransport(1); // el PRIMER write (CNXN) ya falla
  const conn = new ValoraAdb(t, () => {});
  let deadCalls = 0;
  adb_onDead(conn, () => deadCalls++);
  const t0 = Date.now();
  await assert.rejects(
    () => conn.connect(),
    (e) => e.message === 'cable arrancado',
    'connect() rechaza con el error REAL del write',
  );
  const dt = Date.now() - t0;
  assert(dt < 5000, 'muerte en handshake NO cuelga los 60 s (tardó ' + dt + ' ms)');
  await sleep(20);
  assert.strictEqual(deadCalls, 1, 'onDead dispara UNA vez');
  console.log('2. Muerte en handshake: rápida, error real, onDead ×1 — OK');
}

async function testMuerteEnOpen() {
  // Los writes son POR PAQUETE: el frame CNXN son 2 writes (cabecera + payload),
  // así que el OPEN que debe morir es el write #3.
  const t = new FakeTransport(3); // CNXN (#1,#2) ok, OPEN (#3) falla
  const adb = new ValoraAdb(t, () => {});
  let deadCalls = 0;
  adb.onDead = () => deadCalls++;
  await connectFast(adb.conn, t); // handshake completo (CNXN del falso peer)
  await assert.rejects(
    () => adb.screenshot(), // exec → open → _send OPEN → write muere
    (e) => e.message === 'cable arrancado',
    'exec() rechaza con el error real (sin «Uncaught (in promise)»)',
  );
  // Martillar tras la muerte: rechazos inmediatos, onDead sigue en 1.
  for (let i = 0; i < 3; i++) {
    await assert.rejects(() => adb.screenshot(), /cable arrancado/);
  }
  await sleep(20);
  assert.strictEqual(deadCalls, 1, 'onDead UNA vez pese a 3 reintentos');
  console.log('2b. Muerte en OPEN: error real al exec, onDead ×1 martillando — OK');
}

async function testOpenRechazaAlInstante() {
  const t = new FakeTransport(1);
  const conn = new ValoraAdb(t, () => {});
  conn.onDead = () => {};
  await assert.rejects(() => conn.connect(), /cable arrancado/);
  const t0 = Date.now();
  await assert.rejects(
    () => conn.conn.open('shell:echo x'), // AdbConnection vive dentro de ValoraAdb
    (e) => e.message === 'cable arrancado',
    'open() sobre conexión muerta rechaza con el error de la muerte',
  );
  assert(Date.now() - t0 < 1000, 'open() muerto NO espera el timeout de 15 s');
  console.log('3. open() sobre conexión muerta: rechazo al instante — OK');
}

async function testDesconexionConExecPendiente() {
  const t = new FakeTransport(); // escribe bien siempre
  const adb = new ValoraAdb(t, () => {});
  let deadMsg = '';
  adb.onDead = (e) => { deadMsg = e.message; };
  await connectFast(adb.conn, t);
  const pending = adb.screenshot(); // OPEN enviado, sin respuesta
  t.onDisconnect(); // el «cable» se va con el exec en vuelo
  await assert.rejects(
    () => pending,
    (e) => e.message === 'transporte desconectado',
    'exec pendiente despierta con el error de desconexión',
  );
  assert.strictEqual(deadMsg, 'transporte desconectado', 'ValoraAdb reenvía onDead a la página');
  console.log('4. Desconexión con exec en vuelo: despertar + onDead reenviado — OK');
}

/** Puente de suscripción idéntico al que hace ValoraAdb en su constructor. */
function adb_onDead(adb, fn) { adb.onDead = fn; }

(async () => {
  await testWritesLimpios();
  await testMuerteEnHandshake();
  await testMuerteEnOpen();
  await testOpenRechazaAlInstante();
  await testDesconexionConExecPendiente();
  await sleep(150); // margen para que CUALQUIER rechazo huérfano aparezca
  assert.strictEqual(unhandled, 0, 'CENTINELA: ' + unhandled + ' unhandledRejection (la regresión de la consola del dueño)');
  console.log('5. Centinela: 0 «Uncaught (in promise)» en todo el proceso — OK');
  console.log('5/5 — muerte del transporte verificada sin hardware');
  process.exit(0);
})().catch(async (e) => {
  console.error('FALLO:', e.message);
  await sleep(150);
  process.exit(1);
});
