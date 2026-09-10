# progress.md · Registro de turnos de agentes

Documento para agentes únicamente: no se enlaza desde el README ni
sustituye la documentación humana. Cada turno añade una sección al final
con la plantilla de `AGENT.md`.

---

## [TASK-0] Arranque · repo orfanado · 2026-09-10 UTC
- Agente: Super Z (GLM) · ingeniero Flutter/Dart senior
- Hecho:
  - Rescate de `assets/brand/` (icon.png, icon-maskable.png,
    splash-logo.png) y `assets/fonts/` (Inter 400–700, Space Grotesk
    500/700) del repo anterior ANTES del borrado.
  - Release `v1.0.0-beta` eliminada vía API autenticada (HTTP 204).
  - 5 tags remotos eliminados (v1.0.0-beta, v15.0.0-beta, v15.1.0-beta,
    v17.1.0, v17.1.1) vía API (HTTP 204 × 5).
  - Commit inicial huérfano: AGENT.md + progress.md + README mínimo +
    arte rescatado + server/lista-sync/ (servidor socket.io del protocolo
    lista-sync portado 1:1 del original v15).
- Decisiones:
  - El servidor lista-sync se porta con el protocolo EXACTO del §6 de
    MVP-CRUD.md (código de 6 letras sin O/I, límites 8/120/16KB,
    granularidad item_*, LWW, presencia 5s/35s, typing 3s).
  - Versionado arranca en `1.0.0-beta+1` (no se hereda v15/v17).
- Gates: no aplica (sin código Dart aún).
- Bloqueos: ninguno.
- Siguiente: Fase 1 · lectura del spec + inventario de fuentes + design
  system; luego Fase 2 · scaffold Flutter + dominio.
