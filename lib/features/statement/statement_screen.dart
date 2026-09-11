/// ─── Constancia mensual (§9.9 monthly-statement) ────────────────────────────
/// Scopes Mensual | Trimestral | Anual (flechas ciclan). Finance: ingresos/
/// gastos/balance + asiento por categoría. History: nº compras + total USD +
/// total Bs ponderado + asiento. Anexos trim/anual (categoría/tienda, top 6).
/// Tres caminos NUNCA auto-print: PNG 1080×1350 (4:5) · Compartir · PDF.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../services/sharing.dart';
import '../../widgets/share_menu.dart';
import '../../widgets/ui.dart';

const kInkPos = Color(0xFF10755A);
const kInkNeg = Color(0xFFCF4437); // §8: rojo firma de datos (neg) real
const kInkAccent = Color(0xFF22354E);

class StatementScreen extends StatefulWidget {
  const StatementScreen({super.key, required this.kind});

  final String kind; // 'finance' | 'history'

  @override
  State<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends State<StatementScreen> {
  int _scope = 0; // 0 mensual · 1 trimestral · 2 anual
  int _offset = 0; // hacia atrás desde hoy

  /// RepaintBoundary del documento: fuente REAL del PNG 1080×1350.
  final GlobalKey _docKey = GlobalKey();

  String get _scopeLabel => switch (_scope) { 0 => 'Mensual', 1 => 'Trimestral', _ => 'Anual' };

  String get _pngName => 'constancia-${_scopeLabel.toLowerCase()}-valorave.png';

  DateTimeRange get _range {
    final now = DateTime.now();
    switch (_scope) {
      case 0:
        final start = DateTime(now.year, now.month - _offset, 1);
        return DateTimeRange(start: start, end: DateTime(now.year, now.month - _offset + 1, 0));
      case 1:
        final startMonth = now.month - _offset * 3;
        final start = DateTime(now.year, startMonth - 2, 1);
        return DateTimeRange(start: start, end: DateTime(now.year, startMonth + 1, 0));
      default:
        return DateTimeRange(start: DateTime(now.year - _offset, 1, 1), end: DateTime(now.year - _offset, 12, 31));
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final range = _range;
    final tx = store.transactions
        .where((t) => !t.date.isBefore(range.start) && !t.date.isAfter(range.end))
        .toList();
    final purchases = store.purchases
        .where((p) => !p.date.isBefore(range.start) && !p.date.isAfter(range.end))
        .toList();

    final income = tx.where((t) => t.isIncome).fold<double>(0, (a, t) => a + t.amountUSD);
    final expense = tx.where((t) => !t.isIncome).fold<double>(0, (a, t) => a + t.amountUSD);
    final totalBs = purchases.fold<double>(0, (a, p) => a + p.totalBS);

    final suffix = _scope == 0 ? '' : ' — ${fmtMesCorto(range.end.month)} ${range.end.year}';
    final label = '${fmtMesCorto(range.start.month)} ${range.start.year}$suffix';

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Constancia'),
        actions: [
          IconButton(
            tooltip: 'Período anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _offset++),
          ),
          TextButton(
            onPressed: () => setState(() { _scope = (_scope + 1) % 3; _offset = 0; }),
            child: Text(_scopeLabel),
          ),
          IconButton(
            tooltip: 'Período siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: _offset > 0 ? () => setState(() => _offset--) : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Documento: RepaintBoundary REAL, fuente del PNG (captureWidget).
          RepaintBoundary(
            key: _docKey,
            child: Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Row(children: [
                  Container(
                    width: 34,
                    height: 34,
                    decoration: BoxDecoration(color: kInkAccent, borderRadius: BorderRadius.circular(9)),
                    alignment: Alignment.center,
                    child: const Text('V', style: TextStyle(fontFamily: 'SpaceGrotesk', fontSize: 18, fontWeight: FontWeight.w700, color: Colors.white)),
                  ),
                  const SizedBox(width: 10),
                  Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('ValoraVE', style: VeText.displayNum(15, color: kInkAccent)),
                    Text('Constancia ${widget.kind == 'finance' ? 'de finanzas' : 'de compras'}',
                        style: const TextStyle(fontSize: 10.5, color: Colors.black54)),
                  ]),
                  const Spacer(),
                  Text(label.toUpperCase(), style: VeText.labelCaps(9, color: Colors.black54)),
                ]),
                const Divider(height: 26),
                if (widget.kind == 'finance') ...[
                  _row('Ingresos', fmtUSD(income), kInkPos),
                  _row('Gastos', fmtUSD(expense), kInkNeg),
                  const Divider(),
                  _row('Balance', fmtUSD(income - expense), income >= 0 ? kInkAccent : kInkNeg, big: true),
                  const SizedBox(height: 10),
                  ..._categoryRows(tx),
                ] else ...[
                  _row('Compras', '${purchases.length}', kInkAccent, big: true),
                  _row('Total USD', fmtUSD(purchases.fold<double>(0, (a, p) => a + p.totalUSD)), kInkAccent),
                  _row('Total Bs ponderado', 'Bs ${fmtNum(totalBs)}', kInkAccent),
                  const SizedBox(height: 10),
                  ..._storeRows(purchases),
                ],
                const SizedBox(height: 16),
                Text('Generado ${fmtDateTime(DateTime.now())} · ValoraVE 1.0.0-beta',
                    style: const TextStyle(fontSize: 9, color: Colors.black38)),
              ]),
            ),
          ),
          const SizedBox(height: 16),
          // Camino ÚNICO de salida: menú propio texto/imagen/PDF con
          // compartir o descargar por formato (v17.2). Nunca auto-print ni
          // share directo.
          PrimaryButton(
            'Compartir o guardar…',
            icon: Icons.ios_share,
            onPressed: () => unawaited(_shareMenu(context, store, range, label, tx, purchases)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 17),
            label: const Text('Imprimir'),
            onPressed: () => _printPdf(context, store, range, label, tx, purchases),
          ),
        ],
      ),
    );
  }

  Widget _row(String label, String value, Color color, {bool big = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Text(label, style: const TextStyle(fontSize: 12, color: Colors.black54)),
        const SizedBox(width: 6),
        const Expanded(child: LedgerLine()),
        Text(value,
            style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: big ? 22 : 15,
                fontWeight: FontWeight.w700,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: color)),
      ]),
    );
  }

  List<Widget> _categoryRows(List<Transaction> tx) {
    final byCat = <FinanceCategory, double>{};
    for (final t in tx.where((t) => !t.isIncome)) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amountUSD;
    }
    final sorted = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in sorted.take(6))
        _row(e.key.label, fmtUSD(e.value), Colors.black87),
    ];
  }

  List<Widget> _storeRows(List<Purchase> purchases) {
    final byStore = <String, double>{};
    for (final p in purchases) {
      final s = p.store ?? 'Sin tienda';
      byStore[s] = (byStore[s] ?? 0) + p.totalUSD;
    }
    final sorted = byStore.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [
      for (final e in sorted.take(6))
        _row(e.key, fmtUSD(e.value), Colors.black87),
    ];
  }

  /// Menú propio (v17.2): texto · imagen · PDF, cada uno con compartir o
  /// descargar. Genera los bytes solo cuando toca (sin descargar archivos).
  Future<void> _shareMenu(BuildContext context, AppStore store, DateTimeRange range,
      String label, List<Transaction> tx, List<Purchase> purchases) async {
    await showShareMenu(context, title: 'Constancia $_scopeLabel · $label', actions: [
      ShareMenuAction(
        icon: Icons.subject_rounded,
        label: 'Texto',
        hint: 'Resumen legible para pegar o enviar por chat',
        onRun: () async {
          await SharePlus.instance.share(ShareParams(text: _plainText(range, label, tx, purchases)));
          return null;
        },
      ),
      ShareMenuAction(
        icon: Icons.image_outlined,
        label: 'Compartir imagen',
        hint: 'PNG de la constancia (1080 px) para redes o chat',
        onRun: () async {
          final bytes = await captureWidget(_docKey, targetWidth: 1080);
          if (bytes == null) return 'No se pudo generar la imagen. Intenta de nuevo.';
          await sharePng(bytes, _pngName);
          return null;
        },
      ),
      ShareMenuAction(
        icon: Icons.download_rounded,
        label: 'Descargar imagen',
        hint: 'Guarda el PNG sin abrir el share',
        onRun: () async {
          final bytes = await captureWidget(_docKey, targetWidth: 1080);
          if (bytes == null) return 'No se pudo generar la imagen. Intenta de nuevo.';
          return runDownloadBytes(bytes, _pngName);
        },
      ),
      ShareMenuAction(
        icon: Icons.picture_as_pdf_outlined,
        label: 'Compartir PDF',
        hint: 'PDF con la tabla del período',
        onRun: () async {
          final bytes = await _buildPdf(store, range, label, tx, purchases).save();
          await SharePlus.instance.share(ShareParams(
              files: [XFile.fromData(Uint8List.fromList(bytes), name: 'constancia-valorave.pdf', mimeType: 'application/pdf')]));
          return null;
        },
      ),
      ShareMenuAction(
        icon: Icons.save_alt_rounded,
        label: 'Descargar PDF',
        hint: 'Guarda el PDF en la carpeta ValoraVE',
        onRun: () async {
          final bytes = await _buildPdf(store, range, label, tx, purchases).save();
          return runDownloadBytes(Uint8List.fromList(bytes), 'constancia-valorave.pdf');
        },
      ),
    ]);
  }

  /// Texto plano del período (opción «Texto» del menú).
  String _plainText(DateTimeRange range, String label, List<Transaction> tx, List<Purchase> purchases) {
    final income = tx.where((t) => t.isIncome).fold<double>(0, (a, t) => a + t.amountUSD);
    final expense = tx.where((t) => !t.isIncome).fold<double>(0, (a, t) => a + t.amountUSD);
    final b = StringBuffer('Constancia $_scopeLabel · $label — ValoraVE\n\n');
    if (widget.kind == 'finance') {
      b
        ..writeln('Ingresos: ${fmtUSD(income)}')
        ..writeln('Gastos: ${fmtUSD(expense)}')
        ..writeln('Balance: ${fmtUSD(income - expense)}');
    } else {
      b
        ..writeln('Compras: ${purchases.length}')
        ..writeln('Total USD: ${fmtUSD(purchases.fold<double>(0, (a, p) => a + p.totalUSD))}')
        ..writeln('Total Bs ponderado: Bs ${fmtNum(purchases.fold<double>(0, (a, p) => a + p.totalBS))}');
    }
    return b.toString();
  }

  Future<void> _printPdf(BuildContext context, AppStore store, DateTimeRange range, String label,
      List<Transaction> tx, List<Purchase> purchases) async {
    final doc = _buildPdf(store, range, label, tx, purchases);
    await Printing.layoutPdf(onLayout: (_) async => await doc.save());
  }

  /// PDF de calidad (v17.2): encabezado de marca, cajas de totales con color,
  /// tablas de desglose por categoría/tienda y pie honesto. Antes era un
  /// puñado de líneas de texto sin identidad.
  pw.Document _buildPdf(AppStore store, DateTimeRange range, String label,
      List<Transaction> tx, List<Purchase> purchases) {
    final doc = pw.Document();
    final income = tx.where((t) => t.isIncome).fold<double>(0, (a, t) => a + t.amountUSD);
    final expense = tx.where((t) => !t.isIncome).fold<double>(0, (a, t) => a + t.amountUSD);
    final kindLabel = widget.kind == 'finance' ? 'de finanzas' : 'de compras';

    final rows = widget.kind == 'finance'
        ? _pdfCategoryRows(tx)
        : _pdfStoreRows(purchases);
    final breakdownTitle = widget.kind == 'finance' ? 'Gastos por categoría' : 'Gastos por tienda';

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.fromLTRB(36, 40, 36, 36),
      build: (ctx) => [
        // Encabezado de marca.
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.center, children: [
          pw.Container(
            width: 34,
            height: 34,
            decoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF22354E), borderRadius: pw.BorderRadius.all(pw.Radius.circular(9))),
            alignment: pw.Alignment.center,
            child: pw.Text('V', style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColors.white)),
          ),
          pw.SizedBox(width: 10),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Text('ValoraVE', style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF22354E))),
            pw.Text('Constancia $kindLabel · $label', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700)),
          ]),
          pw.Spacer(),
          pw.Container(
            padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey400), borderRadius: pw.BorderRadius.circular(999)),
            child: pw.Text(_scopeLabel.toUpperCase(), style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700)),
          ),
        ]),
        pw.SizedBox(height: 14),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 10),
        // Totales en cajas con color.
        pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.stretch, children: [
          if (widget.kind == 'finance') ...[
            _pdfTotalBox('Ingresos', fmtUSD(income), 0xFF10755A),
            pw.SizedBox(width: 10),
            _pdfTotalBox('Gastos', fmtUSD(expense), 0xFFCF4437),
            pw.SizedBox(width: 10),
            _pdfTotalBox('Balance', fmtUSD(income - expense), 0xFF22354E),
          ] else ...[
            _pdfTotalBox('Compras', '${purchases.length}', 0xFF22354E),
            pw.SizedBox(width: 10),
            _pdfTotalBox('Total USD', fmtUSD(purchases.fold<double>(0, (a, p) => a + p.totalUSD)), 0xFF22354E),
            pw.SizedBox(width: 10),
            _pdfTotalBox('Total Bs', 'Bs ${fmtNum(purchases.fold<double>(0, (a, p) => a + p.totalBS))}', 0xFF10755A),
          ],
        ]),
        pw.SizedBox(height: 18),
        // Desglose.
        pw.Text(breakdownTitle, style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold, color: PdfColor.fromInt(0xFF22354E))),
        pw.SizedBox(height: 6),
        if (rows.isEmpty)
          pw.Text('Sin movimientos en este período.', style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600, fontStyle: pw.FontStyle.italic))
        else
          pw.TableHelper.fromTextArray(
            headers: const ['Concepto', 'Monto'],
            data: rows,
            headerStyle: pw.TextStyle(fontSize: 9.5, fontWeight: pw.FontWeight.bold, color: PdfColors.white),
            headerDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFF22354E)),
            cellStyle: const pw.TextStyle(fontSize: 9.5),
            cellAlignment: pw.Alignment.centerLeft,
            columnWidths: const {0: pw.FlexColumnWidth(3), 1: pw.FlexColumnWidth(1.4)},
            oddRowDecoration: pw.BoxDecoration(color: PdfColor.fromInt(0xFFF4F6FB)),
          ),
        pw.SizedBox(height: 22),
        pw.Divider(color: PdfColors.grey400),
        pw.SizedBox(height: 6),
        pw.Text('Generado ${fmtDateTime(DateTime.now())} · ValoraVE 17.2',
            style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey600)),
      ],
    ));
    return doc;
  }

  List<List<String>> _pdfCategoryRows(List<Transaction> tx) {
    final byCat = <FinanceCategory, double>{};
    for (final t in tx.where((t) => !t.isIncome)) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amountUSD;
    }
    final sorted = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted) [e.key.label, fmtUSD(e.value)]];
  }

  List<List<String>> _pdfStoreRows(List<Purchase> purchases) {
    final byStore = <String, double>{};
    for (final p in purchases) {
      final s = p.store ?? 'Sin tienda';
      byStore[s] = (byStore[s] ?? 0) + p.totalUSD;
    }
    final sorted = byStore.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    return [for (final e in sorted) [e.key, fmtUSD(e.value)]];
  }

  pw.Widget _pdfTotalBox(String label, String value, int color) {
    final c = PdfColor.fromInt(color);
    // Tinte suave del color de firma (92% hacia blanco).
    final tint = PdfColor(1 - (1 - c.red) * 0.08, 1 - (1 - c.green) * 0.08, 1 - (1 - c.blue) * 0.08);
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(10),
        decoration: pw.BoxDecoration(
          color: tint,
          borderRadius: pw.BorderRadius.circular(8),
        ),
        child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
          pw.Text(label.toUpperCase(), style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: c)),
          pw.SizedBox(height: 3),
          pw.Text(value, style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold, color: c)),
        ]),
      ),
    );
  }
}

/// Línea punteada del documento.
class LedgerLine extends StatelessWidget {
  const LedgerLine({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final count = (c.maxWidth / 5).floor().clamp(0, 60);
      return Row(
        children: [
          for (var i = 0; i < count; i++)
            Expanded(child: Container(height: 1.2, margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: const BoxDecoration(color: Color(0x33000000), shape: BoxShape.circle))),
        ],
      );
    });
  }
}
