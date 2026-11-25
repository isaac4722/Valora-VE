---
name: flutter-unslop
description: Makes a Flutter UI stop looking AI-generated. Finds the tells (default purple seed, purple-blue gradients, hard-coded colors, ad-hoc font sizes, off-grid spacing, emoji icons, cards on everything, placeholder copy, no dark theme) and redesigns the screen with a real direction. Use when the user says a Flutter screen looks generic, templated, vibecoded or "like AI made it", asks to polish, restyle or redesign Flutter UI, or wants a design review of Flutter code.
---

# Flutter Unslop

Agent-written Flutter screens share a look: the `flutter create` purple, a gradient
header, a greeting with a waving emoji, shadowed cards in a column, and a different
font size on every line. Each choice is defensible. Together they say nobody decided
anything. This skill finds those defaults and replaces them with decisions.

## Principles

1. **Decide first, then restyle.** Removing tells without a direction produces a
   different kind of generic. Write the direction before touching code.
2. **Same screen, same data, same behavior.** Unslop changes how it looks and reads.
   Do not add features, change navigation, rename public APIs or touch business logic.
3. **Tokens live in the theme.** Every fix should move a decision into `ThemeData`,
   so the next screen inherits it instead of repeating it.
4. **The score is a smoke detector, not a grade.** A low score means the defaults are
   gone. Whether the result is good is still a judgment you make by looking.

## Workflow

### 1. Measure

```bash
node <skill-dir>/scripts/slop.cjs <project-or-file>
node <skill-dir>/scripts/slop.cjs <project-or-file> --json /tmp/unslop.json
```

It scans `lib/` (skipping generated files and tests) and prints a slop score from 0 to
100 with the tells behind it, each with file and line. Tell the user the score and the
top three tells in plain words. If the user shared a screenshot instead of code, skip the
script and judge the same tells by eye using `references/tells.md`.

### 2. Write the direction (three lines, shown to the user)

1. **Purpose:** who uses this screen and the one thing they must do on it.
2. **Tone:** one concrete direction, for example "quiet paper notebook", "bank you
   trust", "arcade", "field tool for gloved hands". Never "modern and clean": that is
   the default look with a name.
3. **Signature detail:** one memorable choice, such as a distinctive number style, an
   unusual accent color, a custom progress shape, a strong layout break.

If the product already has a brand (logo, colors, an existing designed screen), the
direction comes from it. Ask for it when it is not in the repo. Otherwise propose a
direction and confirm it with the user before a large restyle.

### 3. Build the theme

Create or update one theme file before editing screens:

- `ColorScheme.fromSeed` with the product's own seed, light and dark from the same seed,
  and tinted surfaces where the tone calls for it.
- `TextTheme` roles with weight, letter spacing and line height set once. At most four
  sizes on a screen.
- Component themes for buttons, cards, inputs and dividers: one radius family, one
  elevation policy.
- A `ThemeExtension` for tokens Material has no slot for (spacing scale, brand colors).

### 4. Fix the tells, biggest first

Work through the scanner's list in order. `references/tells.md` has the bad and good
version of each. The usual order:

1. Colors: seed, gradients, hard-coded colors, pure black and white, opacity-greys.
2. Type: replace inline `TextStyle(fontSize: …)` with `TextTheme` roles.
3. Space: put every gap on the 4 px scale; same relationship, same gap.
4. Surfaces: remove cards that only group; keep elevation for things that float.
5. Icons and copy: one icon set instead of emoji; real words instead of placeholders.
6. States: dark theme, error and empty states, 48 dp touch targets, `Semantics` labels
   on icon-only controls.

Then add the signature detail. It is the part people remember, so do not skip it.

### 5. Verify

- Run the scanner again and report before and after scores.
- Run `flutter analyze` and the app if a Flutter SDK is available. If it is not, say so:
  do not claim the screen was visually checked.
- Check at 360 px width and with large text (`MediaQuery.textScalerOf`), in light and dark.

## Reporting

Show: the direction, before and after score, what changed grouped by the list above, and
anything you deliberately left alone. Keep code and widget names in English and write the
explanation in the user's language.

## In CI

```bash
node skills/flutter-unslop/scripts/slop.cjs . --max-score 30
```

exits 1 when the score rises above the limit.
