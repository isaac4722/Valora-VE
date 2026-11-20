# Changelog

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
