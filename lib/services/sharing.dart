/// ─── Compartir: textos, enlaces de lista, PNG (share_plus) ─────────────────
/// El PNG 1080×1080 del conversor y 1080×1350 de constancias se dibuja en
/// canvas Flutter (ui.Image → PNG bytes) — aquí están los helpers comunes.
library;

import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/currencies.dart';
import '../core/fmt.dart';
import '../data/store.dart';

/// Comparte el texto de totales de la Lista (shareTotals del web).
Future<void> shareTotalsText(
  BuildContext context,
  AppStore store,
  ({double usd, Map<Currency, double> byCurrency, int units}) totals, {
  RateContext? ctx,
}) async {
  final lines = <String>['Mi lista de compras — ValoraVE', ''];
  for (final item in store.cart) {
    lines.add('• ${item.quantity} × ${item.name} · ${fmtCurrency(item.price, CurrencyX.from(item.currency))}'
        '${item.checked ? ' ✓' : ''}');
  }
  lines.add('');
  for (final e in totals.byCurrency.entries) {
    lines.add('Subtotal ${e.key.code}: ${fmtMoney(e.value, e.key)}');
  }
  lines.add('Total USD: ${fmtUSD(totals.usd)}');
  await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
}

/// Captura un widget (RepaintBoundary) a PNG bytes 1080 px de ancho.
Future<Uint8List?> captureWidget(GlobalKey key, {int targetWidth = 1080}) async {
  final boundary = key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
  if (boundary == null) return null;
  final image = await boundary.toImage(pixelRatio: 3);
  final ratio = targetWidth / image.width;
  if (ratio < 1) {
    final w = targetWidth;
    final h = (image.height * ratio).round();
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.scale(ratio, ratio);
    canvas.drawImage(image, ui.Offset.zero, ui.Paint());
    final scaled = await recorder.endRecording().toImage(w, h);
    final data = await scaled.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  }
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data?.buffer.asUint8List();
}

/// Comparte PNG por WebShare nativo de Android.
Future<void> sharePng(Uint8List bytes, String name) async {
  await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, name: name, mimeType: 'image/png')]));
}

/// Comparte un archivo de texto (CSV/JSON) con nombre sugerido.
Future<void> showShareFile(BuildContext context, String name, String text) async {
  await SharePlus.instance.share(ShareParams(
    text: 'ValoraVE · $name',
    files: [
      XFile.fromData(
        Uint8List.fromList(utf8.encode('\ufeff$text')),
        name: name,
        mimeType: name.endsWith('.json') ? 'application/json' : 'text/csv',
      ),
    ],
  ));
}

/// Descarga (guarda) bytes SIN abrir el share nativo: escribe en la carpeta
/// externa de la app (Android/data/…/files/ValoraVE) y devuelve la ruta.
/// El usuario la encuentra con la app «Archivos» del teléfono; compartir
/// sigue disponible por separado (regla del dueño v17.2: nunca directo).
Future<String?> downloadBytes(Uint8List bytes, {required String fileName}) async {
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

