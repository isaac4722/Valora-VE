# Changelog

## 1.6.0-beta+14 · ronda v17.7 — cambios pendientes + Ola 1 + reestructura

Orden del dueño: «mejores la app en reestructura optimizar ect. Y realizar
los cambios pendientes» (todo en la rama, NADA se pasa a main hasta orden
explícita). Ciclo 9P completo con gates LOCALES por primera vez (SDK
Flutter 3.47.4 instalado en el entorno del agente: analyze + suite antes
de CADA commit, además del runner).

### Añadido · pendientes del scorecard (docs/PARIDAD-MVP-CRUD.md §3)
- **`ConversionPlan.direct` + ruta EUR de 4 tramos visible**: el plan del
  motor es clase propia con bandera de arista directa; el puente EUR se
  pinta COMPLETO (EUR → local → USD → destino) con sello por tramo y
  rótulo del tipo de ruta — antes colapsaba a 2 banderas.
- **Análisis 9.7 (cierre casi total)**: rankings de compras por día de
  semana y por divisa · proyección PUNTEADA DAMP (φ 0.85, la misma
  semántica de predictPrice) sobre el costo de la canasta · **heatmap de
  devaluación 6 meses** (cierra la desviación D2: calendario pictórico,
  un cuadro por día, rojo/verde/intensidad) · **exportGapCsv** (brecha
  por día en CSV) · **histórico multi-divisa** (hasta 3 fuentes
  superpuestas + CSV por columnas).
- **Biometría con toggle** (cierra el pendiente): puerta de marca al
  abrir (main.dart) con verificación de soporte real antes de activar;
  sin soporte o sin canal NUNCA bloquea.
- **SSE en vivo** (cierra el pendiente): `RatesStream` (el cliente ya
  existía sin instanciar) se conecta a `/api/rates/stream` del
  despliegue web que el dueño configure en Ajustes; ingesta común con el
  polling (que sigue como latido), reintento 60 s / 5 min, apagado en
  idle, punto de estado con diálogo de URL.
- **`price_targets` de producto en 2º plano** (cierra el pendiente):
  `AlertEngine.checkProductTargets` anuncia cruces frescos por el canal
  `price_targets` (in-app y en la tarea horaria de workmanager — el
  dispatcher ya lo prometía en su comentario), con rearme y claim por
  día. `metSince` (v13.2) como guarda durable.
- **Familia de widgets BCV** (§12.2 · plan subclassing):
  `BaseRatesWidget` Kotlin + `ParallelWidgetProvider` y `GapWidgetProvider`
  (misma celda 4×1), layouts/receivers con etiqueta, brecha escrita por
  Dart y recalculada de respaldo en Kotlin.
- **Ola 1 del protocolo v2**: el país vive EN la bienvenida (página 3 con
  chips; el paso obligatorio llega preseleccionado) + **coach-marks por
  feature** (cierra D3): `valorave.tips-dismissed`, puntas ancladas al
  widget real, disparadas SOLO tras el walkthrough del módulo — 5
  cableadas (Inicio · Conversor · Lista · Productos · Análisis).

### Cambiado
- **Reestructura**: `converter_screen.dart` 1515 → 845 + 2 parts
  (referencia del par · histórico/notas); `settings_screen.dart` 1102 →
  211 + 3 parts (secciones · alertas · sistema). Parts de la misma
  biblioteca: cero renombres, mismo comportamiento.
- `NotificationsService.show` endurecido (degradación honesta sin canal
  — el centro interno sigue), lo que además hizo el engine testeable.
- README: «Descarga actual» apunta a v1.0.2-beta (corregido en el
  recheck anterior, se mantiene).

### Gates
- analyze=0 issues · **test=126/126** (19 nuevos: motor 5 · análisis 11 ·
  settings 1 · metas 2 · coach-marks 1 · bienvenida reescrito) · build
  en Actions tras el push (matriz APK arm64/v7a).

## 1.5.0-beta+13 · recheck de auditoría — el versionado vuelve al patrón del contrato

El dueño ordenó un recheck completo de `progress.md` y la documentación
contra el código real de esta rama, aplicando el ciclo de 9 pasos de
`AGENT.md`. Resultado de la auditoría: **todo lo declarado existe y está
aplicado** — ronda 1.1.0-dp4 (7/7: quick_actions 4/4, `Decimal` en
`cartTotals`/`computeChange`, «Probar aviso» con notificación Android
real, cabecera solo-nombre, héroe con `ReadWindow` 38, búsqueda global a
pantalla completa con el fix dp5, bienvenida `PageView` de 3 páginas),
ronda v17.6 RECHECK (6/6), v17.5, v17.4 y v17.2 verificadas con evidencia
`file:line`; gates CI+Build verdes en el SHA de partida (fb93678); Reglas
5 y 7 de `AGENT.md` limpias (sin mocks, sin `AppStateScope`, sin patrones
web, sin tokens; 35 dependencias, todas de pub.dev).

### Corregido
- **Versionado fuera de patrón (Regla 5 de AGENT.md)** — la escalera de
  las rondas anteriores (`1.1.0-dp4+6` → `1.2.0+7` → `1.3.0+10` →
  `1.4.0+11` → `1.5.0+12`) había perdido el prerelease `-beta` exigido
  por el contrato (`1.x.y-beta+z`). Se restaura como `1.5.0-beta+13`:
  misma línea 1.5.0 que documenta el CHANGELOG, build siguiente (+13) y
  patrón del contrato devuelto. La versión visible de marketing
  (`kAppVersionVisible`, hoy «17.6») NO se toca: es la convención que ya
  usaba main («17.1» con pubspec `1.0.2-beta+3`), distinta del versionado
  del paquete.
- **pubspec con comentario mentiroso** — decía «v1.0.1-beta+2 · ronda de
  paridad» encima de `1.5.0+12`; ahora documenta la restauración real.
- **README desactualizado** — «Descarga actual» apuntaba a v1.0.1-beta;
  el último release real (verificado por API) es **v1.0.2-beta**.

### Documentación
- **`progress.md`**: entrada `[RECHECK-V17.6]` con el resultado completo
  de la auditoría y la reconstrucción de bitácora de las 5 rondas
  (1.1.0-dp4, v17.2, v17.4, v17.5, v17.6) que estaban en git y CHANGELOG
  pero SIN sección en progress.md — violaban la Regla 2 («sin sección, tu
  trabajo no existe»). Se registran con su rango de commits real, sin
  falsificar fechas.
- Nota honesta: TASK-12 citaba `scripts/verify_apk_sig.py` como evidencia
  de la verificación de firma de v1.0.0-beta; ese archivo era un artefacto
  local del entorno de aquel turno y nunca se commiteó al repo.

## 1.5.0+12 · ronda v17.6 — RECHECK: los fallos confirmados del dueño, resueltos antes de las olas

Quinta pasada. El dueño trajo protocolo v2 (RECHECK + 12 olas): nada de código
nuevo hasta verificar los puntos pendientes CON EVIDENCIA. Se activaron las
skills del protocolo (taste-skill en modo redesign-preserve,
flutter-architecture/ui-design/persistence/testing/platform-integration,
syncfusion-flutter-cartesian-charts; `impeccable` y
`antigravity-bundle-mobile-developer` NO existen en este entorno — reportado).
Resultado del RECHECK: 7 puntos ya cumplidos (dedupe rate-history, héroe con
sparkline y badge «activa», cero bloque 02/Sueldo, banderas locales con
errorBuilder, bienvenida vs walkthrough separados, Trackball+Crosshair,
cobertura real), 3 parciales y 5 fallos confirmados. Esta ronda resuelve los
fallos. Validación local: scripts/validate_v176.py (lexer balance 5 archivos +
28 anclas) ALL OK.

### Corregido
- **«Bs Bs» duplicado en el Conversor** — causa raíz: la salida mostraba la
  píldora `CurrencyTag('Bs')` Y `fmtCurrency()` que ya pinta el prefijo
  `Bs 832,49`. El subtítulo lleva ahora SOLO el número (`fmtMoney`); la
  divisa la dice el tag una sola vez.
- **Swap del Conversor descentrado** — estaba anclado con `SizedBox(width:44)`
  + `Spacer()` (pegado a la izquierda); ahora centrado real con dos
  `Expanded` simétricos entre la fila de entrada y la de salida.
- **Jerarquía héroe del Conversor** — la SALIDA es la cifra héroe (56
  tabular); la entrada editable baja a 40 (secundaria). Una sola cifra
  displayLarge por pantalla.
- **Date picker «no aparece nada»** — el calendario solo contaba días de
  snapshots LOCALES: en un teléfono recién instalado veía 1-2 días y parecía
  roto. Ahora la hoja abre al instante con lo local y fusiona EN VIVO la
  serie remota de 180 días de las fuentes del par (`seriesForSource`),
  con estado «Consultando los días disponibles…» mientras llega, hoja con
  esquinas propias + `useSafeArea`, y mensaje honesto si no hay red NI
  snapshots. Al elegir, la tasa sigue cargando remoto-primero con respaldo
  local (`rateOn`).
- **Pantalla negra del escáner global** — `ScannerScreen` (Productos) era
  full-frame sin estado de cámara: permiso denegado / cámara ocupada = negro
  mudo. Paridad total con RoiScanner: `scanWindow` (recuadro 72 % × 32 %,
  una sola verdad geométrica, sin pinch-zoom que descuadraría el ROI),
  máscara α .55 y marco de apuntado; `errorBuilder` distingue permiso vs
  hardware y ofrece «Abrir ajustes» (`openAppSettings`) y «Escribir a mano».
  Debounce + bandera `_done` anti doble pop.
- **«Buscando tasas…» con icono wifi-off (Inicio)** — el combo mentiroso
  prohibido por el dueño. Ahora la carga usa SPINNER; wifi_off solo en la
  rama de red bloqueada sin datos; cloud_off solo en modo offline elegido.

### Añadido
- **`VeInk` es `ThemeExtension<VeInk>`** (RECHECK R1-1) — las 7 semánticas de
  dinero (pos/neg/warn/manual/cop/brl/mxn) viajan DENTRO del ThemeData
  (`extensions:` en `AppTheme.light()/dark()`, con `copyWith` y `lerp`).
  API pública intacta: `VeColors.of(context)` lee la extensión con fallback
  por brillo; cero llamadas migradas.
- **Estados reutilizables (RECHECK R1-4)** — `LoadingState` (spinner, jamás
  iconografía de red), `ErrorState` (tinta neg + CTA de recuperación) y
  `OfflineState` (cloud_off + copy honesto es-VE + hasta 2 salidas) en
  ui.dart, con la gramática visual de `EmptyState`. Inicio ya los usa.

## 1.4.0+11 · ronda v17.5 — GUI con consultoría externa: toast unificado, divisas explícitas y alertas de producto

Cuarta pasada de GUI, ahora con las sugerencias del modelo de apoyo que el
dueño trajo (consulta con acceso web). Antes de tocar código se auditó cada
punto contra el árbol real: la mayoría ya vivía (tabular figures, FittedBox,
scanWindow, checkout modal, editor de peso, Syncfusion, tickets, CSV,
presupuesto, alerts de tasa, skeleton, pull-to-refresh, ThemeMode.system).
Solo se integraron los HUECOS REALES. Skills: taste + flutter-ui-design +
caveman (moderado).

### Añadido
- **Toast unificado (`showToast`)** — un solo lenguaje de feedback efímero
  para toda la app: flotante, esquina 12, superficie de tinta invertida,
  icono semántico por tipo (info/ok/warn/error con la semántica VeInk) y
  acción opcional. Migrados los 34 SnackBars crudos de 12 archivos; cero
  estilos sueltos. La acción «Ver historial» tras guardar compra se conserva.
- **Etiqueta de divisa (`CurrencyTag`)** — píldora caps junto a la cifra:
  USD con tinta primaria (protagonista), Bs neutra, COP/BRL/MXN/EUR con su
  semántica. El color identifica la divisa, nunca oficial/paralelo (eso
  sigue siendo de datos). Aplicada en Conversor (entrada y salida), héroe
  de Lista y «Precio vigente» de la ficha.
- **Alertas de subida de precio por producto** — hueco real del consultor
  (prioridad alta): `AlertEngine.checkProductRise` avisa cuando un producto
  sube ≥ umbral (slider nuevo en Ajustes, default 10 %) vs su último
  registro, con dedupe por producto+día. Se dispara al registrar precio en
  la ficha y al guardar una compra con producto vinculado. Notificación del
  sistema + centro de notificaciones (kind «umbral»).
- **Comparador de tiendas en la ficha** — sección «Tiendas»: último precio
  por tienda ordenado de más barato a más caro; el más barato va en tinta
  verde con «MÁS BARATO», cada fila con antigüedad y nº de registros. Solo
  aparece con ≥ 2 tiendas (honestidad: sin comparación no hay sección).

### Descartado (con razón documentada)
- Migrar a flutter-starter-app/Riverpod/GoRouter o cambiar paquetes de
  sync/nearby/gráficas: la app ya usa provider + go_router + Syncfusion y
  tiene su propio offline-first con dedupe — el consultor evaluó una
  versión vieja/imaginada del árbol. Evolución, no reescritura.
- AnimatedSwitcher sobre la cifra del Conversor: `AnimatedNumber` (odómetro
  tabular) ya anima la salida; añadir otro animador sería doble motion.

## 1.3.0+10 · ronda v17.4 — dp6 completo: tickets, Material You, matriz y diagnóstico

Tercera pasada de GUI: el dueño pidió «créalo bien todo». Diff completo
dp6 ↔ árbol v17.3 y cierre de los 4 huecos reales que quedaban (todo lo
demás ya vivía en el árbol). Skills: taste + flutter-ui-design +
caveman (moderado), igual que v17.3.

### Añadido
- **Pantalla Tickets (`/tickets`)** — galería 3× de las fotos de recibos
  guardadas en las compras (`ticketPhoto`, data URL comprimida ~200 KB).
  Visor a pantalla completa con zoom 8×, franja de contexto (total pagado,
  Bs, tasa usada), compartir imagen y «quitar foto» con confirmación (la
  compra jamás se borra desde aquí). Foto ilegible → estado honesto, nada
  se rompe. Entradas: Historial (icono galería) y Búsqueda universal.
- **Material You (dp6 · mejora 2)** — `dynamic_color` ya estaba declarado
  pero sin usar. Ahora `AppTheme.light/dark([dynamicScheme])` acepta la
  paleta armonizada de Android 12+ y `ThemeController.dynamicColor`
  (opt-in, persistido) la activa desde Apariencia. CONTRATO: el esquema
  dinámico SOLO tiñe primario/onPrimary (botones, selección, foco);
  superficies, bordes, texto y semántica de dinero siguen de marca.
- **Diagnóstico de fuentes (dp6 · mejora 8)** — sección nueva en Ajustes:
  «Ejecutar diagnóstico» consulta las 4 regiones en vivo y muestra
  OK/Sin respuesta + fuentes obtenidas + latencia ms + error. El data
  layer (`diagnoseRegions`) ya existía en board.dart; faltaba la vista.
- **Matriz 6×6 del conversor (dp6 · mejora 9)** — «Tabla de referencia
  6×6» plegada por defecto: las 6 divisas del foco cruzadas con la tasa
  vigente (1 A = X B vía el plan activo), scroll horizontal con barra,
  celdas sin ruta honestas («—») y diagonal «·».

### Cambiado
- Apariencia ahora agrupa modo de tema + interruptor Material You en una
  sola tarjeta.
- Versión visible 17.4.

## 1.2.0+9 · ronda v17.3 — GUI dp6 integrada (sistema de componentes)

Segunda pasada de GUI guiada por el dueño: «trabaja más la GUI» + adaptación
de dp6 al árbol actual (el actual manda: solo se integra lo que faltaba).
Skills aplicadas: taste (disciplina visual), flutter-ui-design (jerarquía,
estados, tokens), caveman (comunicación, nivel moderado). Skill Caveman
guardada en `agent-skills/caveman/` junto a las familias taste/flutter/dart.

### Añadido — componentes dp6 en ui.dart (adaptados a los tokens VeText/VeColors)
- **PrimaryButton / GhostButton**: botones del sistema (radio 12, feedback
  táctil) — unifican los FilledButton crudos dispersos.
- **Sparkline**: mini-tendencia editorial (sube=neg, baja=pos, meta punteada);
  reemplaza la copia privada de Productos (menos duplicación).
- **MiniRateCard**, **SectionCard**, **SheetHeader**, **Paginator**
  (accesible, liveRegion), **Settle** (cifra que se asienta) y
  **CategoryLegend** (leyenda Oficial/Promedio/Paralelo/Manual).

### Añadido — integración en pantallas
- **Inicio · Sparkline de 7 días** bajo el héroe de tasa: honesta, solo con
  ≥ 2 snapshots reales; muestra «Ayer» de referencia.
- **Inicio · Divisas del foco** rediseñado: grid 2-col de MiniRateCard con
  tinte por categoría y HOJA DE FUENTES por divisa (radio de fuente con
  monto «1 USD = X»; la manual lleva a Ajustes) — patrón dp6 que faltaba.
- **Paginador accesible** en Historial, Productos y Finanzas (antes filas
  ad-hoc sin tooltip ni Semantics).
- **SheetHeader** en la hoja de movimiento de Finanzas.
- **Settle** en la cifra del héroe; botones del sistema en el CTA del
  constanciero («Compartir o guardar…»), «Guardar compra» del checkout y
  estados vacíos de Inicio.
- **CategoryLegend** en Bienvenida (página 3) y Ajustes → Monedas y tasas.

### Mantenido
- Nada de dp6 sobreescrito: FeatureTip (coach-mark) NO se porta — 0 usos en
  dp6 y el sistema de walkthroughs v17.2 ya lo cubre con foco real.

## 1.2.0+8 · ronda v17.2-b — auditoría del Review.txt

Cruce punto por punto del Review.txt contra el código. Todo lo pedido ya
estaba aplicado en v17.2; esta pasada cierra los 2 únicos huecos que
quedaban y valida el resto con anclas de código.

### Corregido
- **Sala: modo Hotspot explícito** («HostPost» del dueño): quinto modo en el
  lobby. El anfitrión activa su punto de acceso y los invitados se conectan
  a él: mismo transporte TCP+UDP del modo LAN dentro de esa subred, cero
  internet y cero datos móviles. PIN+emoji y descubrimiento idénticos.
- **Walkthrough de la Sala en vivo**: /sala era el único módulo sin
  recorrido (está fuera del shell). Ahora se dispara al entrar la primera
  vez y es rejugable desde Ajustes → Tutorial.

### Validación
- 14/14 puntos del Review.txt verificados contra anclas de código reales
  (skills en repo, welcome, inicio sin «02»/Sueldo, offline+dedupe, 8 reqs
  del conversor, tarjeta de marca, lista/checkout 7 reqs, historial 4 reqs,
  productos 6 reqs, finanzas PDF+menú propio, análisis 5 reqs, vuelto
  multi-divisa, dividir con propina, sala P2P completa).

## 1.2.0+7 · ronda v17.2 — offline-first real + revisión general de GUI

Ronda guiada por la revisión completa del dueño: el foco es el
**funcionamiento offline real con persistencia sin duplicados**, los
**walkthroughs por módulo** y una pasada de calidad GUI en TODOS los
módulos (conversor, lista/checkout, productos, finanzas, análisis, sala).
Sigue en rama de prueba: se compila, el dueño prueba y solo entonces va a
main. Skills de agentes incluidas en el repo (`agent-skills/`).

### Añadido — Offline y persistencia (la queja #1)
- **Modo offline total elegible** (Ajustes → Datos y conexión): la app NO
  consulta ninguna API; todo se lee del libro local + tasas manuales.
- **Intervalo de consulta configurable** (1/5/15/30/60 min): «consultas
  esporádicas» por decisión del dueño; el poller se reprograma solo y en
  fallo de red reintenta a los 60 s como máximo.
- **Snapshots sin duplicados**: regla (fuente, día, valor) — un valor
  idéntico en la misma fecha/fuente no vuelve a escribirse; el libro es
  una hoja de ruta compacta por fecha.
- **Estado vacío honesto** en Inicio: distingue «modo offline activo» /
  «sin conexión · sin tasas guardadas todavía» / «buscando tasas» — ya no
  sugiere configuración errónea cuando solo faltó red. Con tasas guardadas
  en Hive, sin red se SIGUE viendo todo (cache-first).

### Añadido — Walkthroughs («app walkthroughs»)
- Recorrido guiado por módulo (Inicio, Conversor, Lista, Productos,
  Historial, Finanzas, Análisis, Ajustes): overlay con foco, pasos
  progresivos, se muestra una vez por instalación y **se repliega desde
  Ajustes → Tutorial → Recorridos por módulo**.

### Añadido — Compartir y descargar (menú propio)
- **Menú propio antes del share nativo** (regla: nunca PNG/PDF directo):
  texto · imagen · PDF, cada uno con «compartir» y «descargar» (guardar en
  carpeta ValoraVE sin abrir el share).
- **Tarjeta de conversión de marca** (1080×1080, compuesta offstage, solo
  memoria): «de esta divisa a esta divisa es tanto» con banderas, fecha y
  fuente — ya no es una captura del cuadro.
- **PDF de constancia reconstruido**: encabezado de marca, cajas de
  totales en color, tabla de desglose por categoría/tienda, pie honesto.

### Mejorado — Inicio
- «Cotización principal» muestra TODAS las tasas de la moneda del país
  (BCV · Paralelo · Promedio · Manual) + la fuente activa de las demás
  divisas, con valores manuales incluidos.
- Retirado el bloque «Tu sueldo» y los índices numéricos «01/02/…» de los
  títulos de sección (decisión del dueño).

### Mejorado — Conversor
- Números largos no rompen el cuadro (FittedBox + lectura/escritura dual).
- Selector de fuente de tasa accesible, oficial por defecto, override por
  módulo con «seguir global».
- Fecha de las tasas bajo el título con presets y **calendario histórico
  funcional** (solo días con snapshot guardados; fin de la pantalla gris).
- Tabla de referencia con ≥2 tasas por divisa identificando moneda y
  fuente («EUR Oficial a Bs», «COP Mercado»…), tap para activar.
- Ajustes rápidos (+100/−100/+10 %/−10 %) junto al campo de entrada.

### Mejorado — Lista y checkout
- Selector de fuente de tasa junto al de moneda del cálculo.
- Escáner procesa SOLO el recuadro de apuntado (scanWindow/ROI).
- Editor de ítems completo: nombre, precio, cantidad, **peso/volumen con
  precio por kg/l**, tienda y código de barras.
- Escaneo sin resultado → «repetir escaneo» o «agregar manualmente» con el
  código prellenado.
- Multitienda: tienda única capturada una vez (editable) o por ítem; la
  compra registra cada producto según su tienda.
- **Checkout como modal** (tiendas, cuenta ajustada, nota, foto de ticket)
  con acceso directo al historial tras guardar.
- Aviso «ya existe» al vincular compras con productos registrados (match
  por código o nombre+tienda, nunca por precio/peso).
- **Compresión automática de tickets antiguos** (>30 días, re-encode JPEG
  solo si reduce >20 %; sin dependencias nuevas).
- Vuelto con **pagos multi-divisa** y dividir cuenta con personas y
  propina.

### Mejorado — Productos
- Ficha como menú completo: gráfica de evolución, variación del último
  registro, historial editable, cambio de código de barras (con escáner)
  y tienda, meta de precio, alta con primer precio en un paso.
- Iconos de importar/exportar escaneo claros y consistentes.

### Mejorado — Análisis
- Gráficas interactivas (tooltip + trackball/crosshair al tap).
- Selector de brecha con cursor en el punto exacto y brecha por día.
- Etiquetas de cobertura REAL («1 Año · N días con datos»).
- Inflación personal con canasta y desglose, históricos sin errores.

### Mejorado — Sala en vivo
- **Pantalla completa** (ruta /sala, adiós al sheet deslizante).
- Cuatro modos: Servidor (sockets) · Cerca (Nearby WiFi-Direct/BT/BLE) ·
  WiFi local (LAN, sin internet) · Bluetooth, cada uno pidiendo SU permiso.
- **Verificación PIN de 4 dígitos + emoji coincidente** en todos los
  caminos; si el emoji no coincide se cancela.
- Descubrimiento de salas públicas cercanas (Nearby + UDP) o entrada por
  código; pública/privada; máximo 10 miembros.
- Servidor propio configurable desde la sala (host:puerto + token, probar
  conexión, guía) y «este teléfono como servidor» con IP:puerto.

### Otros
- `agent-skills/` con la familia taste-skill (Leonxlnx) + skills
  flutter/dart para agentes que trabajen en el repo.
- Modelos: CartItem y PurchaseItem con tienda/tamaño (JSON tolerante).
- Store: findSimilarProduct + recordPurchaseItemOnProduct para el flujo
  compra→catálogo.

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
