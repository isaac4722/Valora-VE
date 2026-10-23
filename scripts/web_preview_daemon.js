'use strict';
/**
 * Servidor estático del preview — sirve la APP (build/web) en :3000.
 * El preview del repo es la app misma. Patrón preview_daemon:
 * spawn(detached) + unref → el servidor queda huérfano en PID 1 y
 * sobrevive entre llamadas bash del sandbox.
 * Uso: node scripts/web_preview_daemon.js  (log: /tmp/web_preview.log)
 */
const { spawn } = require('child_process');
const fs = require('fs');
const NET = require('net');

const MARKER = '/tmp/.web_preview_up';

// ¿Ya hay algo vivo en :3000? Si responde, no duplicar.
function alive() {
  return new Promise((res) => {
    const s = NET.connect(3000, '127.0.0.1');
    s.on('connect', () => { s.destroy(); res(true); });
    s.on('error', () => res(false));
    s.setTimeout(1500, () => { s.destroy(); res(false); });
  });
}

(async () => {
  if (await alive()) {
    console.log(':3000 ya vivo — nada que hacer');
    process.exit(0);
  }
  const child = spawn(process.execPath, [__dirname + '/web_preview_server.js'], {
    detached: true,
    stdio: ['ignore', fs.openSync('/tmp/web_preview.log', 'a'), fs.openSync('/tmp/web_preview.log', 'a')],
  });
  child.unref();
  console.log('preview daemonizado PID', child.pid);
  process.exit(0);
})();
