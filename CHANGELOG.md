# Changelog


## 1.9.10-beta+28 · v19.10 — Auditoría visual premium + notificaciones que sí llegan en 2º plano

- **Notificaciones en 2º plano (fix del síntoma «solo avisan al abrir la
  app»)**: el worker horario retornaba con los `show()` en vuelo sin
  esperar y el engine de 2º plano moría antes de notificar. Ahora
  `AlertEngine` acumula los avisos pendientes y `drain()` los espera;
  `AppStore.flushNotifications()` fuerza el disco del anillo del centro;
  el dispatcher de workmanager espera ambos antes de retornar. Con test
  de regresión (`test/alerts_drain_test.dart`).
- **Auditoría visual 1:1 (web local privada del agente + capturas)**:
  onboarding con contenido centrado verticalmente (slides 2–4, patrón
  del slide 1) — antes quedaban colgados arriba con ~45 % vacío; el
  héroe de Inicio ya no repite la categoría («OFICIAL» + «Oficial ·
  Banco Central de Venezuela» pasa a «OFICIAL» + «Banco Central de
  Venezuela»); el placeholder del presupuesto de Lista ya no se trunca
  («Presupuesto del mes»); la tarjeta «App Widgets» se oculta en web
  (honestidad de plataforma: los widgets son de Android).
- Skills del contrato usadas de punta a punta: rtk (shell), ui-nice-skill
  (checklist 12 puntos + anti-slop), vlm (capturas y verificación),
  humanizer (micro-copy), flutter-accessibility (semántica del héroe ya
  presente; targets verificados), flutter-testing (regresión), taste
  (filtro anti-genérico: cero señales de slop).

## 1.9.9-beta+27 · v19.9 — Contrato del agente reconstruido: docs/agent/, bitácora de 3 niveles y skills unificadas

- **AGENT.md v3 (máquina de estados 9.5 pasos)**: el ciclo de trabajo pasa
  a ser una máquina de estados con routes explícitos (ANALYZE → PLAN →
  IMPLEMENT → VISUAL GATE → AUDIT → CONTROL → RETRY → PERSIST → CI →
  CLOSE/BLOCKED), con la sub-rama de recuperación que NO vuelve ciego al
  paso 1 y la regla de oro de saltar 2_PLAN en reintentos. Ronda conjunta
  de dos sesiones (08360df/303b4f2 + esta), con `MVP-CRUD.md` en la raíz
  como única fuente de verdad funcional.
- **Bitácora de tres niveles**: `progress.md` (82 KB de prosa por turno)
  es reemplazado por `PROGRESS.md` (hot · ≤10 líneas) + `progress_warm.md`
  (últimos ~10 turnos cerrados) + `progress_archive.md` (historial
  comprimido por hito). Una línea por pieza, solo hechos, append-only y
  rotación hot→warm→cold. El detalle histórico queda en la historia git.
- **`docs/agent/` recreado**: CODE_STYLE, TESTING, GIT_WORKFLOW,
  ARCHITECTURE y DEPENDENCIAS (movida a su alcance), cortos y operativos
  en es-VE, basados en la realidad verificable del árbol. Prohibido
  inventar contenido: lo que falta queda como `TODO:`.
- **Skills unificadas en `.agents/skills/`** (59): las 37 oficiales de
  Flutter + 2 de Dart + la familia taste (13) + caveman + humanizer
  (dedup: la copia de agent-skills/ fuera) se consolidan en la ubicación
  canónica que exige el contrato. Del contrato: `ui-nice-skill` (propia
  del repo, orden del dueño), `flutter-frontend-design` (syeduzaif),
  `mobile-design` (sickn33/agentic-awesome-skills), `humanizer` y
  `taste-skill`; nuevas de documentación: `rtk` (Rust Token Killer) y
  `vlm` (procedimiento real del visual gate). CI re-apunta a
  `scripts/quality_gate.sh`.
- **`scripts/quality_gate.sh`**: el gate local del contrato ahora existe —
  pub get + analyze (0) + suite completa + auditoría de prohibiciones en
  `lib/` (AppStateScope/patrones web/mocks), espejo del CI que lo ejecuta.
- **Versionado**: 1.9.9-beta+27 · visible 19.9. Sin cambios funcionales
  en `lib/` (solo la constante de versión visible).