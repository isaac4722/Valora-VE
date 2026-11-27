# HALLAZGOS — v1.1.0-dp4-paridad · v28 «Reglas globales del dueño»

Registro de hallazgos del ciclo EGM (Elephant-Goldfish Model) ejecutado sobre
la rama `v1.1.0-dp4-paridad`. Fase 1 = auditoría «Goldfish» (memoria fresca,
sin heredar supuestos); Fase 3 = corrección «Elephant» con contexto completo.
Cada hallazgo lista su estado: **CORREGIDO** en esta rama, **YA OK** (el
código ya cumplía) o **DECISIÓN** (interpretación documentada).

## Fase 0 — Preparación

- **EGM**: identificado e instalado. Es el plugin open-source
  `google/elephant-goldfish-model` (egm.dev). En este entorno no hay CLI de
  Claude Code/Codex, así que la instalación equivale a obtener el plugin y
  aplicar su flujo nativamente: borrador con contexto completo (Elephant) +
  revisores con memoria fresca (Goldfish). Fuente clonada en
  `/home/z/my-project/egm` y sus modos (`egm-draft`, `egm-review`,
  `egm-resolve`) aplicados al ciclo. — **OK**
- **Flutter SDK** instalado para el gate local (analyze + test + build web).

## Fase 1 — Auditoría Goldfish (hallazgos sobre el código previo)

### Textos
1. **H-1 · Recortes «…»** — 85 usos de `TextOverflow.ellipsis` en 31 archivos
   (montos, nombres de tienda, hints de secciones, etc.). — **CORREGIDO**:
   barrido mecánico (scripts/sweep_ellipsis.py): 77 textos envueltos en
   `FittedBox(scaleDown)` (una línea que escala, jamás «…»), literales cortos
   sin truncamiento y 4 `DefaultTextStyle` corregidos a mano. Quedan **0**.
2. **H-2 · 23 tamaños de texto distintos** — 490 declaraciones `fontSize`
   con valores 9.5 a 42. — **CORREGIDO**: sistema de **4 tamaños canónicos**
   (`VeType` en core/theme.dart): caption 11 · body 13.5 · title 17 ·
   display 30. Barrido en los 47 archivos: el inventario final de `lib/` es
   EXACTAMENTE {11, 13.5, 17, 30}.
3. **H-3 · Rótulos por debajo del piso legible** (9.5-10.5 px). —
   **CORREGIDO**: piso `labelCaps` subido a 11 (caption).

### Envío de información
4. **H-4 · Texto compartido por el share nativo** (6 puntos: totales de
   Lista, resultado del Conversor, constancia, respaldo JSON, CSV histórico,
   mensaje de cobro) → abría el menú del sistema con opciones «enviar
   texto». — **CORREGIDO**: regla de dos vías. **Compartir** solo para
   archivos (PNG/JPEG/PDF, sin texto adjunto: el menú del sistema ya no
   ofrece enviar texto); **Copiar** para todo texto (portapapeles + aviso).
   `export_sheet.dart` reescrito con `ExportKind {archivo, texto}` y
   `ExportMode {compartir, copiar, guardar}`; el botón «Compartir» de texto
   en Pago Móvil se retiró («Copiar mensaje» a todo lo ancho).
5. **H-5 · Ticket compartido con texto adjunto** (JPEG + caption). —
   **CORREGIDO**: viaja solo el archivo.

### Interfaz
6. **H-6 · Iconos descentrados en su caja** — el `Stack` de `VeIconBtn`
   alineaba por defecto `topStart`: el icono quedaba arriba-izquierda de su
   botón. — **CORREGIDO**: `alignment: Alignment.center`.
7. **H-7 · Botones «ghost» = texto plano** — no se distinguían de texto no
   clicable. — **CORREGIDO**: hairline de borde en ghost y secondary
   (botón delineado identificable); en el Inicio los accesos rápidos ya
   tenían caja propia.
8. **H-8 · Sobrecapas** — 3 `PopupMenuButton` flotantes (cuentas, fuentes
   por módulo, sala viva) + tips contextuales (coach marks sobre contenido)
   + tour automático de 12 pasos al abrir. — **CORREGIDO**: menús → acciones
   inline de icono (cuentas, sala) o hoja inferior unificada
   (`showVeHalfSheet`, selector de fuente); motor de tips `no-op` y tour
   automático desactivado (marca el flag y no se muestra). El overlay
   invisible de `renderOffstagePng` (x=-4000, solo para rasterizar
   documentos) se conserva: nunca es visible ni captura navegación.
   Investigación aplicada (web): separar con espacio/hairline/tipografía y
   preferir hojas inferiores/inline sobre capas flotantes (NN/g jerarquía
   visual; «stop putting everything in a card»).
9. **H-9 · Fila de tasa sin affordance** — las filas planas v25 leían como
   texto. — **CORREGIDO**: chevron al final de toda fila clicable
   (`RateTile`), pista 44 px intacta.

### Datos y formato
10. **H-10 · Símbolo ANTES del número** — `fmtCurrency` producía «$ 915,38»
    y el Conversor pintaba el símbolo a la izquierda del monto. —
    **CORREGIDO**: «915,38 $» / «10.000,00 Bs» (punto=miles, coma=decimales,
    ya nativo del formato es-VE) y símbolo tras el campo de monto.
11. **H-11 · Refresco al entrar / offline** — arranque ya refresca
    (`refreshNow()` + `startAuto()` post-frame; `resumed` → `refreshNow()`)
    y sin red sirve la última versión guardada (Hive, offline-first v17.8).
    — **YA OK** (verificado, sin cambios).

## Fase 3 — Inicio (Parte 2a)

12. **H-12 · La tasa se leía como «922,5637 USD»** — el héroe mostraba el
    número de Bs por USD con etiqueta «USD»: error de información. —
    **CORREGIDO**: equivalencia explícita **«1 USD = 922,5637 Bs»** con el
    «=» como pieza gráfica en tinta primaria y símbolo al final.
13. **H-13 · Gráfica (sparkline 14 días) en el Inicio**. — **CORREGIDO**:
    retirada (la serie de 7 días sigue disponible en Tasas).
14. **H-14 · Paralelo en pequeño + brecha** (mini-stats). — **CORREGIDO**:
    eliminados; no queda ningún otro dato en la tarjeta.
15. **H-15 · Nombre de tasa duplicado** — badge «OFICIAL» + «BCV» + nombre
    completo debajo («Banco Central de Venezuela»). — **CORREGIDO**: UNA
    sola forma «BCV · Oficial» (label + categoría en la misma línea; la
    palabra «Oficial» siempre presente en oficiales).
16. **H-16 · Una sola moneda + moneda por defecto configurable** — la
    tarjeta ya usaba la fuente activa del país (BCV por defecto, cambiada
    desde Ajustes → Tasas). — **YA OK** + composición VS/% rediseñada:
    `VS | ▲/▼ +x,x % ayer` con el badge de tendencia del sistema.

## Fase 3 — Tasas (Parte 2b)

17. **H-17 · Las dos categorías (USD/EUR) se confundían** — encabezado
    pequeño con hint «1 USD = X» y no se entendía dónde terminaba cada
    sección. — **CORREGIDO**: secciones con las cuatro partes en orden —
    TÍTULO (bandera + «USD · Dólar», title 17) → DESCRIPCIÓN de una línea
    («Cuánto vale 1 USD. Toca una fila para usarla.») → DETALLES (filas con
    hairlines: la información importante) → ACCIÓN («Configurar fuentes»,
    botón delineado) — separadas por **espacio en blanco + hairline** y sin
    una sola caja contenedora (investigación web: tipografía/escala y
    whitespace para separar; nada de cajas dentro de cajas).
18. **H-18 · «TUS TASAS» flotaba sin contexto**. — **CORREGIDO**: sección
    propia «Tus tasas» con el mismo patrón.

## Fase 2 — Herramientas

19. **H-19 · Skills exigidas instaladas** en `.agents/skills/` vía
    `npx skills add` (mecanismo canónico del repo, `skills-lock.json`
    actualizado): `flutter-unslop` (MBotirjonDev), `unbland`
    (yadavpatle), `anti-slop-design` (Ferousco-dev). Sus reglas se aplicaron
    en la revisión (sin gradientes/colores duros nuevos, tokens del sistema,
    jerarquía 1-a-3, sin tells de slop). — **OK**
20. **H-20 · REA** — CLI `rea-agents` **6.10.1** instalada y operativa
    (versión usada por el repo en v27.1 para el APK de CalculaYa). El modo
    MCP no puede inyectarse al asistente desde dentro de este sandbox: para
    vincularlo al agente del dueño, `npx rea-agents setup` en su equipo.
    — **OK con nota**.

## Tests

- Suite completa: **329/329 verdes** (`flutter analyze` sin incidencias
  nuevas; 68 infos de deprecación preexistentes del SDK 3.50 local vs CI
  3.47.4).
- Tests actualizados al nuevo contrato (estructura v28, no debilitados):
  `rate_sheet_test` (secciones), `custom_rates_test` («Tus tasas»),
  `tips_test` y `widgets_test` (sobrecapas retiradas: NUNCA aparecen),
  `fmt_test` (+3 tests del símbolo tras el número).
- Gate visual (web 390×844): Inicio, Tasas y Conversor verificados — sin
  recortes, jerarquía correcta, sin overlays.

## Revisión Goldfish (EGM · egm-review) y resolución

Dos revisores con memoria fresca (solo requisitos + código, sin el contexto
de la conversación) auditaron la implementación. Hallazgos y resolución:

**Parte 1 (reglas globales)**
- R-P1 · Prefijo «Bs» antes del número en la Constancia (pantalla, PDF y
  texto exportado) → **CORREGIDO**: «X Bs» en los tres puntos.
- R-P2 · Dos ternarios de tamaño fuera del sistema (Conversor «≈»
  12/10.5 · StatementRow 22/15) → **CORREGIDO**: 13.5/11 y 17/13.5.
  Los glifos de marca (LogoMark, iniciales de banco) se documentan como
  marcas gráficas dentro de caja fija, no texto del sistema.
- R-P3 · Dos filas clicables sin affordance (Historial y registros de
  producto) → **CORREGIDO**: `showChevron: true`.
- R-P4 · Icono de accesos rápidos 20 px fuera de escala → **CORREGIDO** a 17
  (escala title, centrado en su caja circular). Los iconos de la barra de
  navegación se documentan como chrome de plataforma (DECISIÓN).
- R-P5 · Motores de tour/tips sin llamadores (código muerto) → **DECISIÓN**:
  se conservan dormidos con el catálogo intacto (reactivables por el dueño);
  el tile de Ajustes explica el retiro.
- Comentarios con tamaños viejos (10.5/9.5) → **CORREGIDOS** a 11 px.

**Parte 2 (Inicio y Tasas)**
- R-Q1 · Sin test del nuevo héroe → **CORREGIDO**: `test/v28_test.dart`
  (3 tests: equivalencia+nombre+VS con dato, NUNCA gráfica/paralelo/brecha,
  fallback honesto sin NaN).
- R-Q2 · `RateGroupHeader` muerto tras la refactor → **CORREGIDO** (retirado
  y doc de la librería corregido).
- R-Q3 · Botón «Tasa manual» muerto para país Global/USD → **CORREGIDO**:
  solo se muestra si la fuente manual existe (bug de borde pre-v28).
- R-Q4 · Héroe alineado al centro → **CORREGIDO**: `CrossAxisAlignment.
  baseline` — cifra, «=», «1 USD» y «Bs» comparten línea de base.
- R-Q5 · Sección EUR sin acción → **CORREGIDO**: «Configurar fuentes»
  también en EUR («Tus tasas» mantiene sus filas como acción directa;
  DECISIÓN: no se añade botón decorativo).
- R-Q6 · Nombre compuesto podría duplicar palabra (fuente EUR) →
  **CORREGIDO** con guard `contains`.
- R-Q7 · Hairline de VS sobraba sin dato → **CORREGIDO**: separador visible
  solo con badge.

Reverificación tras resolver: `flutter analyze` sin incidencias nuevas
(69 infos de deprecación del SDK 3.50 local; CI 3.47.4 no las emite),
**332/332 tests** verdes, gate visual web reejecutado.
