# ARCHITECTURE · Arquitectura y patrones (ValoraVE)

Consulta obligatoria en `2_PLAN`. Este documento describe LO QUE HAY;
el diseño se evoluciona, no se reemplaza (AGENT.md · Nunca hacer).

## Mapa real de `lib/`

```
lib/
├── main.dart                 # bootstrap: Hive + AppState + MaterialApp
├── core/                     # núcleo puro (sin Flutter-UI pesado)
│   ├── models.dart           # entidades: RateEntry/RateBoard, Product,
│   │                         #   Purchase, CartItem, Transaction, Settings,
│   │                         #   AppData (13 claves), templates, notifs…
│   ├── theme.dart            # §8 «El Instrumento»: tokens claro/grafito
│   │                         #   (nota: es ARCHIVO, no carpeta — el mapa de
│   │                         #   AGENT.md lo refiere como lib/core/theme/)
│   ├── fmt.dart              # formato es-VE (1.234,56 · 02-feb-2026)
│   ├── currencies.dart       # 15 fuentes kind/category + DEFAULT
│   ├── analytics.dart        # tienda similar, avatar tinta estable
│   └── version.dart          # versión + build info
├── data/                     # persistencia y fuentes remotas
│   ├── store.dart            # Hive (4 cajas JSON) + migrate + merge
│   ├── board.dart            # motor de tasas: RateContext, plan de
│   │                         #   conversión, degradados, diagnóstico
│   ├── backup.dart           # respaldo JSON replace/merge
│   ├── rate_history.dart / history_api.dart   # histórico BCV/paralelo
│   └── sse_stream.dart       # SSE opcional (ingesta común con polling)
├── state/app_state.dart      # estado reactivo de la app (ChangeNotifier)
├── room/                     # sala en vivo (protocolo lista-sync §6)
│   ├── room_transport.dart  # Socket.IO + Cerca(Nearby) + WiFi(Lan)
│   └── room_controller.dart  # LWW, presencia, typing, GC, outbox
├── services/                 # puentes plataforma (¡no UI!)
│   ├── lan_hub / nearby_hub / bt_hub     # transportes de red
│   ├── deep_link.dart       # valorave://sala?c=..&m=..&p=..
│   ├── biometric.dart · alerts.dart · notifications.dart
│   ├── quick_actions.dart   # 4 shortcuts del launcher
│   ├── photo_compress.dart · sharing.dart (PNG/CSV/texto/print)
│   ├── widget_service.dart  # AppWidgets BCV/Paralelo/Brecha
│   └── workmanager_service.dart  # fondo: respaldo semanal, targets
├── widgets/                  # componentes compartidos de UI
│   ├── ui.dart              # firma visual: ReadWindow, Stamp,
│   │                         #   LedgerRow, RateTicker, SkeletonPaper…
│   ├── app_router.dart      # GoRouter (rutas / + deep links)
│   ├── export_sheet.dart    # ExportSpec: exportación unificada
│   └── rate_sheet / share_card / app_tips / app_tour / coach_mark
└── features/                # módulos funcionales (UI + lógica)
    ├── welcome/  shell/  home/  converter/  lista/  products/
    ├── history/  statement/  insights/  room/  settings/
    ├── scanner/  tickets/  legal/
```

## Flujo de datos (offline-first)

1. **Arranque:** `main.dart` abre Hive → `AppState` carga `AppData`
   (13 claves) desde `store.dart` → el router muestra el shell.
2. **Tasas:** `board.dart` arma `RateBoard` desde fuentes (BCV oficial,
   paralelo, manuales) + SSE opcional; el conversor pide un
   `ConversionPlan` (ruta visible con tramos, incl. EUR 4 tramos).
   Los datos NUNCA se inventan: sin fuente → estado honesto «sin dato».
3. **Escrituras:** toda mutación pasa por métodos del store
   (`addRecord`, `addPurchase`, `setTarget`…) → cajas Hive →
   `AppState` notifica → las pantallas se reconstruyen.
4. **Sala:** los mismos ítems viajan por `room_controller` con
   time-stamps LWW; offline se acumulan en outbox y salen al reconectar.
5. **Fondo:** `workmanager_service` ejecuta respaldo semanal (retención
   4) y price_targets; `widget_service` refresca los AppWidgets nativos.

## Patrones vigentes (respetar)

- **Estado:** `ChangeNotifier` central (`AppState`) + sets locales en
  pantallas con controladores DISPOSED (fuga = bug de primera clase).
- **Navegación:** GoRouter único (creado UNA vez fuera de `build()` —
  el bug v1.0.1 de la bienvenida clavada enseña por qué).
- **Feature-first:** la pantalla nueva nace en `lib/features/<módulo>/`,
  con su lógica aparte si crece (`insights_utils.dart` fuera de la
  pantalla es el patrón a imitar).
- **Exportación unificada:** TODO "compartir/guardar" pasa por
  `widgets/export_sheet.dart` (ExportSpec + formatos) — nada de
  hojas ad-hoc por módulo.
- **Nativo:** Kotlin en `android/app/src/main/kotlin/ve/valorave/app/`
  (MainActivity canal deep link, BcvWidgetProvider por subclassing);
  los cambios de manifest requieren rebuild limpio.

## Fronteras de dependencia

- `features/` → puede usar `core/`, `data/`, `state/`, `widgets/`, `services/`.
- `services/` → NO importa `features/`.
- `core/` → NO importa Flutter-UI pesado (queda testable puro).
- `test/` espeja esta estructura (ver `docs/agent/TESTING.md`).

## Servidor de sala

`server/lista-sync/` (Node/socket.io, deployable con Bun o Node) habla
el MISMO protocolo JSON que los transportes nativos — 1:1, sin dialectos.
Su README documenta el despliegue; no forma parte del APK.
