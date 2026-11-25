---
name: unbland
description: >
  Anti-AI-slop design skill for Flutter mobile apps (plus their store screenshots, feature
  graphics and promo videos) that makes screens look made, not generated, and holds an
  accessibility floor. Audits for AI design tells (decorative gradients, glow, glass, emoji
  icons, tracked-caps eyebrows, box-everything cards, template copy), mobile UX defects
  (contrast, 48dp targets, text scaling, missing loading/empty/error states, reduce motion)
  and drift from the project's own design system. Modes: audit (report only), fix (surgical
  edits), build (new screen), promo (marketing assets). Use for "audit the UI", "does this
  look AI-generated", "make this screen beautiful", "design review", "polish this screen",
  "build a new screen", "check accessibility", /unbland.
argument-hint: "audit <path|screen> | fix <path> | build <screen> | promo"
---

# Unbland

Anti-AI-slop design skill for Flutter apps.

Make every screen look like one person with taste designed it for this product, and never
ship one that fails a person using it. Three ideas carry the skill:

1. **A default nobody chose is the tell.** A gradient isn't wrong because gradients are
   wrong; it's wrong when it's there because generators always add one.
2. **The project's system is the direction.** Work inside the app's existing theme, fonts
   and voice, written down in its design contract. Don't restyle the brand unless the user
   asks for a redesign.
3. **Code shows half, pixels show the rest.** The linter finds code-certain tells; contrast
   in context, hierarchy, density and "could this be any other app" need screenshots. Tag
   every finding `code`, `seen` (from a screenshot) or `inferred`.

`<skill-dir>` below is this folder (in Kiro: `.kiro/skills/unbland`; in Claude Code:
`.claude/skills/unbland`). Run scripts from the project root.

## The Floor (never waivable)

Binds every mode. A screen with an open Floor finding doesn't ship. Full table and Flutter
fixes in [`references/gates.md`](references/gates.md) § Floor.

- **F1 Contrast:** text 4.5:1; large text (≥ 18sp bold or ≥ 24sp) and icons 3:1.
- **F2 Targets:** every tappable thing ≥ 48 × 48dp, ≥ 8dp apart.
- **F3 Tokens:** colours come from the theme. A new colour is a new named token, never `Color(0x…)` in a screen.
- **F4 Text scale:** never clamp or disable scaling; no overflow at 1.3×, still usable at 2.0×.
- **F5 Reduce motion:** looping or decorative animation checks `MediaQuery.disableAnimationsOf(context)`.
- **F6 Labels:** icon-only controls have a `tooltip` or `Semantics` label; painted things (rings, charts) expose a value; colour is never the only signal.
- **F7 No invented facts:** no made-up user counts, ratings, testimonials or research claims. Demo numbers must be ones the app's own logic can produce.
- **F8 States:** every data view has loading, empty and error, plus offline and permission-denied where they apply.
- **F9 Layout:** no overflow at 320dp; content clears nav bars, system insets and the keyboard.
- **F10 One layer:** never a card inside a card.
- **F11 Product truth:** no feature, platform or claim the product doesn't have (contract § Product truth); no "free"/"best"/"#1" on store preview assets.
- **F12 Platform:** system and predictive back work; destructive actions confirm or offer undo.

Above the Floor, **Reflex** gates (R1–R18) are defaults a model falls into: fix them, or
waive one on the record with a reason about this screen. **Polish** checks (P1–P10) are
craft detail: answer them, never blocking.

## Modes

"Just audit", "check", "review", "what's AI about this" → `audit`. "Fix", "polish", "clean
up" → `fix`. "Build", "design", "add a screen" → `build`. Store screenshots, feature
graphic, promo video → `promo`. Unsure → `audit`.

### 0. Pre-flight (every mode)

1. **Find the design contract**, first match wins: the `contract` path in
   `craft.config.json`; `DESIGN.md` or `design.md` at the root. It holds direction,
   tokens, type, spacing, voice, product truth, allowed exceptions and known debt.
   - **None found:** in `audit`, infer the system from the theme files (`ThemeData`,
     colour and text-style classes, `pubspec.yaml` fonts) and report against that, saying
     it's inferred. In `fix`/`build`, offer to write one from
     [`references/contract-template.md`](references/contract-template.md) and a
     `craft.config.json` from [`references/config.md`](references/config.md); write them
     only after the user says yes.
2. Read only the files in scope. Name them before editing anything. Follow the project's
   agent instructions (`CLAUDE.md`, `AGENTS.md`, steering files) if present.

### audit (report only, edits nothing)

1. **Scan.** `node <skill-dir>/scripts/craftlint.mjs <paths>` (`--summary` first on big
   scopes, `--gate F1,F6` to drill in, `--json` to parse). It's the code-certain half.
2. **Contrast.** `node <skill-dir>/scripts/craftlint.mjs tokens` grades the configured
   token pairs; `… contrast <fg> <bg> [--base <hex>]` grades any pair a screen uses
   (8-digit hex is Flutter `0xAARRGGBB`; `--base` is what a translucent colour sits on).
3. **See it.** Screenshots of each screen in scope, from the user or a device
   ([`references/review.md`](references/review.md) § Screenshots, also at font scale 1.3).
   Without pixels, mark visual findings `inferred`.
4. **Walk the judged gates** in [`references/gates.md`](references/gates.md) and the
   catalog in [`references/tells.md`](references/tells.md) per screen. Check states with
   [`references/states.md`](references/states.md).
5. **Fresh eyes.** Give the screenshots and the prompt in
   [`references/review.md`](references/review.md) to a sub-agent that didn't do the audit.
   Without sub-agents, re-read the screenshots cold and say "in-thread".
6. **Report** (format below). A clean audit is a valid result: say so and stop.

### fix (surgical)

1. Run `audit` steps 1–4 on the scope (skip the sub-agent for a single widget).
2. Fix Floor, then Reflex, then Polish. Smallest diff that clears the gate, inside the
   existing system: reuse the project's card, button and header widgets and its
   `textTheme`. Never change behaviour, state management, routing or what copy means.
3. Shared widgets and theme files touch every screen. List the files and the visible
   change, and get a yes before editing them.
4. A Reflex you keep gets a waiver on the line or the line above:
   `// craft: waive R4 group emoji are user-picked content, not icons`. A false-positive
   WARN gets `// craft: dismiss F2 <reason>`. Reasons name something on this screen, 12+
   characters. Floor gates can't be waived. The same waiver on three screens is a house
   style: add it to the contract's "Allowed on purpose" instead.
5. Verify: re-run craftlint on the scope (0 FAIL, every WARN fixed or dismissed),
   `flutter analyze` (0 issues), `flutter test`. Re-take screenshots when possible.

### build (new screen or widget)

1. **Pre-build protocol** ([`references/states.md`](references/states.md) § Protocol).
2. **Signature.** Name the one thing the user should remember from this screen: usually
   the real number or object the product is about, set big. One per screen; everything
   else steps back.
3. **Critique the plan** before code, 1–5 per axis; revise anything under 3 first:
   **Purpose** (every block serves the user goal), **Hierarchy** (squint test: signature
   seen first), **Specificity** (couldn't belong to another app), **Restraint** (one
   accent, no decoration without a job), **Execution** (passes the gates first time).
   State the weakest axis and the fix.
4. Build with the project's widgets and tokens, all states included.
5. Verify as in `fix` step 5, then the fresh-eyes review.

### promo (store screenshots, feature graphic, video)

Same gates, read for marketing assets ([`references/tells.md`](references/tells.md)
§ Promo). Extra rules: every pixel matches the real app (nav labels, feature names,
supported platforms); demo numbers are ones the app can produce; no "free"/"best"/"#1" on
store preview assets (Google Play and App Store guidance). Judge store shots at thumbnail
size first. Render, then view the images before judging.

## Report format

```
Unbland · <mode> · <scope> · contract: <path | inferred>
craftlint: FAIL n · WARN n · REFLEX n (top gates: R8 172, R7 191 …)

Floor (fix before ship)
1. F1 · lib/…/challenge_card.dart:150 · white text on a light gradient card, 1.25:1 · seen
   Fix: on-colour text token on the fill, or a solid surface with an accent border.
Reflex (fix or waive)
…
Polish
…
Fresh-eyes review: <ship | fix | rework> · <its top findings>
Keep: <what is already good and must not be diluted>
```

Rank by cost to the user, not by count. One line of "why it reads as AI or hurts users"
per finding. Group repeats ("R8 inline fontSize · 172 hits in 41 files · move to theme
styles screen by screen") instead of listing them all.

## Guardrails

- **Never break working code.** State, providers, routing, analytics and a11y survive intact.
- **Don't trade one cliché for another.** Gradient → glow, or emoji → icon-in-a-tinted-tile, is still a default.
- **The user's choices win.** A look picked on purpose stays; waive it on the record.
- **Evidence, not accusation.** A tell shows a default nobody chose; it doesn't prove a model made it.
- **Don't manufacture problems.** If a screen is already distinctive, say so.
- **Don't over-design.** A settings screen doesn't need motion. Restraint beats decoration.
- **Copy:** sharpen microcopy in the contract's voice; never invent claims.
- **No mass rewrites** of known debt without a file-level plan the user approved.
