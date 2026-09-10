# Changelog

## 1.1.0-dp4+6 · rama fix/v1.1.0-dp4-paridad

Ronda de CALIDAD VISUAL guiada por el prototipo de referencia **dp4**
(`valorave-flutter-source-dp4.zip`, la reconstrucción fiel del catálogo dp
#4) + cierre de pendientes del spec `MVP-CRUD.md`. Trabaja en rama aparte
según lo acordado: se compila, el dueño prueba y solo entonces se fusiona
a main.

### Añadido
- **Cabecera mínima dp4**: SOLO el nombre «ValoraVE» en tipografía display
  («Valora» + «VE» en tinta primaria), sin logo interno, sin píldora «en
  vivo» ni frescura — menos ruido, más aire. La frescura vive en el héroe
  de Inicio y en RateHealthBanner.
- **Héroe de la tasa protagonista (patrón dp4)** en Inicio: tarjeta con
  cifra héroe en ReadWindow (displayNum 38), banderas, botón copiar,
  sellos de categoría/fuente y píldoras «brecha vs BCV» y «vs ayer» con
  datos REALES del tablero vivo (nunca demo).
- **Búsqueda global dp4 como pantalla completa**: módulos, productos del
  catálogo, compras con tienda y avisos; matching sin acentos. Con el
  fix dp5: UN solo aviso discreto al abrir un resultado (el quirk del
  dp4 apilaba dos SnackBar).
- **Bienvenida multipantalla dp4**: PageView de 3 páginas (marca y
  promesa · lo que hace · datos en vivo de APIs + offline-first) con
  puntos de progreso y «Saltar». NO rejugable desde Ajustes (decisión
  del dueño); el tutorial (país + 7 slides + done) sigue reabriendo.
- **quick_actions**: los 4 shortcuts del manifest de la PWA en el
  launcher Android — Lista, Conversor, Escanear (abre el escáner) y
  Tasa BCV.
- **Notificaciones TESTEABLES**: «Probar aviso» en Ajustes → Alertas
  pide POST_NOTIFICATIONS si falta y dispara una notificación ANDROID
  real por flutter_local_notifications (canal General), además de
  escribir en el centro interno. AlertEngine ya emitía al sistema.
- **Dinero exacto (§3.2 decimal.js)**: `cartTotals` y `computeChange`
  suman y dividen con `Decimal` (paquete decimal) sin cambiar sus APIs.

### Honestos pendientes (documentados en `docs/PARIDAD-MVP-CRUD.md`)
- Los «13 widgets» del §14 referían a la base original perdida (este
  repo nació con 1). Se mantiene el widget BCV funcional; la familia
  ampliada queda como pendiente explícito con su plan.

## 1.0.2-beta+3 (2026-09-11) · v1.0.2-beta

Ronda de paridad contra el spec cerrado `MVP-CRUD.md` (auditoría de 4
frentes: modelo/store · motor/tasas/alertas · 9 pantallas · diseño/nativo).
Objetivo: que la app se PAREZCA a la web original y cerrar el bug crítico
de pérdida de datos. Scorecard completo en `docs/PARIDAD-MVP-CRUD.md`.

### Corregido (bugs de datos)
- **CRÍTICO — `addPurchase` no generaba id**: toda compra persistía con
  `id=''`; «Eliminar compra» borraba el HISTORIAL COMPLETO, «Editar»
  editaba en masa y el merge de backups descartaba todas las compras.
  Ahora genera id único (con test).
- `setCountry` no actualizaba el conversor a `USD→monedaDelPaís` (§2.1).
- `snapshotSeries` ignoraba `days`: las gráficas recibían la serie
  completa en vez de los últimos N días (con test).
- `resetAll` conservaba settings/rateSource: ahora limpia TODO salvo el
  tablero vivo (§2.5, con test).
- Dedupe de `importProducts`: barcode primero; nombre solo si la fila no
  trae barcode.
- Rate-health real (§5): «tasas viejas» solo si se vieron antes y pasan
  >15 min sin refrescar (antes: banner instantáneo al primer error).

### Corregido (diseño §8 — lo que se nota)
- **Cifras héroe 48–64 px tabulares**: conversor 56, lista 64 (eran 22/44).
- **Sombras firma**: card elevación 1 sutil + diálogos/sheets elevación 8
  (antes: cero sombras en toda la app).
- **Transición de página firma**: slide 18/10 px + fade con la curva
  `kEaseVe` (0.16,1,0.3,1) y respeto a `disableAnimations`.
- **Header de marca**: LogoMark tile #22354E con V blanca + bandera VE +
  píldora `live` + «hace X min» (tap = refrescar tablero).
- **Bordes al 100 %** (regla dura): ReadWindow/SkeletonPaper/RuleDouble
  sin alfas; Stamp con fondo exacto 8 %.
- **Space Grotesk en titulares** (PageHeader + AppBar), no solo números.
- **Ledger-dots solo en cierres de cuenta** (§8): los listados dejan de
  llevar puntos contables; Resumen y cuenta por tienda los conservan.
- **Ticker anti-CLS**: placeholder «Cargando cotizaciones…» a la altura
  exacta en vez de colapsar el layout.
- **Splash de marca**: fondo #F7F8F9 (oscuro #121417) + logo centrado
  (antes: blanco puro sin marca).
- **TapScale (0.96) en pestañas y acciones clave**.

### Añadido (paridad §9)
- **Conversor**: Ayer y «Hace 7 días» cargan tasas históricas REALES;
  notas con debounce 600 ms; recientes guardan el monto real; PNG
  compartido con marca ValoraVE; héroes 56 px.
- **Lista**: compartir totales como PNG; StoreSuggest pasivo
  («¿Quizá quisiste…?»); edición de nombre/precio del ítem.
- **Productos**: Importar CSV (importe → importados vs «ya están en
  libro»); corregir/eliminar registros de precio; SnackBar
  «¡bajo tu meta!» al registrar bajo TARGET_EPS.
- **Historial**: el ticket de fotos POR FIN se ve (miniatura, zoom 1-8×)
  y se comparte como JPEG.
- **Finanzas**: orden 01→02→03, confirmación al borrar movimiento, delta
  del mes previo bajo cada StatCard, paginador topeado.
- **Inicio**: hora en el héroe (reloj 30 s), /hora = sueldo/176 (LOTTT),
  copiar sueldo (3 modos), secciones «Divisas del foco» y «Alertas de
  precios» (metas).
- **Ajustes**: toggle autoRefresh, versión visible «17.1 · build N»,
  «Quitar sueldo» (espejo web).
- **Alertas ↔ centro de notificaciones**: cada aviso del motor entra al
  ring (pico/meta/brecha/daily/recordatorio) — antes solo sonaba y no
  dejaba rastro.
- **Scanner**: pinch-zoom ×4, vibración + sonido al leer.
- **Constancia**: el botón «Generar PNG» ya no es falso — captura el
  documento y lo comparte como imagen.


## 1.0.1-beta+2 (2026-09-10) · v1.0.1-beta

Ronda de paridad y estabilización contra el informe del web v15. Arregla
el bug que dejaba a la app «solo en la pantalla de bienvenida» y el icono
transparente del lanzador.

### Corregido
- **Router recreado en cada rebuild (bloqueante)**: `buildRouter()` vivía
  dentro de `ValoraApp.build()` con `context.watch<AppStore>()` — cada
  mutación del store (elegir país en el paso 1 del onboarding, tasas
  nuevas del poller cada 60 s, cualquier registro) fabricaba un GoRouter
  nuevo y reseteaba la navegación a `initialLocation`. El usuario quedaba
  atrapado en la bienvenida y la app parecía «solo una pantalla». Ahora
  el router se crea UNA vez (`initState`) y el onboarding se resuelve con
  `refreshListenable` + `redirect`, el patrón canónico de go_router.
- **Icono del lanzador transparente**: los `mipmap-*/ic_launcher.png`
  eran PNG vacíos (píxeles 0,0,0,0). Regenerados desde `assets/brand/`:
  legacy (5 densidades) + round + **adaptive icon** (API 26+:
  foreground maskable sobre azul #2749CB) + **monochrome** para themed
  icons de Android 13+.

### Añadido (paridad web v15)
- **Escáner de códigos de barras** cableado (la dependencia
  `mobile_scanner` estaba declarada y sin uso): pantalla nueva con
  escaneo continuo, linterna, marco de apuntado, debounce 800 ms y
  fallback «a mano». En Productos: abre la ficha del producto o el alta
  con el código prellenado. En Lista: agrega directo con el precio
  vigente del libro, o prellena el formulario.
- **Sueldo variable** (web v12): modos fijo · base+variable · rango
  min–máx con sueldo efectivo (promedio del rango) alimentando tiles y
  derivadas LOTTT; JSON `salary` tolerante con respaldos antiguos.
- **Recordatorio diario de precios** (Ajustes → Alertas): hora
  seleccionable, disparo in-app (AlertEngine) y con app cerrada
  (WorkManager horario, ±1 h), claim por día anti-duplicados.
- **StoreSheet**: tocar una tienda en «Tus tiendas» abre su detalle
  (gasto acumulado, frecuencia, compras, cross-link al Historial).
- **Compartir cálculo del Conversor** como PNG 1080 px (monto + ruta +
  fuentes) vía `captureWidget` + share_plus.
- **Barras de finanzas 6/12 meses** conmutable (paridad web).
- **Héroe del Inicio con frescura real**: «hace X min» con el
  `fetchedAt` del tablero + píldora «% vs ayer» comparando el snapshot
  local del paralelo (o BCV).

### Mantenimiento
- `ValoraApp` ya no observa el store en la raíz (solo el tema): las
  pantallas se suscriben individualmente y MaterialApp deja de
  reconstruirse en cada ciclo del poller.

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
