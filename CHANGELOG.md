# Changelog


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
