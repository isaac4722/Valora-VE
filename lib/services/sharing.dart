/// ─── Compartir: textos, enlaces de lista, PNG (share_plus) ─────────────────
/// CONVENCIÓN ÚNICA DE RASTERIZADO (v31): TODOS los documentos compartibles
/// (tarjetas de marca y constancias) se componen a **360 px LÓGICOS** de
/// ancho — el «papel de teléfono» para el que está diseñada la app, con su
/// sistema tipográfico real (11 · 13,5 · 17 · 30) — y se rasterizan a
/// **pixelRatio 3 → 1080 px físicos**. Una sola escala para todos los
/// artefactos: la tipografía de cualquier imagen compartida tiene la misma
/// proporción y ninguna tarjeta sale con texto diminuto.
/// v18.0: renderOffstagePng compone documentos FUERA DE PANTALLA (causa
/// raíz de «No se puede generar»: capturar el boundary visible de una
/// tarjeta que el scroll ya recicló/destruyó devuelve null).
library;

import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:share_plus/share_plus.dart';

import '../core/currencies.dart';
import '../core/fmt.dart';
import '../data/store.dart';
import '../widgets/ui.dart';
import 'sharing_io.dart'
    if (dart.library.html) 'sharing_io_stub.dart' as io_impl;

/// Copia el texto de totales de la Lista al PORTAPAPELES (v28 · regla del
/// dueño: el texto se COPIA, nunca se comparte; Compartir es solo para
/// imágenes — ver export_sheet.dart).
void copyTotalsText(
  BuildContext context,
  AppStore store,
  ({double usd, Map<Currency, double> byCurrency, int units}) totals, {
  RateContext? ctx,
}) {
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
  copiarAlPortapapeles(context, lines.join('\n'), 'Lista copiada');
}

/// Busca el RenderRepaintBoundary SUBIENDO por el árbol (v19.4): el key
/// puede vivir sobre un widget compuesto cuyo render directo no es un
/// boundary — el cast ciego anterior reventaba y el catch lo tragaba
/// («No pude generar la tarjeta» SIEMPRE). Nunca lanza; null si no hay
/// boundary saludable (desmontado o sin tamaño).
RenderRepaintBoundary? _findBoundary(RenderObject? node) {
  while (node != null && node is! RenderRepaintBoundary) {
    final parent = node.parent;
    node = parent is RenderObject ? parent : null;
  }
  if (node is RenderRepaintBoundary && node.attached && node.hasSize) {
    return node;
  }
  return null;
}

/// Captura un widget (RepaintBoundary) a PNG bytes 1080 px de ancho.
Future<Uint8List?> captureWidget(
  GlobalKey key, {
  int targetWidth = 1080,
}) async {
  try {
    final boundary = _findBoundary(key.currentContext?.findRenderObject());
    if (boundary == null) return null;
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
    final overlay = Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return null;
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
    // Frames acotados (v31): montaje+layout, settle de pintura/fuentes y
    // uno de margen. En cuanto el boundary tiene tamaño, se avanza.
    for (var i = 0; i < 3; i++) {
      await WidgetsBinding.instance.endOfFrame;
      final node = key.currentContext?.findRenderObject();
      if (node is RenderBox && node.attached && node.hasSize) break;
    }
    final boundary = _findBoundary(key.currentContext?.findRenderObject());
    if (boundary == null) return null;
    final image = await boundary.toImage(pixelRatio: 3);
    return await _resizeToWidth(image, targetWidth);
  } catch (_) {
    return null;
  } finally {
    entry?.remove();
  }
}

/// Comparte PDF por WebShare nativo. Mismo trato que el PNG (v31): SOLO el
/// archivo con su MIME correcto — el receptor abre un documento (no una
/// imagen) y el menú jamás ofrece «enviar texto».
Future<void> sharePdf(Uint8List bytes, String name) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: 'application/pdf')],
    ),
  );
}

/// Comparte PNG por WebShare nativo de Android. SOLO el archivo viaja al
/// share nativo (v28): sin texto, el menú del sistema nunca ofrece
/// «enviar texto» — Compartir es para imágenes.
Future<void> sharePng(Uint8List bytes, String name) async {
  await SharePlus.instance.share(
    ShareParams(
      files: [XFile.fromData(bytes, name: name, mimeType: 'image/png')],
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

/// Descarga (guarda) bytes SIN abrir el share nativo: en nativo escribe en
/// la carpeta externa de la app (Android/data/…/files/ValoraVE) y devuelve
/// la ruta — el usuario la encuentra con la app «Archivos» del teléfono;
/// compartir sigue disponible por separado (regla del dueño v17.2: nunca
/// directo). En web no hay filesystem: null honesto (sharing_io_stub).
Future<String?> downloadBytes(
  Uint8List bytes, {
  required String fileName,
}) => io_impl.downloadBytes(bytes, fileName: fileName);
