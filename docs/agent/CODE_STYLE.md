# CODE_STYLE · Estilo de código y convenciones (ValoraVE)

Consulta obligatoria en `3_IMPLEMENT`. Fuente de verdad del linter:
`analysis_options.yaml` (flutter_lints). Nada de esto se relaja para
"ponerse verde" (AGENT.md · Nunca hacer).

## Dart / Flutter

- **Formato:** `dart format .` antes de cada commit. El estilo de llaves y
  saltos lo decide el formateador, no el autor.
- **Lint base:** `flutter_lints/flutter.yaml`. Única relajación consciente:
  `constant_identifier_names: false` — códigos ISO (USD, VES, COP, EUR,
  BRL, MXN) son identificadores estándar del dominio monetario y van en
  mayúsculas por diseño.
- **Nombres:** archivos `snake_case.dart`; clases/enum `PascalCase`;
  miembros privados `_camelCase`. Un archivo puede exportar varias clases
  del mismo agregado (ver `lib/core/models.dart`), pero una pantalla
  grande se parte en `*_screen.dart` + `*_panels.dart`/`*_sheet.dart`
  (ej.: `insights_screen.dart` + `insights_panels.dart`).
- **Imports:** orden `dart:` → `package:flutter/…` → paquetes → relativos;
  sin wildcards; sin imports muertos (analyze los caza).
- **Constructores `const`** donde el sistema lo permita (menos rebuilds).
- **Recursos:** todo `AnimationController`, `TextEditingController`,
  `FocusNode`, `StreamSubscription`, `Timer`, `Socket` y amigos se
  cancela/desecha en `dispose()`. Las fugas de controllers son bugs de
  primera clase (v19.8 arregló 6; que no vuelvan).

## Idioma y texto

- **es-VE natural** en TODO texto visible: «tú» (no «usted»), términos
  locales (vuelto, cesta, caja, punto), números con coma decimal.
- **Cifras SIEMPRE** vía `lib/core/fmt.dart` (`fmtMoney`, `fmtRate`,
  `fmtQty`, `fmtDate`…). Prohibido `toString()` o `DateFormat` ad-hoc en
  pantallas — el formato es-VE (1.234,56 · 02-feb-2026) vive en UN sitio.
- **Sin «tells» de IA**: prohibido «¡Claro!», «vamos a…», emojis de
  relleno o prosa explicativa en la UI. Si duda, pasar `humanizer`
  (skill, 3_IMPLEMENT post-UI).
- Comentarios de código: explican el POR QUÉ, en español, breves.

## UI (remite a docs/DESIGN-SYSTEM.md)

- Tokens de `lib/core/theme.dart` + componentes de `lib/widgets/ui.dart`.
  Prohibido hardcodear colores/espaciados/fuentes nuevas: se usan los del
  sistema (§8 «El Instrumento»).
- Borde `border` SIEMPRE 100 % de opacidad. Sin gradientes, sin
  tricolor, sin `backdrop-filter` en scroll.
- Cifras héroe y tablas con `FontFeature.tabularFigures()` (Space Grotesk
  display, Inter cuerpo).
- Estados vacíos con jerarquía humana (InlineHint), no pantallas rotas.
- Targets táctiles ≥48dp (consultar `mobile-design` en 2_PLAN).

## Prohibido en `lib/` (el auditor del gate lo caza)

- Mocks de ningún tipo (`Mock*`, mockito/mocktail en lib/).
- `AppStateScope`, `localStorage`, `ServiceWorker` (patrones web).
- Cifras de mercado, tasas o datos de usuario inventados.
- Tokens, API keys o secretos hardcodeados.
- `print()` en producción — usar el registro existente del módulo.

## Commits

Conventional commits EN ESPAÑOL, 1 pieza por commit:
`feat(conversor): …` · `fix(sala): …` · `polish(9P·análisis): …` ·
`docs(agent): …` · `chore(ci): …` · `test(store): …`.
Ver `docs/agent/GIT_WORKFLOW.md` para el flujo completo.
