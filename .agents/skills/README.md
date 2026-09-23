# Skills del agente (ubicación canónica: `.agents/skills/`)

Toda skill vive en `.agents/skills/<skill>/SKILL.md` — una skill = una
carpeta, sin subcarpetas por familia y sin duplicados (regla del
`AGENT.md`). El agente DEBE leer el `SKILL.md` (carga previa) antes de
usar una skill. Catálogo LLM de la familia taste: `taste-llms.txt`.

## Las del contrato (AGENT.md · Integración de Skills)

| Skill del AGENT.md | Carpeta | Origen |
|---|---|---|
| `ui-nice-skill` | `ui-nice-skill/` | **Propia del repo** (orden del dueño v19.9: no existía en registro público; creada para 1_ANALYZE y 4_AUDIT) |
| `flutter-frontend-design` | `flutter-frontend-design/` | github.com/syeduzaif/flutter-frontend-design (MIT) |
| `mobile-design` | `mobile-design/` | github.com/sickn33/agentic-awesome-skills (skills/mobile-design) |
| `humanizer` | `humanizer/` | github.com/blader/humanizer (MIT, orden del dueño v19.3) |
| `taste-skill` | `taste-skill/` | github.com/Leonxlnx/taste-skill |
| `rtk` | `rtk/` | documentación del binario github.com/rtk-ai/rtk (creada v19.9) |
| `vlm` | `vlm/` | procedimiento propio del repo para 3.5 VISUAL GATE (creada v19.9) |
| `caveman` | `caveman/` | incluida en el repo (JuliusBrussee/caveman) |
| `flutter-accessibility` / `flutter-testing` | oficiales | colección Flutter (ver abajo) |

## Inventario completo (59 skills)

| Grupo | Skills |
|---|---|
| **Contrato** | ui-nice-skill · flutter-frontend-design · mobile-design · humanizer · taste-skill · rtk · vlm · caveman |
| **Flutter oficiales (37)** | flutter (meta) · flutter-accessibility · ai-integration · animation · app-workflow · architecture · authentication · background-execution · build-release · ci-cd · code-review · dependency-upgrades · device-testing · figma-workflow · in-app-purchases · localization · navigation · networking · notifications · observability · openapi-client · package-development · performance · persistence · platform-integration · product-analytics · project-creater · responsive-layout · runtime-debugging · security · state-management · testing · text-rendering · ui-design · ui-patterns · visual-effects · webview |
| **Dart oficiales (2)** | dart-language · dart-concurrency |
| **Familia taste (13)** | taste-skill · taste-skill-v1 · gpt-tasteskill · brandkit · minimalist-skill · brutalist-skill · soft-skill · redesign-skill · output-skill · image-to-code-skill · imagegen-frontend-web · imagegen-frontend-mobile · stitch-skill |

## Instalación

- Estándar: `npx skills add <owner/repo> --agent universal --yes` (instala
  en `.agents/skills/<skill>/` y mantiene `skills-lock.json`).
- En entornos sin salida a la red de npm (timeouts documentados en
  TASK-13/23/30), la vía probada es clonar el repo y copiar la carpeta a
  `.agents/skills/<skill>/`, dejando el `SKILL.md` en su raíz, y
  registrar la instalación en `PROGRESS.md`.
- `skills-lock.json` (raíz) lo gestiona el CLI para lo que él instala; el
  inventario canónico de esta carpeta es ESTE README.

## Reglas

- **No contradicción:** si una skill sugiere algo que viola los Límites
  de Tres Niveles del `AGENT.md`, prevalece el `AGENT.md`.
- Skill del contrato no instalada → se registra en `PROGRESS.md` y se
  continúa manualmente aplicando sus principios.
- `mobile-design` se consulta en `2_PLAN` (convenciones de plataforma,
  touch targets ≥48dp) — no dicta estética.
- Actualizar esta tabla al instalar o consolidar skills.
