# Changelog


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

