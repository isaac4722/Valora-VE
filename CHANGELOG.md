# Changelog


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
  exige»; este no es un caso). El hardening REAL del token del relay va por
  donde le duele a la fuga: `allowBackup=false` + `dataExtractionRules`
  vacías — el token y el estado jamás viajan en copias cloud/adb o
  migraciones de dispositivo; la copia de seguridad es la de la app
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
