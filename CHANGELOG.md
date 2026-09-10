# Changelog

## 1.0.0-beta+1 (2026-09-10) · v1.0.0-beta

Arranque desde cero de la app nativa Flutter (el repo web se orfanó).

### Añadido
- Dominio completo del spec MVP-CRUD.md §1 (modelos tolerantes con
  fromJson que nunca lanza) + motor de conversión §3.2 (puente USD, EUR
  visible con `resolveEur`, `ves-avg` SIEMPRE derivado, plan con ruta).
- Formato es-VE completo (§3.3): números, fechas, parsers tolerantes,
  CSV ida/vuelta, búsqueda sin acentos.
- Store central con todas las acciones del web §2 sobre Hive (JSON por
  clave, migración DATA_VERSION 12, resetAll conservando tablero).
- Tablero de tasas con 4 bloques regionales (VE/CO/MX/BR) + respaldo
  pyDolarve, reintentos anti-ráfaga, snapshots 180 días y mergeSeries.
- Backups: export/import JSON v12 con replace (conserva tablero) y
  fusión por id (§4), respaldo semanal automático con retención 4.
- GUI «El Instrumento» (dp4): shell 6 pestañas móvil / 8 rutas, cinta
  3 modos × 3 tamaños × 3 velocidades solo-Inicio, onboarding
  0+país+7+done, centro de notificaciones (9 kinds, ring 50).
- Pantallas: Inicio (héroe, sueldo + derivadas LOTTT, resumen del mes,
  tiendas, recientes, herramientas), Conversor (dual, swap, fecha
  histórica honesta, ruta del cálculo, comparación de fuentes, tabla,
  recientes, notas), Lista (presupuesto, plantillas ×20, vuelto,
  dividir, checkout con ticket 1024px JPEG .72), Productos (21
  semillas, filtros, sparkline, metas TARGET_EPS, CSV ⇄), Historial
  (asientos, filtros, 2 CSV, zoom de ticket), Finanzas (donut, barras
  6/12m, CRUD), Análisis (5 anclas), Ajustes (8 anclas), Legal.
- Sala multi-transporte: Servidor (URL configurable), Cerca (Nearby
  Connections P2P_STAR) y WiFi local (UDP+TCP) con el protocolo
  lista-sync idéntico; QR de sala; outbox offline.
- Alertas: picos (cooldown 30 min), metas de tasa con histéresis,
  brecha, cambio diario; centro con dedupe 10 min; 5 canales locales
  (sin FCM); WorkManager horario + semanal.
- Widget 4×1 BCV (home_widget + Kotlin) · escáner mobile_scanner ·
  bloqueo biométrico opcional · búsqueda global.
- CI (analyze+test) y Build release con firma desde secrets,
  ofuscación y split-per-abi (3 APK + AAB).

### Tests
- 104 tests: motor, modelos/backup/snapshots/analítica, store completo
  (Hive real en temp), protocolo de sala con transports falsos, widget
  tests de pantallas y componentes. Integration flows para emulador.
