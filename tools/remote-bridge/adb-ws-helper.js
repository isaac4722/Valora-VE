#!/usr/bin/env node
/**
 * ─── Valora-VE · Helper ADB sobre Wi-Fi (v21.6) ──────────────────────────────
 * Un navegador NO puede abrir sockets TCP crudos: para ADB por Wi-Fi este
 * helper corre EN LA PC DEL DUEÑO y puentea WebSocket local ↔ TCP al puerto
 * ADB del teléfono. Cero nube, cero pago: todo queda en tu red local.
 *
 * Preparación (una sola vez, con el teléfono por USB y platform-tools):
 *   adb tcpip 5555          (reinicia adbd en modo TCP)
 *   adb connect <ip>:5555   (verifica; luego puede desconectar el cable)
 *
 * Uso del helper:
 *   node adb-ws-helper.js <ip-del-teléfono> [puerto=5555] [ws=8790]
 *
 * Luego en el cliente web: «Conectar por Wi-Fi (helper)» con
 *   ws://127.0.0.1:8790
 */
'use strict';

const http = require('http');
const net = require('net');
const crypto = require('crypto');

const HOST_PHONE = process.argv[2];
const PORT_PHONE = parseInt(process.argv[3] || '5555', 10);
const WS_PORT = parseInt(process.argv[4] || '8790', 10);

if (!HOST_PHONE) {
  console.error('uso: node adb-ws-helper.js <ip-del-teléfono> [puerto=5555] [ws=8790]');
  process.exit(2);
}

const server = http.createServer((req, res) => {
  res.writeHead(200, { 'Content-Type': 'text/plain' });
  res.end('Valora-VE adb-ws-helper activo\n');
});

server.on('upgrade', (req, socket) => {
  // Handshake WebSocket mínimo (RFC 6455) — sin dependencias.
  const key = req.headers['sec-websocket-key'];
  if (!key) return socket.destroy();
  const accept = crypto
    .createHash('sha1')
    .update(key + '258EAFA5-E914-47DA-95CA-C5AB0DC85B11')
    .digest('base64');
  socket.write(
    'HTTP/1.1 101 Switching Protocols\r\n' +
      'Upgrade: websocket\r\n' +
      'Connection: Upgrade\r\n' +
      `Sec-WebSocket-Accept: ${accept}\r\n\r\n`,
  );

  const phone = net.connect(PORT_PHONE, HOST_PHONE, () => {
    console.log(`[helper] teléfono conectado: ${HOST_PHONE}:${PORT_PHONE}`);
  });
  phone.on('error', (e) => {
    console.error(`[helper] error TCP: ${e.message} (¿adb tcpip 5555 y misma red?)`);
    socket.destroy();
  });

  // WS → TCP: decodifica frames (sin máscara del cliente ya que el cliente
  // siempre enmascara; aquí solo aceptamos un frame por envío, suficiente
  // para el protocolo ADB del puente que envía header+payload como 2 writes
  // — cada message event del navegador ya llega como frame propio).
  let acc = Buffer.alloc(0);
  socket.on('data', (d) => {
    acc = Buffer.concat([acc, d]);
    for (;;) {
      if (acc.length < 2) return;
      const b0 = acc[0];
      const opcode = b0 & 0x0f;
      const masked = (b0 & 0x80) !== 0;
      let len = acc[1] & 0x7f;
      let off = 2;
      if (len === 126) {
        if (acc.length < 4) return;
        len = acc.readUInt16BE(2);
        off = 4;
      } else if (len === 127) {
        if (acc.length < 10) return;
        len = Number(acc.readBigUInt64BE(2));
        off = 10;
      }
      const maskLen = masked ? 4 : 0;
      if (acc.length < off + maskLen + len) return;
      let payload = acc.subarray(off + maskLen, off + maskLen + len);
      if (masked) {
        const mask = acc.subarray(off, off + 4);
        const un = Buffer.allocUnsafe(len);
        for (let i = 0; i < len; i++) un[i] = payload[i] ^ mask[i & 3];
        payload = un;
      }
      acc = acc.subarray(off + maskLen + len);
      if (opcode === 0x2 && payload.length) phone.write(payload); // binario
      else if (opcode === 0x8) {
        socket.destroy();
        phone.destroy();
      } // close
    }
  });

  // TCP → WS: codifica cada trozo como frame binario del servidor (sin máscara).
  phone.on('data', (chunk) => {
    socket.write(encodeWsFrame(chunk));
  });
  phone.on('close', () => socket.destroy());
  socket.on('close', () => phone.destroy());
  socket.on('error', () => phone.destroy());
});

function encodeWsFrame(data) {
  const len = data.length;
  let header;
  if (len < 126) {
    header = Buffer.from([0x82, len]);
  } else if (len < 65536) {
    header = Buffer.alloc(4);
    header[0] = 0x82;
    header[1] = 126;
    header.writeUInt16BE(len, 2);
  } else {
    header = Buffer.alloc(10);
    header[0] = 0x82;
    header[1] = 127;
    header.writeBigUInt64BE(BigInt(len), 2);
  }
  return Buffer.concat([header, data]);
}

server.listen(WS_PORT, () => {
  console.log(`[helper] WebSocket listo en ws://127.0.0.1:${WS_PORT} → ADB ${HOST_PHONE}:${PORT_PHONE}`);
});
