# Changelog


## v29 — Parte 3 (Conversor) y Parte 4 (Lista) del dueño *(recuperado)*

Reconstruido en v31 tras perderse el ciclo original. Conversor: título
solo, fecha con protagonismo **Ayer · Hoy · Mañana · Fecha**, campos
gemelos, selector de tasa obvio, atajos fuera, precisión UNA escala
(X,XX · X,XXX · X,XXXX · Completo), swap con la regla del 0, Pago Móvil
con Compartir-imagen/Copiar-texto y patrón sin scroll. Lista: barra
pegadiza en `bottomNavigationBar` (antes tapaba los campos), tarjeta de
valor con FittedBox, presupuesto de una línea, plantillas y toggle «más»
eliminados, Sala en vivo reubicada y reconstruida.

## v30 — Parte 5 (Análisis · Más · Ajustes) del dueño *(recuperado)*

Reconstruido en v31. Análisis en 4 secciones (Divisas · Inflación ·
Canasta · Gastos) sin duplicados; Más con solo Productos · Tickets ·
Ajustes · Actualizaciones · Privacidad; Ajustes en UNA pantalla con
cuentas por TIPO de cobro (pago móvil = banco+cédula+teléfono;
transferencia = banco+tipo+número+cédula; zelle = titular+contacto US),
`dataLines` única fuente y migración de respaldos sin pérdida.

## v28 — Reglas globales del dueño: tipografía, envío y sin sobrecapas · Inicio como equivalencia · Tasas en secciones

Ciclo EGM completo (Goldfish → Elephant) sobre el encargo del dueño en la
rama `v1.1.0-dp4-paridad`. Registro detallado en `HALLAZGOS_v28.md`.

- **Tipografía de 4 tamaños** (`VeType`, core/theme.dart): caption 11 · body
  13.5 · title 17 · display 30. Barrido completo de `lib/` (47 archivos): el
  inventario final es EXACTAMENTE esos 4 valores. Piso de `labelCaps` subido
  a 11.
- **Cero recortes «…»**: los 85 `TextOverflow.ellipsis` se resolvieron sin
  segunda línea — `FittedBox(scaleDown)` para datos dinámicos (el texto
  escala, nunca se corta) y textos cortados corregidos a mano en
  `DefaultTextStyle`.
- **Moneda: símbolo SIEMPRE después del número**: `fmtCurrency` produce
  «915,38 $» / «10.000,00 Bs»; el Conversor mueve el símbolo tras el monto.
  Punto=miles, coma=decimales (es-VE ya nativo). +3 tests en `fmt_test`.
- **Dos vías de envío**: COMPARTIR solo archivos (PNG/JPEG/PDF, jamás con
  texto: el menú del sistema ya no ofrece «enviar texto») y COPIAR para todo
  texto. `export_sheet.dart` reescrito (`ExportKind`/`ExportMode`); Pago
  Móvil queda con «Copiar mensaje»; ticket viaja sin texto.
- **Interfaz**: iconos PERFECTAMENTE centrados en su caja (`VeIconBtn`
  Stack center; bug topStart) y del tamaño de su letra (sm 11 · md 13.5 ·
  lg 17); ghost y secondary delineados (nada de texto-plano clicable);
  chevron en toda fila de tasa; **cero sobrecapas**: 3 PopupMenu fuera
  (acciones inline / hoja inferior), tips contextuales y tour automático
  desactivados (la guía vive en la descripción de cada sección).
- **Inicio**: tarjeta de equivalencia **«1 USD = 922,5637 Bs»** (el «=» como
  pieza gráfica en tinta primaria) — sin gráfica, sin paralelo, sin brecha:
  UNA sola moneda (fuente activa del país, BCV por defecto, configurable en
  Ajustes). Nombre de tasa en UNA forma («BCV · Oficial»; «Oficial» siempre).
  Composición `VS | ▲/▼ % ayer`.
- **Tasas**: secciones con jerarquía completa — TÍTULO (bandera + «USD ·
  Dólar»), DESCRIPCIÓN de una línea, DETALLES (filas) y ACCIÓN («Configurar
  fuentes»); separadas por espacio en blanco + hairline, sin cajas dentro de
  cajas; «Tus tasas» gana su propia sección.
- **Herramientas (Fase 2)**: skills `flutter-unslop`, `unbland`,
  `anti-slop-design` instaladas en `.agents/skills/` (skills-lock.json
  actualizado); REA CLI 6.10.1 operativa; EGM aplicado de punta a punta.
- **Tests**: 329/329 verdes; `rate_sheet_test`, `custom_rates_test`,
  `tips_test` y `widgets_test` actualizados al contrato v28 (estructura
  nueva, intención protectora intacta). Gate visual web (Inicio, Tasas,
  Conversor) sin recortes ni overlays.

## v27.3 — Modo Cachea (Cashea) en la Lista + GUI: botones centrados, bordes y teclado

Corrección del encargo anterior: el «Modo Caché» se retira. Lo que el dueño
pedía era **Modo Cachea**, el esquema de compra con inicial + cuotas
quincenales sin intereses que Cashea popularizó en Venezuela. Se implementa
como **utilidad de cálculo**, no como método de pago:

- **Modo Cachea** en la Lista (botón junto al total): total de la compra,
  inicial 20/30/40/50 % y 3/6/9/12 cuotas; muestra inicial, valor de cada
  cuota y total a pagar en la moneda de cálculo, con equivalente en USD y
  bolívares. Aviso claro de que es informativo y no procesa pagos.
- **Lógica pura** en `lib/core/cachea.dart` con tests de matemática y
  bordes; hoja en `lib/features/lista/cachea_sheet.dart`.
- **GUI**: texto centrado en todos los botones (antes los no expandidos
  arrancaban a la izquierda); borde visible solo en botones secundarios y
  en los accesos rápidos del Inicio (no en toda la UI). Ajustes vuelve a
  la cabecera del Inicio como acceso directo, sin quitarlo de «Más».
- **Teclado**: el shell deja de restar el IME dos veces; la barra inferior
  se esconde mientras se escribe y el contenido queda pegado al teclado,
  sin franja vacía. `resizeToAvoidBottomInset: false` + `AnimatedPadding`.
- **Herramientas**: skills `impeccable-uxui`, `humanizer`, `egm-lite`,
  `egm-draft`, `egm-review`, `egm-drift-report` instaladas en
  `.agents/skills/`; REA CLI 6.10.1 verificada.
- Gates: analyze 0 · **326/326** tests · auditoría de prohibiciones VERDE.

## v27.2 — (RETIRADO en v27.3) Modo caché de cálculo + herramientas instaladas

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
  al titular; el alta la pide con etiqueta propia.
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
  escritorio)**: orientación desbloqueada (portraitUp + landscapeLeft/Right;
  sin portraitDown por la cámara) y shell adaptativo por AMBOS
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
  #08080A grafito) — al abrir el teclado y redimensionarse la vista, la
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
