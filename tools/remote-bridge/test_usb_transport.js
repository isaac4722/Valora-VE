#!/usr/bin/env node
/**
 * ─── Valora-VE · Test del transporte WebUSB sin hardware (v21.6.2) ───────────
 * Simula un USBDevice (MTK/TECNO con dos configuraciones USB) y prueba:
 *   1. findAdb encuentra la interface ADB en la configuración correcta.
 *   2. connect(hint) salta el chooser (requestDevice NO se llama) y cambia
 *      a la configuración donde vive ADB.
 *   3. claimInterface ocupado → reintento corto → diagnóstico con
 *      «adb kill-server» y device cerrado (sin dejarlo colgado).
 *   4. claimInterface ok al 2.º intento (re-enumeración del cable).
 *   5. authorized() filtra solo dispositivos con interface ADB.
 *   6. El handshake AUTH posterior usa la clave RSA (mismo camino del
 *      cliente real) — aquí solo conecta el transporte.
 */
'use strict';

const assert = require('assert');
const path = require('path');
const { AdbTransports } = require(path.join(__dirname, 'public', 'adb.js'));

// ── Stub de WebUSB ───────────────────────────────────────────────────────────
function fakeAdbAlt() {
  return {
    interfaceClass: 0xff,
    interfaceSubclass: 0x42,
    interfaceProtocol: 1,
    alternateSetting: 0,
    endpoints: [
      { type: 'bulk', direction: 'in', endpointNumber: 1 },
      { type: 'bulk', direction: 'out', endpointNumber: 2 },
    ],
  };
}

function fakeMtpAlt() {
  return { interfaceClass: 6, interfaceSubclass: 1, interfaceProtocol: 1, alternateSetting: 0, endpoints: [] };
}

function fakeDevice(opts = {}) {
  const adbAlt = fakeAdbAlt();
  const mtpAlt = fakeMtpAlt();
  const mkCfg = (v, withAdb) => ({
    configurationValue: v,
    interfaces: withAdb
      ? [{ interfaceNumber: 2, alternates: [mtpAlt] }, { interfaceNumber: 4, alternates: [adbAlt] }]
      : [{ interfaceNumber: 2, alternates: [mtpAlt] }],
  });
  const cfgs = opts.twoConfigs ? [mkCfg(1, false), mkCfg(2, true)] : [mkCfg(1, true)];
  const d = {
    productName: opts.name || 'TECNO BF6',
    serialNumber: '012345ABC',
    opened: false,
    configurationValue: 1,
    configuration: cfgs[0],
    configurations: cfgs,
    claims: [],
    _claimCalls: 0,
    _failClaims: opts.failClaims || 0,
    async open() { this.opened = true; },
    async close() { this.opened = false; },
    async selectConfiguration(v) {
      this.configurationValue = v;
      this.configuration = cfgs.find((c) => c.configurationValue === v);
    },
    async claimInterface(n) {
      this._claimCalls++;
      if (this._claimCalls <= this._failClaims) {
        const err = new TypeError('Failed to execute \'claimInterface\' on \'USBDevice\': Unable to claim interface.');
        throw err;
      }
      this.claims.push(n);
    },
    async selectAlternateInterface(n, s) { this._alt = [n, s]; },
    async transferIn() { return new Promise(() => {}); }, // read loop dormido
    async transferOut() { return { bytesWritten: 0 }; },
  };
  return d;
}

function installNavigatorUsb(devices) {
  const requested = [];
  const usb = {
    requestDevice: async () => { requested.push(1); return devices[0] || {}; },
    getDevices: async () => devices,
    addEventListener() {},
  };
  Object.defineProperty(globalThis, 'navigator', { value: { usb }, configurable: true });
  return { usb, requested };
}

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));

async function testFindAdb() {
  const single = fakeDevice();
  const f1 = AdbTransports.WebUsbTransport.findAdb(single);
  assert(f1 && f1.iface.interfaceNumber === 4, 'findAdb: interface 4 en config única');
  const dual = fakeDevice({ twoConfigs: true });
  const f2 = AdbTransports.WebUsbTransport.findAdb(dual);
  assert(f2 && f2.config.configurationValue === 2, 'findAdb: encuentra ADB en la config 2');
  const none = fakeMtpAlt(); // sin ADB
  const empty = { configurations: [{ configurationValue: 1, interfaces: [{ interfaceNumber: 0, alternates: [none] }] }] };
  assert(AdbTransports.WebUsbTransport.findAdb(empty) === null, 'findAdb: null sin interface ADB');
  console.log('1. findAdb (config única, dual, sin ADB) — OK');
}

async function testConnectHintSkipsChooser() {
  const dev = fakeDevice({ twoConfigs: true });
  const { requested } = installNavigatorUsb([dev]);
  const logs = [];
  const t = new AdbTransports.WebUsbTransport((m) => logs.push(m));
  const info = await t.connect(dev);
  assert.strictEqual(requested.length, 0, 'connect(hint) NO debe abrir el chooser');
  assert.strictEqual(info.model, 'TECNO BF6');
  assert.strictEqual(dev.configurationValue, 2, 'cambió a la configuración donde vive ADB');
  assert.deepStrictEqual(dev.claims, [4], 'interface ADB reclamada (número 4)');
  assert.deepStrictEqual(t.endpointIn, 1);
  assert.deepStrictEqual(t.endpointOut, 2);
  assert(logs.some((l) => l.includes('Config USB 1 → 2')), 'log del cambio de configuración');
  assert(logs.some((l) => l.includes('handshake')), 'log del paso a handshake');
  await t.close();
  console.log('2. connect(hint) sin chooser + cambio de configuración — OK');
}

async function testClaimBusyDiagnosis() {
  const dev = fakeDevice({ failClaims: 99 });
  installNavigatorUsb([dev]);
  const t = new AdbTransports.WebUsbTransport(() => {});
  await assert.rejects(
    () => t.connect(dev),
    (e) => e.message.includes('adb kill-server') && e.message.includes('Google USB driver'),
    'claim ocupado → diagnóstico con adb kill-server',
  );
  assert.strictEqual(dev.opened, false, 'device cerrado tras el fallo (no queda colgado)');
  console.log('3. claimInterface ocupado → diagnóstico honesto y cierre limpio — OK');
}

async function testClaimRetrySucceeds() {
  const dev = fakeDevice({ failClaims: 1 }); // falla UNA vez, éxito en el reintento
  installNavigatorUsb([dev]);
  const t = new AdbTransports.WebUsbTransport(() => {});
  const info = await t.connect(dev);
  assert.strictEqual(dev._claimCalls, 2, 'reintento corto tras el primer fallo');
  assert.strictEqual(info.model, 'TECNO BF6');
  await t.close();
  console.log('4. claimInterface con éxito en el 2.º intento (re-enumeración) — OK');
}

async function testAuthorizedFilter() {
  const adbDev = fakeDevice();
  const other = { productName: 'Disco USB', configurations: [] };
  installNavigatorUsb([adbDev, other]);
  const devs = await AdbTransports.WebUsbTransport.authorized();
  assert.strictEqual(devs.length, 1, 'authorized() filtra solo ADB');
  assert.strictEqual(devs[0].productName, 'TECNO BF6');
  console.log('5. authorized() filtra dispositivos con interface ADB — OK');
}

async function testWsTransportStillWorks() {
  // El cambio de firma (hint opcional) no rompe el camino Wi-Fi.
  const t = new AdbTransports.WsTransport('ws://127.0.0.1:1', () => {});
  let rejected = false;
  try {
    await t.connect();
  } catch (_) {
    rejected = true; // puerto cerrado → rechaza como siempre
  }
  assert(rejected, 'WS a puerto cerrado rechaza');
  console.log('6. WsTransport intacto tras el cambio de firma — OK');
}

(async () => {
  await testFindAdb();
  await testConnectHintSkipsChooser();
  await testClaimBusyDiagnosis();
  await testClaimRetrySucceeds();
  await testAuthorizedFilter();
  await testWsTransportStillWorks();
  console.log('6/6 — transporte WebUSB verificado sin hardware');
})().catch((e) => {
  console.error('FALLO:', e.message);
  process.exit(1);
});
