# HALLAZGOS — v1.1.0-dp4-paridad · v31 «Revisión integral + exportación profesional + solo APKs»

Registro del ciclo de revisión integral ordenado por el dueño («verifica
todo el trabajo desde la Fase 0, corrige, mejora PDF/imágenes, solo APKs,
tareas programadas, documenta»). Continúa el ciclo v28 (presente en el
remoto) y **recupera v29/v30, que se perdieron**: el sandbox que ejecutó
aquellos ciclos se recicló y su trabajo NUNCA llegó a GitHub — la punta de
la rama estaba en v28 (commit 7dc0265) mientras la documentación local
(HALLAZGOS_v29/v30) describía código que ya no existía.

## Fase 0 — Diagnóstico de la revisión integral

- **H-45 · v29/v30 perdidos** (hallazgo mayor): la rama remota contenía
  v28; las Partes 3, 4 y 5 vivían solo en docs. — **CORREGIDO**:
  re-implementación completa desde la especificación documentada
  (HALLAZGOS_v29/v30 como spec maestro), ciclo por ciclo, con la suite
  como gate en cada paso (332 → 351 → 349 → 369 verdes).
- EGM operativo (Fase 0 del encargo original): skills de Fase 2 en
  `.agents/skills/` verificadas (flutter-unslop, unbland, anti-slop-design
  + el catálogo del repo); flujo Goldfish→Elephant aplicado en cada
  reconstrucción con la especificación como revisor.

## Reconstrucción v29 — Parte 3 (Conversor) y Parte 4 (Lista)

- Parte 3 completa (H-21..H-30 + V-1..V-4 + R-29a..R-29e): título solo,
  fecha con protagonismo **Ayer · Hoy · Mañana · Fecha** («Mañana» = cobro
  planificado con la tasa viva), campos gemelos con símbolo en ambos
  lados, selector de tasa obvio, atajos eliminados (teclado única vía, ⌫
  largo limpia), precisión UNA escala X,XX·X,XXX·X,XXXX·Completo con clamp
  2..6 en los tres sitios, **regla del 0 del swap** (vacío entra, vacío
  sale — verificado por controladores, no por find.text), Fuentes/Tabla/
  Recientes fuera y Notas inline, Pago Móvil con puerta ante cualquier
  cambio del par con VES (Compartir = imagen, Copiar = texto), patrón
  calculadora sin scroll en 390×844 y píldora del segmented clavada a su
  casilla (H-44: fórmula 2i/(n−1) con guarda).
- Parte 4 completa (H-31..H-38 + V-1/V-2 de v30): barra pegadiza en
  `Scaffold.bottomNavigationBar` en Lista/Productos/Historial (antes TAPABA
  los campos de captura), tarjeta del valor grande con FittedBox,
  presupuesto en UNA línea, CÁLCULOS DE LA LISTA con selector de tasa
  grande, captura qué·cuánto·dónde, plantillas y toggle «más» eliminados
  (respaldos viejos con la clave la ignoran), Sala en vivo con entrada
  propia y sala reconstruida en lenguaje de secciones.

## Reconstrucción v30 — Parte 5 (Análisis · Más · Ajustes)

- Análisis (H-39/H-40): CUATRO secciones — Divisas · Inflación · Canasta ·
  Gastos — barra segmentada de 44 px con rango SOLO donde se usa;
  «Tasa» y «Productos» eliminados (duplicados); CurrencyRanking emigró a
  Gastos; WeekdayRanking retirado; tour a las 4 secciones.
- Más (H-41): solo Productos · Tickets · Ajustes · Actualizaciones ·
  Privacidad y licencias; `/escanear` fuera del router (el escáner vive
  donde se usa; el atajo del launcher entra a Lista y pide el escáner).
- Ajustes (H-42/H-43): UNA pantalla por secciones (rutas viejas
  redirigen; solo `/ajustes/cuentas` sobrevive), cuentas con `kind`
  (pago móvil = banco+cédula+teléfono; transferencia = banco+tipo+número
  20+cédula; zelle = titular+email/teléfono US), `dataLines` única fuente
  para fila/copiado/mensaje/tarjeta, migración de respaldos sin pérdida,
  validación AND por tipo con feedback (R-30a..R-30h resueltos).

## Parte PDF e imágenes (el encargo nuevo de v31)

- **H-46 · Dos escalas de rasterizado incompatibles** — las tarjetas de
  marca se maquetaban a 1080 px LÓGICOS con fontSize 30: el texto de la
  imagen final medía 30 px (diminuto); la constancia, en cambio, se
  renderizaba a 380 lógico ×3. — **CORREGIDO**: convención ÚNICA — todo
  documento compartible se compone a **360 px lógicos** (el papel de
  teléfono, con la tipografía real de la app 11·13,5·17·30) y se
  rasteriza a **pixelRatio 3 → 1080 px**. Tarjetas recompuestas a esa
  escala (héroe display 30 → 90 px en la imagen). Verificado por tests
  que miden el IHDR del PNG real: conversor 1080×1080, pago móvil
  1080×1080, constancia 1080×1350.
- **H-47 · El PDF de la constancia estaba ROTO en producción** —
  `pw.Row(crossAxisAlignment: stretch)` con varios hijos dentro de
  `MultiPage` mide ALTURA INFINITA con este paquete pdf (la excepción
  «Widget won't fit» mataba doc.save()). El patrón venía de v17.2 y jamás
  tuvo test. — **CORREGIDO** (crossAxisAlignment.start + Column
  mainAxisSize.min) y ahora tiene test de regresión.
- **H-48 · PDF sin identidad ni paginación** — Helvetica por defecto,
  márgenes 36/40/36/36 desiguales, cero números de página, el pie solo en
  la última hoja. — **RECONSTRUIDO** (`constancia_pdf.dart`, módulo
  público): **fuentes de marca embebidas** (Inter + SpaceGrotesk vía
  `VePdfFonts`, carga cacheada y degradación honesta a Helvetica si el
  asset falla), **márgenes uniformes 44 pt** (~15,5 mm), **encabezado de
  marca en TODAS las páginas** (logo + ValoraVE + alcance), **pie en
  todas** (sello de generación + «Página n»), tabla con cabecera repetida
  al saltar de página y filas alternas. Test de paginación real: 60
  tiendas → varias hojas.
- **H-49 · Constancia PNG sin 4:5 real** — el header prometía
  1080×1350 pero la altura era la del contenido (cualquier cosa).
  — **CORREGIDO**: lienzo fijo 360×450 (`constanciaPngCanvas`) → 1080×1350
  EXACTO; el MISMO widget sirve de preview (responsivo) y de fuente del
  PNG (repartido) — sin Spacer/minHeight, que rompían en contenedores de
  altura no acotada (ListView/Overlay).
- **H-50 · Manejo de errores sin tratar** — share/guardar/imprimir sin
  try/catch: un fallo de canal nativo mataba el flujo en silencio.
  — **CORREGIDO en tres capas**: `pdfFormat` captura fallos de
  generación («No pude generar el PDF»), `showExportSheet` captura
  fallos de share/guardado («No se pudo completar la exportación»), y
  `_printPdf` avisa en cristiano. `sharePdf` nuevo con MIME
  application/pdf (el receptor abre documento, no imagen).
- **H-51 · DOS tuberías de render gemelas** — `renderSharePng`
  (Overlay propio) y `renderOffstagePng` (otro Overlay) podían divergir;
  la segunda tenía un cast ciego (`as RenderRepaintBoundary?`) que
  reventaba con keys compuestos. — **CORREGIDO**: UNA sola tubería
  (`renderSharePng` delega), boundary buscado SUBIENDO por el árbol,
  espera de frames ACOTADA (3 máximo; jamás cuelga) y overlay retirado
  SIEMPRE (finally). `Overlay.maybeOf` en vez de `of` (sin crash fuera
  de árbol).
- Tarjeta de pago móvil: filas de datos en patrón recibo (rótulo
  izquierda · valor derecha con FittedBox) — con transferencia + fecha
  planificada llegan a 5 filas y la tarjeta cuadrada NUNCA desborda.

## Builds — solo APKs (orden del dueño)

- **H-52 · El AAB ya no se genera** — el workflow `build.yml` producía
  4 APK + AAB + ZIP con los 5 binarios. — **CORREGIDO**: job `aab`
  retirado por completo; el paquete lleva SOLO los 4 APK (1 universal +
  arm64-v8a + armeabi-v7a + x86_64), el LEEME y los checksums sin AAB, y
  la Release (tags) adjunta 4 APK + ZIP. Ningún binario del canal es no
  instalable. Matriz anti-SIGTERM intacta.

## Tareas programadas

- Revisadas: el único job activo del usuario es el keepalive del dev
  server del «Detector de IA» (otro proyecto, otra sesión) — corre bien
  (9 ejecuciones, última exitosa) y NO se toca. ValoraVE no necesita
  tareas programadas: el CI construye en cada push y la app refresca
  tasas al entrar.

## Tests

- Suite completa: **380/380 verdes** (369 de la reconstrucción + 11
  nuevos de `test/export_pdf_test.dart`: fuentes de marca, PDF válido con
  paginación real, cero compras sin morir, errores en cristiano de
  pdfFormat, dimensiones EXACTAS de los tres PNG compartibles leídas del
  IHDR del archivo real).
- `flutter analyze`: 0 errores; solo infos de deprecación pre-existentes
  del SDK 3.50 local (CI usa 3.47.4).
- Inventario de tipografía en lib/: SOLO {11, 13.5, 17, 30} (+ helpers
  parametrizados del sistema y el PDF a la misma escala);
  `TextOverflow.ellipsis` en lib/: **0**.

## Validación en el remoto (cierre del ciclo)

- **CI** (Flutter 3.47.4): VERDE en `9ed2975` — gate analyze 0 + suite +
  auditoría de prohibiciones. (Un primer push paró en 2 warnings de
  imports muertos que el SDK 3.50 local enmascaraba entre sus infos de
  deprecación; corregidos al momento — el gate hizo exactamente su
  trabajo.)
- **Build** (solo-APK, `9ed2975`): VERDE. Artefactos del run 45753624576:
  4 APK (`valorave-v1.18.0-beta-build-20261126-arm64-v8a.apk` 32,8 MB ·
  `armeabi-v7a` 29,3 MB · `x86_64` 35,6 MB · `universal` 84,3 MB) + ZIP
  todo-en-uno (89,8 MB) + símbolos de ofuscación. **El paquete contiene
  EXACTAMENTE los 4 APK + LEEME + checksums — cero .aab** (verificado en
  el listado del job `paquete` y en los logs: 0 menciones).
- Rama `v1.1.0-dp4-paridad` al día: `9ed2975` (docs: `HALLAZGOS_v31.md`,
  CHANGELOG v29/v30/v31, pubspec 1.18.0-beta+54, visible 31).
