/// ─── Fotos de ticket · stub de WEB ──────────────────────────────────────────
/// El navegador no tiene File/Directory: no hay fotos-archivo. La API es la
/// MISMA que ticket_files_vm.dart pero honesta — saveTicketFile devuelve
/// null (el caller conserva la data URL), las lecturas/tamaños dan vacío y
/// las operaciones de archivo dan false. Lo PURO se replica idéntico:
/// isTicketPath, decodeDataUrl y collectTicketFiles/restoreTicketFiles
/// respetando ticketFsSupported=false.
library;

import 'dart:convert';
import 'dart:typed_data';

import '../core/models.dart';

/// Carpeta relativa bajo el directorio de documentos (constante compartida).
const String kTicketDir = 'tickets';

/// El filesystem real solo existe en nativo (web: IndexedDB sin File).
bool get ticketFsSupported => false;

/// ¿La referencia apunta a un archivo (y no a un data URL legacy)?
bool isTicketPath(String ref) =>
    ref.isNotEmpty && !ref.startsWith('data:');

/// Sin filesystem: null honesto — el caller conserva la data URL.
Future<String?> saveTicketFile(Uint8List bytes) async => null;

Future<int> ticketFileSize(String ref) async => 0;

/// Decodifica un data URL `data:image/...;base64,…` (o base64 crudo) a
/// bytes. Null honesto si el data URL está corrupto. (Fuente única, igual
/// que en VM.)
Uint8List? decodeDataUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final b64 = raw.contains(',') ? raw.substring(raw.indexOf(',') + 1) : raw;
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

Future<Uint8List?> loadTicketBytes(String? ref) async {
  if (ref == null || ref.isEmpty) return null;
  if (!isTicketPath(ref)) return decodeDataUrl(ref);
  return null; // ruta de archivo: sin filesystem no hay bytes.
}

Future<bool> rewriteTicketFile(String ref, Uint8List bytes) async => false;

Future<bool> deleteTicketFile(String ref) async => false;

Future<Map<String, String>> collectTicketFiles(AppData data) async =>
    const {};

Future<int> restoreTicketFiles(Map<String, dynamic> files) async => 0;
