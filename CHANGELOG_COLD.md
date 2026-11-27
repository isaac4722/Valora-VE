# Changelog

## 1.16.0-beta+49 · v24.0c — todas las gráficas sobre fl_chart (la librería de CalculaYa)

Orden del dueño: «arregla las gráficas todas las gráficas usando la misma
librería de gráficas que tiene CalculaYa». fl_chart **1.3.1** (confirmada
por REA del APK de la app de referencia) — la misma que pinta su historial.

- **VeTimelineChart → `LineChart`**: multi-serie con eje Y COMPARTIDO (la
  normalización por serie de la era syncfusion era un truco del pintor;
  todas las series de la app viven en la misma unidad y el eje único dice
  la verdad), rejilla punteada 25/50/75 % (`--border`), ejes X 0/⅓/⅔/1 con
  `xLabel` e Y opcional con `yLabel`, áreas degradadas 28 %→0, series
  punteadas (proyecciones), crosshair + puntos por serie (indicador de
  fl_chart punteado en `--faint`) y el chip de valores de SIEMPRE
  (`tooltipBuilder`/TipBox intacto — el tooltip interno apagado, el
  overlay de la app pinta el chip; `onScrub` sigue sincronizando el panel
  del día en Brecha).
- **VeSparkline → `LineChart`** mini (polyline 1.6 px, sin ejes; vacío =
  línea punteada al 30 %). **VeBars → `BarChart`** (barras 26 px
  redondeadas, tooltip al tocar, etiquetas abajo, crece con kEaseVe).
  **VeDonut → `PieChart`** (anillo 68 %, ciclo de tonos, leyenda propia
  intacta).
- **Retirados**: VeAreaChart y VeHeatmap (cero llamadas en producción —
  vivían solo en el test del kit) y el Sparkline legacy de ui.dart (código
  muerto desde v20). CustomPainter queda para lo decorativo (banderas ₮/Ξ,
  ambientes, bordes punteados) — los DATOS viven en fl_chart.

Gates: analyze 0 · 313/313 · auditoría VERDE.

## 1.16.0-beta+49 · v24.0b — Material 3 nativo: shadcn_ui fuera

Orden del dueño: «usa la nativa de Material 3 que tiene Flutter, una
interfaz más simple y mejor». La capa shadcn_ui (TASK-33/34) se retira
COMPLETA y el kit Ve se reconstruye sobre Material puro — misma piel,
mismas medidas.

- **`VeThemeData` (core/ve_theme.dart)**: fachada con la MISMA superficie
  que `ShadTheme.of` (`context.ve.colorScheme.*` + `.brightness`) — las
  102 llamadas de pantallas son un rename mecánico. Tokens 1:1 con
  VeColors (guardián: test/ve_theme_test.dart, el sucesor de
  shad_theme_test). Radii firma 10/8 (`kVeRadius`/`kVeControlRadius`).
- **Kit Ve sobre Material puro**: `VeBtn`/`VeChip` sobre un botón crudo
  propio (Material + InkWell, estados hover/pressed animados, alturas
  exactas 28/36/44); `VeIconBtn` con `Tooltip` nativo; `VeBadge` Container
  puro; `VeToggle` 32×18 propio con Semantics(toggled); `VeCheckbox` 18 px
  con InkWell y el pop intacto; `VeInput` sobre `TextField` (36 px, sin
  contador); `VeSelect` sobre `MenuAnchor` — controlado, sin remount.
- **Hojas**: `showVeSheet` = `showModalBottomSheet` (móvil) + `showDialog`
  (escritorio) con el chrome intacto; TECHO del 88 % ahora resuelto con el
  MediaQuery del contexto que ABRE (useSafeArea del bottom sheet exponía
  padding cero y el techo se inflaba — fix con test del notch al verde).
- **main.dart**: `MaterialApp.router` directo (adiós ShadApp.custom y
  GlobalShadLocalizations); DynamicColorBuilder + AppTheme intactos.
- **Lucide directo** (`lucide_icons_flutter`) en los 25 archivos que lo
  tomaban del re-export de shadcn; `intl` explícito donde shadcn lo
  re-exportaba.
- **pubspec**: `shadcn_ui` FUERA (cero referencias). Tests: 13 harnesses
  sin el wrapper ShadApp; ve_kit_test mide el Material interno (contrato
  28/36/44) y los CustomPaint de gráficos acotados al widget.

Gates: analyze 0 · 316/316 · auditoría VERDE.

## 1.16.0-beta+49 · v24.0a — Riverpod como estado (patrón CalculaYa), provider fuera

Orden del dueño: «usa riverpod para manejar los estados como lo hace
CalculaYa». flutter_riverpod **3.5.0** (la misma línea mayor que la app de
referencia, confirmada por REA de su APK): notifiers manuales, sin codegen.

- **`lib/providers/` nueva (patrón CalculaYa)**:
  `sharedPreferencesProvider` (fail-fast: se sobrescribe en main — el
  assert textual de CalculaYa), `appStoreProvider`, `themeControllerProvider`
  (override con instancia hidratada antes del primer frame, offline-first
  intacto), `notificationsProvider`, `connectivityProvider`,
  `alertsProvider`, `ratesPollerProvider` y `roomControllerProvider`
  (nacen solos bajo demanda, el `RatesNotifier`/`ratesProvider` de CalculaYa
  en dialecto ValoraVE). Puente legacy `ChangeNotifierProvider` (riverpod 3)
  mantiene AppStore/RatesPoller/RoomController tal cual: la REGLA DE ORO de
  v23.0e sigue — cero cambios en el core de persistencia.
- **main()**: `runApp(ProviderScope(overrides: [...]))` — lo que hidrata
  antes del primer frame entra por overrides (igual que CalculaYa), lo
  demás nace solo. `appProviders()` (mundo provider) retirado.
- **UI**: 29 archivos migrados a `ConsumerWidget`/`ConsumerStatefulWidget`;
  114 `context.watch/read` → `ref.watch/read(xProvider)`; los 11 `select`
  de perf conservados como `ref.watch(x.select(...))` (mismo contrato de
  rebuild mínimo en el shell). Funciones de hoja top-level
  (showRateSheet/showManualRateEditor/showNotificationCenter/showPagoMovilSheet/
  toggleVeTheme/veEffectiveDark/tips/tour) reciben `WidgetRef` — el mismo
  patrón de CalculaYa con providers como valor de primera clase.
- **Tests**: 12 harnesses `MultiProvider` → `ProviderScope(overrides:)` +
  visual gate; tips/tour tolerantes a harness parcial (el ProviderException
  de riverpod ocupa el lugar del viejo ProviderNotFoundException).
- **pubspec**: `provider` y `nested` FUERA (cero referencias en el árbol).

Gates: analyze 0 · 318/318 · auditoría VERDE.

## 1.15.0-beta+48 · v23.3a — cierre H2 de la revisión EGM: avisos suaves simétricos en el alta de cuentas

El parche `0002-fix-pago-movil` (turno v23.0h) quedó fuera de la cadena
que el dueño aplicó (0002-feat…0005, ver PROGRESS «v23.2-RECUPERA»);
este turno lo cierra ENCIMA de v23.3, adaptado a la hoja Ve del kit.

- **H2 · `pagoMovilSoftWarnings()` pura**: cuenta 20 dígitos · cédula
  5-9 (la letra no cuenta) · teléfono 11; vacío no avisa, espacios y
  guiones no son dígitos. El alta junta TODOS los avisos en UN solo
  snackbar y el guardado NUNCA se bloquea (la longitud real varía por
  banco — hallazgo goldfish). Antes: un único chequeo de la cuenta.
- **Bug latente cazado por el test del alta**: los controllers se botaban
  al resolver la hoja, ANTES de que terminara su animación de salida
  («used after being disposed» en el fade). Dispose diferido 400 ms —
  viven lo que dura el texto.
- **6 tests** (4 puros + 2 de widget con la hoja Ve real a 390×844: CI
  corto avisa Y la cuenta queda guardada; datos completos → sin
  snackbar). Los de widget adaptados al chrome Ve de v23.3: los campos
  son `VeField`+`VeInput` (rótulo fuera del campo), se direccionan por
  orden de `EditableText`, no por el `labelText` viejo.

## 1.15.0-beta+48 · v23.3 — auditoría doble pez→elefante: integridad de datos, chrome unificado y gate visual con iconos reales

Orden del dueño: subagentes TOTALEMENTE sin contexto en modo fish para un
análisis completo y terminar sin nada pendiente, ejecutar todo y darle
polish a las pantallas. Dos peces auditaron (solo lectura, archivo:línea):
2-a UX/visual (21 piezas: pantallas core + sheets + kit) y 2-b
arquitectura/data-layer (board, estado, persistencia, inventario ticker
completo: 24 ocurrencias — 20 OK, 3 sospechosas, 0 fugas). Elefante
ejecutó TODOS los hallazgos P0/P1/P2 + el ítem Análisis pendiente.

**Integridad de datos (pez 2-b):**
- **P0-1 · Import «Reemplazar» perdía `customRates` y `accounts`**: el
  `AppData` reconstruido de ambos caminos (backup.dart + la ruta paralela
  de settings_system) omitía las listas v23 → caían a `[]` en silencio.
  Arreglado en ambos + conteos en `MergeCounts`/toast de fusión + test de
  round-trip que fija el contrato.
- **P1-1 · El SSE REEMPLAZABA el tablero fusionado del poll**: un payload
  parcial (despliegue web sin cripto/CO) borraba fuentes hasta el próximo
  poll. Ahora `mergeSseSources` (pura, testeada) FUSIONA por id: lo
  ausente sobrevive y un push viejo no pisa un dato fresco.
- **P1-2 · El poll revivía en background**: un flap de red tras el
  stopAuto de los 10 min re-armaba el ciclo para siempre (y el callback en
  vuelo re-armaba tras la cancelación). Bandera `_autoPaused`: nada se
  re-arma sin startAuto (markActive al volver).
- **P1-3 · CalculaYa se consultaba en TODAS las rondas**: la condición se
  evaluaba antes del fetch de euros (con `eur-ves-oficial` aún ausente) →
  request desperdiciado en cada poll. El respaldo vive DESPUÉS del bloque
  de euros; y `mergeRegionBlocks` filtra claves `__` (el contrato del
  puente de derivación ya no depende del caller).
- **P1-4 · El sello de la derivación Bs/USDT mentía**: usaba el máx de
  updatedAt (CoinGecko estampa ahora()) → «hace 0 min» sobre un paralelo
  con horas. Sello honesto = mín (test actualizado al comportamiento
  verdadero); guard de finitud explícito (P2-4) + bordes exactos 0.2/2.0
  con tests.
- **P2-1..P2-9**: timeout cancela DE VERDAD el request (CancelToken + no
  reintentar cancelaciones); backoff muerto y catch muerto de `_brBlock`
  fuera; memo del Worker de CalculaYa (1 consulta por ventana de 30 s
  compartida por VE/CO/cripto — antes hasta 3 idénticas por ronda);
  `_PopCheck` solo anima al marcar (patrón VeFlash); flush final en
  `detached` (`AppStore.flushAll`); doble merge de `_import` eliminado
  usando el resultado de `importBackup`.
- **Inventario ticker/timer completo** (pez 2-b, encargo del dueño): 24
  ocurrencias documentadas con veredicto por ocurrencia; las 2 sospechosas
  de verdad se cerraron (P1-2 y _PopCheck).

**UX/visual (pez 2-a + gate visual):**
- **P0-1 · Chrome de hojas UNIFICADO**: las 7 hojas que quedaban crudas
  (fuentes del Conversor, export×2, Pago Móvil, alta de tasa propia, alta
  de cuenta, calendario histórico, galería de App Widgets — esta última
  hallada al ejecutar la auditoría) migran a
  `showVeSheet`/`showVeHalfSheet`: radio 14, asa, cabecera 48 + ✕, pie
  con VeBtn, `VeField`/`VeInput`/`VeSelect`/`VeSegmented` en los formularios
  (adiós a OutlineInputBorder/DropdownButtonFormField/SegmentedButton
  Material/TextButton/FilledButton de segunda piel).
- **Ítem Análisis pendiente cerrado**: barra de anclas FIJA (título +
  anclas + rango fuera del scroll — los paneles largos ya no se llevan la
  navegación), 4 gráficos 190→184 (familia unificada), pestañas con
  `Semantics(selected)` + una línea con elipsis, sombra de la píldora en
  tokens (`VeColors.shadowLight/Dark`).
- **P1-1 · Targets táctiles**: VeIconBtn visual 32/pista 44 (GestureDetector
  opaco exterior), ✕ de hojas y swap del Conversor a 44, borrar-tasa de
  Ajustes 23→44 dp + `Semantics` (acción destructiva), lápiz del selector
  25→44, steppers de carrito/canasta a 36 (densidad de fila preservada,
  AA holgado), acciones del Conversor md→lg (44).
- **P1-2..P1-4**: hint offline del Inicio a UNA línea (el claim v23.2 no
  había llegado a ese estado); cifras del Historial en `VeNum` tabular;
  el chip «Plantillas» de Lista ahora SÍ scrollea a su ancla
  (`ensureVisible`; la GlobalKey existía pero nadie la usaba).
- **P2**: KpiTile 12/12 (el 13 rompía la rejilla que su propio comentario
  declara), borde del heatmap del esquema (el negro plano era invisible en
  dark), «BCV hoy»/«Paralelo hoy» → «BCV»/«Paralelo» (la etiqueta larga
  envolvía a 2 líneas a 390 — precedente «Brecha» v21), respiro 8 entre
  «TOTAL DE LA COMPRA» y el badge Bs.
- **Gate visual con iconos REALES**: MaterialIcons no es asset de la app
  y en tests la familia cae a Ahem — TODOS los `Icons.*` salían como tofu
  □ en los goldens desde v20 (pestañas de Análisis, swap, chevrons…).
  El gate ahora carga el OTF del caché del SDK (FLUTTER_ROOT con
  caminata de respaldo, portátil). Goldens regenerados y auditados por
  VLM: Conversor y Análisis APROBADOS directo; Inicio y Lista verificados
  por zoom (ticker-marquee y fixture de fechas son por diseño, no cortes).
  Nota honesta: el estado OfflineState se queda con su `Card` del tema
  (borde + sombra firma §8 ya de la paleta) — solo el copy cambió.

analyze 0 · 312/312 (20 tests nuevos: round-trip replace, fusión SSE ×3,
contrato `__tetherDerive__`, bordes de guardia, parsers tolerantes ×2,
galería a viewport móvil ×3) · auditoría de prohibiciones VERDE.

## 1.15.0-beta+48 · v23.2 — patrón calculadora, cripto USDT+ETH y failover CalculaYa (EGM pez→elefante + impeccable + humanizer)

Orden del dueño: «los elementos salen de pantalla — no es una calculadora
normal donde los datos no hay que subir y bajar», subir la calidad visual
de proporciones, escritura UX de claves cortas y, por REA del APK de
CalculaYa 1.1.0, usar su Worker público como respaldo y sumar USDT/ETH
con iconografía propia. Skills aplicadas: impeccable-uxui (proporciones,
jerarquía, anti-slop), humanizer (textos ≤1 línea). Modo pez: auditoría
verídica con archivo:línea de las Core 5 + sheets (12 correcciones TOP).

- **Cripto USDT + ETH** (orden del dueño): 8 divisas del foco — fuentes
  15→20: `usdt-ves` (referencia P2P, arista DIRECTA Bs↔USDT),
  `usdt-usd` (tether global), `eth-usd` (CoinGecko) + manuales; símbolos
  ₮/Ξ (cmap verificado en Inter/JetBrainsMono) y sello PINTADO
  `CryptoFlagPainter` (₮ teal Tether · rombo indigo ETH, cero assets
  nuevos); tintas `usdt`/`eth` en VeColors/VeInk/currencyInk.
- **Failover CalculaYa/CoinGecko en el tablero**: Worker público
  `calculaya-api.jalvarezgw19.workers.dev/tasas` (hallado por REA del APK;
  `usd` = BCV oficial verificado AL DÍGITO en vivo) como respaldo VE #2
  que NUNCA pisa dato fresco + COP mercado #2 (remesas); bloque cripto
  (`_cryptoBlock`): USDT P2P desde CalculaYa, ETH/tether desde CoinGecko;
  derivación honesta de último recurso Bs/USDT = paralelo × tether con
  guard 0.2–2 USD; diagnóstico añade «Cripto».
- **Conversor = patrón calculadora** (hallazgo pez #1/#2): teclado
  VeKeypad como PISO FIJO (teclas 44dp) — la cifra SIEMPRE a la vista, en
  modo «Hoy» no hay scroll; Fuentes·Tabla·Recientes·Notas → half-sheets
  (adiós al ListView de 2.200dp); fichas 1-100 en una línea; acciones con
  iconos + Semantics; dual input comprimido (34/40) con cifras
  FittedBox-blindadas; fecha sin tarjeta envolvente; textos humanizados.
- **Lista despejada** (hallazgo pez #3): captura manual de 3 filas → 2
  (tienda deja de robar una fila); héroe 64→48 (escala única con el
  Conversor); frecuentes + totales por moneda + plantillas viven tras
  «Más» (despliegue progresivo, patrón del Home); «Presupuesto y vuelto».
- **Inicio de primera pantalla**: Cotización con RateTile compacto
  (filas ~50dp, mismas fuentes); Divisas del foco + Tu mes pasan tras
  «Ver todo» con alertas/tiendas/herramientas; textos-ensayo de estados
  offline/primera carga → una línea (humanizer).
- **Libro**: chips de categoría → UNA línea con desplazamiento horizontal (dejan
  de comer 2-3 filas).
- **Kit** (evolución, no reemplazo): `VeChip` gana `dense` (padding 6) e
  `icon` (13px, alto 28 intacto — ve_kit verde); techo de `showRateSheet`
  unificado al 88 % de `showVeSheet` (adiós a los dos techos).
- **Provider optimizado** (decisión del dueño: NO Riverpod): selects
  granulares donde el watch era grueso; el conversor y el shell ya usaban
  select — los rebuilds por ciclo del poller quedan aislados con
  RepaintBoundary en los pisos.
- **Tests al teléfono real**: viewport 390×844 (fin del 1600 que delataba
  el scroll del conversor) + fuentes reales en pago_movil_test; contratos
  de banderas fiat/cripto separadas; foco = 8 divisas; parsers de
  CalculaYa/CoinGecko con payloads reales de curl 21/11/2026;
  derivación con guards; goldens del gate regenerados y verificados a la
  vista (conversor y lista sin scroll). analyze 0 · suite verde ·
  auditoría VERDE.

## 1.15.0-beta+48 · v23.0 — GUI simple «Instrumento directo» (EGM goldfish + comparativa CalculaYa 1.1.0)

Orden del dueño: «un GUI más simple», comparar las funciones en común con
CalculaYa 1.1.0 (ingeniería inversa con REA/apktool sobre su APK) y usar
la mejor de cada una — **resumir sin quitar**. Diseño en modo goldfish:
cada decisión trazada a evidencia del repo o del APK; hallazgos
resueltos antes de implementar. Todo dentro de «El Instrumento» (§8), que
se evoluciona y no se reemplaza.

- **Inicio en 4 bloques con despliegue progresivo**: héroe + cotización +
  «tu mes» a la vista (la cifra que importa, ui-nice-skill: un foco);
  alertas de precios, tiendas, registros, herramientas y la tarjeta de
  App Widgets viven tras el eyebrow «TODO LO DEMÁS · Ver todo» con
  AnimatedSize. Mismas secciones FIJAS de v19.6, mismo orden, a un toque.
- **«Libro» visible en móvil** (mal configurado corregido): la sección
  «Libro» del sidebar de escritorio (Historial · Tickets · Ajustes)
  ahora vive SIEMPRE al pie del Inicio — antes solo se alcanzaban por
  deep-links dispersos y en teléfono no existía puerta visible.
- **VeKeypad en el Conversor** (patrón estrella de CalculaYa): teclado
  propio 0-9 · «,» es-VE · ⌫ — Inter tabular, borde 100 %, háptica
  sutil, Semantics por tecla, blancos ≥48dp — desplegado por defecto y
  plegable; escribe en el campo ACTIVO (la edición bidireccional v19
  queda intacta) + fichas 1/5/10/20/50/100 + toggle
  [Decimales|Redondear] persistido: el redondeo toca SOLO la vista del
  resultado, la línea «≈» y la ruta conservan la cifra exacta.
- **Tasas personalizadas con nombre y brecha** (patrón de CalculaYa):
  «Zelle», «Efectivo»… (máx 8) en la Cotización del Inicio con
  GapChip «+x,x % vs BCV» (tinta warn si la prima >5 %; sin BCV no hay
  chip, jamás «NaN»). REGLA DE ORO: aplicar una tasa propia reusa el
  mecanismo manual EXISTENTE del motor — cero cambios en el core; las
  manuales por fuente siguen intactas como modo avanzado. Merge de
  respaldo por id (unión): la «Zelle» del respaldo sobrevive.
- **Cuentas y Pago Móvil** (función estrella de CalculaYa): cuentas de
  cobro propias (banco · tipo · número · CI · teléfono, máx 4) en
  Ajustes con catálogo de los 27 bancos de pago móvil en TEXTO (sin
  logos de terceros), validación suave (aviso ≠20 dígitos, sin bloqueo)
  y candado biométrico OPT-IN (default OFF). El botón «Pago Móvil» del
  Conversor —solo con destino VES— arma el mensaje de cobro con el
  monto en bolívares + los datos, aviso de sensibilidad y
  copiar/compartir. Texto legal al día en el mismo commit;
  allowBackup=false ya vigente.
- **Textos al día**: el tour decía «Inicio · Divisas · …» y «la lupa» —
  la pestaña es «Conversor» desde v22.0 y la lupa de la CABEZA sigue
  viva (la retirada v20 fue del FAB flotante). Paleta ⌘K unificada y
  los ajustes señalados al bloque «Libro» del Inicio.
- **Tests con fuentes reales**: widgets_test carga las Inter/
  SpaceGrotesk del asset (patrón de gui_correcta_test) — la fuente de
  fallback del entorno de test fabrica overflows falsos («+10 %» mide
  60 px ahí, ~34 en Inter).
- **No adoptado de CalculaYa** (privacidad/peso, política §1 del repo):
  AdMob, compras IAP/premium, FCM/Firestore, RemoteConfig con kill
  switch, OCR ML Kit (+6,7 MB/ABI), multi-idioma (es-VE es identidad).

Gates: analyze 0 · 291/291 tests (25 nuevos) · auditoría de
prohibiciones VERDE.

## 1.14.4-beta+47 · v22.4 — instalación in-app: la app descarga el APK y lanza el instalador de Android

Orden del dueño: «No quiero eso, quiero que la app se descargue el APK de
la release (temporalmente) instale no un atajo y descargar e instalar
manual». v22.3 avisaba y mandaba al navegador; esta ronda cierra el ciclo
COMPLETO dentro de la app.

- **Descarga in-app con progreso** (`lib/services/instalador_apk_vm.dart`):
  baja el APK de la Release a `<cache>/valora_update/<nombre>.apk`
  (carpeta declarada al FileProvider) con porcentaje en vivo por fila —
  el tamaño esperado ya viaja en la Release, así el % marcha aunque el
  servidor no mande content-length. El caché del sistema es el hogar del
  archivo: Android puede reciclarlo sin pedir nada al dueño y si eso
  pasa la fila vuelve a «pendiente» con un aviso honesto.
- **Instalador de Android first-party** (canal `valorave/instalador` en
  MainActivity.kt): el APK descargado se sirve como `content://` vía
  FileProvider de autoridad PROPIA (`${applicationId}.instalador` —
  sufijo que ningún plugin usa; las del lock son `.flutter.*`) y el
  intent ACTION_INSTALL_PACKAGE abre la ventana de instalación del
  sistema sobre él. Sin plugins terceros: el manifest lo escribe el
  propio repo, que era justamente el riesgo del updater de pub.dev
  descartado en v22.3.
- **El permiso de Android 8+ se pide bien**: «Instalar apps
  desconocidas» se consulta ANTES de gastar la descarga
  (`puedeInstalar`) y el diálogo ofrece abrir el ajuste exacto de
  ValoraVE (`abrirAjustesOrigen`), no el menú general. Una sola vez y de
  ahí en adelante las rondas se instalan directo. `REQUEST_INSTALL_PACKAGES`
  declarado en el manifest con su porqué al lado.
- **Sin tokens ni credenciales**: la descarga sale de la URL pública de
  la Release (repo público) y la consulta sigue anónima (60/h por IP,
  con su mensaje propio si GitHub limita). Nada sale del teléfono.
- **Web conserva la vía navegador** (v22.3): el stub del facade
  responde «no disponible» y las filas vuelven a abrir el navegador —
  en web no hay filesystem compartible ni instalador de sistema. El pie
  de la pantalla cuenta la verdad de cada plataforma.
- androidx.core declarado EXPLÍCITO en build.gradle.kts (el manifest ya
  referencia androidx.core.content.FileProvider; la versión no depende de
  la transitividad de terceros).
- 5 tests nuevos (266 en total): descarga real con adaptador de dio sin
  red (archivo en disco temporal + progreso por chunk), gate honesto de
  disponibilidad fuera de Android, y la pantalla con instalador
  fabricado — ciclo completo, permiso con diálogo, fallo de descarga y
  reintento limpio.

## 1.14.3-beta+46 · v22.3 — actualizador del canal dev: la app se entera de las Releases de GitHub

Orden del dueño: crear el actualizador «adecuado para todo el desarrollo
de la App (no para producción)». CI ya publicaba cada tag «v*» como
Release (v17.9/v19.2: los 4 APK + AAB + ZIP); faltaba el lado de la app.

- **Nueva pantalla `/actualizaciones` (Ajustes → «Buscar actualizaciones»)**:
  consulta anónima a api.github.com, compara el build instalado
  (PackageInfo) con el tag más reciente y anuncia si hay algo nuevo — con
  las notas de la Release (el markdown de GitHub aplana a texto), la
  fecha y las 4 filas de descarga por ABI con su tamaño (arm64,
  universal, v7a, x64). Con el kit Ve de siempre: PushScreen con
  «Volver», VeCard, toasts, safe-areas.
- **Comparador propio de versiones** (`lib/data/github_releases.dart`):
  lee los DOS formatos que ha tenido el repo (`v1.0.2-beta` histórico y
  `1.14.3-beta+46` de pubspec), estable > pre-release, build number de
  desempate. Un tag raro no rompe la comparación — se muestra y ya.
- **Sin permisos nuevos, sin código nativo, sin tokens**: la descarga va
  por el navegador del sistema (`url_launcher`, first-party — su familia
  ya viajaba transitiva en el lock) y la instalación por el instalador
  de Android: el mismo gesto de siempre, solo que la app ahora avisa
  cuándo hay algo nuevo. El repo es público: la lectura de Releases no
  lleva credenciales y jamás va un PAT dentro del APK.
- **Plugin tercero descartado** (`github_release_apk_updater`, 1.0.11):
  exige FileProvider con external-path y REQUEST_INSTALL_PACKAGES en el
  manifest anfitrión, y su propio registro arregla conflictos de fusión
  de manifest hasta 1.0.11. Lastre para un canal de desarrollo; esta vía
  no toca el manifest de producción.
- **Fallos en cristiano**: rate-limit de GitHub (60/h anónimas por IP),
  sin conexión, 404 y respuestas raras tienen mensaje propio y
  «Reintentar». La nota al pie declara la consulta anónima, en el mismo
  lenguaje de la pantalla Legal.
- 18 tests nuevos (261 en total): comparador, parser del payload real con
  ambos estilos de nombre de APK, cliente vía adaptador de dio sin
  red, y la pantalla completa (novedad / al día / sin Releases /
  reintento / aviso cuando el navegador no puede abrir).

## 1.14.2-beta+45 · v22.2 — documentación de proceso recuperada

Orden del dueño: «recupera todos los MDs o lo que borraste por
equivocación». Vuelven al repo los archivos de proceso retirados por
error en la ronda v22.0, EXACTAMENTE como estaban (fuente: historial
git):

- `AGENT.md`, `MVP-CRUD.md`, `PROGRESS.md`, `PROGRESS_WARM.md`,
  `PROGRESS_COLD.md`, `CHANGELOG_WARM.md`, `CHANGELOG_COLD.md`,
  `skills-lock.json` y `.agents/skills/` completa (201 archivos de
  skills del agente) — 209 archivos en total.
- `server/lista-sync/README.md` vuelve a tener su referencia canónica
  (MVP-CRUD.md §6).
- La app no cambia: mismo código de v22.1 (compila nativo y web), solo
  sube la versión visible.
- El changelog y la bitácora HOT se pasaron por el tamiz del dueño:
  fuera toda mención a la herramienta que ya no existe en el repo.

## 1.14.0-beta+35 · v21.1 — pulido de instrumento (continuación de la ronda GUI)

Segunda pasada sobre la v21.0, rebase incluido. Refinamiento que preserva
el mundo visual zinc/Linear — nada de rediseño, todo con los tokens de
siempre:

- **Superficies del navegador tematizadas**: `TextSelectionThemeData`
  (cursor tinta, selección `--muted` al 28 %) y `ScrollbarThemeData`
  (pulgar fino 4 px redondeado que sube al hover/arrastre, sin pista).
  La selección de texto y el scroll dejaron de ser azules de fábrica.
- **Píldora activa en la barra inferior**: el tab vivo se apoya en
  `--subtle` (muted) con la curva firma kEaseVe (220 ms) y el rótulo pasa
  a w700; el inactivo queda plano. Mismo patrón en ambos brillos.
  ESTRUCTURA SENSIBLE documentada en el código: dentro de
  `bottomNavigationBar` nada puede expandirse al alto ofertado (un
  Container/Align con `alignment` llenaba la pantalla y dejaba el body en
  0 px — el test de notch del dueño cazó el bug en el primer intento).
- **Presión táctil en VeCard**: las tarjetas interactivas se asientan
  1.5 % al tocar (140 ms) y respetan `disableAnimations`. El hover de
  escritorio sigue igual.
- **Vacío de Productos con criterio de búsqueda**: el medallón
  scanBarcode solo se pinta sin filtro — con una búsqueda sin resultados
  el vacío queda solo-texto, que es lo honesto.
- **pubspec.lock al día**: el lock comprometido databa de gui-33 y no
  contenía csv/talker* (v20.4) — `pub get` lo completa; ahora está en el
  repo.

Gates: flutter analyze 0 · 238/238 tests · detector Impeccable sin
hallazgos · build web verificado en 127.0.0.1:3000 (Inicio/Divisas/Lista/
Análisis en claro y oscuro).

## 1.13.0-beta+33 · v20.4 — auditoría de paquetes (orden del dueño)

Verificación punto por punto del análisis del dueño contra el código real
(los 7 puntos eran reales; el alcance real de cada uno era mayor de lo que
decía el análisis) y corrección completa:

- **Fotos de ticket FUERA del JSON de estado (impacto crítico, confirmado)**:
  `Purchase.ticketPhoto` guardaba un data URL base64 de ~200 KB DENTRO del
  `AppData` — el `jsonEncode` de cada interacción movía megabytes. Ahora
  (nativo) la foto vive una sola vez como JPEG en `<docs>/tickets/*.jpg`
  (path_provider) y la compra guarda SOLO la ruta relativa. Migración única
  en el arranque (`migrateTicketPhotosToFiles`, fire-and-forget, falla suave:
  lo que no migra queda como data URL). Web sin filesystem: data URL como
  siempre. Al quitar/reemplazar foto el archivo se borra del disco (cero
  huérfanos) y `compressOldTicketPhotos` re-encodifica EN el archivo.
- **IsolatedHive para 2º plano (confirmado — hive_ce corrompe cajas si dos
  isolates abren la misma caja)**: en nativo la app Y el worker de
  workmanager pasan por `IsolatedHive` con el `IsolateNameServer` del
  proceso (`lib/data/ins_server*.dart`): quien llegue primero crea el
  isolate de Hive y el otro SE CONECTA — un solo dueño de los archivos.
  Web sin isolates (delega en Hive plano) y tests con el camino plano de
  siempre (`_BoxRef` esconde la diferencia al store).
- **uuid v4 para IDs P2P (confirmado)**: `newId()` era
  `v<microsegundos><contador>` — colisionable si dos teléfonos crean
  compras/ítems en el mismo microsegundo y fusionan la Sala Viva sin
  internet. Ahora `Uuid().v4()` (paquete promovido de transitiva a directa).
- **syncfusion_flutter_charts RETIRADO** — el análisis decía «la única
  instancia»; la realidad eran **6 gráficos en 3 archivos** (brecha, canasta,
  devaluación BCV, producto, gasto por mes, tasas superpuestas) más un
  donut. Todos viven ahora en CustomPainter propio: `VeTimelineChart`
  (multi-serie con escala por serie = eje secundario, área degradada,
  punteados, leyenda, crosshair + chip/TipBox y `onScrub` que sigue
  sincronizando el panel de día de la brecha), `VeBars` y `VeDonut` que ya
  existían en el kit Ve. APKs/AAB sensiblemente más livianos y cero
  condiciones de licencia comercial.
- **package:csv adoptado (punto débil del análisis: el toCSV a mano ya
  escapaba bien)**: se adopta igual por robustez — RFC 4180 estricto con
  CRLF canónico; `parseCSV` ya toleraba CRLF y los tests ganan un
  round-trip con comillas+comas+saltos embebidos. Versión 6.x: la última
  que acepta el Dart 3.9 del CI (7/8 exigen 3.10.1).
- **flutter_secure_storage: DESCARTADO con motivo** — exige minSdk 24 y el
  repo cierra minSdk 21 (§4.13: «se sube solo si un plugin oficial lo
  exige»; este no es un caso). El hardening REAL va por donde le duele
  a la fuga: `allowBackup=false` + `dataExtractionRules` vacías — el
  estado jamás viaja en copias cloud ni migraciones de dispositivo; la copia de seguridad es la de la app
  (JSON local, retención 4). El storage app-privado ya va cifrado en reposo
  (FBE, Android 7+).
- **Observabilidad 100 % LOCAL con talker_flutter**: `VeLog` (buffer de 500
  en memoria del teléfono, sin nube) captura errores de proveedores del
  tablero, cortes SSE, fallos del worker en fondo y fallos de conexión de
  la Sala. Visor nuevo en Ajustes → Diagnóstico → «Registros de la app».
  El buffer del worker es del isolate de fondo (se documenta en el hook).
- **Paquetes**: hive_ce 2.20.0 (vigente, `IsolatedHive` incluido y ahora en
  uso), dio 5.11.x, image_picker 1.2.x, flutter_image_compress 2.5.x al
  día en el lock; uuid/csv/talker entran con su mayor vigente compatible.

## 1.12.0-beta+32 · v20.2 — GUI correcta, rondas 2 y 3 (TASK-35 · p5–p13)

- **Auditoría de rutas a 390 px con notch y fuentes REALES**: nuevo test
  que recorre las 10 rutas (`/`·`/conversor`·`/lista`·`/productos`·
  `/analisis`·`/historial`·`/ajustes`·`/tickets`·`/sala`·`/legal`) a
  390×844 con insets físicos de notch (59/34 lógicos) cargando las fuentes
  Inter/SpaceGrotesk/JetBrainsMono del asset (Ahem mide cada glifo al
  ancho del fontSize y fabricaba overflows falsos). Cualquier RenderFlex
  overflow o excepción de layout revienta en CI, no en el teléfono del
  dueño. La bienvenida se audita además a 320 px (el más estrecho).
- **Conversor (fix auditado)**: los chips de ajuste rápido (±10 % · ±100)
  ahora LLENAN su celda (`VeChip.expands`) — alineados siempre, sin Wrap
  que los reordene; a 390 con fuente real la etiqueta «−10 %» no desborda.
- **Historial (fix doble, hallado por la auditoría)**: los botones de
  export de la barra pegadiza vuelven al prototipo (Btn lg flex-1 SOLO
  texto, sin icono: a 390 icono+«CSV movimientos» desbordaba 1.4 px el
  Row interno del botón) y se elimina el `Expanded` manual que duplicaba
  el que `VeStickyBar` ya pone a cada hijo (ParentData conflictivo
  detectado por la auditoría al navegar a `/historial`).
- **Sala · lobby (fix visual)**: las descripciones de los 4 modos de
  conexión (Cerca · WiFi o Hotspot · Bluetooth · Servidor) ahora muestran
  el texto completo en 3 líneas — antes quedaban «Sin configurar…»
  «el Hot…» «los tel…» «la URL d…» truncados con elipsis a 390 px.
- **Sala · hoja Unirse (fix de paso vivo)**: «Paso X de 3» vuelve a la
  cuenta del prototipo (1 + nombre + código): arranca en 1 (o 2 si el
  nombre viene pre-llenado) en vez de clavar 3, y avanza al dializar las
  ruedas del código — la barra de progreso acompaña (33 % → 66 % → 100 %).
- **Verificación visual con compilación web + VLM (nueva etapa del
  flujo)**: `flutter build web --release` servido en puerto interno +
  recorrido por las 10 pantallas y los sheets (centro de avisos, hoja de
  Unirse) con análisis VLM: techo de sheets respetado (avisos ~40 % de la
  pantalla con fondo visible arriba; Unirse con borde superior a ~35-40 %),
  toggle claro/oscuro funcional y persistido en ambos sentidos, Sala viva
  completa (lobby + unirse por código de 6 ruedas + PIN de emojis).

### Ronda 3 (p6–p12 · orden del dueño)

- **Auditoría de rutas a 390 con fuentes reales (p5)**: test que recorre las
  10 rutas con notch 118/68 — encontró y mató el doble Expanded del
  Historial; export UNIFICADO en un botón «Exportar» (hoja canónica con los
  dos CSV). Bienvenida sin overflow a 320.
- **Selector de moneda profesional (p6)**: CurrencySelect abre
  showCurrencySheet — filas estilo RateTile (bandera · nombre · fuentes
  reales · símbolo mono · check) — UNA sola forma de elegir moneda en toda
  la app. RateTile gana sello de categoría (OFICIAL/MERCADO/PROMEDIO/
  MANUAL). Referencia de fuentes con colores. ELIMINADOS Ruta del cálculo y
  Matriz 6×6. Recientes: dedupe por día calendario.
- **Presupuesto entendible (p7)**: _PanelPresupuesto unifica presupuesto +
  «Cálculos en» (moneda + fuente compactas); hoja con leyenda de la barra y
  «Quitar tope». Tachado mejorado: nombre tachado legible, total sin tachar.
- **Menús contextuales a media pantalla (p8)**: showVeHalfSheet — nace al
  50 % con asa y snap [0.5 → 0.95]; ficha/alta de producto y editor de
  ítem dejan ver la app debajo.
- **Headers limpios + siempre volver (p9)**: subtítulo DEBAJO del título;
  botón Volver en Historial y PushScreen robusto (canPop→pop, sino Inicio);
  lupa flotante móvil retirada.
- **Análisis trabajado (p10)**: KPIs con insignia de color + iconos de
  trazo; lookup de fecha como píldora tocable; fuera la prosa decorativa.
  Fix de harness: el «ribbon diagonal» de los goldens era el banner DEBUG
  de Flutter — desactivado en los harnesses.
- **Sala con INTENCIÓN + escáner contextual (p11)**: segmentado
  «Unirme | Crear» con flujos exclusivos; FIX REAL: «Escanear QR» abría el
  lector de EAN y un QR de sala jamás se leía — modo QR con copy propio.
- **Widgets del launcher remodelados (p12)**: acento por categoría (BCV
  verde · Paralelo rojo · Brecha ámbar), día/noche real, cifra 34 sp y
  previews regenerados.



## 1.11.0-beta+31 · v20.1 — GUI del prototipo en TODAS las pantallas (TASK-34 · p9–p11)

- **Historial (p9) reescrito al prototipo**: título con contador vivo
  («N compras · $X»), chips de periodo con etiquetas legibles (7 días · 30
  días · 90 días · 1 año), búsqueda compacta Ve, y las compras como FILAS
  en grupo dividido (tienda + fecha/ítems + badge de ticket/fuente, total
  tabular a la derecha) que abren la ficha en sheet Ve: cifra 32 px,
  equivalente Bs + tasa, renglones con su tienda (multitienda v17.2),
  miniatura del ticket → visor zoom 8×, editar/anular desde el pie.
  Paginador «Anterior · Página X de Y · Siguiente» y export unificado
  (compras CSV · movimientos CSV) en la barra pegadiza con blur.
- **Análisis (p9) con cromática Ve**: PanelCard/KpiTile migran a la
  superficie shad (borde `--line`, radio 10, sin elevación Material) y la
  cabecera pasa a eyebrow del prototipo; barra de anclas segmentada Ve
  (muted + píldora activa card/borde/sombra, iconos intactos), chips de
  rango Ve, títulos de sección VeEyebrow. Los 6 anclas, el trackball y la
  matemática testeada quedan intactos.
- **Tickets (p10) del prototipo con MEJORA real**: grilla de tarjetas con
  foto 4:3 (2 columnas en móvil, 3 en ≥560 px), tienda semibold +
  fecha·total tabular, borde que sube a line-strong al hover; tile punteado
  «Agregar» que **adjunta la foto a una compra existente** del historial
  (picker de compras sin ticket → cámara → compresión 1024 px) — algo que
  el prototipo no hace desde la galería. Contador de fotos + peso MB,
  VeEmpty punteado y visor a pantalla completa con zoom 8× intacto.
- **Ajustes (p10) al lenguaje Ve**: `_VeSettingsCard` (superficie shad +
  Material transparente para los ListTiles) sustituye las 11 Card de las
  8 secciones; SectionTitle → VeEyebrow; PageHeader → VeTitle; ChipTag
  re-estilizado como píldora Ve 28 px (tinta invertida al seleccionar) —
  heredado por todas las pantallas que lo usan.
- **Bienvenida (p11)**: logo del prototipo (rombo de tinta + círculo del
  fondo, CustomPaint) sobre el wordmark, botones Ve (ghost/primario) en la
  barra de control, bullets y tarjeta de datos con cromática VeCard, chips
  de país en píldora con tinta invertida. Los 4 slides del dueño (v19.0)
  intactos.
- **Paleta ⌘K (p11)**: cromática exacta del prototipo — superficie card,
  borde line-strong, radio 14; filas con caja muted e icono que despierta
  al marcarse (hover `--accent`), eyebrow de grupo Inter 10.5 w600, pie
  «↑↓ navegar · ↵ ejecutar · N resultados». Teclado, grupos y matching sin
  acentos intactos (tests adaptados al nuevo pie).
- **Sala (p11)**: VePanelCard público en ui.dart (card shad + Material
  transparente) sustituye las 12 Card de lobby/sala viva/PIN; PageHeader →
  VeTitle en lobby y sala viva. La mecánica P2P completa (escáner, modos,
  PIN de emojis, deep links) intacta.
- **Tests**: hosts de room/push/palette ganan el ShadApp.custom de
  producción (los widgets Ve lo exigen); suite 213 → **230/230 verdes**,
  analyze 0.

## 1.10.0-beta+30 · v20.0 — GUI del prototipo web sobre shadcn/ui (TASK-34)

- **Tokens del prototipo (p2)**: theme.dart ahora reproduce EXACTOS los
  CSS custom properties del prototipo de referencia (zinc claro/oscuro,
  `--line-strong`, `--faint`, fondos tenues `--pos-bg`/`--neg-bg`/
  `--warn-bg`/`--info-bg` en `VeInk`). El primario pasa a tinta invertida
  (bg fg / texto bg) — cero acentos de marca, como Linear/Vercel.
- **Kit «Ve» (p3)**: `lib/widgets/ve/` — capa shadcn_ui REAL: VeBtn
  (28/36/44 px exactos), VeBadge por tono con fondo tenue, VeChip pill,
  VeToggle 32×18, VeCheckbox con pop, VeSegmented de pastilla deslizante
  (mejora sobre el original), VeStepper, VeInput/VeSelect con foco tinta,
  VeCard/VeGroup/VeRow, VeEyebrow/VeTitle, showVeSheet (bottom móvil /
  modal centrado escritorio), VeStickyBar con blur, VeEmpty punteado,
  VeAmbient (radiales + rejilla de puntos), VeFlash, y los 5 gráficos del
  prototipo (sparkline, área interactiva con crosshair, barras, donut,
  heatmap) en CustomPainter ligero. Fuente JetBrains Mono para kbd/códigos.
  Los bordes shadcn flush (sin reserva de foco) garantizan medidas al píxel.
- **Shell del prototipo (p4)**: escritorio (≥700 px) sidebar de 224 px con
  marca (rombo+tinta), búsqueda ⌘K, navegación de 5 pestañas + sección
  «Libro» (Historial · Tickets · Ajustes) y pie con las tasas del país en
  vivo; móvil barra inferior plana (tinta/faint) + FAB de búsqueda.
- **FIX CRÍTICO de raíz (p4)**: `ShadApp.router` con el tipo default
  construía un `WidgetsApp` SIN ScaffoldMessenger — todos los toasts de
  la app morirían en runtime. La raíz pasa a `ShadApp.custom` +
  `MaterialApp.router`: ShadTheme arriba, Material de verdad abajo.
- **Pantallas (p5–p8)**: Inicio (cabecera del prototipo con campana/
  búsqueda/ajustes, chispa de serie junto a la tasa, badges por tono),
  Conversor (cifra display, chips rápidos, referencias en VeGroup/VeRow),
  Lista (barra de presupuesto con progreso tinta/warn/neg, filas con
  checkbox+stepper, alta rápida con chips, VeStickyBar de checkout) y
  Productos (buscador+chips de categoría, filas con sparkline y badge de
  estado, ficha en showVeSheet wide) — evolucionadas sobre el estado real,
  sin perder una sola función (sala viva, escáner, plantillas, checkout,
  exportación). 213→233 tests verdes; ajustes de viewport móvil en los
  harness de lista.
- **Pendiente del turno**: restilo fino de Análisis/Historial/Tickets/
  Ajustes/Bienvenida al mismo lenguaje (p9–p11) y visual gate final
  completo; la eliminación de `safe/docs-news` y el push quedan listos
  para ejecutarse con las credenciales del dueño.
## 1.9.11-beta+29 · v19.11 — GUI nueva «Linear/Vercel» sobre shadcn/ui (TASK-33)

- **Fundaciones shadcn**: `shadcn_ui` 0.57.1 con `ShadApp.router` en la
  raíz y `ShadThemeVe` (lib/core/shad_theme.dart) — los tokens de color
  son EXACTAMENTE los de siempre (papel-tinta claro · grafito oscuro):
  ni un tono nuevo (orden del dueño: «solo del actual se mantendrán los
  colores»). Test guardián del mapeo 1:1 en ambos temas.
- **Shell Linear**: cabecera 52 px con acciones fantasma + iconografía
  Lucide; barra inferior pill al 10 % sin borde; toggle de tema con giro.
- **Command palette ⌘K**: la búsqueda global se vuelve overlay estilo
  Linear (grupos módulos/productos/compras/avisos, teclado ↑↓·↵·esc,
  hints al pie); atajo Ctrl/⌘+K en escritorio.
- **Sistema de componentes Linear**: Stamp/ChipTag/RateBadge planos
  (radio 8, sin píldoras), SectionTitle en tinta mute, LedgerRow con
  etiqueta regular, icon-buttons cuadrados r8, radios coherentes
  (tarjetas 10 · controles 8). API pública intacta: 199→213 tests sin
  tocar una sola aserción previa.
- **Héroe KPI**: rótulo caps mute + cifra protagonista; badges de
  brecha/vs-ayer rectangulares; tool tiles con cajita muted.
- **Ajustes**: selector de temas con PREVIEWS (Claro · Grafito ·
  Sistema) pintadas con los tokens reales — patrón Vercel/Linear.
- Puente `materialThemeBridge`: las pantallas Material mantienen VeInk,
  transiciones firma y Material You durante la transición.

- **Notificaciones en 2º plano (fix del síntoma «solo avisan al abrir la
  app»)**: el worker horario retornaba con los `show()` en vuelo sin
  esperar y el engine de 2º plano moría antes de notificar. Ahora
  `AlertEngine` acumula los avisos pendientes y `drain()` los espera;
  `AppStore.flushNotifications()` fuerza el disco del anillo del centro;
  el dispatcher de workmanager espera ambos antes de retornar. Con test
  de regresión (`test/alerts_drain_test.dart`).
- **Auditoría visual 1:1 (web local privada del agente + capturas)**:
  onboarding con contenido centrado verticalmente (slides 2–4, patrón
  del slide 1) — antes quedaban colgados arriba con ~45 % vacío; el
  héroe de Inicio ya no repite la categoría («OFICIAL» + «Oficial ·
  Banco Central de Venezuela» pasa a «OFICIAL» + «Banco Central de
  Venezuela»); el placeholder del presupuesto de Lista ya no se trunca
  («Presupuesto del mes»); la tarjeta «App Widgets» se oculta en web
  (honestidad de plataforma: los widgets son de Android).
- Skills del contrato usadas de punta a punta: rtk (shell), ui-nice-skill
  (checklist 12 puntos + anti-slop), vlm (capturas y verificación),
  humanizer (micro-copy), flutter-accessibility (semántica del héroe ya
  presente; targets verificados), flutter-testing (regresión), taste
  (filtro anti-genérico: cero señales de slop).

## 1.9.9-beta+27 · v19.9 — Contrato del agente reconstruido: docs/agent/, bitácora de 3 niveles y skills unificadas

- **AGENT.md v3 (máquina de estados 9.5 pasos)**: el ciclo de trabajo pasa
  a ser una máquina de estados con routes explícitos (ANALYZE → PLAN →
  IMPLEMENT → VISUAL GATE → AUDIT → CONTROL → RETRY → PERSIST → CI →
  CLOSE/BLOCKED), con la sub-rama de recuperación que NO vuelve ciego al
  paso 1 y la regla de oro de saltar 2_PLAN en reintentos. Ronda conjunta
  de dos sesiones (08360df/303b4f2 + esta), con `MVP-CRUD.md` en la raíz
  como única fuente de verdad funcional.
- **Bitácora de tres niveles**: `progress.md` (82 KB de prosa por turno)
  es reemplazado por `PROGRESS.md` (hot · ≤10 líneas) + `progress_warm.md`
  (últimos ~10 turnos cerrados) + `progress_archive.md` (historial
  comprimido por hito). Una línea por pieza, solo hechos, append-only y
  rotación hot→warm→cold. El detalle histórico queda en la historia git.
- **`docs/agent/` recreado**: CODE_STYLE, TESTING, GIT_WORKFLOW,
  ARCHITECTURE y DEPENDENCIAS (movida a su alcance), cortos y operativos
  en es-VE, basados en la realidad verificable del árbol. Prohibido
  inventar contenido: lo que falta queda como `TODO:`.
- **Skills unificadas en `.agents/skills/`** (59): las 37 oficiales de
  Flutter + 2 de Dart + la familia taste (13) + caveman + humanizer
  (dedup: la copia de agent-skills/ fuera) se consolidan en la ubicación
  canónica que exige el contrato. Del contrato: `ui-nice-skill` (propia
  del repo, orden del dueño), `flutter-frontend-design` (syeduzaif),
  `mobile-design` (sickn33/agentic-awesome-skills), `humanizer` y
  `taste-skill`; nuevas de documentación: `rtk` (Rust Token Killer) y
  `vlm` (procedimiento real del visual gate). CI re-apunta a
  `scripts/quality_gate.sh`.
- **`scripts/quality_gate.sh`**: el gate local del contrato ahora existe —
  pub get + analyze (0) + suite completa + auditoría de prohibiciones en
  `lib/` (AppStateScope/patrones web/mocks), espejo del CI que lo ejecuta.
- **Versionado**: 1.9.9-beta+27 · visible 19.9. Sin cambios funcionales
  en `lib/` (solo la constante de versión visible).


## 1.9.8-beta+26 · v19.8 — Análisis rediseñado (web-first), Sala con PIN de emojis y QR con deep link

- **Análisis, rediseñado como un dashboard web** (orden del dueño):
  barra de anclas segmentada (píldora activa, una sola unidad visual
  con los chips de rango), fila de KPIs al tope de cada ancla (brecha
  + tasas del día · inflación personal/productos/devaluación · costo
  de canasta · total gastado), tarjetas-panel con cabecera consistente
  (título + acción a la derecha), panel del día en 3 columnas (BCV ·
  Paralelo · Brecha) en vez de la pila densa de renglones, heatmap que
  solo dibuja meses con datos y estados vacíos compactos (pista con
  ícono, no tarjeta gigante de error). Misma matemática, otra piel.
- **Sala: el flujo de entrada en su sitio** (orden del dueño): el
  lobby arranca por la CONFIGURACIÓN de conexión (cómo se conectan) y
  la tarjeta de nombre desaparece de arriba — el nombre lo pregunta
  la hoja de Unirme en el momento de entrar: modo · nombre · PIN.
  Crear integra el nombre del anfitrión, el switch de PIN y la
  tarjeta del PIN generado.
- **PIN de emojis (tipo 2FA de Google)** (orden del dueño): la sala
  puede exigir 4 emojis para unirse — el candado de la puerta contra
  quien avista la sala cerca. El anfitrión los genera/regenera, se
  muestran en la Sala Viva y viajan cifrados... no: viajan en el hello
  y los valida el anfitrión (bad_pin humano). El invitado los marca
  en un teclado de 12 fichas.
- **QR con deep link real** (orden del dueño): el QR de la sala ahora
  es `valorave://sala?c=CODE&m=MODE&p=0|1` — escaneado con la cámara
  del teléfono (cualquier escáner externo) Android ofrece abrir
  ValoraVE (BROWSABLE + DEFAULT en el manifest, canal
  valorave/deeplink con initial + onNewIntent) y la app cae directo
  a la hoja de unirse prellenada: elige conexión, nombre, PIN si
  procede y conecta si la sala sigue activa. El escáner interno
  además entra por QR y respeta el formato histórico.
- **Exportación UNIFICADA** (orden del dueño): un solo componente
  (showExportSheet + ExportSpec) para TODA la app — formato (CSV ·
  PNG · PDF · texto/JSON) y luego modo (compartir o guardar).
  Migrados: conversor, constancias, historial, productos, respaldo y
  las dos exportaciones de Análisis. share_menu.dart eliminado.
- **Tests**: 196 (185 + 11 nuevos: PIN genera/valida, anfitrión
  rechaza bad_pin y acepta el correcto, el PIN viaja en el hello,
  salas sin PIN intactas, parser del deep link con formato actual,
  histórico, código manual, host ajeno y código corto → null,
  pendingInvite se consume una vez).


## 1.9.7-beta+25 · v19.7 — versión web (modo cliente) de ValoraVE

- **Web, de verdad**: `flutter build web` compila la app completa
  sin cambios en `lib/` — la degradación honesta del arranque (que
  jamás depende de un plugin) hace el resto: Hive persiste en
  IndexedDB, las tasas llegan por CORS de las APIs públicas y
  quick_actions / home_widget / workmanager / notificaciones se
  degradan en silencio, igual que en el host de pruebas.
- **PWA con marca propia**: la carpeta `web/` deja de ser el
  scaffold por defecto — título y descripción es-VE reales, manifest
  con nombre «ValoraVE», colores de marca (#22354E · #F7F8F9 ·
  #121417), theme-color claro/oscuro según el sistema e íconos
  generados desde la marca (normal + maskable, 192/512, favicon).
- **Splash de arranque tipográfico**: mientras baja main.dart.js se
  ve la marca (Valora + VE, tipografía pura como la app, claro u
  oscuro según esquema del sistema); el motor emite
  «flutter-first-frame» y el splash se retira con un fundido.
- **Verificado en navegador** (headless 430×932): onboarding de 4
  slides + selección de país → tablero con tasas vivas (BCV ·
  paralelo · TRM · Brasil · Banxico), barra de 5 tabs y tutorial de
  13 pasos — 0 errores de página.
- **Limpieza de ramas** (orden del dueño): el remoto queda en solo
  `main` y `fix/v1.1.0-dp4-paridad`.

## 1.9.6-beta+24 · v19.6 — widgets in-app retirados, galería de App Widgets del launcher y fix del conversor

- **Widgets de Inicio retirados (orden del dueño)**: el sistema
  configurable de v19.4 — catálogo para añadir/quitar secciones y
  elegir su tamaño, persistido en prefs — sale de la app. El Inicio
  vuelve a sus secciones fijas de siempre: cotización, divisas,
  resumen del mes, alertas, tiendas, registros y herramientas.
- **App Widgets, bien escritos**: la tarjeta «+» del pie del Inicio
  ahora abre la galería de los App Widgets de verdad — los de la
  pantalla de inicio de Android (Tasa BCV · Paralelo · Brecha). Cada
  entrada trae su preview fiel (mismo diseño, colores y jerarquía del
  widget nativo, con las tasas vivas del tablero) y un botón
  «Añadir» que pide el pin al launcher (requestPinAppWidget, Android
  8+, canal propio `valorave/widgets`); si el launcher no lo soporta,
  sale la guía manual de 3 pasos. Diseño adaptado de las tarjetas de
  referencia del dueño.
- **Conversor arreglado (bug del dueño)**: al teclear más de 3 ceros
  la cifra se caía — «4.000» + un dígito quedaba «4,0000» y 40 mil se
  volvía 4. Regla nueva (MoneyField y parseLocaleNum, misma
  semántica): sin coma en el texto, un punto con 3 o más dígitos
  detrás es separador de miles; con 1-2 es decimal; y si lo de
  adelante es puro cero («0.0001») es decimal — las tasas chiquitas
  no se convierten en 1.
- **Tests**: 4 de la galería de App Widgets (secciones fijas,
  previews fieles, pin al canal nativo, guía manual) y 2 de
  regresión del conversor.

## 1.9.5-beta+23 · v19.5 — limpieza dp4, 3 fixes recuperados y widgets de escritorio con preview + resize

- **Limpieza de la desviación**: rama `dp4` y sus 13 runs de Actions
  eliminados; nada de ese trabajo llegó a esta rama sin revalidarse.
- **CSV de movimientos**: cada renglón exporta la tienda del ÍTEM (la
  ficha en pantalla agrupa por tienda desde v17.2, la planilla seguía
  poniendo la de la compra). El ítem manda; si no trae, cae a la compra.
- **Tablero offline**: una región caída ya no borra sus tasas — la ronda
  anterior sobrevive con su hora original y la caída queda reportada en
  `degraded`. Las fuentes frescas pisan a las viejas; nada se inventa.
- **Durabilidad Hive**: flush a disco tras cada persist del snapshot —
  un corte de luz ya no pierde la última compra. Fire-and-forget con
  captura: si el disco falla, el dato sigue en memoria y se reintenta.
- **Widgets de escritorio (encargo Fase 3)**: la familia Tasa BCV ·
  Paralelo · Brecha ahora se VE en el selector antes de añadir (layout
  real en Android 12+, PNG en 5-11, con descripción) y se redimensiona
  de ~2×1 a 4×2 con contenido que se recompone: solo cifra en compacto,
  diseño completo en normal y cifras grandes en 4×2. Tocar abre la app.

## 1.9.4-beta+22 · v19.4 — 5 encargos del dueño: tarjetas TIPs, compartir, widgets de Inicio, buscar sala y FlutLab
## 1.9.10-beta+28 · v19.10 — Auditoría visual premium + notificaciones que sí llegan en 2º plano
## 1.14.1-beta+44 · v22.1 — la app compila también para WEB

- **`flutter build web` en verde**: los 4 servicios que usaban `dart:io`
  sin condicional (`lan_hub`, `workmanager_service`, `ticket_files`, el
  `downloadBytes` de `sharing`) pasaron al patrón facade del repo (`_vm`
  + `_stub` con `if (dart.library.io)`). Firmas públicas idénticas,
  comportamiento web honesto: la sala WiFi-local devuelve vacío (la web
  usa el servidor socket.io), las fotos de ticket siguen como data URL,
  el respaldo en disco no existe y `downloadBytes` da null. En
  Android/iOS nativo NO cambia nada (mismo `_vm` de siempre).
- **Preview del repo = la app misma**: `scripts/web_preview_daemon.js` +
  `web_preview_server.js` sirven `build/web` en :3000 con fallback SPA
  (rutas de go_router). Verificado en vivo con el navegador a 390×844:
  onboarding + Inicio con tasas reales (BCV 886,23 · Paralelo 998,08) y
  0 errores de página.
- Las optimizaciones de rendimiento, el `minSdk` estable (24 · Android
  7.0) y la GUI clara de v22.0 quedan intactos.

## 1.14.0-beta+43 · v22.0 — «la app directa»: repo solo-app, rendimiento en dispositivos humildes, minSdk al mínimo estable y GUI más clara

Orden del dueño: «pasemos a desarrollar la app directamente». El repo deja
de arrastrar la burocracia de proceso y el código se afinó para los
teléfonos viejos (carga aceptable, pero se sentía entrecortada).

- **Repo limpio (solo la app):** fuera `.agents/` (201 archivos de skills
  del agente), `AGENT.md`, `MVP-CRUD.md`, `PROGRESS.md`,
  `PROGRESS_WARM.md`, `PROGRESS_COLD.md`, `CHANGELOG_WARM.md`,
  `CHANGELOG_COLD.md` y `skills-lock.json`. Queda el proyecto real:
  `lib/`, `test/`, `android/`, `ios/`, `web/`, `tools/`, `server/` +
  README/CHANGELOG/LICENSE. Los archivos siguen en el historial git si
  alguna vez hiciera falta consultarlos. README actualizado (sin enlaces
  muertos, contador de tests al día).
- **Rendimiento (la causa real del «se siente entrecortada»):**
  - `AppData.copyWith` (nuevo) + las 36 mutaciones del store convertidas:
    antes CADA mutación (cada tap del carrito, cada tecla del conversor,
    cada aviso) hacía `AppData.fromJson(_data.toJson())` — serializar y
    re-parsear TODO el estado (todos los productos con sus registros,
    compras, notificaciones). Ahora la mutación es O(campo): solo cambia
    la lista tocada y el resto viaja por referencia.
  - `RateTicker` (cinta de tasas del Inicio): RepaintBoundary alrededor de
    la fila móvil — cada frame solo recoloca la capa ya rasterizada en vez
    de re-pintar el shell entero a 60 fps; y la animación SE DETIENE
    cuando no hay filas o el modo es off (antes seguía marcando 60 fps
    en vacío).
  - `VeStickyBar` SIN BackdropFilter: el blur (sigma 12) re-blurreaba el
    contenido completo por debajo en cada frame de scroll de
    Lista/Productos/Historial — el jank nº1 de scroll en teléfonos
    humildes. Fondo casi opaco (alpha 0.96/0.97): misma lectura, costo de
    un rectángulo plano.
  - `MainShell` solo se reconstruye con lo que pinta: `context.select`
    para país / modo offline / fuente activa del país / contador del
    carrito (antes `watch<AppStore>()` reconstruía Scaffold + fondo
    ambiental + tabs en cada mutación del store).
- **minSdk al mínimo estable (orden del dueño):** `minSdk =
  flutter.minSdkVersion` directo del framework — **24 · Android 7.0** en
  Flutter 3.47.4, sin hardcodes. Nota honesta: API 9 (Android 2.3, 2010)
  es técnicamente imposible para Flutter (el motor no arranca por debajo
  de su mínimo declarado); 24 es el mínimo real y estable soportado.
- **GUI más clara:**
  - Cada sección de Inicio explica en una línea qué ofrece (hint bajo el
    eyebrow): Cotización principal, Divisas del foco, Alertas, Resumen del
    mes, Tus tiendas, Registros recientes, Herramientas.
  - La pestaña móvil se unifica con el resto: «Conversor» (decía
    «Divisas» mientras la ruta, el sidebar y la paleta decían Conversor).
- **Gates:** analyze 0 · suite completa verde · auditoría lib/ limpia ·
  goldens del visual gate regenerados (sticky bar y hints cambian
  píxeles) · Impeccable 4.5.2 sobre los archivos tocados.


## 1.14.0-beta+39 · v21.5 — Micro-espaciados del checkout de Lista

La candidata pendiente de la auditoría GUI que solo se veía con ítems en
el carrito — el teclado del CLI no escribe en campos Flutter, así que esta
ronda se hizo por revisión de código y se blindó con tests de widgets que
seedean el carrito y miden la geometría real del sheet a 390×844.

- **El recibo por tienda respira**: las filas del desglose (`LedgerRow`)
  no traen padding propio y en el checkout iban desnudas — se pegaban
  entre sí y contra el filete doble. Ahora llevan `vertical: 3`, el mismo
  ritmo de recibo que ya usaba Inicio; el hueco entre filas pasó de 0 px
  a 6 px y el test lo mide geométricamente.
- **«Total USD» se sienta en la línea base de la cifra**: junto al número
  de 34 px el rótulo flotaba centrado verticalmente, como un dato suelto.
  La fila ahora alinea por `CrossAxisAlignment.baseline` — la cifra manda
  y el complemento acompaña, igual que en el resto del lenguaje Ve.
- **Multitienda: el primer campo de tienda abre con 10 px**: antes el
  lead-in tras el subtotal medía 6 px, igual que el ritmo entre campos,
  y la zona de edición quedaba pegada al cierre del recibo. El primer
  campo del grupo abre con 10 px y los siguientes conservan el 6 px. El
  closure usa el elemento de la vuelta (`identical`), no un índice, para
  que «Tienda de <ítem>» edite siempre su propio ítem.

analyze 0 · 243/243 tests (3 nuevos del checkout) · gate VERDE · web 3000
verificada en vivo (390×844).

## 1.14.0-beta+38 · v21.4 — Arranque sin controles muertos

Última pasada de producción: una pantalla más verificada de primera mano y
la integración DolarVZLA re-auditada contra su spec oficial en vivo.

- **El slide 1 de la bienvenida ya no muestra «Atrás»**: el botón estaba
  deshabilitado en la primera página, pero seguir visible como un control
  que no lleva a ninguna parte confunde al usuario nuevo. Ahora se
  desvanece (`AnimatedOpacity` + `IgnorePointer` + `ExcludeSemantics`) y
  el hueco se reserva igual — los puntos de progreso no saltan de
  posición al navegar. En los slides 2-4 vuelve con fade, como siempre.
  Aserción del contrato en `widgets_test.dart`.
- **Integración DolarVZLA reverificada contra el openapi.json en vivo**:
  el CDN `rates.dolarvzla.com/bcv/current.json` responde 200 y su payload
  (`current.usd`/`current.eur`/`current.date`) casa 1:1 con
  `parseDolarVzlaBcv`. El monitor USDT/paralelo de
  `api.dolarvzla.com/public/usdt/exchange-rate` exige la cabecera
  `x-dolarvzla-key` (401 sin ella, claves temporales por usuario) — queda
  descartado como respaldo anónimo con motivo documentado; el paralelo
  sigue en DolarAPI, su única fuente pública estable. Salud del tablero:
  8/9 endpoints vivos (AwesomeAPI respondió 429 de cuota; es solo
  respaldo y la app lo degrada honestamente).

analyze 0 · 240/240 tests · gate VERDE · web 3000 verificada en vivo
(390×844: onboarding 4 slides, tutorial, Inicio, Conversor, Lista,
Análisis con scrub, Historial y Tickets por deep link, Sala, Ajustes).

## 1.14.0-beta+37 · v21.3 — Respaldo BCV vivo (auditoría externa)

Un test tipo pentest sobre el build web encontró la fuente de respaldo
venezolana muerta y este release la reemplaza. También desmiente un
hallazgo con evidencia de navegador.

- **El respaldo de tasas VE ya no apunta a un dominio muerto**: la app
  consultaba `pydolarve.org` cuando DolarAPI falla, pero ese dominio
  caducó el 07/2025 y hoy resuelve NXDOMAIN — el respaldo llevaba meses
  siendo decorativo. Ahora el oficial BCV (USD y EUR) viene de
  `rates.dolarvzla.com/bcv/current.json`: JSON estático en CDN, sin
  auth, CORS abierto, verificado en vivo el 05/10/2026 con el mismo
  valor que muestra la app (871,37). Se consulta solo si el oficial no
  llegó (no publica paralelo); si el bloque de euros de DolarAPI vive,
  su dato más fresco sobreescribe el del respaldo. Parser puro con
  tests del payload real, y las pantallas Acerca de/README actualizadas
  con la fuente nueva.
- **Hallazgo 2.1 del informe desmentido**: «assets/ 404, fuentes y
  banderas rotas» era un artefacto de leer el AssetManifest sin
  navegador. El build de Flutter 3.47.4 guarda los assets propios un
  nivel más adentro (`assets/assets/…`) y el runtime pide EXACTAMENTE
  esas rutas anidadas — verificadas con el log de red real: banderas y
  fuentes 200. Las rutas de un nivel que el informe probó jamás son
  pedidas por la app.

analyze 0 · 240/240 tests (2 nuevos del parser DolarVZLA) · gate VERDE.

## 1.14.0-beta+36 · v21.2 — Tacto y movimiento (una ronda de craft)

La app ya se ve bien; esta ronda la hace sentir bien. Tres cambios de
sistema, todos invisibles hasta que los usas:

- **Transición unificada de pantallas empujadas**: legal, tickets, sala y
  sala en vivo compartían las transiciones por defecto de cada plataforma,
  así que la app se sentía distinta según el sistema. Ahora las cuatro
  entran con el mismo gesto (fade + subida de 10 px, kEaseVe, 220 ms — el
  easing propio de la app). Las pestañas siguen cambiando al instante, sin
  animación de por medio, y el shell no se tocó.
- **Háptica en las confirmaciones** (Android/iOS; en web no hace nada):
  clic de selección al cambiar de pestaña, al copiar una tasa y al mover
  un segmento; toque de luz cuando un ítem queda agregado a la lista. El
  toast avisa a la vista y la vibración avisa a la mano — antes solo uno
  de los dos trabajaba.
- **Los controles mudos hablan**: las flechas subir/bajar del orden de
  foco en Ajustes ahora dicen a qué país se refieren («Subir Bolívar»), y
  el LED de SSE en vivo explica su estado («Conectado en vivo», «Sin
  conexión — sigue el ciclo normal») por tooltip y por semántica de
  accesibilidad. Antes era un punto de color sin nombre.

analyze 0 · 238/238 tests · detector Impeccable limpio · web puerto 3000
verificado en claro y oscuro.


## 1.14.0-beta+34 · v21.0 — GUI superior (pulido de sistema, identidad intacta)

Ronda de pulido Impeccable sobre la interfaz ya validada: nada de
rediseño — la identidad zinc Linear/Vercel, los 19 arreglos del dueño y
la minimalidad de En vivo quedan intactos. Seis mejoras, cada una en el
nivel correcto del sistema:

- **VeEmpty 2.0 (un solo lenguaje de vacíos)**: el estado vacío del kit
  ahora trae medallón de icono (Lucide, 44 px con fondo muted y borde
  `--line`), título 14/700 y pista 12.5 con aire de línea. Antes era una
  caja punteada con dos renglones tímidos que leía como «algo se rompió»;
  ahora lee como «aquí aún no hay nada, y así se llena». Migrados los 7
  `EmptyState` de Material que sobrevivían (Inicio · Resumen del mes,
  Canasta, Gastos, Fuentes, Inflación personal, Calendario del conversor)
  al componente del kit — cero sistemas tipográficos mezclados y cero
  tarjetas anidadas. Iconos puestos en los 9 vacíos de la app
  (shoppingCart, receiptText, images, scanBarcode, bell, searchX, history,
  flame, shoppingBasket).
- **Cotización principal calmada (jerarquía Linear)**: ANTES toda fila
  llevaba el tinte de su categoría al 7 % y el tablero era un mosaico de
  pastillas verdes/rojas/ámbar/violeta compitiendo. AHORA la superficie es
  neutra y SOLO la fuente activa se tinta (12 % + borde 1.4 + check): la
  selección se encuentra de un vistazo. El color semántico no se pierde:
  los sellos OFICIAL/MERCADO/PROMEDIO/MANUAL (v20, orden del dueño) y el
  símbolo de la divisa lo conservan en todas las filas.
- **Héroe de Inicio: bandera + moneda como UN token**: la banderita
  flotaba entre la cifra y «USD» y el trío leía suelto. Ahora es un chip
  con borde que apoya en la línea base de la cifra — el número respira y
  la unidad se lee de una pieza.
- **KPI «Brecha» sin truncar**: «Brecha BCV ↔ Paralelo» no cabía ni en 2
  líneas en la fila de 3 KPIs del móvil y salía con «…». Queda «Brecha» a
  secas — el par lo escribe el panel que sigue («BCV ↔ PARALELO») y el
  sub sigue diciendo si es alta o normal.
- **Filas de Producto sin redundancia triple**: «Sin precios registrados»
  + «—» + badge «Sin dato» decían lo mismo tres veces. Sin registros, la
  fila queda en nombre + subtítulo + guion; con registros conserva
  sparkline y badge de estado.
- **Galería de Tickets sin eco**: con la galería vacía, «Sin fotos
  todavía» aparecía DOS veces (subtítulo del título y dentro del estado
  vacío). Fuera el eco — el vacío ya explica cómo llenarla.

Verificación: flutter analyze 0 · 238/238 tests · quality_gate VERDE ·
detector Impeccable sin hallazgos · web recompilada y recorrida en el
navegador (390×844) en claro y oscuro: Inicio, Divisas, Lista, Productos,
Análisis, Historial, Tickets.


- **Tarjetas de TIPs y Tutorial sin aire muerto**: la tarjeta ocupaba
  todo el hueco disponible aunque el texto fuera corto — el contenido
  quedaba arriba y los botones pegados al fondo, con un vacío gigante
  en el medio. Ahora mide su contenido: cuelga bajo el foco y se apoya
  sobre él; si el texto no cabe, se scrollea como siempre.
- **«Generar» la tarjeta del conversor arreglado**: el bug tenía dos
  patas — el GlobalKey estaba sobre un KeyedSubtree (el cast a
  RepaintBoundary reventaba y el catch lo tragaba: null SIEMPRE) y los
  Future.delayed ganaban la carrera contra el vsync. Key al boundary,
  endOfFrame×2 y captureWidget endurecido (sube al boundary que envuelve
  en vez de cast ciego).
- **Widgets de Inicio con vista previa y tamaño**: catálogo donde cada
  sección se ve ANTES de añadirla (la MISMA pieza pinta la hoja y el
  Inicio), selector Compacto/Normal/Grande cuyo contenido cambia de
  verdad (divisas 4/todas · resumen con o sin detalle · alertas 3/6/8 ·
  tiendas 2/4/6 · registros 2+2/3+3/5+5), y persistencia que recuerda
  los quitados (un widget retirado vuelve a aparecer tras reiniciar:
  bug cazado por test).
- **Buscar sala dentro de Crear Sala**: campo que filtra las salas
  públicas avistadas por nombre, anfitrión o código — sin tildes ni
  mayúsculas. Escribir ya arranca la escucha; tocar un resultado entra.
- **FlutLab**: ios/ y web/ estándar en la raíz (flutter create --org
  ve.valorave) + docs/FLUTLAB.md con lo verificado. pubspec.lock sigue
  commiteado a propósito (recomendación oficial de Dart para apps).


## 1.9.3-beta+21 · v19.3 — auditoría GUI completa: 37 fixes de pantalla

Ronda de auditoría del GUI en 3 frentes (shell/home/welcome · insights/
products/statement · lista/converter/room/history) con verificación
línea a línea de cada hallazgo. Todos los fixes corrigen defectos que
`flutter analyze` no puede ver: desbordes con datos reales, texto
invisible en oscuro, accesibilidad y fugas de memoria.

- **Desbordes de fila (9)**: cabecera y pie del centro de notificaciones,
  barra de export del Historial, «Probar conexión» de la sala, botones
  del escáner, Compartir/Copiar del conversor, cabeceras por tienda del
  checkout, fila de foto del ticket y leyenda del heatmap — todas a
  Wrap/Flexible (rompían a 360 dp escala 1.0 o textScale ≥1.1).
- **Texto del usuario sin recorte (10)**: precio/tienda de Productos,
  monto de Recientes, título del visor de tickets, fila PRECIO VIGENTE,
  rótulos de la constancia, StatCard «Tienda top» (FittedBox §8),
  búsqueda global con tiles «y N más» por grupo + clamp de página al
  borrar productos («Página 3 de 2» con pantalla vacía).
- **Español real (1 raíz)**: el `showDatePicker` de Análisis renderizaba
  en INGLÉS («SELECT DATE»/CANCEL/OK) — la app fijaba locale es-VE sin
  delegates. Añadido `flutter_localizations` (+ intl 0.20.3, syncfusion
  34.2.8 alineada al Flutter 3.47 del CI) con delegates en ambos
  MaterialApps.
- **Tema oscuro y contraste (4)**: subtítulo del menú de compartir
  invisible en oscuro (black54 → onSurfaceVariant); pie de la constancia
  a 4.5:1 de contraste; tinta de días sin datos legible; rótulos de la
  matriz al piso de 9.5 px del sistema.
- **Accesibilidad textScale (5)**: puntos del onboarding con FittedBox +
  slide 1 con scroll (desbordaba en landscape); tab bar y header con
  minHeight elástico (las etiquetas se recortaban a textScale ≥2.35);
  campo CANTIDAD elástico; monto del ranking sin partirse en 2 líneas.
- **Elemento muerto + copy + formato (3)**: el badge «N ítems» del héroe
  de la Lista JAMÁS se pintaba (LiveBadge con live:false colapsa a
  cero); «Toca el lápiz» ya no aparece en filas sin lápiz; la meta de
  precio se guarda/lee con coma es-VE (antes «3.0» con punto).
- **Higiene (6)**: dispose de los TextEditingController de 4 diálogos
  (leak por apertura); orden de `mounted` en tips (un desmonte ya no
  consume el tip para siempre); rate VES correcto en productos creados
  al guardar compra (unitsPerUSD(usd) devolvía siempre 1).
- **Escáner ROI con estado de error (paridad)**: permiso denegado o
  cámara ocupada ya NO muestra pantalla negra muda — estado con salidas
  (abrir ajustes · escribir a mano), igual que el escáner principal.
- **Skills**: `agent-skills/humanizer/` (blader/humanizer, MIT) añadido
  a las familias del repo; LICENSE propietaria propagada a TODAS las
  ramas (main, test, fix/v1.0.1-*, fix/v1.0.2-*) por orden del dueño.
- **Bump 1.9.3-beta+21 · kAppVersionVisible 19.3**.


## 1.9.2-beta+20 · v19.2 — licencia propietaria + paquete único ZIP

El dueño pasó el repo a PÚBLICO y pidió: licencia de propietario (sin
uso público), y que cada build entregue los 4 APK + el AAB en UN solo
ZIP, con los compiladores estándar de GitHub Actions.

- **LICENSE propietaria** (nueva): copyright 2026 isaac4722, todos los
  derechos reservados. Uso personal del titular y de quien él autorice
  POR ESCRITO; prohibidos copia, distribución, modificación, obras
  derivadas, ingeniería inversa, publicación y uso para entrenar IA.
  La visibilidad pública del repo NO es autorización de uso. Sección
  «Licencia» añadida al README y a la Regla 9 del AGENT.md.
- **Paquete único por build**: el job `paquete` junta los 4 APK + el
  AAB + un LEEME.txt (qué ABI es para qué dispositivo, cómo instalar,
  nota de licencia) + checksums.sha256, y entrega UN artefacto:
  `valorave-v{versión}-build-{fecha}-completo.zip`. Exige los 5
  binarios presentes antes de comprimir — nada a medias.
- **AAB en CADA ronda** (antes solo en tags): el job `aab` compila el
  bundle de Play Store en cada push, con los mismos compiladores
  estándar (ubuntu-latest, Temurin 17, Flutter 3.47.4 fijado).
- **Release (tags) más simple y segura**: ya no compila nada —
  descarga el ZIP del mismo run y adjunta los 6 archivos (4 APK +
  AAB + ZIP), siempre con `fail_on_unmatched_files: true`.
- **Mini-errores de los builds corregidos**: Kotlin 2.2.20 → 2.3.20
  (el propio Flutter avisaba que dejaría de soportarlo), con la
  migración de DSL que 2.3 exige (kotlinOptions → compilerOptions con
  JvmTarget tipado), y `ndkVersion = 28.2.13676358` (la que exige
  integration_test; el default 27.0.12077973 chocaba en cada build).
- **Higiene de artefactos**: los intermedios de la matriz (apk-*) y
  el aab viven 1 día (solo alimentan al `paquete` del mismo run); el
  ZIP y los símbolos de ofuscación viven 30. Con el repo público el
  storage es gratis e ilimitado; el workflow de limpieza queda como
  red de seguridad documentada por si vuelve a privado.
- **Bump 1.9.2-beta+20 · kAppVersionVisible 19.2**.


## 1.9.1-beta+19 · v19.1 — saneamiento del storage de Actions (cierre v19.0)

Incidente del 2026-09-16: los APK de la v19.0 (SHA 2b0ce40) compilaban
en las 4 ABI pero los Upload fallaban con «Artifact storage quota has
been hit» — el repo arrastraba 4,3 GB de artefactos legacy (75, de
rondas v17 con sets de 117-123 MB y retención de 30 días) contra un
quota de 500 MB del repo privado. La Regla 9 de AGENT.md (los 4 APK
siempre disponibles para CUALQUIER dispositivo) quedaba rota sin que
el código tuviera la culpa.

- **Limpieza quirúrgica**: 69 artefactos legacy borrados (4,2 GB).
  Conservados los 4 APK de la v18.0 (enlaces del dueño) y los del run
  v19.0 vigente.
- **Workflow `limpieza-artefactos.yml`** (nuevo): diario 04:23 UTC +
  botón manual; conserva los 3 artefactos más recientes POR NOMBRE
  (≈ las últimas 3 rondas de APK, ~270 MB peor caso) y borra el resto.
  El job de release (tags) descarga artefactos de su propio run —
  siempre los más nuevos — así que jamás se toca. Validado con datos
  reales de la API antes de commitear.
- **Bump 1.9.1-beta+19 · kAppVersionVisible 19.1**: los APK finales de
  esta ronda se distinguen de los 1.9.0-beta+18 de prueba.


## 1.9.0-beta+18 · ronda v19.0 — la gran ronda de UI, tasas y persistencia

21 encargos del dueño en un ciclo: bienvenida en slides, tutorial propio
sin congelones, tips con reglas, selector de tasa visual agrupado,
conversor bidireccional, formato de miles en vivo, UNA consulta por
región, hive_ce y las pantallas reconstruidas.

### Onboarding y guía
- **Bienvenida en PageView de 4 slides** con avanzar/retroceder (botones
  Atrás/Siguiente + puntos tocables + swipe): marca → lo que hace →
  datos tuyos → país con banderas. El país elegido se conserva al navegar.
- **Motor de coach marks propio** (tutorial_coach_mark RETIRADO): el
  agujero del foco se mide del rect REAL del ancla; la tarjeta se
  posiciona con clamping y SUS BOTONES VIVEN FIJOS AL PIE — si el
  contenido no cabe, el texto se scrollea, nunca los botones: el
  tutorial no se puede congelar. Los 13 textos reescritos contra las
  pantallas reales.
- **Tips contextuales con reglas** (misma forma visual que el tutorial,
  sello TIP): el tutorial manda (sin tour visto no hay tips), empiezan
  en la 2ª apertura, a lo sumo uno cada 6 h, cada uno UNA vez. Catálogo:
  manual sin Ajustes, tasa de otro día, campo inverso del conversor,
  cerrar compra, presupuesto en tu moneda, metas de precio y QR de sala.

### Tasas y conversión
- **Selector de TASA visual en toda la app** (aparte del selector de
  Moneda): filas [Bandera][Nombre][Precio + símbolo] con el color de
  categoría establecido; la Lista de Cotización del Inicio se agrupa por
  divisa base — sección USD (BCV · Paralelo · Promedio · Manual · TRM ·
  Mercado · Brasil · Banxico) y sección EUR (aristas del euro).
- **Tasa manual desde cualquier interfaz**: el lápiz de la fila Manual
  (Inicio y hoja) abre el editor inline con formato de miles; guardar
  ACTIVA la tasa. La sección de Ajustes se conserva.
- **Conversor BIDIRECCIONAL**: escribir en el campo de abajo calcula el
  monto hacia arriba. Elegir la divisa del otro lado INTERCAMBIA los
  lados — jamás existe «VES → VES» (plan(from==to) → null, guard en
  setConverterPair). El swap conserva el número escrito.
- **MoneyField**: formato es-VE en vivo en TODOS los montos (1000 →
  «1.000», millón → «1.000.000», coma decimal; canon en dos pasadas que
  entiende setText programáticos).
- **UNA consulta por región** (DolarAPI lista completa): CO
  /v1/cotizaciones (USD+EUR juntos) + TRM; BR /v1/cotacoes (USD+EUR).
  Smoke test contra la API real: 10 fuentes vivas, 0 degradadas.
- **Snapshot garantizado**: el histórico que consulta el conversor se
  fusiona al libro local (día gana remoto) — toda tasa consultada vive
  en el teléfono.

### Persistencia y pantallas
- **hive → hive_ce** (Community Edition 2.20.0 + flutter 2.3.4): misma
  API para nuestras cajas JSON, cero migración de datos.
- **Sala reconstruida** (PushScreen): notch y barras del sistema
  respetadas, botón ATRÁS visible, separación uniforme — los 5 modos se
  conservan (Servidor con su config propia). Sala Viva y Tickets con el
  mismo tratamiento.
- **Ficha de producto**: secciones en Cards con divisores, montos con
  MoneyField; alta agrupada en Card.
- **Lista**: el Total grande en la moneda de cálculo + USD de extra al
  lado (≈ $); Vuelto y Dividir la cuenta se mudan al modal de Finalizar
  compra (bloque AL PAGAR); presupuesto con MoneyField y moneda que se
  fija y se conserva (bug: cambiarla sin monto la reseteaba a VES).
- **Ajustes**: sección de manuales reconstruida (fila flexible + editor
  compartido — el ancho fijo de 120 px desbordaba en pantallas angostas).
- **Home**: fecha/hora en UNA línea corta («lun 15 sep · 14:30»);
  héroe y banner animados con AnimatedSize (cero saltos al actualizar);
  con la tasa manual activa NO hay banner de «sin conexión» — es una
  tasa personalizada, la app funciona normal.
- **Conversor sin red**: el histórico responde del libro local PRIMERO
  (cero esperas de 9 s fingiendo búsqueda).

### Plugins
- tutorial_coach_mark retirado (motor propio); hive/hive_flutter →
  hive_ce/hive_ce_flutter; suite 159 tests verde, analyze 0 issues.
### Integración de la rama paralela (misma ronda, otra sesión)
Dos sesiones trabajaron la misma ronda v19.0 en paralelo; esta entrega
las INTEGRA sin perder nada:
- **Sala P2P reescrita desde 0** (seam RoomLink determinista:
  hello→welcome, roles, gobierno, caída del anfitrión + 317 tests de
  protocolo) — CON el modo **Servidor** devuelto (socket.io): el dueño
  ordenó NO eliminarlo; vuelve como un RoomLink más con su config
  (host:puerto, token, probar, guía).
- **Respaldo por región** si DolarAPI cae: VE → pyDolarVenezuela ·
  CO → Superfinanciera (datos.gov.co) + AwesomeAPI · MX → Frankfurter ·
  BR → AwesomeAPI — sobre la consolidación de UNA consulta por región.
- **CI endurecido**: toolchain fijado y pubspec.lock commiteado.

