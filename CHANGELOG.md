# Changelog


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
  (el propio Flutter avisaba que dejaría de soportarlo) y
  `ndkVersion = 28.2.13676358` (la que exige integration_test; el
  default 27.0.12077973 chocaba en cada build).
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

