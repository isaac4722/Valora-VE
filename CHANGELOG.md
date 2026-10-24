# Changelog

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
