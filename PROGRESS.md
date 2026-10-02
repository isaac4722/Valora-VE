# PROGRESS.md · HOT — turno activo (o el último cerrado)

Una línea por pieza: `YYYY-MM-DD · estado · pieza · gate · route`.
Máx ~10 líneas. Al cerrar el turno: las líneas bajan a `PROGRESS_WARM.md`
(rotación del contrato con `tools/rotar_bitacora.sh`). Sin prosa, sin
justificaciones. Solo se AÑADE.
Si no hay turno activo, el último cerrado está al final de `PROGRESS_WARM.md`.

2026-10-02 · DOING · TASK-35 abre turno — GUI correcta: notch/SafeArea en todas las superficies, techo en menús/sheets, Sala al lenguaje Ve del prototipo, toggle de tema en cabecera · docs-news reintegrados a nivel contenido (AGENT.md + bitácoras canónicas + skills-lock) · gate n/a · 3_IMPLEMENT
2026-10-02 · DONE · TASK-35 p1 docs — .md de safe/docs-news reintegrados (AGENT.md nomenclatura canónica, bitácoras sin duplicación, skills-lock 59) · gate verde · 7_PERSIST (3a42ad7)
2026-10-02 · DONE · TASK-35 p2 shell — SafeArea superior global + AnnotatedRegion por tema + TOGGLE claro/oscuro de vuelta (cabecera Inicio y marca sidebar) · gate verde · 7_PERSIST (d5a7a3e)
2026-10-02 · DONE · TASK-35 p3 techos — FIX CRÍTICO showVeSheet (overlay alineado abajo/centrado, techo 88 %), centro de avisos al prototipo, galería snap 0.72/0.85, rate_sheet 80 % · gate verde · 7_PERSIST (f6bb841)
2026-10-02 · DONE · TASK-35 p4 sala — lobby PushScreen lenguaje Ve + hoja UNIRSE 3 pasos (chips · nombre · 6 ruedas) + PIN emojis + InviteSheet a pantalla completa · gate verde · 7_PERSIST (1df489c)
2026-10-02 · DONE · TASK-35 p5 auditoría 390 + VLM — test 10 rutas con notch y fuentes reales (RoomController al harness), VeChip.expands, Historial sin icono en export + sin Expanded doble, Sala descripciones a 3 líneas, Paso X de 3 del prototipo · gate VERDE (analyze 0 · 236/236 · prohibiciones OK) · web+VLM: sheets con techo, toggle funcional, 10 pantallas sin defectos · 7_PERSIST
2026-10-02 · DONE · TASK-35 p6 selector moneda hoja Ve + sellos categoría + sin Ruta/Matriz + dedup día · 237/237 · 8_CI
2026-10-02 · DONE · TASK-35 p7 panel presupuesto entendible + tachado mejorado · 237/237 · VLM APROBADO · 8_CI
2026-10-02 · DONE · TASK-35 p8 showVeHalfSheet media pantalla + snap 0.5→0.95 · 237/237 · 8_CI
2026-10-02 · DONE · TASK-35 p9 subtítulo bajo título + volver siempre + sin lupa móvil · 237/237 · 8_CI
2026-10-02 · DONE · TASK-35 p10 análisis insignias KPI + fix banner DEBUG en goldens · 237/237 · VLM APROBADO · 8_CI
2026-10-02 · DONE · TASK-35 p11 Sala intención Unirme|Crear + escáner QR real (EAN no leía QR) · 237/237 · 8_CI
2026-10-02 · DONE · TASK-35 p12 widgets launcher acento categoría + día/noche + previews · 237/237 · 8_CI
2026-10-02 · DOING · TASK-35 p13 cierre v1.12.0-beta+32 · v20.2 — gate final + push + Actions · gate n/a · 7_PERSIST
