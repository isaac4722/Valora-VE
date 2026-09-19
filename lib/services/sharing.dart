/// ─── Compartir: textos, enlaces de lista, PNG (share_plus) ─────────────────
/// El PNG 1080×1080 del conversor y 1080×1350 de constancias se dibuja en
/// canvas Flutter (ui.Image → PNG bytes) — aquí están los helpers comunes.
/// v18.0: renderOffstagePng compone documentos FUERA DE PANTALLA (causa
/// raíz de «No se puede generar»: capturar el boundary visible de una
/// tarjeta que el scroll ya recicló/destruyó devuelve null).
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
    lines.add(
      '• ${item.quantity} × ${item.name} · ${fmtCurrency(item.price, CurrencyX.from(item.currency))}'
      '${item.checked ? ' ✓' : ''}',
    );
  }
  lines.add('');
  for (final e in totals.byCurrency.entries) {
    lines.add('Subtotal ${e.key.code}: ${fmtMoney(e.value, e.key)}');
  }
  lines.add('Total USD: ${fmtUSD(totals.usd)}');
  await SharePlus.instance.share(ShareParams(text: lines.join('\n')));
}

/// Captura un widget (RepaintBoundary) a PNG bytes 1080 px de ancho.
/// Endurecido (v18.0): boundary muerto/desmontado/sin tamaño → null limpio
/// en vez de excepción; el llamante decide el mensaje humano.
/// Endurecido (v19.4): el render del key puede NO ser el RepaintBoundary
/// (key sobre un widget compuesto) — se SUBE hasta el boundary que lo
/// envuelve. El cast ciego anterior reventaba y el catch lo tragaba:
/// «No pude generar la tarjeta» SIEMPRE (bug de la tarjeta del conversor).
Future<Uint8List?> captureWidget(
  GlobalKey key, {
  int targetWidth = 1080,
}) async {
  try {
    RenderObject? node = key.currentContext?.findRenderObject();
    while (node != null && node is! RenderRepaintBoundary) {
      final parent = node.parent;
      node = parent is RenderObject ? parent : null;
    }
    final boundary = node is RenderRepaintBoundary ? node : null;
    if (boundary == null || !boundary.attached || !boundary.hasSize) {
      return null;
    }
    final image = await boundary.toImage(pixelRatio: 3);
    return await _resizeToWidth(image, targetWidth);
  } catch (_) {
    return null; // sin cero: el documento compartible nunca tumba la app
  }
}

/// Reescala una imagen al ancho objetivo (calidad 1080 px).
Future<Uint8List?> _resizeToWidth(ui.Image image, int targetWidth) async {
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

/// Renderiza un widget FUERA DE PANTALLA y lo devuelve como PNG (v18.0).
///
/// El documento se monta en el Overlay raíz posicionado en left:-4000:
/// PINTADO de verdad (Offstage NO pinta y RepaintBoundary.toImage sale
/// vacío) pero invisible para el usuario. Se dejan correr DOS frames para
/// que layout, fuentes e imágenes terminen, y se rasteriza a 3× con ancho
/// lógico fijado ([width] — default 360 → 1080 px finales) porque las filas
/// con Expanded necesitan un ancho acotado.
///
/// Este es el camino propio de los generadores (Lista/Totales y
/// Constancia): no dependen de que la tarjeta visible siga montada.
Future<Uint8List?> renderOffstagePng(
  BuildContext context,
  Widget doc, {
  int targetWidth = 1080,
  double width = 360,
}) async {
  OverlayEntry? entry;
  final key = GlobalKey();
  try {
    final overlay = Overlay.of(context, rootOverlay: true);
    entry = OverlayEntry(
      builder: (_) => Positioned(
        left: -4000,
        top: 0,
        width: width,
        child: RepaintBoundary(
          key: key,
          child: Material(type: MaterialType.transparency, child: doc),
        ),
      ),
    );
    overlay.insert(entry);
    // Dos frames: montaje+layout y settle de pintura/fuentes.
    await WidgetsBinding.instance.endOfFrame;
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        key.currentContext?.findRenderObject() as RenderRepaintBoundary?;
    if (boundary == null || !boundary.attached || !boundary.hasSize) {
      return null;
    }
    final image = await boundary.toImage(pixelRatio: 3);
    return await _resizeToWidth(image, targetWidth);
  } catch (_) {
    return null;
  } finally {
    entry?.remove();
  }
}

/// Comparte PNG por WebShare nativo de Android.
Future<void> sharePng(Uint8List bytes, String name) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: 'image/png')],
    ),
  );
}

/// Comparte un archivo de texto (CSV/JSON) con nombre sugerido.
Future<void> showShareFile(BuildContext context, String name, String text) =>
    shareFile(name, text);

/// Comparte un archivo de texto SIN contexto (v19.8: el componente unificado
/// de exportación ejecuta fuera del árbol de widgets).
Future<void> shareFile(String name, String text) async {
  await SharePlus.instance.share(
    ShareParams(
      text: 'ValoraVE · $name',
      files: [
        XFile.fromData(
          Uint8List.fromList(utf8.encode('\ufeff$text')),
          name: name,
          mimeType: name.endsWith('.json') ? 'application/json' : 'text/csv',
        ),
      ],
    ),
  );
}

/// Guarda texto plano (CSV/JSON) en la carpeta de la app y devuelve la ruta.
/// Gemelo de [downloadBytes] para fuentes que solo producen texto.
Future<String?> downloadText(String text, {required String fileName}) {
  return downloadBytes(
    Uint8List.fromList(utf8.encode('\ufeff$text')),
    fileName: fileName,
  );
}

/// Descarga (guarda) bytes SIN abrir el share nativo: escribe en la carpeta
/// externa de la app (Android/data/…/files/ValoraVE) y devuelve la ruta.
/// El usuario la encuentra con la app «Archivos» del teléfono; compartir
/// sigue disponible por separado (regla del dueño v17.2: nunca directo).
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
