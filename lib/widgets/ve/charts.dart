/// ─── Gráficos «Ve» · fl_chart (v24 · la librería de CalculaYa) ──────────────
/// Sparkline, barras redondeadas, donut con leyenda y el timeline multi-serie
/// — los gráficos de la app sobre `fl_chart` (la MISMA librería que usa
/// CalculaYa, confirmada por REA de su APK), vestidos con el lenguaje del
/// prototipo: paleta por tono idéntica a charts.tsx, grid punteado, tooltips
/// de superficie con borde fuerte y cifras tabulares.
///
/// v24: VeAreaChart y VeHeatmap (sin llamadas en producción) y el Sparkline
/// legacy de ui.dart se retiraron; CustomPainter quedó solo para lo
/// decorativo (banderas, ambientes) — los DATOS viven en fl_chart.
library;

import 'dart:math' as math;

import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';

import 'package:valorave/core/ve_theme.dart';
import '../../core/theme.dart';

/// Tono de serie.
enum VeChartTone { pos, neg, warn, info, fg, muted }

/// Resuelve el color de un tono con el tema activo.
Color _toneColor(BuildContext context, VeChartTone tone) {
  final scheme = context.ve.colorScheme;
  final VeInk ink = Theme.of(context).extension<VeInk>()!;
  return switch (tone) {
    VeChartTone.pos => ink.pos,
    VeChartTone.neg => ink.neg,
    VeChartTone.warn => ink.warn,
    VeChartTone.info => ink.manual,
    VeChartTone.fg => scheme.foreground,
    VeChartTone.muted => scheme.mutedForeground,
  };
}

// ─────────────────────────────────────────────────────────── Sparkline ─────

/// Sparkline del prototipo (ui.tsx): polyline 1.6 px sin relleno; sin datos,
/// línea punteada tenue (estado 30 % de opacidad).
class VeSparkline extends StatelessWidget {
  const VeSparkline({
    super.key,
    required this.data,
    this.tone = VeChartTone.pos,
    this.height = 32,
  });

  final List<double> data;
  final VeChartTone tone;
  final double height;

  @override
  Widget build(BuildContext context) {
    final Color color = _toneColor(context, tone);

    if (data.length < 2) {
      // Estado vacío honesto: línea punteada al 40 % de la altura.
      return SizedBox(
        height: height,
        width: double.infinity,
        child: LineChart(
          LineChartData(
            minY: 0,
            maxY: 1,
            minX: 0,
            maxX: 1,
            gridData: const FlGridData(show: false),
            titlesData: const FlTitlesData(show: false),
            borderData: FlBorderData(show: false),
            lineTouchData: const LineTouchData(enabled: false),
            lineBarsData: [
              LineChartBarData(
                spots: const [FlSpot(0, 0.6), FlSpot(1, 0.6)],
                barWidth: 1.2,
                color: color.withValues(alpha: 0.3),
                dashArray: const [4, 4],
                dotData: const FlDotData(show: false),
              ),
            ],
          ),
        ),
      );
    }

    final min = data.reduce(math.min);
    final max = data.reduce(math.max);
    final rng = (max - min) == 0 ? 1.0 : (max - min);
    // 15 % de aire vertical para que la línea no pegue en los bordes.
    return SizedBox(
      height: height,
      width: double.infinity,
      child: LineChart(
        LineChartData(
          minY: min - rng * 0.15,
          maxY: max + rng * 0.15,
          minX: 0,
          maxX: (data.length - 1).toDouble(),
          gridData: const FlGridData(show: false),
          titlesData: const FlTitlesData(show: false),
          borderData: FlBorderData(show: false),
          lineTouchData: const LineTouchData(enabled: false),
          lineBarsData: [
            LineChartBarData(
              spots: [
                for (var i = 0; i < data.length; i++) FlSpot(i.toDouble(), data[i]),
              ],
              isCurved: false,
              barWidth: 1.6,
              color: color,
              dotData: const FlDotData(show: false),
            ),
          ],
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────── Barras ───────

/// Barras del prototipo: redondeadas arriba (4), tope 26 de ancho, etiqueta
/// de la categoría abajo y tooltip al tocar la barra.
class VeBars extends StatelessWidget {
  const VeBars({
    super.key,
    required this.labels,
    required this.data,
    this.tone = VeChartTone.fg,
    this.height = 120,
    this.formatValue,
    this.semantic,
  });

  final List<String> labels;
  final List<double> data;
  final VeChartTone tone;
  final double height;

  /// Formato del valor (tooltip y semántica).
  final String Function(double v)? formatValue;

  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    final Color color = _toneColor(context, tone);
    final max = math.max(1.0, data.isEmpty ? 1 : data.reduce(math.max));

    return Semantics(
      label: semantic ?? 'Gráfico de barras',
      child: SizedBox(
        height: height,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: 1),
          duration: const Duration(milliseconds: 450),
          curve: kEaseVe,
          builder: (context, t, _) => BarChart(
            BarChartData(
              maxY: max.toDouble(),
              alignment: BarChartAlignment.spaceAround,
              gridData: const FlGridData(show: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                leftTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 20,
                    getTitlesWidget: (value, meta) {
                      final i = value.toInt();
                      if (i < 0 || i >= labels.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 5),
                        child: Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            color: scheme.mutedForeground,
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),
              barTouchData: BarTouchData(
                touchTooltipData: BarTouchTooltipData(
                  getTooltipColor: (_) => scheme.background,
                  tooltipBorder: BorderSide(color: scheme.border),
                  getTooltipItem: (group, groupIndex, rod, rodIndex) {
                    final i = group.x;
                    if (i < 0 || i >= labels.length) return null;
                    return BarTooltipItem(
                      '${labels[i]}  '
                      '${formatValue?.call(data[i]) ?? data[i]}',
                      TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
                        fontFeatures: const [FontFeature.tabularFigures()],
                        color: scheme.foreground,
                      ),
                    );
                  },
                ),
              ),
              barGroups: [
                for (var i = 0; i < data.length; i++)
                  BarChartGroupData(
                    x: i,
                    barRods: [
                      BarChartRodData(
                        toY: data[i] <= 0
                            ? 2.0
                            : math.max(3.0, data[i] * t),
                        width: 26,
                        color: color.withValues(alpha: 0.8),
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────────────────────── Donut ───────

/// Donut del prototipo (charts.tsx): anillo 68 %, ciclo
/// warn→pos→neg→fg→info→muted con separaciones de superficie y leyenda a la
/// derecha con cuadritos 9×9 y porcentaje tabular.
class VeDonut extends StatelessWidget {
  const VeDonut({
    super.key,
    required this.labels,
    required this.data,
    this.size = 132,
    this.formatValue,
    this.semantic,
  });

  final List<String> labels;
  final List<double> data;
  final double size;

  /// Formato del valor de leyenda (por defecto: porcentaje).
  final String Function(double v)? formatValue;

  final String? semantic;

  static const List<VeChartTone> _cycle = [
    VeChartTone.warn,
    VeChartTone.pos,
    VeChartTone.neg,
    VeChartTone.fg,
    VeChartTone.info,
    VeChartTone.muted,
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    final total = data.fold<double>(0, (a, b) => a + b);

    return Semantics(
      label: semantic ?? 'Gráfico de categorías',
      child: Row(
        children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 500),
            curve: kEaseVe,
            builder: (context, t, _) => SizedBox(
              width: size,
              height: size,
              child: PieChart(
                PieChartData(
                  sectionsSpace: data.length > 1 ? 2 : 0,
                  centerSpaceRadius: size * 0.34,
                  startDegreeOffset: -90,
                  sections: [
                    for (var i = 0; i < data.length; i++)
                      PieChartSectionData(
                        value: math.max(0.0, data[i] * t),
                        color: _toneColor(context, _cycle[i % _cycle.length]),
                        radius: size * 0.16,
                        showTitle: false,
                      ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (var i = 0; i < labels.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      children: [
                        Container(
                          width: 9,
                          height: 9,
                          decoration: BoxDecoration(
                            color: _toneColor(
                              context,
                              _cycle[i % _cycle.length],
                            ),
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            labels[i],
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 11.5,
                              color: scheme.mutedForeground,
                            ),
                          ),
                        ),
                        Text(
                          formatValue?.call(data[i]) ??
                              '${total > 0 ? (data[i] / total * 100).toStringAsFixed(0) : 0} %',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 11.5,
                            fontFeatures: const [FontFeature.tabularFigures()],
                            fontWeight: FontWeight.w500,
                            color: scheme.foreground,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────── Timeline multi-serie ────────

/// Punto temporal de una serie [VeTimelineSeries].
class VeTimelinePoint {
  const VeTimelinePoint(this.t, this.v);

  final DateTime t;
  final double v;
}

/// Una serie temporal del [VeTimelineChart].
///
/// El grosor, el punteado y el formato del tooltip son propios. El eje Y es
/// COMPARTIDO entre series (todas las series de la app viven en la misma
/// unidad — Bs o USD — y el eje único dice la verdad de las proporciones;
/// la normalización por serie de la era syncfusion era un truco del pintor).
class VeTimelineSeries {
  const VeTimelineSeries({
    required this.name,
    required this.points,
    required this.color,
    this.area = false,
    this.dashed = false,
    this.dashPattern = const <double>[5, 3],
    this.width = 2,
    this.format,
  });

  final String name;
  final List<VeTimelinePoint> points;
  final Color color;

  /// Relleno degradado 28 % → 0 bajo la línea (serie protagonista).
  final bool area;

  /// Línea PUNTEADA (proyección / serie secundaria — jamás sólida si es
  /// derivada: el dueño exige distinguirlas a la vista).
  final bool dashed;
  final List<double> dashPattern;
  final double width;

  /// Formato del valor en el tooltip (null → sin fila en el tooltip).
  final String Function(double)? format;
}

/// Gráfico de líneas/área temporal MULTI-SERIE sobre fl_chart (v24 — la
/// librería de CalculaYa; antes syncfusion hasta v20.4, luego CustomPainter).
///
/// · Rejilla punteada al 25/50/75 % (línea `--border`).
/// · Eje X con etiquetas [xLabel] en 0/⅓/⅔/1 y eje Y opcional [yLabel].
/// · Al tocar/arrastrar: indicador de fl_chart + chip de valores encima
///   (o [tooltipBuilder] para un chip a medida — TipBox de Análisis).
/// · [onScrub] avisa la fecha bajo el dedo (null al soltar) — la pantalla
///   de brecha sincroniza su panel de día con esto.
/// · [legend] pinta la leyenda abajo (punto de color + nombre).
class VeTimelineChart extends StatefulWidget {
  const VeTimelineChart({
    super.key,
    required this.series,
    this.height = 200,
    this.margin = const EdgeInsets.fromLTRB(6, 10, 6, 0),
    this.legend = false,
    required this.xLabel,
    this.yLabel,
    this.onScrub,
    this.tooltipBuilder,
    this.semantic,
  });

  final List<VeTimelineSeries> series;
  final double height;
  final EdgeInsetsGeometry margin;
  final bool legend;

  /// Etiqueta del eje X (y del chip), p. ej. `DateFormat('dd/MM').format`.
  final String Function(DateTime t) xLabel;

  /// Etiqueta del eje Y (null = sin eje).
  final String Function(double v)? yLabel;

  /// Fecha bajo el dedo (null = soltado / fuera).
  final void Function(DateTime? t)? onScrub;

  /// Chip a medida; por defecto superficie + borde fuerte (estilo prototipo).
  final Widget Function(DateTime t, List<(String, String)> rows)?
  tooltipBuilder;

  final String? semantic;

  @override
  State<VeTimelineChart> createState() => _VeTimelineChartState();
}

class _VeTimelineChartState extends State<VeTimelineChart> {
  /// Fracción 0..1 del toque sobre el ancho del plot (null = soltado).
  double? _x;

  bool get _hasData => widget.series.any((s) => s.points.length >= 2);

  (double, double)? _timeBounds() {
    double? lo, hi;
    for (final s in widget.series) {
      for (final p in s.points) {
        final ms = p.t.millisecondsSinceEpoch.toDouble();
        if (lo == null || ms < lo) lo = ms;
        if (hi == null || ms > hi) hi = ms;
      }
    }
    if (lo == null || hi == null || lo == hi) return null;
    return (lo, hi);
  }

  (double, double)? _valueBounds() {
    double? lo, hi;
    for (final s in widget.series) {
      for (final p in s.points) {
        if (lo == null || p.v < lo) lo = p.v;
        if (hi == null || p.v > hi) hi = p.v;
      }
    }
    if (lo == null || hi == null) return null;
    return (lo, hi);
  }

  void _scrubTo(double x) {
    final b = _timeBounds();
    if (b == null) return;
    setState(() => _x = x.clamp(0.0, 1.0).toDouble());
    widget.onScrub?.call(
      DateTime.fromMillisecondsSinceEpoch(
        (b.$1 + (b.$2 - b.$1) * _x!).round(),
      ),
    );
  }

  void _release() {
    if (_x == null) return;
    setState(() => _x = null);
    widget.onScrub?.call(null);
  }

  @override
  Widget build(BuildContext context) {
    final shad = context.ve;
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;
    final crossInk = dark ? VeColors.faintDark : VeColors.faintLight;

    if (!_hasData) return SizedBox(height: widget.height);
    final tb = _timeBounds();
    final vb = _valueBounds();
    if (tb == null || vb == null) return SizedBox(height: widget.height);

    final minX = tb.$1;
    final maxX = tb.$2;
    final rngY = (vb.$2 - vb.$1) == 0 ? 1.0 : (vb.$2 - vb.$1);
    final minY = vb.$1 - rngY * 0.06;
    final maxY = vb.$2 + rngY * 0.06;

    final chip = _x == null ? null : _buildTooltip(context);

    return Semantics(
      label: widget.semantic ?? 'Gráfico de evolución',
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: widget.margin,
              child: SizedBox(
                height: widget.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: LineChart(
                        LineChartData(
                          minX: minX,
                          maxX: maxX,
                          minY: minY,
                          maxY: maxY,
                          clipData: const FlClipData.all(),
                          gridData: FlGridData(
                            show: true,
                            drawVerticalLine: false,
                            horizontalInterval: (maxY - minY) / 4,
                            checkToShowHorizontalLine: (v) =>
                                (v - minY).abs() > 0.001 &&
                                (maxY - v).abs() > 0.001,
                            getDrawingHorizontalLine: (v) => FlLine(
                              color: scheme.border,
                              strokeWidth: 1,
                              dashArray: const [3, 3],
                            ),
                          ),
                          titlesData: FlTitlesData(
                            topTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            rightTitles: const AxisTitles(
                              sideTitles: SideTitles(showTitles: false),
                            ),
                            leftTitles: widget.yLabel == null
                                ? const AxisTitles(
                                    sideTitles:
                                        SideTitles(showTitles: false),
                                  )
                                : AxisTitles(
                                    sideTitles: SideTitles(
                                      showTitles: true,
                                      reservedSize: 36,
                                      interval: (maxY - minY) / 2,
                                      getTitlesWidget: (value, meta) => Text(
                                        widget.yLabel!(value),
                                        style: TextStyle(
                                          fontFamily: 'Inter',
                                          fontSize: 10,
                                          fontFeatures: const [
                                            FontFeature.tabularFigures(),
                                          ],
                                          color: scheme.mutedForeground,
                                        ),
                                      ),
                                    ),
                                  ),
                            bottomTitles: AxisTitles(
                              sideTitles: SideTitles(
                                showTitles: true,
                                reservedSize: 18,
                                interval: (maxX - minX) / 3,
                                getTitlesWidget: (value, meta) => Text(
                                  widget.xLabel(
                                    DateTime.fromMillisecondsSinceEpoch(
                                      value.round(),
                                    ),
                                  ),
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 10,
                                    color: scheme.mutedForeground,
                                  ),
                                ),
                              ),
                            ),
                          ),
                          borderData: FlBorderData(show: false),
                          lineBarsData: [
                            for (final s in widget.series)
                              if (s.points.isNotEmpty)
                                LineChartBarData(
                                  spots: [
                                    for (final p in s.points)
                                      FlSpot(
                                        p.t.millisecondsSinceEpoch.toDouble(),
                                        p.v,
                                      ),
                                  ],
                                  isCurved: false,
                                  barWidth: s.width,
                                  color: s.color,
                                  dashArray: s.dashed
                                      ? [
                                          for (final d in s.dashPattern)
                                            d.toInt(),
                                        ]
                                      : null,
                                  dotData: const FlDotData(show: false),
                                  belowBarData: s.area
                                      ? BarAreaData(
                                          show: true,
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              s.color.withValues(
                                                alpha: 0.28,
                                              ),
                                              s.color.withValues(alpha: 0),
                                            ],
                                          ),
                                        )
                                      : BarAreaData(show: false),
                                ),
                          ],
                          lineTouchData: LineTouchData(
                            touchSpotThreshold: 24,
                            // El chip es NUESTRO (TipBox/_ChartChip): el
                            // tooltip interno apagado, el indicador de
                            // fl_chart hace de crosshair.
                            touchTooltipData: const LineTouchTooltipData(
                              getTooltipItems:
                                  defaultLineTooltipNoItems,
                            ),
                            getTouchedSpotIndicator: (bar, spots) =>
                                spots.map((spot) {
                              return TouchedSpotIndicatorData(
                                FlLine(
                                  color: crossInk,
                                  strokeWidth: 1,
                                  dashArray: const [3, 3],
                                ),
                                FlDotData(
                                  show: true,
                                  getDotPainter: (spot, percent, bar, index) =>
                                      FlDotCirclePainter(
                                    radius: 3,
                                    color: scheme.background,
                                    strokeWidth: 2,
                                    strokeColor:
                                        bar.color ?? scheme.foreground,
                                  ),
                                ),
                              );
                            }).toList(),
                            touchCallback: (event, response) {
                              final spots = response?.lineBarSpots;
                              final end = event is FlPointerExitEvent ||
                                  event is FlPanEndEvent ||
                                  event is FlPanCancelEvent;
                              if (spots == null || spots.isEmpty) {
                                if (end) _release();
                                return;
                              }
                              final spot = spots.first;
                              final frac =
                                  (spot.x - minX) / (maxX - minX);
                              if (end) {
                                _scrubTo(frac);
                                _release();
                              } else {
                                _scrubTo(frac);
                              }
                            },
                          ),
                        ),
                      ),
                    ),
                    ?chip,
                  ],
                ),
              ),
            ),
            if (widget.legend) _Legend(series: widget.series),
          ],
        ),
      ),
    );
  }

  Widget _buildTooltip(BuildContext context) {
    final bounds = _timeBounds();
    if (bounds == null || _x == null) return const SizedBox.shrink();
    final t = DateTime.fromMillisecondsSinceEpoch(
      (bounds.$1 + (bounds.$2 - bounds.$1) * _x!).round(),
    );
    final rows = <(String, String)>[];
    for (final s in widget.series) {
      final fmt = s.format;
      if (fmt == null || s.points.isEmpty) continue;
      final p = _nearest(s.points, t);
      rows.add((s.name, fmt(p.v)));
    }
    if (rows.isEmpty) return const SizedBox.shrink();
    final defaultChip = _ChartChip(
      text: rows.length == 1
          ? '${widget.xLabel(t)}  ${rows.first.$2}'
          : [
              widget.xLabel(t),
              ...rows.map((r) => '${r.$1}  ${r.$2}'),
            ].join('\n'),
    );
    final built = widget.tooltipBuilder?.call(t, rows) ?? defaultChip;
    return Align(
      alignment: Alignment(-1 + 2 * _x!.clamp(0.1, 0.9).toDouble(), -1),
      child: Padding(
        padding: const EdgeInsets.only(top: 2),
        child: built,
      ),
    );
  }
}

/// Punto de una serie más cercano a [t] (por milisegundos).
VeTimelinePoint _nearest(List<VeTimelinePoint> pts, DateTime t) {
  final ms = t.millisecondsSinceEpoch;
  var best = pts.first;
  var bestD = (best.t.millisecondsSinceEpoch - ms).abs();
  for (final p in pts) {
    final d = (p.t.millisecondsSinceEpoch - ms).abs();
    if (d < bestD) {
      best = p;
      bestD = d;
    }
  }
  return best;
}

/// Leyenda del prototipo: punto de color 8 px + nombre en 10 muted.
class _Legend extends StatelessWidget {
  const _Legend({required this.series});

  final List<VeTimelineSeries> series;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 4),
      child: Wrap(
        spacing: 14,
        runSpacing: 4,
        alignment: WrapAlignment.center,
        children: [
          for (final s in series)
            if (s.points.isNotEmpty)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      color: s.color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 5),
                  Text(
                    s.name,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10,
                      color: scheme.mutedForeground,
                    ),
                  ),
                ],
              ),
        ],
      ),
    );
  }
}

/// Chip de valor del gráfico: superficie + borde fuerte + texto tabular.
class _ChartChip extends StatelessWidget {
  const _ChartChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    final shad = context.ve;
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: scheme.background,
        borderRadius: BorderRadius.circular(6),
        border: Border.all(
          color: dark ? VeColors.lineStrongDark : VeColors.lineStrongLight,
        ),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 11,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: scheme.foreground,
        ),
      ),
    );
  }
}

/// Sin tooltip interno: el chip lo pinta la app (TipBox/_ChartChip).
List<LineTooltipItem?> defaultLineTooltipNoItems(
  List<LineBarSpot> touchedSpots,
) => List<LineTooltipItem?>.filled(touchedSpots.length, null);
