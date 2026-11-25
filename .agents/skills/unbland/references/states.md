# States and the pre-build protocol

## Protocol (before building or reworking a screen)

Answer each in one line, in the plan, before writing code.

1. **User goal:** what does the person come here to do or learn?
2. **Primary action:** the one thing to tap. Secondaries step back.
3. **Signature:** the one number or object they remember.
4. **Thumb zone:** primary action in the lower half, reachable one-handed; destructive actions away from it and confirmed.
5. **Targets:** ≥ 48dp (Android) / 44pt (iOS), ≥ 8dp apart.
6. **States:** which of the seven below apply, and what each shows.
7. **Accessibility:** contrast pairs, labels, focus order, font scale 1.3 and 2.0, no colour-only meaning.
8. **Motion:** what moves and why; the reduce-motion path.
9. **Insets:** status bar, nav bar, keyboard, gesture bar.
10. **Text:** no string concatenation for sentences; room for ~30% longer translations; RTL if supported.
11. **Widths:** 320, 360, 412dp phones; tablets and foldables get a capped content width or two panes.
12. **Tokens:** colours, type and radius from the theme; spacing on the scale.
13. **Reuse:** which existing project widgets carry it.

## The seven states

Every data-backed view enumerates these. Not every view needs all seven; say which don't apply.

| State | What it must do | Example |
| --- | --- | --- |
| Ideal | The real content, signature first | Today's total, set big |
| Empty | Why it's empty and the one action that fills it; first-use vs no-results vs cleared | No friends yet → invite; no results → change the filter |
| Loading | Layout stays stable; show the last known value if there is one; skeleton only for slow, known layouts | Leaderboard first load |
| Error | Say what failed in plain words, keep what's still valid on screen, offer retry | "Couldn't update ranks. Retry", local data still shown |
| Offline | Work from local data; mark what's stale; queue actions | "Last updated 2h ago" |
| Success | Confirm briefly, then get out of the way | Snackbar, then back to the list |
| Permission-denied | Explain the cost, link straight to the setting, never a dead end | Notifications off → "Turn on" opens settings |

Riverpod: check `AsyncValue.when(loading:, error:, data:)`. Bloc: every state in the
`BlocBuilder`. `FutureBuilder`/`StreamBuilder`: `hasError` and `waiting` handled. A branch
that returns `SizedBox.shrink()` is an F8 finding unless the view is decorative.
