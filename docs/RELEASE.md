# Checklist de release

Antes de crear un tag `v*` (el workflow `build.yml` publica la Release):

## 1. Gates locales (obligatorios)
- [ ] `flutter analyze` → **0 issues** (estándar del repo, AGENT.md · Regla 3).
- [ ] `flutter test` → suite verde completa (unit + widget).

## 2. Integration tests SOLO LOCAL (decisión §4.17)
CI **no** corre integration tests: se ejecutan en un emulador/dispositivo
antes de cada tag:
```
flutter test integration_test/app_test.dart -d <emulador>
```
- [ ] arranque → onboarding → tablero honesto
- [ ] conversión EUR→COP con arista
- [ ] alta de producto → precio → meta cumplida
- [ ] compra completa → checkout → asiento
- [ ] respaldo → borrar todo → fusión recupera
- [ ] (opcional) sala local con dos instancias (emulador + host)

## 3. Numeración
- [ ] Versión `1.x.y-beta+z` en `pubspec.yaml` (AGENT.md · Regla 5: prohibido
      salir del formato).
- [ ] Tag `v<versión-sin-build>`: ej. `v1.0.0-beta` ↔ `1.0.0-beta+1`.

## 4. Publicación
- [ ] Commit con conventional commit es-VE (`feat:`, `fix:`, `chore:`…).
- [ ] Push a `main` (el Build de main valida binarios sin publicar Release).
- [ ] `git tag v…` + push del tag → `build.yml` publica la GitHub Release
      con 4 APK (armeabi-v7a · arm64-v8a · x86_64 · **universal
      todo-en-uno**) + AAB, firmados con el keystore de secrets y
      ofuscados (`--obfuscate --split-debug-info`). El job `release`
      descarga los APK de la matriz del mismo run y exige que estén los
      5 archivos (`fail_on_unmatched_files: true`): nada se publica a
      medias.
- [ ] Verificar Actions verde; si falla: causa raíz (PROHIBIDO desactivar gates).
- [ ] Descargar artefactos y verificar: APK instala · `apksigner verify` OK.

## 5. Post-release
- [ ] `CHANGELOG.md` con entrada de la versión.
- [ ] Sección nueva en `progress.md` (plantilla AGENT.md).
