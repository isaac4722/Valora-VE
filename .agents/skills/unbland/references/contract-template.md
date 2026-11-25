# <App name> design contract

The direction every unbland mode works inside. Change this file (with the owner's
yes) instead of drifting screen by screen. Save it as `DESIGN.md` at the root, or anywhere
and point `craft.config.json` → `contract` at it. Date the facts; re-check paths before
quoting line numbers.

## Direction

One or two sentences: what the product is about and what every main screen leads with
(the signature). Then the fixed facts:

- Modes: light / dark / both. Platforms: Android / iOS / both (Material 3 or Cupertino conventions).
- Brand assets that are on purpose and must not be "fixed" (logo, mascot, signature colour).

## Tokens

Source files: `<path to colours>`, `<path to theme>`.

| Role | Token | Hex | Use |
| --- | --- | --- | --- |
| Signal / primary | | | Primary action, the one highlighted thing |
| On primary | | | Text and icons on the primary fill |
| Background | | | Scaffold |
| Surfaces | | | Card → raised → floating |
| Borders | | | Hairline / selected |
| Text | | | Primary / secondary / tertiary (note any that fail 4.5:1) |
| Status | | | Success, warning, danger, info |

Known failing pairs (from `craftlint tokens`):

## Type

Families and roles (display, body, numbers), where they're loaded, the scale, and which
styles to use (`Theme.of(context).textTheme`, custom text-style class). Styles not to use
in new code.

## Shape and space

- Radius scale and which component uses which.
- Spacing scale and screen gutter; space above a heading ≥ 2× space below.
- Button heights, icon family, motion curve and durations.

## Voice (copy)

Three adjectives, then a few "Instead of → Write" rows from the real app.

| Instead of | Write |
| --- | --- |
| | |

## Product truth (F11)

True today: the features, platforms and limits that exist.
Not true: what must never be shown or claimed (unbuilt features, other platforms, invented proof).

## Allowed on purpose

Choices that look like tells but were made deliberately; use these as waiver reasons.

## Known debt

Open findings to fix as screens are touched, with paths. Run `craftlint --summary` for counts.
