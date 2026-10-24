/// ─── Instalador del canal dev · stub web (v22.4) ────────────────────────────
/// En el navegador no hay filesystem compartible ni instalador de sistema:
/// el APK no puede bajar a un archivo temporal ni lanzarse la instalación.
/// La pantalla detecta `disponible == false` y conserva la vía v22.3
/// (descarga por el navegador del sistema) — contrato honesto, nada finge.
///
/// El constructor acepta (y descarta) el mismo `Dio?` que el impl nativo y
/// `descargar` comparte firma exacta con él: los seams de tests compilan
/// idénticos en ambos mundos del facade. dio es pure-Dart (viaja en el
/// lock, seguro en web); jamás se importa dart:io aquí.
library;

import 'package:dio/dio.dart';

class InstaladorApk {
  const InstaladorApk({Dio? dio});

  /// Web: la instalación in-app no existe. La pantalla vuelve al navegador.
  bool get disponible => false;

  Future<bool> get puedeInstalar async => false;

  Future<String> descargar({
    required String url,
    required String nombre,
    String? carpetaBase,
    void Function(int recibidos, int total)? progreso,
  }) async =>
      throw UnsupportedError(
        'instalador: la descarga in-app no existe en web — usar el navegador',
      );

  Future<bool> instalar(String ruta) async => false;

  Future<bool> abrirAjustesOrigen() async => false;
}
