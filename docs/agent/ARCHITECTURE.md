# ARCHITECTURE · Arquitectura y patrones (es-VE)

## Mapa real de `lib/`

| Capa | Ruta | Contenido |
|---|---|---|
| Dominio | `lib/core/` | `models`, `theme` (sistema de diseño), `fmt` (es-VE), `currencies`, `analytics`, `version` |
| Datos | `lib/data/` | `store` (Hive), `board` (tablero de tasas + respaldos regionales), `backup`, `history_api`, `rate_history`, `sse_stream` (SSE propio sobre dio) |
| Servicios | `lib/services/` | conectividad, notificaciones, widgets Android, sharing/exportación, deep link, biometría, quick actions, workmanager, bt/lan/nearby hubs |
| Estado | `lib/state/app_state.dart` | `AppState` + `ThemeController` (provider como DI) |
| Sala P2P | `lib/room/` | `room_controller` (protocolo hello→welcome, gobierno de roles) + `room_transport` (seam `RoomLink`) |
| Features | `lib/features/` | `welcome`, `home`, `lista`, `converter`, `insights`, `history`, `statement`, `products`, `room`, `scanner`, `settings`, `legal`, `shell` — cada módulo con su UI y lógica |
| UI compartida | `lib/widgets/` | `ui` (sistema de diseño), `app_router`, `export_sheet` (exportación unificada), `rate_sheet`, `share_card`, `app_tour`, `coach_mark`, `app_tips` |

## Decisiones estructurales (cerradas)

- **Offline-first:** Hive (`hive_ce`) persiste TODO; la red es un lujo.
  Sin red no se consulta (fin de las cargas falsas).
- **Sala P2P sin internet:** 5 modos (Cerca/WiFi-Hotspot/Bluetooth RFCOMM
  nativo `BtSppPlugin.kt`/LAN/Servidor) detrás del seam `RoomLink`.
- **Degradación honesta en web:** el arranque jamás depende de un plugin;
  Hive → IndexedDB, plugins nativos → excepción capturada y logueada.
- **Exportación unificada:** `showExportSheet` + `ExportSpec`
  (`lib/widgets/export_sheet.dart`) para TODA la app.
- **Deep link:** `valorave://sala?c=CODE&m=MODE&p=0|1` (canal
  `valorave/deeplink` en `MainActivity.kt` → `DeepLinkService`).

## Reglas

- No reemplazar arquitectura ni sistema de diseño: solo evolucionar lo
  existente.
- Modificar `lib/core/` afecta a toda la app → preguntar primero.
- Fuente de verdad funcional: `MVP-CRUD.md` (raíz · reconstrucción
  canónica v19.9). Si el código y el MD discrepan, manda el MD y la
  desviación se anota en `PROGRESS.md`.

## TODO

- (ninguno pendiente: todo lo listado es verificable en el árbol)
