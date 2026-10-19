#!/usr/bin/env node
/**
 * ─── Valora-VE · Test del keygen/firma ADB en Node (v21.6.1) ─────────────────
 * Verifica la ruta criptográfica del puente SIN hardware, con el WebCrypto de
 * Node (mismas primitivas que el navegador):
 *   1. AdbKeys.load() genera RSA-2048 (el bug v21.6: generateKey sin
 *      modulusLength revientaba con «RsaHashedKeyGenParams: modulusLength:
 *      Missing required property» en el teléfono del dueño).
 *   2. publicKeyAdb() produce el formato nativo de ADB (android_pubkey.c):
 *      524 bytes = len|n0inv|n|rr|e con len=64 palabras (big-endian),
 *      n0inv = -1/n mod 2^32 y rr = R^2 mod n.
 *   3. sign() firma un AUTH TOKEN de 20 bytes y la firma VERIFICA contra la
 *      clave pública JWK (RSASSA-PKCS1-v1_5 + SHA-1, como adbd).
 *
 * Uso: node test_adb_keys.js
 */
'use strict';

const assert = require('assert');
const crypto = require('crypto');
const { AdbKeys } = require('./public/adb.js');

async function main() {
  // 1 · keygen RSA-2048 (antes: crash garantizado)
  const key = await AdbKeys.load();
  assert.ok(key.jwk && key.priv, 'load() debe devolver {jwk, priv}');
  const nB = AdbKeys._b64uToBytes(key.jwk.n);
  assert.strictEqual(nB.length, 256, 'módulo de 2048 bits (256 bytes)');
  assert.strictEqual(key.jwk.e, 'AQAB', 'exponente 65537 en JWK');
  console.log('✓ 1/4 generateKey RSA-2048 OK (modulusLength+publicExponent presentes)');

  // 2 · formato ADB de la clave pública
  const pub = await AdbKeys.publicKeyAdb(key);
  const b64part = pub.split(' ')[0];
  const raw = Buffer.from(b64part, 'base64');
  assert.strictEqual(raw.length, 524, '524 bytes = 4+4+256+256+4');
  const len = raw.readUInt32BE(0);
  assert.strictEqual(len, 64, 'len = 64 palabras de 32 bits');
  const n0inv = BigInt(raw.readUInt32BE(4));
  const n = BigInt('0x' + raw.subarray(8, 8 + 256).toString('hex'));
  const rr = BigInt('0x' + raw.subarray(8 + 256, 8 + 512).toString('hex'));
  const e = raw.readUInt32BE(8 + 512);
  assert.strictEqual(e, 65537, 'exponente big-endian al final');
  const M32 = 1n << 32n;
  const inv = (M32 - n0inv) % M32; // stored = -1/n → invierte el signo
  assert.strictEqual((n * inv) % M32, 1n, 'n0inv = -1/n mod 2^32');
  assert.strictEqual(rr, (1n << 4096n) % n, 'rr = R^2 mod n con R = 2^2048');
  assert.ok(pub.endsWith(' valora-bridge\0'), 'nombre de clave + NUL');
  console.log('✓ 2/4 publicKeyAdb: 524 bytes, len=64, n0inv y rr correctos');

  // 3 · firma + verificación RSASSA-PKCS1-v1_5/SHA-1 (lo que hace adbd)
  const token = crypto.randomBytes(20); // AUTH TOKEN de adbd: 20 bytes
  const sig = await AdbKeys.sign(key, new Uint8Array(token));
  assert.strictEqual(sig.length, 256, 'firma de 2048 bits');
  const pubJwk = { kty: key.jwk.kty, n: key.jwk.n, e: key.jwk.e };
  const pubKey = await crypto.subtle.importKey(
    'jwk',
    pubJwk,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-1' },
    true,
    ['verify'],
  );
  const ok = await crypto.subtle.verify(
    { name: 'RSASSA-PKCS1-v1_5' },
    pubKey,
    sig,
    token,
  );
  assert.ok(ok, 'la firma debe verificar contra la clave pública');
  console.log('✓ 3/4 sign+verify RSASSA-PKCS1-v1_5/SHA-1 OK (reto de 20 bytes)');

  // 4 · la clave persistida se reimporta (localStorage se omite en Node:
  // simula guardado y recarga manual con el JWK exportado)
  const jwk2 = JSON.parse(JSON.stringify(key.jwk));
  const priv2 = await crypto.subtle.importKey(
    'jwk',
    jwk2,
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-1' },
    true,
    ['sign'],
  );
  const sig2 = new Uint8Array(
    await crypto.subtle.sign({ name: 'RSASSA-PKCS1-v1_5' }, priv2, token),
  );
  const ok2 = await crypto.subtle.verify({ name: 'RSASSA-PKCS1-v1_5' }, pubKey, sig2, token);
  assert.ok(ok2, 'reimport del JWK persistido debe firmar igual');
  console.log('✓ 4/4 JWK persistido reimporta y firma (persistencia navegador OK)');

  console.log('\n4/4 · ruta criptográfica del puente verificada sin hardware');
}

main().catch((e) => {
  console.error('✗ ' + (e && e.message));
  process.exit(1);
});
