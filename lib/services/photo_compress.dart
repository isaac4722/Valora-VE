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
/// · Todo falla suave: cualquier error de decode/encode devuelve null y el
///   caller conserva la foto original tal cual.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_image_compress/flutter_image_compress.dart';

import '../data/store.dart';

/// Contador de ahorro de la última pasada (bytes liberados · fotos tocadas).
/// Opcional, para diagnóstico: no alimenta ninguna UI por ahora.
int lastSavedBytes = 0;
int lastSavedPhotos = 0;

/// Acumulado de la sesión (todas las pasadas juntas).
int totalSavedBytes = 0;

/// Decodifica un data URL 'data:image/...;base64,…' (o base64 crudo) a bytes.
/// Null honesto si el data URL está corrupto.
Uint8List? decodeDataUrl(String? raw) {
  if (raw == null || raw.isEmpty) return null;
  try {
    final b64 = raw.contains(',') ? raw.substring(raw.indexOf(',') + 1) : raw;
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

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
/// antigua que [age], default 30 días) a calidad 60 / máx 1024 px, guardando
/// el resultado como data URL JPEG igual que hoy. Solo toca la compra si el
/// nuevo peso es al menos un 20 % menor. Las fotos recientes NO se tocan.
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
    final raw = p.ticketPhoto;
    if (raw == null || raw.isEmpty) continue;
    if (p.date.isAfter(cutoff)) continue; // fotos recientes: intocables.
    final bytes = decodeDataUrl(raw);
    if (bytes == null || bytes.isEmpty) continue;
    final out = await compressJpeg(bytes, quality: 60, maxDim: 1024);
    if (out == null) continue; // falló o no reduce → se conserva.
    final reduction = bytes.lengthInBytes - out.lengthInBytes;
    if (reduction <= bytes.lengthInBytes * 0.20) continue; // <20 % → no vale.
    store.updatePurchase(
      p.id,
      p.copyWith(
          ticketPhoto:
              'data:image/jpeg;base64,${base64Encode(out)}'),
    );
    saved += reduction;
    touched++;
  }
  lastSavedBytes = saved;
  lastSavedPhotos = touched;
  totalSavedBytes += saved;
}
