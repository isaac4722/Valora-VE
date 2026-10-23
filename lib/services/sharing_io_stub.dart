/// ─── Descarga a disco · stub de WEB ─────────────────────────────────────────
/// El navegador no escribe en el filesystem del teléfono: null honesto —
/// el export_sheet ya maneja la respuesta nula con su mensaje humano y el
/// share (share_plus sí soporta web) sigue disponible por separado.
library;

import 'dart:typed_data';

Future<String?> downloadBytes(
  Uint8List bytes, {
  required String fileName,
}) async => null;
