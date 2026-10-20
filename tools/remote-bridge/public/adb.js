/**
 * ─── ADB daemon mínimo en JavaScript (v21.6 · Valora-VE) ────────────────────
 * Implementación propia del protocolo ADB (CNXN/AUTH/OPEN/OKAY/WRTE/CLSE)
 * con dos transportes intercambiables:
 *   · WebUSB — el teléfono conectado por CABLE al navegador del dueño
 *     (interface ADB: class 0xFF · subclass 0x42 · protocol 1).
 *   · WebSocket — el helper local (adb-ws-helper.js) que puentea TCP al
 *     ADB del teléfono en Wi-Fi (modo `adb tcpip 5555`).
 *
 * Sin dependencias: WebCrypto firma los retos AUTH TOKEN (RSA-SHA1) y
 * construye la clave pública en el formato propio de ADB
 * (len·n0inv·n·rr·exponente, base64 + nombre + NUL).
 *
 * Servicios usados por el puente: `exec:` (screencap/input binario-seguro),
 * `shell:` (comandos de texto) y `tcp:<puerto>` (HTTP directo al servidor
 * de pruebas de la app: /health /test /erase /nav).
 */
'use strict';

const A_CNXN = 0x434e584e;
const A_AUTH = 0x41755448;
const A_OPEN = 0x4f50454e;
const A_OKAY = 0x4f4b4159;
const A_WRTE = 0x57525445;
const A_CLSE = 0x434c5345;
const A_VERSION = 0x01000001;
const A_MAXDATA = 4096;
const AUTH_TOKEN = 1;
const AUTH_SIGNATURE = 2;
const AUTH_RSAPUBLICKEY = 3;

/** Suma de bytes del payload mod 2^32 (checksum ADB). */
function checksum(bytes) {
  let s = 0;
  for (let i = 0; i < bytes.length; i++) s += bytes[i];
  return s >>> 0;
}

function enc(str) {
  return new TextEncoder().encode(str);
}

/** Empaqueta una cabecera ADB de 24 bytes little-endian. */
function header(cmd, arg0, arg1, dataLen, dataSum) {
  const h = new ArrayBuffer(24);
  const v = new DataView(h);
  v.setUint32(0, cmd, true);
  v.setUint32(4, arg0, true);
  v.setUint32(8, arg1, true);
  v.setUint32(12, dataLen, true);
  v.setUint32(16, dataSum, true);
  v.setUint32(20, cmd ^ 0xffffffff, true);
  return new Uint8Array(h);
}

// ── Claves RSA del puente (formato ADB) ──────────────────────────────────────
const AdbKeys = {
  NAME: 'valora-bridge',

  async load() {
    if (typeof crypto === 'undefined' || !crypto.subtle) {
      throw new Error(
        'WebCrypto no disponible — abre el cliente por HTTPS (preview) o http://127.0.0.1 (página local del helper)',
      );
    }
    let saved = null;
    try { saved = localStorage.getItem('valora.adbkey'); } catch (_) {}
    if (saved) {
      try {
        const jwk = JSON.parse(saved);
        const priv = await crypto.subtle.importKey(
          'jwk',
          jwk,
          { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-1' },
          true,
          ['sign'],
        );
        return { jwk, priv };
      } catch (_) {
        try { localStorage.removeItem('valora.adbkey'); } catch (_) {}
      }
    }
    // RsaHashedKeyGenParams EXIGE modulusLength y publicExponent; ADB exige
    // RSA-2048 con SHA-1 (adbd rechaza claves de otra longitud).
    const pair = await crypto.subtle.generateKey(
      {
        name: 'RSASSA-PKCS1-v1_5',
        modulusLength: 2048,
        publicExponent: new Uint8Array([0x01, 0x00, 0x01]), // 65537
        hash: 'SHA-1',
      },
      true,
      ['sign'],
    );
    const jwk = await crypto.subtle.exportKey('jwk', pair.privateKey);
    try { localStorage.setItem('valora.adbkey', JSON.stringify(jwk)); } catch (_) {}
    return { jwk, priv: pair.privateKey };
  },

  /** b64url de JWK → bytes grandes-endian. */
  _b64uToBytes(s) {
    const pad = '='.repeat((4 - (s.length % 4)) % 4);
    const raw = atob(s.replace(/-/g, '+').replace(/_/g, '/') + pad);
    return Uint8Array.from(raw, (c) => c.charCodeAt(0));
  },

  /** Clave pública en formato ADB (android_pubkey.c): len|n0inv|n|rr|e. */
  async publicKeyAdb(key) {
    const nB = this._b64uToBytes(key.jwk.n);
    const eB = this._b64uToBytes(key.jwk.e);
    let n = 0n;
    for (const b of nB) n = (n << 8n) | BigInt(b);
    let e = 0n;
    for (const b of eB) e = (e << 8n) | BigInt(b);

    const bits = nB.length * 8;
    const words = bits / 32;
    const WORDS = BigInt(words);
    const M32 = 1n << 32n;

    // n0inv = -1/n mod 2^32 — inverso modular de n (impar) vía Euler:
    // n^(2^31 - 1) ≡ n^(-1) (mod 2^32).
    const inv = this._powMod(n, (1n << 31n) - 1n, M32);
    const n0inv = (M32 - inv) % M32;
    // rr = R^2 mod n con R = 2^bits (parametrización Montgomery de ADB).
    const rr = (1n << BigInt(bits) * 2n) % n;

    const out = new Uint8Array(4 + 4 + words * 4 + words * 4 + 4);
    const dv = new DataView(out.buffer);
    dv.setUint32(0, words, false); // len en palabras (big-endian en struct)
    dv.setUint32(4, Number(n0inv), false);
    out.set(nB, 8); // módulo ya en big-endian
    const rrB = this._bigToBytes(rr, words * 4);
    out.set(rrB, 8 + words * 4);
    dv.setUint32(8 + words * 4 * 2, Number(e), false);

    const b64 = btoa(String.fromCharCode(...out));
    return b64 + ' ' + this.NAME + '\0';
  },

  _bigToBytes(v, size) {
    const out = new Uint8Array(size);
    for (let i = size - 1; i >= 0; i--) {
      out[i] = Number(v & 0xffn);
      v >>= 8n;
    }
    return out;
  },

  _powMod(b, e, m) {
    let r = 1n;
    b %= m;
    while (e > 0n) {
      if (e & 1n) r = (r * b) % m;
      b = (b * b) % m;
      e >>= 1n;
    }
    return r;
  },

  async sign(key, tokenBytes) {
    const sig = await crypto.subtle.sign(
      { name: 'RSASSA-PKCS1-v1_5' },
      key.priv,
      tokenBytes,
    );
    return new Uint8Array(sig);
  },
};

// ── Transportes ──────────────────────────────────────────────────────────────
/** WebUSB: cable USB directo al navegador (Chrome/Edge escritorio). */
class WebUsbTransport {
  constructor(log) {
    this.log = log;
    this.device = null;
    this.endpointIn = null;
    this.endpointOut = null;
    this.onMessage = null;
    this.onDisconnect = null;
  }

  /** Interfaces ADB (class 0xFF · subclass 0x42 · protocol 1|2) de un USBDevice.
   *  Devuelve { config, iface, alt } o null. Algunos teléfonos (MTK/TECNO)
   *  exponen varias configuraciones y ADB no siempre está en la primera. */
  static findAdb(device) {
    const isAdb = (a) =>
      a.interfaceClass === 0xff &&
      a.interfaceSubclass === 0x42 &&
      (a.interfaceProtocol === 1 || a.interfaceProtocol === 2);
    const configs = device.configurations && device.configurations.length
      ? device.configurations
      : (device.configuration ? [device.configuration] : []);
    for (const c of configs) {
      for (const i of c.interfaces) {
        const a = i.alternates.find(isAdb);
        if (a) return { config: c, iface: i, alt: a };
      }
    }
    return null;
  }

  /** Dispositivos USB YA autorizados en este origen — sirve para reconectar
   *  sin el chooser (abrir la página y que conecte solo). */
  static async authorized() {
    if (typeof navigator === 'undefined' || !navigator.usb) return [];
    const devs = await navigator.usb.getDevices();
    const out = [];
    for (const d of devs) {
      try { if (WebUsbTransport.findAdb(d)) out.push(d); } catch (_) {}
    }
    return out;
  }

  static _claimHelp(e) {
    return (
      'Chrome no pudo tomar la interface ADB del teléfono (' + (e.message || e) + '). ' +
      'Casi siempre OTRO programa de tu PC ya la tiene tomada: ' +
      '① corre «adb kill-server» en tu PC (el adb de consola sigue vivo) y cierra Android Studio/scrcpy/Vysor; ' +
      '② desconecta y vuelve a meter el cable; ' +
      '③ cambia el modo USB del teléfono (Transferir archivos ⇄ Solo carga) para re-enumerar; ' +
      '④ (Windows, solo la primera vez) instala el driver WinUSB — Google USB driver. ' +
      'Luego pulsa «Conectar por USB» otra vez.'
    );
  }

  /** Conecta. `hint` = USBDevice ya autorizado (sin chooser) — opcional. */
  async connect(hint) {
    let device = hint || null;
    if (!device) {
      if (typeof navigator === 'undefined' || !navigator.usb) {
        throw new Error('WebUSB no disponible — usa Chrome o Edge de escritorio para el modo USB');
      }
      device = await navigator.usb.requestDevice({
        filters: [
          { classCode: 0xff, subclassCode: 0x42, protocolCode: 1 },
          { classCode: 0xff, subclassCode: 0x42, protocolCode: 2 },
        ],
      });
    }
    this.device = device;
    this.log(
      'USB: ' + (device.productName || device.manufacturerName || 'Android') +
      (device.serialNumber ? ' · serie ' + device.serialNumber : ''),
    );
    await device.open();

    // Elige la configuración que CONTENGA la interface ADB (no siempre la 1).
    const found = WebUsbTransport.findAdb(device);
    if (!found) {
      try { await device.close(); } catch (_) {}
      throw new Error('Interface ADB no encontrada — activa «Depuración USB» en el teléfono y reconecta el cable');
    }
    if (device.configurationValue !== found.config.configurationValue) {
      this.log('Config USB ' + device.configurationValue + ' → ' + found.config.configurationValue + ' (donde vive ADB)');
      await device.selectConfiguration(found.config.configurationValue);
    }
    const { iface, alt } = found;

    // claimInterface: reintento corto — adbd a veces libera la interface
    // a mitad de la re-enumeración del cable.
    try {
      await device.claimInterface(iface.interfaceNumber);
    } catch (e1) {
      await new Promise((r) => setTimeout(r, 500));
      try {
        await device.claimInterface(iface.interfaceNumber);
      } catch (_) {
        try { await device.close(); } catch (_) {}
        throw new Error(WebUsbTransport._claimHelp(e1));
      }
    }
    await device.selectAlternateInterface(iface.interfaceNumber, alt.alternateSetting);
    for (const ep of alt.endpoints) {
      if (ep.type !== 'bulk') continue;
      if (ep.direction === 'in') this.endpointIn = ep.endpointNumber;
      if (ep.direction === 'out') this.endpointOut = ep.endpointNumber;
    }
    if (this.endpointIn === null || this.endpointOut === null) {
      throw new Error('Endpoints bulk ADB no encontrados');
    }
    this.log('Interface ADB tomada (endpoints ' + this.endpointIn + '/' + this.endpointOut + ') — handshake…');
    navigator.usb.addEventListener('disconnect', () => {
      if (this.onDisconnect) this.onDisconnect();
    });
    this._readLoop();
    return {
      model: device.productName || 'Android',
      serial: device.serialNumber || '',
    };
  }

  async _readLoop() {
    try {
      while (this.device && this.device.opened) {
        const r = await this.device.transferIn(this.endpointIn, 16 * 1024);
        if (r.status === 'stalled') {
          await this.device.clearHalt('in', this.endpointIn);
          continue;
        }
        if (r.data && r.data.byteLength && this.onMessage) {
          this.onMessage(new Uint8Array(r.data.buffer, r.data.byteOffset, r.data.byteLength));
        }
      }
    } catch (e) {
      this.log('USB read fin: ' + e.message);
      if (this.onDisconnect) this.onDisconnect();
    }
  }

  async write(bytes) {
    await this.device.transferOut(this.endpointOut, bytes);
  }

  async close() {
    try {
      if (this.device && this.device.opened) await this.device.close();
    } catch (_) { /* ya cerrado */ }
  }
}

/** WebSocket hacia adb-ws-helper.js (Wi-Fi, helper en la PC del dueño). */
class WsTransport {
  constructor(url, log) {
    this.url = url;
    this.log = log;
    this.ws = null;
    this.onMessage = null;
    this.onDisconnect = null;
  }

  connect() {
    return new Promise((resolve, reject) => {
      const ws = new WebSocket(this.url);
      ws.binaryType = 'arraybuffer';
      this.ws = ws;
      ws.onopen = () =>
        resolve({ model: 'Android (Wi-Fi)', serial: this.url });
      ws.onerror = () => reject(new Error('No se pudo abrir el WebSocket del helper'));
      ws.onmessage = (ev) => {
        if (this.onMessage) this.onMessage(new Uint8Array(ev.data));
      };
      ws.onclose = () => {
        if (this.onDisconnect) this.onDisconnect();
      };
    });
  }

  async write(bytes) {
    if (this.ws.readyState !== 1) throw new Error('Helper WebSocket cerrado');
    this.ws.send(bytes);
  }

  async close() {
    try {
      this.ws.close();
    } catch (_) { /* ya cerrado */ }
  }
}

// ── Conexión ADB ─────────────────────────────────────────────────────────────
class AdbConnection {
  /**
   * @param transport instancia WebUsbTransport | WsTransport (sin conectar)
   * @param log fn para trazas
   */
  constructor(transport, log) {
    this.t = transport;
    this.log = log || (() => {});
    this.maxData = A_MAXDATA;
    this.nextLocalId = 1;
    /** localId → {service, remoteId, chunks, resolveOpen, onData, onClose} */
    this.streams = new Map();
    this._buf = new Uint8Array(0);
    this.t.onMessage = (b) => this._feed(b);
  }

  /** Handshake completo (CNXN + AUTH). Devuelve info del dispositivo.
   *  `hint` = USBDevice ya autorizado (transporte WebUSB, sin chooser). */
  async connect(hint) {
    const info = await this.t.connect(hint);
    this.key = await AdbKeys.load();
    this.t.onDisconnect = () => this._dropAll(new Error('transporte desconectado'));

    this._send(A_CNXN, A_VERSION, A_MAXDATA, enc('host::features=shell_v2,cmd,stat_v2,ls_v2'));

    let authAttempts = 0;
    let waitMs = 60000;
    for (;;) {
      const msg = await this._waitMessage(
        (m) => m.cmd === A_CNXN || m.cmd === A_AUTH,
        waitMs,
      );
      if (msg.cmd === A_CNXN) {
        this.maxData = msg.arg1 || A_MAXDATA;
        return info;
      }
      if (msg.arg0 === AUTH_TOKEN) {
        if (authAttempts < 2) {
          const sig = await AdbKeys.sign(this.key, msg.data);
          this._send(A_AUTH, AUTH_SIGNATURE, 0, sig);
        } else {
          // El teléfono no conoce la clave: publica y pide confirmación.
          const pub = await AdbKeys.publicKeyAdb(this.key);
          this._send(A_AUTH, AUTH_RSAPUBLICKEY, 0, enc(pub));
          if (authAttempts === 2) {
            this.log(
              'Clave publicada — MIRA EL TELÉFONO: acepta «Permitir depuración USB» de valora-bridge (ideal: marca «Siempre permitir»)',
            );
            waitMs = 180000; // tiempo de sobra para aceptar en el teléfono
          }
        }
        authAttempts++;
      }
    }
  }

  /** Abre un stream de servicio. Resuelve (OKAY del dispositivo) con el
   *  PROPIO registro del stream — s.localId, s.remoteId, s.write/stream.
   *  v21.8: los comandos pelados («wm size», «input tap …») viajan como
   *  `shell:<cmd>` — adbd rechaza servicios desconocidos; los prefijos
   *  conocidos (exec:/tcp:/sync:/…) pasan intactos. */
  open(service, { onData, onClose } = {}) {
    const KNOWN = /^(shell:|exec:|tcp:|localabstract:|localfilesystem:|localreserved:|sync:|jdwp:|framebuffer:|track-|reverse:|host:|root:|usb:|abb:|abb_exec:|features:|reconnect:|banner:|mdns:|pair:|tls:)/;
    const svc = KNOWN.test(service) ? service : 'shell:' + service;
    return new Promise((resolve, reject) => {
      const localId = this.nextLocalId++;
      const s = {
        localId,
        service: svc,
        remoteId: 0,
        closed: false,
        chunks: [],
        // v21.8: sin onData la WRTE entrante debe ACUMULARSE (exec lo espera);
        // antes se caía en `else if (s.collect)` y exec devolvía vacío.
        collect: !onData,
        onData,
        onClose,
        resolve,
        reject,
        timer: setTimeout(() => {
          this.streams.delete(localId);
          reject(new Error('OPEN sin respuesta: ' + service));
        }, 15000),
      };
      this.streams.set(localId, s);
      this._send(A_OPEN, localId, 0, enc(svc));
    });
  }

  /** Comando one-shot por `exec:`/`shell:` — devuelve toda la salida. */
  async exec(command, timeoutMs = 30000) {
    const s = await this.open(command);
    const chunks = s.chunks;
    return new Promise((resolve, reject) => {
      s.timer = setTimeout(() => {
        this.streams.delete(s.localId);
        s.onClose(new Error('exec timeout: ' + command));
      }, timeoutMs);
      s.onClose = (err) => {
        clearTimeout(s.timer);
        if (err) return reject(err);
        const total = chunks.reduce((a, b) => a + b.length, 0);
        const out = new Uint8Array(total);
        let off = 0;
        for (const c of chunks) {
          out.set(c, off);
          off += c.length;
        }
        resolve(out);
      };
    });
  }

  /** Escribe al stream (tcp:). */
  async writeStream(localId, bytes) {
    const s = this.streams.get(localId);
    if (!s || !s.remoteId) throw new Error('stream no abierto');
    for (let off = 0; off < bytes.length; off += this.maxData) {
      const chunk = bytes.subarray(off, Math.min(off + this.maxData, bytes.length));
      this._send(A_WRTE, s.localId, s.remoteId, chunk);
      await this._waitOk(s.localId);
    }
  }

  async closeStream(localId) {
    const s = this.streams.get(localId);
    if (s && s.remoteId) this._send(A_CLSE, s.localId, s.remoteId);
    this.streams.delete(localId);
  }

  async _waitOk(localId) {
    await this._waitMessage(
      (m) => m.cmd === A_OKAY && m.arg1 === localId,
      10000,
    );
  }

  // ── Framing ────────────────────────────────────────────────────────────────
  _send(cmd, arg0, arg1, data) {
    const d = data || new Uint8Array(0);
    this.t.write(header(cmd, arg0, arg1, d.length, checksum(d)));
    if (d.length) this.t.write(d);
  }

  _feed(bytes) {
    const merged = new Uint8Array(this._buf.length + bytes.length);
    merged.set(this._buf);
    merged.set(bytes, this._buf.length);
    this._buf = merged;

    while (this._buf.length >= 24) {
      const dv = new DataView(this._buf.buffer, this._buf.byteOffset);
      const cmd = dv.getUint32(0, true);
      const magic = dv.getUint32(20, true);
      // v21.8: el XOR hay que traerlo a SIN SIGNO (>>> 0) — getUint32 devuelve
      // sin signo y el XOR int32 puede ser negativo; sin el >>> 0 CADA frame
      // se leía como corrupto y el handshake nunca completaba (lo destapó el
      // adbd mock del test v21.8; contra el teléfono real no se había llegado).
      if (((cmd ^ 0xffffffff) >>> 0) !== magic) {
        // Frame corrupto: descarta un byte y reintenta (resincroniza).
        this._buf = this._buf.subarray(1);
        continue;
      }
      const arg0 = dv.getUint32(4, true);
      const arg1 = dv.getUint32(8, true);
      const len = dv.getUint32(12, true);
      if (this._buf.length < 24 + len) break; // payload incompleto
      const data = this._buf.subarray(24, 24 + len);
      this._buf = this._buf.subarray(24 + len);
      this._dispatch({ cmd, arg0, arg1, data });
    }
  }

  _waiters = [];

  _waitMessage(pred, timeoutMs) {
    return new Promise((resolve, reject) => {
      const w = {
        pred,
        resolve,
        reject,
        timer: setTimeout(() => {
          this._waiters = this._waiters.filter((x) => x !== w);
          reject(new Error('timeout esperando mensaje ADB'));
        }, timeoutMs),
      };
      this._waiters.push(w);
    });
  }

  _dispatch(m) {
    // Esperas globales (CNXN/AUTH, OKAY de writes).
    for (const w of [...this._waiters]) {
      if (w.pred(m)) {
        this._waiters = this._waiters.filter((x) => x !== w);
        clearTimeout(w.timer);
        w.resolve(m);
        if (m.cmd === A_OKAY) return; // los OKAY no abren streams
      }
    }

    switch (m.cmd) {
      case A_OKAY: {
        // OKAY del dispositivo a nuestro OPEN: arg0 = stream remoto,
        // arg1 = nuestro localId. El registro resuelto ES el stream.
        const s = this.streams.get(m.arg1);
        if (s && !s.remoteId) {
          s.remoteId = m.arg0;
          clearTimeout(s.timer);
          s.resolve(s);
        }
        break;
      }
      case A_WRTE: {
        const s = this.streams.get(m.arg1);
        if (s) {
          if (s.onData) s.onData(m.data);
          else if (s.collect) s.chunks.push(m.data);
          this._send(A_OKAY, s.localId, s.remoteId);
        }
        break;
      }
      case A_CLSE: {
        const s = this.streams.get(m.arg1);
        if (s) {
          s.closed = true;
          clearTimeout(s.timer);
          this.streams.delete(m.arg1);
          if (s.onClose) s.onClose(null);
        }
        break;
      }
      default:
        break;
    }
  }

  _dropAll(err) {
    // También despierta a las esperas globales (CNXN/AUTH/OKAY): si el
    // transporte muere a mitad del handshake no debe colgar 60 s.
    const waiters = this._waiters.splice(0);
    for (const w of waiters) {
      clearTimeout(w.timer);
      w.reject(err);
    }
    for (const id of [...this.streams.keys()]) {
      const s = this.streams.get(id);
      this.streams.delete(id);
      if (s.onClose) s.onClose(err);
      if (s.reject) s.reject(err);
    }
  }
}

// ── API de alto nivel para el puente ─────────────────────────────────────────
/**
 * Cliente ADB completo: conexión + helpers de captura, entrada y HTTP
 * contra el servidor de pruebas de la app (tcp:8090).
 */
class ValoraAdb {
  constructor(transport, log) {
    this.log = log;
    this.conn = new AdbConnection(transport, log);
  }

  async connect(hint) {
    const info = await this.conn.connect(hint);
    try {
      const size = await this.conn.exec('wm size', 10000);
      const m = new TextDecoder().decode(size).match(/(\d+)x(\d+)/);
      info.resolution = m ? { w: +m[1], h: +m[2] } : null;
    } catch (_) {
      info.resolution = null;
    }
    return info;
  }

  /** Captura PNG completa (exec: es binario-seguro, sin pty). */
  async screenshot() {
    return this.conn.exec('exec:screencap -p', 45000);
  }

  async tap(x, y) {
    return this.conn.exec(`input tap ${Math.round(x)} ${Math.round(y)}`, 15000);
  }

  async swipe(x1, y1, x2, y2, ms = 300) {
    return this.conn.exec(
      `input swipe ${Math.round(x1)} ${Math.round(y1)} ${Math.round(x2)} ${Math.round(y2)} ${Math.round(ms)}`,
      20000,
    );
  }

  async text(str) {
    const safe = str.replace(/([\\ "$`!&*();<>?[\]{}|~])/g, '\\$1');
    return this.conn.exec(`input text ${safe}`, 20000);
  }

  async key(keycode) {
    return this.conn.exec(`input keyevent ${keycode}`, 15000);
  }

  async shell(cmd) {
    return this.conn.exec(cmd, 30000);
  }

  /**
   * HTTP de una petición contra el servidor de pruebas de la app por el
   * servicio tcp:8090 de ADB — exactamente como `adb forward`, pero vivo
   * en el navegador. path ejemplo: '/health', '/test?scenario=cart'.
   */
  async appHttp(path, { token } = {}) {
    const s = await this.conn.open('tcp:8090');
    const chunks = [];
    s.onData = (b) => chunks.push(b);
    const req =
      `GET ${path} HTTP/1.1\r\n` +
      `Host: 127.0.0.1:8090\r\n` +
      'Accept: application/json\r\n' +
      'Connection: close\r\n' +
      (token ? `x-valora-token: ${token}\r\n` : '') +
      '\r\n';
    return new Promise((resolve, reject) => {
      s.timer = setTimeout(() => {
        this.conn.streams.delete(s.localId);
        reject(new Error('app timeout: ' + path));
      }, 20000);
      s.onClose = (err) => {
        clearTimeout(s.timer);
        if (err) return reject(err);
        const total = chunks.reduce((a, b) => a + b.length, 0);
        const raw = new Uint8Array(total);
        let off = 0;
        for (const c of chunks) {
          raw.set(c, off);
          off += c.length;
        }
        const text = new TextDecoder().decode(raw);
        const idx = text.indexOf('\r\n\r\n');
        const headers = idx >= 0 ? text.slice(0, idx) : '';
        const payload = idx >= 0 ? raw.subarray(idx + 4) : raw;
        let status = 0;
        const sm = headers.match(/HTTP\/1\.[01] (\d+)/);
        if (sm) status = +sm[1];
        let json = null;
        try {
          json = JSON.parse(new TextDecoder().decode(payload));
        } catch (_) {
          /* respuesta no-JSON */
        }
        resolve({ status, headers, json, raw: payload });
      };
      this.conn.writeStream(s.localId, enc(req)).catch(reject);
    });
  }
}

if (typeof window !== 'undefined') {
  window.ValoraAdb = ValoraAdb;
  window.AdbTransports = { WebUsbTransport, WsTransport };
}
if (typeof module !== 'undefined') {
  module.exports = { ValoraAdb, AdbKeys, AdbTransports: { WebUsbTransport, WsTransport } };
}
