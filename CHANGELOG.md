# Changelog

## v33 — Revisión Goldfish de textos y documentación

Ciclo de corrección ordenado por el dueño («busca cualquier error o mala
escritura y arréglalo; verifica que todo esté completo; deja solo main y
la dp4»). Cinco revisores sin contexto (EGM Goldfish) auditaron README,
GUIA, contrato, verdad funcional, bitácoras, CHANGELOG completo y strings
de la UI; el elefante verificó cada hallazgo contra el código y ejecutó.
Registro detallado en `HALLAZGOS_v33.md`.

- **UI (13 strings con errores)**: «Nombre y precio válidos» (×4),
  «Zona de peligro», «desde hace más de 15 min» (banner de salud),
  «Antiácido en pastillas» (semilla; «Antiacídico» no existe),
  «Aparecen en Tasas con sus brechas», «Ya están en el libro» (×2); CSV
  con encabezados con tilde — «Código», «Categoría», «Día» — e
  importador que acepta AMBAS grafías (los CSV viejos sin tilde siguen
  entrando; test de brecha actualizado en par con el código).
- **README al día con la realidad v31/v32**: sin AAB (4 APK + ZIP con
  LEEME y checksums), descarga enlazada a /latest (decía «Release
  v1.0.2-beta»), CUATRO transportes de Sala (faltaba el Bluetooth
  clásico), módulo Más sin buscador y con 5 destinos, Ajustes como una
  pantalla por secciones, Conversor sin fichas 1-100.
- **MVP-CRUD (verdad funcional) actualizado**: §4 con la política solo-APK
  de v31 (antes ordenaba conservar el AAB), §4.10 con los 4 transportes,
  §2 con las 15 claves AppData, §8 sin `shad_theme.dart` (el archivo no
  existe) y sin RateTicker (retirado en v26), §9 al día (8 rutas del
  shell, Análisis en 4 secciones, Ajustes v32, Conversor v29).
- **AGENT.md y catálogo de skills**: 67 skills reales (decía 59), sin la
  referencia fantasma a `shad_theme.dart`, skill en femenino consistente
  («regístrala»/«instalarla»), flujo citando AGENT.md (el README de skills
  citaba un WORKFLOW.md inexistente y una carpeta docs/ retirada) y
  procedencia apuntando a `skills-lock.json`.
- **GUIA_DE_LA_APP**: «sin nube» (decía «sin servidores», que chocaba con
  el modo Servidor autoalojado), «antes de romper la línea», precisión
  real del Conversor 2/3/4/«Completo».
- **Bitácora al día**: entradas AÑADIDAS de v25 y v29–v32 (el trabajo
  existía en git pero no en PROGRESS.md), TASK-35 cerrada (su alcance
  quedó absorbido por v23–v32), rotación ejecutada (hot ≤10 líneas,
  CHANGELOG hot 3 versiones) y ortografía de entradas previas
  (APROBADOS, redirigidas, reverificada, CalculaYa).
- **LICENSE**: «PROHIBICIONES EXPRESAS» (decía «EXPRESSAS», portugués) y
  concordancia «incluidos».
- Versión 1.18.0-beta+56 · visible 33.

## v32 — GUI del dueño: soltar las esquinas

Ciclo de GUI sobre el gate visual web 390×844 (orden del dueño: franja
vacía, títulos solos, Cachea bien ubicada, sin lupa en Inicio, iconos
grandes y centrados, Sala de nuevo, Ajustes refactor). Registro detallado
en `HALLAZGOS_v32.md`.

- **Barra pegadiza SIN franja vacía** (G-1): `VeStickyBar` abraza a la
  barra de tabs — ~20 px de papel muerto eliminados en Lista/Productos/
  Historial.
- **Texto jamás microscópico** (G-2): `VeRow.sub` se envuelve en varias
  líneas a 13.5 px reales (adiós FittedBox que encogía los modos de Sala).
- **Títulos SOLOS** (G-3): Lista y Ajustes sin botones al lado del título;
  Historial vive en su fila de entrada gemela de Sala en vivo.
- **Modo Cachea BIEN UBICADO** (G-4): fila delineada a todo lo ancho bajo
  el total — icono, título, explicación, chevron; ya no una píldora suelta.
- **Header de Inicio SIN lupa** (G-5): avisos · tema · ajustes a 40/18,
  centrados contra el saludo.
- **Iconos que se ven** (G-6): `VeIconBtn` 36/17 por defecto; Escáner
  (40/18), Atrás de PushScreen (40/20), Tasas (40/18), orden de divisas,
  acciones de cuenta.
- **Sala separada y centrada** (G-7): código de invitación centrado (mismo
  eje que el QR) y puertas «Unirme/Escanear» gemelas.
- **Ajustes refactor completo** (G-8): un encabezado solo por sección con
  hint, filas planas del kit, switches Material → VeToggle, sliders con
  rótulo completo, zona de peligro sin caja, «Acerca de» en VeGroup.
  Lógica H-43 intacta.
- Verificación: analyze 0 · **380/380 tests** · gate visual verde.

## v31 — Revisión integral + exportación PDF/imágenes profesional + solo APKs

Ciclo de revisión ordenado por el dueño («verifica todo desde la Fase 0,
corrige, mejora PDF/imágenes, builds solo APK, documenta»). Registro
detallado en `HALLAZGOS_v31.md`. Incluye la **recuperación de v29/v30**,
cuyo código se perdió con el sandbox y nunca llegó al remoto.

- **v29/v30 RECUPERADOS**: la punta de la rama estaba en v28; las Partes
  3, 4 y 5 se reimplementaron desde su especificación con la suite como
  gate (332 → 380 tests verdes). Detalle por hallazgo en
  `HALLAZGOS_v31.md` (los `HALLAZGOS_v29/v30` originales se perdieron con
  el sandbox; su especificación quedó reconstruida ahí).
- **Exportación PDF/imágenes reconstruida** (`constancia_pdf.dart` +
  `VePdfFonts` + `pdfFormat`): fuentes de marca Inter/SpaceGrotesk
  embebidas (degradación honesta a Helvetica), encabezado de marca y pie
  con «Página n» en TODAS las hojas, márgenes uniformes 44 pt, tabla con
  cabecera repetida al saltar de página, y manejo de errores en tres
  capas (generación / share / imprimir) con mensajes en cristiano.
- **FIX CRÍTICO**: el PDF de la constancia estaba ROTO en producción —
  `Row(crossAxisAlignment: stretch)` dentro de `MultiPage` mide altura
  infinita y mataba `doc.save()`. Regresión cubierta por test.
- **Convención única de rasterizado**: todo PNG compartible se compone a
  360 px lógicos (tipografía real de la app) y se rasteriza ×3 → 1080 px.
  Tarjetas de marca recompuestas (antes: 1080 lógicos con texto diminuto);
  constancia a 4:5 EXACTO 1080×1350 con lienzo fijo; dimensiones medidas
  del IHDR del PNG real en tests.
- **UNA tubería de render** (`renderSharePng` → `renderOffstagePng`):
  boundary a prueba de keys compuestas, espera de frames acotada y
  overlay siempre retirado. `sharePdf` con MIME de documento.
- **Builds SOLO APK**: job AAB retirado del CI — 1 universal +
  arm64-v8a/armeabi-v7a/x86_64; paquete, LEEME, checksums y Release sin
  ningún binario no instalable.
- Tareas programadas revisadas (sin cambios necesarios para ValoraVE);
  versión 1.18.0-beta+54 · visible 31.
