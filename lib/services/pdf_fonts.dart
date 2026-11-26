/// ─── Fuentes de marca para los PDF (v31 · exportación profesional) ──────────
/// El PDF de la constancia (y cualquier PDF futuro) usa las MISMAS fuentes de
/// la app (Inter para texto, SpaceGrotesk para cifras y marca) para que el
/// documento impreso o compartido tenga la misma identidad que la pantalla.
///
/// ROBUSTEZ (regla del dueño v31): si un TTF no puede cargarse (asset
/// corrupto, plataforma sin bundle, test sin fuentes), el valor queda `null`
/// y el paquete `pdf` cae a su fuente por defecto (Helvetica): el documento
/// NUNCA deja de generarse por culpa de una fuente.
///
/// Carga UNA vez (caché estática) y comparte la Future entre llamadas
/// concurrentes: el primer botón de export paga el coste, los demás vuelan.
library;

import 'dart:typed_data';

import 'package:flutter/services.dart' show rootBundle;
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

/// Fuentes del sistema de exportación PDF.
///
/// Todos los campos son nullable a propósito: `pw.TextStyle(font: null)`
/// usa la fuente por defecto del paquete — degradación honesta, jamás error.
class VePdfFonts {
  VePdfFonts._({
    required this.inter,
    required this.interSemiBold,
    required this.interBold,
    required this.grotesk,
    required this.groteskBold,
  });

  /// Inter Regular — cuerpo del documento.
  final pw.Font? inter;

  /// Inter SemiBold — rótulos y encabezados de sección.
  final pw.Font? interSemiBold;

  /// Inter Bold — cifras destacadas.
  final pw.Font? interBold;

  /// SpaceGrotesk Medium — cifras tabulares.
  final pw.Font? grotesk;

  /// SpaceGrotesk Bold — marca y protagonistas.
  final pw.Font? groteskBold;

  static Future<VePdfFonts>? _pending;
  static VePdfFonts? _cache;

  /// Carga (o devuelve en caché) las fuentes de marca. Nunca lanza: ante
  /// cualquier fallo el campo afecto queda null y el PDF sigue saliendo.
  static Future<VePdfFonts> load() {
    final cached = _cache;
    if (cached != null) return Future.value(cached);
    return _pending ??= _doLoad().then((v) {
      _cache = v;
      _pending = null;
      return v;
    });
  }

  static Future<VePdfFonts> _doLoad() async {
    final fonts = await (
      _tryLoad('assets/fonts/Inter-Regular.ttf'),
      _tryLoad('assets/fonts/Inter-SemiBold.ttf'),
      _tryLoad('assets/fonts/Inter-Bold.ttf'),
      _tryLoad('assets/fonts/SpaceGrotesk-Medium.ttf'),
      _tryLoad('assets/fonts/SpaceGrotesk-Bold.ttf'),
    ).wait;
    return VePdfFonts._(
      inter: fonts.$1,
      interSemiBold: fonts.$2,
      interBold: fonts.$3,
      grotesk: fonts.$4,
      groteskBold: fonts.$5,
    );
  }

  /// Carga un TTF del bundle; cualquier fallo → null (degradación, no error).
  static Future<pw.Font?> _tryLoad(String asset) async {
    try {
      final ByteData data = await rootBundle.load(asset);
      return pw.Font.ttf(data);
    } catch (_) {
      return null;
    }
  }

  /// Cifra protagonista (SpaceGrotesk Bold, tabular por naturaleza).
  pw.TextStyle num({
    required double size,
    PdfColor? color,
  }) =>
      pw.TextStyle(font: groteskBold, fontSize: size, color: color);

  /// Cuerpo de texto (Inter Regular).
  pw.TextStyle body({
    required double size,
    PdfColor? color,
  }) =>
      pw.TextStyle(font: inter, fontSize: size, color: color);

  /// Rótulo en versalitas (Inter SemiBold).
  pw.TextStyle caps({
    required double size,
    PdfColor? color,
  }) =>
      pw.TextStyle(font: interSemiBold, fontSize: size, color: color);
}
