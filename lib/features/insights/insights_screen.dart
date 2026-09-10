/// ─── Análisis (§9.7) ────────────────────────────────────────────────────────
/// 5 anclas: Divisas (brecha BCV↔Paralelo dual + lookup por fecha + histórico
/// + proyección amortiguada DAMP_PHI=0.85) · Inflación (personal + heatmap
/// devaluación 365d) · Productos (mayores subidas/bajadas, gasto por tienda) ·
/// Canasta (CRUD basket) · Tasa histórica (registros + CSVs).
library;

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/analytics.dart' as an;
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/history_api.dart';
import '../../data/rate_history.dart';
import '../../data/store.dart';
import '../../services/sharing.dart';
import '../../widgets/ui.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _anchor = 0; // 0 divisas · 1 inflación · 2 productos · 3 canasta · 4 tasa
  int _days = 30; // 7 · 30 · 90 · 365

  static const _anchors = [
    (Icons.currency_exchange, 'Divisas'),
    (Icons.local_fire_department_outlined, 'Inflación'),
    (Icons.inventory_2_outlined, 'Productos'),
    (Icons.shopping_basket_outlined, 'Canasta'),
    (Icons.history, 'Tasa histórica'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const PageHeader('Análisis', hint: 'Lo que la inflación no te cuenta de corrido'),
          // Anclas.
          Row(children: [
            for (int i = 0; i < _anchors.length; i++)
              Expanded(
                child: InkWell(
                  onTap: () => setState(() => _anchor = i),
                  borderRadius: BorderRadius.circular(10),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    margin: const EdgeInsets.symmetric(horizontal: 2),
                    decoration: BoxDecoration(
                      color: _anchor == i ? scheme.primary.withValues(alpha: 0.08) : Colors.transparent,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: _anchor == i ? scheme.primary.withValues(alpha: 0.4) : scheme.outlineVariant),
                    ),
                    child: Column(children: [
                      Icon(_anchors[i].$1, size: 17,
                          color: _anchor == i ? scheme.primary : scheme.onSurfaceVariant),
                      const SizedBox(height: 3),
                      Text(_anchors[i].$2, style: TextStyle(
                          fontSize: 9.5, fontWeight: FontWeight.w700,
                          color: _anchor == i ? scheme.primary : scheme.onSurfaceVariant)),
                    ]),
                  ),
                ),
              ),
          ]),
          // Período sticky.
          const SizedBox(height: 10),
          Wrap(spacing: 6, children: [
            for (final d in [7, 30, 90, 365])
              ChipTag('$d d', selected: _days == d, onTap: () => setState(() => _days = d)),
          ]),
          const SizedBox(height: 6),
          switch (_anchor) {
            0 => _DivisasAnchor(days: _days),
            1 => _InflacionAnchor(days: _days),
            2 => _ProductosAnchor(),
            3 => _CanastaAnchor(),
            _ => _HistoricaAnchor(days: _days),
          },
        ],
      ),
    );
  }
}

/// Ancla 1: brecha dual + histórico + proyección + lookup por fecha.
class _DivisasAnchor extends StatefulWidget {
  const _DivisasAnchor({required this.days});
  final int days;

  @override
  State<_DivisasAnchor> createState() => _DivisasAnchorState();
}

class _DivisasAnchorState extends State<_DivisasAnchor> {
  List<HistPoint>? _bcv;
  List<HistPoint>? _parallel;
  String? _error;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void didUpdateWidget(covariant _DivisasAnchor old) {
    super.didUpdateWidget(old);
    if (old.days != widget.days) _load();
  }

  Future<void> _load() async {
    setState(() { _loading = true; _error = null; });
    try {
      final b = await veHistory(eur: false, paralelo: false, days: widget.days);
      final p = await veHistory(eur: false, paralelo: true, days: widget.days);
      if (mounted) setState(() { _bcv = b.points; _parallel = p.points; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      // Fallback honesto: snapshots locales (180 días).
      final store = context.read<AppStore>();
      final localB = snapshotSeries(store.snapshots, 'ves-bcv', widget.days);
      final localP = snapshotSeries(store.snapshots, 'ves-parallel', widget.days);
      if (localB.length >= 2) {
        {
          setState(() {
            _bcv = localB.map((s) => HistPoint(date: s.day, rate: s.rate)).toList();
            _parallel = localP.map((s) => HistPoint(date: s.day, rate: s.rate)).toList();
            _loading = false;
            _error = 'Serie local (sin conexión al histórico remoto)';
          });
        }
      } else {
        setState(() { _loading = false; _error = 'Sin conexión y sin snapshots guardados'; });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    final ctx = store.contextOf();
    final gap = ctx.gapPct();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (gap != null) ...[
        const SizedBox(height: 8),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(children: [
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text('BRECHA BCV ↔ PARALELO', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 4),
                Text(fmtPct(gap),
                    style: VeText.displayNum(28, color: VeColors.of(context).warn)),
              ]),
              const Spacer(),
              Stamp(gap.abs() >= 15 ? 'alta' : 'normal',
                  color: gap.abs() >= 15 ? VeColors.of(context).neg : VeColors.of(context).pos),
            ]),
          ),
        ),
      ],
      if (_error != null)
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(children: [
            Icon(Icons.info_outline, size: 13, color: scheme.onSurfaceVariant),
            const SizedBox(width: 6),
            Expanded(child: Text(_error!, style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant))),
            TextButton(onPressed: _load, child: const Text('Reintentar', style: TextStyle(fontSize: 12))),
          ]),
        ),
      if (_loading)
        const Padding(
          padding: EdgeInsets.all(20),
          child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
        )
      else if (_bcv != null && _bcv!.length >= 2)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: SfCartesianChart(
              legend: const Legend(isVisible: true, position: LegendPosition.bottom, textStyle: TextStyle(fontSize: 10)),
              primaryXAxis: DateTimeAxis(dateFormat: DateFormat('dd/MM'), majorGridLines: const MajorGridLines(width: 0)),
              tooltipBehavior: TooltipBehavior(enable: true),
              series: [
                AreaSeries<HistPoint, DateTime>(
                  dataSource: _bcv!.map((p) => HistPoint(date: p.date, rate: p.rate)).toList(),
                  xValueMapper: (p, _) => DateTime.parse(p.date),
                  yValueMapper: (p, _) => p.rate,
                  name: 'BCV',
                  color: VeColors.of(context).pos.withValues(alpha: 0.25),
                  borderColor: VeColors.of(context).pos,
                  borderWidth: 2,
                ),
                LineSeries<HistPoint, DateTime>(
                  dataSource: (_parallel ?? const []).map((p) => HistPoint(date: p.date, rate: p.rate)).toList(),
                  xValueMapper: (p, _) => DateTime.parse(p.date),
                  yValueMapper: (p, _) => p.rate,
                  name: 'Paralelo',
                  color: VeColors.of(context).neg,
                  width: 1.8,
                ),
              ],
            ),
          ),
        ),
      // Lookup por fecha.
      _LookupFecha(),
    ]);
  }
}

class _LookupFecha extends StatefulWidget {
  const _LookupFecha();

  @override
  State<_LookupFecha> createState() => _LookupFechaState();
}

class _LookupFechaState extends State<_LookupFecha> {
  DateTime _date = DateTime.now().subtract(const Duration(days: 1));
  double? _rate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Consultar tasa por fecha'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            Expanded(
              child: Text(fmtDate(_date), style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            ),
            TextButton(
              onPressed: () async {
                final d = await showDatePicker(
                    context: context,
                    initialDate: _date,
                    firstDate: DateTime(2023, 1, 3),
                    lastDate: DateTime.now(),
                    locale: const Locale('es'));
                if (d == null || !context.mounted) return;
                setState(() => _date = d);
                final store = context.read<AppStore>();
                final local = store.snapshots.where((p) =>
                    p.sourceId == 'ves-bcv' && p.day == SnapshotPoint.dayKey(d)).firstOrNull;
                setState(() => _rate = local?.rate);
              },
              child: const Text('Elegir'),
            ),
            if (_rate != null)
              TextButton(
                onPressed: () => copiarAlPortapapeles(context,
                    'BCV ${fmtDate(_date)}: ${fmtRate(_rate!)}', 'Tasa copiada'),
                child: const Text('Copiar'),
              ),
          ]),
        ),
      ),
      if (_rate != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('BCV: ${fmtRate(_rate!)} Bs/USD',
              style: VeText.displayNum(15, color: scheme.onSurface)),
        ),
    ]);
  }
}

/// Ancla 2: inflación personal + heatmap de devaluación.
class _InflacionAnchor extends StatelessWidget {
  const _InflacionAnchor({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final infl = an.personalInflation(store.products);
    final timeline = an.vesRateTimeline(store.snapshots
        .where((p) => p.sourceId == 'ves-bcv')
        .map((s) => PriceRecord(
            id: s.day, price: s.rate, originalPrice: s.rate, currency: 'VES',
            quantity: 1, rate: s.rate, sourceId: 'ves-bcv', date: DateTime.parse(s.day)))
        .toList());
    final deval = an.vesDevaluation(timeline);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: StatCard(label: 'Inflación personal (USD)', value: fmtPct(infl.usd),
            icon: Icons.local_fire_department_outlined, tone: infl.usd > 0 ? StatTone.neg : StatTone.neutral)),
        const SizedBox(width: 8),
        Expanded(child: StatCard(
            label: 'Devaluación BCV (${timeline.length}d serie)',
            value: deval == null ? '—' : fmtPct(deval.pct),
            sub: deval == null ? null : 'desde ${fmtDate(deval.fromAt)}',
            icon: Icons.trending_down, tone: StatTone.neg)),
      ]),
      const SizedBox(height: 10),
      if (deval != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SfCartesianChart(
              title: ChartTitle(text: 'Devaluación BCV (serie diaria)', textStyle: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              primaryXAxis: DateTimeAxis(dateFormat: DateFormat('MMM'), majorGridLines: const MajorGridLines(width: 0)),
              series: [
                AreaSeries<HistPoint, DateTime>(
                  dataSource: timeline
                      .map((p) => HistPoint(date: SnapshotPoint.dayKey(p.date), rate: p.price))
                      .toList(),
                  xValueMapper: (p, _) => DateTime.parse(p.date),
                  yValueMapper: (p, _) => p.rate,
                  color: VeColors.of(context).manual.withValues(alpha: 0.2),
                  borderColor: VeColors.of(context).manual,
                  borderWidth: 2,
                ),
              ],
            ),
          ),
        )
      else
        Text('Sin snapshots suficientes: la serie local se construye cada día '
                'que la app consulta tasas (máx 180 días).',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
      if (infl.usd == 0)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Tu inflación personal sale de los productos con ≥2 registros '
                  'en tu libro de precios.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ),
    ]);
  }
}

/// Ancla 3: rankings de productos y tiendas.
class _ProductosAnchor extends StatelessWidget {
  const _ProductosAnchor();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final withVariation = store.products
        .where((p) => p.records.length >= 2)
        .map((p) => (product: p, variation: an.totalVariation(p.records)))
        .toList()
      ..sort((a, b) => b.variation.compareTo(a.variation));
    final up = withVariation.take(5).toList();
    final down = withVariation.reversed.take(5).toList();
    final storeStats = an.storeStats(store.purchases).take(5).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      Text('Mayores subidas', style: VeText.labelCaps(10, color: scheme.onSurfaceVariant)),
      for (final e in up)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(e.product.name, style: const TextStyle(fontSize: 13)),
          trailing: TrendBadge(e.variation, dense: true),
        ),
      const SizedBox(height: 8),
      Text('Mayores bajadas', style: VeText.labelCaps(10, color: scheme.onSurfaceVariant)),
      for (final e in down)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: Text(e.product.name, style: const TextStyle(fontSize: 13)),
          trailing: TrendBadge(e.variation, dense: true),
        ),
      const SizedBox(height: 8),
      Text('Gasto por tienda', style: VeText.labelCaps(10, color: scheme.onSurfaceVariant)),
      for (final s in storeStats)
        ListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          leading: StoreAvatar(s.store.isEmpty ? 'Sin Tienda' : s.store, size: 30),
          title: Text(s.store.isEmpty ? 'Sin tienda' : s.store, style: const TextStyle(fontSize: 13)),
          subtitle: Text('${s.count} compras', style: const TextStyle(fontSize: 11)),
          trailing: Text(fmtUSD(s.totalUSD), style: VeText.displayNum(13, color: scheme.onSurface)),
        ),
    ]);
  }
}

/// Ancla 4: canasta básica (CRUD).
class _CanastaAnchor extends StatelessWidget {
  const _CanastaAnchor();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      Text('Tu canasta: los productos que vigilas cada mes.',
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      if (store.basket.isEmpty)
        EmptyState('Canasta vacía', icon: Icons.shopping_basket_outlined,
            hint: 'Agrega desde tus productos: sigue tu precio mensual de la canasta completa.',
            actionLabel: 'Ir a productos', onAction: () {})
      else
        Card(
          child: Column(children: [
            for (final b in store.basket)
              Builder(builder: (ctx) {
                final p = store.products.where((p) => p.id == b.productId).firstOrNull;
                final last = p?.latestRecord;
                return ListTile(
                  dense: true,
                  leading: CategoryIcon(cat: p?.category, size: 30),
                  title: Text(p?.name ?? 'Producto eliminado', style: const TextStyle(fontSize: 13.5)),
                  subtitle: Text(last == null ? 'Sin precio' : fmtUSD(last.price), style: const TextStyle(fontSize: 11)),
                  trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                    IconButton(
                        icon: const Icon(Icons.remove_circle_outline, size: 18),
                        onPressed: () => store.updateBasketItem(b.productId, b.quantity - 1)),
                    Text('${b.quantity}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
                    IconButton(
                        icon: const Icon(Icons.add_circle_outline, size: 18),
                        onPressed: () => store.updateBasketItem(b.productId, b.quantity + 1)),
                    IconButton(
                        icon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
                        onPressed: () => store.removeFromBasket(b.productId)),
                  ]),
                );
              }),
          ]),
        ),
      // Agregar a canasta desde catálogo.
      SectionTitle('Agregar a la canasta'),
      Wrap(spacing: 6, children: [
        for (final p in store.products.take(8))
          if (!store.basket.any((b) => b.productId == p.id))
            ChipTag(p.name, onTap: () => store.addToBasket(p.id, 1)),
      ]),
    ]);
  }
}

/// Ancla 5: registros propios + export.
class _HistoricaAnchor extends StatelessWidget {
  const _HistoricaAnchor({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final series = snapshotSeries(store.snapshots, 'ves-bcv', days);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      Text('Tus registros (${series.length} días guardados)',
          style: VeText.labelCaps(10, color: scheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      if (series.isEmpty)
        Text('Aún no hay snapshots: cada día que la app consulta tasas guarda '
                'un punto por fuente (máx 180 días).',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))
      else
        Card(
          child: Column(children: [
            for (final s in series.reversed.take(10))
              ListTile(
                dense: true,
                title: Text(fmtDate(DateTime.parse(s.day)), style: const TextStyle(fontSize: 12.5)),
                trailing: Text(fmtRate(s.rate), style: VeText.displayNum(13, color: scheme.onSurface)),
              ),
          ]),
        ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        icon: const Icon(Icons.table_view, size: 14),
        label: const Text('Exportar histórico CSV'),
        onPressed: () {
          final rows = <List<String>>[['Dia', 'BCV']];
          for (final s in series) {
            rows.add([s.day, s.rate.toStringAsFixed(4)]);
          }
          showShareFile(context, 'valorave-bcv-historico.csv', toCSV(rows, delimiter: ';'));
        },
      ),
    ]);
  }
}
