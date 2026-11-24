# Changelog

## v27.2 — Modo caché de cálculo (REA CalculaYa) + herramientas instaladas

Investigación REA del APK 1.1.0: `RateCacheValidator`,
`cached_rates_dolarvzla_v1`, `history_rates_cache_v3`, `isCacheValid`,
«Invalidando cache y forzando actualización» y «Forzar actualización».
CalculaYa congela la tasa para calcular con ella y la invalida cuando el
usuario fuerza la actualización. Se aplicó el mismo concepto, **no** como
método de pago sino como modo de cálculo:

- **Modo caché**: ajuste persistido `Settings.cacheMode` que congela el
  tablero (`setRateBoard` no pisa la tasa mientras está activo). Como
  `contextOf()` alimenta todos los módulos, el conversor, la lista, los
  productos y el análisis calculan con **la misma tasa congelada**.
- **Aviso global** `CacheModeBanner` en el shell: «Modo caché · Tasa
  congelada: hace X» con botón **Actualizar** (apaga el caché, refresca y
  vuelve a congelar). También hay un chip **Caché** en la línea de fuente
  del Conversor y un interruptor en Ajustes → General.
- **Pull-to-refresh y Reintentar** respetan el modo: actualizan el caché
  en vez de pisarlo.
- **Herramientas instaladas y verificadas**: skills `impeccable-uxui`,
  `humanizer`, `egm-lite`, `egm-draft`, `egm-review` y `egm-drift-report`
  en `.agents/skills/`; CLI **REA 6.10.1** instalada con `npx` (el análisis
  nativo requiere Ghidra/Hopper, no configurado en el sandbox; la
  extracción del APK se hizo con unzip/strings). EGM se aplicó como
  SDD-lite: evidencia, diseño, revisión y drift.
- Gates: analyze 0 · **325/325** tests · auditoría de prohibiciones VERDE.

## v27.1 — REA del APK de CalculaYa 1.1.0: logos reales, titular y precisión BCV

Se analizó el APK `CalculaYa-1.1.0.apks` (base + splits) con ingeniería
inversa: unzip de assets, strings del AOT y revisión de los 27 PNG de
`assets/banks/`. Hallazgos aplicados:

- **Logos reales de los 27 bancos**: se copiaron y normalizaron a 128×128
  sobre fondo blanco (`assets/banks/`), con el nombre exacto del catálogo.
  La fila de cuentas y la hoja de Pago Móvil los usan; el monograma original
  queda como respaldo si el PNG tarda en decodificar.
- **Sistema de cuentas de CalculaYa**: además del alias y la cuenta
  principal de v27, cada cuenta guarda el **titular** («Account holder» del
  APK), banco, tipo, número, cédula y teléfono. El mensaje de cobro incluye
  al titular; el alta lo pide con etiqueta propia.
- **Precisión BCV (REA)**: el APK alterna «Decimales» y «Redondear»; el modo
  decimales usa todos los decimales de la tasa BCV. La app ahora arranca en
  4 decimales (BCV publica 4) y el ajuste permite 2, 3 o 4. Se aplicó a la
  tasa del Inicio, a las filas de Tasas y al resultado del conversor.
- **Investigación de herramientas**: impeccable (lenguaje de diseño y
  antipatrones), humanizer (patrones de escritura IA) y EGM (Google
  Elephant-Goldfish Model: SDD con brief, design doc, review, drift). Se
  aplicó el espíritu EGM: evidencia del repo, diseño por fases, revisión y
  gate visual; REA MCP se usó de forma manual (unzip/strings) porque el
  servidor no está instalado en el sandbox.
- Gates: analyze 0 · **322/322** tests (más 2 capturas visuales del gate) ·
  auditoría de prohibiciones VERDE.

## v27 — GUI/UX reconstruida: Inicio de verdad, hub «Más», Ajustes en capas y precisión CalculaYa (orden del dueño)

Encargo: «reconstruir las GUI/UX de la app móvil de la forma más completa
posible, mantener el contexto, usar impeccable y humanizer, quitar ETH,
usar los decimales de CalculaYa (REA), copiar su sistema de cuentas y
facilitar el acceso a los módulos». Metodología EGM: lectura de evidencia
del repo (v19–v26), auditoría doble pez→elefante (UX/visual + datos/
textos) y gate visual con capturas reales a 390×844.

- **Inicio de verdad (v27)**: una sola cifra protagonista (tasa activa +
  fuente + frescura + chispa real de 14 días), cuatro acciones de uso
  diario (Convertir · Lista · Precios · Cuentas), «Tu mes» con la cifra
  gastada y su presupuesto, y «Actividad reciente». Se retiran del Inicio
  el acordeón «Todo lo demás», la tabla de cotización, las divisas del
  foco, las alertas, las tiendas, los registros, las herramientas, el
  bloque «Libro» y la tarjeta de App Widgets. Nada se pierde: la
  cotización completa vive en **Tasas**, las herramientas en **Más**, los
  widgets en **Ajustes → General**, las alertas en **Productos** y las
  tiendas en **Historial/Análisis**.
- **Navegación lógica (5 pestañas)**: Inicio · Conversor · Lista ·
  Análisis · **Más**. «Más» es un hub con buscador local que reúne
  Productos, Historial, Tickets, Sala Viva, Cuentas, Ajustes,
  Actualizaciones y Privacidad. Las rutas sin pestaña propia marcan
  «Más» en la barra; el sidebar de escritorio conserva Productos en
  «Libro». Paleta ⌘K y tour actualizados a las cinco pestañas.
- **Ajustes reconstruido**: hub con seis grupos y el valor actual a la
  vista; cada grupo abre su pantalla (General · Tasas · Cuentas ·
  Apariencia · Datos y acerca de). General reúne país, **decimales
  2/3/4**, modo sin red, intervalo y widgets; Tasas reúne fuentes,
  manuales, tasas propias, alertas y diagnóstico; Cuentas es la pantalla
  de cobro; Datos reúne respaldo, registros, actualizaciones, tutorial y
  legal. Se acabó la lista interminable con secciones escondidas al final.
- **Precisión decimal (REA CalculaYa)**: ajuste persistido 2/3/4
  decimales (`Settings.precision`), aplicado a la tasa protagonista, a
  las filas de Tasas y al resultado del conversor; `fmtRatePrecise` y
  `fmtMoneyPrecise` con tests. La API de CalculaYa publica 4 decimales;
  el usuario elige cuántos ver sin perder la cifra exacta.
- **Cuentas de cobro (sistema CalculaYa)**: cada cuenta tiene alias
  («Cuenta principal»), banco, tipo, número, CI, teléfono y una estrella
  de **cuenta principal**; el Conversor abre el Pago Móvil con esa cuenta
  por defecto. Se añaden insignias originales por banco (27 monogramas
  sobre el color de marca, pintadas en Flutter) — no logos de terceros —
  con fallback de monograma. Borrar la principal promueve a la siguiente.
- **ETH retirado**: fuera del enum `Currency`, de las fuentes, del tema,
  del painter de banderas, del welcome (rejilla 4+3) y de las pruebas.
  Quedan 7 divisas: VES · USD · EUR · COP · BRL · MXN · USDT.
- **Textos humanizados**: Inicio, navegación, Ajustes, Cuentas, Tasas,
  Más, avisos y mensajes de cobro; menos párrafos, cero guiones largos en
  la UI y una idea por línea. Se conserva el español venezolano y el
  vocabulario local.
- **APIs al servicio de la pantalla**: Tasas muestra qué proveedores
  responden y cuáles no (`providers`/`degraded` del tablero); Ajustes
  mantiene diagnóstico por región, GitHub Releases, biometría, SSE,
  respaldo JSON y registros locales. Sin cifras inventadas.
- Gates: analyze 0 · **322/322** tests (nuevos: precisión, cuentas
  principales/alias, insignias, hub, tasas y navegación) · auditoría de
  prohibiciones VERDE · gate visual 9 capturas a 390×844 (Inicio, Tasas,
  Más, Ajustes, General, Cuentas, Datos y shell).

## v26 — dispositivos nuevos: vertical y horizontal + noche limpia (orden del dueño)

«Configura todo para vertical y horizontal en los móviles nuevos
(plegables), quita la cinta del Inicio y sus configuraciones, que no se
interrumpe la noche ni los botones de navegación de Android, arregla el
área blanca sobre el teclado, y quita textos pequeños que el usuario ya
sabe (el día)». Evaluación del aplanado v25 pedido por el dueño: lo
esencial SIGUE TODO (grupos USD/EUR de la Cotización, TUS TASAS con
brecha, hints de sección, stats de tiendas, GASTO ACUMULADO, pie del
Historial, Libro al pie) — nada faltaba; lo que salió fue ruido.

- **Responsivo de verdad (móvil girado · plegable · tablet ·
  escritorio)**: orientación desbloqueada (portraitUp + landscapeLeft/
  Right; sin portraitDown por la cámara) y shell adaptativo por AMBOS
  ejes: en un móvil girado (alto útil < 500 px) la barra de pestañas se
  conserva — el sidebar de 224 px se comería el paisaje —; el sidebar es
  para pantallas holgadas (≥ 700 px de ancho Y alto ≥ 500: tablets,
  plegables abiertos, escritorio). El SafeArea del shell en modo ancho
  consume el inset inferior: en un móvil girado la barra de gestos queda
  DEBAJO del contenido, no encima.
- **Conversor a DOS PANELES en horizontal**: LayoutBuilder decide con el
  espacio real (el sidebar ya descontó sus px) — si el lienzo es más
  ancho que alto (≥ 560 px), cifras/fichas/secciones a la izquierda
  (scroll) y acciones + VeKeypad como PANEL fijo a la derecha (340 px;
  scrollea solo en paisajes comprimidos). En VERTICAL el patrón
  calculadora v24.1a queda INTACTO (piso fijo permanente — cerrado). El
  pad funciona igual en su panel: teclas → campo activo.
- **No se interrumpe la noche + fin del «área blanca sobre el
  teclado»**: el fondo de la ventana Android pasa de blanco heredado a
  los colores EXACTOS del tema (values: #FAFAFA papel · values-night:
  #08080A grafito) — al abrir el teclado y re-tamañarse la vista, la
  franja expuesta pinta la MISMA noche, no blanco puro. Edge-to-edge
  (SystemUiMode.edgeToEdge): el papel pinta detrás de la barra de estado
  y de la barra de navegación, sin franjas ajenas al tema; splash
  alineado al papel/grafito exactos; corte de pantalla shortEdges
  (notch y plegables también en horizontal).
- **La cinta del Inicio SE RETIRA con todo su árbol** (no aportaba: las
  tasas ya viven en la sección Cotización): fuera el RateTicker del
  shell, fuera la sección «Personalización» de Ajustes (modo/tamaño/
  velocidad) y fuera los campos tickerMode/tickerSize/tickerSpeed del
  modelo. Los respaldos viejos que traigan esas claves cargan igual
  (fromJson ignora lo extinto) — verificado por test de round-trip.
- **El día ya lo sabe el usuario**: la línea «lun 24 nov · 14:30» sale
  del héroe del Inicio (el reloj del sistema vive en la barra de
  estado); el papel arranca con las acciones de cabecera a la derecha y
  el saludo como titular, ahora a 24 px Space Grotesk.
- Tests: **315/315** (nuevos: horizontal con pad-panel a la derecha y
  teclas funcionando, cinta + configuración ausentes en Ajustes, fecha
  fuera con saludo titular; reescrito el de fecha v19) · analyze 0 ·
  auditoría de prohibiciones VERDE · web rebuilt y verificado en vivo a
  390×844 y 844×390.

## v24.1 — patrón calculadora cerrado + deep link web + pulido de posicionamiento (orden del dueño)

Captura → corrección → recaptura sobre la v24.0d, con el encargo directo:
«el conversor debe ser como tipo calculadora… si yo subo todo sube… hay
elementos mal ubicados».

- **Conversor = calculadora de verdad**: los dos campos de monto son de
  SOLO LECTURA (`MoneyField.readOnly`) — el teclado del sistema JAMÁS
  aparece (en el teléfono el IME comprimía todo el layout: «si yo subo,
  todo sube»). La única vía de entrada es el VeKeypad, como una
  calculadora; tocar un campo cambia el lado ACTIVO (símbolo de divisa en
  tinta plena + cursor visible) y tocar el lado INACTIVO abre una entrada
  NUEVA (no concatena sobre el valor pasivo).
- **El pad es PISO FIJO permanente**: fuera el toggle «ocultar teclado» y
  el AnimatedSize — el VeKeypad vive SIEMPRE abajo, SIEMPRE en el mismo
  lugar; lo único que sube o baja es el contenido de arriba. El toggle ya
  no tiene sentido: sin pad no habría vía de entrada.
- **Deep link web arreglado (bug real desde v20.3)**: abrir/recargar
  /conversor, /ajustes o /historial CAÍA EN INICIO. Diagnóstico con probes
  de consola (boot → router → redirect): el histórico por defecto (hash)
  reescribe la URL (/conversor → '/') durante el arranque del motor, antes
  de que el router exista — Uri.base y defaultRouteName ya llegan tarde.
  Fix: la ruta de entrada se CAPTURA en main() (primer renglón, `Uri.base`
  todavía prístino), el router arranca con ella explícita +
  `overridePlatformDefaultLocation` y el history.state de la sesión previa
  se limpia en web/index.html. Verificado en vivo: /conversor /ajustes
  /historial /analisis abren directo.
- **Canal web que sirve builds frescos**: el preview server mandaba
  `main.dart.js` con `max-age=3600` — tras cada rebuild los usuarios
  navegaban hasta 1 h sobre el build VIEJO (y la auditoría con VLM leía
  código desactualizado). Ahora `Cache-Control: no-cache` para todo
  (main.dart.js no está fingerprinteado).
- **Eje X del gráfico de Análisis con 4 anclas exactas**: los múltiplos de
  intervalo de fl_chart no calzan con los extremos y fabricaban solapes al
  borde («19/11 24/11» pegados). `baselineX: minX` ancla la rejilla de
  títulos en las 4 anclas + filtro de anclas + `SideTitleFitInsideData`
  (los de borde se meten dentro). Verificado en vivo: 09/10 · 24/10 ·
  08/11 · 24/11.
- **Welcome equilibrado**: el Wrap de divisas dejaba a ETH sola en una
  segunda fila (7+1) — ahora rejilla 4+4 (VES USD EUR COP / BRL MXN USDT
  ETH), un elemento mal ubicado a la vista.
- **Inicio**: las barras de «Últimos 7 días» pasan de tinta fg (vigas
  negras) al verde de marca con ancho adaptativo (18 px con 2-3 datos) y
  esquinas 6; la chispa del héroe se muestra desde 3 puntos (con 2 era un
  guion plano flotante).
- **Test del conversor reescrito al patrón calculadora** (tap al campo +
  teclas del pad, no enterText) y goldens regenerados (conversor, inicio
  móvil y desktop).

## 1.16.0-beta+49 · v24.0d — polish impeccable + gate visual al día (iconos con tinta, tooltips de marca, techo fiel)

Vuelta de polish sobre el Material 3 nuevo con auditoría visual VLM de las
6 capturas + zoom de evidencia (la metodología de v23.3):

- **Iconos de botón con la tinta del texto (fix REAL de la auditoría)**: el
  icono `leading` de VeBtn/VeIconBtn caía al negro del IconTheme de la app
  y DESAPARECÍA sobre el botón primario (el «+» de Agregar producto era
  casi invisible — el zoom lo confirmó). `IconTheme.merge` con la tinta
  del texto, como la era shadcn.
- **Tooltips de tinta invertida** en AppTheme (la piel de shadcn, en
  Material puro): claro = tinta #09090B con texto blanco; oscuro =
  superficie accent con texto claro; 450 ms de espera.
- **Techo del sheet fiel al notch** (v24.0b): el 88 % se resuelve con el
  MediaQuery del contexto que ABRE — el bottom sheet de useSafeArea exponía
  padding cero y el techo se inflaba; el test del notch lo guarda.
- **Gate visual regenerado** (6 capturas, Material 3 + fl_chart) y
  auditado: 1 defecto real (el icono, corregido arriba); lecturas falsas
  documentadas con zoom y medición (el sparkline mide SU caja exacta de
  200 px; el ticker corta al borde porque es marquee; LIBRO vive bajo la
  barra al hacer scroll; el sidebar muestra 2 decimales por diseño
  compacto).

Gates: analyze 0 · 313/313 · auditoría VERDE · visual gate 6/6.

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
  `sharedPreferencesProvider` (fail-fast: se sobreescribe en main — el
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
- **P1-3 · Calculaya se consultaba en TODAS las rondas**: la condición se
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
  fuera; memo del Worker de Calculaya (1 consulta por ventana de 30 s
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
  VLM: Conversor y Análisis APROBADO directo; Inicio y Lista verificados
  por zoom (ticker-marquee y fixture de fechas son por diseño, no cortes).
  Nota honesta: el estado OfflineState se queda con su `Card` del tema
  (borde + sombra firma §8 ya de la paleta) — solo el copy cambió.

analyze 0 · 312/312 (20 tests nuevos: round-trip replace, fusión SSE ×3,
contrato `__tetherDerive__`, bordes de guardia, parsers tolerantes ×2,
galería a viewport móvil ×3) · auditoría de prohibiciones VERDE.

## 1.15.0-beta+48 · v23.2 — patrón calculadora, cripto USDT+ETH y failover Calculaya (EGM pez→elefante + impeccable + humanizer)

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
- **Failover Calculaya/CoinGecko en el tablero**: Worker público
  `calculaya-api.jalvarezgw19.workers.dev/tasas` (hallado por REA del APK;
  `usd` = BCV oficial verificado AL DÍGITO en vivo) como respaldo VE #2
  que NUNCA pisa dato fresco + COP mercado #2 (remesas); bloque cripto
  (`_cryptoBlock`): USDT P2P desde Calculaya, ETH/tether desde CoinGecko;
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
- **Libro**: chips de categoría → UNA línea con deslazo horizontal (dejan
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
  Calculaya/CoinGecko con payloads reales de curl 21/11/2026;
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
  dio baja el APK de la Release a `<cache>/valora_update/<nombre>.apk`
  (carpeta declarada al FileProvider) con porcentaje en vivo por fila —
  el tamaño esperado ya viaja en la Release, así el % marcha aunque el
  servidor no mande content-length. El cache del sistema es el hogar del
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
  ahí en adelante las rondas se instalan directo. REQUEST_INSTALL_
  PACKAGES declarado en el manifest con su porqué al lado.
- **Sin tokens ni credenciales**: la descarga sale de la URL pública de
  la Release (repo público) y la consulta sigue anónima (60/h por IP,
  con su mensaje propio si GitHub limita). Nada sale del teléfono.
- **Web conserva la vía navegador** (v22.3): el stub del facade
  responde «no disponible» y las filas vuelven a abrir el navegador —
  en web no hay filesystem compartible ni instalador de sistema. El pie
  de la pantalla cuenta la verdad de cada plataforma.
- androidx.core declarado EXPLÍCITO en build.gradle.kts (el manifest ya
  referencia androidx.core.content.FileProvider; la versión no depende
  de la transividad de terceros).
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
