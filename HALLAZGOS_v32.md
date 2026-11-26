# HALLAZGOS — v1.1.0-dp4-paridad · v32 «GUI del dueño: soltar las esquinas»

Ciclo de GUI ordenado por el dueño: barra pegadiza que dejaba una franja
vacía, títulos que no estaban solos, Modo Cachea mal ubicado, lupa en el
header de Inicio, iconos pequeños y descentrados (escáner, atrás), filas
con texto microscópico, Sala por trabajar de nuevo y Ajustes por
refactorizar. EG M operativo (Fase 0/2: skills del repo + flujo
Goldfish→Elephant con la especificación como revisor); gate visual web
390×844 como cierre.

## Diagnóstico (lo que se vio en el gate visual, no solo en código)

- **G-1 · Franja vacía bajo «Cerrar compra · Dividir cuenta»**: la barra
  pegadiza (`VeStickyBar`) sumaba SafeArea mínimo 8 + padding inferior 12
  (~20 px de papel muerto) entre los botones y la barra de tabs — en el
  gate se medía ~35 px de blanco. **CORREGIDO**: la barra abraza a la
  barra de tabs (minimum 0 · padding 10/6). Verificado en captura.
- **G-2 · Texto microscópico en filas**: `VeRow` envolvía el `sub` en
  `FittedBox.scaleDown` — los subtítulos largos (modos de Sala, «Nearby ·
  WiFi-Direct/BLE…») se encogían hasta ~8 px. **CORREGIDO**: el sub
  ENVUELVE a varias líneas a 13.5 px reales (regla del dueño: el texto
  jamás se encoge ni se corta). Verificado en captura de Sala.
- **G-3 · Títulos acompañados**: el título de Lista llevaba el icono de
  Historial al lado. **CORREGIDO**: títulos SOLOS (Lista · Ajustes) y las
  puertas viven en filas de entrada gemelas (Sala en vivo · Historial de
  compras), delineadas, separadas y centradas.
- **G-4 · Modo Cachea mal ubicado**: era una píldora ghost suelta,
  alineada a la izquierda entre la tarjeta del total y el presupuesto.
  **CORREGIDO**: fila delineada a todo lo ancho, gemela de Sala/Historial,
  con icono, título, explicación y chevron; deshabilitada con aviso
  honesto sin carrito.
- **G-5 · Lupa en el header de Inicio**: retirada por orden del dueño
  (su función queda en el sidebar de escritorio ⌘K). Iconos que quedan
  (avisos · tema · ajustes) subidos a 40 visual / 18 glifo, centrados
  contra el bloque del saludo.
- **G-6 · Iconos pequeños y descentrados**: `VeIconBtn` por defecto 32/16
  (se perdía junto a inputs de 44 px). **CORREGIDO**: defaults 36/17, y
  los señalados por el dueño a mano — Escáner de Lista (40/18), Atrás de
  `PushScreen` (40/20), atrás/ajustes de Tasas (40/18), flechas de orden
  en Ajustes (36/15), acciones de cuenta (36/17). El centrado sigue el
  Stack al centro de v28; el glifo ya no parece flotar.
- **G-7 · Sala**: código de invitación alineado a la izquierda contra QR
  centrado. **CORREGIDO**: código y QR comparten eje centrado. Puertas
  «Unirme con el código / Escanear QR» ahora JEMELAS (mismo ancho y
  altura). Modos de conexión legibles (G-2).
- **G-8 · Ajustes**: mezclaba SwitchListTile/ListTile/TextButton de
  Material con dobles encabezados (sección + sub-sección) y cajas dentro
  de cajas. **REFACTORIZADA completa**: un encabezado SOLO por sección con
  su hint, filas planas del kit, `_FilaSwitch` (título + sub + VeToggle)
  sustituye a los switches de Material, sliders con rótulo completo en su
  propia fila, zona de peligro en tinta negativa sin caja, «Acerca de» en
  `VeGroup` de filas del kit. Lógica intacta (H-43 tipos de cuenta,
  validaciones, dataLines).

## Cambios de estructura (contratos vigentes)

- Secciones de Ajustes (v32): CUENTAS Y COBRO · TASAS Y FUENTES · ALERTAS
  · DIAGNÓSTICO DE FUENTES · PAÍS Y DECIMALES · DATOS Y CONEXIÓN ·
  APARIENCIA · RESPALDO · ACERCA DE — una pantalla, cero subpantallas
  (H-42 se mantiene; test actualizado a los nuevos encabezados).
- «Añadir un widget» → «Añadir un widget de Android» (fila de la sección
  Datos y conexión). Test actualizado.

## Verificación

- `flutter analyze`: 0 errores/avisos (solo infos de deprecación del SDK
  local 3.50, pre-existentes; CI usa 3.47.4).
- Suite completa: **380/380 verdes** tras actualizar 2 contratos de test
  (encabezados de Ajustes y etiqueta del widget).
- Gate visual web 390×844 (capturas del ciclo): Inicio sin lupa y con
  iconos grandes; Lista con título solo, gemelas Sala/Historial, Cachea en
  fila propia y barra pegadiza sin franja; Ajustes plano de cabo a cabo;
  Sala con modos legibles y puertas gemelas; código de sala centrado.
