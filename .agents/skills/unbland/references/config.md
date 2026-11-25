# craft.config.json

Optional file at the project root that tells `craftlint.mjs` about the project. Every key is
optional; missing keys use the defaults below. Use `--config <file>` for another path.

| Key | Default | What it does |
| --- | --- | --- |
| `contract` | none | Path to the design contract (else `DESIGN.md` / `design.md` at the root) |
| `paths` | `["lib"]` | What to scan when no paths are given. Add native layouts (`android/app/src/main/res/layout`) and promo sources (`promo/src`) if you have them |
| `themeDirs` | `lib/core/theme/`, `lib/theme/`, `lib/src/theme/` | Files here may hold raw colours, font sizes and letter spacing |
| `colorsFile` | none | Dart file with `static const Color name = Color(0xAARRGGBB)` tokens; needed for `tokens` |
| `colorClass` | `AppColors` | Class name of the colour tokens (`AppColors.primary`) |
| `cardWidgets` | `["Card"]` | Widgets treated as cards for F10 (card inside a card), e.g. `["AppCard", "Card"]` |
| `lightFills` | `[]` | Token names of light fills (lime, yellow, amber, light gradients). Turns on the F1 "white text on a light fill" check |
| `baseColor` | `#FFFFFF` | Background that translucent colours sit on when grading contrast (your scaffold colour) |
| `contrastPairs` | `[]` | `[["fgToken", "bgToken", "text" or "ui"], …]` graded by `tokens`. `WHITE` and `BLACK` are built in |
| `spacingScale` | `0 1 2 4 8 12 16 20 24 32 40 48 56 64 72 80 96 120` | Allowed padding and gap values for R7 |
| `eyebrowStyles` | `[]` | Calls that make tracked-caps labels, e.g. `["AppText.eyebrow"]` (R5) |
| `fonts` | `[]` | App font names; promo font stacks without any of them get an N2 note |
| `previewPaths` | `[]` | Store-asset sources (screenshots, feature graphic, video) checked for `previewBanned` |
| `previewBanned` | `\b(free\|best\|#1\|number one)\b` | Regex of words not allowed on store preview assets |
| `claims` | `[]` | Product-truth checks for F11: `{ "pattern": "tiktok", "flags": "i", "unless": "soon\|not yet", "message": "…" }` |

## Example

```json
{
  "contract": "DESIGN.md",
  "paths": ["lib", "android/app/src/main/res/layout"],
  "colorsFile": "lib/theme/app_colors.dart",
  "cardWidgets": ["AppCard", "Card"],
  "lightFills": ["primary", "highlight"],
  "baseColor": "#101114",
  "contrastPairs": [["textPrimary", "background", "text"], ["onPrimary", "primary", "text"]],
  "claims": [{ "pattern": "\\b(iOS|iPhone)\\b", "message": "app is Android only" }]
}
```
