# Changelog


## 1.9.10-beta+28 · v19.10 — Auditoría visual premium + notificaciones que sí llegan en 2º plano
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
