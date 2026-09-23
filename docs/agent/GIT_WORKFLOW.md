# GIT_WORKFLOW · Flujo de Git y Builds (es-VE)

## Ramas

- `main`: estable. **Merge SOLO con orden expresa del dueño.**
- `fix/v1.1.0-dp4-paridad`: rama de trabajo actual.
- Sin ramas de experimentación sin permiso (precedente TASK-25: la
  desviación se revirtió completa).

## Commits

- Conventional commits en español: `feat|fix|docs|chore|test(scope): ...`
- Una pantalla/pieza por commit (regla del ciclo de trabajo).
- Ejemplos reales: `feat(v19.8): Análisis web-first + Sala con PIN de
  emojis...`, `fix(9P): conversor 40000→4...`, `docs(v19.6): CHANGELOG +
  bitácora...`.
- Gates ANTES de cada commit: `flutter analyze` 0 + `flutter test` verde.
- Prohibido commitear tokens, API keys o secretos (auth por remote URL
  local del entorno, jamás en archivos).

## Versionado

- Esquema: `1.x.y-beta+z` en `pubspec.yaml`. Prohibido salirse.
- Cada ronda bumpa: `pubspec.yaml` + `kAppVersionVisible` en
  `lib/core/version.dart` + entrada en `CHANGELOG.md`.

## CI (`.github/workflows/ci.yml`)

Cada push/PR: `pub get` → `flutter analyze` (0) → `flutter test`.
ubuntu-latest + Temurin 17 + Flutter 3.47.4 fijado. El paso 8 del ciclo
exige esperar este run hasta verde antes de cerrar turno.

## Builds (`.github/workflows/build.yml`) — orden expresa del dueño

- Cada push a main/fix produce SIEMPRE: **4 APK** (`armeabi-v7a` androids
  viejos · `arm64-v8a` nuevos · `x86_64` emuladores/Intel · `universal`
  todo-en-uno) + **AAB** de Play Store + **UN ZIP**
  `valorave-v{versión}-build-{fecha}-completo.zip` (con LEEME.txt y
  checksums) + símbolos de ofuscación aparte.
- Nomenclatura: `valorave-v{versión}-build-{AAAAMMDD Caracas}-{abi}.apk/.aab`.
- En tags `v*`: la Release adjunta los 6 archivos (4 APK + AAB + ZIP).
- Prohibido retirar un ABI, el AAB o el ZIP sin orden expresa del dueño.
- x86 de 32 bits NO es construible (Flutter no distribuye motor para ese
  ABI) — no cuenta como cobertura faltante.
- `limpieza-artefactos.yml`: red de seguridad diaria por si el repo
  vuelve a privado (público = storage gratis).
