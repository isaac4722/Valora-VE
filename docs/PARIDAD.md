# Paridad 1:1 contra MVP-CRUD.md §14

Estado de la verificación final. Evidencia: archivo/módulo/test.
**v1.0.1-beta (2026-09-10)**: ronda de paridad con informe del web v15 —
fix bloqueante del router, icono real, escáner, recordatorio, sueldo
variable, StoreSheet, share PNG del conversor, barras 6/12, héroe fresco.

| # | Ítem §14 | Estado | Evidencia |
|---|---|---|---|
| 1 | 13 claves AppData persisten (Hive) v12 + migración + merge HMR-safe | ✅ | `lib/data/store.dart` (4 cajas JSON, `migrate`, merge tolerante) · `test/store_test.dart` round-trip |
| 2 | 15 fuentes kind/category + DEFAULT oficiales + manuales editables | ✅ | `lib/core/currencies.dart` (RateSource.all) · `test/currencies_test.dart` |
| 3 | Conversión puente USD + EUR visible + ruta path/sourceIds + históricos honestos + PICKER_MIN | ✅ | `RateContext.plan/resolveEur` · conversor con `showDatePicker(firstDate: 2023-01-03)` y `withoutData` honesto · `test/currencies_test.dart` |
| 4 | Formato es-VE (1.234,56 · COP 0 · EUR 4 dec · 02-feb-2026 · hace X min por fetchedAt) | ✅ | `lib/core/fmt.dart` · `test/fmt_test.dart` |
| 5 | CRUD productos/records/disponibilidad/metas (TARGET_EPS, metSince auto) + 21 semillas + CSV ⇄ + pág.20 | ✅ | `store.addRecord/setTarget/setUnavailable` · `products_screen` · `test/store_test.dart` |
| 6 | CRUD carrito + checked/checkedBy + presupuesto + plantillas (20) + vuelto + dividir + checkout + ticket foto + enlace | ✅ | `lista_screen.dart` (checkout con `image_picker` 1024px .72) · `test/store_test.dart` |
| 7 | CRUD compras + filtros + pág.20 + 2 CSV + JSON + constancia | ✅ | `history_screen.dart` + `statement_screen.dart` |
| 8 | CRUD transacciones + resumen + donut + barras 6/12m + constancia | 🔄 | **v17.8: módulo retirado por orden del dueño** — los gráficos de gastos viven en Análisis («Gastos», alimentado por compras); modelo Transaction conservado para round-trip de respaldos viejos |
| 9 | Home (hero/board/tiles/extras/copy/tiendas/alertas/recientes/herramientas) | ✅* | `home_screen.dart` (héroe con frescura `fetchedAt` + píldora «vs ayer» con snapshots; StoreSheet por tienda; **sueldo retirado v17.2 a pedido del dueño** — modelo/settings conservados; v17.8: «Resumen del mes» alimentado por compras) |
| 10 | Análisis 6 anclas + gap + lookup + proyección + heatmap + rankings + canasta + gastos + CSVs | ✅* | `insights_screen.dart` (proyección amortiguada DAMP 0.85; heatmap sustituido por curva de serie diaria — D2; **v17.8: ancla Gastos** con monthSpend/storeSpend) |
| 11 | Ajustes 8 anclas + respaldo replace/merge + Zona peligro | ✅ | `settings_screen.dart` + `lib/data/backup.dart` · `test/models_backup_test.dart` |
| 12 | Onboarding 0+país+done + tour completo rejugable | ✅ | `welcome_screen.dart` + `widgets/app_tour.dart` (v17.8: UN tutorial de 13 pasos con tutorial_coach_mark; los slides y los recorridos por módulo se retiraron) |
| 13 | Shell 7 rutas / móvil 5 + ticker 3×3×3 solo-home + badge carrito + banner salud | ✅ | `main_shell.dart` + `app_router.dart` (v17.8: sin pestaña Finanzas) · `test/widgets_test.dart` |
| 14 | Sala protocolo §6 (granular, LWW, GC, presencia, typing, joiner pierde previa) + share/QR | ✅ | `lib/room/room_transport.dart` + `server/lista-sync/` 1:1 · selector Servidor/Cerca/WiFi · `test/room_protocol_test.dart` |
| 15 | Alertas: spikes (cooldown 30min) + targets (histéresis) + gap/daily/reminder + centro 9 kinds ring 50 + WorkManager | ✅ | `lib/services/alerts.dart` + `workmanager_service.dart` · recordatorio diario REAL (prefs + claim por día, camino in-app y camino workmanager ±1 h) · `test/store_test.dart` (centro) |
| 16 | Nativo: 4 shortcuts + widgets + scanner + foto 1024 ≤12MB + constancia PNG/share/print + zoom 1–8× | ✅* | `BcvWidgetProvider.kt` + `widget_service.dart` · **escáner REAL cableado** (`features/scanner/scanner_screen.dart`: continuo + linterna + fallback manual + debounce; Productos abre ficha/alta con código prellenado, Lista agrega con precio vigente) · `InteractiveViewer` zoom · shortcuts nativos parcialmente (D4) |
| 17 | Diseño §8 al píxel (tokens, firmas, tabular, curva, duraciones, reducedMotion) | ✅ | `lib/core/theme.dart` (tokens dp4 exactos) + `docs/DESIGN-SYSTEM.md` |
| 18 | analyze/test verdes; APK release ofuscado | ✅ | CI: analyze 0 · tests verdes · Build en runner SUCCESS · Release con 3 APK + AAB, firma v2 verificada. **v1.0.1-beta: fix del GoRouter creado en build() (atrapaba al usuario en bienvenida), icono launcher real (legacy + adaptive + monochrome), escáner cableado, recordatorio diario, sueldo variable, StoreSheet, compartir PNG del conversor, barras 6/12, héroe «vs ayer»** |

Leyenda: ✅ completo · ✅* completo con desviación consciente documentada.

## Funciones de la web v15 cubiertas (extras que el MD no menciona)
- Búsqueda global de la app (módulos/productos/notificaciones) → `main_shell.dart` `showGlobalSearch`.
- Banner de salud de tasas (>15 min) → `RateHealthBanner`.
- Tabla de referencia del conversor + notas persistentes (5000) + recientes 10 con dedupe 60s → `converter_screen.dart` + store.
- Sugerencia pasiva de tiendas (`findSimilarStore`) + avatar con tinta estable → `lib/core/analytics.dart`.
- Diagnóstico por bloque de región en el motor (providers/degradados) → `lib/data/board.dart`.
- Servidor lista-sync listo para desplegar → `server/lista-sync/` (Bun/Node, README propio).
- Respaldo semanal automático con retención 4 → `workmanager_service.dart`.
- SSE opcional de un despliegue web (rates-stream) → `lib/data/sse_stream.dart`.

## Desviaciones conscientes (mandadas por AGENT.md · Regla 4)
- **D1 · Sueldo variable — CERRADA en v1.0.1**: modos fijo · base+variable ·
  rango min–máx con sueldo efectivo (promedio del rango) alimentando tiles y
  LOTTT. El mapa JSON `salary` gana mode/base/variable/min/max tolerantes
  (respaldos viejos siguen cargando).
- **D2 · Heatmap de devaluación — CERRADA en v17.7**: calendario pictórico
  de 6 meses en Análisis → Inflación, un cuadro por día (rojo=subida de la
  tasa, verde=baja, intensidad=magnitud vs el día anterior con datos),
  leyenda y día con mayor subida. La serie de área se conserva junto al
  calendario (dos vistas del mismo dato honesto).
- **D3 · Onboarding guiado — EVOLUCIONADA en v17.8**: la Ola 1 (puntas por
  feature, v17.7) se retiró: sus dos sistemas (recorridos por módulo +
  puntas con respiro de 900 ms) se apilaban y se salían de pantalla
  (capturas del dueño). Hoy hay UN tutorial completo rejugable
  (`widgets/app_tour.dart`, tutorial_coach_mark): 13 pasos anclados que
  cruzan las 5 pestañas + Ajustes, un overlay a la vez, alineación con el
  rect real, banderas de assets/flags. El país sigue eligiéndose EN la
  bienvenida (página 3 con chips + banderas reales).
- **D4 · 4 shortcuts nativos — CERRADA en 1.1.0-dp4**: quick_actions 4/4 en
  el launcher (Lista · Conversor · Escanear · Tasa BCV) + el intent
  `valorave://sala` registrado.
- **D5 · PNG 1080×1080/1350 dibujado a canvas pixel-perfect**: el flujo
  Compartir/PDF/Imprimir está completo vía share_plus/printing; el canvas
  exacto del web (fitText + rows punteados) queda como iteración de píxel.
  En v1.0.1 el Conversor ya comparte su cálculo como PNG 1080 (monto + ruta
  + fuentes) con `captureWidget`.

## Extras de la rama v17.7 (1.6.0-beta+14)
- Ruta EUR de 4 tramos VISIBLE en «Ruta del cálculo» + `ConversionPlan.direct`
  (clase propia del motor, tests ida/vuelta).
- Análisis: rankings por día de semana y por divisa · proyección DAMP
  punteada · exportGapCsv · histórico multi-divisa (3 fuentes + CSV).
- Biometría con toggle (puerta de marca al abrir; sin soporte no bloquea) ·
  SSE en vivo opcional (ingesta común con el polling) · `price_targets` de
  producto en 2º plano (canal propio + workmanager) · familia de widgets
  BCV/Paralelo/Brecha por subclassing Kotlin.
- Reestructura: converter 1515→845 + 2 parts; settings 1102→211 + 3 parts.

## Sala multi-transporte (decisión §4.10)
- **Servidor**: `SocketIoTransport` con URL configurable (Ajustes → Sala en
  `_RoomSheet` lobby) + `server/lista-sync/` listo para desplegar.
- **Cerca (sin internet)**: `NearbyTransport` sobre `nearby_connections`
  P2P_STAR — el creador anuncia (hub retransmite), invitados descubren.
- **WiFi local**: `LanTransport` — ServerSocket 48130 + broadcast UDP de
  descubrimiento, protocolo JSON por línea idéntico.
- Outbox offline común; protocolo lista-sync idéntico en los tres (tests).
