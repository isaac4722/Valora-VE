# HALLAZGOS v34 — Ronda de errores del dueño

Registro de trabajo del ciclo v34. Entrada: el dueño revisó la app tras
la v33 y reportó errores observados pantalla por pantalla; este ciclo
los corrige y reescribe las GUI pedidas. Cada hallazgo lleva su fix y su
verificación.

Convención: **E-##** error reportado por el dueño · **F-##** hallazgo
propio encontrado durante el arreglo.

---

## E-01 · Desalineación en la parte inferior de la Bienvenida (4 slides)

**Síntoma** (dueño): «Primera pantalla: desalineación visual en la parte
inferior (indicadores de página y botón Siguiente)» — y persiste en las
cuatro pantallas.

**Causa raíz**: la barra de control era un `Row` con
`Flexible(Atrás, max 96) + Expanded(puntos) + Flexible(Siguiente,
max 150)`. Los puntos vivían en el HUECO entre botones: como
«Siguiente/Comenzar» es más ancho que «Atrás», el centro de los puntos
quedaba corrido a la izquierda del eje de la pantalla.

**Fix**: la barra es un `Stack` — `Center` con los puntos sobre el ancho
REAL de la pantalla, y el `Row` de botones encima con cajas GEMELAS de
110 px (`SizedBox` fijo + `expands`) ancladas a los bordes. El «Atrás»
conserva su `AnimatedOpacity` de v21.4 (desaparece en el slide 1 sin
mover nada).

**Verificación**: test de bienvenida existente pasa (avanza slide por
slide, país, «Comenzar»); geometría centrada por construcción.

## E-02 · Falta de separación entre las opciones de tasas (3er slide)

**Síntoma** (dueño): «Tercera pantalla: falta de separación visual entre
las opciones de tasas».

**Causa**: `CategoryLegend` pintaba las 4 filas con solo 5 px de aire
vertical y ningún divisor — a 390 px se leían como un bloque pegado.

**Fix**: leyenda reescrita — cada opción es una fila de 9 px de aire con
punto de COLOR (la muestra del código de colores v34: verde · rojo ·
naranja · morado), nombre en la tinta del tipo, ejemplos en 11 y hairline
separador entre filas.

## E-03 · Falta la bandera de Estados Unidos en Global / USD

**Síntoma** (dueño): «Cuarta pantalla: falta la bandera de Estados
Unidos en Global / USD».

**Causa**: `_CountryChip` usaba `Icons.public` para `Country.US`
(«USD no tiene bandera de país», v19) — pero el dueño quiere la bandera
estadounidense y el asset `assets/flags/us.png` YA existe (lo usa el
`Flag(Currency.usd)` en toda la app).

**Fix**: TODOS los chips usan `Flag(country.currency)` — US pinta la
bandera de EE. UU. Chips a 40 px de alto con bandera de 16.

## E-04 · El indicador de tiempo no se refresca tras actualizar a mano

**Síntoma** (dueño): «El indicador de tiempo de actualización no se
refresca correctamente tras una actualización manual, mostrando “hace 9
horas” (en todos lados es así)».

**Causa raíz**: el sello pintaba `RateEntry.updatedAt` — la fecha de
PUBLICACIÓN de la API (BCV publica la tasa 1 vez al día: 9 horas es la
edad real del dato publicado). Refrescar a mano trae el mismo valor con
la misma fecha → el sello jamás se movía. El reloj correcto para «hace
X» ya existía en el modelo: `RateBoard.fetchedAt` («reloj al recibir,
para “hace X min”») pero ninguna UI lo usaba.

**Fix**: todos los sellos de frescura (Inicio `_RateCard`, filas de
Tasas, `_freshnessOf` de la hoja de fuentes, `frescura` del Conversor)
usan `board.fetchedAt ?? updatedAt`. Las fuentes MANUALES conservan su
propio reloj (`updatedAt`/«tu tasa manual»). Tras un pull-to-refresh
exitoso el sello dice «hace instantes».

## E-05 · Icono del interruptor de tema desalineado (ambos modos)

**Síntoma** (dueño): «El icono dentro del interruptor de cambio de tema
aparece desalineado y no centrado» — en claro y oscuro.

**Causa raíz** (F-01, propio): `VeIconBtn` fuerza `width: size` (40) en
`_VeRawButton`, cuyo `Row` interno tiene `MainAxisAlignment.start` — el
glifo de 18 px quedaba PEGADO A LA IZQUIERDA de la caja de 40 con 11 px
muertos a la derecha. No era óptico: era geométrico, y afectaba a TODOS
los botones de icono de la app (avisos, tema, ajustes, escáner, flechas
de orden...).

**Fix**: `VeIconBtn` pasa `mainAxisAlignment: MainAxisAlignment.center`
— el glifo queda centrado en su caja en ambos brillos.

## E-06 · Conversor: notas fuera, selector liviano, swap roto

**Síntomas** (dueño): «Se sugiere eliminar la función de notas en
conversiones. Corregir la interfaz de la tasa para mostrar solo el
nombre y fecha de actualización, evitando saturar el espacio. El botón
de intercambio (flechas) presenta un fallo visual de corte y debe
rediseñarse para parecer un botón funcional».

**Fix**:
- Notas retiradas: `_notesCtrl`/`_notesSave` fuera del estado, la fila
  inline fuera del `_DualInput` (los métodos `readConversionNotes`/
  `writeConversionNotes` del store quedan para compatibilidad de prefs).
- Selector: nombre (17, w800, COLOREADO por tipo) + fecha de
  actualización — la línea «1 USD = X Bs · hace X» se retiró; el
  resultado ya vive en los campos gemelos.
- Swap: caja circular 44×44 delineada (borde line-strong) con superficie
  OPACA de tarjeta — el hairline de fondo muere detrás del botón y se
  lee tocable; la rotación 180° de v23.3 sigue intacta.

## E-07 · Código de colores por tipo de tasa en toda la UI

**Síntoma** (dueño): «Aplicación de código de colores por tipo de tasa
en toda la interfaz (verde para oficiales, rojo para informales/paralelo,
anaranjado para promedio y morado para manuales) y eliminación de
etiquetas secundarias para mantener la consistencia visual y
accesibilidad».

**Fix** (la semántica ya existía en `VeInk` — pos/neg/warn/manual — solo
faltaba ponerla a mandar):
- `RateTile` (hoja de fuentes): nombre en la tinta de su categoría;
  fila activa con DIFUMINADO del color (gradiente 16 %→2 % de izquierda
  a derecha) + barra de acento de 3 px a la izquierda; sin sello de
  palabra — bajo el nombre vive SOLO la fecha o el hint de acción.
- Inicio `_RateCard`: nombre solo y coloreado («BCV», «Paralelo»).
- Tasas: filas propias (`_CustomRateRow`) en morado manual.
- Conversor: selector con el nombre coloreado + difuminado del mismo
  color cuando hay tasa.
- `SourceSeal`: queda SOLO el icono de color (13 px) — la palabra vive
  en `Semantics` para el lector de pantalla (accesibilidad intacta).
- `CategoryLegend`: reescrita como leyenda del código de colores (E-02).

## E-08 · «Tu mes» y «Actividad reciente» en tarjetas separadas

**Síntoma** (dueño): «Se recomienda organizar las secciones “Tu mes” y
“Actividad reciente” en tarjetas separadas, asegurando una correcta
centralización y jerarquía visual de los elementos internos».

**Fix**: nueva `_HomeCard` (superficie + hairline + radio 16 — la misma
piel del héroe) envuelve cada sección; los estados vacíos se CENTRAN
(icono, título, texto y salida en el mismo eje óptico) y la jerarquía
interna es rótulo → cifra display 30 → detalle 11.

## E-09 · Reescritura completa: Bienvenida, Ajustes y Sala en Vivo

**Síntoma** (dueño): «Reescribe completamente la GUI de Bienvenida,
Ajustes y Sala en Vivo».

**Fix**:
- **Bienvenida**: reescrita (E-01/E-02/E-03) — además los pilares del
  «Lo que hace» viven en tarjetas delineadas con icono en tile tintado,
  título 17 y cuerpo 13.5.
- **Ajustes**: cada sección (Cuentas y cobro · Tasas y fuentes ·
  Alertas · Diagnóstico · País y decimales · Datos y conexión ·
  Apariencia · Respaldo · Acerca de) vive en su PROPIA tarjeta
  `_AjustesSeccion`: icono en tile tintado 34 px + título 17 + pista 11
  + contenido. Toda la lógica (H-42/H-43) intacta — solo cambió la piel.
- **Sala en Vivo**: el lobby en tarjetas `_SalaCard` — «Cómo se
  conectan», «Tu intención» (con los flujos Unirme/Crear dentro) y
  «Salas cercanas» (con «Escuchar/Parar» en el encabezado); la sección
  del servidor propio también en tarjeta. Anclas de tests
  (`lobby-crear`, `lobby-cercanas`) y flujos P2P intactos.

## E-10 · Lista: rejerarquización y tamaños

**Síntoma** (dueño): «A la Lista necesita una reconfiguración o una
mejor jerarquización de los elementos, y sus tamaños necesitan mejor
corrección».

**Fix**: nueva jerarquía de arriba a abajo — título → **total** (héroe)
→ **captura** (alta rápida + tarjeta de detalle, lo que se hace todos
los días, ANTES vivía tras 5 bloques de configuración) → **lista viva**
(carrito + vaciar) → cálculos → presupuesto → Modo Cachea → puertas
(Sala en vivo + Historial agrupadas en un solo bloque con hairline).
Separaciones uniformes de 14 px entre bloques y anclas del tour
conservadas.

---

## Verificación

- `flutter analyze`: 0 errores · 0 avisos (72 infos de deprecación
  `material.dart` son del SDK 3.50 local; el CI usa 3.47.4 donde no
  existen).
- Suite completa: verde (ver CHANGELOG).
- Contrato AGENT.md: sin `AppStateScope`/`ServiceWorker`/`localStorage`
  en `lib/`; los dobles siguen en `test/`.
