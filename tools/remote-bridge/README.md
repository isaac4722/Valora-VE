# Puente de depuración remota · Valora-VE (v21.8.1)

Depuración y pruebas en tiempo real del teléfono Android del dueño desde la
máquina del desarrollador — sin USB del desarrollador, sin servicios de pago,
sin nube intermedia, **sin scrcpy**. **v21.8 — «Wi-Fi del servidor, sin
helper»**: cuando este servidor alcanza el teléfono (LAN), la preview sirve
Wi-Fi completo — ADB real (`/adb-ws`), pantalla H.264 (~15-30 fps,
`screenrecord` + WebCodecs) y toque/teclas (`/ws/input`) — todo dentro de la
preview, cero programas en la PC.

```
Modo A (USB · todo en la preview del navegador)
┌────────────────────┐  ADB (WebUSB cable)  ┌──────────────────────┐
│ Teléfono Android   │◄────────────────────►│ Navegador del dueño  │
│ · Valora-VE        │  screencap / input / │ · cliente del puente │
│ · servidor pruebas │  tcp:8090 (HTTP)     └──────────┬───────────┘
│   127.0.0.1:8090   │                        WebSocket │ (rol bridge)
└────────────────────┘                            ┌──────▼───────────┐
                                                  │ server.js (relay)│
                                                  │ / · /pilot · ws  │
                                                  └──────────────────┘

Modo B (SIN PC · v21.7)
┌────────────────────┐   WebSocket SALIENTE   ┌──────────────────────┐
│ Teléfono Android   │───────────────────────►│ server.js (relay)    │
│ · la APP es el     │  (sin helper, sin      │ (rol bridge)         │
│   puente (DevRelay)│   cable, sin programas │                      │
└────────────────────┘   en la PC)            └──────────┬───────────┘
                                                 WebSocket / SSE
                                            ┌──────▼───────────────┐
                                            │ Piloto (desarrollador)│
                                            │ /pilot · pilot_cli.js │
                                            └───────────────────────┘

Modo C (Wi-Fi del SERVIDOR · v21.8, sin helper ni cable del dev)
┌────────────────────┐   ADB/TCP :5555    ┌───────────────────────────┐
│ Teléfono Android   │◄──────────────────►│ server.js (relay, :3000)  │
│ · adbd en Wi-Fi    │  /adb-ws (bytes)   │ · puente WS↔TCP /adb-ws   │
│ · 192.168.0.229    │  screenrecord H.264→│ · /ws/video (binario)    │
│                    │  `adb shell input` │ · /ws/input (JSON)        │
└────────────────────┘                    └──────────┬────────────────┘
                                          WebSocket │ token de sesión
                                          ┌─────────▼───────────┐
                                          │ Navegador del dueño  │
                                          │ · ADB real (adb.js)  │
                                          │ · WebCodecs H.264    │
                                          └──────────────────────┘
Requiere platform-tools en la máquina del servidor (`ADB_BIN`) y que el
servidor esté en la MISMA red que el teléfono (el preview en la nube no llega
a la LAN: `/api/adb` lo dice honesto y la UI degrada a USB / puente de app).
```

## Piezas

| Archivo | Qué es |
|---|---|
| `server.js` | Relay WebSocket + páginas + ADB del servidor: `/adb-ws` (WS↔TCP), `/ws/video` (screenrecord H.264 con reinicio/backpressure), `/ws/input` (tap/swipe/key/text), `/api/adb[+/connect|/meta]`. Puerto 3000. Token en `.token`. |
| `public/index.html` | Cliente del DUEÑO: USB (puente) o espectador del puente de la app; transmite y comanda. |
| `public/adb.js` | Protocolo ADB propio (CNXN/AUTH/OPEN/WRTE) sobre WebUSB o WS. |
| `public/pilot.html` | Consola visual: ver la pantalla, tocar, comandos de app. |
| `pilot_cli.js` | Consola del desarrollador por CLI (automatización). |
| `adb-ws-helper.js` | LEGADO (v21.6): helper de la PC para ADB por Wi-Fi — hoy lo reemplaza el modo «Wi-Fi por el servidor» (v21.8). Se conserva por compatibilidad. |
| `test_relay.js` | Test E2E del relay (sin hardware): `node test_relay.js`. |
| `test_adb_keys.js` | Test del keygen/firma RSA-2048 de ADB en Node: `node test_adb_keys.js`. |
| `test_usb_transport.js` | Test del transporte WebUSB con USBDevice simulado (chooser, configs múltiples, claim ocupado): `node test_usb_transport.js`. |
| `test_helper_url.js` | Test de la normalización/diagnóstico de la dirección del helper (IP del teléfono vs helper, sin navegador): `node test_helper_url.js`. |
| `test_server_wifi.js` | Test del servidor v21.8 SIN hardware — adbd MOCK (protocolo ADB real) + adb FALSO: `/api/adb*`, puente `/adb-ws` con el CLIENTE REAL (ValoraAdb: handshake + shell + screencap + tap), `/ws/input` (redondeo/escape/keycode), `/ws/video` (annex-b SPS+PPS+IDR), funciones puras del cliente (feeder/assembler/codec/mapeo): `node test_server_wifi.js`. |
| `test_adb_dead.js` | Test de muerte del transporte (v21.8.1, sin hardware): writes sobre USB/WS muertos dan errores limpios (no TypeError de null), `connect()`/`exec()` rechazan RÁPIDO con el error real, `onDead` dispara UNA vez, y CENTINELA de `unhandledRejection` = 0 en todo el proceso (regresión de los «Uncaught (in promise)» vistos en consola del dueño): `node test_adb_dead.js`. |
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
2. **Wi-Fi por el servidor (v21.8 — Wi-Fi completo dentro de la preview):** en
   la máquina que corre `server.js` instala platform-tools (o `ADB_BIN=<ruta>`)
   y está en la misma red que el teléfono. Una vez por cable: `adb tcpip 5555`.
   En el cliente: **«Wi-Fi por el servidor» → «Conectar por Wi-Fi»** — sin
   escribir NADA (el servidor usa el teléfono por defecto de su config) el
   cliente hace `adb connect`, habla ADB REAL por `/adb-ws` (misma pila que
   USB: shell, screencap, appcmd) y tecla/toque van por la sesión ADB.
   **Pantalla H.264 (~15-30 fps):** botón «▶ Pantalla H.264» —
   `screenrecord --output-format=h264` + WebCodecs (Annex-B, sin scrcpy);
   reinicio transparente cada 170 s (tope de screenrecord en Android <14) y
   backpressure (> 2 MB acumulados → se reinicia el stream). Mapeo de toque
   canvas→display con `wm size` + rotación (`/api/adb/meta`). Sin multi-touch
   (límite de `adb shell input`, documentado). Sin audio y pantallas
   `FLAG_SECURE` salen negras (límites del método, no del puente).
   Env del servidor: `ADB_BIN`, `ADB_SERIAL`, `ADB_WIFI_HOST`, `ADB_WIFI_PORT`,
   `VIDEO_BIT_RATE` (4 Mbps), `VIDEO_SIZE` (vacío = nativa), `VIDEO_TIME_LIMIT` (170).
3. **Wi-Fi con helper (LEGADO v21.6):** `node tools/remote-bridge/adb-ws-helper.js
   <ip-del-teléfono> 5555` + página local `http://127.0.0.1:8790/`. Hoy el modo
   2 lo reemplaza (sin helper). **`ws://…` NUNCA se abre en la barra del
   navegador** (Chrome: `ERR_UNKNOWN_URL_SCHEME`) — la lección del dueño que
   motivó los modos A/B/C todo-en-la-preview.
4. **Autorización del teléfono (USB/Wi-Fi):** al conectar verás en el log
   «Clave publicada — MIRA EL TELÉFONO»: acepta «¿Permitir depuración USB?»
   de la clave **valora-bridge** (marca «Siempre» y no vuelve a preguntar).
5. Activa el servidor de pruebas en Ajustes (y pega el token de la app en el
   piloto para `/erase`).
6. La pantalla empieza a transmitir (1–3 fps por USB; ≈1 fps por el puente
   de la app; 15–30 fps por H.264 del servidor).

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
- Si el teléfono se va a mitad de sesión (cable desconectado, Wi-Fi caído,
  adbd reiniciado), la página se entera SOLA vía `onDead` (v21.8.1): log
  «Conexión perdida», limpieza de la UI, regreso a espectador y — con el
  cable vuelto a meter — reconexión automática sin chooser. El flujo de
  screencap se corta tras 5 errores seguidos en vez de martillar para
  siempre, y ningún write sobre transporte muerto produce «Uncaught (in
  promise)» en la consola.
- El build web de la app (ahora en puerto **3001**) no incluye el servidor
  de pruebas ni el puente sin PC (stub no-op con la misma API).
