# progress_archive.md · COLD — historial comprimido por hito

Solo hechos, una línea por pieza (`fecha · estado · pieza · gate · route`).
Detalle completo de cada turno: `git log` + `CHANGELOG.md` + el
`progress.md` v1 conservado en la historia git (retirado en v19.9).
Solo se AÑADE; prohibido reescribir entradas.

## Hito 2026-09-10 · Arranque del repo y v1.0.x

2026-09-10 · DONE · TASK-0 arranque repo orfanado: arte+fonts rescatados, releases/tags viejos borrados, server lista-sync 1:1 · gate n/a · FIN
2026-09-10 · DONE · TASK-1..10 construcción completa fases 1-2: spec, design system, scaffold, dominio, pantallas base · gate n/a · FIN
2026-09-10 · DONE · TASK-11 build-fix widget BCV (SharedPreferences directo, sin import del plugin) + integration_test en host · analyze 0 · test 104/104 · build SUCCESS · FIN
2026-09-10 · DONE · TASK-12 release v1.0.0-beta publicada (3 APK + AAB) y firma v2 verificada · release OK · FIN
2026-09-10 · DONE · TASK-13 v1.0.1-beta: fix router (GoRouter único, no recreado) + iconos reales + escáner + sueldo variable · CI verde · FIN
2026-09-10 · DONE · TASK-14 release v1.0.1-beta publicada y verificada byte a byte · release OK · FIN
2026-09-10 · DONE · TASK-15 v1.0.2-beta: paridad contra spec (scorecard ~80-84 %) + bugs de datos (addPurchase id) + diseño §8 + flujos §9 · CI+Build verde · FIN
2026-09-13 · DONE · DOC-AGENT-V2 AGENT.md v2 (ciclo 9 pasos) propagado a todas las ramas · gate docs · FIN
2026-09-13 · DONE · RECHECK-V17.6 auditoría bitácora↔código 100 % aplicado + rondas 1.1.0-dp4/v17.2-v17.6 reconstruidas + versionado restaurado 1.5.0-beta+13 · analyze 0 · test 107/107 · FIN

## Hito 2026-09-13/14 · v17.7 → v18.0

2026-09-13 · DONE · TASK-16 v17.7: ConversionPlan + ruta EUR 4 tramos + Análisis 9.7 (rankings/proyección/heatmap) + biometría + SSE vivo + familia widgets BCV + Ola 1 + reestructura (7 commits) · analyze 0 · test 126/126 · FIN
2026-09-14 · DONE · TASK-17 v17.8: tutorial único (app_tour sobre plugin) + Finanzas fuera + IGTF fuera + offline real (5 commits) · analyze 0 · test 140/140 · FIN
2026-09-14 · DONE · TASK-18 v17.9: matriz de 4 APK (cualquier dispositivo Android) + Regla 9 del contrato · gates en CI · FIN
2026-09-14 · DONE · TASK-19 v18.0: recheck + 6 encargos: BT RFCOMM nativo (BtSppPlugin.kt), Sala Viva, conversor XE/Wise, generadores PNG, version.dart fuente única (8 commits) · analyze 0 · test 142/142 · FIN

## Hito 2026-09-15/16 · v19.0 (dos sesiones + integración)

2026-09-16 · DONE · TASK-20·A v19.0: 21 encargos del dueño — slides, coach_mark propio, tips con reglas, rate_sheet, conversor bidireccional, MoneyField, 1 consulta/región, hive_ce, PushScreen (16 commits) · analyze 0 · test 159/159 · FIN
2026-09-15 · DONE · TASK-20·B v19.0: DolarApi blindado + respaldos regionales + es-VE total + sellos + BiSwap + sala P2P reescrita desde 0 (seam RoomLink) · analyze 0 · test 155 · FIN
