# Puente de depuración remota · Valora-VE (v21.6.1)

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
| `adb-ws-helper.js` | Helper de la PC del dueño para ADB por Wi-Fi. También SIRVE el cliente en `http://127.0.0.1:8790/` (modo local, sin permiso de red local). |
| `test_relay.js` | Test E2E del relay (sin hardware): `node test_relay.js`. |
| `test_adb_keys.js` | Test del keygen/firma RSA-2048 de ADB en Node: `node test_adb_keys.js`. |

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

1. **Wi-Fi (probado con TECNO BF6):** una vez por cable: `adb tcpip 5555`;
   luego en la PC: `node tools/remote-bridge/adb-ws-helper.js <ip-del-teléfono> 5555`
   y abre la **página local** `http://127.0.0.1:8790/` — pega ahí la URL del
   preview y el token (se recuerda; si dejas el token vacío lo busca solo en
   `<relay>/api/token`). No hace falta permiso de red local: la página y el
   helper viven en tu misma máquina.
   - Alternativa: el cliente hospedado en el preview con `ws://127.0.0.1:8790`
     — ahí Chrome pedirá «acceso a la red local» UNA vez (acéptalo; si lo
     bloqueaste: ícono de la barra → Permisos → Permitir) y solo funciona
     hacia `127.0.0.1` (mixed content: nada de `ws://192.168.x.x` desde https).
2. **USB:** activa «Depuración USB» → cliente (`/` del preview) → «Conectar
   por USB» → diálogos de WebUSB + «Permitir depuración USB».
3. **Autorización del teléfono (ambos modos):** al conectar verás en el log
   «Clave publicada — MIRA EL TELÉFONO»: acepta «¿Permitir depuración USB?»
   de la clave **valora-bridge** (marca «Siempre» y no vuelve a preguntar).
4. Activa el servidor de pruebas en Ajustes (y pega el token de la app en el
   cliente para `/erase`: queda en `localStorage`).
5. La pantalla empieza a transmitir (1–3 fps, screencap adaptativo).

Notas: si abres DOS pestañas del cliente, la más nueva TOMA EL CONTROL (la
vieja se cierra con aviso — cero puentes zombis). Si el teléfono no responde,
el helper corta a los 8 s con diagnóstico en su consola.

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
