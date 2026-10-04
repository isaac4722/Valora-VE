/// ─── Compresión de fotos de ticket ──────────────────────────────────
/// Re-encode JPEG en memoria con flutter_image_compress (dart:ui NO tiene
/// encoder JPEG: solo PNG — por eso el paquete).
///
/// Reglas del dueño (v17.2):
/// · Las fotos NUEVAS ya salen de image_picker a 1024 px JPEG .72 — aquí solo
///   se re-asegura el tamaño si el picker no recortó de verdad.
/// · compressOldTicketPhotos re-comprime SOLO tickets con más de [age] de
///   antigüedad y SOLO si el re-encode reduce >20 % del peso (nunca degrada
///   una foto reciente ni guarda una «compresión» que engorda).
/// · v20.4: las fotos viven en ARCHIVO (tickets/*.jpg); el re-encode se
///   escribe en el mismo archivo — el JSON de estado ya no carga fotos.
/// · Todo falla suave: cualquier error de decode/encode devuelve null y el
///   caller conserva la foto original tal cual.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../data/store.dart';
import 'ticket_files.dart';

// La implementación única del decode de data URLs (y del acceso a
// fotos-archivo) vive en ticket_files; se re-exporta para no romper a los
// consumidores que hoy importan este archivo.
export 'ticket_files.dart'
    show
        decodeDataUrl,
        deleteTicketFile,
        isTicketPath,
        loadTicketBytes,
        rewriteTicketFile,
        saveTicketFile,
        ticketFileSize,
        ticketFsSupported;

/// Contador de ahorro de la última pasada (bytes liberados · fotos tocadas).
/// Opcional, para diagnóstico: no alimenta ninguna UI por ahora.
int lastSavedBytes = 0;
int lastSavedPhotos = 0;

/// Acumulado de la sesión (todas las pasadas juntas).
int totalSavedBytes = 0;

/// Comprime un JPEG en memoria: re-encode a [quality] con tope de [maxDim]
/// px por el lado mayor (sin upscale). Devuelve null si no logra comprimir
/// (fallo de plataforma O el resultado no es menor que el original): en
/// ambos casos el caller debe conservar los bytes de entrada.
Future<Uint8List?> compressJpeg(
  Uint8List bytes, {
  int quality = 60,
  int maxDim = 1024,
}) async {
  if (bytes.isEmpty) return null;
  try {
    final out = await FlutterImageCompress.compressWithList(
      bytes,
      quality: quality.clamp(1, 100),
      format: CompressFormat.jpeg,
      minWidth: maxDim,
      minHeight: maxDim,
      keepExif: false,
    );
    if (out.isEmpty) return null;
    // Honestidad: si el re-encode NO reduce, no compensa — null = conservar.
    if (out.lengthInBytes >= bytes.lengthInBytes) return null;
    return out;
  } catch (_) {
    return null; // fallo de plataforma → caller conserva el original.
  }
}

/// Recorre las compras del libro y re-comprime los tickets VIEJOS (date más
/// antigua que [age], default 30 días) a calidad 60 / máx 1024 px. v20.4:
/// · Foto-ARCHIVO (tickets/x.jpg): el re-encode se escribe en el mismo
///   archivo — el JSON nunca ve bytes de imagen.
/// · Data URL legada (respaldo viejo importado): en nativo se MIGRA a
///   archivo (el campo pasa a ruta relativa); en web se re-encoda in place.
/// Solo toca la compra si el nuevo peso es al menos un 20 % menor. Las
/// fotos recientes NO se tocan.
///
/// Llamar en fire-and-forget tras guardar una compra:
/// `unawaited(compressOldTicketPhotos(store));`
Future<void> compressOldTicketPhotos(
  AppStore store, {
  Duration age = const Duration(days: 30),
}) async {
  final cutoff = DateTime.now().subtract(age);
  var saved = 0, touched = 0;
  for (final p in store.purchases) {
    final ref = p.ticketPhoto;
    if (ref == null || ref.isEmpty) continue;
    if (p.date.isAfter(cutoff)) continue; // fotos recientes: intocables.
    final bytes = await loadTicketBytes(ref);
    if (bytes == null || bytes.isEmpty) continue;
    final out = await compressJpeg(bytes, quality: 60, maxDim: 1024);
    if (out == null) continue; // falló o no reduce → se conserva.
    final reduction = bytes.lengthInBytes - out.lengthInBytes;
    if (reduction <= bytes.lengthInBytes * 0.20) continue; // <20 % → no vale.
    if (isTicketPath(ref)) {
      // Foto-archivo: reescritura in situ; la compra NO cambia (cero JSON).
      if (await rewriteTicketFile(ref, out)) {
        saved += reduction;
        touched++;
      }
      continue;
    }
    // Data URL legada: migrar a archivo en nativo (el JSON adelgaza);
    // en web no hay filesystem — re-encode in place como siempre.
    final path = await saveTicketFile(out);
    if (path != null) {
      store.updatePurchase(p.id, p.copyWith(ticketPhoto: path));
    } else {
      store.updatePurchase(
        p.id,
        p.copyWith(ticketPhoto: 'data:image/jpeg;base64,${base64Encode(out)}'),
      );
    }
    saved += reduction;
    touched++;
  }
  lastSavedBytes = saved;
  lastSavedPhotos = touched;
  totalSavedBytes += saved;
}

/// Migración v20.4 (un solo uso, primer arranque nativo): convierte TODAS
/// las data URLs del libro a archivos `tickets/*.jpg` y actualiza cada
/// compra con su ruta relativa. Devuelve cuántas fotos migró. Falla suave:
/// si una foto no puede migrarse, conserva su data URL (nada se pierde).
Future<int> migrateTicketPhotosToFiles(AppStore store) async {
  if (!ticketFsSupported) return 0;
  var migrated = 0;
  for (final p in store.purchases) {
    final ref = p.ticketPhoto;
    // Solo migran data URLs: las rutas de archivo ya viven fuera del JSON.
    if (ref == null || ref.isEmpty || isTicketPath(ref)) continue;
    final bytes = await loadTicketBytes(ref);
    if (bytes == null || bytes.isEmpty) continue;
    final path = await saveTicketFile(bytes);
    if (path == null) continue; // disco lleno: queda como data URL.
    store.updatePurchase(p.id, p.copyWith(ticketPhoto: path));
    migrated++;
  }
  return migrated;
}
