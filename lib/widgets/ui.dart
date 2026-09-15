/// ─── ValoraVE · Sistema de diseño «El Instrumento» (§8 + GUI dp4) ───────────
/// Componentes firma: Stamp, ReadWindow, LedgerRow, RuleDouble, SourceSeal,
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

/// Curva firma del sistema (EASE [0.16, 1, 0.3, 1]) — definida UNA sola vez
/// en core/theme.dart (§8) y re-exportada aquí para no romper a quien ya la
/// importaba desde ui.dart.
export '../core/theme.dart' show kEaseVe;

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

/// Sello puntual de estado/fuente: borde de tinta 38 %, fondo al 8 % (§8).
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
        color: c.withValues(alpha: 0.08),
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
        // §8 regla dura: bordes 100 % sólidos (nunca alpha parcial).
        border: Border.all(color: dark ? VeColors.borderDark : VeColors.borderLight),
      ),
      child: Semantics(
        label: semanticLabel,
        child: child,
      ),
    );
  }
}

/// Renglón «Etiqueta ······ cifra» con puntos contables — SOLO cierre de
/// cuentas (§8). Default `dots: false`: las listas de items NO encienden
/// puntos (contrato: quien necesite filete contable pasa dots: true).
/// Sin puntos, el label ocupa el resto de la fila para que la cifra quede
/// alineada a la derecha igual que con ellos (misma geometría, sin dot-leader).
class LedgerRow extends StatelessWidget {
  const LedgerRow({
    super.key,
    required this.label,
    required this.value,
    this.valueColor,
    this.boldValue = false,
    this.leading,
    this.dots = false,
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
        if (dots)
          Flexible(
            child: Text(
              label,
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: scheme.onSurface),
              overflow: TextOverflow.ellipsis,
            ),
          )
        else
          Expanded(
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

/// Doble filete contable (rule-double): cierre de totales. §8 bordes 100 %:
/// filete fuerte = token border sólido · filete débil = token muted sólido.
class RuleDouble extends StatelessWidget {
  const RuleDouble({super.key});

  @override
  Widget build(BuildContext context) {
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Column(children: [
      Container(height: 1, color: dark ? VeColors.borderDark : VeColors.borderLight),
      const SizedBox(height: 2),
      Container(height: 1, color: dark ? VeColors.mutedDark : VeColors.mutedLight),
    ]);
  }
}

/// Sello de categoría de tasa (v19.0 · orden del dueño): ICONO + PALABRA —
/// la identidad no vive en una rayita de color («AI slop», fuera). Un sello
/// se lee SIN colores y dice QUÉ es la tasa: OFICIAL 🏛 · MERCADO 🛒 ·
/// PROMEDIO ⚖ · MANUAL ✎. El color queda solo como acento suave.
class SourceSeal extends StatelessWidget {
  const SourceSeal(this.cat, {super.key});

  final SourceCategory cat;

  @override
  Widget build(BuildContext context) {
    final VeInk sem = VeColors.of(context);
    final (icon, word, c) = switch (cat) {
      SourceCategory.official =>
        (Icons.account_balance_rounded, 'OFICIAL', sem.pos),
      SourceCategory.parallel => (Icons.storefront_rounded, 'MERCADO', sem.neg),
      SourceCategory.mixed => (Icons.balance_rounded, 'PROMEDIO', sem.warn),
      SourceCategory.manual => (Icons.edit_note_rounded, 'MANUAL', sem.manual),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2.5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: c.withValues(alpha: 0.38), width: 1),
      ),
      child: Row(mainAxisSize: MainAxisSize.min, children: [
        Icon(icon, size: 10.5, color: c),
        const SizedBox(width: 4),
        Text(word,
            style: TextStyle(
                fontSize: 8.5,
                fontWeight: FontWeight.w800,
                letterSpacing: 0.6,
                color: c)),
      ]),
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
            // §8: display en SpaceGrotesk (los números siguen tabulares).
            Text(title,
                style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
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

/// Estado de CARGA (v17.6 · RECHECK R1-4/R2-6): spinner + título + pista.
///
/// REGLA DURA: la carga NUNCA lleva icono wifi-off — ese icono es de
/// [OfflineState]. «Buscando tasas…» con señal cortada era exactamente el
/// combo mentiroso que el dueño prohibió. Para skeletons de layout completo
/// existe SkeletonPaper; este tile cubre bloques dentro de una pantalla.
class LoadingState extends StatelessWidget {
  const LoadingState(this.title,
      {super.key, this.hint, this.actionLabel, this.onAction});

  final String title;
  final String? hint;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
        child: Column(children: [
          SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
                strokeWidth: 2.6, color: scheme.primary),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          if (hint != null) ...[
            const SizedBox(height: 6),
            Text(hint!,
                textAlign: TextAlign.center,
                style: TextStyle(
                    fontSize: 12.5,
                    height: 1.45,
                    color: scheme.onSurfaceVariant)),
          ],
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            GhostButton(actionLabel!, onPressed: onAction),
          ],
        ]),
      ),
    );
  }
}

/// Estado de ERROR (v17.6 · RECHECK R1-4): tile en tinta neg + pista + CTA
/// de recuperación SIEMPRE visible (un error sin salida no es un estado).
class ErrorState extends StatelessWidget {
  const ErrorState(this.title,
      {super.key, required this.hint, this.actionLabel, this.onAction, this.icon = Icons.error_outline});

  final String title;
  final String hint;
  final String? actionLabel;
  final VoidCallback? onAction;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Color neg = VeColors.of(context).neg;
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 30),
        child: Column(children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: neg.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: neg),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: scheme.onSurfaceVariant)),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 14),
            GhostButton(actionLabel!, onPressed: onAction),
          ],
        ]),
      ),
    );
  }
}

/// Estado OFFLINE (v17.6 · RECHECK R1-4/R2-6): cloud_off + copy honesto
/// es-VE + salidas reales (reintentar · tasa manual). Solo este estado dice
/// «sin conexión»; carga y datos guardados jamás lo mencionan.
class OfflineState extends StatelessWidget {
  const OfflineState(this.title,
      {super.key,
      required this.hint,
      this.actionLabel,
      this.onAction,
      this.secondaryLabel,
      this.onSecondary,
      this.icon = Icons.cloud_off});

  final String title;
  final String hint;
  final String? actionLabel;
  final VoidCallback? onAction;
  final String? secondaryLabel;
  final VoidCallback? onSecondary;
  final IconData icon;

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
              color: scheme.onSurfaceVariant.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, size: 24, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          Text(title,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(hint,
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: scheme.onSurfaceVariant)),
          if ((actionLabel != null && onAction != null) ||
              (secondaryLabel != null && onSecondary != null)) ...[
            const SizedBox(height: 14),
            Row(mainAxisAlignment: MainAxisAlignment.center, children: [
              if (actionLabel != null && onAction != null) ...[
                GhostButton(actionLabel!, onPressed: onAction),
                if (secondaryLabel != null && onSecondary != null)
                  const SizedBox(width: 8),
              ],
              if (secondaryLabel != null && onSecondary != null)
                GhostButton(secondaryLabel!, onPressed: onSecondary),
            ]),
          ],
        ]),
      ),
    );
  }
}

/// Tile de icono de categoría de PRODUCTO con tinta semántica.
/// v17.8: la variante de finanzas (finCat) se retiró con el módulo.
class CategoryIcon extends StatelessWidget {
  const CategoryIcon({super.key, this.cat, this.size = 36});

  final ProductCategory? cat;
  final double size;

  @override
  Widget build(BuildContext context) {
    final VeInk sem = VeColors.of(context);
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final (IconData icon, Color color) = switch (cat!) {
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

/// Píldora de fuente con SourceSeal + etiqueta (RateBadge).
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
          if (s != null) ...[SourceSeal(s.category), const SizedBox(width: 6)],
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

/// Banner de salud de tasas (§9 ui-bits). Dos causas, dos copys:
/// · SIN RED (v17.8, señal viva de connectivity_plus): calmado — las
///   tasas guardadas siguen siendo la verdad y la red vuelve sola.
/// · TASAS VIEJAS (>15 min con red): aviso con reintentar.
class RateHealthBanner extends StatelessWidget {
  const RateHealthBanner({super.key, required this.stale, this.offline = false, this.onRetry});

  final bool stale;
  final bool offline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    if (!stale && !offline) return const SizedBox.shrink();
    final VeInk sem = VeColors.of(context);
    final bool netDown = offline && stale;
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: netDown
            ? sem.manual.withValues(alpha: 0.09)
            : sem.warn.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
            color: netDown ? sem.manual.withValues(alpha: 0.35) : sem.warn.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(netDown ? Icons.wifi_off : Icons.hourglass_top,
            size: 14, color: netDown ? sem.manual : sem.warn),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
              netDown
                  ? 'Sin conexión — tasas guardadas a la vista'
                  : 'Las tasas no se actualizan hace más de 15 min',
              style: TextStyle(
                  fontSize: 12,
                  color: netDown ? sem.manual : sem.warn,
                  fontWeight: FontWeight.w600)),
        ),
        if (!netDown && onRetry != null)
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
    // Modo off = preferencia del usuario → no se monta (shrink). Sin datos →
    // placeholder anti-CLS con la misma altura (delega en RateTicker).
    if (widget.mode == 'off') return const SizedBox.shrink();
    if (widget.items.isEmpty) {
      final double height = switch (widget.size) {
        'compact' => 30.0,
        'large' => 48.0,
        _ => 38.0,
      };
      final bool dark = Theme.of(context).brightness == Brightness.dark;
      return Container(
        height: height,
        color: (dark ? VeColors.mutedDark : VeColors.mutedLight).withValues(alpha: 0.4),
        alignment: Alignment.center,
        child: Text(
          'Cargando cotizaciones…',
          style: TextStyle(
            fontSize: 13.5,
            color: dark ? VeColors.mutedFgDark : VeColors.mutedFgLight,
          ),
        ),
      );
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
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    return Container(
      height: height,
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(12),
        // §8 regla dura: borde sólido (nunca alpha parcial).
        border: Border.all(color: dark ? VeColors.borderDark : VeColors.borderLight),
      ),
    );
  }
}

/// ─── Tintas semánticas por divisa / categoría (CONTRATO §8) ────────────────
/// CONTRATO PARA FEATURE-AGENT: `currencyInk(Currency)` y
/// `categoryInk(String)` son helpers PURos sin BuildContext — devuelven la
/// tinta canónica CLARA de cada divisa/categoría de fuente. Sirven para
/// colorea dots/badges/datos donde ya existe contexto de tema o para PDFs
/// con tema fijo claro. Para tinta con tema oscuro usa VeColors.of(context).

/// Tinta firma por divisa (§8): VES azul · USD rojo · EUR violeta ·
/// COP oliva · BRL verde · MXN magenta.
Color currencyInk(Currency c) => switch (c) {
      Currency.ves => Color(0xFF2563EB),
      Currency.usd => Color(0xFFCF4437),
      Currency.eur => Color(0xFF6E5BB8),
      Currency.cop => Color(0xFF5D6B13),
      Currency.brl => Color(0xFF12873C),
      Currency.mxn => Color(0xFFB03D90),
    };

/// Tinta por categoría de fuente de tasa (código string del enum
/// SourceCategory: 'official' | 'mixed' | 'parallel' | 'manual').
/// Tolerante: código desconocido → neutro (mutedFg claro).
Color categoryInk(String sourceCategory) => switch (sourceCategory) {
      'official' => VeColors.posLight,
      'mixed' => VeColors.warnLight,
      'parallel' => VeColors.negLight,
      'manual' => VeColors.manualLight,
      _ => VeColors.mutedFgLight,
    };

/// Marca de la app: tile azul-noche con la «V» blanca en SpaceGrotesk bold.
/// Tamaños fijados por §8 (header 24×24 radius 6).
class LogoMark extends StatelessWidget {
  const LogoMark({super.key, this.size = 24, this.radius = 6});

  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: const Color(0xFF22354E),
        borderRadius: BorderRadius.circular(radius),
      ),
      child: Text(
        'V',
        style: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: size * 0.58,
          fontWeight: FontWeight.w700,
          color: Colors.white,
          height: 1.0,
        ),
      ),
    );
  }
}

/// Copia al portapapeles con toast unificado (v17.5).
void copiarAlPortapapeles(BuildContext context, String text, String aviso) {
  Clipboard.setData(ClipboardData(text: text));
  showToast(context, aviso, kind: ToastKind.ok);
}

/// Tipos del aviso unificado (v17.5 · sugerencia del modelo de apoyo:
/// «banners/snackbars unificados»): un solo lenguaje de feedback efímero
/// para TODA la app — cero SnackBars crudos sueltos con estilos distintos.
enum ToastKind { info, ok, warn, error }

/// Aviso unificado «toast-papel»: flotante, esquina 12, superficie de tinta
/// invertida, icono semántico por tipo y acción opcional. Siempre reemplaza
/// al aviso anterior (hideCurrentSnackBar) para no encolar ruido.
void showToast(
  BuildContext context,
  String msg, {
  ToastKind kind = ToastKind.info,
  String? actionLabel,
  VoidCallback? onAction,
}) {
  // El toast vive sobre superficie INVERTIDA (fg): en claro es tinta oscura
  // → usamos las semánticas dark; en grafito es superficie clara → claras.
  final bool inv = Theme.of(context).brightness == Brightness.light;
  final VeInk sem = inv ? const VeInk.dark() : const VeInk.light();
  final Color infoInk = inv ? VeColors.primaryDark : VeColors.primaryLight;
  final (IconData icon, Color ink) = switch (kind) {
    ToastKind.info => (Icons.info_outline_rounded, infoInk),
    ToastKind.ok => (Icons.check_circle_outline, sem.pos),
    ToastKind.warn => (Icons.warning_amber_rounded, sem.warn),
    ToastKind.error => (Icons.error_outline, sem.neg),
  };
  final Color toastBg = inv ? VeColors.fgDark : VeColors.fgLight;
  final Color toastFg = inv ? VeColors.fgLight : VeColors.fgDark;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(
      behavior: SnackBarBehavior.floating,
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      elevation: 0,
      backgroundColor: toastBg,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      content: Row(children: [
        Icon(icon, size: 17, color: ink),
        const SizedBox(width: 9),
        Expanded(
          child: Text(msg,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                  color: toastFg)),
        ),
        // Acción integrada (SnackBarAction no permite tinta propia en este
        // Flutter): TextButton con la tinta de info sobre el fondo invertido.
        if (actionLabel != null && onAction != null)
          TextButton(
            onPressed: onAction,
            style: TextButton.styleFrom(
              foregroundColor: infoInk,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              minimumSize: Size.zero,
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            child: Text(actionLabel),
          ),
      ]),
    ));
}

/// Etiqueta de divisa (v17.5 · sugerencia «USD vs Bs indistinguibles»):
/// píldora caps con tinta por divisa — USD con tinta primaria (protagonista),
/// Bs neutra, el resto con la semántica VeInk (COP oliva · BRL verde ·
/// MXN magenta · EUR violeta). El color NUNCA dice oficial/paralelo (eso es
/// de datos); solo identifica la divisa junto a la cifra.
class CurrencyTag extends StatelessWidget {
  const CurrencyTag(this.code, {super.key});

  final String code;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final VeInk sem = VeColors.of(context);
    final String c = code.toUpperCase();
    final (Color ink, String label) = switch (c) {
      'USD' => (scheme.primary, 'USD'),
      'VES' => (scheme.onSurfaceVariant, 'Bs'),
      'COP' => (sem.cop, 'COP'),
      'BRL' => (sem.brl, 'BRL'),
      'MXN' => (sem.mxn, 'MXN'),
      'EUR' => (sem.manual, 'EUR'),
      _ => (scheme.onSurfaceVariant, c),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2.5),
      decoration: BoxDecoration(
        color: ink.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: ink.withValues(alpha: 0.32)),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.6,
              color: ink)),
    );
  }
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

// ═══════════════════════════════════════════════════════════════════════════
// dp6 · Componentes adoptados del motor v17 «Consolidación nativa» (GUI dp6,
// decisión del dueño: el actual manda, se integra lo que faltaba). Adaptados
// a los tokens de ESTA rama (VeText/VeColors/SourceSeal) — sin segundas
// bibliotecas. Botones (Primary/Ghost), Sparkline, MiniRateCard, SectionCard,
// SheetHeader, Paginator, Settle y CategoryLegend.
// ═══════════════════════════════════════════════════════════════════════════

/// Botón primario de la casa: lleno, radio 12, feedback táctil TapScale.
/// Unifica el FilledButton crudo que quedaba suelto en las pantallas.
class PrimaryButton extends StatelessWidget {
  const PrimaryButton(this.text, {super.key, this.onPressed, this.icon});

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.icon(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: scheme.primary,
          foregroundColor: scheme.onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
        icon: icon != null ? Icon(icon, size: 18) : null,
        label: Text(text),
    );
  }
}

/// Botón fantasma con borde: acción secundaria visible, sin competir con el
/// primario. [ink] tiñe texto y borde (para acciones destructivas/alerta).
class GhostButton extends StatelessWidget {
  const GhostButton(this.text, {super.key, this.onPressed, this.icon, this.ink});

  final String text;
  final VoidCallback? onPressed;
  final IconData? icon;
  final Color? ink;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return OutlinedButton.icon(
      onPressed: onPressed,
      style: OutlinedButton.styleFrom(
        foregroundColor: ink ?? scheme.onSurface,
        side: BorderSide(color: ink?.withValues(alpha: 0.35) ?? scheme.outline),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      icon: icon != null ? Icon(icon, size: 18) : null,
      label: Text(text),
    );
  }
}

/// Sparkline editorial: mini-tendencia teñida por dirección. Sube → neg (una
/// tasa que sube es devaluación), baja → pos; meta punteada si cae en rango.
/// Sin datos suficientes (menos de 2 puntos) no pinta nada — honesto.
class Sparkline extends StatelessWidget {
  const Sparkline({
    super.key,
    required this.values,
    this.height = 28,
    this.width = 84,
    this.target,
    this.up,
    this.down,
  });

  final List<double> values;
  final double height;
  final double? target;
  final double width;
  final Color? up;
  final Color? down;

  @override
  Widget build(BuildContext context) {
    if (values.length < 2) return SizedBox(height: height, width: width);
    final VeInk sem = VeColors.of(context);
    final bool rising = values.last >= values.first;
    final Color ink = rising ? (up ?? sem.neg) : (down ?? sem.pos);
    return SizedBox(
      width: width,
      height: height,
      child: CustomPaint(
        size: Size(width, height),
        painter: _SparklinePainter(
          values: values,
          ink: ink,
          target: target,
          targetInk: sem.warn,
        ),
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter({
    required this.values,
    required this.ink,
    required this.targetInk,
    this.target,
  });

  final List<double> values;
  final Color ink;
  final Color targetInk;
  final double? target;

  @override
  void paint(Canvas canvas, Size size) {
    double lo = values.reduce(math.min), hi = values.reduce(math.max);
    if (target != null) {
      lo = math.min(lo, target!);
      hi = math.max(hi, target!);
    }
    if (hi - lo < 1e-9) hi = lo + 1;
    Offset pt(int i) => Offset(
          size.width * i / (values.length - 1),
          size.height - 3 - (size.height - 6) * (values[i] - lo) / (hi - lo),
        );
    final path = Path()..moveTo(pt(0).dx, pt(0).dy);
    for (var i = 1; i < values.length; i++) {
      path.lineTo(pt(i).dx, pt(i).dy);
    }
    final paint = Paint()
      ..color = ink
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(path, paint);
    // Punto «hoy» al final de la serie.
    canvas.drawCircle(pt(values.length - 1), 2.2, Paint()..color = ink);
    if (target != null && target! >= lo && target! <= hi) {
      final y = size.height - 3 - (size.height - 6) * (target! - lo) / (hi - lo);
      final dash = Paint()
        ..color = targetInk
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1;
      var x = 0.0;
      while (x < size.width) {
        canvas.drawLine(Offset(x, y), Offset(math.min(x + 3, size.width), y), dash);
        x += 6;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values.length != values.length ||
      (values.length > 1 && old.values.last != values.last) ||
      old.target != target;
}

/// Tarjeta compacta de tasa (grid 2-col de «Divisas del foco»): bandera +
/// etiqueta arriba, cifra displayNum abajo, tinte por categoría de fuente.
class MiniRateCard extends StatelessWidget {
  const MiniRateCard({
    super.key,
    required this.label,
    required this.value,
    this.ink,
    this.leading,
    this.onTap,
  });

  final String label;
  final String value;
  final Color? ink;
  final Widget? leading;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outline.withValues(alpha: 0.8)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              if (leading != null) ...[leading!, const SizedBox(width: 5)],
              Flexible(
                child: Text(label,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              ),
            ]),
            const SizedBox(height: 4),
            Text(value, style: VeText.displayNum(18, color: ink ?? scheme.onSurface)),
          ],
        ),
      ),
    );
  }
}

/// Tarjeta de sección con rótulo técnico y acciones a la derecha: reemplaza
/// la pareja Card + SectionTitle manual cuando el bloque vive en un borde.
class SectionCard extends StatelessWidget {
  const SectionCard({
    super.key,
    this.title,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.actions = const [],
  });

  final String? title;
  final EdgeInsets padding;
  final Widget child;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: scheme.outline.withValues(alpha: 0.8)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (title != null || actions.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                if (title != null)
                  Expanded(
                    child: Text(title!,
                        style: VeText.labelCaps(10.5, color: scheme.primary)),
                  ),
                ...actions,
              ]),
            ),
          child,
        ],
      ),
    );
  }
}

/// Encabezado estándar de bottom sheet (título SpaceGrotesk + cerrar).
class SheetHeader extends StatelessWidget {
  const SheetHeader(this.title, {super.key});

  final String title;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 12, 8),
      child: Row(children: [
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 17,
                fontWeight: FontWeight.w700),
          ),
        ),
        IconButton(
          tooltip: 'Cerrar',
          onPressed: () => Navigator.of(context).pop(),
          icon: Icon(Icons.close_rounded, color: scheme.onSurfaceVariant),
        ),
      ]),
    );
  }
}

/// Paginador accesible (Anterior · «Página X de Y» liveRegion · Siguiente).
/// Se oculta solo si hay una página o menos.
class Paginator extends StatelessWidget {
  const Paginator({
    super.key,
    required this.page,
    required this.totalPages,
    required this.onPage,
  });

  final int page; // 1-based
  final int totalPages;
  final ValueChanged<int> onPage;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (totalPages <= 1) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        IconButton(
          tooltip: 'Página anterior',
          onPressed: page > 1 ? () => onPage(page - 1) : null,
          icon: const Icon(Icons.chevron_left_rounded),
          style: IconButton.styleFrom(foregroundColor: scheme.primary),
        ),
        Semantics(
          liveRegion: true,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerHighest.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              'Página $page de $totalPages',
              style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        IconButton(
          tooltip: 'Página siguiente',
          onPressed: page < totalPages ? () => onPage(page + 1) : null,
          icon: const Icon(Icons.chevron_right_rounded),
          style: IconButton.styleFrom(foregroundColor: scheme.primary),
        ),
      ]),
    );
  }
}

/// Cifra que «se asienta»: 4 px de subida + fade 220 ms al montar. Para el
/// momento en que el número clave aparece ya resuelto (sin odómetro largo).
class Settle extends StatefulWidget {
  const Settle({super.key, required this.child});

  final Widget child;

  @override
  State<Settle> createState() => _SettleState();
}

class _SettleState extends State<Settle> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 220));

  @override
  void initState() {
    super.initState();
    _c.forward();
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
        animation: _c,
        builder: (context, child) => Transform.translate(
          offset: Offset(0, 4 * (1 - Curves.easeOutCubic.transform(_c.value))),
          child: Opacity(opacity: _c.value, child: child),
        ),
        child: widget.child,
      );
}

/// Leyenda de categorías de tasa con el SourceSeal de la casa (v19.0:
/// icono + palabra). Usada en Bienvenida y Ajustes para explicar de un
/// vistazo qué significa cada sello del libro.
class CategoryLegend extends StatelessWidget {
  const CategoryLegend({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    const rows = <(SourceCategory, String, String)>[
      (
        SourceCategory.official,
        'Oficial',
        'BCV · TRM · Banxico · Real · EUR oficial'
      ),
      (SourceCategory.mixed, 'Promedio', 'Entre oficial y mercado'),
      (SourceCategory.parallel, 'Mercado', 'Paralelo VES · COP · EUR'),
      (SourceCategory.manual, 'Manual', 'Tu propia tasa'),
    ];
    return Column(
      children: [
        for (final (cat, label, detail) in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 5),
            child: Row(children: [
              SourceSeal(cat),
              const SizedBox(width: 8),
              Text(label,
                  style: const TextStyle(
                      fontSize: 12, fontWeight: FontWeight.w700)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(detail,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant)),
              ),
            ]),
          ),
      ],
    );
  }
}
