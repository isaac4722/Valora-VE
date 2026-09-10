# progress.md · Registro de turnos de agentes

Documento para agentes únicamente: no se enlaza desde el README ni
sustituye la documentación humana. Cada turno añade una sección al final
con la plantilla de `AGENT.md`.

---

## [TASK-0] Arranque · repo orfanado · 2026-09-10 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Hecho:
  - Rescate de `assets/brand/` (icon.png, icon-maskable.png,
    splash-logo.png) y `assets/fonts/` (Inter 400–700, Space Grotesk
    500/700) del repo anterior ANTES del borrado.
  - Release `v1.0.0-beta` eliminada vía API autenticada (HTTP 204).
  - 5 tags remotos eliminados (v1.0.0-beta, v15.0.0-beta, v15.1.0-beta,
    v17.1.0, v17.1.1) vía API (HTTP 204 × 5).
  - Commit inicial huérfano: AGENT.md + progress.md + README mínimo +
    arte rescatado + server/lista-sync/ (servidor socket.io del protocolo
    lista-sync portado 1:1 del original v15).
- Decisiones:
  - El servidor lista-sync se porta con el protocolo EXACTO del §6 de
    MVP-CRUD.md (código de 6 letras sin O/I, límites 8/120/16KB,
    granularidad item_*, LWW, presencia 5s/35s, typing 3s).
  - Versionado arranca en `1.0.0-beta+1` (no se hereda v15/v17).
- Gates: no aplica (sin código Dart aún).
- Bloqueos: ninguno.
- Siguiente: Fase 1 · lectura del spec + inventario de fuentes + design
  system; luego Fase 2 · scaffold Flutter + dominio.


---

## [TASK-1..10] Construcción completa de la app · 2026-09-10 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Hecho:
  - Fase 1: MVP-CRUD.md leído completo; inventario de dp4/dp6/v15;
    tokens dp4 extraídos → docs/DESIGN-SYSTEM.md.
  - Fase 2: scaffold `flutter create --org ve.valorave`; dominio portado
    (currencies 15 fuentes + RateContext, models tolerantes, fmt es-VE,
    analytics, stores) + datos (AppStore Hive §2, board 4 regiones,
    backup merge §4, rate_history 180d, SSE propio sobre dio).
  - Fase 3: tema «El Instrumento» (tokens dp4 exactos) + lib/widgets/ui.dart
    (Stamp, ReadWindow, LedgerRow, RuleDouble, SourceDot, TrendBadge,
    AnimatedNumber, RateTicker 3×3×3, RateHealthBanner, etc.) + shell 6
    pestañas / 8 rutas + onboarding 0+país+7+done.
  - Fase 4: 10 pantallas completas + búsqueda global + centro de
    notificaciones + constancias (PNG/PDF/print) + respaldos.
  - Fase 5: RoomTransport con 3 transportes (socket.io / Nearby P2P_STAR /
    WiFi LAN UDP+TCP) + protocolo lista-sync compartido + outbox +
    server/lista-sync (Bun/Node) ya en el commit inicial.
  - Fase 6: plugins oficiales (docs/DEPENDENCIAS.md con las 5 trampas),
    manifest con permisos justificados 1 a 1, keystore nuevo como secrets
    (KEYSTORE_BASE64/PASSWORD/KEY_ALIAS/KEY_PASSWORD), firma release via
    keystore.properties, ProGuard, widget BCV en Kotlin.
  - Fase 7: 104 tests verdes (motor, modelos/backup/snapshots, store con
    Hive real, protocolo sala, widget tests de pantallas/componentes) +
    integration_test/app_test.dart (5 flujos, corren local antes de tag).
  - Fase 8: workflows ci.yml (gates) y build.yml (firma+ofuscación+release).
  - Fase 10: README, CHANGELOG, docs/{DESIGN-SYSTEM,DEPENDENCIAS,RELEASE,
    PARIDAD,MIGRACION}.md.
- Decisiones:
  - Hive guarda JSON por clave (migraciones/backup unificados).
  - Currency enum lowercase + code getter uppercase (JSON compatible web).
  - Sin cifras de tasas inventadas: primer arranque sin red = estado
    degradado honesto + editor manual (la web v15 tampoco trae semillas).
  - Desviaciones conscientes D1–D5 documentadas en docs/PARIDAD.md
    (sueldo variable, heatmap pictórico, coach-marks, shortcuts, canvas
    PNG exacto) — el MD manda y quedan anotadas.
- Gates: analyze=0 issues · test=104/104 · build=CI (local sin Android SDK
  por disco; la build real la hace el runner con 16 GB — §Fase 6 nota RAM).
- Bloqueos: ninguno.
- Siguiente: verificación remota de Actions/Release tras el push y el tag.
