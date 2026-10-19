# Puente de depuración remota · Valora-VE (v21.6)

Depuración y pruebas en tiempo real del teléfono Android del dueño desde la
máquina del desarrollador — sin USB del desarrollador, sin servicios de pago,
sin nube intermedia: todo corre en el servidor del preview + tu navegador.

```
┌────────────────────┐  ADB (WebUSB cable   ┌──────────────────────┐
│ Teléfono Android   │  o Wi-Fi + helper)   │ Navegador del dueño  │
│ · Valora-VE        │◄────────────────────►│ · tools/remote-      │
│ · servidor pruebas │  screencap / input / │   bridge  (cliente)  │
│   127.0.0.1:8090   │  tcp:8090 (HTTP)     └──────────┬───────────┘
└────────────────────┘                                 │ WebSocket
                                            ┌──────────▼───────────┐
                                            │ server.js (relay)    │
                                            │ / · /pilot · /api/ws │
                                            └──────────┬───────────┘
                                     WebSocket / SSE   │
                                            ┌──────────▼───────────┐
                                            │ Piloto (desarrollador)│
                                            │ /pilot · pilot_cli.js │
                                            └───────────────────────┘
```

## Piezas

| Archivo | Qué es |
|---|---|
| `server.js` | Relay WebSocket + páginas. Puerto 3000. Token en `.token`. |
| `public/index.html` | Cliente del DUEÑO: conecta el teléfono y transmite. |
| `public/adb.js` | Protocolo ADB propio (CNXN/AUTH/OPEN/WRTE) sobre WebUSB o WS. |
| `public/pilot.html` | Consola visual: ver la pantalla, tocar, comandos de app. |
| `pilot_cli.js` | Consola del desarrollador por CLI (automatización). |
| `adb-ws-helper.js` | Helper de la PC del dueño para ADB por Wi-Fi. |
| `test_relay.js` | Test E2E del relay (sin hardware): `node test_relay.js`. |

## Del lado de la app (repo `lib/services/dev_bridge*`)

El servidor de pruebas local escucha SOLO en `127.0.0.1:8090` del teléfono —
el único camino desde fuera es el servicio `tcp:8090` de ADB (igual que
DevTools). Toggle en **Ajustes → Diagnóstico → Servidor de pruebas**
(en debug arranca siempre; en release nace apagado).

| Endpoint | Qué hace |
|---|---|
| `GET /health` | Versión, modo y contadores del store (JSON). |
| `GET /test?scenario=cart` | Siembra 5 ítems multitienda (para ver el checkout). |
| `GET /test?scenario=products` | Siembra 3 productos con registro de precio. |
| `GET /test?scenario=purchase` | Siembra 2 compras en el historial. |
| `GET /nav?to=/historial` | Navega (lista blanca de rutas). |
| `GET /erase` | Borra datos de usuario (conserva ajustes/tablero). Exige `x-valora-token` (se muestra en Ajustes). |

## Cómo se usa (dueño)

1. **USB (recomendado):** activa «Depuración USB» en el teléfono → abre la
   página del puente (`/` en el preview) → «Conectar por USB» → acepta los
   diálogos (WebUSB + «Permitir depuración USB» con la clave del navegador).
2. **Wi-Fi:** una vez por cable: `adb tcpip 5555`; luego en la PC:
   `node tools/remote-bridge/adb-ws-helper.js <ip-del-teléfono> 5555` y en el
   cliente pega `ws://127.0.0.1:8790` antes de «Conectar por Wi-Fi».
3. Activa el servidor de pruebas en Ajustes (y pega el token en el cliente
   una sola vez: queda en `localStorage`).
4. La pantalla empieza a transmitir (1–3 fps, screencap adaptativo).

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
  y guardadas en `localStorage` del dueño — el teléfono las autoriza una vez.
- El stream es screencap (1–3 fps, perfecto para verificar estado); para
  30+ fps la ruta de upgrade es scrcpy/WebCodecs — pendiente, no bloqueante.
- Los clics del navegador llegan como `input tap/swipe` en coordenadas de
  dispositivo; el teclado CLI del navegador NO escribe en campos Flutter —
  para eso está `pilot_cli.js text` o los endpoints `/test`.
- El build web de la app (ahora en puerto **3001**) no incluye el servidor
  de pruebas (stub no-op con la misma API).
