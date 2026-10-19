#!/usr/bin/env node
/**
 * ─── Valora-VE · Test de normalizeHelperUrl sin navegador (v21.6.3) ──────────
 * El error real del dueño: pegó una dirección que new URL() rechaza
 * («Dirección inválida»). El campo debe ser a prueba de confusión:
 *   · «192.168.0.229:5555» (IP del TELÉFONO) → error que enseña el COMANDO
 *     del helper, no un «inválida» genérico.
 *   · «127.0.0.1:8790» sin esquema → se normaliza a ws://127.0.0.1:8790.
 *   · https://… del preview → error claro pidiendo ws://.
 *   · ws:// válido pasa intacto.
 */
'use strict';

const fs = require('fs');
const path = require('path');
const assert = require('assert');

// Extrae la función PURA del script inline de index.html (sin DOM).
const html = fs.readFileSync(path.join(__dirname, 'public', 'index.html'), 'utf8');
const m = html.match(/function normalizeHelperUrl[\s\S]*?\n}\n/);
assert(m, 'normalizeHelperUrl encontrada en el script inline');
const normalizeHelperUrl = new Function(m[0] + '\nreturn normalizeHelperUrl;')();

const CASES = [
  // [entrada, esperado]
  ['', 'error|falta'],
  ['   ', 'error|falta'],
  ['192.168.0.229:5555', 'error|telefono:192.168.0.229'],
  ['192.168.0.229', 'error|telefono:192.168.0.229'],
  ['10.0.0.7:5555', 'error|telefono:10.0.0.7'],
  ['172.16.5.4:5555', 'error|telefono:172.16.5.4'],
  ['127.0.0.1:8790', 'ok|ws://127.0.0.1:8790'],
  ['ws://127.0.0.1:8790', 'ok|ws://127.0.0.1:8790'],
  ['ws://localhost:9999', 'ok|ws://localhost:9999'],
  ['localhost:8790', 'ok|ws://localhost:8790'],
  ['  ws://127.0.0.1:8790  ', 'ok|ws://127.0.0.1:8790'],
  ['https://preview-x.space-z.ai', 'error|esquema:https:'],
  ['http://192.168.0.229:8080', 'error|telefono:192.168.0.229'],
];

let ok = 0;
for (const [input, expected] of CASES) {
  const r = normalizeHelperUrl(input);
  const [kind, detail] = expected.split('|');
  if (kind === 'error' && detail.startsWith('telefono:')) {
    assert(r.error && r.error.includes(detail.slice('telefono:'.length)), 'IP de teléfono → comando del helper: ' + JSON.stringify(input));
    assert(r.error.includes('node adb-ws-helper.js'), 'el error incluye el comando exacto');
    assert(r.error.includes('USB'), 'el error menciona la salida por USB');
  } else if (kind === 'error' && detail.startsWith('esquema:')) {
    assert(r.error && r.error.includes('ws://'), 'esquema incorrecto → pide ws://: ' + JSON.stringify(input));
  } else if (kind === 'error') {
    assert(r.error && r.error.includes('ejemplo'), 'vacío → ejemplo: ' + JSON.stringify(input));
  } else {
    assert.strictEqual(r.url, detail, 'normaliza: ' + JSON.stringify(input));
    assert(!r.error, 'sin error para ' + JSON.stringify(input));
  }
  ok++;
}

// El caso EXACTO del log del dueño (14:55:10): lo que fuera que pegara,
// hoy ya no puede salir «Dirección inválida» sin explicación accionable.
for (const bad of ['192.168.0.229:5555', 'telefono', ':', 'ws://', '...']) {
  const r = normalizeHelperUrl(bad);
  assert(r.error || r.url, 'siempre error O url: ' + JSON.stringify(bad));
  if (r.error) assert(r.error.length > 25, 'error con contexto, no genérico: ' + JSON.stringify(bad));
}

console.log(ok + '/' + CASES.length + ' casos + dueño simulado — normalizeHelperUrl OK');
