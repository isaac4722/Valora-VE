# The tells, and what to do instead

Each rule id matches the scanner (`scripts/slop.cjs --list-rules`).

## U01 Template colors

```dart
// tell
colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
// instead: a seed that belongs to the product, and surfaces that fit the tone
const seed = Color(0xFFB4532A);
ColorScheme.fromSeed(seedColor: seed, brightness: brightness)
    .copyWith(surface: const Color(0xFFFAF6EF));
```

## U02 Purple-to-blue gradient

The `#667EEA → #764BA2` header is the single most recognisable sign. Remove it. If the
design needs depth, use a flat tinted surface, or a tonal gradient between two neighbors
of your own primary (`c.primary` to `c.primaryContainer`).

## U03 Hard-coded colors, U10 pure black and white, U13 opacity-greys

```dart
// tell
Text(title, style: const TextStyle(color: Colors.black)),
Text(sub, style: TextStyle(color: Colors.grey[600])),
Container(color: Colors.white.withOpacity(0.2)),
// instead
final c = Theme.of(context).colorScheme;
Text(title, style: t.titleMedium),                 // onSurface by default
Text(sub, style: t.bodyMedium),                    // onSurfaceVariant set in the theme
Container(color: c.surfaceContainerHighest),
```

Brand colors that Material has no role for go in a `ThemeExtension`, not in widgets.

## U04 Ad-hoc font sizes

```dart
// tell: 26, 22, 18, 17, 15, 13, 12 on one screen
Text('Title', style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
// instead: roles, tuned once in the theme
Text('Title', style: Theme.of(context).textTheme.headlineMedium),
```

In the theme, give headings a tighter line height (1.1 to 1.25) and slightly negative
letter spacing, body text 1.45 to 1.5. Hierarchy comes from size and weight, not color.

## U05 Spacing off the grid

Use 4, 8, 12, 16, 24, 32, 48. `15`, `18`, `10`, `7` and `30` are what you get when every
gap is guessed separately. Related items sit closer than unrelated ones.

## U06 Too many radii

Pick a family (8 / 12 / 20, or one value) and put it in the component themes
(`cardTheme`, `filledButtonTheme`, `inputDecorationTheme`). A 25 px pill button next to a
16 px card next to a 12 px tile reads as three designers.

## U07 Cards and shadows on everything

A list of five shadowed cards is a list. Use rows with a `Divider`, or one tinted
container around the group. Keep elevation for surfaces that really sit above others:
sheets, menus, a floating action button.

## U08 Emoji as icons

```dart
// tell
Text('🔥'), Text('Welcome back 👋'), Text('Get Started ✨')
// instead: one icon set, same weight everywhere
Icon(Icons.local_fire_department_outlined)
```

Emoji render differently on every platform and never align with the text baseline. One
emoji in a celebratory moment is a choice; one per row is a pattern.

## U09 Placeholder copy

"Welcome back, John Doe", "Get Started", "Let's crush your goals" say nothing. Write what
is true on this screen: `3 left today.`, `Pay 45 000 so'm`, `No orders yet. Your first one
will appear here.` Buttons name the action; headings state the situation.

## U11 No dark theme

```dart
MaterialApp(
  theme: buildTheme(Brightness.light),
  darkTheme: buildTheme(Brightness.dark),
)
```

Build both from the same function so they cannot drift.

## U12 Loading without error or empty states

```dart
builder: (context, snapshot) {
  if (snapshot.hasError) return ErrorState(onRetry: retry); // what happened + one action
  if (!snapshot.hasData) return const LoadingState();
  if (snapshot.data!.isEmpty) return const EmptyState();
  return OrderList(snapshot.data!);
}
```

## Not detected by the scanner, check by eye

- Everything centered; no clear primary action; two filled buttons side by side.
- `GestureDetector` on tappable rows (no ripple, no focus). Use `InkWell` or a button.
- Touch targets under 48 dp; icon-only buttons without a `Semantics` label or tooltip.
- A hero illustration or gradient blob that carries no information.
- Text that overflows at 360 px or with large system fonts.
