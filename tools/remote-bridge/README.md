# Puente de depuración remota · Valora-VE (v21.7)

Depuración y pruebas en tiempo real del teléfono Android del dueño desde la
máquina del desarrollador — sin USB del desarrollador, sin servicios de pago,
sin nube intermedia. **v21.7 — «todo dentro de la preview»**: el modo sin
PC ya no necesita helper — la PROPIA app abre el canal hacia el relay.

```
Modo A (USB · todo en la preview del navegador)
┌────────────────────┐  ADB (WebUSB cable)  ┌──────────────────────┐
│ Teléfono Android   │◄────────────────────►│ Navegador del dueño  │
│ · Valora-VE        │  screencap / input / │ · cliente del puente │
│ · servidor pruebas │  tcp:8090 (HTTP)     └──────────┬───────────┘
│   127.0.0.1:8090   │                        WebSocket │ (rol bridge)
└────────────────────┘                            ┌──────▼───────────┐
                                                  │ server.js (relay)│
Modo B (SIN PC · v21.7)                           │ / · /pilot · ws  │
┌────────────────────┐   WebSocket SALIENTE       └──────┬───────────┘
│ Teléfono Android   │──────────────────────────────────►│ (rol bridge)
│ · la APP es el     │   (sin helper, sin cable,         │
│   puente (DevRelay)│    sin programas en la PC)        │
└────────────────────┘                                   │
                                                  WebSocket / SSE
                                            ┌──────▼───────────────┐
                                            │ Piloto (desarrollador)│
                                            │ /pilot · pilot_cli.js │
                                            └───────────────────────┘
```

## Piezas

| Archivo | Qué es |
|---|---|
| `server.js` | Relay WebSocket + páginas. Puerto 3000. Token en `.token`. |
| `public/index.html` | Cliente del DUEÑO: USB (puente) o espectador del puente de la app; transmite y comanda. |
| `public/adb.js` | Protocolo ADB propio (CNXN/AUTH/OPEN/WRTE) sobre WebUSB o WS. |
| `public/pilot.html` | Consola visual: ver la pantalla, tocar, comandos de app. |
| `pilot_cli.js` | Consola del desarrollador por CLI (automatización). |
| `adb-ws-helper.js` | Helper de la PC del dueño para ADB por Wi-Fi. También SIRVE el cliente en `http://127.0.0.1:8790/` (modo local, sin permiso de red local). |
| `test_relay.js` | Test E2E del relay (sin hardware): `node test_relay.js`. |
| `test_adb_keys.js` | Test del keygen/firma RSA-2048 de ADB en Node: `node test_adb_keys.js`. |
| `test_usb_transport.js` | Test del transporte WebUSB con USBDevice simulado (chooser, configs múltiples, claim ocupado): `node test_usb_transport.js`. |
| `test_helper_url.js` | Test de la normalización/diagnóstico de la dirección del helper (IP del teléfono vs helper, sin navegador): `node test_helper_url.js`. |
## Del lado de la app (repo `lib/services/*`)

**Servidor de pruebas local (v21.6)** — escucha SOLO en `127.0.0.1:8090` del
teléfono; el único camino desde fuera es el servicio `tcp:8090` de ADB (igual
que DevTools). Toggle en **Ajustes → Diagnóstico → Servidor de pruebas**
(en debug arranca siempre; en release nace apagado).

**Puente sin PC (v21.7, `dev_relay*`)** — WebSocket SALIENTE de la app hacia
el relay (`role=bridge&token=…`, mismo protocolo server.js): la app responde
`appcmd` con su propio servidor de pruebas, `shot`/`stream` con captura de
su propia UI (RepaintBoundary → PNG → JPEG), y niega con motivo claro
`tap|swipe|text|key|shell` (inyectar entrada exige ADB). Reconexión con
backoff 2/5/10/15/30 s; 4001/4003 quedan con estado claro sin pelear.
Se configura en **Ajustes → Diagnóstico → Puente sin PC** (URL del preview +
token de sesión + interruptor con auto-reconexión al arrancar).

| Endpoint | Qué hace |
|---|---|
| `GET /health` | Versión, modo y contadores del store (JSON). |
| `GET /test?scenario=cart` | Siembra 5 ítems multitienda (para ver el checkout). |
| `GET /test?scenario=products` | Siembra 3 productos con registro de precio. |
| `GET /test?scenario=purchase` | Siembra 2 compras en el historial. |
| `GET /nav?to=/historial` | Navega (lista blanca de rutas). |
| `GET /erase` | Borra datos de usuario (conserva ajustes/tablero). Exige `x-valora-token` (se muestra en Ajustes). |

## Cómo se usa (dueño)

0. **Sin cable y sin PC (v21.7 — recomendado para «todo dentro de la preview»):**
   instala el APK ≥ v21.7 → **Ajustes → Diagnóstico → «Puente sin PC»** →
   pega la URL del preview (botón «copiar URL del preview» en el panel) y el
   token de sesión → enciende el interruptor. El teléfono abre el canal hacia
   el preview SOLO: pantalla (≈1 fps), /health, /test, /nav y /erase. Los
   toques reales (tap/swipe) siguen pidiendo USB — la app lo dice honesto.
1. **USB (todo en la preview del navegador):** activa «Depuración USB» →
   cliente (`/` del preview) → «Conectar por USB» → diálogos de WebUSB +
   «Permitir depuración USB».
   - **Reconexión automática:** tras la primera autorización, abrir la página
     reconecta SOLO (sin chooser ni clics) y enchufar el cable con la página
     abierta también dispara la conexión (hot-plug).
   - **Si Chrome dice «Unable to claim interface»:** otro programa de tu PC
     tiene tomada la interface ADB — casi siempre el `adb` de consola:
     `adb kill-server`, cierra Android Studio/scrcpy/Vysor, desconecta y
     vuelve a meter el cable. En Windows la primera vez hace falta el driver
     WinUSB (Google USB driver). El cliente también cambia solo a la
     configuración USB donde vive ADB (algunos MTK lo exponen fuera de la 1).
2. **Wi-Fi con helper (avanzado, opcional):** una vez por cable:
   `adb tcpip 5555`; luego en la PC:
   `node tools/remote-bridge/adb-ws-helper.js <ip-del-teléfono> 5555` y usa la
   **página local** `http://127.0.0.1:8790/` (sin permiso de red local; token
   autollenable vía `<relay>/api/token`). Ojo con las dos direcciones: el
   campo del cliente pide el HELPER (`ws://127.0.0.1:8790` — acepta
   `127.0.0.1:8790` y `localhost:8790` sin esquema); la IP del TELÉFONO va en
   el comando. **`ws://…` NUNCA se abre en la barra del navegador** (Chrome:
   `ERR_UNKNOWN_URL_SCHEME`) — va solo en el campo del cliente.
3. **Autorización del teléfono (USB/Wi-Fi):** al conectar verás en el log
   «Clave publicada — MIRA EL TELÉFONO»: acepta «¿Permitir depuración USB?»
   de la clave **valora-bridge** (marca «Siempre» y no vuelve a preguntar).
4. Activa el servidor de pruebas en Ajustes (y pega el token de la app en el
   piloto para `/erase`).
5. La pantalla empieza a transmitir (1–3 fps por USB; ≈1 fps por el puente
   de la app).

Notas: si abres DOS pestañas del cliente, la más nueva TOMA EL CONTROL (la
vieja se cierra con aviso — cero puentes zombis). La página abierta SIN
teléfono es ESPECTADORA (rol pilot): ver el puente de la app y mandarle
comandos no la pelea con nadie; al conectar USB toma el rol de puente sola.
Si el teléfono no responde, el helper corta a los 8 s con diagnóstico.

## Cómo se usa (desarrollador — yo)

```bash
node tools/remote-bridge/pilot_cli.js status          # ¿puente vivo?
node tools/remote-bridge/pilot_cli.js shot f.png      # captura completa
node tools/remote-bridge/pilot_cli.js tap 200 400     # tocar
node tools/remote-bridge/pilot_cli.js key 4           # Atrás
node tools/remote-bridge/pilot_cli.js text "Arroz"    # escribir
node tools/remote-bridge/pilot_cli.js app /health     # app por tcp:8090
node tools/remote-bridge/pilot_cli.js app "/test?scenario=cart"
node tools/remote-bridge/pilot_cli.js app /erase --token <token>
node tools/remote-bridge/pilot_cli.js stream 8 dir/   # grabar frames
```

## Seguridad y límites (honestos)

- El preview es de acceso por URL-larga: el token viaja inyectado en las
  páginas servidas; sin URL no hay puente. `/erase` además exige el token
  mostrado en el teléfono (otra capa contra borrados accidentales).
- El protocolo ADB usa claves RSA-2048 generadas en el navegador (WebCrypto)
  y guardadas en el navegador del dueño — el teléfono las autoriza una vez.
- El puente sin PC (v21.7) NO inyecta toques (eso exige ADB); sirve pantalla
  a ≈1 fps y los endpoints de pruebas. El stream por USB es screencap
  (1–3 fps); para 30+ fps la ruta de upgrade es scrcpy/WebCodecs — pendiente,
  no bloqueante.
- Los clics del navegador llegan como `input tap/swipe` en coordenadas de
  dispositivo; el teclado CLI del navegador NO escribe en campos Flutter —
  para eso está `pilot_cli.js text` o los endpoints `/test`.
- El build web de la app (ahora en puerto **3001**) no incluye el servidor
  de pruebas ni el puente sin PC (stub no-op con la misma API).
