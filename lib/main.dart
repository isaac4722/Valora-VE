/// ─── Entrada de la rama test/lowder (banco de pruebas de Lowder) ───────────
/// La APP REAL vive intacta en fix/v1.1.0-dp4-paridad — su main.dart (Hive +
/// providers + router + biométrico) no se tocó; esta rama existe SOLO para
/// probar Lowder (Fase 4 del dueño).
///
/// ¿Por qué un delegado en vez de un entry aparte? El editor de Lowder
/// (`dart run lowder`) compila `lib/main.dart` para web SIN permitir otro
/// target, y la app real importa dart:io (sharing, lan_hub, workmanager)
/// que no compila a JS. Este entry delega en lowder_entry.dart para que el
/// editor levante limpio sin arrastrar la app. Para volver a la app real:
/// `git checkout fix/v1.1.0-dp4-paridad`.
library;

import 'lowder_entry.dart' as lowder;

void main() => lowder.main();
