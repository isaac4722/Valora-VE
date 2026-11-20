# Changelog

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
- **Integración DolarVZLA re-verificada contra el openapi.json en vivo**:
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

