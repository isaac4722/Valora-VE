# Tells catalog (Flutter + marketing assets)

Patterns that make a mobile UI look generated, how to spot them, and the fix. IDs link to
`gates.md`. How each is found: ⚙ craftlint, 👁 screenshot, 🧠 judgment.

## First-order defaults (anyone notices)

| Tell | Found | Spot it | Fix |
| --- | --- | --- | --- |
| Gradient on every hero card and button (R1) | ⚙👁 | `LinearGradient(`, gradient tokens | Solid surfaces; accent only on the primary action and the signature |
| Glow orbs behind login / splash / welcome (R2) | ⚙👁 | `RadialGradient(` behind content | Plain background; the brand mark carries the screen |
| Emoji as icons (R4) | ⚙ | Pictographs in `Text`, chips, quiz options, "Done 🎉" | One icon family or the brand illustration |
| Purple / indigo seed, or the untouched Material blue / `deepPurple` | 👁 | `ColorScheme.fromSeed(seedColor: Colors.deepPurple)`, bare `ThemeData()` | A colour chosen for the product |
| Centred everything (R15) | 👁 | Every screen a centred column | Left-aligned content |
| "Unlock your potential" copy (R9) | ⚙ | Template words | Say the number and the next step |

## Second-order defaults (designers notice)

The "tasteful" escape that became the new median. If the app already sits near one of
these, restraint matters more, not less.

| Tell | Found | Spot it | Fix |
| --- | --- | --- | --- |
| Near-black + one neon accent used everywhere (R14) | 👁 | Accent borders, icons, text and chips on one screen | Accent marks one thing per region |
| Cream paper + terracotta + serif display, on an app that never chose it | 👁 | Warm off-white background, clay accent | Move one axis: accent first |
| Tracked-caps eyebrow above each heading (R5) | ⚙ | `.toUpperCase()`, `letterSpacing ≥ 1`, eyebrow styles | Drop it, or a sentence-case label one step smaller |
| Mono as costume (R10) | 🧠 | Monospace on words | Mono for numbers only |
| Glass nav / glass cards (R3) | ⚙👁 | `BackdropFilter`, alpha surfaces | Solid raised surface + hairline |
| Icon in a tinted rounded tile leading every card (R13) | ⚙ | Tinted `BoxDecoration` with radius wrapping an `Icon` | Inline icon or none |
| Neon glow shadow (R16) | ⚙ | `BoxShadow` in an accent colour | Surface step, no shadow |
| Box-everything (R6) | 👁 | Six equal cards stacked | One signature at size, then rows |
| Count-up on every number (R12) | 🧠 | `TweenAnimationBuilder` on each stat | Only the signature, once |
| Shimmer for everything (R11) | 🧠 | Shimmer on fast loads | Last value or small indicator |

## Mobile UX defects (users feel them)

| Defect | Found | Spot it |
| --- | --- | --- |
| Unreadable text (F1) | ⚙👁 | White on light fills; tertiary grey for body text |
| Tiny targets (F2) | ⚙👁 | 36–44dp buttons, `shrinkWrap`, `Size.zero` |
| Broken at large font (F4) | 👁 | Clipped labels at font scale 1.3; fixed `height:` on text boxes |
| Silent screens (F8) | ⚙🧠 | `error: … => SizedBox.shrink()`; no empty state |
| Hidden under the nav (F9) | 👁 | Last list item behind a floating nav |
| Unlabelled icons (F6) | ⚙ | `IconButton` without `tooltip` |
| Colour-only meaning (F6) | 🧠 | Up/down change shown only by green/red |

## Consistency (drift)

| Drift | Spot it | Fix |
| --- | --- | --- |
| Type drift (R8) | Inline `fontSize:` across many files | Theme `textTheme` |
| Spacing drift (R7) | 6, 10, 14, 18 values | The contract's scale |
| Radius drift | `BorderRadius.circular(<n>)` literals | Radius tokens |
| Colour drift (F3, R18) | `Color(0x…)`, `Colors.white` | Named tokens |
| Native drift (N1) | Android layouts in `res/layout/*.xml` (overlays, widgets) with their own hex and `sans-serif` | Mirror tokens in `res/values/colors.xml` |

## Promo (store screenshots, feature graphic, video)

Often built in HTML/React/Remotion; craftlint reads `.ts/.tsx/.js/.jsx` too. Judge store
shots at thumbnail size first: store search shows the first few small.

| Tell / defect | Gate | Spot it |
| --- | --- | --- |
| Screens that don't match the app (nav labels, feature names, unsupported platforms) | F11 | Compare with real screenshots and the contract's Product truth |
| Demo numbers the app's logic can't produce, or the wrong label for a number | F7 | Recompute with the real code |
| "Free", "best", "#1" on preview assets | F11 | Text in shots, feature graphic, video end card |
| Fonts differ from the app | N2 | Font stacks without the app's families |
| Gradient headline text, glow blobs, glass phones | R1–R3 | `linear-gradient`, `radial-gradient`, `backdrop-filter` |
| Every scene enters the same way; bounce springs | R12 | Same entrance in every scene |
| Caption headline could sell any app | R9 | Would it work unchanged for a competitor? Rewrite around the product's real thing |
| Unreadable at thumbnail | F1 | Small captions, low-contrast sub lines |
