/// ─── Análisis (v19.8 · rediseño web-first) ─────────────────────────────────
/// Tablero de análisis rediseñado como un dashboard web: barra de anclas
/// segmentada, fila de KPIs arriba de cada panel, tarjetas-panel con
/// cabecera consistente (título + acción a la derecha), rango de tiempo
/// integrado a la barra y exportación UNIFICADA (el mismo componente en
/// todos los módulos). 6 anclas: Divisas · Inflación · Productos · Canasta
/// · Gastos · Tasa. La lógica de datos no cambia (misma matemática
/// testeada); cambia la PRESENTACIÓN.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/analytics.dart' as an;
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/shad_theme.dart' show kShadControlRadius;
import '../../core/theme.dart';
import '../../data/history_api.dart';
import '../../data/rate_history.dart';
import '../../data/store.dart';
import '../../widgets/app_tour.dart' show TourKeys;
import '../../widgets/export_sheet.dart';
import '../../widgets/ui.dart';
import 'insights_panels.dart';
import 'insights_utils.dart';

class InsightsScreen extends StatefulWidget {
  const InsightsScreen({super.key});

  @override
  State<InsightsScreen> createState() => _InsightsScreenState();
}

class _InsightsScreenState extends State<InsightsScreen> {
  int _anchor =
      0; // 0 divisas · 1 inflación · 2 productos · 3 canasta · 4 gastos · 5 tasa
  int _days = 30; // 1 M · 6 M · 1 Año · Máximo (3650 = todo lo que haya)

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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: VeEntry(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            VeTitle(
              // v20 (distill): fuera la prosa decorativa — subtítulo
              // informativo de una línea.
              sub: const Text('Tasas, inflación, canasta y gastos'),
              child: const Text('Análisis'),
            ),
            // ── Barra de anclas (v19.8): segmentada, 6 vistas del tablero.
            // TASK-34 p9: cromática del segmentado Ve (muted + borde),
            // píldora activa card + borde + sombra corta — sin pérdida de
            // iconos (la superioridad táctil de la app).
            KeyedSubtree(
              key: TourKeys.anclas,
              child: Builder(
                builder: (barCtx) {
                  final shad = ShadTheme.of(barCtx).colorScheme;
                  return Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: shad.muted,
                      borderRadius: BorderRadius.circular(kShadControlRadius),
                      border: Border.all(color: shad.border),
                    ),
                    child: Row(
                      children: [
                        for (var i = 0; i < _anchors.length; i++)
                          Expanded(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 2,
                              ),
                              child: _AnchorTab(
                                icon: _anchors[i].$1,
                                label: _anchors[i].$2,
                                selected: _anchor == i,
                                onTap: () => setState(() => _anchor = i),
                              ),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
            // ── Rango: chips del prototipo pegados a la barra de anclas.
            const SizedBox(height: 8),
            KeyedSubtree(
              key: TourKeys.rango,
              child: Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final (d, label) in _ranges)
                    VeChip(
                      active: _days == d,
                      onTap: () => setState(() => _days = d),
                      child: Text(label),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 6),
            switch (_anchor) {
              0 => _DivisasAnchor(days: _days),
              1 => _InflacionAnchor(
                days: _days,
                onGoToBasket: () => setState(() => _anchor = 3),
              ),
              2 => ProductosAnchor(days: _days),
              3 => const CanastaAnchor(),
              4 => GastosAnchor(days: _days),
              _ => HistoricaAnchor(days: _days),
            },
          ],
        ),
      ),
    );
  }
}

/// Tab de ancla: icono + etiqueta en columna, fondo píldora cuando activo
/// (el segmented-control de la web, táctil).
class _AnchorTab extends StatelessWidget {
  const _AnchorTab({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context).colorScheme;
    final scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 160),
        padding: const EdgeInsets.symmetric(vertical: 7),
        decoration: BoxDecoration(
          // Píldora activa del VeSegmented: superficie card + borde y una
          // sombra corta — la píldora «flota» sobre el muted del contenedor.
          color: selected ? shad.card : null,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: selected ? shad.border : Colors.transparent,
          ),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: dark
                        ? Colors.black.withValues(alpha: 0.35)
                        : const Color(0x1409090B),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ]
              : null,
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 15,
              color: selected ? shad.foreground : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 3),
            Text(
              label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 9.5,
                fontWeight: FontWeight.w500,
                color: selected ? shad.foreground : scheme.onSurfaceVariant,
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
      final store = context.read<AppStore>();
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
      final d =
          (DateTime.parse(pts[i].date).millisecondsSinceEpoch - ms).abs();
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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── KPIs: la brecha + las dos tasas del día, en una fila (web).
        const SizedBox(height: 8),
        KpiRow(
          tiles: [
            KpiTile(
              // v21 (GUI superior): «Brecha» a secas — el par queda escrito
              // en el panel que sigue («BCV ↔ PARALELO») y en móvil la
              // etiqueta larga se cortaba con «…» aunque pidiera 2 líneas.
              label: 'Brecha',
              value: gap == null ? '—' : fmtPct(gap),
              sub: gap != null && gap.abs() >= 15
                  ? 'brecha alta'
                  : (gap != null ? 'brecha normal' : null),
              icon: LucideIcons.arrowLeftRight,
              color: gap == null ? scheme.onSurface : ink.warn,
            ),
            KpiTile(
              label: 'BCV hoy',
              value: bcv.isEmpty ? '—' : fmtRate(bcv.last.rate),
              sub: bcv.isEmpty
                  ? null
                  : fmtDayShort(DateTime.parse(bcv.last.date)),
              icon: LucideIcons.landmark,
              color: ink.pos,
            ),
            KpiTile(
              label: 'Paralelo hoy',
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
                  height: 190,
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
        // Lookup por fecha (compacto: una tarjeta, no una sección gigante).
        const SizedBox(height: 10),
        const _LookupFecha(),
      ],
    );
  }
}

/// Panel del día tocado en la gráfica de brecha, en 3 columnas como las
/// stat-rows de la web: BCV · Paralelo · Brecha % de ESE día (paralelo/BCV
/// − 1, solo con ambas tasas > 0). Sin tap: último día.
class _DayPanel extends StatelessWidget {
  const _DayPanel({
    required this.bcv,
    required this.parallel,
    required this.index,
  });

  final List<HistPoint> bcv;
  final List<HistPoint> parallel;
  final int? index;

  @override
  Widget build(BuildContext context) {
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
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                index == null ? 'ÚLTIMO DÍA' : 'DÍA TOCADO',
                style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              Text(
                fmtDate(DateTime.parse(p.date)),
                style: TextStyle(
                  fontSize: 11.5,
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
                  fontSize: 10.5,
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
            8.5,
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
                    fontSize: 12,
                    fontStyle: FontStyle.italic,
                    fontWeight: FontWeight.w500,
                    color: color,
                  )
                : VeText.displayNum(
                    15,
                    color: color,
                    weight: bold ? FontWeight.w800 : FontWeight.w700,
                  ),
          ),
        ),
      ],
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
    return PanelCard(
      title: 'Consultar tasa por fecha',
      subtitle:
          'Tus snapshots locales — desde el día que la app empezó a '
          'consultar tasas',
      child: Column(
        children: [
          // v20 (VLM gate): el selector de fecha es un CAMPO de verdad —
          // píldora tocable con icono de calendario y chevron (antes era
          // texto plano + botón «Elegir» que nadie veía).
          InkWell(
            onTap: () async {
              final d = await showDatePicker(
                context: context,
                initialDate: _date,
                firstDate: DateTime(2023, 1, 3),
                lastDate: DateTime.now(),
                locale: const Locale('es'),
              );
              if (d == null || !context.mounted) return;
              final store = context.read<AppStore>();
              final day = SnapshotPoint.dayKey(d);
              final b = store.snapshots
                  .where((p) => p.sourceId == 'ves-bcv' && p.day == day)
                  .firstOrNull;
              final p = store.snapshots
                  .where(
                    (x) => x.sourceId == 'ves-parallel' && x.day == day,
                  )
                  .firstOrNull;
              setState(() {
                _date = d;
                _rateB = b?.rate;
                _rateP = p?.rate;
                _searched = true;
              });
            },
            borderRadius: BorderRadius.circular(10),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLowest,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.calendarDays,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      fmtDate(_date),
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Icon(
                    LucideIcons.chevronDown,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_rateB != null)
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => copiarAlPortapapeles(
                  context,
                  'BCV ${fmtDate(_date)}: ${fmtRate(_rateB!)}',
                  'Tasa copiada',
                ),
                child: const Text('Copiar'),
              ),
            ),
          if (_rateB != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LedgerRow(
                label: 'BCV · ${fmtDate(_date)}',
                value: '${fmtRate(_rateB!)} Bs/USD',
                valueColor: ink.pos,
                boldValue: true,
              ),
            ),
          if (_rateP != null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: LedgerRow(
                label: 'Paralelo · ${fmtDate(_date)}',
                value: '${fmtRate(_rateP!)} Bs/USD',
                valueColor: ink.neg,
                boldValue: true,
              ),
            ),
          if (_searched && _rateB == null && _rateP == null)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                'Sin registro local para esa fecha: los snapshots empiezan el día '
                'que la app consulta tasas. Para tasas remotas de fechas pasadas '
                'usa el Conversor → fecha histórica.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// ───────────────────────── Ancla 2: Inflación ──────────────────────────────

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
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
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
                  height: 190,
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
                        fontSize: 10.5,
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
                        fontSize: 12,
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
                    style: VeText.labelCaps(10, color: scheme.onSurfaceVariant),
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
              height: 190,
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
