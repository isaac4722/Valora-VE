/// ─── Análisis (§9.7) ────────────────────────────────────────────────────────
/// 6 anclas: Divisas (brecha BCV↔Paralelo dual + gráfica interactiva con
/// trackball por día + panel de brecha diaria + lookup por fecha) · Inflación
/// (personal PONDERADA por la canasta + promedio simple de productos + serie
/// de costo + curva de devaluación BCV) · Productos (rankings en el rango) ·
/// Canasta (CRUD) · Gastos (v17.8: vista resumida de las compras de Lista,
/// alimentada automática — sucesora de los gráficos de Finanzas) · Tasa
/// histórica (fuente seleccionable + gráfica + CSV).
/// Gráficas tap-friendly (ActivationMode.singleTap): tooltip con formato es-VE,
/// crosshair vertical y trackball flotante; cobertura REAL anunciada con
/// snapshotSeries/snapshotDepth (nunca «365 días» sin datos — § honesto).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/analytics.dart' as an;
import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/history_api.dart';
import '../../data/rate_history.dart';
import '../../data/store.dart';
import '../../services/sharing.dart';
import '../../widgets/coach_mark.dart';
import '../../widgets/ui.dart';
import 'insights_utils.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _anchor = 0; // 0 divisas · 1 inflación · 2 productos · 3 canasta · 4 gastos · 5 tasa
  int _days = 30; // 1 M · 6 M · 1 Año · Máximo (3650 = todo lo que haya)

  /// Ancla del coach-mark de rango/export (Ola 1 · tips-dismissed).
  static final GlobalKey _tipRango = GlobalKey(debugLabel: 'tip-insights-rango');

  static const _anchors = [
    (Icons.currency_exchange, 'Divisas'),
    (Icons.local_fire_department_outlined, 'Inflación'),
    (Icons.inventory_2_outlined, 'Productos'),
    (Icons.shopping_basket_outlined, 'Canasta'),
    (Icons.payments_outlined, 'Gastos'),
    (Icons.history, 'Tasa'),
  ];

  static const _ranges = <(int, String)>[
    (30, '1 M'),
    (183, '6 M'),
    (365, '1 Año'),
    (3650, 'Máximo'),
  ];

  @override
  void initState() {
    super.initState();
    // Coach-mark (Ola 1): rango + exportación — tras el walkthrough.
    scheduleFeatureTip(context, '/analisis', 'insights.rango',
        anchor: _tipRango,
        title: 'Rango y exportación',
        body: 'Los chips cambian la ventana de TODAS las gráficas (la cobertura '
            'real siempre se anuncia). Divisas exporta la brecha en CSV y Tasa '
            'histórica superpone hasta 3 divisas.');
  }

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
          // Rango: chips piden la ventana; la cobertura REAL la anuncia cada
          // gráfica (§ etiquetas honestas — si falta cobertura, se dice).
          const SizedBox(height: 10),
          KeyedSubtree(
            key: _tipRango,
            child: Wrap(spacing: 6, children: [
              for (final (d, label) in _ranges)
                ChipTag(label, selected: _days == d, onTap: () => setState(() => _days = d)),
            ]),
          ),
          const SizedBox(height: 6),
          switch (_anchor) {
            0 => _DivisasAnchor(days: _days),
            1 => _InflacionAnchor(days: _days, onGoToBasket: () => setState(() => _anchor = 3)),
            2 => _ProductosAnchor(days: _days),
            3 => _CanastaAnchor(),
            4 => _GastosAnchor(days: _days),
            _ => _HistoricaAnchor(days: _days),
          },
        ],
      ),
    );
  }
}

/// Ancla 1: brecha dual + gráfica interactiva (trackball por día + panel de
/// brecha diaria) + lookup por fecha.
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
  int? _gapIdx; // punto tocado en la serie BCV (trackball)

  // Trackball tap-friendly: divisor vertical PUNTEADO en el punto exacto +
  // burbujas de ambas series + marcador en el punto tocado (§ interactivas).
  final TrackballBehavior _trackball = TrackballBehavior(
    enable: true,
    activationMode: ActivationMode.singleTap,
    lineType: TrackballLineType.vertical,
    lineDashArray: const <double>[4, 3],
    tooltipDisplayMode: TrackballDisplayMode.floatAllPoints,
    tooltipSettings: const InteractiveTooltip(enable: true),
    markerSettings: const TrackballMarkerSettings(markerVisibility: TrackballVisibilityMode.visible),
  );

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
    setState(() { _loading = true; _error = null; _gapIdx = null; });
    try {
      final b = await veHistory(eur: false, paralelo: false, days: widget.days);
      final p = await veHistory(eur: false, paralelo: true, days: widget.days);
      if (!mounted) return;
      setState(() { _bcv = b.points; _parallel = p.points; _loading = false; });
    } catch (e) {
      if (!mounted) return;
      // Fallback honesto: snapshots locales (hasta 180 días reales).
      final store = context.read<AppStore>();
      final localB = snapshotSeries(store.snapshots, 'ves-bcv', widget.days);
      final localP = snapshotSeries(store.snapshots, 'ves-parallel', widget.days);
      if (localB.length >= 2) {
        setState(() {
          _bcv = localB.map((s) => HistPoint(date: s.day, rate: s.rate)).toList();
          _parallel = localP.map((s) => HistPoint(date: s.day, rate: s.rate)).toList();
          _loading = false;
          _error = 'Serie local (sin conexión al histórico remoto)';
        });
      } else {
        setState(() { _loading = false; _error = 'Sin conexión y sin snapshots guardados'; });
      }
    }
  }

  // Guarda el punto tocado para el panel de brecha diaria (feedback visible).
  // API real de syncfusion 27: onTrackballPositionChanging entrega
  // TrackballArgs con UN ChartPointInfo (dataPointIndex del punto tocado).
  void _onTrackball(TrackballArgs details) {
    final idx = details.chartPointInfo.dataPointIndex;
    if (idx == null || idx < 0) return;
    if (idx != _gapIdx) setState(() => _gapIdx = idx);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    final ctx = store.contextOf();
    final gap = ctx.gapPct();
    final bcv = _bcv ?? const <HistPoint>[];
    final par = _parallel ?? const <HistPoint>[];
    final ready = _bcv != null && _bcv!.length >= 2;

    // Cobertura REAL: se anuncia la serie paralelo (suele ser la más corta);
    // si no hay paralelo, la de BCV.
    final covPoints = par.isNotEmpty ? par.length : bcv.length;
    final covFirst = par.isNotEmpty
        ? DateTime.tryParse(par.first.date)
        : (bcv.isEmpty ? null : DateTime.tryParse(bcv.first.date));
    final covSubject = par.isNotEmpty ? 'paralelo' : null;

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
      else if (ready)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(10),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                coverageText(
                  rangeLabel: rangeName(widget.days),
                  requestedDays: widget.days,
                  points: covPoints,
                  first: covFirst,
                  sinceSubject: covSubject,
                ),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 4),
              SizedBox(
                height: 220,
                child: SfCartesianChart(
                  legend: const Legend(isVisible: true, position: LegendPosition.bottom, textStyle: TextStyle(fontSize: 10)),
                  primaryXAxis: DateTimeAxis(dateFormat: DateFormat('dd/MM'), majorGridLines: const MajorGridLines(width: 0)),
                  trackballBehavior: _trackball,
                  onTrackballPositionChanging: _onTrackball,
                  series: [
                    AreaSeries<HistPoint, DateTime>(
                      dataSource: bcv,
                      xValueMapper: (p, _) => DateTime.parse(p.date),
                      yValueMapper: (p, _) => p.rate,
                      name: 'BCV',
                      color: VeColors.of(context).pos.withValues(alpha: 0.25),
                      borderColor: VeColors.of(context).pos,
                      borderWidth: 2,
                    ),
                    if (par.isNotEmpty)
                      LineSeries<HistPoint, DateTime>(
                        dataSource: par,
                        xValueMapper: (p, _) => DateTime.parse(p.date),
                        yValueMapper: (p, _) => p.rate,
                        name: 'Paralelo',
                        color: VeColors.of(context).neg,
                        width: 1.8,
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 6),
              _GapPanel(bcv: bcv, parallel: par, index: _gapIdx),
              // exportGapCsv (§9.7): la brecha por día en CSV es-VE.
              if (bcv.isNotEmpty && par.isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerRight,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.table_view, size: 14),
                    label: const Text('Exportar brecha CSV'),
                    onPressed: () => showShareFile(
                        context,
                        'valorave-brecha-${SnapshotPoint.dayKey(DateTime.now())}.csv',
                        toCSV(gapCsvRows(bcv, par), delimiter: ';')),
                  ),
                ),
              ],
            ]),
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Text(
            'Serie insuficiente para graficar: ${bcv.length} '
            '${bcv.length == 1 ? 'punto' : 'puntos'} con datos. Cada día que la app '
            'consulta tasas guarda un punto por fuente (máx 180 días).',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
        ),
      // Lookup por fecha.
      _LookupFecha(),
    ]);
  }
}

/// Panel del día tocado en la gráfica de brecha: BCV, paralelo y brecha % de
/// ESE día (paralelo/BCV − 1, solo con ambas tasas > 0). Sin tap: último día.
class _GapPanel extends StatelessWidget {
  const _GapPanel({required this.bcv, required this.parallel, required this.index});

  final List<HistPoint> bcv;
  final List<HistPoint> parallel;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);
    if (bcv.isEmpty) return const SizedBox.shrink();
    final i = (index == null || index! < 0 || index! >= bcv.length) ? bcv.length - 1 : index!;
    final p = bcv[i];
    final parPoint = parallel.where((x) => x.date == p.date).firstOrNull;
    final g = gapForDay(bcv, parallel, p.date);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(index == null ? 'ÚLTIMO DÍA' : 'DÍA TOCADO',
              style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
          const Spacer(),
          Text(fmtDate(DateTime.parse(p.date)),
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: scheme.onSurface)),
        ]),
        const SizedBox(height: 6),
        LedgerRow(label: 'BCV', value: fmtRate(p.rate), valueColor: ink.pos),
        LedgerRow(
            label: 'Paralelo',
            value: parPoint == null ? 'sin dato' : fmtRate(parPoint.rate),
            valueColor: ink.neg),
        LedgerRow(
            label: 'Brecha ese día',
            value: g == null ? '—' : fmtPct(g.pct),
            valueColor: g == null ? scheme.onSurfaceVariant : ink.warn,
            boldValue: true),
        if (parPoint == null)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text('El paralelo no tiene registro ese día: la brecha necesita ambas tasas (>0) el mismo día.',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ),
      ]),
    );
  }
}

class _LookupFecha extends StatefulWidget {
  const _LookupFecha();

  @override
  State<_LookupFecha> createState() => _LookupFechaState();
}

class _LookupFechaState extends State<_LookupFecha> {
  DateTime _date = DateTime.now().subtract(const Duration(days: 1));
  double? _rateB;
  double? _rateP;
  bool _searched = false;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);
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
                final store = context.read<AppStore>();
                final day = SnapshotPoint.dayKey(d);
                final b = store.snapshots
                    .where((p) => p.sourceId == 'ves-bcv' && p.day == day)
                    .firstOrNull;
                final p = store.snapshots
                    .where((x) => x.sourceId == 'ves-parallel' && x.day == day)
                    .firstOrNull;
                setState(() { _date = d; _rateB = b?.rate; _rateP = p?.rate; _searched = true; });
              },
              child: const Text('Elegir'),
            ),
            if (_rateB != null)
              TextButton(
                onPressed: () => copiarAlPortapapeles(context,
                    'BCV ${fmtDate(_date)}: ${fmtRate(_rateB!)}', 'Tasa copiada'),
                child: const Text('Copiar'),
              ),
          ]),
        ),
      ),
      if (_rateB != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: LedgerRow(label: 'BCV · ${fmtDate(_date)}', value: '${fmtRate(_rateB!)} Bs/USD',
              valueColor: ink.pos, boldValue: true),
        ),
      if (_rateP != null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: LedgerRow(label: 'Paralelo · ${fmtDate(_date)}', value: '${fmtRate(_rateP!)} Bs/USD',
              valueColor: ink.neg, boldValue: true),
        ),
      if (_searched && _rateB == null && _rateP == null)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Sin registro local para esa fecha: los snapshots empiezan el día que la app '
                  'consulta tasas. Para tasas remotas de fechas pasadas usa el Conversor → fecha histórica.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ),
    ]);
  }
}

/// Ancla 2: inflación personal (canasta ponderada por costo + promedio simple
/// de todos los productos) + serie de costo de la canasta + devaluación BCV.
class _InflacionAnchor extends StatelessWidget {
  const _InflacionAnchor({required this.days, required this.onGoToBasket});

  final int days;
  final VoidCallback onGoToBasket;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);

    // Inflación personal de la CANASTA (ponderada por costo, §4 del web).
    final b = basketInflation(store.basket, store.products, days: days);
    // Todos los productos con ≥2 registros en el rango (promedio simple).
    final prod = productsInflation(store.products, days: days);
    // Serie de costo de la canasta (forward-fill desde el común más antiguo).
    final costSeries = basketCostSeries(store.basket, store.products, days: days);
    // Proyección punteada DAMP (§9.7 · φ 0.85, misma semántica de predictPrice):
    // 30 días de canasta al momentum amortiguado — memoria, no promesa.
    final costProj = dampProjection(
        [for (final e in costSeries) (day: e.day, value: e.cost)]);
    // Devaluación BCV (curva) — reutiliza an.vesRateTimeline + an.vesDevaluation.
    final timeline = an.vesRateTimeline(store.snapshots
        .where((p) => p.sourceId == 'ves-bcv')
        .map((s) => PriceRecord(
            id: s.day, price: s.rate, originalPrice: s.rate, currency: 'VES',
            quantity: 1, rate: s.rate, sourceId: 'ves-bcv', date: DateTime.parse(s.day)))
        .toList());
    final deval = an.vesDevaluation(timeline);
    final devalPoints =
        timeline.map((p) => HistPoint(date: SnapshotPoint.dayKey(p.date), rate: p.price)).toList();

    final breaks = b?.breaks ?? const <BasketBreak>[];
    final ups = [...breaks.where((e) => e.pct > 0)]..sort((x, y) => y.pct.compareTo(x.pct));
    final downs = [...breaks.where((e) => e.pct < 0)]..sort((x, y) => x.pct.compareTo(y.pct));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      if (b != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(child: Text('INFLACIÓN PERSONAL · TU CANASTA',
                    style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant))),
                Stamp('${b.measured} productos', color: scheme.primary),
              ]),
              const SizedBox(height: 8),
              ReadWindow(
                semanticLabel: 'Inflación personal de la canasta ${fmtPct(b.pct)}',
                child: Row(children: [
                  Expanded(
                    child: Text(fmtPct(b.pct),
                        style: VeText.displayNum(30,
                            color: b.pct > 0 ? ink.neg : (b.pct < 0 ? ink.pos : scheme.onSurface))),
                  ),
                  Icon(b.pct >= 0 ? Icons.trending_up : Icons.trending_down,
                      size: 20, color: b.pct >= 0 ? ink.neg : ink.pos),
                ]),
              ),
              const SizedBox(height: 8),
              Text('Costo de la canasta: ${fmtUSD(b.oldCost)} → ${fmtUSD(b.newCost)} · desde ${fmtDate(b.fromAt)}',
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
              if (b.skipped > 0)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      '${b.skipped} de ${store.basket.length} productos de la canasta sin ≥2 registros '
                      'en el rango: no se inventa su variación.',
                      style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
                ),
            ]),
          ),
        )
      else
        EmptyState('Sin inflación personal medible todavía',
            icon: Icons.local_fire_department_outlined,
            hint: 'Tu inflación personal sale de tu canasta: necesita productos con ≥2 registros '
                'dentro del rango elegido. Agrega productos a la canasta y registra sus precios.',
            actionLabel: 'Ver canasta',
            onAction: onGoToBasket),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(child: StatCard(
            label: 'Todos tus productos',
            value: prod == null ? '—' : fmtPct(prod.pct),
            sub: prod == null ? 'sin ≥2 registros en el rango' : 'promedio simple · ${prod.products} productos',
            icon: Icons.inventory_2_outlined)),
        const SizedBox(width: 8),
        Expanded(child: StatCard(
            label: 'Devaluación BCV (${timeline.length}d serie)',
            value: deval == null ? '—' : fmtPct(deval.pct),
            sub: deval == null ? null : 'desde ${fmtDate(deval.fromAt)}',
            icon: Icons.trending_down, tone: StatTone.neg)),
      ]),
      if (costSeries.length >= 2) ...[
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('COSTO DE LA CANASTA (USD)', style: VeText.labelCaps(10, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                  coverageText(
                      rangeLabel: rangeName(days),
                      requestedDays: days,
                      points: costSeries.length,
                      first: costSeries.first.day,
                      sinceSubject: 'canasta'),
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              SizedBox(
                height: 200,
                child: SfCartesianChart(
                  primaryXAxis: DateTimeAxis(dateFormat: DateFormat('dd/MM'), majorGridLines: const MajorGridLines(width: 0)),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    activationMode: ActivationMode.singleTap,
                    builder: (dynamic s, dynamic point, dynamic series, int i, int si) {
                      if (i < 0 || i >= costSeries.length) return const SizedBox.shrink();
                      final p = costSeries[i];
                      return _TipBox(main: fmtUSD(p.cost), sub: fmtDayLabel(p.day),
                          bg: scheme.primary, fg: scheme.onPrimary);
                    },
                  ),
                  crosshairBehavior: CrosshairBehavior(
                    enable: true,
                    lineType: CrosshairLineType.vertical,
                    lineDashArray: const <double>[4, 3],
                    activationMode: ActivationMode.singleTap,
                  ),
                  series: [
                    AreaSeries<({DateTime day, double cost, int items}), DateTime>(
                      dataSource: costSeries,
                      xValueMapper: (p, _) => p.day,
                      yValueMapper: (p, _) => p.cost,
                      name: 'Canasta',
                      color: ink.manual.withValues(alpha: 0.2),
                      borderColor: ink.manual,
                      borderWidth: 2,
                    ),
                    // Proyección PUNTEADA (DAMP φ 0.85): se distingue a la
                    // vista de la serie real — nunca se pinta sólida.
                    if (costProj != null)
                      LineSeries<({DateTime day, double value}), DateTime>(
                        dataSource: costProj.points,
                        xValueMapper: (p, _) => p.day,
                        yValueMapper: (p, _) => p.value,
                        name: 'Proyección 30 d',
                        color: ink.warn,
                        width: 1.6,
                        dashArray: const <double>[6, 4],
                      ),
                  ],
                ),
              ),
              if (costProj != null)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                      'Línea punteada: proyección 30 días con memoria amortiguada '
                      '(φ 0,85 · ${costProj.dailyPct >= 0 ? '+' : ''}${costProj.dailyPct.toStringAsFixed(2)} %/día). '
                      'Es una lectura del momentum, no una promesa.',
                      style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
                ),
            ]),
          ),
        ),
      ],
      if (ups.isNotEmpty || downs.isNotEmpty) ...[
        const SizedBox(height: 10),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DESGLOSE POR PRODUCTO', style: VeText.labelCaps(10, color: scheme.onSurfaceVariant)),
              if (ups.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Sin subidas registradas en el rango.',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
              for (final e in ups.take(5))
                LedgerRow(label: e.name, value: fmtPct(e.pct), valueColor: ink.neg),
              if (downs.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text('MAYORES BAJADAS', style: VeText.labelCaps(10, color: scheme.onSurfaceVariant)),
              ],
              for (final e in downs.take(5))
                LedgerRow(label: e.name, value: fmtPct(e.pct), valueColor: ink.pos),
            ]),
          ),
        ),
      ],
      if (deval != null)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('DEVALUACIÓN BCV (SERIE DIARIA)', style: VeText.labelCaps(10, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 2),
              Text(
                  coverageText(
                      rangeLabel: 'Serie BCV',
                      requestedDays: days,
                      points: devalPoints.length,
                      first: devalPoints.isEmpty ? null : DateTime.tryParse(devalPoints.first.date),
                      sinceSubject: 'BCV'),
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 4),
              SizedBox(
                height: 200,
                child: SfCartesianChart(
                  primaryXAxis: DateTimeAxis(dateFormat: DateFormat('dd/MM'), majorGridLines: const MajorGridLines(width: 0)),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    activationMode: ActivationMode.singleTap,
                    builder: (dynamic s, dynamic point, dynamic series, int i, int si) {
                      if (i < 0 || i >= devalPoints.length) return const SizedBox.shrink();
                      final p = devalPoints[i];
                      return _TipBox(main: 'BCV ${fmtRate(p.rate)}', sub: fmtDayLabel(DateTime.parse(p.date)),
                          bg: scheme.primary, fg: scheme.onPrimary);
                    },
                  ),
                  crosshairBehavior: CrosshairBehavior(
                    enable: true,
                    lineType: CrosshairLineType.vertical,
                    lineDashArray: const <double>[4, 3],
                    activationMode: ActivationMode.singleTap,
                  ),
                  series: [
                    AreaSeries<HistPoint, DateTime>(
                      dataSource: devalPoints,
                      xValueMapper: (p, _) => DateTime.parse(p.date),
                      yValueMapper: (p, _) => p.rate,
                      color: ink.manual.withValues(alpha: 0.2),
                      borderColor: ink.manual,
                      borderWidth: 2,
                    ),
                  ],
                ),
              ),
            ]),
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Sin snapshots suficientes: la serie local se construye cada día '
                  'que la app consulta tasas (máx 180 días).',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ),
      // Heatmap de devaluación (§9.7 · calendario 6 m pictórico — cierra D2):
      // % diario del BCV en calendario; rojo=subida (devaluación), verde=baja.
      _HeatmapCalendar(
          data: devaluationDaily(store.snapshots
              .where((p) => p.sourceId == 'ves-bcv')
              .toList())),
      if (prod == null && b == null)
        Padding(
          padding: const EdgeInsets.only(top: 6),
          child: Text('Tu inflación por productos necesita ≥2 registros en el rango: '
                  'registra precios en Productos para medir variaciones.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        ),
    ]);
  }
}

/// Ancla 3: rankings de productos (en el rango) y tiendas.
class _ProductosAnchor extends StatelessWidget {
  const _ProductosAnchor({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final measured = <(Product, double)>[];
    for (final p in store.products) {
      final v = variationInRange(p, days);
      if (v != null) measured.add((p, v));
    }
    final up = [...measured.where((e) => e.$2 > 0)]..sort((a, b) => b.$2.compareTo(a.$2));
    final down = [...measured.where((e) => e.$2 < 0)]..sort((a, b) => a.$2.compareTo(b.$2));
    final storeStats = an.storeStats(store.purchases).take(5).toList();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      if (up.isEmpty && down.isEmpty)
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text('Sin subidas ni bajadas registradas dentro del rango elegido.',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        )
      else ...[
        Text('Mayores subidas', style: VeText.labelCaps(10, color: scheme.onSurfaceVariant)),
        for (final e in up.take(5))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(e.$1.name, style: const TextStyle(fontSize: 13)),
            trailing: TrendBadge(e.$2, dense: true),
          ),
        const SizedBox(height: 8),
        Text('Mayores bajadas', style: VeText.labelCaps(10, color: scheme.onSurfaceVariant)),
        for (final e in down.take(5))
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            title: Text(e.$1.name, style: const TextStyle(fontSize: 13)),
            trailing: TrendBadge(e.$2, dense: true),
          ),
        const SizedBox(height: 8),
      ],
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
      // ── Rankings de compras (§9.7): por día de semana y por moneda ──
      if (store.purchases.isNotEmpty) ...[
        const SizedBox(height: 10),
        Text('Compras por día de la semana',
            style: VeText.labelCaps(10, color: scheme.onSurfaceVariant)),
        _WeekdayRanking(purchases: store.purchases),
        const SizedBox(height: 10),
        Text('Compras por divisa',
            style: VeText.labelCaps(10, color: scheme.onSurfaceVariant)),
        _CurrencyRanking(purchases: store.purchases),
      ],
    ]);
  }
}

/// Distribución del gasto por día de la semana (Lun→Dom) con el día fuerte
/// señalado — el «ranking» honesto: total USD efectivo + nº de compras.
class _WeekdayRanking extends StatelessWidget {
  const _WeekdayRanking({required this.purchases});
  final List<Purchase> purchases;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = weekdaySpend(purchases);
    final maxTotal = rows.fold<double>(0, (m, e) => e.totalUSD > m ? e.totalUSD : m);
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Column(children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 3),
              child: Row(children: [
                SizedBox(
                  width: 34,
                  child: Text(r.day,
                      style: TextStyle(
                          fontSize: 12,
                          fontWeight: r.totalUSD == maxTotal && maxTotal > 0
                              ? FontWeight.w800
                              : FontWeight.w500,
                          color: scheme.onSurface)),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: maxTotal > 0 ? r.totalUSD / maxTotal : 0,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 74,
                  child: Text(r.totalUSD > 0 ? fmtUSD(r.totalUSD) : '—',
                      textAlign: TextAlign.right,
                      style: VeText.displayNum(11.5, color: scheme.onSurface)),
                ),
                SizedBox(
                  width: 30,
                  child: Text('${r.count}',
                      textAlign: TextAlign.right,
                      style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Gasto por divisa: lo pagado en CADA moneda (precio original de los ítems)
/// con su equivalente USD — el orden del ranking es por USD (comparable).
class _CurrencyRanking extends StatelessWidget {
  const _CurrencyRanking({required this.purchases});
  final List<Purchase> purchases;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = currencySpend(purchases);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
        child: Column(children: [
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(children: [
                SizedBox(
                  width: 44,
                  child: Text(r.currency,
                      style: VeText.displayNum(12, color: scheme.onSurface)),
                ),
                Expanded(
                  child: Text(
                      '${fmtMoney(r.totalOriginal, CurrencyX.from(r.currency))} · '
                      '${r.items} ítem${r.items == 1 ? '' : 's'}',
                      style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                ),
                Text('≈ ${fmtUSD(r.totalUSD)}',
                    style: VeText.displayNum(12, color: scheme.onSurface)),
              ]),
            ),
        ]),
      ),
    );
  }
}

/// Ancla 4: canasta básica (CRUD) — vive aquí: la inflación personal del
/// ancla Inflación se calcula con ESTA canasta.
class _CanastaAnchor extends StatelessWidget {
  const _CanastaAnchor();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      Text('Tu canasta: los productos que vigilas cada mes. Con ella se calcula '
              'tu inflación personal.',
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      if (store.basket.isEmpty)
        EmptyState('Canasta vacía', icon: Icons.shopping_basket_outlined,
            hint: 'Agrega desde tus productos: sigue su precio mensual y Análisis medirá '
                'la variación del costo de la canasta completa.',
            actionLabel: 'Ir a productos', onAction: () => context.go('/productos'))
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

/// Ancla 4 (v17.8): GASTOS de las compras de Lista — vista resumida que
/// reemplaza los gráficos del módulo Finanzas. Se alimenta AUTOMÁTICA de
/// las compras guardadas (cero carga manual, cero duplicar datos): total
/// del rango + donut por tienda + barras por mes, con la cobertura real
/// de datos siempre a la vista (§ honesto).
class _GastosAnchor extends StatelessWidget {
  const _GastosAnchor({required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));
    final inRange =
        store.purchases.where((p) => !p.date.isBefore(from)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final total = inRange.fold<double>(0, (a, p) => a + p.paidUSD);
    final byStore = storeSpend(inRange);
    final byMonth = monthSpend(store.purchases,
        months: days >= 365 ? 12 : (days >= 183 ? 12 : 6));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      Text(
          'Lo que gastaste según tus compras guardadas — sin registro manual: '
          'cada compra finalizada en Lista entra aquí sola.',
          style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
      const SizedBox(height: 8),
      if (inRange.isEmpty)
        EmptyState('Sin compras en el rango',
            icon: Icons.payments_outlined,
            hint: 'Finaliza una compra en Lista (botón «Finalizar compra») y '
                'este resumen se llena solo: total, tiendas y meses.')
      else ...[
        // Resumen del rango.
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                  rangeName(days) == 'Máximo'
                      ? 'Gastado · todo el historial'
                      : 'Gastado · ${rangeName(days)}',
                  style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              AnimatedNumber(total,
                  style: VeText.displayNum(30, color: scheme.onSurface),
                  decimals: 2),
              const SizedBox(height: 4),
              Text(
                  '${inRange.length} ${inRange.length == 1 ? 'compra' : 'compras'} · '
                  '${byStore.where((s) => s.store != 'Otras' && s.store != 'Sin tienda').length} tiendas',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            ]),
          ),
        ),
        // Donut por tienda (top 6 + Otras).
        if (byStore.length > 1) ...[
          SectionTitle('Por tienda'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SfCircularChart(
                legend: const Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    textStyle: TextStyle(fontSize: 10)),
                series: [
                  DoughnutSeries<({String store, double totalUSD, int count}), String>(
                    dataSource: byStore,
                    xValueMapper: (e, _) => e.store,
                    yValueMapper: (e, _) => e.totalUSD,
                    pointColorMapper: (e, i) =>
                        chartPalette(context)[i % chartPalette(context).length],
                    radius: '70%',
                    dataLabelSettings: const DataLabelSettings(isVisible: false),
                    enableTooltip: true,
                  ),
                ],
              ),
            ),
          ),
        ] else ...[
          SectionTitle('Por tienda'),
          Card(
            child: ListTile(
              dense: true,
              leading: Icon(Icons.storefront_outlined, color: scheme.primary),
              title: Text(byStore.first.store, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
              trailing: Text(fmtUSD(byStore.first.totalUSD),
                  style: VeText.displayNum(13.5, color: sem.neg)),
            ),
          ),
        ],
        // Barras por mes (ventana 6 o 12 meses según el rango).
        if (byMonth.length > 1) ...[
          SectionTitle('Gasto por mes'),
          Card(
            child: SizedBox(
              height: 200,
              child: SfCartesianChart(
                primaryXAxis: const CategoryAxis(),
                tooltipBehavior: TooltipBehavior(enable: true),
                series: [
                  ColumnSeries<({String month, double totalUSD, int count}), String>(
                    dataSource: byMonth,
                    xValueMapper: (e, _) => e.month,
                    yValueMapper: (e, _) => e.totalUSD,
                    name: 'Gasto',
                    color: sem.neg,
                    dataLabelSettings: const DataLabelSettings(isVisible: false),
                    enableTooltip: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ],
    ]);
  }
}

/// Ancla 5: registros propios por fuente (selector MULTI-DIVISA: hasta 3
/// fuentes superpuestas) + gráfica interactiva + tabla + export por columnas.
class _HistoricaAnchor extends StatefulWidget {
  const _HistoricaAnchor({required this.days});
  final int days;

  @override
  State<_HistoricaAnchor> createState() => _HistoricaAnchorState();
}

class _HistoricaAnchorState extends State<_HistoricaAnchor> {
  /// Selección múltiple (historial multi-divisa, §9.7): hasta 3 fuentes.
  final Set<String> _selected = {};

  /// Fuentes CON snapshots locales (sin manuales ni USD: no tienen historial).
  List<String> _sources(AppStore store) {
    final ids = store.snapshots.map((s) => s.sourceId).toSet();
    return [
      for (final s in RateSource.all)
        if (ids.contains(s.id) && s.currency != Currency.usd && s.category != SourceCategory.manual)
          s.id,
    ];
  }

  void _toggle(String id, List<String> sources) {
    setState(() {
      if (_selected.contains(id)) {
        // Nunca queda vacío: la última fuente no se desmarca.
        if (_selected.length > 1) _selected.remove(id);
      } else {
        if (_selected.length >= 3) return; // tope legible de 3 series
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);
    final sources = _sources(store);
    // Selección efectiva: la guardada (válida) o el default honesto.
    final selected = <String>[
      for (final id in _selected.where(sources.contains))
        if (sources.contains(id)) id,
    ];
    if (selected.isEmpty) {
      final def = sources.contains('ves-bcv')
          ? 'ves-bcv'
          : (sources.isNotEmpty ? sources.first : '');
      if (def.isNotEmpty) selected.add(def);
    }
    final multi = selected.length > 1;
    // Serie por fuente seleccionada.
    final seriesById = <String, List<SnapshotPoint>>{
      for (final id in selected)
        id: snapshotSeries(store.snapshots, id, widget.days),
    };
    final allSeries = seriesById.values.expand((s) => s).toList();
    final firstDay = allSeries.isEmpty
        ? null
        : DateTime.tryParse(
            (allSeries.map((p) => p.day).toList()..sort()).first);
    final covPoints = allSeries.map((p) => p.day).toSet().length;
    // Paleta por índice (máx 3): las divisas se distinguen por curva.
    final palette = [scheme.primary, ink.neg, ink.warn];

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const SizedBox(height: 10),
      if (sources.isEmpty)
        EmptyState('Sin historial local aún',
            icon: Icons.history,
            hint: 'Cada día que la app consulta tasas guarda un punto por fuente (máx 180 días). '
                'Entra a Inicio y actualiza para empezar tu libro de tasas.',
            actionLabel: 'Ir a Inicio',
            onAction: () => context.go('/'))
      else ...[
        // Selector MULTI (hasta 3): toca para sumar/quitar fuente de la gráfica.
        Wrap(spacing: 6, runSpacing: 6, children: [
          for (final id in sources)
            ChipTag(RateSource.of(id)?.label ?? id,
                selected: selected.contains(id),
                onTap: () => _toggle(id, sources)),
        ]),
        if (multi)
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Multi-divisa: hasta 3 fuentes superpuestas; la última no se quita.',
                style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
          ),
        const SizedBox(height: 8),
        Text(
          coverageText(
              rangeLabel: rangeName(widget.days),
              requestedDays: widget.days,
              points: covPoints,
              first: firstDay,
              sinceSubject: null),
          style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        if (allSeries.length >= 2)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(10),
              child: SizedBox(
                height: 210,
                child: SfCartesianChart(
                  legend: Legend(
                      isVisible: multi,
                      position: LegendPosition.bottom,
                      textStyle: const TextStyle(fontSize: 10)),
                  primaryXAxis: DateTimeAxis(dateFormat: DateFormat('dd/MM'), majorGridLines: const MajorGridLines(width: 0)),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    activationMode: ActivationMode.singleTap,
                    builder: (dynamic s, dynamic point, dynamic series, int i, int si) {
                      if (i < 0 || s is! List || i >= s.length) return const SizedBox.shrink();
                      final p = s[i] as SnapshotPoint;
                      return _TipBox(main: fmtRate(p.rate), sub: fmtDayLabel(DateTime.parse(p.day)),
                          bg: scheme.primary, fg: scheme.onPrimary);
                    },
                  ),
                  crosshairBehavior: CrosshairBehavior(
                    enable: true,
                    lineType: CrosshairLineType.vertical,
                    lineDashArray: const <double>[4, 3],
                    activationMode: ActivationMode.singleTap,
                  ),
                  series: [
                    for (var k = 0; k < selected.length; k++)
                      LineSeries<SnapshotPoint, DateTime>(
                        dataSource: seriesById[selected[k]]!,
                        xValueMapper: (p, _) => DateTime.parse(p.day),
                        yValueMapper: (p, _) => p.rate,
                        name: RateSource.of(selected[k])?.label ?? selected[k],
                        color: palette[k % palette.length],
                        width: 1.8,
                      ),
                  ],
                ),
              ),
            ),
          )
        else if (allSeries.length == 1)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                'Solo 1 punto con datos (${fmtDate(DateTime.parse(allSeries.first.day))}): '
                'se necesitan al menos 2 fechas para mostrar variación.',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          )
        else
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
                'Aún no hay snapshots de las fuentes elegidas. Profundidad local total: '
                '${snapshotDepth(store.snapshots)} días (máx 180).',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
          ),
        if (allSeries.isNotEmpty) ...[
          const SizedBox(height: 8),
          Card(
            child: Column(children: [
              // Tabla por día: una columna por fuente (multi-divisa real).
              for (final day in (allSeries.map((p) => p.day).toSet().toList()..sort())
                  .reversed
                  .take(10))
                ListTile(
                  dense: true,
                  title: Text(fmtDate(DateTime.parse(day)), style: const TextStyle(fontSize: 12.5)),
                  trailing: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      for (var k = 0; k < selected.length; k++)
                        Padding(
                          padding: EdgeInsets.only(left: k == 0 ? 0 : 10),
                          child: Text(
                              _rateForDay(seriesById[selected[k]]!, day),
                              style: VeText.displayNum(13,
                                  color: multi ? palette[k % palette.length] : scheme.onSurface)),
                        ),
                    ]),
                  ),
                ),
            ]),
          ),
        ],
        const SizedBox(height: 8),
        OutlinedButton.icon(
          icon: const Icon(Icons.table_view, size: 14),
          label: Text(multi ? 'Exportar histórico CSV (${selected.length} fuentes)' : 'Exportar histórico CSV'),
          onPressed: allSeries.isEmpty
              ? null
              : () {
                  // CSV multi-divisa: Día + una columna por fuente elegida.
                  final days = allSeries.map((p) => p.day).toSet().toList()..sort();
                  final rows = <List<String>>[
                    ['Dia', for (final id in selected) id],
                  ];
                  for (final day in days) {
                    rows.add([
                      day,
                      for (final id in selected) _rateForDay(seriesById[id]!, day, raw: true),
                    ]);
                  }
                  showShareFile(
                      context,
                      'valorave-historico${multi ? '-multi' : '-${selected.first}'}.csv',
                      toCSV(rows, delimiter: ';'));
                },
        ),
      ],
    ]);
  }

  /// Tasa de [series] en [day]: formateada o cruda (CSV); '—' si no hay.
  String _rateForDay(List<SnapshotPoint> series, String day, {bool raw = false}) {
    final p = series.where((x) => x.day == day).firstOrNull;
    if (p == null) return raw ? '' : '—';
    return raw ? p.rate.toStringAsFixed(4) : fmtRate(p.rate);
  }
}

/// Burbuja de tooltip firma: valor en displayNum + fecha es-VE abreviada.
class _TipBox extends StatelessWidget {
  const _TipBox({required this.main, required this.sub, required this.bg, required this.fg});

  final String main;
  final String sub;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(color: bg, borderRadius: BorderRadius.circular(8)),
      child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(main, style: VeText.displayNum(12, color: fg)),
        const SizedBox(height: 1),
        Text(sub, style: TextStyle(fontSize: 9.5, color: fg.withValues(alpha: 0.85))),
      ]),
    );
  }
}

/// Calendario pictórico de devaluación (§9.7 · el heatmap 6 m del web —
/// cierra la desviación D2): un cuadro por día, rojo=subida de la tasa
/// (devaluación), verde=baja, intensidad = magnitud vs el día anterior con
/// datos. Últimos 6 meses calendario; sin datos → cuadro neutro (nunca
/// inventa días). Encima del grid: día con mayor subida del período.
class _HeatmapCalendar extends StatelessWidget {
  const _HeatmapCalendar({required this.data});

  /// % diario (vs día anterior con datos) por 'YYYY-MM-DD'.
  final List<({String day, double pct})> data;

  static const int _kMonths = 6;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);
    final byDay = {for (final e in data) e.day: e.pct};
    final maxAbs = data.fold<double>(0, (m, e) => e.pct.abs() > m ? e.pct.abs() : m);
    final worst = data.isEmpty ? null : (data.reduce((a, b) => a.pct >= b.pct ? a : b));

    // Meses calendario: los últimos 6 (incluye el actual), del más viejo al
    // más reciente.
    final now = DateTime.now();
    final months = <DateTime>[
      for (var i = _kMonths - 1; i >= 0; i--) DateTime(now.year, now.month - i, 1),
    ];

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('CALENDARIO DE DEVALUACIÓN · 6 MESES',
              style: VeText.labelCaps(10, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 2),
          Text(
              worst == null
                  ? 'Sin días comparables aún: cada día que la app consulta '
                      'tasas llena un cuadro.'
                  : 'Cuadro por día (BCV vs el día anterior con datos). '
                      'Día con mayor subida: ${fmtDayLabel(DateTime.parse(worst.day))} '
                      '(${worst.pct >= 0 ? '+' : ''}${worst.pct.toStringAsFixed(1)} %).',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 10),
          for (final m in months)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(
                    '${fmtMesCorto(m.month).toUpperCase()} ${m.year}',
                    style: VeText.labelCaps(9.5, color: scheme.primary)),
                const SizedBox(height: 6),
                _monthGrid(context, m, byDay, maxAbs, ink),
              ]),
            ),
          // Leyenda: el color SOLO significa dirección del movimiento.
          Row(children: [
            _legendBox(ink.pos.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text('baja', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
            const SizedBox(width: 10),
            _legendBox(scheme.surfaceContainerHighest),
            const SizedBox(width: 4),
            Text('sin datos', style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
            const SizedBox(width: 10),
            _legendBox(ink.neg.withValues(alpha: 0.7)),
            const SizedBox(width: 4),
            Text('subida · más intenso = mayor cambio',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant)),
          ]),
        ]),
      ),
    );
  }

  Widget _legendBox(Color c) => Container(
        width: 11,
        height: 11,
        decoration: BoxDecoration(
          color: c,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: Colors.black26, width: 0.5),
        ),
      );

  /// Grid de un mes: cuadros cuadrados en 7 columnas (L→D), con blancos de
  /// encuadre al inicio. GridView sin scroll con altura exacta.
  Widget _monthGrid(BuildContext context, DateTime month,
      Map<String, double> byDay, double maxAbs, VeInk ink) {
    final scheme = Theme.of(context).colorScheme;
    final leading = DateTime(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return LayoutBuilder(builder: (ctx, cons) {
      const gap = 3.0;
      final cell = (cons.maxWidth - 6 * gap) / 7;
      final rows = ((leading + daysInMonth) / 7).ceil();
      return SizedBox(
        height: rows * cell + (rows - 1) * gap,
        child: GridView.count(
          crossAxisCount: 7,
          mainAxisSpacing: gap,
          crossAxisSpacing: gap,
          childAspectRatio: 1,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          children: [
            for (var i = 0; i < leading; i++) const SizedBox.shrink(),
            for (var d = 1; d <= daysInMonth; d++)
              _cell(context, DateTime(month.year, month.month, d), byDay, maxAbs, ink, scheme),
          ],
        ),
      );
    });
  }

  Widget _cell(BuildContext context, DateTime day, Map<String, double> byDay,
      double maxAbs, VeInk ink, ColorScheme scheme) {
    final pct = byDay[SnapshotPoint.dayKey(day)];
    Color fill = scheme.surfaceContainerHighest;
    if (pct != null && maxAbs > 0) {
      final t = (pct.abs() / maxAbs).clamp(0.18, 0.85);
      fill = pct > 0
          ? ink.neg.withValues(alpha: t)
          : (pct < 0 ? ink.pos.withValues(alpha: t) : scheme.surfaceContainerHighest);
    }
    final label = pct == null
        ? '${day.day} ${fmtMesCorto(day.month)} sin datos'
        : '${day.day} ${fmtMesCorto(day.month)}: '
            '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)} %';
    return Semantics(
      label: label,
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
    );
  }
}
