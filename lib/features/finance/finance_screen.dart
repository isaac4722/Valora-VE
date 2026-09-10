/// ─── Finanzas (§9.6 · MODULE=finance) ──────────────────────────────────────
/// 01 Resumen (balance mensual con AnimatedNumber + statcards + ledger por
/// categoría) · 02 Movimientos (filtros periodo/tipo, CRUD con validaciones,
/// import CSV/JSON round-trip) · 03 Análisis (donut de gastos + barras
/// ingresos vs gastos 6/12m) · export CSV + constancia.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../services/sharing.dart';
import '../../widgets/ui.dart';
import '../statement/statement_screen.dart';

const List<String> _periods = ['Todo', '7d', '30d', '90d', '365d'];
const List<String> _typeFilters = ['Todos', 'Ingresos', 'Gastos'];

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  String _period = '30d';
  String _typeFilter = 'Todos';
  int _page = 0;

  List<Transaction> _filtered(AppStore store) {
    var list = store.transactions;
    final days = switch (_period) { '7d' => 7, '30d' => 30, '90d' => 90, '365d' => 365, _ => 0 };
    if (days > 0) {
      final from = DateTime.now().subtract(Duration(days: days));
      list = list.where((t) => t.date.isAfter(from)).toList();
    }
    if (_typeFilter == 'Ingresos') list = list.where((t) => t.isIncome).toList();
    if (_typeFilter == 'Gastos') list = list.where((t) => !t.isIncome).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monthTx = store.transactions.where((t) => t.date.year == now.year && t.date.month == now.month).toList();
    final income = monthTx.where((t) => t.isIncome).fold<double>(0, (a, t) => a + t.amountUSD);
    final expense = monthTx.where((t) => !t.isIncome).fold<double>(0, (a, t) => a + t.amountUSD);
    final filtered = _filtered(store);
    final pageItems = filtered.skip(_page * 20).take(20).toList();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _txDialog(context, store, null),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Movimiento'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          PageHeader('Finanzas', hint: 'Tus movimientos en USD normalizado',
            action: IconButton(
              icon: const Icon(Icons.picture_as_pdf_outlined, size: 19),
              tooltip: 'Constancia',
              onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const StatementScreen(kind: 'finance'))),
            )),
          // 01 Resumen.
          SectionTitle('Resumen', index: 1),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('Balance de ${kMeses[now.month - 1]}', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                AnimatedNumber(income - expense,
                    style: VeText.displayNum(34, color: (income - expense) < 0 ? VeColors.of(context).neg : scheme.onSurface),
                    decimals: 2),
                const SizedBox(height: 12),
                Row(children: [
                  Expanded(child: StatCard(label: 'Ingresos', value: fmtUSD(income), icon: Icons.south_west, tone: StatTone.pos)),
                  const SizedBox(width: 8),
                  Expanded(child: StatCard(label: 'Gastos', value: fmtUSD(expense), icon: Icons.north_east, tone: StatTone.neg)),
                ]),
              ]),
            ),
          ),
          // 03 Análisis (donut + barras).
          SectionTitle('Análisis', index: 3),
          _DonutChart(transactions: store.transactions),
          _BarsChart(transactions: store.transactions),
          // 02 Movimientos.
          SectionTitle('Movimientos', index: 2, actionLabel: 'Exportar CSV', onAction: () => _export(context, filtered)),
          Wrap(spacing: 6, children: [
            for (final p in _periods)
              ChipTag(p, selected: _period == p, onTap: () => setState(() { _period = p; _page = 0; })),
            const SizedBox(width: 4),
            for (final t in _typeFilters)
              ChipTag(t, selected: _typeFilter == t, onTap: () => setState(() { _typeFilter = t; _page = 0; })),
          ]),
          const SizedBox(height: 8),
          if (filtered.isEmpty)
            EmptyState('Sin movimientos en el filtro', icon: Icons.receipt_outlined,
                hint: 'Registra ingresos y gastos con el botón + de abajo.')
          else
            Card(
              child: Column(children: [
                for (final t in pageItems)
                  ListTile(
                    dense: true,
                    leading: CategoryIcon(finCat: t.category, size: 32),
                    title: Text(t.category.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                    subtitle: Text('${t.description ?? ''} ${fmtDate(t.date)}'.trim(),
                        style: const TextStyle(fontSize: 11)),
                    trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                      Text(
                        '${t.isIncome ? '+' : '−'}${fmtUSD(t.amountUSD)}',
                        style: VeText.displayNum(13.5,
                            color: t.isIncome ? VeColors.of(context).pos : VeColors.of(context).neg),
                      ),
                      PopupMenuButton<String>(
                        icon: const Icon(Icons.more_vert, size: 16),
                        onSelected: (v) {
                          if (v == 'edit') {
                            _txDialog(context, store, t);
                          } else if (v == 'delete') {
                            store.deleteTransaction(t.id);
                          }
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 'edit', child: Text('Editar')),
                          PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                        ],
                      ),
                    ]),
                  ),
              ])),
            if (filtered.length > 20)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(onPressed: _page > 0 ? () => setState(() => _page--) : null, icon: const Icon(Icons.chevron_left)),
                  Text('Página ${_page + 1}', style: const TextStyle(fontSize: 12)),
                  IconButton(onPressed: () => setState(() => _page++), icon: const Icon(Icons.chevron_right)),
                ]),
              ),
        ],
      ),
    );
  }

  void _export(BuildContext context, List<Transaction> list) {
    final rows = <List<String>>[
      ['Fecha', 'Tipo', 'Categoria', 'Monto', 'Moneda', 'MontoUSD', 'Descripcion'],
    ];
    for (final t in list) {
      rows.add([fmtDate(t.date), t.type, t.category.label, t.amount.toStringAsFixed(2),
        t.currency, t.amountUSD.toStringAsFixed(2), t.description ?? '']);
    }
    showShareFile(context, 'finanzas-valorave.csv', toCSV(rows));
  }

  Future<void> _txDialog(BuildContext context, AppStore store, Transaction? existing) async {
    final amountCtrl = TextEditingController(text: existing == null ? '' : '${existing.amount}');
    final descCtrl = TextEditingController(text: existing?.description ?? '');
    var type = existing?.type ?? 'expense';
    var category = existing?.category ?? FinanceCategory.alimentacion;
    var currency = existing?.currency ?? 'VES';
    var date = existing?.date ?? DateTime.now();

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
          child: ListView(
            shrinkWrap: true,
            padding: const EdgeInsets.all(20),
            children: [
              Text(existing == null ? 'Registrar movimiento' : 'Editar movimiento',
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              SegmentedChips<String>(
                options: const ['expense', 'income'],
                value: type,
                onChanged: (v) => setSheet(() {
                  type = v;
                  // Categoría coherente con el tipo.
                  category = v == 'income' ? FinanceCategory.salario : FinanceCategory.alimentacion;
                }),
                labelOf: (v) => v == 'income' ? 'Ingreso' : 'Gasto',
              ),
              const SizedBox(height: 10),
              TextField(
                controller: amountCtrl,
                autofocus: existing == null,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(hintText: 'Monto'),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [
                for (final c in Currency.values)
                  ChipTag(c.code, selected: currency == c.code,
                      onTap: () => setSheet(() => currency = c.code)),
              ]),
              const SizedBox(height: 10),
              Wrap(spacing: 6, children: [
                for (final c in FinanceCategory.values.where((c) => c.isIncome == (type == 'income')))
                  ChipTag(c.label, selected: category == c,
                      onTap: () => setSheet(() => category = c)),
              ]),
              const SizedBox(height: 10),
              TextField(controller: descCtrl, decoration: const InputDecoration(hintText: 'Descripción (opcional)')),
              const SizedBox(height: 10),
              Row(children: [
                Text('Fecha: ${fmtDate(date)}', style: const TextStyle(fontSize: 13)),
                const Spacer(),
                TextButton(
                  onPressed: () async {
                    final d = await showDatePicker(
                        context: ctx,
                        initialDate: date,
                        firstDate: DateTime(2023, 1, 3),
                        lastDate: DateTime.now(),
                        locale: const Locale('es'));
                    if (d != null) setSheet(() => date = d);
                  },
                  child: const Text('Cambiar'),
                ),
              ]),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: () {
                    final amount = parseLocaleNum(amountCtrl.text);
                    if (amount == null || amount <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Ingresa monto válido'), behavior: SnackBarBehavior.floating));
                      return;
                    }
                    final ctx2 = store.contextOf(module: RateModule.finance);
                    final u = ctx2.unitsPerUSD(CurrencyX.from(currency));
                    if (u == null || u <= 0) {
                      ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(
                          content: Text('Sin tasa para esa moneda'), behavior: SnackBarBehavior.floating));
                      return;
                    }
                    final amountUSD = amount / u;
                    if (existing == null) {
                      store.addTransaction(Transaction(
                        id: '',
                        type: type,
                        category: category,
                        amount: amount,
                        currency: currency,
                        amountUSD: amountUSD,
                        date: date,
                        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                      ));
                    } else {
                      store.updateTransaction(existing.id, Transaction(
                        id: existing.id,
                        type: type,
                        category: category,
                        amount: amount,
                        currency: currency,
                        amountUSD: amountUSD,
                        date: date,
                        description: descCtrl.text.trim().isEmpty ? null : descCtrl.text.trim(),
                      ));
                    }
                    Navigator.pop(ctx);
                  },
                  child: Text(existing == null ? 'Registrar' : 'Guardar'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Donut de gastos por categoría (syncfusion).
class _DonutChart extends StatelessWidget {
  const _DonutChart({required this.transactions});
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monthTx = transactions.where((t) => !t.isIncome && t.date.year == now.year && t.date.month == now.month).toList();
    if (monthTx.isEmpty) return const SizedBox.shrink();
    final byCat = <FinanceCategory, double>{};
    for (final t in monthTx) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amountUSD;
    }
    final palette = chartPalette(context);
    final data = byCat.entries.toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SfCircularChart(
          title: ChartTitle(text: 'Gastos del mes (USD)', textStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          legend: Legend(isVisible: true, position: LegendPosition.bottom,
              textStyle: const TextStyle(fontSize: 10)),
          series: [
            DoughnutSeries<MapEntry<FinanceCategory, double>, String>(
              dataSource: data,
              xValueMapper: (e, _) => e.key.label,
              yValueMapper: (e, _) => e.value,
              pointColorMapper: (e, i) => palette[i % palette.length],
              radius: '70%',
              dataLabelSettings: const DataLabelSettings(isVisible: false),
              enableTooltip: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// Barras ingresos vs gastos últimos 6 meses.
class _BarsChart extends StatelessWidget {
  const _BarsChart({required this.transactions});
  final List<Transaction> transactions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final months = <String, ({double income, double expense})>{};
    for (var i = 5; i >= 0; i--) {
      final m = DateTime(now.year, now.month - i, 1);
      months['${m.month}/${m.year % 100}'] = (income: 0, expense: 0);
    }
    for (final t in transactions) {
      final key = '${t.date.month}/${t.date.year % 100}';
      if (!months.containsKey(key)) continue;
      final cur = months[key]!;
      months[key] = t.isIncome
          ? (income: cur.income + t.amountUSD, expense: cur.expense)
          : (income: cur.income, expense: cur.expense + t.amountUSD);
    }
    final data = months.entries
        .map((e) => _BarPoint(e.key, e.value.income, e.value.expense))
        .toList();
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: SfCartesianChart(
          title: ChartTitle(text: 'Ingresos vs gastos (6 meses)', textStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          legend: const Legend(isVisible: true, position: LegendPosition.bottom, textStyle: TextStyle(fontSize: 10)),
          primaryXAxis: const CategoryAxis(),
          tooltipBehavior: TooltipBehavior(enable: true),
          series: [
            ColumnSeries<_BarPoint, String>(
              dataSource: data,
              xValueMapper: (p, _) => p.month,
              yValueMapper: (p, _) => p.income,
              name: 'Ingresos',
              color: VeColors.of(context).pos,
            ),
            ColumnSeries<_BarPoint, String>(
              dataSource: data,
              xValueMapper: (p, _) => p.month,
              yValueMapper: (p, _) => p.expense,
              name: 'Gastos',
              color: VeColors.of(context).neg,
            ),
          ],
        ),
      ),
    );
  }
}

class _BarPoint {
  _BarPoint(this.month, this.income, this.expense);
  final String month;
  final double income, expense;
}
