/// ─── ValoraVE · Sistema de diseño «El Instrumento» (§8 + GUI dp4) ───────────
/// Componentes firma: Stamp, ReadWindow, LedgerRow, RuleDouble, SourceDot,
/// TrendBadge, SectionTitle, PageHeader, EmptyState, CategoryIcon, StatCard,
/// StoreAvatar, Flag, AnimatedNumber (odómetro), LiveDot, ChipTag,
/// SegmentedChips, RateTicker configurable, RateHealthBanner.
/// Motion: EASE [0.16,1,0.3,1] · tap 120 / state 200 / layout 300 / entrance
/// 600 ms · TAP .96 · stagger 45 ms cap 350 · reducedMotion del sistema.
library;

import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

import '../core/currencies.dart';
import '../core/fmt.dart';
import '../core/models.dart';
import '../core/theme.dart';

/// Curva firma del sistema (EASE [0.16, 1, 0.3, 1]).
const Cubic kEaseVe = Cubic(0.16, 1.0, 0.3, 1.0);

const Duration kTapDur = Duration(milliseconds: 120);
const Duration kStateDur = Duration(milliseconds: 200);
const Duration kLayoutDur = Duration(milliseconds: 300);
const Duration kEntranceDur = Duration(milliseconds: 600);

/// Botón con escala en tap (TAP .96, 120 ms).
class TapScale extends StatefulWidget {
  const TapScale({super.key, required this.child, required this.onTap, this.scale = 0.96});

  final Widget child;
  final VoidCallback? onTap;
  final double scale;

  @override
  State<TapScale> createState() => _TapScaleState();
}

class _TapScaleState extends State<TapScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: widget.onTap == null ? null : (_) => setState(() => _down = true),
      onTapCancel: () => setState(() => _down = false),
      onTapUp: (_) => setState(() => _down = false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _down ? widget.scale : 1,
        duration: kTapDur,
        curve: kEaseVe,
        child: widget.child,
      ),
    );
  }
}

/// Bandera circular de divisa desde assets internos (offline-first).
class Flag extends StatelessWidget {
  const Flag(this.code, {super.key, this.size = 20});

  final Currency code;
  final double size;

  static const Map<Currency, String> _assets = {
    Currency.ves: 'assets/flags/ve.png',
    Currency.usd: 'assets/flags/us.png',
    Currency.eur: 'assets/flags/eu.png',
    Currency.cop: 'assets/flags/co.png',
    Currency.brl: 'assets/flags/br.png',
    Currency.mxn: 'assets/flags/mx.png',
  };

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Theme.of(context).brightness == Brightness.dark
            ? VeColors.mutedDark
            : VeColors.mutedLight,
      ),
      padding: const EdgeInsets.all(1.2),
      child: ClipOval(
        child: Image.asset(
          _assets[code]!,
          width: size,
          height: size,
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) => ColoredBox(color: scheme.outlineVariant),
        ),
      ),
    );
  }
}

/// Sello puntual de estado/fuente: borde de tinta 38 %, fondo al 7 %.
class Stamp extends StatelessWidget {
  const Stamp(this.text, {super.key, this.color, this.icon});

  final String text;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final Color c = color ?? Theme.of(context).colorScheme.onSurfaceVariant;
    final Widget? iconWidget = icon == null ? null : Icon(icon, size: 9, color: c);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        border: Border.all(color: c.withValues(alpha: 0.38)),
        borderRadius: BorderRadius.circular(5),
        color: c.withValues(alpha: 0.07),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (iconWidget != null) ...[
            iconWidget,
            const SizedBox(width: 3),
          ],
          Text(
            text.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.8,
              color: c,
            ),
          ),
        ],
      ),
    );
  }
}

/// Ventana de lectura: pozo hundido donde se asienta la cifra héroe
/// (Semantics en cifras protagonistas, §Fase 3).
class ReadWindow extends StatelessWidget {
  const ReadWindow({super.key, required this.child, this.padding = const EdgeInsets.symmetric(horizontal: 14, vertical: 12), this.semanticLabel});

  final Widget child;
  final EdgeInsets padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: dark
            ? VeColors.mutedDark.withValues(alpha: 0.8)
            : VeColors.mutedLight.withValues(alpha: 0.55),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
            color: Theme.of(context).colorScheme.outlineVariant.withValues(alpha: 0.5)),
      ),
      child: Semantics(
        label: semanticLabel,
        child: child,
      ),
    );
  }
}

/// Renglón «Etiqueta ······ cifra» con puntos contables (solo cierre cuentas).
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.boldValue = false,
    this.leading,
    this.dots = true,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? valueColor;
  final bool boldValue;
  final Widget? leading;
  final bool dots;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final row = Row(
      children: [
        if (leading != null) ...[leading!, const SizedBox(width: 6)],
        Flexible(
          child: Text(
            label,
            style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurface),
            overflow: TextOverflow.ellipsis,
          ),
        ),
        if (dots) ...[
          const SizedBox(width: 6),
          Expanded(child: _LedgerDots(color: scheme.onSurfaceVariant.withValues(alpha: 0.42))),
        ],
        const SizedBox(width: 6),
        Text(
          value,
          style: VeText.displayNum(14, color: valueColor ?? scheme.onSurface,
              weight: boldValue ? FontWeight.w700 : FontWeight.w600),
        ),
      ],
    );
    if (onTap == null) return row;
    return InkWell(onTap: onTap, borderRadius: BorderRadius.circular(8), child: row);
  }
}

class _LedgerDots extends StatelessWidget {
  const _LedgerDots({required this.color});
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final int count = (c.maxWidth / 6).floor().clamp(0, 60);
      return Row(
        children: [
          for (int i = 0; i < count; i++)
            Expanded(
              child: Container(
                height: 1.4,
                margin: const EdgeInsets.symmetric(horizontal: 1),
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
            ),
        ],
      );
    });
  }
}

/// Doble filete contable (rule-double): cierre de totales.
class RuleDouble extends StatelessWidget {
  const RuleDouble({super.key});

  @override
  Widget build(BuildContext context) {
    final Color c = Theme.of(context).colorScheme.outlineVariant;
    return Column(children: [
      Container(height: 1, color: c.withValues(alpha: 0.9)),
      const SizedBox(height: 2),
      Container(height: 1, color: c.withValues(alpha: 0.6)),
    ]);
  }
}

/// Marca de categoría de fuente: barra 3×13 con formas distintas.
class SourceDot extends StatelessWidget {
  const SourceDot(this.cat, {super.key, this.color});

  final SourceCategory cat;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final VeInk sem = VeColors.of(context);
    final Color c = color ??
        switch (cat) {
          SourceCategory.official => sem.pos,
          SourceCategory.mixed => sem.warn,
          SourceCategory.parallel => sem.neg,
          SourceCategory.manual => sem.manual,
        };
    return Container(
      width: 3,
      height: 13,
      decoration: BoxDecoration(
        color: cat == SourceCategory.mixed ? Colors.transparent : c,
        border: cat == SourceCategory.mixed ? Border.all(color: c, width: 1.6) : null,
        borderRadius: switch (cat) {
          SourceCategory.official => BorderRadius.circular(999),
          SourceCategory.parallel => const BorderRadius.only(
              topLeft: Radius.circular(0),
              bottomLeft: Radius.circular(0),
              topRight: Radius.circular(999),
              bottomRight: Radius.circular(999)),
          _ => BorderRadius.circular(2),
        },
      ),
    );
  }
}

/// Insignia de tendencia: «+2,1 %» — subida rojo, bajada verde (precios).
class TrendBadge extends StatelessWidget {
  const TrendBadge(this.pct, {super.key, this.dense = false});

  final double pct;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final VeInk sem = VeColors.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final bool up = pct > 0;
    final bool flat = pct.abs() < 0.01;
    final Color c = flat ? scheme.onSurfaceVariant : (up ? sem.neg : sem.pos);
    return Row(mainAxisSize: MainAxisSize.min, children: [
      Icon(flat ? Icons.remove : (up ? Icons.trending_up : Icons.trending_down),
          size: dense ? 11 : 13, color: c),
      const SizedBox(width: 3),
      Text(
        flat ? 'Igual' : fmtPct(pct),
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: dense ? 10.5 : 12,
          fontWeight: FontWeight.w700,
          color: c,
        ),
      ),
    ]);
  }
}

/// Chip pequeño con tinte (ChipTag).
class ChipTag extends StatelessWidget {
  const ChipTag(this.label, {super.key, this.color, this.selected = false, this.onTap});

  final String label;
  final Color? color;
  final bool selected;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurfaceVariant;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: selected ? c.withValues(alpha: 0.15) : Colors.transparent,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
              color: selected ? c.withValues(alpha: 0.5) : scheme.outlineVariant),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 12,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            color: selected ? c : scheme.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}

/// Grupo de chips segmentados (SegmentedChips).
class SegmentedChips<T> extends StatelessWidget {
  const SegmentedChips({
    super.key,
    required this.options,
    required this.value,
    required this.onChanged,
    this.labelOf,
  });

  final List<T> options;
  final T value;
  final ValueChanged<T> onChanged;
  final String Function(T)? labelOf;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      children: [
        for (final o in options)
          ChipTag(
            labelOf?.call(o) ?? '$o',
            selected: o == value,
            onTap: () => onChanged(o),
          ),
      ],
    );
  }
}

/// Índice + rótulo técnico + acción derecha.
class SectionTitle extends StatelessWidget {
  const SectionTitle(this.title, {super.key, this.icon, this.actionLabel, this.onAction, this.index});

  final String title;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;
  final int? index;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(children: [
        if (index != null) ...[
          Text(
            index!.toString().padLeft(2, '0'),
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: scheme.primary.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(width: 8),
        ],
        if (icon != null) ...[
          Icon(icon, size: 14, color: scheme.primary),
          const SizedBox(width: 6),
        ],
        Expanded(
          child: Text(
            title.toUpperCase(),
            style: VeText.labelCaps(11, color: scheme.onSurface, weight: FontWeight.w700),
          ),
        ),
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel!, style: const TextStyle(fontSize: 12)),
          ),
      ]),
    );
  }
}

/// Cabecera de módulo: título + hint + acción.
class PageHeader extends StatelessWidget {
  const PageHeader(this.title, {super.key, this.hint, this.action});

  final String title;
  final String? hint;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 6, bottom: 14),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(title,
                style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: scheme.onSurface,
                    height: 1.1)),
            if (hint != null) ...[
              const SizedBox(height: 3),
              Text(hint!, style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
            ],
          ]),
        ),
        ?action,
      ]),
    );
  }
}

/// Estado vacío: tile de icono + título + pista + CTA.
class EmptyState extends StatelessWidget {
  const EmptyState(this.title, {super.key, required this.icon, required this.hint, this.actionLabel, this.onAction});

  final IconData icon;
  final String title;
  final String hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
        child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: scheme.primary.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: scheme.primary),
          ),
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(hint, textAlign: TextAlign.center,
              style: TextStyle(fontSize: 12.5, height: 1.45, color: scheme.onSurfaceVariant)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.arrow_forward, size: 15),
              label: Text(actionLabel!),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Tile de icono de categoría con tinta semántica (producto o finanzas).
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, this.cat, this.finCat, this.size = 36});

  final ProductCategory? cat;
  final FinanceCategory? finCat;
  final double size;

  @override
  Widget build(BuildContext context) {
    final VeInk sem = VeColors.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = finCat != null
        ? switch (finCat!) {
            FinanceCategory.salario => (Icons.account_balance, sem.pos),
            FinanceCategory.otrosIngresos => (Icons.account_balance_outlined, sem.warn),
            FinanceCategory.alimentacion => (Icons.restaurant, sem.neg),
            FinanceCategory.transporte => (Icons.directions_car, sem.pos),
            FinanceCategory.servicios => (Icons.lightbulb_outline, sem.warn),
            FinanceCategory.entretenimiento => (Icons.movie_outlined, sem.manual),
            FinanceCategory.salud => (Icons.favorite_border, sem.neg),
            FinanceCategory.educacion => (Icons.menu_book_outlined, sem.pos),
            FinanceCategory.otrosGastos => (Icons.more_horiz, scheme.onSurfaceVariant),
          }
        : switch (cat!) {
            ProductCategory.alimentos => (Icons.lunch_dining_outlined, sem.pos),
            ProductCategory.bebidas => (Icons.local_cafe_outlined, sem.pos),
            ProductCategory.limpieza => (Icons.cleaning_services_outlined, sem.warn),
            ProductCategory.higiene => (Icons.soap_outlined, sem.manual),
            ProductCategory.farmacia => (Icons.medication_outlined, sem.neg),
            ProductCategory.tecnologia => (Icons.smartphone_outlined, sem.manual),
            ProductCategory.otros => (Icons.inventory_2_outlined, scheme.onSurfaceVariant),
          };
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(size * 0.3),
      ),
      child: Icon(icon, size: size * 0.5, color: color),
    );
  }
}

enum StatTone { neutral, pos, neg, warn }

/// Tarjeta de indicador (StatCard).
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.icon,
    this.tone = StatTone.neutral,
  });

  final String label;
  final String value;
  final String? sub;
  final IconData? icon;
  final StatTone tone;

  @override
  Widget build(BuildContext context) {
    final VeInk sem = VeColors.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color toneColor = switch (tone) {
      StatTone.pos => sem.pos,
      StatTone.neg => sem.neg,
      StatTone.warn => sem.warn,
      StatTone.neutral => scheme.onSurfaceVariant,
    };
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            if (icon != null) ...[
              Icon(icon, size: 13, color: toneColor),
              const SizedBox(width: 5),
            ],
            Expanded(
              child: Text(label.toUpperCase(),
                  style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
                  overflow: TextOverflow.ellipsis),
            ),
          ]),
          const SizedBox(height: 9),
          Text(value, style: VeText.displayNum(21, color: scheme.onSurface)),
          if (sub != null) ...[
            const SizedBox(height: 4),
            Text(sub!, style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
          ],
        ]),
      ),
    );
  }
}

/// Avatar de tienda con iniciales y tinta estable (hash del nombre).
class StoreAvatar extends StatelessWidget {
  const StoreAvatar(this.name, {super.key, this.size = 34});

  final String name;
  final double size;

  @override
  Widget build(BuildContext context) {
    final VeInk sem = VeColors.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final List<Color> inks = [sem.pos, sem.cop, sem.manual, sem.brl, sem.mxn, sem.warn];
    final Color ink = inks[name.hashCode.abs() % inks.length];
    final String initials = name
        .split(' ')
        .where((w) => w.isNotEmpty)
        .take(2)
        .map((w) => w[0].toUpperCase())
        .join();
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Text(initials, style: VeText.displayNum(size * 0.36, color: ink, weight: FontWeight.w700)),
    );
  }
}

/// AnimatedNumber: odómetro (§8 — sin setState por frame del dígitos):
/// interpola el valor mostrado con un AnimationController.
class AnimatedNumber extends StatefulWidget {
  const AnimatedNumber(
    this.value, {
    super.key,
    required this.style,
    this.decimals,
    this.prefix,
    this.suffix,
    this.duration = kStateDur,
  });

  final double value;
  final TextStyle style;
  final int? decimals;
  final String? prefix;
  final String? suffix;
  final Duration duration;

  @override
  State<AnimatedNumber> createState() => _AnimatedNumberState();
}

class _AnimatedNumberState extends State<AnimatedNumber> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl =
      AnimationController(vsync: this, duration: widget.duration);
  late Animation<double> _anim = AlwaysStoppedAnimation(widget.value);
  double _from = 0, _to = 0;

  @override
  void initState() {
    super.initState();
    _from = _to = widget.value;
  }

  @override
  void didUpdateWidget(covariant AnimatedNumber old) {
    super.didUpdateWidget(old);
    if (old.value != widget.value) {
      _from = _to;
      _to = widget.value;
      _anim = Tween<double>(begin: _from, end: _to)
          .animate(CurvedAnimation(parent: _ctrl, curve: kEaseVe));
      _ctrl
        ..reset()
        ..forward();
    }
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _anim,
      builder: (context, _) {
        final v = _anim.value;
        final dec = widget.decimals ?? 2;
        final text = '${widget.prefix ?? ''}${fmtNum(v, decimals: dec)}${widget.suffix ?? ''}';
        return Text(text, style: widget.style.copyWith(fontFeatures: const [FontFeature.tabularFigures()]));
      },
    );
  }
}

/// LiveDot: pulso del estado «en vivo».
class LiveDot extends StatelessWidget {
  const LiveDot({super.key, this.color, this.size = 7});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = color ?? VeColors.of(context).pos;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(color: c, shape: BoxShape.circle),
    );
  }
}

/// LiveBadge: píldora «en vivo» del header.
class LiveBadge extends StatelessWidget {
  const LiveBadge({super.key, required this.live, this.label});

  final bool live;
  final String? label;

  @override
  Widget build(BuildContext context) {
    if (!live) return const SizedBox.shrink();
    final VeInk sem = VeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: sem.pos.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: sem.pos.withValues(alpha: 0.3)),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        LiveDot(color: sem.pos),
        const SizedBox(width: 5),
        Text(label ?? 'en vivo',
            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sem.pos)),
      ]),
    );
  }
}

/// Píldora de fuente con SourceDot + etiqueta (RateBadge).
class RateBadge extends StatelessWidget {
  const RateBadge({super.key, required this.sourceId, this.trailing, this.onTap, this.selected = false});

  final String sourceId;
  final String? trailing;
  final VoidCallback? onTap;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final s = RateSource.of(sourceId);
    final label = s?.label ?? sourceId;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.07)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected
                  ? Theme.of(context).colorScheme.primary.withValues(alpha: 0.4)
                  : Theme.of(context).colorScheme.outlineVariant),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (s != null) ...[SourceDot(s.category), const SizedBox(width: 6)],
          Text(label, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
          if (trailing != null) ...[
            const SizedBox(width: 6),
            Text(trailing!, style: VeText.displayNum(12.5, color: Theme.of(context).colorScheme.onSurface)),
          ],
        ]),
      ),
    );
  }
}

/// Pills horizontales de fuentes (SourcePills).
class SourcePills extends StatelessWidget {
  const SourcePills({super.key, required this.sources, required this.value, required this.onChanged});

  final List<String> sources;
  final String value;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final id in sources)
          RateBadge(
            sourceId: id,
            selected: id == value,
            onTap: () => onChanged(id),
          ),
      ],
    );
  }
}

/// Selector de moneda con banderas (CurrencySelect).
class CurrencySelect extends StatelessWidget {
  const CurrencySelect({super.key, required this.value, required this.onChanged, this.withUsd = true});

  final Currency value;
  final ValueChanged<Currency> onChanged;
  final bool withUsd;

  @override
  Widget build(BuildContext context) {
    final options = CurrencyX.focusOrder(null).where((c) => withUsd || c != Currency.usd).toList();
    return PopupMenuButton<Currency>(
      initialValue: value,
      onSelected: onChanged,
      itemBuilder: (_) => [
        for (final c in options)
          PopupMenuItem(
            value: c,
            child: Row(children: [
              Flag(c, size: 18),
              const SizedBox(width: 8),
              Text(c.label, style: const TextStyle(fontSize: 13.5)),
            ]),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.25)),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Flag(value, size: 18),
          const SizedBox(width: 6),
          Text(value.code, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(width: 2),
          Icon(Icons.expand_more, size: 15, color: Theme.of(context).colorScheme.onSurfaceVariant),
        ]),
      ),
    );
  }
}

/// Banner de salud de tasas (>15 min sin fresca — §9 ui-bits).
class RateHealthBanner extends StatelessWidget {
  const RateHealthBanner({super.key, required this.stale, this.onRetry});

  final bool stale;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!stale) return const SizedBox.shrink();
    final VeInk sem = VeColors.of(context);
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: sem.warn.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sem.warn.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(Icons.hourglass_top, size: 14, color: sem.warn),
        const SizedBox(width: 8),
        Expanded(
          child: Text('Las tasas no se actualizan hace más de 15 min',
              style: TextStyle(fontSize: 12, color: sem.warn, fontWeight: FontWeight.w600)),
        ),
        if (onRetry != null)
          TextButton(
            onPressed: onRetry,
            style: TextButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 8),
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap),
            child: const Text('Reintentar', style: TextStyle(fontSize: 12)),
          ),
      ]),
    );
  }
}

/// Ticker de cotizaciones configurable (3 modos × 3 tamaños × 3 velocidades,
/// solo Inicio — §9.0 RateTicker). Loop −50 %; anti-CLS «Cargando…».
class RateTicker extends StatefulWidget {
  const RateTicker({
    super.key,
    required this.items,
    required this.mode,
    required this.size,
    required this.speed,
  });

  final List<({Currency flag, String label, double value, String unit, bool isEur})> items;
  final String mode; // featured | focus | off
  final String size; // compact | normal | large
  final int speed; // 90 | 120 | 180

  @override
  State<RateTicker> createState() => _RateTickerState();
}

class _RateTickerState extends State<RateTicker> with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl = AnimationController(vsync: this, duration: const Duration(seconds: 120))..repeat();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (widget.mode == 'off' || widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    _ctrl.duration = Duration(seconds: widget.speed);
    final (double height, double labelSize, double valueSize) = switch (widget.size) {
      'compact' => (30.0, 11.0, 12.0),
      'large' => (48.0, 14.5, 16.0),
      _ => (38.0, 12.5, 13.5),
    };
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final row = Row(mainAxisSize: MainAxisSize.min, children: [
      for (int i = 0; i < widget.items.length; i++)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Flag(widget.items[i].flag, size: 15),
            const SizedBox(width: 6),
            Text(widget.items[i].label,
                style: TextStyle(fontSize: labelSize, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant)),
            const SizedBox(width: 6),
            Text(
              widget.items[i].isEur ? fmtEurRate(widget.items[i].value) : fmtRate(widget.items[i].value),
              style: VeText.displayNum(valueSize, color: scheme.onSurface),
            ),
            const SizedBox(width: 4),
            Text(widget.items[i].unit,
                style: TextStyle(fontSize: labelSize - 1, fontWeight: FontWeight.w700, color: scheme.onSurfaceVariant)),
          ]),
        ),
    ]);

    return Container(
      height: height,
      color: (Theme.of(context).brightness == Brightness.dark ? VeColors.mutedDark : VeColors.mutedLight)
          .withValues(alpha: 0.4),
      child: AnimatedBuilder(
        animation: _ctrl,
        builder: (context, child) => ClipRect(
          child: FractionalTranslation(
            translation: Offset(-_ctrl.value * 0.5, 0),
            child: OverflowBox(maxWidth: double.infinity, alignment: Alignment.centerLeft, child: child),
          ),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [row, row]),
      ),
    );
  }
}

/// Skeleton de papel: altura exacta anti-CLS (skeleton-paper).
class SkeletonPaper extends StatelessWidget {
  const SkeletonPaper({super.key, this.height = 84});

  final double height;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.outlineVariant.withValues(alpha: 0.5)),
      ),
    );
  }
}

/// Copia al portapapeles con SnackBar accesible.
void copiarAlPortapapeles(BuildContext context, String text, String aviso) {
  Clipboard.setData(ClipboardData(text: text));
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(aviso), behavior: SnackBarBehavior.floating));
}

/// Genera un color estable a partir de un hash (para gráficas/tiendas).
Color tintOf(String key, List<Color> palette) => palette[key.hashCode.abs() % palette.length];

/// Paleta de 8 tintes para gráficas (var(--chart-1..8) del web).
List<Color> chartPalette(BuildContext context) {
  final VeInk sem = VeColors.of(context);
  return [
    Theme.of(context).colorScheme.primary,
    sem.pos,
    sem.neg,
    sem.warn,
    sem.manual,
    sem.cop,
    sem.brl,
    sem.mxn,
  ];
}

/// Helper: formatea moneda según el código string del modelo.
String fmtMoneyCode(double v, String code) => fmtCurrency(v, CurrencyX.from(code));

/// math importado para usos futuros (proporciones de donut).
double clamp01(double v) => math.min(1, math.max(0, v));

/// Fecha corta local (intl para robustez en meses raros).
String fmtMesAno(DateTime d) => DateFormat.MMMM('es').format(d).substring(0, 3);
