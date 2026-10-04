# PROGRESS.md · HOT — turno activo (o el último cerrado)

Una línea por pieza: `YYYY-MM-DD · estado · pieza · gate · route`.
Máx ~10 líneas. Al cerrar el turno: las líneas bajan a `PROGRESS_WARM.md`
(rotación del contrato con `tools/rotar_bitacora.sh`). Sin prosa, sin
justificaciones. Solo se AÑADE.
Si no hay turno activo, el último cerrado está al final de `PROGRESS_WARM.md`.

2026-10-02 · DOING · TASK-35 abre turno — GUI correcta: notch/SafeArea en todas las superficies, techo en menús/sheets, Sala al lenguaje Ve del prototipo, toggle de tema en cabecera · docs-news reintegrados a nivel contenido (AGENT.md + bitácoras canónicas + skills-lock) · gate n/a · 3_IMPLEMENT
2026-10-02 · DONE · repaso docs — consolidación new-docs aplicada (a1c3ad8: retiro de 11 .md, DESIGN-SYSTEM preservado) + referencias huérfanas corregidas en AGENT/README/MVP-CRUD y nombres de bitácora normalizados · CI verde · 9_CLOSE
2026-10-02 · DONE · repaso docs 2 (orden del dueño) — docs/ retirado al 100% (DESIGN-SYSTEM.md a historial git) y referencias de AGENT/README/MVP-CRUD re-dirigidas al código canónico (shad_theme/theme/ui.dart) · CI verde · 9_CLOSE
2026-10-03 · DONE · v20.4 auditoría de paquetes — fotos de ticket a ARCHIVO (JSON en KB, migración única), IsolatedHive+INS (app y worker, sin corrupción de cajas), uuid v4 en newId, csv RFC 4180 (6.x por Dart 3.9), talker 100% local + visor en Diagnóstico, syncfusion RETIRADO (6 gráficos + donut → VeTimelineChart/VeBars/VeDonut), allowBackup=false para el token del relay · gate CI · 8_CI
