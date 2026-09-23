# Skills · Catálogo del Contrato

Las skills se invocan **dentro** de los estados del flujo definido en `WORKFLOW.md`. Lee el `SKILL.md` de cada skill antes de usarla.

## Ubicación y organización

- **Ubicación canónica:** `.agents/skills/<skill-name>/SKILL.md`.
- **Catálogo:** `.agents/skills/README.md`. Si el repo ya contiene skills, verifica que estén en `.agents/skills/` (no dispersas). Si hay duplicados, consolida.
- **Instalación:** `npx skills add <owner/repo> --agent universal --yes` (mantiene `skills-lock.json`). Sin red npm disponible, clonar y copiar a `.agents/skills/<skill>/` (precedente TASK-13/23).
- **Faltas:** si una skill requerida no está instalada, regístralo en `PROGRESS.md` y aplica sus principios manualmente.

## Token-efficiency (RTK + Caveman)

| Skill | Estados donde se usa | Cuándo | Notas |
|---|---|---|---|
| `rtk` (Rust Token Killer) | Transversal (cualquier estado que ejecute shell) | Comandos ruidosos: `rtk flutter analyze`, `rtk flutter test`, `rtk git status`, `rtk git diff --stat`, `rtk grep`. Reduce **input**. | Instalar vía `brew install rtk` o releases github.com/rtk-ai/rtk; luego `rtk init --global`. |
| `caveman` | 3_IMPLEMENT, 4_AUDIT, 7_PERSIST (solo output conversacional) | Activar modo `lite` o `full` para comprimir respuestas al usuario. Reduce **output**. | **NUNCA** para `docs/`, `PROGRESS.md`, `progress_warm.md`, `progress_archive.md`, commits ni documentación. Solo respuestas conversacionales. |

**Regla:** RTK optimiza input, Caveman optimiza output. Son capas, no excluyentes. Si una skill de diseño sugiere verbosidad y Caveman sugiere brevedad, prevalece Caveman **solo en output conversacional**; `docs/` y commits van en español normal.

## Diseño y calidad

| Skill | Estados | Cuándo |
|---|---|---|
| `ui-nice-skill` | 1_ANALYZE, 4_AUDIT | Toda creación/modificación de pantallas o flujos UI. Audita contra el sistema de diseño vigente del repo; no inventa estética. |
| `flutter-frontend-design` | 3_IMPLEMENT | UI nueva en `lib/`. |
| `mobile-design` | 2_PLAN (consulta) | Convenciones de plataforma (touch targets ≥48dp, breakpoints). Solo consulta, no dicta estética. |
| `humanizer` | 3_IMPLEMENT (post-UI) | Pulir TODO texto visible al usuario antes de cerrar. |
| `vlm` | 3.5_VISUAL_GATE | Capturas Flutter web local; descarta slop/BASURA. No rediseña. |
| `taste-skill` | 4_AUDIT | Opcional. Si la auditoría visual detecta riesgo de "AI slop". |
| `flutter-accessibility` (oficial) | 4_AUDIT | Semántica, contraste, `Semantics()`, navegación por teclado si hay UI nueva. |
| `flutter-testing` (oficial) | 4_AUDIT | Widget/golden tests si la pieza tocó widgets o layouts. Complementa `quality_gate.sh`. |

**Regla de no contradicción:** si una skill sugiere algo que viola los Límites de tres niveles en `AGENT.md`, prevalece el contrato.
