# Lowder en la rama test/lowder (banco de pruebas)

**Qué es esta rama.** Un patio de pruebas de [Lowder](https://pub.dev/packages/lowder)
(0.1.12), aislado de la app real. La app de verdad — Hive, providers,
router, widgets de escritorio — vive intacta en `fix/v1.1.0-dp4-paridad`;
aquí SOLO se experimenta con pantallas declaradas en archivos `.low`.

**Qué es (y qué no es) Lowder.** No es un editor que se conecta al repo:
es un paquete que se integra al proyecto y renderiza pantallas descritas
en `.low` (JSON); el editor es una interfaz web que Lee y ESCRIBE esos
archivos dentro del propio proyecto. Verificado contra el paquete
publicado y su repositorio (HCaseira/lowder_flutter).

## Estructura montada

| Pieza | Ruta | Para qué |
|-------|------|----------|
| Entry secundario | `lib/lowder_entry.dart` | `ValoraLowder extends Lowder` con la lista de `SolutionSpec` (nombre + filePath por archivo de pantallas) y SU PROPIO `main()`. |
| Entry del editor | `lib/main.dart` | Delegado de 3 líneas al anterior. Necesario porque `dart run lowder` compila `lib/main.dart` para web sin permitir otro target, y la app real usa `dart:io` (no compila a JS). |
| Pantallas | `assets/lowder/demo.low` | Demo de 2 pantallas con `routeName`, `Navigate` (con estado) y `Pop`. |
| Dependencia | `pubspec.yaml` | `lowder: ^0.1.12` + carpeta `assets/lowder/` declarada. |

## Correr el editor

```bash
git checkout test/lowder
flutter pub get
dart run lowder
# Compila lib/main.dart para web (unos segundos) y sirve:
#   http://0.0.0.0:8787  →  editor en http://localhost:8787/editor.html
```

En el editor: crear pantalla → elegir widget raíz (p. ej. `Material`) →
armar el árbol en el panel de propiedades → **guardar** (escribe el
`.low`). Correr la app para verlas: `flutter run` (el `main.dart` de esta
rama ya delega en el entry Lowder). Opciones del CLI: `-p <puerto>` y
`-a <dirección>`.

## Cómo se conecta (y cómo NO) con la app real

Lowder trae su propio mundo; los puentes son manuales:

- **Enrutamiento propio.** Las pantallas Lowder se registran por el
  `routeName` de sus `properties` y navegan entre sí con las acciones
  `Navigate` (`jumpToRoute`/`jumpToScreen`, con `state` y callbacks
  `onPop`) y `Pop`. No hay integración con go_router: para saltar de una
  pantalla nativa de la app a una Lowder (o al revés) se escribe a mano
  (p. ej. desde un botón nativo, montar la pantalla Lowder como página).
- **Estado propio (Bloc).** Lowder usa su sistema Bloc interno
  (`BlocState`, `SetState`, `state.xxx` en propiedades). NO se sincroniza
  solo con el `AppStore` (provider/ChangeNotifier) de la app: cualquier
  puente de datos se hace a mano vía callbacks o `InheritedWidget`
  alrededor del widget Lowder.
- **Sin integración mágica con los widgets existentes.** Los widgets del
  design system de ValoraVE no existen en Lowder hasta que se registren:
  crear una clase con `IWidgets`/`IActions`/`IProperties` y pasarla al
  `SolutionSpec` correspondiente.

## Límites conocidos (verificados)

- El editor siempre compila `lib/main.dart` (por eso el delegado de esta
  rama); no hay flag para otro target en 0.1.12.
- `dart:io` no compila a web — el entry Lowder no importa nada de la app
  real, y por eso esta rama mantiene las pruebas funcionando (los tests
  no importan `main.dart`).
- CI/Build del repo disparan solo en main y fix/v1.1.0-dp4-paridad: los
  pushes de esta rama NO generan runs (a propósito — es experimental).
  Los gates locales (analyze/test) sí se corrieron antes de cada commit.
