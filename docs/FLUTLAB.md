# FlutLab · compatibilidad del repo

Investigación pedida por el dueño (v19.4): verificar si FlutLab
(<https://flutlab.io>) necesita la estructura estándar de Flutter en la
raíz del repo y dejarla lista.

## Qué es FlutLab (verificado)

IDE de Flutter 100 % en línea. Importa proyectos desde GitHub y los
compila en su granja de builds — APK para Android y builds de iOS sin
tener una Mac. Para reconocer la raíz de un proyecto usa el mismo
criterio que la herramienta `flutter`: un `pubspec.yaml` en la raíz con
las carpetas de plataforma al lado.

## Estado de la estructura (después de v19.4)

| Pieza | Estado |
|---|---|
| `pubspec.yaml` en la raíz | Ya estaba |
| `lib/` | Ya estaba |
| `android/` | Ya estaba (applicationId `ve.valorave.app`) |
| `test/` | Ya estaba (185 tests) |
| `assets/` (brand/flags/fonts) | Ya estaba |
| `.gitignore` | Ya estaba — ignora `.dart_tool/`, `build/`, keystores y secretos |
| `ios/` | **Añadido en v19.4** (`flutter create --platforms=ios --org ve.valorave`) |
| `web/` | **Añadido en v19.4** (`flutter create --platforms=web`) |

`ios/` trae su propio `.gitignore` (Pods, DerivedData, xcuserdata y los
generados de Xcode). El `.gitignore` de la raíz NO se tocó: lo que ya
estaba explícitamente agregado se conserva tal cual.

## Decisiones

- **`pubspec.lock` se mantiene commiteado.** La nota de FlutLab lo
  lista entre los «generados», pero para APLICACIONES la
  recomendación oficial de Dart (dart.dev · «What not to commit») es
  commitearlo: builds reproducibles en FlutLab, GitHub Actions y en
  cualquier máquina. El repo ya lo tenía — no se quita.
- **`web/` e `ios/` son andamiaje.** La app es Android-first: plugins
  como `nearby_connections`, `flutter_local_notifications`,
  `workmanager`, `home_widget` y `local_auth` no tienen implementación
  web, así que un BUILD WEB desde FlutLab no es un objetivo soportado
  (compila andamiaje, no producto). El build de APK/AAB — que es lo
  que FlutLab se usa — queda cubierto por `android/` + CI propio.
- **iOS sin Mac**: FlutLab compila iOS en su granja; el `ios/` añadido
  es el estándar de la plantilla (sin firma ni capacidades extra).
  Firmar para la App Store sigue requiriendo las credenciales del
  dueño en FlutLab.

## Cómo probar FlutLab con este repo

1. Cuenta en flutlab.io → Import → GitHub → `isaac4722/Valora-VE`
   (privado: pide un token con acceso al repo).
2. Rama a compilar: la que se quiera probar (`safe/v1.1.0-dp4-paridad`
   es la de trabajo actual; antes `fix/v1.1.0-dp4-paridad`).
3. Build Android (APK). Los artefactos oficiales siguen saliendo del
   GitHub Actions del repo (4 APK + AAB + ZIP, regla §9 de AGENT.md) —
   FlutLab queda como vía rápida de prueba, no como canal de release.
