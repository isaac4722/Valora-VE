/// ─── Punto de entrada Lowder (SOLO rama test/lowder) ──────────────────────
/// Esta rama existe para PROBAR Lowder sin tocar la app real, que sigue
/// intacta en fix/v1.1.0-dp4-paridad. Lowder NO es un editor que se conecta
/// al repo: es un paquete que se integra al proyecto y genera pantallas
/// desde archivos .low; el editor (`dart run lowder`) abre una interfaz web
/// que lee y escribe esos archivos DENTRO de este mismo proyecto.
///
/// Cómo correr:
///   1. `flutter pub get`
///   2. `dart run lowder`            → compila y sirve
///   3. abrir http://localhost:8787/editor.html
///   4. crear/editar pantallas y GUARDAR — escribe assets/lowder/*.low
///   5. `flutter run` (main.dart de ESTA rama delega aquí) para verlas vivas
///
/// Detalles y puentes con la app real en docs/LOWDER.md.
library;

import 'package:flutter/material.dart';
import 'package:lowder/widget/lowder.dart';

Future<void> main() async {
  runApp(ValoraLowder());
}

/// Raíz Lowder de la rama de prueba: registra las «soluciones» (.low) que
/// el editor lee y escribe. Cada SolutionSpec = un archivo de pantallas con
/// nombre propio; añadir más pantallas = sumarlas al .low (o crear otro
/// archivo y registrar otro SolutionSpec).
class ValoraLowder extends Lowder {
  ValoraLowder({super.key}) : super('ValoraVE · Lowder');

  @override
  List<SolutionSpec> get solutions => [
        SolutionSpec('Demo', filePath: 'assets/lowder/demo.low'),
      ];
}
