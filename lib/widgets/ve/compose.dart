/// ─── Composición «Ve» · cards, rows, sheets y ambiente (TASK-34) ───────────
/// Piezas de composición del prototipo web sobre shadcn_ui: Card/Group/Row
/// (listas divididas), Eyebrow/Title (jerarquía tipográfica), Sheet (bottom
/// móvil / modal centrado escritorio — como el original), StickyBar con blur,
/// Empty punteado y el fondo ambiental (radiales pos/warn + rejilla de puntos).
library;

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/shad_theme.dart' show kShadRadius;
import '../../core/theme.dart';

// ──────────────────────────────────────────────────────────────── Card ─────

/// Tarjeta del prototipo: radius 10, borde `--line`, superficie; al pasar el
/// cursor el borde sube a `--line-strong` (hover suave de escritorio).
class VeCard extends StatefulWidget {
  const VeCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(16),
    this.clip = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final EdgeInsetsGeometry padding;
  final bool clip;

  @override
  State<VeCard> createState() => _VeCardState();
}

class _VeCardState extends State<VeCard> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;
    final Color lineStrong = dark
        ? VeColors.lineStrongDark
        : VeColors.lineStrongLight;

    return MouseRegion(
      onEnter: widget.onTap == null
          ? null
          : (_) => setState(() => _hover = true),
      onExit: widget.onTap == null
          ? null
          : (_) => setState(() => _hover = false),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 140),
          curve: Curves.easeOut,
          padding: widget.padding,
          clipBehavior: widget.clip ? Clip.antiAlias : Clip.none,
          decoration: BoxDecoration(
            color: scheme.card,
            borderRadius: BorderRadius.circular(kShadRadius),
            border: Border.all(
              color: _hover && widget.onTap != null
                  ? lineStrong
                  : scheme.border,
            ),
          ),
          child: widget.child,
        ),
      ),
    );
  }
}

/// Grupo de filas divididas (Group + Row del prototipo): tarjeta con
/// separadores `--line` entre hijos y filas de mínimo 46 px.
class VeGroup extends StatelessWidget {
  const VeGroup({super.key, required this.children, this.semantic});

  final List<Widget> children;
  final String? semantic;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Semantics(
      label: semantic,
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: scheme.card,
          borderRadius: BorderRadius.circular(kShadRadius),
          border: Border.all(color: scheme.border),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < children.length; i++) ...[
              if (i > 0) Divider(height: 1, thickness: 1, color: scheme.border),
              children[i],
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila de lista del prototipo: etiqueta + subtítulo a la izquierda, valor a
/// la derecha (tabular). Tappable → hover; `danger` en tinta negativa.
class VeRow extends StatefulWidget {
  const VeRow({
    super.key,
    required this.label,
    this.sub,
    this.right,
    this.onTap,
    this.danger = false,
    this.showChevron = false,
    this.semantic,
  });

  final Widget label;
  final Widget? sub;
  final Widget? right;
  final VoidCallback? onTap;
  final bool danger;
  final bool showChevron;
  final String? semantic;

  @override
  State<VeRow> createState() => _VeRowState();
}

class _VeRowState extends State<VeRow> {
  bool _hover = false;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;

    final content = Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              DefaultTextStyle(
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w500,
                  color: widget.danger ? ink.neg : scheme.foreground,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: widget.label,
              ),
              if (widget.sub != null) ...[
                const SizedBox(height: 2),
                DefaultTextStyle(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: scheme.mutedForeground,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: widget.sub!,
                ),
              ],
            ],
          ),
        ),
        if (widget.right != null) ...[
          const SizedBox(width: 12),
          DefaultTextStyle(
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: scheme.mutedForeground,
            ),
            child: widget.right!,
          ),
        ],
        if (widget.showChevron) ...[
          const SizedBox(width: 8),
          Icon(
            LucideIcons.chevronRight,
            size: 14,
            color: scheme.mutedForeground,
          ),
        ],
      ],
    );

    final row = Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      color: _hover && widget.onTap != null ? scheme.accent : null,
      child: content,
    );

    if (widget.onTap == null) {
      return Semantics(label: widget.semantic, child: row);
    }
    return Semantics(
      label: widget.semantic,
      button: true,
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: row,
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────── Jerarquía texto ──────

/// Rótulo de sección en mayúsculas (eyebrow): 10.5 px w600 tracking .08em,
/// con slot `right` para acciones de encabezado.
class VeEyebrow extends StatelessWidget {
  const VeEyebrow({super.key, required this.child, this.right});

  final Widget child;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: [
          Expanded(
            child: DefaultTextStyle(
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: 0.84,
                color: scheme.mutedForeground,
              ),
              child: child,
            ),
          ),
          ?right,
        ],
      ),
    );
  }
}

/// Título de página del prototipo: eyebrow opcional arriba, 22 px Space
/// Grotesk semibold tracking -0.02em, acciones a la derecha.
class VeTitle extends StatelessWidget {
  const VeTitle({super.key, required this.child, this.sub, this.right});

  final Widget child;
  final Widget? sub;
  final Widget? right;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (sub != null) ...[
                  DefaultTextStyle(
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.84,
                      color: scheme.mutedForeground,
                    ),
                    child: sub!,
                  ),
                  const SizedBox(height: 4),
                ],
                DefaultTextStyle(
                  style: VeText.displayNum(
                    22,
                    color: scheme.foreground,
                    weight: FontWeight.w600,
                  ).copyWith(height: 1.2),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  child: child,
                ),
              ],
            ),
          ),
          if (right != null) ...[const SizedBox(width: 12), right!],
        ],
      ),
    );
  }
}

/// Entrada de pantalla (anim-in del prototipo): fade + 6 px hacia arriba en
/// 180 ms al montar la ruta.
class VeEntry extends StatelessWidget {
  const VeEntry({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 180),
      curve: Curves.easeOut,
      builder: (context, t, c) => Opacity(
        opacity: t,
        child: Transform.translate(offset: Offset(0, 6 * (1 - t)), child: c),
      ),
      child: child,
    );
  }
}

// ─────────────────────────────────────────────────────────────── Sheet ─────

/// Sheet del prototipo: bottom-sheet en móvil y modal centrado en escritorio
/// (≥ 700 px), con la MISMA cromática exacta: cabecera 48 px (título + ✕),
/// cuerpo scrollable y pie opcional con área segura.
///
/// Construido sobre `showShadSheet` (móvil) y `showShadDialog` (escritorio).
Future<T?> showVeSheet<T>({
  required BuildContext context,
  required String title,
  required WidgetBuilder builder,
  Widget? footer,
  bool wide = false,
  bool dismissible = true,
}) {
  final bool desktop = MediaQuery.sizeOf(context).width >= 700;
  final shad = ShadTheme.of(context);
  final barrier = shad.brightness == Brightness.dark
      ? Colors.black.withValues(alpha: 0.55)
      : Colors.black.withValues(alpha: 0.40);

  if (desktop) {
    return showShadDialog<T>(
      context: context,
      barrierDismissible: dismissible,
      barrierColor: barrier,
      builder: (context) => _VeSheetChrome(
        title: title,
        footer: footer,
        wide: wide,
        dismissible: dismissible,
        body: builder(context),
      ),
    );
  }
  return showShadSheet<T>(
    context: context,
    side: ShadSheetSide.bottom,
    barrierColor: barrier,
    isDismissible: dismissible,
    backgroundColor: shad.colorScheme.card,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(14)),
    ),
    builder: (context) => _VeSheetChrome(
      title: title,
      footer: footer,
      wide: wide,
      dismissible: dismissible,
      body: builder(context),
      bottomSheet: true,
    ),
  );
}

/// Cromática compartida del sheet (cabecera · cuerpo · pie).
class _VeSheetChrome extends StatelessWidget {
  const _VeSheetChrome({
    required this.title,
    required this.body,
    required this.footer,
    required this.wide,
    required this.dismissible,
    this.bottomSheet = false,
  });

  final String title;
  final Widget body;
  final Widget? footer;
  final bool wide;
  final bool dismissible;
  final bool bottomSheet;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final double maxW = wide ? 576 : 448;

    Widget chrome = Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.card,
        borderRadius: bottomSheet
            ? const BorderRadius.vertical(top: Radius.circular(14))
            : BorderRadius.circular(14),
        border: Border.all(color: scheme.border),
      ),
      child: Material(
        // Ancestro Material transparente: los cuerpos de la app mezclan
        // controles shadcn con widgets Material propios (MoneyField,
        // TextField de nombre, PopupMenu de divisas…) que lo exigen.
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: 48,
              padding: const EdgeInsets.only(left: 16, right: 8),
              decoration: BoxDecoration(
                border: Border(bottom: BorderSide(color: scheme.border)),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: scheme.foreground,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (dismissible)
                    ShadButton.raw(
                      variant: ShadButtonVariant.ghost,
                      onPressed: () => Navigator.of(context).maybePop(),
                      width: 32,
                      height: 32,
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      hoverBackgroundColor: scheme.accent,
                      foregroundColor: scheme.mutedForeground,
                      hoverForegroundColor: scheme.foreground,
                      child: Icon(LucideIcons.x, size: 15),
                    ),
                ],
              ),
            ),
            Flexible(
              child: ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: MediaQuery.sizeOf(context).height * 0.66,
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: body,
                ),
              ),
            ),
            if (footer != null)
              Container(
                padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                decoration: BoxDecoration(
                  border: Border(top: BorderSide(color: scheme.border)),
                ),
                child: SafeArea(
                  top: false,
                  minimum: const EdgeInsets.only(bottom: 4),
                  child: Row(children: [Expanded(child: footer!)]),
                ),
              ),
          ],
        ),
      ),
    );

    if (!bottomSheet) {
      chrome = ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxW),
        child: chrome,
      );
    }
    return chrome;
  }
}

// ─────────────────────────────────────────────────────────── StickyBar ─────

/// Barra pegada al fondo del viewport (StickyBar del prototipo): fondo
/// bg/85 + blur real del contenido que pasa por debajo + borde superior.
/// Colocar como último hijo de un Stack sobre el contenido scrollable.
class VeStickyBar extends StatelessWidget {
  const VeStickyBar({super.key, required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;

    return ClipRect(
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          decoration: BoxDecoration(
            color: scheme.background.withValues(alpha: dark ? 0.88 : 0.85),
            border: Border(top: BorderSide(color: scheme.border)),
          ),
          child: SafeArea(
            top: false,
            minimum: const EdgeInsets.only(bottom: 8),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
              child: Row(
                children: [
                  for (var i = 0; i < children.length; i++) ...[
                    if (i > 0) const SizedBox(width: 8),
                    Expanded(child: children[i]),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────── Empty ─────

/// Estado vacío del prototipo: tarjeta punteada (borde discontinuo
/// `--line-strong`), título, subtítulo y acción opcional centrada.
class VeEmpty extends StatelessWidget {
  const VeEmpty({super.key, required this.title, this.sub, this.action});

  final String title;
  final String? sub;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;
    final Color lineStrong = dark
        ? VeColors.lineStrongDark
        : VeColors.lineStrongLight;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(kShadRadius),
      ),
      foregroundDecoration: _DashedDecoration(
        color: lineStrong,
        radius: kShadRadius,
      ),
      child: Column(
        children: [
          Text(
            title,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              fontWeight: FontWeight.w500,
              color: scheme.foreground,
            ),
            textAlign: TextAlign.center,
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(
              sub!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12,
                color: scheme.mutedForeground,
              ),
              textAlign: TextAlign.center,
            ),
          ],
          if (action != null) ...[const SizedBox(height: 12), action!],
        ],
      ),
    );
  }
}

class _DashedDecoration extends Decoration {
  const _DashedDecoration({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _DashedBoxPainter(color: color, radius: radius);
  }
}

class _DashedBoxPainter extends BoxPainter {
  _DashedBoxPainter({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    final size = configuration.size;
    if (size == null) return;
    final rect = offset & size;
    final rrect = RRect.fromRectAndRadius(rect, Radius.circular(radius));
    final path = Path()..addRRect(rrect);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = color;
    for (final m in path.computeMetrics()) {
      double start = 0;
      while (start < m.length) {
        canvas.drawPath(
          m.extractPath(start, (start + 5).clamp(0, m.length)),
          paint,
        );
        start += 5 + 4;
      }
    }
  }
}

// ──────────────────────────────────────────────────────────── Ambiente ─────

/// Fondo ambiental del prototipo (app-ambient + app-dots): dos radiales
/// tenues (pos arriba-derecha 7 %, warn a la izquierda 6 %) y una rejilla de
/// puntos `--line` de 22 px que se desvanece al 72 % de la altura.
///
/// Pintado UNA sola vez (RepaintBoundary + shouldRepaint false) — costo
/// trivial incluso en pantallas grandes.
class VeAmbient extends StatelessWidget {
  const VeAmbient({super.key, this.dots = true});

  final bool dots;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final bool dark = shad.brightness == Brightness.dark;

    return RepaintBoundary(
      child: CustomPaint(
        painter: _AmbientPainter(
          pos: ink.pos,
          warn: ink.warn,
          line: scheme.border,
          dots: dots,
          dark: dark,
        ),
        size: Size.infinite,
      ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.pos,
    required this.warn,
    required this.line,
    required this.dots,
    required this.dark,
  });

  final Color pos;
  final Color warn;
  final Color line;
  final bool dots;
  final bool dark;

  @override
  void paint(Canvas canvas, Size size) {
    // Radial pos: foco en 85 % x, -12 % y → radio 1100×520 (elipse aprox).
    final rectPos = Rect.fromCenter(
      center: Offset(size.width * 0.85, -size.height * 0.12),
      width: size.width * 1.6,
      height: size.height * 1.1,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(rectPos.center, rectPos.width / 2, [
          pos.withValues(alpha: dark ? 0.05 : 0.07),
          pos.withValues(alpha: 0),
        ]),
    );

    // Radial warn: foco en -8 % x, 18 % y.
    final rectWarn = Rect.fromCenter(
      center: Offset(-size.width * 0.08, size.height * 0.18),
      width: size.width * 1.3,
      height: size.height * 0.95,
    );
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = ui.Gradient.radial(rectWarn.center, rectWarn.width / 2, [
          warn.withValues(alpha: dark ? 0.045 : 0.06),
          warn.withValues(alpha: 0),
        ]),
    );

    if (!dots) return;

    // Rejilla de puntos 22 px con máscara que se desvanece al 72 %.
    final dotPaint = Paint()..color = line;
    final fade = Paint()
      ..shader = ui.Gradient.linear(
        Offset(0, 0),
        Offset(0, size.height * 0.72),
        [const Color(0xFF000000), const Color(0x00000000)],
      )
      ..blendMode = BlendMode.dstIn;

    canvas.saveLayer(Offset.zero & size, Paint());
    const step = 22.0;
    for (double x = step / 2; x < size.width; x += step) {
      for (double y = step / 2; y < size.height; y += step) {
        canvas.drawCircle(Offset(x, y), 1, dotPaint);
      }
    }
    canvas.drawRect(Offset.zero & size, fade);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _AmbientPainter old) =>
      old.pos != pos ||
      old.warn != warn ||
      old.line != line ||
      old.dots != dots;
}

// ───────────────────────────────────────────────── Flash de número ────────

/// Flash del prototipo (anim-flash): cuando [value] cambia, el fondo del
/// hijo destella en pos/18 % y se disuelve en 900 ms. Para cifras de tasas.
class VeFlash extends StatefulWidget {
  const VeFlash({super.key, required this.value, required this.child});

  /// Valor vigilado: cada cambio dispara el flash.
  final Object value;
  final Widget child;

  @override
  State<VeFlash> createState() => _VeFlashState();
}

class _VeFlashState extends State<VeFlash> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void didUpdateWidget(covariant VeFlash old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _c.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final bool dark = shad.brightness == Brightness.dark;

    return AnimatedBuilder(
      animation: _c,
      builder: (context, child) => DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(6),
          color: _c.isAnimating
              ? ink.pos.withValues(alpha: (dark ? 0.14 : 0.18) * (1 - _c.value))
              : null,
        ),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ─────────────────────────────────────────────────── Cifra tabular ─────────

/// Texto numérico tabular del prototipo (clase .num): Inter con tnum —
/// para montos y contadores que no deben bailar de ancho.
class VeNum extends StatelessWidget {
  const VeNum(this.data, {super.key, this.style, this.semanticsLabel});

  final String data;
  final TextStyle? style;
  final String? semanticsLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Semantics(
      label: semanticsLabel ?? data,
      child: Text(
        data,
        style:
            (style ??
                    TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      color: scheme.foreground,
                    ))
                .copyWith(fontFeatures: const [FontFeature.tabularFigures()]),
      ),
    );
  }
}
