/// ─── Controles «Ve» · Material 3 nativo (v25 «HOJA») ──────────────────────
/// Botones, chips, badges, inputs y selectores del lenguaje «HOJA»:
/// píldoras SIN borde, tinta sólida solo donde importa (primario, chip
/// activo, tecla de keypad), inputs SUBRAYADOS y badges SOLO de texto.
/// Construidos sobre Material 3 PURO (InkWell/Material/TextField/MenuAnchor).
///
/// Medidas v25 (regla del dueño):
///   Btn   sm 36 · md 44 · lg 52 px, píldora 999, primary = tinta sólida
///   IconBtn plano · hover tonal circular · pista ≥44
///   Chip  h 28 · pill 999 · activo = tinta sólida · inactivo tonal muted
///   Badge solo-texto caps 10.5px w600 + punto opcional (SIN fondo)
///   Toggle 32×18 · Checkbox circular · Stepper sin caja
///   Input 36 SUBRAYADO (reposo 1px · foco 2px tinta)
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/ve_theme.dart';

// ─────────────────────────────────────────────────────────────── Botones ───

/// Variante visual de [VeBtn], 1:1 con el `Btn` del prototipo.
enum VeBtnVariant { primary, secondary, ghost, danger }

/// Tamaño de [VeBtn] (sm 28 · md 36 · lg 44 px).
enum VeBtnSize { sm, md, lg }

/// Botón del sistema sobre [_VeRawButton] — Material 3 puro con la piel
/// «HOJA».
///
/// - primary: píldora de TINTA sólida (fg) con texto bg.
/// - secondary: tonal muted SIN borde, hover en `--hover`.
/// - ghost: sin fill; texto fg, hover en `--hover`.
/// - danger: tonal neg 10 % SIN borde con texto neg.
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
    final scheme = context.ve.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final bool dark = context.ve.brightness == Brightness.dark;

    final (
      double h,
      double px,
      double fs,
      double isz,
      double gap,
    ) = switch (size) {
      // v25 «HOJA»: alturas sm 36 · md 44 · lg 52 (regla del dueño).
      VeBtnSize.sm => (36, 12, 12, 13, 6),
      VeBtnSize.md => (44, 16, 13.5, 15, 8),
      VeBtnSize.lg => (52, 18, 14.5, 16, 8),
    };

    final (
      Color bg,
      Color hoverBg,
      Color pressedBg,
      Color fg,
    ) = switch (variant) {
      VeBtnVariant.primary => (
        scheme.primary,
        _shift(scheme.primary, dark ? 0.10 : -0.08),
        _shift(scheme.primary, dark ? 0.16 : -0.14),
        scheme.background,
      ),
      // Tonal muted SIN borde: el tono es el contorno.
      VeBtnVariant.secondary => (
        scheme.muted,
        scheme.accent,
        scheme.accent,
        scheme.foreground,
      ),
      VeBtnVariant.ghost => (
        Colors.transparent,
        scheme.accent,
        scheme.accent,
        scheme.foreground,
      ),
      // Danger tonal neg 10 % (token negBg) SIN borde, texto neg.
      VeBtnVariant.danger => (
        ink.negBg,
        _shift(ink.negBg, dark ? 0.06 : -0.04),
        _shift(ink.negBg, dark ? 0.10 : -0.08),
        ink.neg,
      ),
    };

    final Widget button = _VeRawButton(
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
      gap: gap,
      padding: EdgeInsets.symmetric(horizontal: px),
      textStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: fs,
        fontWeight: FontWeight.w600,
        color: fg,
      ),
      radius: 999,
      leading: icon == null ? null : Icon(icon, size: iconSize ?? isz),
      child: child,
    );

    return Semantics(
      button: true,
      enabled: enabled,
      label: semantic,
      child: _TapScaleVe(onTap: enabled ? onPressed : null, child: button),
    );
  }
}

/// Botón Material 3 crudo con la piel exacta del prototipo: fondo animado
/// por estado (reposo → hover → pressed), tinta del texto fija y CERO
/// píxeles reservados — el control mide exactamente `height`. Ocupa el
/// lugar del ShadButton.raw de la era shadcn con la misma superficie.
class _VeRawButton extends StatefulWidget {
  const _VeRawButton({
    required this.onPressed,
    required this.height,
    required this.backgroundColor,
    required this.hoverBackgroundColor,
    required this.pressedBackgroundColor,
    required this.foregroundColor,
    this.width,
    this.mainAxisAlignment = MainAxisAlignment.start,
    this.padding = EdgeInsets.zero,
    this.gap = 0,
    this.textStyle,
    this.radius = 999,
    this.leading,
    required this.child,
  });

  final VoidCallback? onPressed;
  final double height;
  final double? width;
  final Color backgroundColor;
  final Color hoverBackgroundColor;
  final Color pressedBackgroundColor;
  final Color foregroundColor;
  final MainAxisAlignment mainAxisAlignment;
  final EdgeInsets padding;
  final double gap;
  final TextStyle? textStyle;
  final double radius;
  final Widget? leading;
  final Widget child;

  @override
  State<_VeRawButton> createState() => _VeRawButtonState();
}

class _VeRawButtonState extends State<_VeRawButton> {
  bool _hover = false;
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final Color bg = !enabled
        ? widget.backgroundColor
        : _down
        ? widget.pressedBackgroundColor
        : _hover
        ? widget.hoverBackgroundColor
        : widget.backgroundColor;
    final BorderRadius r = BorderRadius.circular(widget.radius);
    return MouseRegion(
      onEnter: enabled ? (_) => setState(() => _hover = true) : null,
      onExit: enabled ? (_) => setState(() => _hover = false) : null,
      child: Material(
        color: bg,
        borderRadius: r,
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: widget.onPressed,
          onHighlightChanged: enabled ? (v) => setState(() => _down = v) : null,
          borderRadius: r,
          child: Opacity(
            opacity: enabled ? 1 : 0.6,
            child: SizedBox(
              height: widget.height,
              width: widget.width,
              child: Padding(
                padding: widget.padding,
                child: Row(
                  mainAxisSize: widget.width == null
                      ? MainAxisSize.min
                      : MainAxisSize.max,
                  mainAxisAlignment: widget.mainAxisAlignment,
                  children: [
                    if (widget.leading != null) ...[
                      // La tinta del icono es la del TEXTO del botón (como
                      // la era shadcn): IconTheme.merge tiñe los Icon sin
                      // color propio — sin esto, el icono caía al negro del
                      // IconTheme de la app y desaparecía sobre el primario.
                      IconTheme.merge(
                        data: IconThemeData(color: widget.foregroundColor),
                        child: widget.leading!,
                      ),
                      SizedBox(width: widget.gap),
                    ],
                    // v25 · fix overflow 320: el hijo va SIEMPRE en
                    // Flexible(loose) — da al contenido un máximo ACOTADO
                    // (lo que resta del ancho). Hijos con Expanded interno
                    // (trigger del VeSelect) son legales; textos e iconos
                    // miden lo suyo sin forced stretch y JAMÁS desbordan la
                    // píldora (un Text apretado envuelve, no rebosa).
                    Flexible(
                      fit: FlexFit.loose,
                      child: DefaultTextStyle(
                        style:
                            widget.textStyle ??
                            TextStyle(color: widget.foregroundColor),
                        child: widget.child,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

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

/// Botón de icono PLANO v25 «HOJA»: sin borde, hover tonal circular y
/// punto rojo opcional de notificación. Pista ≥44 garantizada por el
/// envoltorio de golpe.
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
    final scheme = context.ve.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;

    Widget core = Semantics(
      button: true,
      label: label,
      child: _TapScaleVe(
        onTap: onTap,
        child: Tooltip(
          message: label,
          waitDuration: const Duration(milliseconds: 450),
          child: _VeRawButton(
            onPressed: onTap,
            width: size,
            height: size,
            padding: EdgeInsets.zero,
            backgroundColor: Colors.transparent,
            hoverBackgroundColor: scheme.accent,
            pressedBackgroundColor: scheme.accent,
            foregroundColor: danger ? ink.neg : scheme.foreground,
            radius: 999,
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
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );

    // v23.3 (pez 2-a P1-1): caja de golpe ≥44 — el visual sigue siendo
    // `size` (32 por defecto) pero el dedo tiene 44×44 de pista: la caja
    // exterior crece y el margen también dispara el tap (GestureDetector
    // opaco por fuera, botón por dentro — la arena elige al ganador y
    // onTap corre UNA vez).
    final double hit = size < 44 ? 44 : size;
    if (onTap == null) {
      return SizedBox(
        width: hit,
        height: hit,
        child: Center(child: core),
      );
    }
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        width: hit,
        height: hit,
        child: Center(child: core),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────── Chips ──────

/// Chip pill v25 «HOJA» (h 28 visual · radius 999): filtros de categoría,
/// montos rápidos del conversor, acciones de encabezado. ACTIVO = píldora
/// de tinta sólida; inactivo = tonal muted SIN borde. Sin borde discontinuo
/// (`dashed` se aplana al mismo tonal). Pista de toque ≥44: el wrapper
/// centra la píldora de 28 en una caja de golpe de 44 de alto.
class VeChip extends StatelessWidget {
  const VeChip({
    super.key,
    required this.child,
    this.onTap,
    this.active = false,
    this.dashed = false,
    this.expands = false,
    this.icon,
    this.dense = false,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool active;
  final bool dashed;

  /// Ocupa todo el ancho disponible (fila de chips al mismo ancho — REQ 6
  /// v18.0: «±10 % · ±100» alineados sin Wrap que los reordene).
  final bool expands;

  /// Icono opcional antes del texto (v23.2: fichas de secciones del
  /// Conversor). 13 px, mismo color del texto — no cambia el alto 28.
  final IconData? icon;

  /// Padding horizontal 6 en vez de 12 (v23.2: filas de fichas expandidas
  /// del piso de teclado — 7 slots por línea no dan para 24 px de aire).
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    final bool dark = context.ve.brightness == Brightness.dark;

    final Color fg = active ? scheme.background : scheme.foreground;
    final Widget content = icon == null
        ? _chipText(context, fg)
        : Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 13, color: fg),
              const SizedBox(width: 5),
              Flexible(child: _chipText(context, fg)),
            ],
          );

    final Widget button = _VeRawButton(
      onPressed: onTap,
      height: 28,
      width: expands ? double.infinity : null,
      mainAxisAlignment: expands
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      padding: EdgeInsets.symmetric(horizontal: dense ? 6 : 12),
      // v25 «HOJA»: activo = tinta sólida · inactivo = tonal muted (sin
      // borde, sin discontinuo).
      backgroundColor: active ? scheme.primary : scheme.muted,
      hoverBackgroundColor: active
          ? _shift(scheme.primary, dark ? 0.10 : -0.08)
          : scheme.accent,
      pressedBackgroundColor: active
          ? _shift(scheme.primary, dark ? 0.16 : -0.14)
          : scheme.accent,
      foregroundColor: fg,
      radius: 999,
      textStyle: TextStyle(
        fontFamily: 'Inter',
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: fg,
      ),
      child: content,
    );

    // Pista de toque ≥44 (v23.3, patrón VeIconBtn): caja de golpe centrada
    // — el visual sigue siendo la píldora de 28.
    // v25.2 (fix Wrap): SIN `expands`, el Center debe ENCOGERSE al ancho de
    // la píldora (`widthFactor: 1`) — con widthFactor null, Center se
    // expandía al ancho entrante del Wrap (358) y CADA chip ocupaba su
    // propia fila centrada (la fila de fechas se apilaba verticalmente).
    final double hit = 44;
    return Semantics(
      button: onTap != null,
      child: SizedBox(
        width: expands ? double.infinity : null,
        height: hit,
        child: Center(
          widthFactor: expands ? null : 1,
          child: onTap == null
              ? button
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onTap,
                  child: _TapScaleVe(onTap: onTap, child: button),
                ),
        ),
      ),
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

// ────────────────────────────────────────────────────────────── Badge ──────

/// Tono semántico de [VeBadge] (fondo tenue + texto del tono).
enum VeTone { neutral, pos, neg, warn, info }

/// Badge v25 «HOJA»: SOLO texto de color — caps 10.5 px w600 mayúsculas
/// del tono y punto pulsante opcional. SIN fondo, SIN borde (regla de 3).
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
    final scheme = context.ve.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;

    final Color fg = switch (tone) {
      VeTone.neutral => scheme.mutedForeground,
      VeTone.pos => ink.pos,
      VeTone.neg => ink.neg,
      VeTone.warn => ink.warn,
      VeTone.info => ink.manual,
    };

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
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
              VePulseDot(color: fg, size: 4),
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

/// Switch compacto 32×18 del prototipo, Flutter puro (v24): pista tinta al
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
    final scheme = context.ve.colorScheme;
    final bool dark = context.ve.brightness == Brightness.dark;
    final Color lineStrong = dark
        ? VeColors.lineStrongDark
        : VeColors.lineStrongLight;

    // 32×18 EXACTOS del prototipo; pulgada 14 con 2 de aire (margin: 2).
    final Widget toggle = Semantics(
      toggled: value,
      enabled: onChanged != null,
      child: GestureDetector(
        onTap: onChanged == null ? null : () => onChanged!(!value),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          width: 32,
          height: 18,
          decoration: BoxDecoration(
            color: value ? scheme.primary : lineStrong,
            borderRadius: BorderRadius.circular(999),
          ),
          child: AnimatedAlign(
            duration: const Duration(milliseconds: 180),
            curve: Curves.easeOut,
            alignment: value ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.all(2),
              child: Container(
                width: 14,
                height: 14,
                decoration: BoxDecoration(
                  color: scheme.background,
                  shape: BoxShape.circle,
                ),
              ),
            ),
          ),
        ),
      ),
    );
    return label == null ? toggle : Semantics(label: label, child: toggle);
  }
}

// ──────────────────────────────────────────────────────────── Checkbox ─────

/// Checkbox 18 px v25 «HOJA»: CIRCULAR (controles 999) y SIN borde —
/// tonal muted al reposo, tinta sólida al marcar, con la animación pop del
/// check en tinta invertida.
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
    final scheme = context.ve.colorScheme;
    final bool dark = context.ve.brightness == Brightness.dark;
    final Color lineStrong = dark
        ? VeColors.lineStrongDark
        : VeColors.lineStrongLight;

    return Semantics(
      checked: value,
      enabled: onChanged != null,
      child: Material(
        color: value ? scheme.primary : lineStrong,
        shape: const CircleBorder(),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onChanged,
          customBorder: const CircleBorder(),
          child: SizedBox(
            width: 18,
            height: 18,
            child: Center(
              // Marcado: check en tinta invertida sobre la píldora de tinta.
              // El pop vive en _PopCheck (solo en la transición a marcado).
              child: _PopCheck(
                color: value ? scheme.background : Colors.transparent,
                size: 12,
                checked: value,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Check con animación pop (scale 0.4 → 1.15 → 1, 220 ms).
class _PopCheck extends StatefulWidget {
  const _PopCheck({
    required this.color,
    required this.size,
    this.checked = true,
  });

  final Color color;
  final double size;

  /// v23.3 (pez 2-b P2-5): el pop se dispara solo al MARCAR — antes cada
  /// rebuild del padre re-animaba (mismo patrón de guard que VeFlash).
  final bool checked;

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
    // v23.3: solo en la transición a marcado — un rebuild cualquiera no
    // re-anima.
    if (widget.checked && !old.checked) _c.forward(from: 0);
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

/// Control segmentado v25 «HOJA»: contenedor transparente y la pastilla
/// activa — píldora de TINTA sólida — se DESLIZA entre segmentos
/// (AnimatedAlign). Cero borde, cero sombra.
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
    final scheme = context.ve.colorScheme;
    final int active = segments.indexWhere((s) => s.value == value);

    return Container(
      height: 32,
      padding: const EdgeInsets.all(2),
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
                      // v25 «HOJA»: segmento activo = píldora de tinta.
                      color: scheme.primary,
                      borderRadius: BorderRadius.circular(999),
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
                                  ? scheme.background
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

/// Stepper compacto v25 «HOJA»: − valor + SIN caja y SIN separadores
/// dibujados — solo iconos y cifra tabular sobre el papel (h 36).
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
    final scheme = context.ve.colorScheme;

    Widget side(IconData i, VoidCallback? onTap) => GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: SizedBox(
        // v23.3 (pez 2-a P1-1): pista de 36 — el stepper vive en filas
        // densas (carrito 2 líneas) donde 44 engordaría la fila; 36 es
        // AA holgado (24) manteniendo la densidad de la Lista.
        width: 36,
        height: double.infinity,
        child: Icon(
          i,
          size: 14,
          color: onTap == null
              ? scheme.mutedForeground.withValues(alpha: 0.4)
              : scheme.foreground,
        ),
      ),
    );

    return Semantics(
      label: semantic,
      child: SizedBox(
        height: 36,
        // v25 «HOJA»: stepper SIN caja (ni clip — no hay superficie que
        // recortar).
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            side(
              LucideIcons.minus,
              value <= min ? null : () => onChanged(value - 1),
            ),
            SizedBox(
              width: 36,
              child: Center(
                child: Text(
                  '$value',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: scheme.foreground,
                  ),
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

/// Campo de texto 36 px v25 «HOJA» sobre `TextField` de Material 3:
/// SUBRAYADO — sin fill ni caja; reposo línea 1 px, foco línea 2 px tinta.
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
    final scheme = context.ve.colorScheme;
    final bool dark = context.ve.brightness == Brightness.dark;
    final Color faint = dark ? VeColors.faintDark : VeColors.faintLight;

    return Semantics(
      label: semantic,
      textField: true,
      child: SizedBox(
        height: 36,
        child: Center(
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            enabled: enabled,
            autofocus: autofocus,
            keyboardType: keyboardType,
            inputFormatters: inputFormatters,
            maxLength: maxLength,
            textAlign: textAlign,
            onChanged: onChanged,
            onSubmitted: onSubmitted,
            cursorColor: scheme.primary,
            style:
                style ??
                TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  color: scheme.foreground,
                ),
            decoration: InputDecoration(
              hintText: placeholder,
              hintStyle: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                color: faint,
              ),
              // v25 «HOJA»: input subrayado — línea 1 px en reposo, 2 px de
              // tinta al foco. Sin fill.
              border: UnderlineInputBorder(
                borderSide: BorderSide(
                  color: dark
                      ? VeColors.lineStrongDark
                      : VeColors.lineStrongLight,
                ),
              ),
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: scheme.border),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: scheme.primary, width: 2),
              ),
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 2,
                vertical: 9,
              ),
              // maxLength NO muestra contador (contrato de la era shadcn).
              counterText: '',
            ),
          ),
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
    final scheme = context.ve.colorScheme;
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
  const VeSelectOption({
    required this.value,
    required this.label,
    this.leading,
  });

  final T value;
  final String label;

  /// Icono/insignia opcional a la izquierda (v27.1: logos de banco).
  final Widget? leading;
}

/// Select sobre `MenuAnchor` de Material 3 v25 «HOJA» (36 px · trigger
/// subrayado). Menú popover radio 20, sin borde, sin sombra — controlado
/// por `value`, sin trucos de remount.
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
    final scheme = context.ve.colorScheme;
    final bool dark = context.ve.brightness == Brightness.dark;
    final Color faint = dark ? VeColors.faintDark : VeColors.faintLight;

    String? selectedLabel;
    Widget? selectedLeading;
    for (final o in options) {
      if (o.value == value) {
        selectedLabel = o.label;
        selectedLeading = o.leading;
      }
    }

    Widget triggerRow(
      String text, {
      bool isPlaceholder = false,
      Widget? leading,
    }) => Row(
      children: [
        if (leading != null) ...[leading, const SizedBox(width: 8)],
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
      child: MenuAnchor(
        alignmentOffset: const Offset(0, 4),
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(scheme.popover),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shadowColor: const WidgetStatePropertyAll(Colors.transparent),
          elevation: const WidgetStatePropertyAll(0),
          shape: WidgetStatePropertyAll(
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          ),
          padding: const WidgetStatePropertyAll(
            EdgeInsets.symmetric(vertical: 4),
          ),
        ),
        menuChildren: [
          for (final o in options)
            MenuItemButton(
              onPressed: () => onChanged?.call(o.value),
              child: Row(
                children: [
                  if (o.leading != null) ...[
                    o.leading!,
                    const SizedBox(width: 8),
                  ],
                  Flexible(
                    child: Text(
                      o.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13,
                        color: scheme.foreground,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
        builder: (context, controller, child) => Container(
          // v25 «HOJA»: trigger subrayado (línea 1 px bajo el control).
          decoration: BoxDecoration(
            border: Border(bottom: BorderSide(color: scheme.border, width: 1)),
          ),
          child: _VeRawButton(
            onPressed: () {
              if (controller.isOpen) {
                controller.close();
              } else {
                controller.open();
              }
            },
            height: 36,
            width: double.infinity,
            backgroundColor: Colors.transparent,
            hoverBackgroundColor: scheme.accent,
            pressedBackgroundColor: scheme.accent,
            foregroundColor: scheme.foreground,
            padding: const EdgeInsets.symmetric(horizontal: 2),
            radius: 999,
            child: selectedLabel == null
                ? triggerRow(placeholder ?? 'Elegir…', isPlaceholder: true)
                : triggerRow(selectedLabel, leading: selectedLeading),
          ),
        ),
      ),
    );
  }
}

// ──────────────────────────────────────────────────────────────── kbd ──────

/// Tecla de atajo (kbd) v25 «HOJA»: SOLO texto — JetBrains Mono 10 px en
/// muted, sin caja ni borde.
class VeKbd extends StatelessWidget {
  const VeKbd({super.key, required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 2),
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
