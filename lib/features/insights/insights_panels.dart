/// ─── Análisis · paneles (v19.8 · rediseño web-first) ────────────────────────
/// Segunda mitad del tablero de Análisis (v30): Canasta · Gastos +
/// `CurrencyRanking` (emigró a Gastos — es analítica de gastos) + los
/// widgets COMPARTIDOS (KpiTile, PanelCard, InlineHint, TipBox,
/// HeatmapCalendar). Estados vacíos compactos y honestos (nunca pantallas
/// rotas). H-40: Productos · Tasa · WeekdayRanking retirados.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'insights_utils.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorave/providers/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

// ─────────────────────────── Widgets compartidos ───────────────────────────

/// Tile compacto de KPI: etiqueta caps + número grande + sub. La fila de
/// web dashboards: 2-3 datos que resumen el panel de arriba.
class KpiTile extends ConsumerWidget {
  const KpiTile({
    super.key,
    required this.label,
    required this.value,
    this.sub,
    this.color,
    this.icon,
  });

  final String label;
  final String value;
  final String? sub;
  final Color? color;
  final IconData? icon;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurface;
    // v25 «HOJA»: KPI PLANO — eyebrow + cifra display, sin tarjeta.
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              if (icon != null) ...[
                // v25 «HOJA»: el icono va PELADO en tono de dato — sin
                // chip tintado ni borde (el color ya dice la categoría).
                Icon(icon, size: 14, color: c),
                const SizedBox(width: 6),
              ],
              Expanded(
                child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
                  label,
                  // 9P·Pantalla: 2 líneas — «Brecha BCV ↔ Paralelo» ya no
                  // se corta con «…» en la columna de 3 KPIs del móvil.
                  maxLines: 2,
                  style: VeText.labelCaps(11, color: scheme.onSurfaceVariant),
                )),
              ),
            ],
          ),
          if (icon != null)
            const SizedBox(height: 8)
          else
            const SizedBox(height: 0),
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              value,
              maxLines: 1,
              style: VeText.displayNum(17, color: c),
            ),
          ),
          if (sub != null) ...[
            const SizedBox(height: 4),
            FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
              sub!,
              maxLines: 2,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                height: 1.35,
                color: scheme.onSurfaceVariant,
              ),
            )),
          ],
        ],
      ),
    );
  }
}

/// Fila de 2-3 KPIs con el mismo alto (como los stat-rows de la web).
class KpiRow extends ConsumerWidget {
  const KpiRow({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < tiles.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            Expanded(child: tiles[i]),
          ],
        ],
      ),
    );
  }
}

/// Tarjeta-panel con cabecera consistente: título + acción a la derecha
/// (el patrón de TODA tarjeta del dashboard — nada de títulos flotando).
class PanelCard extends ConsumerWidget {
  const PanelCard({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
    this.trailing,
    this.child,
    this.padding = const EdgeInsets.all(14),
  });

  final String title;
  final String? subtitle;
  final Widget? action;
  final Widget? trailing;
  final Widget? child;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    // v25 «HOJA»: panel PLANO — cabecera eyebrow + acción derecha y el
    // contenido sobre el papel, sin tarjeta (la separación entre secciones
    // la pone el aire, 28-36 px).
    return Padding(
      padding: padding,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title.toUpperCase(),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.84,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              // ignore: use_null_aware_elements
              if (action != null) action!,
              // ignore: use_null_aware_elements
              if (trailing != null) trailing!,
            ],
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                height: 1.35,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (child != null) ...[const SizedBox(height: 10), child!],
        ],
      ),
    );
  }
}

/// Pista compacta para estados vacíos y mensajes honestos: una línea con
/// ícono, no una tarjeta gigante que parece error.
class InlineHint extends ConsumerWidget {
  const InlineHint(
    this.text, {
    super.key,
    this.icon,
    this.actionLabel,
    this.onAction,
  });

  final String text;
  final IconData? icon;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      // v25 «HOJA»: pista PLANA — icono + texto muted sobre el papel, sin
      // fill de fondo.
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            Icon(
              icon ?? Icons.info_outline,
              size: 14,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                text,
                style: TextStyle(
                  fontSize: 11,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
            if (actionLabel != null && onAction != null)
              Padding(
                padding: const EdgeInsets.only(left: 8),
                child: TextButton(
                  onPressed: onAction,
                  style: TextButton.styleFrom(
                    visualDensity: VisualDensity.compact,
                  ),
                  child: Text(
                    actionLabel!,
                    style: const TextStyle(fontSize: 13.5),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Burbuja de tooltip firma: valor en displayNum + fecha es-VE abreviada.
class TipBox extends ConsumerWidget {
  const TipBox({
    super.key,
    required this.main,
    required this.sub,
    required this.bg,
    required this.fg,
  });

  final String main;
  final String sub;
  final Color bg;
  final Color fg;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(main, style: VeText.displayNum(13.5, color: fg)),
          const SizedBox(height: 1),
          Text(
            sub,
            style: TextStyle(fontSize: 11, color: fg.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

/// Gasto por divisa (v30 · H-40/R-30e): lo pagado en CADA moneda (precio
/// original de los ítems) con su equivalente USD — el orden del ranking es
/// por USD (comparable). Emigró a Gastos (es analítica de gastos) y
/// respeta el RANGO de esa sección: recibe las compras `inRange`.
class CurrencyRanking extends ConsumerWidget {
  const CurrencyRanking({super.key, required this.purchases});
  final List<Purchase> purchases;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final rows = currencySpend(purchases);
    if (rows.isEmpty) return const SizedBox.shrink();
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                SizedBox(
                  width: 44,
                  child: Text(
                    r.currency,
                    style: VeText.displayNum(13.5, color: scheme.onSurface),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${fmtMoney(r.totalOriginal, CurrencyX.from(r.currency))} · '
                    '${r.items} ítem${r.items == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 13.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '≈ ${fmtUSD(r.totalUSD)}',
                  style: VeText.displayNum(13.5, color: scheme.onSurface),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── Ancla 4: Canasta ─────────────────────────────────

/// Sección 3: canasta básica (CRUD) — vive aquí: la inflación personal de
/// la sección Inflación se calcula con ESTA canasta.
class CanastaAnchor extends ConsumerWidget {
  const CanastaAnchor({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final cost = basketCostSeries(store.basket, store.products, days: 365);
    final lastCost = cost.isEmpty ? null : cost.last;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (lastCost != null)
          KpiRow(
            tiles: [
              KpiTile(
                label: 'Costo de la canasta',
                value: fmtUSD(lastCost.cost),
                sub: '${lastCost.items} productos · hoy',
                icon: Icons.shopping_basket_outlined,
              ),
              KpiTile(
                label: 'Productos vigilados',
                value: '${store.basket.length}',
                sub: 'con precio mensual',
                icon: Icons.inventory_2_outlined,
              ),
            ],
          ),
        const SizedBox(height: 10),
        if (store.basket.isEmpty)
          VeEmpty(
            icon: LucideIcons.shoppingBasket,
            title: 'Canasta vacía',
            sub:
                'Agrega desde tus productos: sigue su precio mensual y Análisis medirá '
                'la variación del costo de la canasta completa.',
            action: VeBtn(
              size: VeBtnSize.sm,
              variant: VeBtnVariant.secondary,
              onPressed: () => context.go('/productos'),
              child: const Text('Ir a productos'),
            ),
          )
        else
          PanelCard(
            title: 'Tu canasta',
            subtitle:
                'Los productos que vigilas cada mes — tu inflación personal '
                'se calcula con ellos.',
            child: Column(
              children: [
                for (final b in store.basket)
                  Builder(
                    builder: (ctx) {
                      final p = store.products
                          .where((p) => p.id == b.productId)
                          .firstOrNull;
                      final last = p?.latestRecord;
                      return ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        leading: CategoryIcon(cat: p?.category, size: 30),
                        title: Text(
                          p?.name ?? 'Producto eliminado',
                          style: const TextStyle(fontSize: 13.5),
                        ),
                        subtitle: Text(
                          last == null ? 'Sin precio' : fmtUSD(last.price),
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _QtyStepper(
                              qty: b.quantity,
                              onChanged: (d) => store.updateBasketItem(
                                b.productId,
                                (b.quantity + d).clamp(1, 99),
                              ),
                              onRemove: () =>
                                  store.removeFromBasket(b.productId),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
              ],
            ),
          ),
        // Agregar a canasta desde catálogo.
        const VeEyebrow(child: Text('AGREGAR A LA CANASTA')),
        Wrap(
          spacing: 6,
          children: [
            for (final p in store.products.take(8))
              if (!store.basket.any((b) => b.productId == p.id))
                ChipTag(p.name, onTap: () => store.addToBasket(p.id, 1)),
          ],
        ),
      ],
    );
  }
}

/// Stepper compacto −/n/+ con quitar por long-press en −.
class _QtyStepper extends ConsumerWidget {
  const _QtyStepper({
    required this.qty,
    required this.onChanged,
    required this.onRemove,
  });

  final int qty;
  final ValueChanged<int> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _miniBtn(
          icon: Icons.remove,
          onTap: () => onChanged(-1),
          onLongPress: onRemove,
          color: scheme.onSurfaceVariant,
        ),
        SizedBox(
          width: 26,
          child: Text(
            '$qty',
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700),
          ),
        ),
        _miniBtn(icon: Icons.add, onTap: () => onChanged(1)),
      ],
    );
  }

  Widget _miniBtn({
    required IconData icon,
    required VoidCallback onTap,
    VoidCallback? onLongPress,
    Color? color,
  }) {
    return SizedBox(
      // v23.3 (pez 2-a P1-1): pista 36×36 — igual que VeStepper: filas
      // densas de la Canasta, AA holgado sin engordar la fila.
      width: 36,
      height: 36,
      child: IconButton(
        padding: EdgeInsets.zero,
        visualDensity: VisualDensity.compact,
        iconSize: 16,
        color: color,
        icon: Icon(icon),
        onPressed: onTap,
        onLongPress: onLongPress,
      ),
    );
  }
}

// ───────────────────────── Ancla 5: Gastos ─────────────────────────────────

/// Sección 4 (v17.8): GASTOS de las compras de Lista — vista resumida que
/// reemplaza los gráficos del módulo Finanzas. Se alimenta AUTOMÁTICA de
/// las compras guardadas (cero carga manual, cero duplicar datos): total
/// del rango + donut por tienda + barras por mes + compras por divisa
/// (v30 · H-40/R-30e: `CurrencyRanking` emigró aquí y usa el MISMO
/// `inRange` de la sección), con la cobertura real de datos siempre a la
/// vista (§ honesto).
class GastosAnchor extends ConsumerWidget {
  const GastosAnchor({super.key, required this.days});
  final int days;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    final now = DateTime.now();
    final from = now.subtract(Duration(days: days));
    final inRange =
        store.purchases.where((p) => !p.date.isBefore(from)).toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    final total = inRange.fold<double>(0, (a, p) => a + p.paidUSD);
    final byStore = storeSpend(inRange);
    final byMonth = monthSpend(
      store.purchases,
      months: days >= 365 ? 12 : (days >= 183 ? 12 : 6),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (inRange.isEmpty)
          VeEmpty(
            icon: LucideIcons.receiptText,
            title: 'Sin compras en el rango',
            sub:
                'Finaliza una compra en Lista (botón «Finalizar compra») y '
                'este resumen se llena solo: total, tiendas y meses.',
          )
        else ...[
          KpiRow(
            tiles: [
              KpiTile(
                label: rangeName(days) == 'Máximo'
                    ? 'Gastado · todo el historial'
                    : 'Gastado · ${rangeName(days)}',
                value: fmtUSD(total),
                sub:
                    '${inRange.length} ${inRange.length == 1 ? 'compra' : 'compras'} · '
                    '${byStore.where((s) => s.store != 'Otras' && s.store != 'Sin tienda').length} tiendas',
                icon: Icons.payments_outlined,
                color: sem.neg,
              ),
            ],
          ),
          // Donut por tienda (top 6 + Otras).
          if (byStore.length > 1) ...[
            const VeEyebrow(child: Text('POR TIENDA')),
            // v20.4: VeDonut (CustomPainter propio, leyenda integrada) en
            // lugar de SfCircularChart.
            PanelCard(
              title: 'Distribución por tienda',
              child: Center(
                child: VeDonut(
                  labels: [for (final e in byStore) e.store],
                  data: [for (final e in byStore) e.totalUSD],
                  size: 210,
                  formatValue: (v) => fmtUSD(v),
                  semantic: 'Gasto por tienda',
                ),
              ),
            ),
          ] else ...[
            const VeEyebrow(child: Text('POR TIENDA')),
            PanelCard(
              title: 'Distribución por tienda',
              child: ListTile(
                dense: true,
                visualDensity: VisualDensity.compact,
                contentPadding: EdgeInsets.zero,
                leading: Icon(Icons.storefront_outlined, color: scheme.primary),
                title: Text(
                  byStore.first.store,
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                trailing: Text(
                  fmtUSD(byStore.first.totalUSD),
                  style: VeText.displayNum(13.5, color: sem.neg),
                ),
              ),
            ),
          ],
          // Barras por mes (ventana 6 o 12 meses según el rango).
          if (byMonth.length > 1) ...[
            const VeEyebrow(child: Text('GASTO POR MES')),
            PanelCard(
              title: 'Gasto por mes',
              // v20.4: VeBars (CustomPainter propio) en lugar de syncfusion.
              child: VeBars(
                labels: [for (final e in byMonth) e.month],
                data: [for (final e in byMonth) e.totalUSD],
                tone: VeChartTone.neg,
                height: 200,
                formatValue: (v) => fmtUSD(v),
                semantic: 'Gasto por mes',
              ),
            ),
          ],
          // ── Compras por divisa (v30 · H-40): `CurrencyRanking` emigró de
          // Productos a Gastos — es analítica de gastos. R-30e: usa el
          // MISMO `inRange` de la sección (antes cuadraba con TODO el
          // historial y no con el rango elegido).
          const VeEyebrow(child: Text('COMPRAS POR DIVISA')),
          PanelCard(
            title: 'Compras por divisa',
            subtitle: 'Lo pagado en cada moneda en ${rangeName(days)}',
            child: CurrencyRanking(purchases: inRange),
          ),
        ],
      ],
    );
  }
}

// ─────────────────── Calendario de devaluación ─────────────────────────────

/// Calendario pictórico de devaluación (§9.7 · el heatmap 6 m del web —
/// cierra la desviación D2): un cuadro por día, rojo=subida de la tasa
/// (devaluación), verde=baja, intensidad = magnitud vs el día anterior con
/// datos. Solo meses con datos (nunca media pantalla de cuadros vacíos).
/// Encima del grid: día con mayor subida del período.
class HeatmapCalendar extends ConsumerWidget {
  const HeatmapCalendar({super.key, required this.data});

  /// % diario (vs día anterior con datos) por 'YYYY-MM-DD'.
  final List<({String day, double pct})> data;

  static const int _kMonths = 6;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);
    final byDay = {for (final e in data) e.day: e.pct};
    final maxAbs = data.fold<double>(
      0,
      (m, e) => e.pct.abs() > m ? e.pct.abs() : m,
    );
    final worst = data.isEmpty
        ? null
        : (data.reduce((a, b) => a.pct >= b.pct ? a : b));

    // Sin datos: NI se dibuja el calendario — una línea honesta.
    if (data.isEmpty) {
      return const SizedBox.shrink();
    }

    // Meses CON datos (de los últimos 6), del más viejo al más reciente.
    final now = DateTime.now();
    final monthsWithData = <DateTime>{
      for (final e in data) DateTime.parse(e.day),
    }.map((d) => DateTime(d.year, d.month, 1)).toSet().toList()..sort();
    final months = monthsWithData
        .where((m) => !m.isBefore(DateTime(now.year, now.month - _kMonths + 1)))
        .toList();
    if (months.isEmpty) {
      return const SizedBox.shrink();
    }

    return PanelCard(
      title: 'Calendario de devaluación',
      subtitle: worst == null
          ? null
          : 'Cuadro por día (BCV vs el día anterior con datos). '
                'Día con mayor subida: ${fmtDayLabel(DateTime.parse(worst.day))} '
                '(${fmtPct(worst.pct)}).',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final m in months)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${fmtMesCorto(m.month).toUpperCase()} ${m.year}',
                    style: VeText.labelCaps(11, color: scheme.primary),
                  ),
                  const SizedBox(height: 6),
                  _monthGrid(context, m, byDay, maxAbs, ink),
                ],
              ),
            ),
          // Leyenda: el color SOLO significa dirección del movimiento.
          // Wrap: la fila suma ~301 px fijos y desbordaba en <=330 dp
          // y a textScale >=1.1 (fix overflow) — envuelve por pares.
          Wrap(
            spacing: 4,
            runSpacing: 4,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              _legendBox(context, ink.pos.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                'baja',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              _legendBox(context, scheme.surfaceContainerHighest),
              const SizedBox(width: 4),
              Text(
                'sin datos',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              _legendBox(context, ink.neg.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                'subida · más intenso = mayor cambio',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendBox(BuildContext context, Color c) => Container(
    width: 11,
    height: 11,
    // v25 «HOJA»: swatch de leyenda SIN borde — el color de dato es la
    // marca, no una caja de UI.
    decoration: BoxDecoration(color: c, borderRadius: BorderRadius.circular(3)),
  );

  /// Grid de un mes: cuadros cuadrados en 7 columnas (L→D), con blancos de
  /// encuadre al inicio. GridView sin scroll con altura exacta.
  Widget _monthGrid(
    BuildContext context,
    DateTime month,
    Map<String, double> byDay,
    double maxAbs,
    VeInk ink,
  ) {
    final scheme = Theme.of(context).colorScheme;
    final leading = DateTime(month.year, month.month, 1).weekday - 1;
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    return LayoutBuilder(
      builder: (ctx, cons) {
        const gap = 3.0;
        final cell = (cons.maxWidth - 6 * gap) / 7;
        final rows = ((leading + daysInMonth) / 7).ceil();
        return SizedBox(
          height: rows * cell + (rows - 1) * gap,
          child: GridView.count(
            crossAxisCount: 7,
            mainAxisSpacing: gap,
            crossAxisSpacing: gap,
            childAspectRatio: 1,
            physics: const NeverScrollableScrollPhysics(),
            padding: EdgeInsets.zero,
            children: [
              for (var i = 0; i < leading; i++) const SizedBox.shrink(),
              for (var d = 1; d <= daysInMonth; d++)
                _cell(
                  context,
                  DateTime(month.year, month.month, d),
                  byDay,
                  maxAbs,
                  ink,
                  scheme,
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _cell(
    BuildContext context,
    DateTime day,
    Map<String, double> byDay,
    double maxAbs,
    VeInk ink,
    ColorScheme scheme,
  ) {
    final pct = byDay[SnapshotPoint.dayKey(day)];
    Color fill = scheme.surfaceContainerHighest;
    if (pct != null && maxAbs > 0) {
      final t = (pct.abs() / maxAbs).clamp(0.18, 0.85);
      fill = pct > 0
          ? ink.neg.withValues(alpha: t)
          : (pct < 0
                ? ink.pos.withValues(alpha: t)
                : scheme.surfaceContainerHighest);
    }
    final label = pct == null
        ? '${day.day} ${fmtMesCorto(day.month)} sin datos'
        : '${day.day} ${fmtMesCorto(day.month)}: ${fmtPct(pct)}';
    return Semantics(
      label: label,
      // v25 «HOJA»: celda del heatmap SIN borde — el fill ES el dato
      // (intensidad del día), no una caja de UI.
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(3),
        ),
      ),
    );
  }
}
