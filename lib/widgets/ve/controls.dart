/// ─── Controles «Ve» · capa shadcn/ui del prototipo web (TASK-34) ────────────
/// Botones, chips, badges, inputs y selectores del lenguaje del prototipo,
/// construidos SOBRE componentes reales de `shadcn_ui` (ShadButton.raw,
/// ShadBadge.raw, ShadInput, ShadSwitch, ShadCheckbox, ShadSelect): la app se
/// viste con el port Flutter de shadcn/ui — no con imitaciones Material.
///
/// Medidas EXACTAS del prototipo (ui.tsx):
///   Btn   sm 28 · md 36 · lg 44 px, radius 8, active:scale .98
///   IconBtn 32×32 con borde line-strong
///   Chip  h 28, pill 999, activo = tinta invertida fg→bg
///   Badge h 20, caps 10.5px w600 tracking .06em, fondo tenue del tono
///   Toggle 32×18 · Checkbox 18 radius 5 (pop al marcar)
///   Stepper 28 con separadores · Input 36 con foco tinta
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/shad_theme.dart' show kShadControlRadius;
import '../../core/theme.dart';

// ─────────────────────────────────────────────────────────────── Botones ───

/// Variante visual de [VeBtn], 1:1 con el `Btn` del prototipo.
enum VeBtnVariant { primary, secondary, ghost, danger }

/// Tamaño de [VeBtn] (sm 28 · md 36 · lg 44 px).
enum VeBtnSize { sm, md, lg }

/// Botón del sistema sobre [ShadButton.raw] — el componente shadcn/ui real
/// con la piel exacta del prototipo.
///
/// - primary: tinta invertida (bg fg / texto bg).
/// - secondary: superficie + borde fuerte, hover en `--hover`.
/// - ghost: sin borde; texto muted → fg y fondo hover.
/// - danger: superficie + texto neg + borde neg 40 %, hover en `--neg-bg`.
class VeBtn extends StatelessWidget {
  const VeBtn({
    super.key,
    required this.onPressed,
    required this.child,
    this.variant = VeBtnVariant.secondary,
    this.size = VeBtnSize.md,
    this.icon,
    this.iconSize,
    this.expands = false,
    this.enabled = true,
    this.semantic,
  });

  final VoidCallback? onPressed;
  final Widget child;
  final VeBtnVariant variant;
  final VeBtnSize size;

  /// Icono Lucide a la izquierda del texto (13–16 px según tamaño).
  final IconData? icon;

  /// Tamaño explícito del icono (por defecto se deriva del [size]).
  final double? iconSize;

  /// Ocupa todo el ancho disponible.
  final bool expands;

  final bool enabled;

  /// Etiqueta para lectores de pantalla.
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final bool dark = shad.brightness == Brightness.dark;

    final (
      double h,
      double px,
      double fs,
      double isz,
      double gap,
    ) = switch (size) {
      VeBtnSize.sm => (28, 10, 12, 13, 6),
      VeBtnSize.md => (36, 14, 13, 15, 8),
      VeBtnSize.lg => (44, 16, 14, 16, 8),
    };

    final (
      ShadButtonVariant rawVariant,
      Color bg,
      Color hoverBg,
      Color pressedBg,
      Color fg,
      Color? borderColor,
    ) = switch (variant) {
      VeBtnVariant.primary => (
        ShadButtonVariant.primary,
        scheme.primary,
        _shift(scheme.primary, dark ? 0.10 : -0.08),
        _shift(scheme.primary, dark ? 0.16 : -0.14),
        scheme.background,
        null,
      ),
      VeBtnVariant.secondary => (
        ShadButtonVariant.secondary,
        scheme.card,
        scheme.accent,
        scheme.accent,
        scheme.foreground,
        dark ? VeColors.lineStrongDark : VeColors.lineStrongLight,
      ),
      VeBtnVariant.ghost => (
        ShadButtonVariant.ghost,
        Colors.transparent,
        scheme.accent,
        scheme.accent,
        scheme.foreground,
        null,
      ),
      VeBtnVariant.danger => (
        ShadButtonVariant.secondary,
        scheme.card,
        ink.negBg,
        ink.negBg,
        ink.neg,
        ink.neg.withValues(alpha: 0.4),
      ),
    };

    Widget button = ShadButton.raw(
      variant: rawVariant,
      onPressed: enabled ? onPressed : null,
      height: h,
      width: expands ? double.infinity : null,
      mainAxisAlignment: expands
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      backgroundColor: bg,
      hoverBackgroundColor: hoverBg,
      pressedBackgroundColor: pressedBg,
      foregroundColor: fg,
      hoverForegroundColor: fg,
      pressedForegroundColor: fg,
      gap: gap,
      padding: EdgeInsets.symmetric(horizontal: px),
      textStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: fs,
        fontWeight: FontWeight.w500,
        color: fg,
      ),
      // Sin borde shadcn: el borde vive en el envoltorio exterior (_VeBorder)
      // — reserva CERO píxeles y el botón mide exactamente `h`.
      decoration: _flushDecor(radius: kShadControlRadius),
      leading: icon == null ? null : Icon(icon, size: iconSize ?? isz),
      child: child,
    );

    if (borderColor != null) {
      button = _VeBorder(
        radius: kShadControlRadius,
        color: borderColor,
        child: button,
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: semantic,
      child: _TapScaleVe(onTap: enabled ? onPressed : null, child: button),
    );
  }
}

/// Envoltorio de borde FLUTTER puro para controles shadcn: pinta el borde
/// DENTRO del tamaño del hijo (cero píxeles reservados — el control mide
/// exactamente lo que dice medir) y añade un halo de foco vía boxShadow
/// (tampoco afecta el layout) cuando el foco entra por teclado.
class _VeBorder extends StatefulWidget {
  const _VeBorder({
    required this.radius,
    required this.color,
    required this.child,
    this.ringColor,
  });

  final double radius;
  final Color color;
  final Widget child;

  /// Color del halo de foco (por defecto: tinta al 25 %).
  final Color? ringColor;

  @override
  State<_VeBorder> createState() => _VeBorderState();
}

class _VeBorderState extends State<_VeBorder> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final ring = widget.ringColor ?? scheme.primary.withValues(alpha: 0.25);
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onFocusChange: (v) => setState(() => _focused = v),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 150),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(widget.radius),
          border: Border.all(color: widget.color),
          boxShadow: _focused
              ? [BoxShadow(color: ring, blurRadius: 4, spreadRadius: 1)]
              : null,
        ),
        child: widget.child,
      ),
    );
  }
}

/// Decoración flush (sin reserva de foco) para variantes sin borde propio.
ShadDecoration _flushDecor({double radius = 999}) => ShadDecoration(
  border: ShadBorder.fromBorderSide(
    const ShadBorderSide(color: Colors.transparent, width: 0),
    padding: EdgeInsets.zero,
    radius: BorderRadius.circular(radius),
  ),
  focusedBorder: ShadBorder.fromBorderSide(
    const ShadBorderSide(color: Colors.transparent, width: 0),
    padding: EdgeInsets.zero,
    radius: BorderRadius.circular(radius),
  ),
);

/// Escala 0.98 al presionar (active:scale del prototipo) sin robar el gesto.
class _TapScaleVe extends StatefulWidget {
  const _TapScaleVe({required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  State<_TapScaleVe> createState() => _TapScaleVeState();
}

class _TapScaleVeState extends State<_TapScaleVe> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerDown: widget.onTap == null
          ? null
          : (_) => setState(() => _down = true),
      onPointerUp: widget.onTap == null
          ? null
          : (_) => setState(() => _down = false),
      onPointerCancel: widget.onTap == null
          ? null
          : (_) => setState(() => _down = false),
      child: AnimatedScale(
        scale: _down ? 0.98 : 1,
        duration: const Duration(milliseconds: 90),
        curve: Curves.easeOut,
        child: widget.child,
      ),
    );
  }
}

/// Aclara (t>0) u oscurece (t<0) — SOLO estados hover/pressed.
Color _shift(Color c, double t) =>
    t >= 0 ? Color.lerp(c, Colors.white, t)! : Color.lerp(c, Colors.black, -t)!;

/// Botón cuadrado de 32×32 con icono (IconBtn del prototipo), borde fuerte,
/// tooltip nativo shadcn y punto rojo opcional de notificación.
class VeIconBtn extends StatelessWidget {
  const VeIconBtn({
    super.key,
    required this.icon,
    required this.onTap,
    required this.label,
    this.size = 32,
    this.iconSize = 15,
    this.dot = false,
    this.danger = false,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final String label;
  final double size;
  final double iconSize;

  /// Punto de notificación (esquina superior derecha).
  final bool dot;

  /// Tinta destructiva para el icono.
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final bool dark = shad.brightness == Brightness.dark;

    return Semantics(
      button: true,
      label: label,
      child: _TapScaleVe(
        onTap: onTap,
        child: ShadTooltip(
          waitDuration: const Duration(milliseconds: 450),
          builder: (context) => Text(label),
          child: _VeBorder(
            radius: kShadControlRadius,
            color: danger
                ? ink.neg.withValues(alpha: 0.4)
                : dark
                ? VeColors.lineStrongDark
                : VeColors.lineStrongLight,
            child: ShadButton.raw(
              variant: ShadButtonVariant.secondary,
              onPressed: onTap,
              width: size,
              height: size,
              padding: EdgeInsets.zero,
              backgroundColor: scheme.card,
              hoverBackgroundColor: scheme.accent,
              pressedBackgroundColor: scheme.accent,
              foregroundColor: danger ? ink.neg : scheme.foreground,
              hoverForegroundColor: danger ? ink.neg : scheme.foreground,
              decoration: _flushDecor(radius: kShadControlRadius),
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(icon, size: iconSize),
                  if (dot)
                    Positioned(
                      right: -3,
                      top: -3,
                      child: Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: ink.neg,
                          shape: BoxShape.circle,
                          border: Border.all(color: scheme.card, width: 2),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────── Chips ──────

/// Chip pill del prototipo (h 28 · radius 999): filtros de categoría, montos
/// rápidos del conversor, acciones de encabezado. Activo = tinta invertida.
/// `dashed` reproduce la variante «añadir» con borde discontinuo.
class VeChip extends StatelessWidget {
  const VeChip({
    super.key,
    required this.child,
    this.onTap,
    this.active = false,
    this.dashed = false,
    this.expands = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool active;
  final bool dashed;

  /// Ocupa todo el ancho disponible (fila de chips al mismo ancho — REQ 6
  /// v18.0: «±10 % · ±100» alineados sin Wrap que los reordene).
  final bool expands;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;

    final Widget content = _chipText(
      context,
      active ? scheme.background : scheme.foreground,
    );

    Widget button = ShadButton.raw(
      variant: ShadButtonVariant.ghost,
      onPressed: onTap,
      height: 28,
      width: expands ? double.infinity : null,
      mainAxisAlignment: expands
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      padding: dashed
          ? EdgeInsets.zero
          : const EdgeInsets.symmetric(horizontal: 12),
      backgroundColor: active ? scheme.primary : scheme.card,
      hoverBackgroundColor: active
          ? _shift(scheme.primary, dark ? 0.10 : -0.08)
          : scheme.accent,
      foregroundColor: active ? scheme.background : scheme.foreground,
      textStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: active ? scheme.background : scheme.foreground,
      ),
      // Borde via envoltorio Flutter: cero píxeles reservados.
      decoration: _flushDecor(),
      child: content,
    );

    if (dashed) {
      button = _DashedBorder(
        radius: 14,
        color: dark ? VeColors.lineStrongDark : VeColors.lineStrongLight,
        child: button,
      );
    } else {
      button = _VeBorder(
        radius: 999,
        color: active
            ? scheme.primary
            : dark
            ? VeColors.lineStrongDark
            : VeColors.lineStrongLight,
        child: button,
      );
    }

    return Semantics(
      button: onTap != null,
      child: _TapScaleVe(onTap: onTap, child: button),
    );
  }

  Widget _chipText(BuildContext context, Color fg) => DefaultTextStyle(
    style: TextStyle(
      fontFamily: 'Inter',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: fg,
    ),
    child: child,
  );
}

/// Borde discontinuo redondeado (variante «dashed» del Chip).
class _DashedBorder extends StatelessWidget {
  const _DashedBorder({
    required this.radius,
    required this.color,
    required this.child,
  });

  final double radius;
  final Color color;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      foregroundPainter: _DashedRRectPainter(radius: radius, color: color),
      child: child,
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  _DashedRRectPainter({required this.radius, required this.color});

  final double radius;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    for (final p in _dashPath(rrect, 4, 3)) {
      canvas.drawPath(p, paint);
    }
  }

  List<Path> _dashPath(RRect rrect, double dash, double gap) {
    final path = Path()..addRRect(rrect);
    final metrics = path.computeMetrics();
    final out = <Path>[];
    for (final m in metrics) {
      double start = 0;
      while (start < m.length) {
        out.add(m.extractPath(start, (start + dash).clamp(0, m.length)));
        start += dash + gap;
      }
    }
    return out;
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter old) =>
      old.color != color || old.radius != radius;
}

// ────────────────────────────────────────────────────────────── Badge ──────

/// Tono semántico de [VeBadge] (fondo tenue + texto del tono).
enum VeTone { neutral, pos, neg, warn, info }

/// Badge caps del prototipo: 10.5 px w600 mayúsculas, fondo tenue del tono
/// (`--pos-bg` & co.) y punto pulsante opcional. Sobre [ShadBadge.raw].
class VeBadge extends StatelessWidget {
  const VeBadge({
    super.key,
    required this.child,
    this.tone = VeTone.neutral,
    this.dot = false,
  });

  final Widget child;
  final VeTone tone;
  final bool dot;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;

    final (Color bg, Color fg) = switch (tone) {
      VeTone.neutral => (scheme.muted, scheme.mutedForeground),
      VeTone.pos => (ink.posBg, ink.pos),
      VeTone.neg => (ink.negBg, ink.neg),
      VeTone.warn => (ink.warnBg, ink.warn),
      VeTone.info => (ink.infoBg, ink.manual),
    };

    return ShadBadge.raw(
      variant: ShadBadgeVariant.secondary,
      backgroundColor: bg,
      foregroundColor: fg,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(6),
        side: const BorderSide(style: BorderStyle.none),
      ),
      child: DefaultTextStyle(
        style: TextStyle(
          fontFamily: 'Inter',
          fontSize: 10.5,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.6,
          color: fg,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (dot) ...[
              VePulseDot(color: fg, size: 5),
              const SizedBox(width: 6),
            ],
            child,
          ],
        ),
      ),
    );
  }
}

/// Punto que pulsa (anim-pulse 1.8 s · 1 → 0.35 → 1).
class VePulseDot extends StatefulWidget {
  const VePulseDot({super.key, required this.color, this.size = 6});

  final Color color;
  final double size;

  @override
  State<VePulseDot> createState() => _VePulseDotState();
}

class _VePulseDotState extends State<VePulseDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: Tween<double>(
        begin: 1,
        end: 0.35,
      ).animate(CurvedAnimation(parent: _c, curve: Curves.easeInOut)),
      child: Container(
        width: widget.size,
        height: widget.size,
        decoration: BoxDecoration(color: widget.color, shape: BoxShape.circle),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────── Toggle ─────

/// Switch compacto 32×18 del prototipo sobre [ShadSwitch]: pista tinta al
/// activar, pista `--line-strong` al reposo, pulgada de fondo siempre.
class VeToggle extends StatelessWidget {
  const VeToggle({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;
    final Color lineStrong = dark
        ? VeColors.lineStrongDark
        : VeColors.lineStrongLight;

    final Widget toggle = ShadSwitch(
      value: value,
      onChanged: onChanged,
      // 32×18 EXACTOS del prototipo (margin = aire interno del pulgar).
      width: 32,
      height: 18,
      margin: 2,
      duration: const Duration(milliseconds: 180),
      thumbColor: scheme.background,
      checkedTrackColor: scheme.primary,
      uncheckedTrackColor: lineStrong,
      decoration: ShadDecoration(
        border: ShadBorder.fromBorderSide(
          ShadBorderSide(color: Colors.transparent, width: 0),
          padding: EdgeInsets.zero,
          radius: BorderRadius.circular(999),
        ),
        focusedBorder: ShadBorder.fromBorderSide(
          ShadBorderSide(color: Colors.transparent, width: 0),
          padding: EdgeInsets.zero,
          radius: BorderRadius.circular(999),
        ),
      ),
    );
    return label == null ? toggle : Semantics(label: label, child: toggle);
  }
}

// ──────────────────────────────────────────────────────────── Checkbox ─────

/// Checkbox 18 px radius 5 sobre [ShadCheckbox], con la animación pop del
/// prototipo al marcar y el check en tinta invertida.
class VeCheckbox extends StatelessWidget {
  const VeCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.label,
  });

  final bool value;
  final VoidCallback? onChanged;
  final String? label;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;
    final Color lineStrong = dark
        ? VeColors.lineStrongDark
        : VeColors.lineStrongLight;

    return _VeBorder(
      radius: 5,
      color: value ? scheme.primary : lineStrong,
      ringColor: scheme.primary.withValues(alpha: 0.45),
      child: ShadCheckbox(
        value: value,
        onChanged: onChanged == null ? null : (_) => onChanged!(),
        size: 18,
        duration: const Duration(milliseconds: 180),
        color: scheme.primary,
        uncheckedColor: scheme.card,
        decoration: _flushDecor(radius: 5),
        icon: _PopCheck(color: scheme.background, size: 12),
      ),
    );
  }
}

/// Check con animación pop (scale 0.4 → 1.15 → 1, 220 ms).
class _PopCheck extends StatefulWidget {
  const _PopCheck({required this.color, required this.size});

  final Color color;
  final double size;

  @override
  State<_PopCheck> createState() => _PopCheckState();
}

class _PopCheckState extends State<_PopCheck>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 220),
  );

  @override
  void didUpdateWidget(covariant _PopCheck old) {
    super.didUpdateWidget(old);
    _c.forward(from: 0);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final curved = CurvedAnimation(
      parent: _c,
      curve: const Cubic(0.34, 1.56, 0.64, 1),
    );
    return ScaleTransition(
      scale: Tween<double>(begin: 0.4, end: 1).animate(curved),
      child: Icon(LucideIcons.check, size: widget.size, color: widget.color),
    );
  }
}

// ────────────────────────────────────────────────────────── Segmented ──────

/// Segmento del [VeSegmented].
class VeSegment<T> {
  const VeSegment({required this.value, required this.label});
  final T value;
  final String label;
}

/// Control segmentado del prototipo (subtle + borde) con MEJORA sobre el
/// original: la pastilla activa se DESLIZA entre segmentos (AnimatedAlign)
/// en vez de aparecer — feedback de movimiento superior.
class VeSegmented<T> extends StatelessWidget {
  const VeSegmented({
    super.key,
    required this.value,
    required this.onChanged,
    required this.segments,
  });

  final T value;
  final ValueChanged<T> onChanged;
  final List<VeSegment<T>> segments;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;
    final int active = segments.indexWhere((s) => s.value == value);

    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(kShadControlRadius),
        border: Border.all(color: scheme.border),
      ),
      child: LayoutBuilder(
        builder: (context, c) {
          final double w = c.maxWidth / segments.length;
          return Stack(
            children: [
              if (active >= 0)
                AnimatedAlign(
                  duration: const Duration(milliseconds: 220),
                  curve: kEaseVe,
                  alignment: Alignment(
                    -1 + 2 * (active + 0.5) / segments.length,
                    0,
                  ),
                  child: Container(
                    width: w,
                    height: double.infinity,
                    decoration: BoxDecoration(
                      color: scheme.card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: scheme.border),
                      boxShadow: [
                        BoxShadow(
                          color: dark
                              ? Colors.black.withValues(alpha: 0.35)
                              : const Color(0x1409090B),
                          blurRadius: 3,
                          offset: const Offset(0, 1),
                        ),
                      ],
                    ),
                  ),
                ),
              Row(
                children: [
                  for (var i = 0; i < segments.length; i++)
                    Expanded(
                      child: GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        // v21.2: clic de selección al cambiar de segmento —
                        // el gesto táctil confirma sin ruido (no-op en web).
                        onTap: () {
                          HapticFeedback.selectionClick();
                          onChanged(segments[i].value);
                        },
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 150),
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: i == active
                                  ? scheme.foreground
                                  : scheme.mutedForeground,
                            ),
                            child: Text(segments[i].label),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────── Stepper ──────

/// Stepper compacto del prototipo: − valor + con separadores verticales
/// (h 28), usado en la lista y en «dividir cuenta».
class VeStepper extends StatelessWidget {
  const VeStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 1,
    this.max = 99,
    this.semantic,
  });

  final int value;
  final ValueChanged<int> onChanged;
  final int min;
  final int max;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;
    final Color lineStrong = dark
        ? VeColors.lineStrongDark
        : VeColors.lineStrongLight;

    Widget side(IconData i, VoidCallback? onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: 28,
        height: double.infinity,
        child: Icon(
          i,
          size: 13,
          color: onTap == null
              ? scheme.mutedForeground.withValues(alpha: 0.4)
              : scheme.foreground,
        ),
      ),
    );

    return Semantics(
      label: semantic,
      child: Container(
        height: 28,
        decoration: BoxDecoration(
          color: scheme.card,
          borderRadius: BorderRadius.circular(kShadControlRadius),
          border: Border.all(color: lineStrong),
        ),
        clipBehavior: Clip.antiAlias,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            side(
              LucideIcons.minus,
              value <= min ? null : () => onChanged(value - 1),
            ),
            Container(
              width: 32,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: scheme.border),
                  right: BorderSide(color: scheme.border),
                ),
              ),
              child: Text(
                '$value',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w500,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  color: scheme.foreground,
                ),
              ),
            ),
            side(
              LucideIcons.plus,
              value >= max ? null : () => onChanged(value + 1),
            ),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────── Input ──────

/// Campo de texto 36 px del prototipo sobre [ShadInput]: borde fuerte,
/// placeholder `--faint` y foco con borde tinta.
class VeInput extends StatelessWidget {
  const VeInput({
    super.key,
    this.controller,
    this.placeholder,
    this.onChanged,
    this.onSubmitted,
    this.focusNode,
    this.enabled = true,
    this.textAlign = TextAlign.start,
    this.keyboardType,
    this.inputFormatters,
    this.maxLength,
    this.autofocus = false,
    this.style,
    this.semantic,
  });

  final TextEditingController? controller;
  final String? placeholder;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final FocusNode? focusNode;
  final bool enabled;
  final TextAlign textAlign;
  final TextInputType? keyboardType;
  final List<TextInputFormatter>? inputFormatters;
  final int? maxLength;
  final bool autofocus;
  final TextStyle? style;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;
    final Color faint = dark ? VeColors.faintDark : VeColors.faintLight;

    return Semantics(
      label: semantic,
      textField: true,
      child: _VeBorder(
        radius: kShadControlRadius,
        color: dark ? VeColors.lineStrongDark : VeColors.lineStrongLight,
        child: ShadInput(
          controller: controller,
          placeholder: placeholder == null
              ? null
              : Text(
                  placeholder!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    color: faint,
                  ),
                ),
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          focusNode: focusNode,
          enabled: enabled,
          autofocus: autofocus,
          keyboardType: keyboardType,
          inputFormatters: inputFormatters,
          maxLength: maxLength,
          textAlign: textAlign,
          style:
              style ??
              TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                color: scheme.foreground,
              ),
          decoration: ShadDecoration(
            color: scheme.card,
          ).merge(_flushDecor(radius: kShadControlRadius)),
        ),
      ),
    );
  }
}

/// Rótulo + control + ayuda (Field del prototipo): eyebrow, campo, hint.
class VeField extends StatelessWidget {
  const VeField({
    super.key,
    required this.label,
    required this.child,
    this.hint,
  });

  final String label;
  final Widget child;
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.84,
            color: scheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 6),
        child,
        if (hint != null) ...[
          const SizedBox(height: 4),
          Text(
            hint!,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              color: scheme.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────── Select ─────

/// Opción de [VeSelect] (valor + etiqueta visible).
class VeSelectOption<T> {
  const VeSelectOption({required this.value, required this.label});
  final T value;
  final String label;
}

/// Select sobre [ShadSelect] con la piel del prototipo (36 px · borde
/// fuerte). Menú popover nativo de shadcn/ui.
///
/// Nota de API: ShadSelect no es controlado (su valor viaja en
/// `initialValue`); para reflejar cambios externos se remonta con una
/// ValueKey derivada del valor — patrón ligero y sin controlador extra.
class VeSelect<T> extends StatelessWidget {
  const VeSelect({
    super.key,
    required this.value,
    required this.options,
    required this.onChanged,
    this.placeholder,
    this.semantic,
  });

  final T? value;
  final List<VeSelectOption<T>> options;
  final ValueChanged<T>? onChanged;
  final String? placeholder;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;
    final Color faint = dark ? VeColors.faintDark : VeColors.faintLight;

    final String? selectedLabel = value == null
        ? null
        : options
              .where((o) => o.value == value)
              .map((o) => o.label)
              .firstOrNull;

    Widget triggerRow(String text, {bool isPlaceholder = false}) => Row(
      children: [
        Expanded(
          child: Text(
            text,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              color: isPlaceholder ? faint : scheme.foreground,
            ),
          ),
        ),
        Icon(LucideIcons.chevronDown, size: 14, color: scheme.mutedForeground),
      ],
    );

    return Semantics(
      label: semantic,
      child: _VeBorder(
        radius: kShadControlRadius,
        color: dark ? VeColors.lineStrongDark : VeColors.lineStrongLight,
        child: ShadSelect<T>(
          key: ValueKey<T?>(value),
          initialValue: value,
          placeholder: Text(
            placeholder ?? 'Elegir…',
            style: TextStyle(fontFamily: 'Inter', fontSize: 13, color: faint),
          ),
          selectedOptionBuilder: (context, v) => selectedLabel == null
              ? triggerRow(placeholder ?? 'Elegir…', isPlaceholder: true)
              : triggerRow(selectedLabel),
          onChanged: (v) {
            if (v != null) onChanged?.call(v);
          },
          options: [
            for (final o in options)
              ShadOption(
                value: o.value,
                child: Text(
                  o.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    color: scheme.foreground,
                  ),
                ),
              ),
          ],
          decoration: ShadDecoration(
            color: scheme.card,
          ).merge(_flushDecor(radius: kShadControlRadius)),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────── kbd ──────

/// Tecla de atajo (kbd del prototipo): JetBrains Mono 10 px, borde línea.
class VeKbd extends StatelessWidget {
  const VeKbd({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: scheme.border),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontFamily: 'JetBrainsMono',
          fontVariations: const [FontVariation('wght', 500)],
          fontSize: 10,
          color: scheme.mutedForeground,
        ),
      ),
    );
  }
}
