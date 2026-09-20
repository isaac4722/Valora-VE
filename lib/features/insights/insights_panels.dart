/// ─── Análisis · paneles (v19.8 · rediseño web-first) ────────────────────────
/// Segunda mitad del tablero de Análisis: Productos · Canasta · Gastos ·
/// Tasa + los widgets COMPARTIDOS del rediseño (KpiTile, PanelCard,
/// InlineHint, TipBox, HeatmapCalendar). Pensado como un dashboard web:
/// fila de KPIs arriba, tarjetas-panel con cabecera y acción a la derecha,
/// estados vacíos compactos y honestos (nunca pantallas rotas).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/analytics.dart' as an;
import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/rate_history.dart';
import '../../data/store.dart';
import '../../services/sharing.dart';
import '../../widgets/ui.dart';
import 'insights_utils.dart';

// ─────────────────────────── Widgets compartidos ───────────────────────────

/// Tile compacto de KPI: etiqueta caps + número grande + sub. La fila de
/// web dashboards: 2-3 datos que resumen el panel de arriba.
class KpiTile extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = color ?? scheme.onSurface;
    return Card(
      child: Padding(
        // 9P·Pulido: aire interno 12/12 (antes 11 vertical — los KPIs se
        // veían apretados contra el borde de la tarjeta en la auditoría
        // visual de la web).
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, size: 12, color: c.withValues(alpha: 0.85)),
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child: Text(
                    label,
                    // 9P·Pantalla: 2 líneas — «Brecha BCV ↔ Paralelo» ya no
                    // se corta con «…» en la columna de 3 KPIs del móvil.
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: VeText.labelCaps(
                      9.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 7),
            FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                value,
                maxLines: 1,
                style: VeText.displayNum(19, color: c),
              ),
            ),
            if (sub != null) ...[
              const SizedBox(height: 4),
              Text(
                sub!,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 10.5,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Fila de 2-3 KPIs con el mismo alto (como los stat-rows de la web).
class KpiRow extends StatelessWidget {
  const KpiRow({super.key, required this.tiles});

  final List<Widget> tiles;

  @override
  Widget build(BuildContext context) {
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
class PanelCard extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: padding,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: VeText.labelCaps(10.5, color: scheme.primary),
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
                  fontSize: 11,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
            if (child != null) ...[const SizedBox(height: 10), child!],
          ],
        ),
      ),
    );
  }
}

/// Pista compacta para estados vacíos y mensajes honestos: una línea con
/// ícono, no una tarjeta gigante que parece error.
class InlineHint extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(12),
        ),
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
                  fontSize: 11.5,
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
                    style: const TextStyle(fontSize: 12),
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
class TipBox extends StatelessWidget {
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
  Widget build(BuildContext context) {
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
          Text(main, style: VeText.displayNum(12, color: fg)),
          const SizedBox(height: 1),
          Text(
            sub,
            style: TextStyle(fontSize: 9.5, color: fg.withValues(alpha: 0.85)),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────── Ancla 3: Productos ───────────────────────────────

/// Ancla 3: rankings de productos (en el rango) y tiendas.
class ProductosAnchor extends StatelessWidget {
  const ProductosAnchor({super.key, required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final measured = <(Product, double)>[];
    for (final p in store.products) {
      final v = variationInRange(p, days);
      if (v != null) measured.add((p, v));
    }
    final up = [...measured.where((e) => e.$2 > 0)]
      ..sort((a, b) => b.$2.compareTo(a.$2));
    final down = [...measured.where((e) => e.$2 < 0)]
      ..sort((a, b) => a.$2.compareTo(b.$2));
    final storeStats = an.storeStats(store.purchases).take(5).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (up.isEmpty && down.isEmpty)
          InlineHint(
            'Sin subidas ni bajadas registradas dentro del rango elegido: '
            'registra precios en Productos y los rankings aparecen aquí.',
            icon: Icons.trending_flat,
          )
        else ...[
          PanelCard(
            title: 'Mayores subidas',
            subtitle: '${up.length} productos al alza en ${rangeName(days)}',
            child: up.isEmpty
                ? const Text('Ninguna subida en el rango.')
                : Column(
                    children: [
                      for (final e in up.take(5))
                        ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            e.$1.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: TrendBadge(e.$2, dense: true),
                        ),
                    ],
                  ),
          ),
          const SizedBox(height: 10),
          PanelCard(
            title: 'Mayores bajadas',
            subtitle:
                '${down.length} productos a la baja en ${rangeName(days)}',
            child: down.isEmpty
                ? const Text('Ninguna bajada en el rango.')
                : Column(
                    children: [
                      for (final e in down.take(5))
                        ListTile(
                          dense: true,
                          visualDensity: VisualDensity.compact,
                          contentPadding: EdgeInsets.zero,
                          title: Text(
                            e.$1.name,
                            style: const TextStyle(fontSize: 13),
                          ),
                          trailing: TrendBadge(e.$2, dense: true),
                        ),
                    ],
                  ),
          ),
        ],
        const SizedBox(height: 10),
        PanelCard(
          title: 'Gasto por tienda',
          subtitle: storeStats.isEmpty
              ? 'Sin compras guardadas todavía'
              : 'Top ${storeStats.length} por total USD',
          child: storeStats.isEmpty
              ? const SizedBox.shrink()
              : Column(
                  children: [
                    for (final s in storeStats)
                      ListTile(
                        dense: true,
                        visualDensity: VisualDensity.compact,
                        contentPadding: EdgeInsets.zero,
                        leading: StoreAvatar(
                          s.store.isEmpty ? 'Sin Tienda' : s.store,
                          size: 30,
                        ),
                        title: Text(
                          s.store.isEmpty ? 'Sin tienda' : s.store,
                          style: const TextStyle(fontSize: 13),
                        ),
                        subtitle: Text(
                          '${s.count} compras',
                          style: const TextStyle(fontSize: 11),
                        ),
                        trailing: Text(
                          fmtUSD(s.totalUSD),
                          style: VeText.displayNum(13, color: scheme.onSurface),
                        ),
                      ),
                  ],
                ),
        ),
        // ── Rankings de compras (§9.7): por día de semana y por moneda ──
        if (store.purchases.isNotEmpty) ...[
          const SizedBox(height: 10),
          PanelCard(
            title: 'Compras por día de la semana',
            child: WeekdayRanking(purchases: store.purchases),
          ),
          const SizedBox(height: 10),
          PanelCard(
            title: 'Compras por divisa',
            child: CurrencyRanking(purchases: store.purchases),
          ),
        ],
      ],
    );
  }
}

/// Distribución del gasto por día de la semana (Lun→Dom) con el día fuerte
/// señalado — el «ranking» honesto: total USD efectivo + nº de compras.
class WeekdayRanking extends StatelessWidget {
  const WeekdayRanking({super.key, required this.purchases});
  final List<Purchase> purchases;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rows = weekdaySpend(purchases);
    final maxTotal = rows.fold<double>(
      0,
      (m, e) => e.totalUSD > m ? e.totalUSD : m,
    );
    return Column(
      children: [
        for (final r in rows)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 3),
            child: Row(
              children: [
                SizedBox(
                  width: 34,
                  child: Text(
                    r.day,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: r.totalUSD == maxTotal && maxTotal > 0
                          ? FontWeight.w800
                          : FontWeight.w500,
                      color: scheme.onSurface,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(3),
                    child: LinearProgressIndicator(
                      value: maxTotal > 0 ? r.totalUSD / maxTotal : 0,
                      minHeight: 6,
                      backgroundColor: scheme.surfaceContainerHighest,
                      color: scheme.primary,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                // FittedBox: a textScale >=1.3 «$ 1.234,56» (≈91 px)
                // envolvía en 2 líneas dentro del box fijo de 74 px y
                // descuadraba la fila del ranking (fix a11y).
                SizedBox(
                  width: 74,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      r.totalUSD > 0 ? fmtUSD(r.totalUSD) : '—',
                      style: VeText.displayNum(11.5, color: scheme.onSurface),
                    ),
                  ),
                ),
                SizedBox(
                  width: 30,
                  child: Text(
                    '${r.count}',
                    textAlign: TextAlign.right,
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
    );
  }
}

/// Gasto por divisa: lo pagado en CADA moneda (precio original de los ítems)
/// con su equivalente USD — el orden del ranking es por USD (comparable).
class CurrencyRanking extends StatelessWidget {
  const CurrencyRanking({super.key, required this.purchases});
  final List<Purchase> purchases;

  @override
  Widget build(BuildContext context) {
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
                    style: VeText.displayNum(12, color: scheme.onSurface),
                  ),
                ),
                Expanded(
                  child: Text(
                    '${fmtMoney(r.totalOriginal, CurrencyX.from(r.currency))} · '
                    '${r.items} ítem${r.items == 1 ? '' : 's'}',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                Text(
                  '≈ ${fmtUSD(r.totalUSD)}',
                  style: VeText.displayNum(12, color: scheme.onSurface),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

// ───────────────────────── Ancla 4: Canasta ─────────────────────────────────

/// Ancla 4: canasta básica (CRUD) — vive aquí: la inflación personal del
/// ancla Inflación se calcula con ESTA canasta.
class CanastaAnchor extends StatelessWidget {
  const CanastaAnchor({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
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
          EmptyState(
            'Canasta vacía',
            icon: Icons.shopping_basket_outlined,
            hint:
                'Agrega desde tus productos: sigue su precio mensual y Análisis medirá '
                'la variación del costo de la canasta completa.',
            actionLabel: 'Ir a productos',
            onAction: () => context.go('/productos'),
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
        SectionTitle('Agregar a la canasta'),
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
class _QtyStepper extends StatelessWidget {
  const _QtyStepper({
    required this.qty,
    required this.onChanged,
    required this.onRemove,
  });

  final int qty;
  final ValueChanged<int> onChanged;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
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
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
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
      width: 30,
      height: 34,
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

/// Ancla 5 (v17.8): GASTOS de las compras de Lista — vista resumida que
/// reemplaza los gráficos del módulo Finanzas. Se alimenta AUTOMÁTICA de
/// las compras guardadas (cero carga manual, cero duplicar datos): total
/// del rango + donut por tienda + barras por mes, con la cobertura real
/// de datos siempre a la vista (§ honesto).
class GastosAnchor extends StatelessWidget {
  const GastosAnchor({super.key, required this.days});
  final int days;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
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
          EmptyState(
            'Sin compras en el rango',
            icon: Icons.payments_outlined,
            hint:
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
            SectionTitle('Por tienda'),
            PanelCard(
              title: 'Distribución por tienda',
              child: SizedBox(
                height: 210,
                child: SfCircularChart(
                  legend: const Legend(
                    isVisible: true,
                    position: LegendPosition.bottom,
                    textStyle: TextStyle(fontSize: 10),
                  ),
                  series: [
                    DoughnutSeries<
                      ({String store, double totalUSD, int count}),
                      String
                    >(
                      dataSource: byStore,
                      xValueMapper: (e, _) => e.store,
                      yValueMapper: (e, _) => e.totalUSD,
                      pointColorMapper: (e, i) => chartPalette(
                        context,
                      )[i % chartPalette(context).length],
                      radius: '70%',
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: false,
                      ),
                      enableTooltip: true,
                    ),
                  ],
                ),
              ),
            ),
          ] else ...[
            SectionTitle('Por tienda'),
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
            SectionTitle('Gasto por mes'),
            PanelCard(
              title: 'Gasto por mes',
              child: SizedBox(
                height: 200,
                child: SfCartesianChart(
                  primaryXAxis: const CategoryAxis(),
                  tooltipBehavior: TooltipBehavior(enable: true),
                  series: [
                    ColumnSeries<
                      ({String month, double totalUSD, int count}),
                      String
                    >(
                      dataSource: byMonth,
                      xValueMapper: (e, _) => e.month,
                      yValueMapper: (e, _) => e.totalUSD,
                      name: 'Gasto',
                      color: sem.neg,
                      dataLabelSettings: const DataLabelSettings(
                        isVisible: false,
                      ),
                      enableTooltip: true,
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ],
    );
  }
}

// ───────────────────────── Ancla 6: Tasa ───────────────────────────────────

/// Ancla 6: registros propios por fuente (selector MULTI-DIVISA: hasta 3
/// fuentes superpuestas) + gráfica interactiva + tabla + export por columnas.
class HistoricaAnchor extends StatefulWidget {
  const HistoricaAnchor({super.key, required this.days});
  final int days;

  @override
  State<HistoricaAnchor> createState() => _HistoricaAnchorState();
}

class _HistoricaAnchorState extends State<HistoricaAnchor> {
  /// Selección múltiple (historial multi-divisa, §9.7): hasta 3 fuentes.
  final Set<String> _selected = {};

  /// Fuentes CON snapshots locales (sin manuales ni USD: no tienen historial).
  List<String> _sources(AppStore store) {
    final ids = store.snapshots.map((s) => s.sourceId).toSet();
    return [
      for (final s in RateSource.all)
        if (ids.contains(s.id) &&
            s.currency != Currency.usd &&
            s.category != SourceCategory.manual)
          s.id,
    ];
  }

  void _toggle(String id, List<String> sources) {
    setState(() {
      if (_selected.contains(id)) {
        // Nunca queda vacío: la última fuente no se desmarca.
        if (_selected.length > 1) _selected.remove(id);
      } else {
        if (_selected.length >= 3) return; // tope legible de 3 series
        _selected.add(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);
    final sources = _sources(store);
    // Selección efectiva: la guardada (válida) o el default honesto.
    final selected = <String>[
      for (final id in _selected.where(sources.contains))
        if (sources.contains(id)) id,
    ];
    if (selected.isEmpty) {
      final def = sources.contains('ves-bcv')
          ? 'ves-bcv'
          : (sources.isNotEmpty ? sources.first : '');
      if (def.isNotEmpty) selected.add(def);
    }
    final multi = selected.length > 1;
    // Serie por fuente seleccionada.
    final seriesById = <String, List<SnapshotPoint>>{
      for (final id in selected)
        id: snapshotSeries(store.snapshots, id, widget.days),
    };
    final allSeries = seriesById.values.expand((s) => s).toList();
    final firstDay = allSeries.isEmpty
        ? null
        : DateTime.tryParse(
            (allSeries.map((p) => p.day).toList()..sort()).first,
          );
    final covPoints = allSeries.map((p) => p.day).toSet().length;
    // Paleta por índice (máx 3): las divisas se distinguen por curva.
    final palette = [scheme.primary, ink.neg, ink.warn];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (sources.isEmpty)
          EmptyState(
            'Sin historial local aún',
            icon: Icons.history,
            hint:
                'Cada día que la app consulta tasas guarda un punto por fuente (máx 180 días). '
                'Entra a Inicio y actualiza para empezar tu libro de tasas.',
            actionLabel: 'Ir a Inicio',
            onAction: () => context.go('/'),
          )
        else ...[
          PanelCard(
            title: 'Fuentes',
            subtitle: multi
                ? 'Hasta 3 superpuestas · toca para sumar o quitar'
                : 'Toca para sumar otra divisa a la gráfica',
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  for (final id in sources)
                    Padding(
                      padding: const EdgeInsets.only(right: 6),
                      child: ChipTag(
                        RateSource.of(id)?.label ?? id,
                        selected: selected.contains(id),
                        onTap: () => _toggle(id, sources),
                      ),
                    ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          if (allSeries.length >= 2)
            PanelCard(
              title: multi ? 'Tasas superpuestas' : 'Tasa en el rango',
              subtitle: coverageText(
                rangeLabel: rangeName(widget.days),
                requestedDays: widget.days,
                points: covPoints,
                first: firstDay,
                sinceSubject: null,
              ),
              child: SizedBox(
                height: 210,
                child: SfCartesianChart(
                  legend: Legend(
                    isVisible: multi,
                    position: LegendPosition.bottom,
                    textStyle: const TextStyle(fontSize: 10),
                  ),
                  primaryXAxis: DateTimeAxis(
                    dateFormat: DateFormat('dd/MM'),
                    majorGridLines: const MajorGridLines(width: 0),
                  ),
                  tooltipBehavior: TooltipBehavior(
                    enable: true,
                    activationMode: ActivationMode.singleTap,
                    builder:
                        (
                          dynamic s,
                          dynamic point,
                          dynamic series,
                          int i,
                          int si,
                        ) {
                          if (i < 0 || s is! List || i >= s.length) {
                            return const SizedBox.shrink();
                          }
                          final p = s[i] as SnapshotPoint;
                          return TipBox(
                            main: fmtRate(p.rate),
                            sub: fmtDayLabel(DateTime.parse(p.day)),
                            bg: scheme.primary,
                            fg: scheme.onPrimary,
                          );
                        },
                  ),
                  crosshairBehavior: CrosshairBehavior(
                    enable: true,
                    lineType: CrosshairLineType.vertical,
                    lineDashArray: const <double>[4, 3],
                    activationMode: ActivationMode.singleTap,
                  ),
                  series: [
                    for (var k = 0; k < selected.length; k++)
                      LineSeries<SnapshotPoint, DateTime>(
                        dataSource: seriesById[selected[k]]!,
                        xValueMapper: (p, _) => DateTime.parse(p.day),
                        yValueMapper: (p, _) => p.rate,
                        name: RateSource.of(selected[k])?.label ?? selected[k],
                        color: palette[k % palette.length],
                        width: 1.8,
                      ),
                  ],
                ),
              ),
            )
          else if (allSeries.length == 1)
            InlineHint(
              'Solo 1 punto con datos (${fmtDate(DateTime.parse(allSeries.first.day))}): '
              'se necesitan al menos 2 fechas para mostrar variación.',
              icon: Icons.hourglass_empty,
            )
          else
            InlineHint(
              'Aún no hay snapshots de las fuentes elegidas. Profundidad local total: '
              '${snapshotDepth(store.snapshots)} días (máx 180).',
              icon: Icons.hourglass_empty,
            ),
          if (allSeries.isNotEmpty) ...[
            const SizedBox(height: 10),
            PanelCard(
              title: 'Últimos días',
              subtitle: 'Hasta 10 fechas recientes con datos',
              child: Column(
                children: [
                  // Tabla por día: una columna por fuente (multi-divisa real).
                  for (final day
                      in (allSeries.map((p) => p.day).toSet().toList()..sort())
                          .reversed
                          .take(10))
                    ListTile(
                      dense: true,
                      visualDensity: VisualDensity.compact,
                      contentPadding: EdgeInsets.zero,
                      title: Text(
                        fmtDate(DateTime.parse(day)),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                      trailing: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            for (var k = 0; k < selected.length; k++)
                              Padding(
                                padding: EdgeInsets.only(left: k == 0 ? 0 : 10),
                                child: Text(
                                  _rateForDay(seriesById[selected[k]]!, day),
                                  style: VeText.displayNum(
                                    13,
                                    color: multi
                                        ? palette[k % palette.length]
                                        : scheme.onSurface,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              icon: const Icon(Icons.table_view, size: 14),
              label: Text(
                multi
                    ? 'Exportar histórico CSV (${selected.length} fuentes)'
                    : 'Exportar histórico CSV',
              ),
              onPressed: allSeries.isEmpty
                  ? null
                  : () {
                      // CSV multi-divisa: Día + una columna por fuente elegida.
                      final days = allSeries.map((p) => p.day).toSet().toList()
                        ..sort();
                      final rows = <List<String>>[
                        ['Dia', for (final id in selected) id],
                      ];
                      for (final day in days) {
                        rows.add([
                          day,
                          for (final id in selected)
                            _rateForDay(seriesById[id]!, day, raw: true),
                        ]);
                      }
                      showShareFile(
                        context,
                        'valorave-historico${multi ? '-multi' : '-${selected.first}'}.csv',
                        toCSV(rows, delimiter: ';'),
                      );
                    },
            ),
          ],
        ],
      ],
    );
  }

  /// Tasa de [series] en [day]: formateada o cruda (CSV); '—' si no hay.
  String _rateForDay(
    List<SnapshotPoint> series,
    String day, {
    bool raw = false,
  }) {
    final p = series.where((x) => x.day == day).firstOrNull;
    if (p == null) return raw ? '' : '—';
    return raw ? p.rate.toStringAsFixed(4) : fmtRate(p.rate);
  }
}

// ─────────────────── Calendario de devaluación ─────────────────────────────

/// Calendario pictórico de devaluación (§9.7 · el heatmap 6 m del web —
/// cierra la desviación D2): un cuadro por día, rojo=subida de la tasa
/// (devaluación), verde=baja, intensidad = magnitud vs el día anterior con
/// datos. Solo meses con datos (nunca media pantalla de cuadros vacíos).
/// Encima del grid: día con mayor subida del período.
class HeatmapCalendar extends StatelessWidget {
  const HeatmapCalendar({super.key, required this.data});

  /// % diario (vs día anterior con datos) por 'YYYY-MM-DD'.
  final List<({String day, double pct})> data;

  static const int _kMonths = 6;

  @override
  Widget build(BuildContext context) {
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
                    style: VeText.labelCaps(9.5, color: scheme.primary),
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
              _legendBox(ink.pos.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                'baja',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              _legendBox(scheme.surfaceContainerHighest),
              const SizedBox(width: 4),
              Text(
                'sin datos',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(width: 10),
              _legendBox(ink.neg.withValues(alpha: 0.7)),
              const SizedBox(width: 4),
              Text(
                'subida · más intenso = mayor cambio',
                style: TextStyle(fontSize: 10, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _legendBox(Color c) => Container(
    width: 11,
    height: 11,
    decoration: BoxDecoration(
      color: c,
      borderRadius: BorderRadius.circular(3),
      border: Border.all(color: Colors.black26, width: 0.5),
    ),
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
      child: Container(
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(3),
          border: Border.all(color: scheme.outlineVariant, width: 0.5),
        ),
      ),
    );
  }
}
