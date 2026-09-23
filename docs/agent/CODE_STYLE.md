# CODE_STYLE · Estilo de código (es-VE)

Operativo y corto. Lo que no está aquí manda al linter y al sentido común.

## Base

- Linter: `flutter_lints` vía `analysis_options.yaml`. Gate: **0 issues**.
- `constant_identifier_names` DESACTIVADO a propósito: los códigos ISO
  (USD, VES, COP, EUR, BRL, MXN) son identificadores estándar del dominio
  monetario y van en mayúsculas por diseño.
- `dart format` antes de cada commit (los diffs de 23+ archivos formateados
  son norma aceptada, no ruido).

## Nombres y forma

- Archivos `snake_case.dart`; clases `PascalCase`; privado `_camelCase`.
- Todo archivo de `lib/` abre con un comentario `///` de bloque
  (`/// ─── Título ───`) que explica QUÉ hace y POR QUÉ, en español.
- Texto visible al usuario: **español es-VE** siempre (cifras con coma
  decimal y punto de miles vía `lib/core/fmt.dart`).

## Patrones del repo

- **Estado/DI:** `provider` + `ChangeNotifier` (decisión cerrada del
  dueño §4). La composición usa `package:nested`.
- **Seams para tests:** la radio/plataforma va detrás de una interfaz
  (ej. `RoomLink` en `lib/room/room_transport.dart`); los tests
  inyectan enlaces falsos. Nada de mocks en `lib/`.
- **UI:** sistema de diseño en `lib/core/theme.dart` +
  `lib/widgets/ui.dart` (tokens DP4/DP5). Evolucionar, jamás reemplazar.
- **Versión visible:** `kAppVersionVisible` en `lib/core/version.dart`
  es la fuente única del pie de documentos (no hardcodear).

## Prohibido en `lib/`

Mocks, `AppStateScope`, `localStorage`/`ServiceWorker` u otros patrones
web que no apliquen, cifras de mercado inventadas, tokens/API keys.

## Commits

Conventional commits en español: `feat|fix|docs|chore|test(scope): ...`.
Detalle en `docs/agent/GIT_WORKFLOW.md`.
