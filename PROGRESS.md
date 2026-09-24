# PROGRESS.md · HOT — turno activo (o el último cerrado)

Una línea por pieza: `YYYY-MM-DD · estado · pieza · gate · route`.
Máx ~10 líneas. Al cerrar el turno: las líneas bajan a `progress_warm.md`
(rotación del contrato). Sin prosa, sin justificaciones. Solo se AÑADE.
Si no hay turno activo, el último cerrado está al final de `progress_warm.md`.

2026-09-23 · DONE · TASK-30 contrato+docs+bitácora+skills+gate completos · CI+Build verde sobre 4e69f13 · FIN
2026-09-24 · DONE · TASK-31 rama remota renombrada safe/v1.1.0-dp4-paridad (antes fix/…; orden dueño: red de seguridad) + refs vigentes (GIT_WORKFLOW, FLUTLAB, ci.yml, build.yml) · n/a · 7_PERSIST
2026-09-24 · DONE · TASK-31 skills del contrato 10/10 en .agents/skills + rtk 0.50.0 instalado (init --global) + SKILL.md leídos (rtk, caveman) + comandos vía rtk · n/a · 7_PERSIST
2026-09-24 · DONE · TASK-31 rebuild en rama safe: pub get + analyze 0 + test 196/196 + quality_gate VERDE · gate verde · 5_CONTROL
2026-09-24 · BLOCKED · TASK-31 npx skills add sin red ×2 → skills-lock.json sin refrescar (61 skills vendidas intactas; hashes del lock viejos) · n/a · 9_CLOSE
