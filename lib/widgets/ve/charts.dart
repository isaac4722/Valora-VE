/// ─── Gráficos «Ve» · pintores del prototipo (TASK-34) ──────────────────────
/// Sparkline, área interactiva (crosshair + tooltip), barras redondeadas,
/// donut con leyenda y heatmap de calendario — los cinco gráficos del
/// prototipo web, en CustomPainter ligero (sin dependencias de charts).
///
/// Paleta por tono idéntica a charts.tsx: pos/neg/warn/info/fg + grid
/// `--line`, texto `--muted` y tooltip de superficie con borde fuerte.
library;

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/theme.dart';

/// Tono de serie.
enum VeChartTone { pos, neg, warn, info, fg, muted }

/// Resuelve el color de un tono con el tema activo.
Color _toneColor(BuildContext context, VeChartTone tone) {
  final scheme = ShadTheme.of(context).colorScheme;
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
      return SizedBox(
        height: height,
        width: double.infinity,
        child: CustomPaint(
          painter: _DashedLinePainter(color: color.withValues(alpha: 0.3)),
        ),
      );
    }

    return SizedBox(
      height: height,
      width: double.infinity,
      child: RepaintBoundary(
        child: CustomPaint(
          painter: _SparklinePainter(data: data, color: color),
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({required this.data, required this.color});

  final List<double> data;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final min = data.reduce(math.min);
    final max = data.reduce(math.max);
    final rng = (max - min) == 0 ? 1.0 : (max - min);

    final path = Path();
    for (var i = 0; i < data.length; i++) {
      final x = i / (data.length - 1) * size.width;
      // 15 % de aire vertical para que la línea no pegue en los bordes.
      final y =
          size.height * 0.85 - ((data[i] - min) / rng) * size.height * 0.7;
      i == 0 ? path.moveTo(x, y) : path.lineTo(x, y);
    }
    canvas.drawPath(
      path,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.6
        ..strokeJoin = StrokeJoin.round
        ..strokeCap = StrokeCap.round
        ..color = color,
    );
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.data != data || old.color != color;
}

class _DashedLinePainter extends CustomPainter {
  _DashedLinePainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color;
    final path = Path()
      ..moveTo(0, size.height * 0.4)
      ..lineTo(size.width, size.height * 0.4);
    for (final m in path.computeMetrics()) {
      double start = 0;
      while (start < m.length) {
        canvas.drawPath(
          m.extractPath(start, (start + 4).clamp(0, m.length)),
          paint,
        );
        start += 4 + 4;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedLinePainter old) => old.color != color;
}

// ──────────────────────────────────────────────────────── Área activa ──────

/// Gráfico de área interactivo del prototipo (AreaChart de ui.tsx + tooltip
/// de charts.tsx): relleno degradado 28 % → 0, rejilla punteada al 25/50/75 %
/// y, al arrastrar el dedo o el cursor, crosshair + punto destacado + chip
/// con etiqueta y valor.
class VeAreaChart extends StatefulWidget {
  const VeAreaChart({
    super.key,
    required this.data,
    required this.labels,
    required this.format,
    this.tone = VeChartTone.warn,
    this.height = 170,
    this.semantic,
  });

  final List<double> data;
  final List<String> labels;

  /// Formatea el valor del tooltip (p. ej. `+12,4 %`).
  final String Function(double v) format;

  final VeChartTone tone;
  final double height;
  final String? semantic;

  @override
  State<VeAreaChart> createState() => _VeAreaChartState();
}

class _VeAreaChartState extends State<VeAreaChart> {
  int? _idx;

  void _update(double dx, double width) {
    if (width <= 0) return;
    final i = ((dx / width).clamp(0.0, 1.0) * (widget.data.length - 1)).round();
    if (i != _idx) setState(() => _idx = i);
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;
    final Color color = _toneColor(context, widget.tone);

    if (widget.data.length < 2) return SizedBox(height: widget.height);

    return Semantics(
      label: widget.semantic ?? 'Gráfico de serie',
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => _update(d.localPosition.dx, w),
            onTapDown: (d) => _update(d.localPosition.dx, w),
            onVerticalDragUpdate: (d) => _update(d.localPosition.dx, w),
            onHorizontalDragEnd: (_) => setState(() => _idx = null),
            onPanCancel: () => setState(() => _idx = null),
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onHover: (e) => _update(e.localPosition.dx, w),
              onExit: (_) => setState(() => _idx = null),
              child: SizedBox(
                width: w,
                height: widget.height,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fill(
                      child: RepaintBoundary(
                        child: CustomPaint(
                          painter: _AreaPainter(
                            data: widget.data,
                            color: color,
                            grid: scheme.border,
                            crosshair: dark
                                ? VeColors.faintDark
                                : VeColors.faintLight,
                            surface: scheme.card,
                            idx: _idx,
                          ),
                        ),
                      ),
                    ),
                    if (_idx != null)
                      Align(
                        alignment: Alignment(
                          -1 +
                              2 *
                                  (_idx! / (widget.data.length - 1)).clamp(
                                    0.1,
                                    0.9,
                                  ),
                          -1,
                        ),
                        child: Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: _ChartChip(
                            text:
                                '${widget.labels[_idx!]}  ${widget.format(widget.data[_idx!])}',
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ),
          );
        },
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
    final shad = ShadTheme.of(context);
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

class _AreaPainter extends CustomPainter {
  _AreaPainter({
    required this.data,
    required this.color,
    required this.grid,
    required this.crosshair,
    required this.surface,
    required this.idx,
  });

  final List<double> data;
  final Color color;
  final Color grid;
  final Color crosshair;
  final Color surface;
  final int? idx;

  @override
  void paint(Canvas canvas, Size size) {
    final min = data.reduce(math.min);
    final max = data.reduce(math.max);
    final span = (max - min) * 0.15;
    final lo = min - (span == 0 ? 1 : span);
    final hi = max + (span == 0 ? 1 : span);
    final rng = hi - lo;

    double x(int i) => i / (data.length - 1) * size.width;
    double y(double v) => size.height - ((v - lo) / rng) * size.height;

    // Rejilla punteada al 25/50/75 %.
    final gridPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = grid;
    for (final f in [0.25, 0.5, 0.75]) {
      final yy = size.height * f;
      final p = Path()
        ..moveTo(0, yy)
        ..lineTo(size.width, yy);
      for (final m in p.computeMetrics()) {
        double s = 0;
        while (s < m.length) {
          canvas.drawPath(
            m.extractPath(s, (s + 2).clamp(0, m.length)),
            gridPaint,
          );
          s += 2 + 3;
        }
      }
    }

    // Curva.
    final line = Path();
    for (var i = 0; i < data.length; i++) {
      i == 0 ? line.moveTo(x(0), y(data[0])) : line.lineTo(x(i), y(data[i]));
    }

    // Relleno degradado 28 % → 0.
    final area = Path.from(line)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();
    final fill = Paint()
      ..shader = ui.Gradient.linear(Offset(0, 0), Offset(0, size.height), [
        color.withValues(alpha: 0.28),
        color.withValues(alpha: 0),
      ]);
    canvas.drawPath(area, fill);

    canvas.drawPath(
      line,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.8
        ..strokeJoin = StrokeJoin.round
        ..color = color,
    );

    // Crosshair + punto.
    if (idx != null) {
      canvas.drawLine(
        Offset(x(idx!), 0),
        Offset(x(idx!), size.height),
        Paint()
          ..strokeWidth = 1
          ..color = crosshair,
      );
      final c = Offset(x(idx!), y(data[idx!]));
      canvas.drawCircle(c, 3.5, Paint()..color = color);
      canvas.drawCircle(
        c,
        3.5,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 2
          ..color = surface,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _AreaPainter old) =>
      old.data != data ||
      old.color != color ||
      old.grid != grid ||
      old.idx != idx;
}

// ──────────────────────────────────────────────────────────── Barras ───────

/// Barras redondeadas del prototipo (Bars de charts.tsx): radius 4, grosor
/// máximo 26, tono por serie y etiquetas `--muted` debajo. MEJORA: las
/// barras CRECEN con la curva firma al montar (entrada viva, no estática).
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
    final scheme = ShadTheme.of(context).colorScheme;
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
          builder: (context, t, _) => Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              for (var i = 0; i < data.length; i++)
                Expanded(
                  child: Tooltip(
                    message:
                        '${labels[i]}  ${formatValue?.call(data[i]) ?? data[i]}',
                    waitDuration: const Duration(milliseconds: 350),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        Expanded(
                          child: Align(
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              width: 26,
                              constraints: BoxConstraints(
                                minHeight: data[i] <= 0 ? 2 : 3,
                              ),
                              height: ((data[i] / max) * 88 * t),
                              decoration: BoxDecoration(
                                color: color.withValues(alpha: 0.8),
                                borderRadius: const BorderRadius.vertical(
                                  top: Radius.circular(4),
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          labels[i],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 10.5,
                            color: scheme.mutedForeground,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
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
    final scheme = ShadTheme.of(context).colorScheme;
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
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _DonutPainter(
                    progress: t,
                    values: data,
                    colors: [
                      for (var i = 0; i < data.length; i++)
                        _toneColor(context, _cycle[i % _cycle.length]),
                    ],
                    separator: scheme.card,
                  ),
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

class _DonutPainter extends CustomPainter {
  _DonutPainter({
    required this.progress,
    required this.values,
    required this.colors,
    required this.separator,
  });

  final double progress;
  final List<double> values;
  final List<Color> colors;
  final Color separator;

  @override
  void paint(Canvas canvas, Size size) {
    final total = values.fold<double>(0, (a, b) => a + b);
    if (total <= 0) return;
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.shortestSide / 2;
    final stroke = radius * 0.32; // cutout 68 %.
    final rect = Rect.fromCircle(center: center, radius: radius - stroke / 2);

    double start = -math.pi / 2;
    final gap = values.length > 1 ? 0.03 : 0.0;
    for (var i = 0; i < values.length; i++) {
      final sweep = values[i] / total * 2 * math.pi * progress;
      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke
        ..strokeCap = StrokeCap.butt
        ..color = colors[i];
      canvas.drawArc(rect, start, math.max(0, sweep - gap), false, paint);
      start += values[i] / total * 2 * math.pi * progress;
    }
  }

  @override
  bool shouldRepaint(covariant _DonutPainter old) =>
      old.values != values || old.colors != colors || old.progress != progress;
}

// ─────────────────────────────────────────────────────────── Heatmap ───────

/// Heatmap mensual del prototipo (Análisis): rejilla L..D con `offset` de
/// celdas vacías, 5 niveles de intensidad warn y el día dentro de la celda
/// (tinta de fondo en niveles 3–4 para contraste).
class VeHeatmap extends StatelessWidget {
  const VeHeatmap({
    super.key,
    required this.byDay,
    required this.offset,
    required this.maxValue,
    this.cell = 30,
    this.semantic,
  });

  /// Gasto por día del mes (índice 0 = día 1).
  final List<double> byDay;

  /// Celdas vacías antes del día 1 (0 = lunes).
  final int offset;

  /// Escala de intensidad (gasto máximo del mes).
  final double maxValue;

  /// Lado de cada celda.
  final double cell;

  final String? semantic;

  static const List<String> _dow = ['L', 'M', 'M', 'J', 'V', 'S', 'D'];

  int _level(double v) {
    if (v <= 0) return 0;
    if (maxValue <= 0) return 1;
    if (v < maxValue * 0.25) return 1;
    if (v < maxValue * 0.55) return 2;
    if (v < maxValue * 0.85) return 3;
    return 4;
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final bool dark = shad.brightness == Brightness.dark;
    final Color faint = dark ? VeColors.faintDark : VeColors.faintLight;

    Color levelColor(int l) => switch (l) {
      0 => scheme.muted,
      1 => ink.warn.withValues(alpha: 0.20),
      2 => ink.warn.withValues(alpha: 0.45),
      3 => ink.warn.withValues(alpha: 0.70),
      _ => ink.warn,
    };

    return Semantics(
      label: semantic ?? 'Mapa de calor de gasto diario',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.only(left: cell * 0.28),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                for (final d in _dow)
                  SizedBox(
                    width: cell + 4,
                    child: Text(
                      d,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10,
                        color: faint,
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Wrap(
            spacing: 4,
            runSpacing: 4,
            children: [
              for (var i = 0; i < offset; i++)
                SizedBox(width: cell, height: cell),
              for (var d = 0; d < byDay.length; d++)
                Container(
                  width: cell,
                  height: cell,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: levelColor(_level(byDay[d])),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${d + 1}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: _level(byDay[d]) >= 3
                          ? scheme.background
                          : scheme.mutedForeground,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────── Timeline multi-serie (v20.4) ─────

/// Punto temporal de una serie [VeTimelineSeries].
class VeTimelinePoint {
  const VeTimelinePoint(this.t, this.v);

  final DateTime t;
  final double v;
}

/// Una serie temporal del [VeTimelineChart].
///
/// Cada serie se NORMALIZA a su propio rango vertical (equivalente al eje
/// secundario que usaba syncfusion): el relleno muestra la forma, el tooltip
/// el valor real. El grosor, el punteado y el formato del tooltip son propios.
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

/// Gráfico de líneas/área temporal MULTI-SERIE en CustomPainter puro
/// (v20.4 — reemplaza a syncfusion_flutter_charts en brecha, canasta y
/// producto: cero dependencia, APKs livianos, mismo lenguaje del prototipo).
///
/// · Rejilla punteada al 25/50/75 % (como VeAreaChart).
/// · Eje X con etiquetas [xLabel] (típico «dd/MM») y eje Y opcional con la
///   escala de la PRIMERA serie ([yLabel]).
/// · Crosshair vertical punteado con puntos por serie + chip de valores
///   (o [tooltipBuilder] para un chip a medida).
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

  /// Etiqueta del eje Y sobre la escala de la primera serie (null = sin eje).
  final String Function(double v)? yLabel;

  /// Fecha bajo el crosshair (null = soltado / fuera).
  final void Function(DateTime? t)? onScrub;

  /// Chip a medida; por defecto superficie + borde fuerte (estilo prototipo).
  final Widget Function(DateTime t, List<(String, String)> rows)?
  tooltipBuilder;

  final String? semantic;

  @override
  State<VeTimelineChart> createState() => _VeTimelineChartState();
}

class _VeTimelineChartState extends State<VeTimelineChart> {
  /// Posición del crosshair en 0..1 sobre el ancho del plot.
  double? _x;

  bool get _hasData => widget.series.any((s) => s.points.length >= 2);

  void _update(double dx, double width) {
    if (width <= 0 || !_hasData) return;
    final x = (dx / width).clamp(0.0, 1.0).toDouble();
    if (x != _x) {
      setState(() => _x = x);
      final b = _timeBounds();
      if (b != null) {
        widget.onScrub?.call(
          DateTime.fromMillisecondsSinceEpoch(
            (b.$1 + (b.$2 - b.$1) * x).round(),
          ),
        );
      }
    }
  }

  void _release() {
    setState(() => _x = null);
    widget.onScrub?.call(null);
  }

  (int, int)? _timeBounds() {
    int? lo, hi;
    for (final s in widget.series) {
      for (final p in s.points) {
        final ms = p.t.millisecondsSinceEpoch;
        if (lo == null || ms < lo) lo = ms;
        if (hi == null || ms > hi) hi = ms;
      }
    }
    if (lo == null || hi == null || lo == hi) return null;
    return (lo, hi);
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context).colorScheme;
    final ink = Theme.of(context).extension<VeInk>()!;

    if (!_hasData) return SizedBox(height: widget.height);

    final chip = _x == null ? null : _buildTooltip(context);

    return Semantics(
      label: widget.semantic ?? 'Gráfico de evolución',
      child: LayoutBuilder(
        builder: (context, c) {
          final w = c.maxWidth;
          return GestureDetector(
            behavior: HitTestBehavior.opaque,
            onHorizontalDragUpdate: (d) => _update(d.localPosition.dx, w),
            onTapDown: (d) => _update(d.localPosition.dx, w),
            onVerticalDragUpdate: (d) => _update(d.localPosition.dx, w),
            onHorizontalDragEnd: (_) => _release(),
            onPanCancel: _release,
            child: MouseRegion(
              cursor: SystemMouseCursors.click,
              onHover: (e) => _update(e.localPosition.dx, w),
              onExit: (_) => _release(),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Padding(
                    padding: widget.margin,
                    child: SizedBox(
                      width: w,
                      height: widget.height,
                      child: Stack(
                        clipBehavior: Clip.none,
                        children: [
                          Positioned.fill(
                            child: RepaintBoundary(
                              child: CustomPaint(
                                painter: _TimelinePainter(
                                  series: widget.series,
                                  x: _x,
                                  grid: shad.border,
                                  muted: shad.mutedForeground,
                                  crosshair: Theme.of(context).brightness ==
                                          Brightness.dark
                                      ? VeColors.faintDark
                                      : VeColors.faintLight,
                                  xLabel: widget.xLabel,
                                  yLabel: widget.yLabel,
                                ),
                              ),
                            ),
                          ),
                          if (chip != null) chip,
                        ],
                      ),
                    ),
                  ),
                  if (widget.legend) _Legend(series: widget.series),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildTooltip(BuildContext context) {
    final bounds = _timeBounds();
    if (bounds == null) return const SizedBox.shrink();
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
          : '${widget.xLabel(t)}\n'
                + rows.map((r) => '${r.$1}  ${r.$2}').join('\n'),
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
    final scheme = ShadTheme.of(context).colorScheme;
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

/// Trazo de línea con patrón discontinuo (extracción por PathMetrics —
/// el camino original queda intacto).
ui.Path _dash(ui.Path source, List<double> pattern) {
  if (pattern.isEmpty) return source;
  final dest = ui.Path();
  for (final metric in source.computeMetrics()) {
    var dist = 0.0;
    var draw = true;
    var i = 0;
    while (dist < metric.length) {
      final len = pattern[i % pattern.length];
      if (draw) {
        dest.addPath(
          metric.extractPath(dist, math.min(dist + len, metric.length)),
          ui.Offset.zero,
        );
      }
      dist += len;
      draw = !draw;
      i++;
    }
  }
  return dest;
}

/// Pintor del timeline: rejilla punteada 25/50/75 %, ejes con etiquetas,
/// áreas degradadas, líneas (sólidas o punteadas) y crosshair con puntos.
class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.series,
    required this.x,
    required this.grid,
    required this.muted,
    required this.crosshair,
    required this.xLabel,
    required this.yLabel,
  });

  final List<VeTimelineSeries> series;
  final double? x; // 0..1 o null
  final Color grid;
  final Color muted;
  final Color crosshair;
  final String Function(DateTime) xLabel;
  final String Function(double)? yLabel;

  static const _gutterLeft = 36.0;
  static const _gutterBottom = 16.0;

  @override
  void paint(ui.Canvas canvas, ui.Size size) {
    // Orden del widget se respeta: áreas primero (llaman los call sites).
    final paintable = series
        .where((s) => s.points.length >= 2)
        .toList();
    if (paintable.isEmpty) return;

    // Escala temporal global.
    var loMs = paintable.first.points.first.t.millisecondsSinceEpoch;
    var hiMs = loMs;
    for (final s in paintable) {
      for (final p in s.points) {
        final ms = p.t.millisecondsSinceEpoch;
        if (ms < loMs) loMs = ms;
        if (ms > hiMs) hiMs = ms;
      }
    }
    final span = math.max(1, hiMs - loMs);

    // Rangos verticales POR serie (normalización propia, como el eje 2º).
    final ranges = <VeTimelineSeries, (double, double)>{};
    for (final s in paintable) {
      var lo = s.points.first.v;
      var hi = lo;
      for (final p in s.points) {
        if (p.v < lo) lo = p.v;
        if (p.v > hi) hi = p.v;
      }
      if (hi - lo < 1e-9) {
        lo -= 1;
        hi += 1;
      }
      final pad = (hi - lo) * 0.06;
      ranges[s] = (lo - pad, hi + pad);
    }

    final plot = ui.Rect.fromLTWH(
      _gutterLeft,
      4,
      math.max(0, size.width - _gutterLeft - 4),
      math.max(0, size.height - _gutterBottom - 4),
    );
    if (plot.isEmpty) return;

    // Rejilla punteada al 25/50/75 %.
    final gridPaint = Paint()
      ..color = grid
      ..strokeWidth = 1;
    for (final f in const [0.25, 0.5, 0.75]) {
      final y = plot.top + plot.height * f;
      canvas.drawPath(
        _dash(ui.Path()..moveTo(plot.left, y)..lineTo(plot.right, y),
            const [3, 3]),
        gridPaint,
      );
    }

    // Etiquetas del eje Y (escala de la PRIMERA serie).
    if (yLabel != null) {
      final range = ranges[paintable.first]!;
      for (final f in const [0.0, 0.5, 1.0]) {
        final v = range.$2 - (range.$2 - range.$1) * f;
        _label(
          canvas,
          yLabel!(v),
          ui.Offset(plot.left - 6, plot.top + plot.height * f),
          align: ui.TextAlign.right,
        );
      }
    }

    // Etiquetas del eje X: inicio, tercios, fin.
    final ticks = [0.0, 1 / 3, 2 / 3, 1.0];
    for (final f in ticks) {
      final t = DateTime.fromMillisecondsSinceEpoch(loMs + (span * f).round());
      _label(
        canvas,
        xLabel(t),
        ui.Offset(plot.left + plot.width * f, plot.bottom + 4),
        align: f == 0
            ? ui.TextAlign.left
            : (f == 1 ? ui.TextAlign.right : ui.TextAlign.center),
      );
    }

    // Series: áreas primero, líneas después (como syncfusion las apila).
    for (final s in paintable) {
      final range = ranges[s]!;
      final path = ui.Path();
      for (var i = 0; i < s.points.length; i++) {
        final p = s.points[i];
        final fx =
            (p.t.millisecondsSinceEpoch - loMs) / span;
        final fy = (range.$2 - p.v) / (range.$2 - range.$1);
        final px = plot.left + plot.width * fx.clamp(0.0, 1.0);
        final py = plot.top + plot.height * fy.clamp(0.0, 1.0);
        if (i == 0) {
          path.moveTo(px, py);
        } else {
          path.lineTo(px, py);
        }
      }

      if (s.area) {
        final fill = ui.Path.from(path)
          ..lineTo(
            plot.left + plot.width,
            plot.top + plot.height,
          )
          ..lineTo(plot.left, plot.top + plot.height)
          ..close();
        canvas.drawPath(
          fill,
          Paint()
            ..shader = ui.Gradient.linear(
              ui.Offset(0, plot.top),
              ui.Offset(0, plot.bottom),
              [
                s.color.withValues(alpha: 0.28),
                s.color.withValues(alpha: 0),
              ],
            ),
        );
      }

      final line = Paint()
        ..color = s.color
        ..strokeWidth = s.width
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(s.dashed ? _dash(path, s.dashPattern) : path, line);
    }

    // Crosshair vertical punteado + punto por serie.
    final sx = x;
    if (sx != null) {
      final cx = plot.left + plot.width * sx;
      canvas.drawPath(
        _dash(
          ui.Path()..moveTo(cx, plot.top)..lineTo(cx, plot.bottom),
          const [4, 3],
        ),
        Paint()
          ..color = crosshair
          ..strokeWidth = 1,
      );
      for (final s in paintable) {
        final range = ranges[s]!;
        final t = DateTime.fromMillisecondsSinceEpoch(
          loMs + (span * sx).round(),
        );
        final p = _nearest(s.points, t);
        final fy = (range.$2 - p.v) / (range.$2 - range.$1);
        canvas.drawCircle(
          ui.Offset(
            cx,
            plot.top + plot.height * fy.clamp(0.0, 1.0),
          ),
          3.2,
          Paint()..color = s.color,
        );
      }
    }
  }

  /// Etiqueta 9.5 px muted con [align] sobre el punto dado.
  void _label(
    ui.Canvas canvas,
    String text,
    ui.Offset at, {
    ui.TextAlign align = ui.TextAlign.left,
  }) {
    final tp = TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 9.5,
          fontFeatures: const [FontFeature.tabularFigures()],
          color: muted,
        ),
      ),
      textAlign: align,
      textDirection: TextDirection.ltr,
    )..layout();
    final dx = switch (align) {
      ui.TextAlign.right => at.dx - tp.width,
      ui.TextAlign.center => at.dx - tp.width / 2,
      _ => at.dx,
    };
    tp.paint(canvas, ui.Offset(dx, at.dy));
  }

  @override
  bool shouldRepaint(covariant _TimelinePainter old) =>
      old.x != x ||
      old.series != series ||
      old.grid != grid ||
      old.muted != muted ||
      old.crosshair != crosshair;
}
