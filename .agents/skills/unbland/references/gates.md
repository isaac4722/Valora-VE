# Gates

The one list of what unbland refuses. `craftlint.mjs` implements the gates marked
**M**; the rest are judged. If the script and this file disagree, this file wins. "Theme
token" means the project's colour class (`AppColors.*` by default) or `ColorScheme`.

**Tier:** **Floor** never ships and can't be waived. **Reflex** is a default a model falls
into: fix it, or waive it on the record. **Polish** is craft detail: answer it, never
blocking.

**Check:** **M** craftlint (static) · **S** seen in a screenshot · **J** judged by reading
the code and the screen.

**Grades in craftlint:** `FAIL` (Floor, certain) · `WARN` (suspected: confirm and fix, or
dismiss) · `REFLEX` (fix or waive) · `NOTE` (bookkeeping) · `WAIVED` / `DISMISSED` (reason
recorded on the line).

## Waivers

On the flagged line or the line above:

```dart
// craft: waive R4 group emoji are user-picked content, not icons
// craft: dismiss F2 48dp hit area comes from the parent InkWell
```

The reason names something on this screen and is 12+ characters. Floor gates can't be
waived. The same Reflex waived on three screens is a house style: write it into the
contract's "Allowed on purpose".

## Floor

| Gate | Check | The defect | The fix (Flutter) |
| --- | --- | --- | --- |
| F1 | M/S | Contrast under 4.5:1 for text, 3:1 for large text (≥ 18sp bold, ≥ 24sp) and icons. White text on light fills (lime, yellow, amber, light gradients): white on `#C5F75A` is 1.25:1. | The on-colour token (`onPrimary`) on light fills; grade pairs with `craftlint contrast`. Tertiary/hint greys are for hints and disabled states, not content. |
| F2 | M/S | Tap target under 48 × 48dp, or two targets closer than 8dp. `shrinkWrap`, `VisualDensity.compact`, `minimumSize` < 48, a 36dp `SizedBox` around an `IconButton`. | Keep the visual small, grow the hit area: default `IconButton` constraints, a 48dp hit box, `MaterialTapTargetSize.padded`. |
| F3 | M | `Color(0x…)` / `Color.fromARGB` in a screen or widget. | A named token in the colour class (third-party brand colours too, e.g. `whatsapp`). |
| F4 | M/S | `TextScaler.noScaling`, `textScaleFactor: 1`, fixed-height boxes that clip text at 1.3×. | Let text scale; `minHeight` not `height`; `maxLines` + ellipsis where space is truly fixed; test at 1.3 and 2.0. |
| F5 | M/J | A looping or decorative animation with no reduce-motion path. | `MediaQuery.disableAnimationsOf(context)` → show the end state; keep functional motion short. |
| F6 | M/J | `IconButton` without `tooltip`; `GestureDetector`/`InkWell` around an icon with no `Semantics`; `CustomPaint` with no value; meaning by colour alone (▲/▼ only green/red). | `tooltip:`; `Semantics(label:, value:, button: true)`; pair colour with an icon or word. |
| F7 | J | Invented facts: user counts, ratings, "studies show", testimonials, fake people in real UI; demo numbers the app's logic can't produce. | Remove, or use real data; compute demo numbers with the app's own logic. |
| F8 | M/J | A data view that shows nothing while loading, swallows errors (`error: (_, __) => const SizedBox.shrink()`), or has no empty state. | Every state in `states.md`; errors say what happened and offer retry. |
| F9 | S/J | Overflow stripes at 320dp; last item hidden under a floating nav; inputs under the keyboard; content under system bars. | `SafeArea`, bottom padding ≥ nav height + inset, `Flexible`/`Expanded`, scroll with `viewInsets`. |
| F10 | M | A card inside a card (any of `cardWidgets` nested). | One containment layer: inner groups become rows, dividers or a raised fill without a border. |
| F11 | M/J | A claim the product can't back (contract § Product truth); "free", "best", "#1" on store preview assets. | Show and say what exists today. |
| F12 | J | Back gesture or button overridden or broken; destructive action without confirm or undo. | `PopScope` only to protect unsaved work; confirm dialog or undo snackbar. |

## Reflex

| Gate | Check | The tell | Why it reads as made-by-default | The fix |
| --- | --- | --- | --- | --- |
| R1 | M/S | Decorative gradient fills on cards, buttons, headers. | The first thing every generator adds to look "premium". | Solid surfaces; at most one gradient per screen, on the signature only. |
| R2 | M/S | Radial glow blobs and halos behind content (login, splash, onboarding). | The "aurora" background is the most recognised AI hero. | Plain background; let the logo, illustration or number be the focal point. |
| R3 | M/S | Glass: `BackdropFilter` / blur panels. | Second-generation "premium" default. | Solid raised surface with a hairline border; elevation by lightness. |
| R4 | M | Emoji as icons or decoration in chrome: chips, buttons, headers, empty states, onboarding options, "Done 🎉". | Emoji stand in for an icon nobody chose and render differently on every OEM. | One icon family or the brand illustration. Allowed: user content, and emoji the contract keeps on purpose. |
| R5 | M | Tracked-caps eyebrows (`.toUpperCase()`, `letterSpacing` ≥ 1) above headings and as labels. | The eyebrow above every heading is the strongest template tell. | Sentence case, body face, one step smaller, untracked. The heading alone is enough. |
| R6 | J/S | Box-everything: every block is the same card with the same border, radius and padding. | No hierarchy: nothing matters more than anything else. | Signature on the background at size; secondary items as rows with dividers; vary weight, not boxes. |
| R7 | M | Off-scale spacing (6, 10, 14, 18, 22 …) and the same gap everywhere. | Uniform or random spacing has no rhythm. | The contract's scale; more space above a heading than below it. |
| R8 | M | Inline `fontSize:` / `TextStyle(...)` instead of `Theme.of(context).textTheme`. | Type drifts screen to screen; sizes nobody chose. | Theme text styles; `copyWith(color:)` only. Fix per screen as it's touched. |
| R9 | M/J | Template copy: unlock, elevate, seamless, supercharge, journey, level up, awesome, amazing, "Oops! Something went wrong", exclamation marks everywhere. | Copy that fits any app says nothing about this one. | Concrete, in the contract's voice: what happened, the number, the next step. |
| R10 | J | Mono as costume: monospace on labels, captions or words. | Mono signals "data" only when it's data. | Mono for numbers, codes and measurements only. |
| R11 | J/S | Shimmer skeletons for everything, including fast loads and single numbers. | Skeleton-everywhere is a kit default. | Skeleton only for slow loads with a known layout; else keep the last value or a small indicator. |
| R12 | M/J | Bouncy or elastic curves; the same entrance on every widget; count-up on every number. | Motion with no job. | `Curves.easeOutCubic`, 150–250ms; one entrance per screen; count-up only on the signature, once. |
| R13 | M | Icon inside a tinted rounded tile, leading every card and row. | Most common card tell after the gradient. | Inline icon beside the text, or none. Keep tiles only where the icon is the content (app logos). |
| R14 | S | The accent over ~10% of a screen, or two accents fighting in one card. | When everything is highlighted nothing is. | The accent marks one signal per region. |
| R15 | S | Everything centred on content screens. | Centred stacks are the generator's default layout. | Left-align content; centre only empty states, splash and a hero number. |
| R16 | M | Coloured glow shadows (`BoxShadow` in an accent colour). | Neon glow on dark is an AI dark-mode default. | No shadow on dark; separate by surface step. |
| R17 | J/S | Untouched Material defaults: default `AlertDialog`, `SnackBar`, progress colour, white spinner on a light button, default `TextField`. | Unthemed components read as unfinished. | Theme them once in the app theme. |
| R18 | M | `Colors.white` / `Colors.black` in screens. | Pure white/black is usually off-palette next to tinted surfaces. | Text, on-colour and background tokens; `Colors.transparent` is fine. |

## Polish

| Check | What to look for |
| --- | --- |
| P1 | Counters and scores use tabular figures (`FontFeature.tabularFigures()`) so digits don't jiggle. |
| P2 | Nested radius: inner radius = outer radius − padding. |
| P3 | Plurals and numbers: "1 item" vs "2 items"; digit grouping; durations as "2h 10m"; locale-aware formats. |
| P4 | Haptics on meaningful moments only, never on scroll. |
| P5 | Ripples clip to the shape (`InkWell` `borderRadius` matches the container). |
| P6 | Long names and translated text: ellipsis on one line or wrap to two; never cut mid-glyph. |
| P7 | One icon family and weight; no mixed outlined/filled in one row. |
| P8 | Borders one weight; no double borders where a card meets a list. |
| P9 | Optical alignment: icon and text baselines line up; numbers align right in tables and ranks. |
| P10 | Microcopy in the contract's voice. |
