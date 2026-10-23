/// ─── Descarga a disco · implementación VM (dart:io) ─────────────────────────
/// Escribe bytes en la carpeta externa de la app (Android/data/…/files/…) y
/// devuelve la ruta. El usuario la encuentra con la app «Archivos» del
/// teléfono; compartir sigue disponible por separado (regla del dueño
/// v17.2: nunca directo). Web no tiene esta ruta: sharing_io_stub.dart.
library;

import 'dart:io';
import 'dart:typed_data';

import 'package:path_provider/path_provider.dart';

Future<String?> downloadBytes(
  Uint8List bytes, {
  required String fileName,
}) async {
  try {
    final dirs = await getExternalStorageDirectories();
    final base = dirs?.whereType<Directory>().firstOrNull?.path;
    if (base == null) return null;
    final dir = Directory('$base/ValoraVE');
    if (!await dir.exists()) await dir.create(recursive: true);
    final file = File('${dir.path}/$fileName');
    await file.writeAsBytes(bytes, flush: true);
    return file.path;
  } catch (_) {
    return null;
  }
}
