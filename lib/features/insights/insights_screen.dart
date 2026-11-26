/// ─── Análisis (v19.8 · rediseño web-first) ─────────────────────────────────
/// Tablero de análisis (v30 · H-39/H-40): CUATRO secciones — Divisas ·
/// Inflación · Canasta · Gastos — en la MISMA barra segmentada de 44 px
/// del Conversor (píldora deslizante, a todo lo ancho del contenido). El
/// rango `VeSegmented` vive a todo lo ancho SOLO en las secciones que lo
/// usan (Canasta no tiene rango). H-40: «Tasa» y «Productos» salieron
/// (repetían el Conversor y el desglose de Inflación/Gastos);
/// `CurrencyRanking` emigró a Gastos. La lógica de datos no cambia (misma
/// matemática testeada).
library;

import 'package:flutter/material.dart';

import '../../core/analytics.dart' as an;
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/history_api.dart';
import '../../data/rate_history.dart';
import '../../widgets/app_tour.dart' show TourKeys;
import '../../widgets/export_sheet.dart';
import '../../widgets/ui.dart';
import 'insights_panels.dart';
import 'insights_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorave/providers/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:intl/intl.dart';

class InsightsScreen extends ConsumerStatefulWidget {
  const InsightsScreen({super.key});

  @override
  ConsumerState<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends ConsumerState<InsightsScreen> {
  int _anchor = 0; // 0 divisas · 1 inflación · 2 canasta · 3 gastos
  int _days = 30; // 1 M · 6 M · 1 Año · Máximo (3650 = todo lo que haya)

  static const _anchors = <VeSegment<int>>[
    VeSegment(value: 0, label: 'Divisas'),
    VeSegment(value: 1, label: 'Inflación'),
    VeSegment(value: 2, label: 'Canasta'),
    VeSegment(value: 3, label: 'Gastos'),
  ];

  /// Secciones que usan el rango (H-39): Canasta es un CRUD sin ventana
  /// de tiempo — la barra del rango no existe ahí.
  bool get _rangoAplica => _anchor != 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: VeEntry(
        // v23.3 (pez 2-a): título + barra de anclas + rango FIJOS — antes
        // vivían DENTRO del ListView y al scrollear paneles largos (Canasta
        // con N ítems, tabla «Últimos días») la navegación se iba del
        // viewport. Ahora solo scrollea el panel activo; las anclas del
        // tour viajan con los widgets (TourKeys.anclas/rango intactas).
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: VeTitle(
                // v20 (distill): fuera la prosa decorativa — subtítulo
                // informativo de una línea.
                sub: const Text('Tasas, inflación, canasta y gastos'),
                child: const Text('Análisis'),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Barra de secciones (v30 · H-39): el MISMO control
                  // del Conversor — VeSegmented de 44 px con píldora
                  // deslizante, a todo lo ancho del contenido. Cuatro
                  // secciones respiran; las 6 anclas viejas quedaban
                  // apretadas y desalineadas.
                  KeyedSubtree(
                    key: TourKeys.anclas,
                    child: VeSegmented<int>(
                      value: _anchor,
                      height: 44,
                      onChanged: (i) => setState(() => _anchor = i),
                      segments: _anchors,
                    ),
                  ),
                  // ── Rango (H-39): VeSegmented a todo lo ancho, SOLO en
                  // las secciones que lo usan. R-30f: Offstage — montado
                  // SIEMPRE (el paso del tour enfoca su rect), invisible
                  // cuando no aplica (Canasta).
                  Offstage(
                    offstage: !_rangoAplica,
                    child: Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: KeyedSubtree(
                        key: TourKeys.rango,
                        child: VeSegmented<int>(
                          value: _days,
                          onChanged: (d) => setState(() => _days = d),
                          segments: const [
                            VeSegment(value: 30, label: '1 M'),
                            VeSegment(value: 183, label: '6 M'),
                            VeSegment(value: 365, label: '1 Año'),
                            VeSegment(value: 3650, label: 'Máximo'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 24),
                children: [
                  switch (_anchor) {
                    0 => _DivisasAnchor(days: _days),
                    1 => _InflacionAnchor(
                      days: _days,
                      onGoToBasket: () => setState(() => _anchor = 2),
                    ),
                    2 => const CanastaAnchor(),
                    _ => GastosAnchor(days: _days),
                  },
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ───────────────────────── Ancla 1: Divisas ────────────────────────────────

/// Ancla 1: KPIs (brecha + tasas) + gráfica interactiva con trackball por
/// día + panel del día en 3 columnas + exportación unificada + lookup por
/// fecha.
class _DivisasAnchor extends ConsumerStatefulWidget {
  const _DivisasAnchor({required this.days});
  final int days;

  @override
  ConsumerState<_DivisasAnchor> createState() => _DivisasAnchorState();
}

class _DivisasAnchorState extends ConsumerState<_DivisasAnchor> {
  List<HistPoint>? _bcv;
  List<HistPoint>? _parallel;
  String? _error;
  bool _loading = true;
  int? _gapIdx; // punto tocado en la serie BCV (trackball)

  // Trackball tap-friendly: divisor vertical PUNTEADO en el punto exacto +
  // burbujas de ambas series + marcador en el punto tocado (§ interactivas).
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
    setState(() {
      _loading = true;
      _error = null;
      _gapIdx = null;
    });
    try {
      final b = await veHistory(eur: false, paralelo: false, days: widget.days);
      final p = await veHistory(eur: false, paralelo: true, days: widget.days);
      if (!mounted) return;
      setState(() {
        _bcv = b.points;
        _parallel = p.points;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      // Fallback honesto: snapshots locales (hasta 180 días reales).
      final store = ref.read(appStoreProvider);
      final localB = snapshotSeries(store.snapshots, 'ves-bcv', widget.days);
      final localP = snapshotSeries(
        store.snapshots,
        'ves-parallel',
        widget.days,
      );
      if (localB.length >= 2) {
        setState(() {
          _bcv = localB
              .map((s) => HistPoint(date: s.day, rate: s.rate))
              .toList();
          _parallel = localP
              .map((s) => HistPoint(date: s.day, rate: s.rate))
              .toList();
          _loading = false;
          _error = 'Serie local (sin conexión al histórico remoto)';
        });
      } else {
        setState(() {
          _loading = false;
          _error = 'Sin conexión y sin snapshots guardados';
        });
      }
    }
  }

  // Guarda el punto tocado para el panel de brecha diaria (feedback visible).
  /// Índice del punto de BCV más cercano a la fecha tocada en la gráfica
  /// (v20.4: sustituye al trackball de syncfusion — el panel de día
  /// sincroniza con el crosshair de VeTimelineChart).
  int _nearestIdx(List<HistPoint> pts, DateTime t) {
    final ms = t.millisecondsSinceEpoch;
    var best = 0;
    var bestD = (DateTime.parse(pts.first.date).millisecondsSinceEpoch - ms)
        .abs();
    for (var i = 1; i < pts.length; i++) {
      final d = (DateTime.parse(pts[i].date).millisecondsSinceEpoch - ms).abs();
      if (d < bestD) {
        best = i;
        bestD = d;
      }
    }
    return best;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);
    final store = ref.watch(appStoreProvider);
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── KPIs: la brecha + las dos tasas del día, en una fila (web).
        const SizedBox(height: 8),
        KpiRow(
          tiles: [
            KpiTile(
              // v21 (GUI superior) + v30 (H-40): «Brecha» a secas — sin
              // adjetivos redundantes («brecha alta»): el par queda
              // escrito en el panel que sigue («BCV ↔ PARALELO»).
              label: 'Brecha',
              value: gap == null ? '—' : fmtPct(gap),
              icon: LucideIcons.arrowLeftRight,
              color: gap == null ? scheme.onSurface : ink.warn,
            ),
            KpiTile(
              // v23.3: «BCV» a secas (simetría con «Paralelo» — ver arriba).
              label: 'BCV',
              value: bcv.isEmpty ? '—' : fmtRate(bcv.last.rate),
              sub: bcv.isEmpty
                  ? null
                  : fmtDayShort(DateTime.parse(bcv.last.date)),
              icon: LucideIcons.landmark,
              color: ink.pos,
            ),
            KpiTile(
              // v23.3 (gate visual): «Paralelo» a secas — igual que «Brecha»
              // en v21: a 390 la etiqueta larga envolvía a 2 líneas y se
              // amontonaba con el sub; el «hoy» ya lo dice la fecha del sub.
              label: 'Paralelo',
              value: par.isEmpty ? '—' : fmtRate(par.last.rate),
              sub: par.isEmpty
                  ? 'sin registro hoy'
                  : fmtDayShort(DateTime.parse(par.last.date)),
              icon: LucideIcons.store,
              color: ink.neg,
            ),
          ],
        ),
        if (_error != null)
          InlineHint(
            '$_error · ',
            icon: Icons.wifi_off,
            actionLabel: 'Reintentar',
            onAction: _load,
          )
        else if (!_loading && !ready)
          InlineHint(
            'Serie insuficiente para graficar: ${bcv.length} '
            '${bcv.length == 1 ? 'punto' : 'puntos'} con datos. Cada día que la app '
            'consulta tasas guarda un punto por fuente (máx 180 días).',
            icon: Icons.hourglass_empty,
          ),
        if (_loading)
          const Padding(
            padding: EdgeInsets.all(20),
            child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
          )
        else if (ready)
          PanelCard(
            title: 'BCV ↔ Paralelo',
            subtitle: coverageText(
              rangeLabel: rangeName(widget.days),
              requestedDays: widget.days,
              points: covPoints,
              first: covFirst,
              sinceSubject: covSubject,
            ),
            // Exportación UNIFICADA (v19.8): el mismo componente de toda la
            // app — aquí sale la brecha diaria en CSV.
            action: IconButton(
              tooltip: 'Exportar',
              icon: Icon(Icons.ios_share, size: 17, color: scheme.primary),
              onPressed: bcv.isEmpty || par.isEmpty
                  ? null
                  : () => showExportSheet(
                      context,
                      ExportSpec(
                        title: 'Brecha BCV ↔ Paralelo',
                        subtitle:
                            '${rangeName(widget.days)} · '
                            '$covPoints días con datos',
                        formats: [
                          csvFormat(
                            hint: 'La brecha por día: ambas tasas y el %',
                            fileName:
                                'valorave-brecha-${SnapshotPoint.dayKey(DateTime.now())}.csv',
                            rows: () => gapCsvRows(bcv, par),
                          ),
                        ],
                      ),
                    ),
            ),
            child: Column(
              children: [
                // v20.4: VeTimelineChart (CustomPainter propio) en lugar de
                // syncfusion — área BCV + línea Paralelo, leyenda y el
                // panel de día sincronizado con el dedo (onScrub).
                VeTimelineChart(
                  // v23.3 (pez 2-a): 184 — la familia de referencia del kit
                  // (product_sheet 186, default 200) y la meta sin scroll.
                  height: 184,
                  // 9P·Pulido: margen interno para que la curva no roce
                  // el borde superior de la tarjeta (auditoría de la web).
                  margin: const EdgeInsets.fromLTRB(6, 14, 10, 4),
                  legend: true,
                  xLabel: (t) => DateFormat('dd/MM').format(t),
                  yLabel: (v) => fmtNum(v, decimals: 0),
                  semantic: 'Brecha entre BCV y Paralelo',
                  onScrub: (t) {
                    if (!mounted) return;
                    setState(() {
                      _gapIdx = t == null ? null : _nearestIdx(bcv, t);
                    });
                  },
                  series: [
                    VeTimelineSeries(
                      name: 'BCV',
                      points: [
                        for (final p in bcv)
                          VeTimelinePoint(DateTime.parse(p.date), p.rate),
                      ],
                      color: ink.pos,
                      area: true,
                      format: (v) => fmtRate(v),
                    ),
                    if (par.isNotEmpty)
                      VeTimelineSeries(
                        name: 'Paralelo',
                        points: [
                          for (final p in par)
                            VeTimelinePoint(DateTime.parse(p.date), p.rate),
                        ],
                        color: ink.neg,
                        width: 1.8,
                        format: (v) => fmtRate(v),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                _DayPanel(bcv: bcv, parallel: par, index: _gapIdx),
              ],
            ),
          ),
      ],
    );
  }
}

/// Panel del día tocado en la gráfica de brecha, en 3 columnas como las
/// stat-rows de la web: BCV · Paralelo · Brecha % de ESE día (paralelo/BCV
/// − 1, solo con ambas tasas > 0). Sin tap: último día.
class _DayPanel extends ConsumerWidget {
  const _DayPanel({
    required this.bcv,
    required this.parallel,
    required this.index,
  });

  final List<HistPoint> bcv;
  final List<HistPoint> parallel;
  final int? index;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);
    if (bcv.isEmpty) return const SizedBox.shrink();
    final i = (index == null || index! < 0 || index! >= bcv.length)
        ? bcv.length - 1
        : index!;
    final p = bcv[i];
    final parPoint = parallel.where((x) => x.date == p.date).firstOrNull;
    final g = gapForDay(bcv, parallel, p.date);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      // v25 «HOJA»: panel del día PLANO — eyebrow + datos, sin caja.
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                index == null ? 'ÚLTIMO DÍA' : 'DÍA TOCADO',
                style: VeText.labelCaps(11, color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                fmtDate(DateTime.parse(p.date)),
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: _dayCol(
                  context,
                  label: 'BCV',
                  value: fmtRate(p.rate),
                  color: ink.pos,
                ),
              ),
              Expanded(
                child: _dayCol(
                  context,
                  label: 'Paralelo',
                  value: parPoint == null ? 'sin dato' : fmtRate(parPoint.rate),
                  color: parPoint == null ? scheme.onSurfaceVariant : ink.neg,
                  dimmed: parPoint == null,
                ),
              ),
              Expanded(
                child: _dayCol(
                  context,
                  label: 'Brecha',
                  value: g == null ? '—' : fmtPct(g.pct),
                  color: g == null ? scheme.onSurfaceVariant : ink.warn,
                  bold: true,
                  dimmed: g == null,
                ),
              ),
            ],
          ),
          if (parPoint == null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                'El paralelo no tiene registro ese día: la brecha necesita ambas '
                'tasas (>0) el mismo día.',
                style: TextStyle(
                  fontSize: 11,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _dayCol(
    BuildContext context, {
    required String label,
    required String value,
    required Color color,
    bool bold = false,
    bool dimmed = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: VeText.labelCaps(
            11,
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 3),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            value,
            // 9P·Pulido: «sin dato»/«—» baja de peso y tamaño — ya no
            // compite visualmente con las cifras reales del panel.
            style: dimmed
                ? TextStyle(
                    fontSize: 13.5,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: color,
                  )
                : VeText.displayNum(
                    17,
                    color: color,
                    weight: bold ? FontWeight.w800 : FontWeight.w700,
                  ),
          ),
        ),
      ],
    );
  }
}

// ───────────────────────── Ancla 2: Inflación ──────────────────────────────

/// Ancla 2: inflación personal (canasta ponderada por costo + promedio simple
/// de todos los productos) + serie de costo de la canasta + devaluación BCV.
class _InflacionAnchor extends ConsumerWidget {
  const _InflacionAnchor({required this.days, required this.onGoToBasket});

  final int days;
  final VoidCallback onGoToBasket;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);

    // Inflación personal de la CANASTA (ponderada por costo, §4 del web).
    final b = basketInflation(store.basket, store.products, days: days);
    // Todos los productos con ≥2 registros en el rango (promedio simple).
    final prod = productsInflation(store.products, days: days);
    // Serie de costo de la canasta (forward-fill desde el común más antiguo).
    final costSeries = basketCostSeries(
      store.basket,
      store.products,
      days: days,
    );
    // Proyección punteada DAMP (§9.7 · φ 0.85, misma semántica de predictPrice):
    // 30 días de canasta al momentum amortiguado — memoria, no promesa.
    final costProj = dampProjection([
      for (final e in costSeries) (day: e.day, value: e.cost),
    ]);
    // Devaluación BCV (curva) — reutiliza an.vesRateTimeline + an.vesDevaluation.
    final timeline = an.vesRateTimeline(
      store.snapshots
          .where((p) => p.sourceId == 'ves-bcv')
          .map(
            (s) => PriceRecord(
              id: s.day,
              price: s.rate,
              originalPrice: s.rate,
              currency: 'VES',
              quantity: 1,
              rate: s.rate,
              sourceId: 'ves-bcv',
              date: DateTime.parse(s.day),
            ),
          )
          .toList(),
    );
    final deval = an.vesDevaluation(timeline);
    final devalPoints = timeline
        .map(
          (p) => HistPoint(date: SnapshotPoint.dayKey(p.date), rate: p.price),
        )
        .toList();

    final breaks = b?.breaks ?? const <BasketBreak>[];
    final ups = [...breaks.where((e) => e.pct > 0)]
      ..sort((x, y) => y.pct.compareTo(x.pct));
    final downs = [...breaks.where((e) => e.pct < 0)]
      ..sort((x, y) => x.pct.compareTo(y.pct));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 8),
        // ── KPIs: personal · productos · devaluación (la fila de arriba).
        KpiRow(
          tiles: [
            KpiTile(
              label: 'Inflación personal',
              value: b == null ? '—' : fmtPct(b.pct),
              sub: b == null
                  ? 'canasta sin ≥2 registros'
                  : 'canasta · ${b.measured} productos',
              icon: Icons.local_fire_department_outlined,
              color: b == null
                  ? scheme.onSurface
                  : (b.pct > 0
                        ? ink.neg
                        : (b.pct < 0 ? ink.pos : scheme.onSurface)),
            ),
            KpiTile(
              label: 'Todos tus productos',
              value: prod == null ? '—' : fmtPct(prod.pct),
              sub: prod == null
                  ? 'sin ≥2 registros'
                  : 'promedio simple · ${prod.products}',
              icon: Icons.inventory_2_outlined,
            ),
            KpiTile(
              label: 'Devaluación BCV',
              value: deval == null ? '—' : fmtPct(deval.pct),
              sub: deval == null
                  ? 'sin serie suficiente'
                  : 'desde ${fmtDate(deval.fromAt)}',
              icon: Icons.trending_down,
              color: ink.neg,
            ),
          ],
        ),
        if (b != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'Costo de la canasta: ${fmtUSD(b.oldCost)} → ${fmtUSD(b.newCost)} · '
              'desde ${fmtDate(b.fromAt)}',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          )
        else
          VeEmpty(
            icon: LucideIcons.flame,
            title: 'Sin inflación personal medible todavía',
            sub:
                'Tu inflación personal sale de tu canasta: necesita productos con ≥2 registros '
                'dentro del rango elegido. Agrega productos a la canasta y registra sus precios.',
            action: VeBtn(
              size: VeBtnSize.sm,
              variant: VeBtnVariant.secondary,
              onPressed: onGoToBasket,
              child: const Text('Ver canasta'),
            ),
          ),
        if (b != null && b.skipped > 0)
          InlineHint(
            '${b.skipped} de ${store.basket.length} productos de la canasta sin '
            '≥2 registros en el rango: no se inventa su variación.',
            icon: Icons.rule,
          ),
        if (costSeries.length >= 2) ...[
          const SizedBox(height: 10),
          PanelCard(
            title: 'Costo de la canasta (USD)',
            subtitle: coverageText(
              rangeLabel: rangeName(days),
              requestedDays: days,
              points: costSeries.length,
              first: costSeries.first.day,
              sinceSubject: 'canasta',
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // v20.4: VeTimelineChart — área real + proyección PUNTEADA
                // (DAMP φ 0.85) que se distingue a la vista de la serie real.
                VeTimelineChart(
                  height: 184,
                  margin: EdgeInsets.zero,
                  xLabel: (t) => DateFormat('dd/MM').format(t),
                  yLabel: (v) => fmtNum(v, decimals: 0),
                  semantic: 'Costo de la canasta en dólares',
                  tooltipBuilder: (t, rows) => TipBox(
                    main: rows.isEmpty ? '' : rows.first.$2,
                    sub: fmtDayLabel(t),
                    bg: scheme.primary,
                    fg: scheme.onPrimary,
                  ),
                  series: [
                    VeTimelineSeries(
                      name: 'Canasta',
                      points: [
                        for (final p in costSeries)
                          VeTimelinePoint(p.day, p.cost),
                      ],
                      color: ink.manual,
                      area: true,
                      format: fmtUSD,
                    ),
                    if (costProj != null)
                      VeTimelineSeries(
                        name: 'Proyección 30 d',
                        points: [
                          for (final p in costProj.points)
                            VeTimelinePoint(p.day, p.value),
                        ],
                        color: ink.warn,
                        dashed: true,
                        dashPattern: const <double>[6, 4],
                        width: 1.6,
                        format: fmtUSD,
                      ),
                  ],
                ),
                if (costProj != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Línea punteada: proyección 30 días con memoria amortiguada '
                      '(φ 0,85 · ${fmtPct(costProj.dailyPct, decimals: 2)}/día). '
                      'Es una lectura del momentum, no una promesa.',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ],
        if (ups.isNotEmpty || downs.isNotEmpty) ...[
          const SizedBox(height: 10),
          PanelCard(
            title: 'Desglose por producto',
            subtitle: 'Los que más movieron tu canasta en ${rangeName(days)}',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (ups.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Sin subidas registradas en el rango.',
                      style: TextStyle(
                        fontSize: 13.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                for (final e in ups.take(5))
                  LedgerRow(
                    label: e.name,
                    value: fmtPct(e.pct),
                    valueColor: ink.neg,
                  ),
                if (downs.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Text(
                    'MAYORES BAJADAS',
                    style: VeText.labelCaps(11, color: scheme.onSurfaceVariant),
                  ),
                ],
                for (final e in downs.take(5))
                  LedgerRow(
                    label: e.name,
                    value: fmtPct(e.pct),
                    valueColor: ink.pos,
                  ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 10),
        if (deval != null)
          PanelCard(
            title: 'Devaluación BCV (serie diaria)',
            subtitle: coverageText(
              rangeLabel: 'Serie BCV',
              requestedDays: days,
              points: devalPoints.length,
              first: devalPoints.isEmpty
                  ? null
                  : DateTime.tryParse(devalPoints.first.date),
              sinceSubject: 'BCV',
            ),
            // v20.4: VeTimelineChart en lugar de syncfusion.
            child: VeTimelineChart(
              height: 184,
              margin: EdgeInsets.zero,
              xLabel: (t) => DateFormat('dd/MM').format(t),
              yLabel: (v) => fmtNum(v, decimals: 0),
              semantic: 'Devaluación diaria del BCV',
              tooltipBuilder: (t, rows) => TipBox(
                main: 'BCV ${rows.isEmpty ? '' : rows.first.$2}',
                sub: fmtDayLabel(t),
                bg: scheme.primary,
                fg: scheme.onPrimary,
              ),
              series: [
                VeTimelineSeries(
                  name: 'BCV',
                  points: [
                    for (final p in devalPoints)
                      VeTimelinePoint(DateTime.parse(p.date), p.rate),
                  ],
                  color: ink.manual,
                  area: true,
                  format: fmtRate,
                ),
              ],
            ),
          )
        else
          InlineHint(
            'Sin snapshots suficientes: la serie local se construye cada día '
            'que la app consulta tasas (máx 180 días).',
            icon: Icons.hourglass_empty,
          ),
        // Heatmap de devaluación (§9.7 · calendario 6 m pictórico — cierra D2):
        // % diario del BCV en calendario; rojo=subida (devaluación), verde=baja.
        // v19.8: solo meses con datos — nada de media pantalla de cuadros vacíos.
        HeatmapCalendar(
          data: devaluationDaily(
            store.snapshots.where((p) => p.sourceId == 'ves-bcv').toList(),
          ),
        ),
        if (prod == null && b == null)
          InlineHint(
            'Tu inflación por productos necesita ≥2 registros en el rango: '
            'registra precios en Productos para medir variaciones.',
            icon: Icons.rule,
          ),
      ],
    );
  }
}
