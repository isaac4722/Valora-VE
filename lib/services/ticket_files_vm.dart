/// ─── Fotos de ticket en ARCHIVO (v20.4) ────────────────────────────────────
///
/// Antes: el JPEG vivía DENTRO del JSON de estado como data URL base64
/// (~200 KB por foto) — cada interacción reserializaba megabytes y el
/// `AppData.toJson` se volvía el cuello de botella de memoria/latencia.
///
/// Ahora (nativo): la foto se escribe una sola vez como JPEG en
/// `<docs>/tickets/<nombre>.jpg` (path_provider) y `Purchase.ticketPhoto`
/// guarda SOLO la ruta relativa — el JSON queda en kilobytes.
/// Web: no hay filesystem → las fotos siguen como data URL (sin cambio).
/// Respaldos viejos: la migración (`migrateTicketPhotosToFiles`) convierte
/// data URLs → archivos en el primer arranque, sin perder ninguna.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:path_provider/path_provider.dart';

import '../core/models.dart';

/// Carpeta relativa bajo el directorio de documentos.
const String kTicketDir = 'tickets';

/// El filesystem real solo existe en nativo (web: IndexedDB sin File).
bool get ticketFsSupported => !kIsWeb;

/// ¿La referencia apunta a un archivo (y no a un data URL legacy)?
bool isTicketPath(String ref) =>
    ref.isNotEmpty && !ref.startsWith('data:');

Directory? _cachedDir;

Future<Directory> _ticketDir() async {
  final cached = _cachedDir;
  if (cached != null) return cached;
  final docs = await getApplicationDocumentsDirectory();
  final dir = Directory('${docs.path}/$kTicketDir');
  if (!await dir.exists()) {
    await dir.create(recursive: true);
  }
  _cachedDir = dir;
  return dir;
}

/// Guarda bytes JPEG como archivo y devuelve la ruta RELATIVA
/// (`tickets/<nombre>.jpg`). Null honesto si no hay filesystem (web) o
/// falla el disco — el caller conserva la data URL en esos casos.
Future<String?> saveTicketFile(Uint8List bytes) async {
  if (!ticketFsSupported || bytes.isEmpty) return null;
  try {
    final dir = await _ticketDir();
    final name =
        't-${DateTime.now().microsecondsSinceEpoch}-${_seq++}.jpg';
    await File('${dir.path}/$name').writeAsBytes(bytes, flush: true);
    return '$kTicketDir/$name';
  } catch (_) {
    return null;
  }
}

int _seq = 0;

/// Archivo absoluto de una ruta relativa. Null si la ref no es de archivo
/// (data URL) o el archivo no existe (borrado por el usuario con un
/// limpiador: la UI muestra el vacío honesto, no un crash).
Future<File?> ticketFile(String ref) async {
  if (!ticketFsSupported || !isTicketPath(ref)) return null;
  try {
    final dir = await _ticketDir();
    final f = File('${dir.path}/${ref.substring(kTicketDir.length + 1)}');
    return await f.exists() ? f : null;
  } catch (_) {
    return null;
  }
}

/// Tamaño real en bytes de una foto-archivo. 0 si no aplica.
Future<int> ticketFileSize(String ref) async {
  final f = await ticketFile(ref);
  if (f == null) return 0;
  try {
    return await f.length();
  } catch (_) {
    return 0;
  }
}

/// Decodifica un data URL `data:image/...;base64,…` (o base64 crudo) a
/// bytes. Null honesto si el data URL está corrupto. (Fuente única: la
/// usa loadTicketBytes y photo_compress — nada duplica la lógica.)
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
  final f = await ticketFile(ref);
  if (f == null) return null;
  try {
    return await f.readAsBytes();
  } catch (_) {
    return null;
  }
}

/// Escribe de vuelta los bytes de una foto-archivo (re-compresión in situ).
/// Devuelve true si pudo escribir. Las data URLs no se tocan aquí.
Future<bool> rewriteTicketFile(String ref, Uint8List bytes) async {
  final f = await ticketFile(ref);
  if (f == null) return false;
  try {
    await f.writeAsBytes(bytes, flush: true);
    return true;
  } catch (_) {
    return false;
  }
}

/// Borra la foto-archivo de una referencia (quitar foto de una compra /
/// reemplazo de foto: sin huérfanos en el disco). False si no había archivo.
Future<bool> deleteTicketFile(String ref) async {
  final f = await ticketFile(ref);
  if (f == null) return false;
  try {
    await f.delete();
    return true;
  } catch (_) {
    return false;
  }
}


/// ─── Respaldo con fotos (v20.4) ────────────────────────────────────────────
/// Las fotos viven en ARCHIVO y el estado guarda rutas; un respaldo que
/// solo serializara `AppData` perdería las fotos al restaurar en otro
/// teléfono. Por eso el respaldo lleva un bloque `ticketFiles` aparte
/// ({ruta relativa: base64}) — el JSON de estado SIGUE en kilobytes y las
/// fotos viajan solo cuando hay respaldo (opt-in / semanal).

/// Colecciona las fotos-archivo referenciadas por [data] como base64.
/// Las data URLs legadas no se tocan (ya viajan inline en `data`).
Future<Map<String, String>> collectTicketFiles(AppData data) async {
  if (!ticketFsSupported) return const {};
  final out = <String, String>{};
  for (final p in data.purchases) {
    final ref = p.ticketPhoto;
    if (ref == null || !isTicketPath(ref) || out.containsKey(ref)) continue;
    final bytes = await loadTicketBytes(ref);
    if (bytes == null) continue; // archivo perdido: se omite con honestidad.
    out[ref] = base64Encode(bytes);
  }
  return out;
}

/// Escribe las fotos de un respaldo ({ruta: base64}) a disco con su ruta
/// relativa original. Devuelve cuántas restauró. Falla suave por foto.
Future<int> restoreTicketFiles(Map<String, dynamic> files) async {
  if (!ticketFsSupported || files.isEmpty) return 0;
  var n = 0;
  for (final entry in files.entries) {
    final ref = entry.key;
    final b64 = entry.value;
    if (ref.isEmpty || !isTicketPath(ref) || b64 is! String || b64.isEmpty) {
      continue;
    }
    final f = await ticketFile(ref);
    if (f == null) continue;
    try {
      await f.writeAsBytes(base64Decode(b64), flush: true);
      n++;
    } catch (_) {
      // Sin espacio o corrupta: se omite — la compra sigue con su ruta y la
      // UI muestra el vacío honesto si el archivo no aparece.
    }
  }
  return n;
}
