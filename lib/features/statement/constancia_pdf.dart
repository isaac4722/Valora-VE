/// ─── PDF de la Constancia (v17.2 · v31, módulo público) ────────────────────
/// Constructor del PDF «Constancia de compras», separado de la pantalla para
/// ser verificable por tests y reutilizable por cualquier otro flujo.
///
/// v31 — exportación profesional:
/// · **Fuentes de marca**: Inter y SpaceGrotesk del asset (VePdfFonts); si
///   un TTF falla, se degrada a Helvetica sin romper el documento.
/// · **Márgenes uniformes**: 44 pt (~15,5 mm) en las cuatro caras — antes
///   36/40/36/36 desiguales.
/// · **Encabezado en TODAS las páginas**: marca compacta + alcance — una
///   hoja suelta siempre dice de dónde es.
/// · **Pie en TODAS las páginas**: sello de generación + «Página n».
/// · **Tabla** de desglose por tienda: cabecera repetida al saltar de
///   página (TableHelper) y filas alternas de tinte suave.
library;

import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/version.dart';
import '../../services/pdf_fonts.dart';

/// Tinta del papel (token de marca primaryLight — ver core/theme.dart).
const PdfColor _ink = PdfColor.fromInt(0xFF22354E);
final PdfColor _pos = PdfColor.fromInt(0xFF10755A);

/// Construye el documento PDF de la constancia.
Future<pw.Document> buildConstanciaPdf({
  required String scopeLabel,
  required String label,
  required List<Purchase> purchases,
}) async {
  // Fuentes de marca; si el asset falla, null → Helvetica (degradación).
  final f = await VePdfFonts.load();

  final doc = pw.Document();
  final rows = _storeRows(purchases);
  final totalUsd = purchases.fold<double>(0, (a, p) => a + p.totalUSD);
  final totalBs = purchases.fold<double>(0, (a, p) => a + p.totalBS);
  final generado =
      'Generado ${fmtDateTime(DateTime.now())} · ValoraVE $kAppVersionVisible';

  // Caja de total (tinte suave del color de firma, 92% hacia blanco).
  pw.Widget totalBox(String label, String value, PdfColor c) {
    final tint = PdfColor(
      1 - (1 - c.red) * 0.08,
      1 - (1 - c.green) * 0.08,
      1 - (1 - c.blue) * 0.08,
    );
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: tint,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        // mainAxisSize.min: el layout de hijos de MultiPage recibe altura
        // NO acotada; con max (default) la columna mediría infinito y la
        // página reventaría. Bug latente del patrón original (v28) que la
        // revisión integral de v31 cazó: el PDF de la constancia estaba
        // roto en producción.
        child: pw.Column(
          mainAxisSize: pw.MainAxisSize.min,
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(label.toUpperCase(), style: f.caps(size: 11, color: c)),
            pw.SizedBox(height: 3),
            pw.Text(value, style: f.num(size: 13.5, color: c)),
          ],
        ),
      ),
    );
  }

  doc.addPage(
    pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      // Márgenes UNIFORMES en las cuatro caras: 44 pt ≈ 15,5 mm.
      margin: const pw.EdgeInsets.all(44),
      // Encabezado de marca en TODAS las páginas: compacto, con el alcance
      // a la derecha — una hoja suelta siempre dice de dónde es.
      header: (ctx) => pw.Row(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Container(
            width: 24,
            height: 24,
            decoration: pw.BoxDecoration(
              color: _ink,
              borderRadius: pw.BorderRadius.all(pw.Radius.circular(6)),
            ),
            alignment: pw.Alignment.center,
            child: pw.Text('V', style: f.num(size: 13.5, color: PdfColors.white)),
          ),
          pw.SizedBox(width: 8),
          pw.Text('ValoraVE', style: f.num(size: 13.5, color: _ink)),
          pw.Spacer(),
          pw.Container(
            padding:
                const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey400),
              borderRadius: pw.BorderRadius.circular(999),
            ),
            child: pw.Text(
              'CONSTANCIA · ${scopeLabel.toUpperCase()}',
              style: f.caps(size: 11, color: PdfColors.grey700),
            ),
          ),
        ],
      ),
      // Pie en TODAS las páginas: sello de generación + numeración.
      // mainAxisSize.min: el layout de header/footer recibe altura NO
      // acotada; con max la columna mediría infinito y rompería la página.
      footer: (ctx) => pw.Column(
        mainAxisSize: pw.MainAxisSize.min,
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Divider(color: PdfColors.grey400),
          pw.Row(
            children: [
              pw.Expanded(
                child: pw.Text(
                  generado,
                  style: f.body(size: 11, color: PdfColors.grey600),
                ),
              ),
              pw.Text(
                'Página ${ctx.pageNumber}',
                style: f.body(size: 11, color: PdfColors.grey600),
              ),
            ],
          ),
        ],
      ),
      build: (ctx) => [
        // Título del documento (la marca vive en el encabezado de hoja).
        pw.SizedBox(height: 4),
        pw.Text('Constancia de compras', style: f.caps(size: 17, color: _ink)),
        pw.SizedBox(height: 2),
        pw.Text(
          'Período: $label',
          style: f.body(size: 11, color: PdfColors.grey700),
        ),
        pw.SizedBox(height: 14),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 10),
        // Totales en cajas con color. crossAxisAlignment.start: en el
        // layout de MultiPage la altura disponible NO está acotada y
        // `stretch` con varios hijos mide infinito (caza de la revisión
        // v31 — el patrón original reventaba el PDF en producción). Las
        // cajas comparten estructura (rótulo+valor) → misma altura.
        pw.Row(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            totalBox('Compras', '${purchases.length}', _ink),
            pw.SizedBox(width: 10),
            totalBox('Total USD', fmtUSD(totalUsd), _ink),
            pw.SizedBox(width: 10),
            totalBox('Total Bs', '${fmtNum(totalBs)} Bs', _pos),
          ],
        ),
        pw.SizedBox(height: 18),
        // Desglose por tienda (la cabecera se repite sola al saltar página).
        pw.Text('Gastos por tienda', style: f.caps(size: 13.5, color: _ink)),
        pw.SizedBox(height: 6),
        if (rows.isEmpty)
          pw.Text(
            'Sin compras en este período.',
            style: pw.TextStyle(
              fontSize: 11,
              color: PdfColors.grey600,
              fontStyle: pw.FontStyle.italic,
            ),
          )
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Concepto', 'Monto'],
            data: rows,
            headerStyle: f.caps(size: 11, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: _ink),
            cellStyle: f.body(size: 11),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: const {
              0: pw.FlexColumnWidth(3),
              1: pw.FlexColumnWidth(1.4),
            },
            oddRowDecoration: pw.BoxDecoration(
              color: PdfColor.fromInt(0xFFF4F6FB),
            ),
          ),
      ],
    ),
  );
  return doc;
}

/// Asientos por tienda (mayor gasto primero) para la tabla del PDF.
List<List<String>> _storeRows(List<Purchase> purchases) {
  final byStore = <String, double>{};
  for (final p in purchases) {
    final s = p.store ?? 'Sin tienda';
    byStore[s] = (byStore[s] ?? 0) + p.totalUSD;
  }
  final sorted = byStore.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [
    for (final e in sorted) [e.key, fmtUSD(e.value)],
  ];
}
