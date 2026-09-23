# TESTING · Estrategia de tests (es-VE)

## Gates (obligatorios antes de cada commit)

| Gate | Comando | Criterio |
|---|---|---|
| Análisis | `flutter analyze` | 0 issues |
| Suite | `flutter test` | 100 % verde |
| Uno a la vez | `flutter test test/ruta/archivo_test.dart` | verde |
| Todo junto | `bash scripts/quality_gate.sh` | verde (analyze + test + auditoría) |

Línea base actual: **196 tests verdes** (v19.8). El CI (`.github/workflows/ci.yml`)
repite pub get → analyze → test en ubuntu-latest con Flutter 3.47.4.

## Estructura

- `test/` refleja la estructura de `lib/`: un `_test.dart` por pieza
  (`room_test`, `board_test`, `store_test`, `sharing_test`, `fmt_test`,
  `insights_utils_test`, `app_widgets_test`, `widgets_test`, etc.).
- `integration_test/app_test.dart`: 5 flujos que corren en host
  (`flutter test integration_test/app_test.dart -d flutter-tester`).

## Cómo se testea aquí

- **Seams + fakes en `test/`** (nunca mocks en `lib/`): ej. `FakeLink
  implements RoomLink` graba lo enviado y deja inyectar lo que llega —
  el controlador no sabe que no hay radio.
- Lógica pura en helpers testables (`insights_utils`, `fmt`,
  `currencies`) → tests unitarios directos.
- Widget tests con `SharedPreferences` real en el árbol (como
  `appProviders`) y tour ya visto para que la barrera del coach no
  bloquee taps.
- PNG/tarjetas: patrón híbrido `pumps` + `runAsync` (el `toImage` del
  engine no fluye con solo pumps) — ver `sharing_test.dart`.
- Sin `pumpAndSettle` cuando hay animaciones infinitas (pulso del foco):
  esperar por condición.

## Reglas del contrato

- Prohibido debilitar tests o relajar `analyze` para «ponerse verde».
- Test falla y no entiendes la causa raíz tras 2 intentos → preguntar.
- Todo cambio de comportamiento viene con su test (Definición de Hecho).
