# PROGRESS.md · HOT — turno activo (o el último cerrado)

Una línea por pieza: `YYYY-MM-DD · estado · pieza · gate · route`.
Máx ~10 líneas. Al cerrar el turno: las líneas bajan a `progress_warm.md`
(rotación del contrato). Sin prosa, sin justificaciones. Solo se AÑADE.
Si no hay turno activo, el último cerrado está al final de `progress_warm.md`.

2026-10-01 · DONE · TASK-34 abre turno — GUI prototipo web → Flutter shadcn_ui superior + migración docs safe/docs-news · gate n/a · 2_PLAN
2026-10-01 · DONE · TASK-34 p1 docs: 4 .md de safe/docs-news (CHANGELOG_COLD/WARM + PROGRESS_COLD/WARM) + nota CHANGELOGs en AGENT.md + LICENSE sin legislación (intención del dueño 0adc35c) · gate n/a · 3_IMPLEMENT
2026-10-01 · DONE · TASK-34 p2 tema: tokens EXACTOS del prototipo en theme.dart (zinc :root/.dark, line-strong, faint, pos/neg/warn/info-bg en VeInk, primario tinta invertida fg→bg) · gate analyze 0 · 213/213 · 3_IMPLEMENT
2026-10-01 · DONE · TASK-34 p3 kit Ve: lib/widgets/ve (controls+compose+charts) sobre shadcn_ui real — ShadButton.raw/Badge/Switch/Checkbox/Input/Select con medidas EXACTAS 28/36/44·32×18 (bordes flush sin reserva), VeSegmented deslizante, VeAreaChart con crosshair, VeDonut/VeBars/VeHeatmap, showVeSheet móvil/modal, VeAmbient, JetBrainsMono · gate analyze 0 · 230/230 · 3_IMPLEMENT
2026-10-01 · DONE · TASK-34 p4 shell: sidebar 224px escritorio (marca+⌘K+nav+Libro+pie de tasas en vivo) + tabs móviles planos del prototipo + FAB búsqueda + VeAmbient de fondo; FIX CRÍTICO main.dart → ShadApp.custom+MaterialApp.router (el tipo default montaba WidgetsApp SIN ScaffoldMessenger: toasts rotos) · gate analyze 0 · 230/230 · VLM 6/6 APROBADO · 3_IMPLEMENT
2026-10-01 · DONE · TASK-34 p5-8 pantallas: Inicio (cabecera campana/búsqueda/ajustes + chispa de serie + badges tono), Conversor (display+chips+referencias Ve), Lista (presupuesto con barra tinta/warn/neg + filas checkbox/stepper + sticky checkout), Productos (chips categoría + sparkline + badge estado + ficha sheet wide) · fixes overflow 390px (Wrap compartir, Flexible cartText) · gate analyze 0 · 233/233 · VLM lista/conversor APROBADO · 9_CLOSE
2026-10-01 · DONE · TASK-34 p12 cierre: v1.10.0-beta+30 · visible 20.0 + CHANGELOG rotado + fixes VLM (hint corto) · PENDIENTE próximo turno: p9-11 (Análisis/Historial/Tickets/Ajustes/Bienvenida), push+Actions y borrado safe/docs-news (requieren PAT del dueño) · gate analyze 0 · 233/233 · 9_CLOSE
