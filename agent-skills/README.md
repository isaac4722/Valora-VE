# Agent Skills · Carpeta estándar única (ValoraVE)

Skills para agentes de IA (Claude/Codex/universal) que trabajen en este
código. **Una sola carpeta estándar:** cada skill vive DIRECTO en
`agent-skills/<skill>/SKILL.md` (convención del CLI `skills`:
`npx skills add … --agent universal` instala en `./agent-skills/<skill>/`).
Sin subcarpetas por familia: un skill = una carpeta.

## Las 5 del contrato (AGENT.md · Integración de Skills)

| Skill del AGENT.md | Carpeta | Origen |
|---|---|---|
| `ui-nice-skill` | `agent-skills/ui-nice-skill/` | **Propia del repo** (orden del dueño v19.9: no existía en ningún registro público; creada para 1_ANALYZE y 4_AUDIT) |
| `flutter-frontend-design` | `agent-skills/flutter-frontend-design/` | github.com/syeduzaif/flutter-frontend-design (MIT) |
| `mobile-design` | `agent-skills/mobile-design/` | github.com/sickn33/agentic-awesome-skills (skills/mobile-design) |
| `Humanizer` | `agent-skills/humanizer/` | github.com/blader/humanizer (MIT, orden del dueño v19.3) |
| `Taste Skill` | `agent-skills/taste-skill/` | github.com/Leonxlnx/taste-skill |

## Inventario completo (57 skills)

| Grupo | Skills |
|---|---|
| **Contrato (5)** | ui-nice-skill · flutter-frontend-design · mobile-design · humanizer · taste-skill |
| **Flutter (37)** | flutter (meta) · flutter-accessibility · ai-integration · animation · app-workflow · architecture · authentication · background-execution · build-release · ci-cd · code-review · dependency-upgrades · device-testing · figma-workflow · in-app-purchases · localization · navigation · networking · notifications · observability · openapi-client · package-development · performance · persistence · platform-integration · product-analytics · project-creater · responsive-layout · runtime-debugging · security · state-management · testing · text-rendering · ui-design · ui-patterns · visual-effects · webview |
| **Dart (2)** | dart-language · dart-concurrency |
| **Taste familia (13)** | taste-skill · taste-skill-v1 · gpt-tasteskill · brandkit · minimalist-skill · brutalist-skill · soft-skill · redesign-skill · output-skill · image-to-code-skill · imagegen-frontend-web · imagegen-frontend-mobile · stitch-skill |
| **Otras (1)** | caveman (comunicación ultra-comprimida) |

Archivos sueltos: `README.md` (este) y `taste-llms.txt` (índice LLM de la
familia taste, conservado del repo original de procedencia).

## Uso rápido

```bash
# Leer una skill directamente como contexto (lo que hace el agente):
cat agent-skills/ui-nice-skill/SKILL.md

# Instalar una para TU agente (fuera de este repo, p.ej. en tu máquina):
npx skills add ./agent-skills/ui-nice-skill --agent universal --yes
npx skills add ./agent-skills/taste-skill --agent universal --yes
npx skills add ./agent-skills/mobile-design --agent universal --yes
```

`skills-lock.json` (raíz del repo) lo gestiona el CLI `skills` para lo
que él instala desde registros; el inventario canónico de esta carpeta
es ESTE README.

## Convenciones del proyecto

- El diseño visual sigue el sistema DP4/DP5 documentado en
  `MVP-CRUD.md` §8 + `docs/DESIGN-SYSTEM.md` y los tokens de
  `lib/core/theme.dart` + `lib/widgets/ui.dart`.
- `ui-nice-skill` y `taste-skill` aplican como filtro de calidad visual
  para toda GUI nueva o tocada (leer la skill, declarar «Design Read»,
  evitar defaults de IA).
- `flutter/`, `dart/` y `flutter-frontend-design` son la guía canónica de
  arquitectura, estado, persistencia (Hive), red offline-first y tests.
- `mobile-design` se consulta en 2_PLAN para convenciones de plataforma
  (touch targets ≥48dp, breakpoints) — no dicta estética.
- **Regla de No Contradicción** (AGENT.md): si una skill sugiere algo
  que viola los Límites de Tres Niveles, prevalece el AGENT.md.
