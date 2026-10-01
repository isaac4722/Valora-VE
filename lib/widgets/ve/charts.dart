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
