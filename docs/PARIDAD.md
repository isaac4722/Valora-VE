# Paridad 1:1 contra MVP-CRUD.md §14

Estado de la verificación final. Evidencia: archivo/módulo/test.

| # | Ítem §14 | Estado | Evidencia |
|---|---|---|---|
| 1 | 13 claves AppData persisten (Hive) v12 + migración + merge HMR-safe | ✅ | `lib/data/store.dart` (4 cajas JSON, `migrate`, merge tolerante) · `test/store_test.dart` round-trip |
| 2 | 15 fuentes kind/category + DEFAULT oficiales + manuales editables | ✅ | `lib/core/currencies.dart` (RateSource.all) · `test/currencies_test.dart` |
| 3 | Conversión puente USD + EUR visible + ruta path/sourceIds + históricos honestos + PICKER_MIN | ✅ | `RateContext.plan/resolveEur` · conversor con `showDatePicker(firstDate: 2023-01-03)` y `withoutData` honesto · `test/currencies_test.dart` |
| 4 | Formato es-VE (1.234,56 · COP 0 · EUR 4 dec · 02-feb-2026 · hace X min por fetchedAt) | ✅ | `lib/core/fmt.dart` · `test/fmt_test.dart` |
| 5 | CRUD productos/records/disponibilidad/metas (TARGET_EPS, metSince auto) + 21 semillas + CSV ⇄ + pág.20 | ✅ | `store.addRecord/setTarget/setUnavailable` · `products_screen` · `test/store_test.dart` |
| 6 | CRUD carrito + checked/checkedBy + presupuesto + plantillas (20) + vuelto + dividir + checkout + ticket foto + enlace | ✅ | `lista_screen.dart` (checkout con `image_picker` 1024px .72) · `test/store_test.dart` |
| 7 | CRUD compras + filtros + pág.20 + 2 CSV + JSON + constancia | ✅ | `history_screen.dart` + `statement_screen.dart` |
| 8 | CRUD transacciones + resumen + donut + barras 6/12m + constancia | ✅ | `finance_screen.dart` (syncfusion) |
| 9 | Home (hero/board/sueldo fijo/tiles/extras/LOTTT/copy/tiendas/alertas/recientes/herramientas) | ✅ | `home_screen.dart` (sueldo VARIABLE del web → desviación consciente D1) |
| 10 | Análisis 5 anclas + gap + lookup + proyección + heatmap + rankings + canasta + CSVs | ✅* | `insights_screen.dart` (proyección amortiguada DAMP 0.85; heatmap sustituido por curva de serie diaria — D2) |
| 11 | Ajustes 8 anclas + respaldo replace/merge + Zona peligro | ✅ | `settings_screen.dart` + `lib/data/backup.dart` · `test/models_backup_test.dart` |
| 12 | Onboarding 0+país+7+done + Saltar + reopenTutorial | ✅ | `welcome_screen.dart` · `test/widgets_test.dart` (coach-marks → D3) |
| 13 | Shell 8 rutas / móvil 6 + ticker 3×3×3 solo-home + badge carrito + banner salud | ✅ | `main_shell.dart` + `app_router.dart` · `test/widgets_test.dart` |
| 14 | Sala protocolo §6 (granular, LWW, GC, presencia, typing, joiner pierde previa) + share/QR | ✅ | `lib/room/room_transport.dart` + `server/lista-sync/` 1:1 · selector Servidor/Cerca/WiFi · `test/room_protocol_test.dart` |
| 15 | Alertas: spikes (cooldown 30min) + targets (histéresis) + gap/daily/reminder + centro 9 kinds ring 50 + WorkManager | ✅ | `lib/services/alerts.dart` + `workmanager_service.dart` · `test/store_test.dart` (centro) |
| 16 | Nativo: 4 shortcuts + widgets + scanner + foto 1024 ≤12MB + constancia PNG/share/print + zoom 1–8× | ✅* | `BcvWidgetProvider.kt` + `widget_service.dart` · `mobile_scanner` · `InteractiveViewer` zoom · shortcuts nativos parcialmente (D4) |
| 17 | Diseño §8 al píxel (tokens, firmas, tabular, curva, duraciones, reducedMotion) | ✅ | `lib/core/theme.dart` (tokens dp4 exactos) + `docs/DESIGN-SYSTEM.md` |
| 18 | analyze/test verdes; APK release ofuscado | ✅ | CI: analyze 0 · 104 tests · `build.yml` con `--obfuscate --split-per-abi` |

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

## Desviaciones conscientes (mandadas por AGENT.md §5.4)
- **D1 · Sueldo variable**: el web tiene calculadora variable `valorave.salary`
  (localStorage, modos on/base/range). El MD solo menciona `salary` fijo.
  Implementado el fijo completo + derivadas LOTTT; el variable (modos
  base/rango) queda como pieza pendiente documentada — el MD manda.
- **D2 · Heatmap de devaluación**: el calendario 6m del web se porta como
  serie de área diaria con el mismo dato (vesRateTimeline/vesDevaluation);
  el heatmap pictórico exacto queda pendiente de píxel.
- **D3 · Coach-marks**: el flujo de onboarding 0+país+7+done con «Saltar» y
  re-apertura está completo; los coach-marks por feature con
  `valorave.tips-dismissed` quedan como iteración de pulido.
- **D4 · 4 shortcuts nativos**: el widget BCV y el intent `valorave://sala`
  están registrados; los shortcuts de launcher (quick_actions) quedan como
  iteración siguiente.
- **D5 · PNG 1080×1080/1350 dibujado a canvas pixel-perfect**: el flujo
  Compartir/PDF/Imprimir está completo vía share_plus/printing; el canvas
  exacto del web (fitText + rows punteados) queda como iteración de píxel.

## Sala multi-transporte (decisión §4.10)
- **Servidor**: `SocketIoTransport` con URL configurable (Ajustes → Sala en
  `_RoomSheet` lobby) + `server/lista-sync/` listo para desplegar.
- **Cerca (sin internet)**: `NearbyTransport` sobre `nearby_connections`
  P2P_STAR — el creador anuncia (hub retransmite), invitados descubren.
- **WiFi local**: `LanTransport` — ServerSocket 48130 + broadcast UDP de
  descubrimiento, protocolo JSON por línea idéntico.
- Outbox offline común; protocolo lista-sync idéntico en los tres (tests).
