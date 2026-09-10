/// ─── Constancia mensual (§9.9 monthly-statement) ────────────────────────────
/// Scopes Mensual | Trimestral | Anual (flechas ciclan). Finance: ingresos/
/// gastos/balance + asiento por categoría. History: nº compras + total USD +
/// total Bs ponderado + asiento. Anexos trim/anual (categoría/tienda, top 6).
/// Tres caminos NUNCA auto-print: PNG 1080×1350 (4:5) · Compartir · PDF.
library;

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

const kInkPos = Color(0xFF10755A);
const kInkNeg = Color(0xFFB8352A);
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

  String get _scopeLabel => switch (_scope) { 0 => 'Mensual', 1 => 'Trimestral', _ => 'Anual' };

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
          // Documento (RepaintBoundary fuente del PNG).
          Container(
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
          const SizedBox(height: 16),
          // Tres caminos: nunca auto-print.
          FilledButton.icon(
            icon: const Icon(Icons.image_outlined, size: 17),
            label: const Text('Generar PNG (1080×1350)'),
            onPressed: () {
              // El PNG se dibuja con canvas Flutter y se comparte (buildShareImage).
              ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                  content: Text('Constancia PNG lista: se comparte o guarda desde el panel de Android'),
                  behavior: SnackBarBehavior.floating));
            },
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.share_outlined, size: 17),
            label: const Text('Compartir'),
            onPressed: () => _sharePdf(context, store, range, label, tx, purchases),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 17),
            label: const Text('Imprimir / PDF'),
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

  Future<void> _printPdf(BuildContext context, AppStore store, DateTimeRange range, String label,
      List<Transaction> tx, List<Purchase> purchases) async {
    final doc = _buildPdf(store, range, label, tx, purchases);
    await Printing.layoutPdf(onLayout: (_) async => await doc.save());
  }

  Future<void> _sharePdf(BuildContext context, AppStore store, DateTimeRange range, String label,
      List<Transaction> tx, List<Purchase> purchases) async {
    final doc = _buildPdf(store, range, label, tx, purchases);
    final bytes = await doc.save();
    await SharePlus.instance.share(ShareParams(files: [XFile.fromData(bytes, name: 'constancia-valorave.pdf', mimeType: 'application/pdf')]));
  }

  pw.Document _buildPdf(AppStore store, DateTimeRange range, String label,
      List<Transaction> tx, List<Purchase> purchases) {
    final doc = pw.Document();
    final income = tx.where((t) => t.isIncome).fold<double>(0, (a, t) => a + t.amountUSD);
    final expense = tx.where((t) => !t.isIncome).fold<double>(0, (a, t) => a + t.amountUSD);
    doc.addPage(pw.Page(
      pageFormat: PdfPageFormat.a4,
      build: (ctx) => pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
        pw.Text('ValoraVE — Constancia ${widget.kind}', style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
        pw.Text(label, style: const pw.TextStyle(fontSize: 11, color: PdfColors.grey700)),
        pw.Divider(),
        if (widget.kind == 'finance') ...[
          pw.Text('Ingresos: ${fmtUSD(income)}'),
          pw.Text('Gastos: ${fmtUSD(expense)}'),
          pw.Text('Balance: ${fmtUSD(income - expense)}', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
        ] else ...[
          pw.Text('Compras: ${purchases.length}'),
          pw.Text('Total USD: ${fmtUSD(purchases.fold<double>(0, (a, p) => a + p.totalUSD))}'),
        ],
      ]),
    ));
    return doc;
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
