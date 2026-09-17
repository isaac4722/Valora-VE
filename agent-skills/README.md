# Agent Skills incluidas en el repo

Skills para agentes de IA (Claude/Codex/universal) que trabajen en este código.
Se instalan con `npx skills add <ruta>` o se leen directamente como contexto.

## Procedencia

| Carpeta | Origen | Contenido |
|---------|--------|-----------|
| `taste/` | https://github.com/Leonxlnx/taste-skill | Familia completa anti-slop de frontend (taste, brandkit, minimalist, redesign, imagegen-frontend-*, stitch, soft, output, image-to-code) |
| `flutter/` | `npx skills add flutter/agent-plugins --skill '*'` | 37 skills Flutter (app-workflow, ui-design, persistence, networking, notifications, testing, performance, etc.) |
| `dart/` | `npx skills add dart-lang/skills --skill '*'` | dart-language, dart-concurrency |
| `humanizer/` | https://github.com/blader/humanizer (orden del dueño · v19.3) | Reescribe texto con «tells» de IA para que lea como humano (prosa, docs, copy) — MIT, respuesta a `/humanizer` |
| `caveman/` | incluida en el repo | modo de comunicación ultra-comprimido (niveles lite/full/ultra) — recorta tokens sin perder sustancia técnica |

## Uso rápido

```bash
# Instalar una familia completa para tu agente
npx skills add ./agent-skills/taste --skill '*' --agent universal --yes
npx skills add ./agent-skills/flutter --skill '*' --agent universal --yes
npx skills add ./agent-skills/dart --skill '*' --agent universal --yes
```

## Convenciones del proyecto

- El diseño visual sigue el sistema DP4/DP5 documentado en `docs/PARIDAD-MVP-CRUD.md`
  y los tokens de `lib/core/theme.dart` + `lib/widgets/ui.dart`.
- `taste/` aplica como filtro de calidad anti-genérico para toda GUI nueva
  (leer el brief, declarar «Design Read», evitar defaults de IA).
- `flutter/` y `dart/` son la guía canónica de arquitectura, estado,
  persistencia (Hive), red offline-first y tests.
