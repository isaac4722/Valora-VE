# Decisiones de la migración desde 0 (PWA → Flutter nativo)

Este documento registra CÓMO se decidió reconstruir la app desde cero y
por qué. El repo anterior (web v15/v17) se orfanó: código, 5 tags y
releases borrados; el arte aprobado (brand + fuentes) se rescató antes.

## Principios
1. **MVP-CRUD.md es la única verdad funcional**; dp4 manda en lo visual;
   dp6 facilita el port de funciones avanzadas; la web v15 es referencia
   conductual.
2. **Flutter/Dart puro**: Kotlin solo en `android/` para el widget y
   bridges imprescindibles. Cero HTML/JS en la app.
3. **Offline-first**: primera ejecución sin red funciona completa con
   tipografías empaquetadas y tablero honesto (sin cifras inventadas).
4. **Plugins oficiales** con versiones compatibles (docs/DEPENDENCIAS.md).

## Decisiones cerradas por el dueño (§4 del encargo)
Orfanado con force-push · applicationId `ve.valorave.app` · GUI dp4 ·
versión `1.0.0-beta+1` · keystore nuevo como secrets · sin FCM (solo
notificaciones locales con 5 canales) · tests TODO · PAT fino para API ·
sala con 3 transportes detrás de `RoomTransport` · minSdk 21 · es-VE ·
Flutter stable sin pin en CI · integration solo local antes de tags.

## Decisiones técnicas propias (documentadas para futuros agentes)
- **Hive guarda JSON por clave** (no TypeAdapters): backups y migraciones
  reutilizan fromJson/toJson tolerantes; imposible tener desalineación
  entre caja y backup. La hidratación es atómica (una clave única).
- **`AppStore.withData`** permite widget tests sin Hive (FakeAsync no
  ejecuta file IO); los unit tests de Hive usan `hydrate(testDir:)` con
  `test()` plano.
- **Currency enum en minúsculas** (`Currency.usd`) con `code` getter en
  mayúsculas: compatibilidad JSON con la web y ergonomía Dart.
- **`ves-avg` SIEMPRE derivado** en el motor (BCV+paralelo)/2 — ni
  siquiera si la red lo trae (§3.1).
- **Sin semillas de tasas inventadas**: la web v15 no trae cifras
  embebidas y el encargo prohíbe inventar; el primer arranque sin red
  muestra el estado degradado honesto + editor manual prominente.
- **SSE propio sobre dio** (trampa 1), **file_picker 12** (trampa 2),
  **path_provider_android 2.2.17** (trampa 3) — ver docs/DEPENDENCIAS.md.
- **Sala**: el protocolo lista-sync vive UNA vez (`RoomProtocol`) y lo
  comparten servidor, Nearby (hub en el creador) y LAN (UDP+TCP). El
  guard `baseline+suppress` del web es `applyRemoteRoomEvent` del store:
  los eventos remotos aplican al estado y jamás se re-emiten.
