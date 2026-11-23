/// ─── Inicio (v27 · papel-tinta) ────────────────────────────────────────────
/// Una pantalla de inicio de verdad: el ojo cae en UNA cifra (la tasa del
/// día), luego en las cuatro acciones que usa la gente y después en su mes.
/// Lo demás vive donde tiene sentido: la cotización completa en Tasas, los
/// módulos secundarios en Más, los ajustes en su hub. Sin acordeones ni
/// secciones escondidas: cada bloque se explica solo y cabe en 390 px.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/ve_theme.dart';
import '../../data/rate_history.dart' show snapshotSeries;
import '../../state/app_state.dart';
import '../../widgets/app_router.dart' show kHeroRateKey;
import '../../widgets/app_tips.dart';
import '../../widgets/app_tour.dart' show TourKeys;
import '../../widgets/ui.dart';
import '../shell/command_palette.dart' show showCommandPalette;
import '../shell/main_shell.dart' show toggleVeTheme, veEffectiveDark;
import '../shell/notifs_center.dart' show showNotificationCenter;
import '../rates/rates_screen.dart' show editManualRate;
import 'package:valorave/providers/providers.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final poller = ref.watch(ratesPollerProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: RefreshIndicator(
        onRefresh: () => poller.refreshNow(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 28),
          children: [
            const TipsTrigger(scope: 'home'),
            const _HomeHeader(),
            const SizedBox(height: 18),
            _RateCard(poller: poller),
            const SizedBox(height: 22),
            const _QuickActions(),
            const _MonthSummary(),
            const _RecentActivity(),
          ],
        ),
      ),
    );
  }
}

/// Cabecera: saludo + tres acciones que importan (avisos, búsqueda, tema).
/// Ajustes vive en Más; la fecha la dice el reloj del teléfono (v26).
class _HomeHeader extends ConsumerWidget {
  const _HomeHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final store = ref.watch(appStoreProvider);
    final unread = store.notifs.any((n) => !n.read);
    final dark = veEffectiveDark(ref);

    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      saludo(DateTime.now()),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: VeText.displayNum(
                        24,
                        color: scheme.onSurface,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Tasas, compras y cuentas en orden.',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              VeIconBtn(
                icon: LucideIcons.bell,
                label: 'Avisos',
                dot: unread,
                size: 36,
                iconSize: 16,
                onTap: () => showNotificationCenter(context, ref),
              ),
              const SizedBox(width: 4),
              VeIconBtn(
                icon: LucideIcons.search,
                label: 'Buscar',
                size: 36,
                iconSize: 16,
                onTap: () => showCommandPalette(context),
              ),
              const SizedBox(width: 4),
              VeIconBtn(
                icon: dark ? LucideIcons.sun : LucideIcons.moon,
                label: dark ? 'Tema claro' : 'Tema oscuro',
                size: 36,
                iconSize: 16,
                onTap: () => toggleVeTheme(ref),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta protagonista: la tasa activa del país, su fuente, la chispa real
/// de 14 días y dos salidas: convertir o ver la cotización completa.
class _RateCard extends ConsumerWidget {
  const _RateCard({required this.poller});

  final RatesPoller poller;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final store = ref.watch(appStoreProvider);
    final country = CountryX.from(store.settings.country);
    final activeId = store.sourceFor(country.currency);
    final s = RateSource.of(activeId);
    final e = store.board.sources[activeId];
    final ctx = store.contextOf();
    final manualRate = ctx.rate(activeId);
    final precision = store.settings.precision;

    if (s == null || (e == null && manualRate <= 0)) {
      return _RateEmpty(poller: poller, country: country);
    }
    final double displayRate = e?.rate ?? manualRate;
    final DateTime updatedAt = e?.updatedAt ?? DateTime.now();

    final bool isVe = country == Country.VE;
    final bcv = isVe ? store.board.sources['ves-bcv']?.rate : null;
    final parallel = isVe ? store.board.sources['ves-parallel']?.rate : null;
    final gap =
        (bcv != null && bcv > 0 && displayRate > 0 && activeId != 'ves-bcv')
        ? (displayRate / bcv - 1) * 100
        : null;

    final dayKey = SnapshotPoint.dayKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final yest =
        store.snapshots
            .where((p) => p.sourceId == activeId && p.day == dayKey)
            .toList()
          ..sort((a, b) => a.day.compareTo(b.day));
    final double? vsAyer = (yest.isNotEmpty && yest.last.rate > 0)
        ? (displayRate / yest.last.rate - 1) * 100
        : null;

    final serie = snapshotSeries(
      store.snapshots,
      activeId,
      14,
    ).map((p) => p.rate).toList(growable: false);

    final detail =
        s.detail.toLowerCase().startsWith(
          '${s.category.label.toLowerCase()} · ',
        )
        ? s.detail.substring(s.category.label.length + 3)
        : s.detail;

    return KeyedSubtree(
      key: TourKeys.cotizacion,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: context.ve.colorScheme.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                VeBadge(
                  tone: switch (s.category) {
                    SourceCategory.official => VeTone.pos,
                    SourceCategory.parallel => VeTone.neg,
                    SourceCategory.mixed => VeTone.warn,
                    SourceCategory.manual => VeTone.info,
                  },
                  child: Text(s.category.label.toUpperCase()),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    s.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                if (poller.loading)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 1.8),
                  )
                else
                  Text(
                    timeAgo(updatedAt),
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Semantics(
                    label:
                        '1 USD igual a ${fmtRatePrecise(displayRate, precision)} ${country.currency.code}',
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Flexible(
                          child: FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              fmtRatePrecise(displayRate, precision),
                              key: kHeroRateKey,
                              maxLines: 1,
                              style:
                                  VeText.displayNum(
                                    42,
                                    color: scheme.onSurface,
                                  ).copyWith(
                                    fontFeatures: const [
                                      FontFeature.tabularFigures(),
                                    ],
                                  ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 6),
                        Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Text(
                            'USD',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              letterSpacing: 0.6,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                if (serie.length >= 3)
                  SizedBox(
                    width: 84,
                    height: 38,
                    child: VeSparkline(
                      data: serie,
                      tone: serie.last >= serie.first
                          ? VeChartTone.pos
                          : VeChartTone.neg,
                      height: 38,
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              detail.isEmpty ? 'Tasa activa del tablero' : detail,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 14,
              runSpacing: 6,
              children: [
                if (parallel != null && parallel > 0)
                  _MiniStat(
                    label: 'Paralelo',
                    value: fmtRatePrecise(parallel, precision),
                  ),
                if (gap != null) _MiniStat(label: 'Brecha', value: fmtPct(gap)),
                if (vsAyer != null)
                  _MiniStat(
                    label: 'vs ayer',
                    value: fmtPct(vsAyer, forceSign: true),
                    tone: vsAyer >= 0 ? VeTone.pos : VeTone.neg,
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: VeBtn(
                    variant: VeBtnVariant.primary,
                    onPressed: () => context.go('/conversor'),
                    child: const Text('Convertir'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: VeBtn(
                    variant: VeBtnVariant.secondary,
                    onPressed: () => context.push('/tasas'),
                    child: const Text('Ver tasas'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _RateEmpty extends ConsumerWidget {
  const _RateEmpty({required this.poller, required this.country});

  final RatesPoller poller;
  final Country country;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final store = ref.watch(appStoreProvider);
    final manualId = '${country.currency.code.toLowerCase()}-manual';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: scheme.surface,
        border: Border.all(color: context.ve.colorScheme.border),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tasa del día',
            style: VeText.labelCaps(10.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            poller.loading ? 'Buscando tasas…' : 'Sin tasa todavía',
            style: VeText.displayNum(
              26,
              color: scheme.onSurface,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            poller.offlineNet
                ? 'Sin red. Pega una tasa manual y sigue trabajando.'
                : 'Cuando llegue el tablero, la cifra aparece aquí.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: VeBtn(
                  variant: VeBtnVariant.secondary,
                  onPressed: poller.loading ? null : () => poller.retryNow(),
                  child: const Text('Reintentar'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: VeBtn(
                  variant: VeBtnVariant.ghost,
                  onPressed: () =>
                      editManualRate(context, ref, store, manualId),
                  child: const Text('Tasa manual'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MiniStat extends ConsumerWidget {
  const _MiniStat({required this.label, required this.value, this.tone});

  final String label;
  final String value;
  final VeTone? tone;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);
    final color = switch (tone) {
      VeTone.pos => ink.pos,
      VeTone.neg => ink.neg,
      VeTone.warn => ink.warn,
      _ => scheme.onSurface,
    };
    return Text.rich(
      TextSpan(
        children: [
          TextSpan(
            text: '$label ',
            style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
          ),
          TextSpan(
            text: value,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: color,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cuatro acciones de uso diario, con icono y etiqueta. Sin cajas: el aire
/// y el icono bastan; el blanco de toque es de 48 px.
class _QuickActions extends ConsumerWidget {
  const _QuickActions();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final actions = <_QuickAction>[
      _QuickAction(
        icon: LucideIcons.arrowLeftRight,
        label: 'Convertir',
        onTap: () => context.go('/conversor'),
      ),
      _QuickAction(
        icon: LucideIcons.shoppingCart,
        label: 'Lista',
        onTap: () => context.go('/lista'),
      ),
      _QuickAction(
        icon: LucideIcons.package,
        label: 'Precios',
        onTap: () => context.go('/productos'),
      ),
      _QuickAction(
        icon: LucideIcons.landmark,
        label: 'Cuentas',
        onTap: () => context.push('/ajustes/cuentas'),
      ),
    ];
    return Row(
      children: [
        for (final a in actions) ...[
          Expanded(child: _QuickActionButton(action: a)),
          if (a != actions.last) const SizedBox(width: 6),
        ],
      ],
    );
  }
}

class _QuickAction {
  const _QuickAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
}

class _QuickActionButton extends ConsumerWidget {
  const _QuickActionButton({required this.action});

  final _QuickAction action;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: action.label,
      child: InkWell(
        onTap: action.onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 6),
          child: Column(
            children: [
              Container(
                width: 46,
                height: 46,
                decoration: BoxDecoration(
                  color: context.ve.colorScheme.muted,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  action.icon,
                  size: 20,
                  color: context.ve.colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 7),
              Text(
                action.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Resumen del mes: una cifra, cuántas compras y dónde se gastó. Si hay
/// presupuesto, la barra dice cuánto queda sin convertirse en otro gráfico.
class _MonthSummary extends ConsumerWidget {
  const _MonthSummary();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final purchases = store.purchases
        .where((p) => p.date.year == now.year && p.date.month == now.month)
        .toList();
    final spent = purchases.fold<double>(0, (a, p) => a + p.paidUSD);
    final byStore = <String, double>{};
    for (final p in purchases) {
      final k = (p.store ?? '').trim().isEmpty ? 'Sin tienda' : p.store!.trim();
      byStore[k] = (byStore[k] ?? 0) + p.paidUSD;
    }
    final top = byStore.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final budgetCurrency = CurrencyX.from(store.data.budget.currency);
    final budget = store.data.budget.amount;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VeEyebrow(
          hint: 'Lo que llevas gastado en ${kMeses[now.month - 1]}.',
          right: VeBtn(
            variant: VeBtnVariant.ghost,
            size: VeBtnSize.sm,
            onPressed: () => context.go('/analisis'),
            child: const Text('Ver análisis'),
          ),
          child: const Text('TU MES'),
        ),
        if (purchases.isEmpty)
          _EmptyPanel(
            icon: LucideIcons.receiptText,
            title: 'Sin compras este mes',
            body: 'Cierra una compra en Lista y el resumen se llena solo.',
            action: 'Hacer una compra',
            onAction: () => context.go('/lista'),
          )
        else ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      fmtUSD(spent),
                      style: VeText.displayNum(30, color: scheme.onSurface)
                          .copyWith(
                            fontFeatures: const [FontFeature.tabularFigures()],
                          ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${purchases.length} ${purchases.length == 1 ? 'compra' : 'compras'}'
                      '${top.isEmpty ? '' : ' · ${top.first.key}'}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              if (top.isNotEmpty)
                StoreAvatar(
                  top.first.key == 'Sin tienda' ? 'Sin tienda' : top.first.key,
                  size: 34,
                ),
            ],
          ),
          if (budget > 0) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: (spent / budget).clamp(0, 1),
                minHeight: 4,
                backgroundColor: context.ve.colorScheme.muted,
                color: context.ve.colorScheme.foreground,
              ),
            ),
            const SizedBox(height: 5),
            Text(
              'Presupuesto: ${fmtCurrency(budget, budgetCurrency)}',
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ],
    );
  }
}

/// Últimos movimientos: tres compras, sin gráficos. La puerta al Historial
/// está en el encabezado.
class _RecentActivity extends ConsumerWidget {
  const _RecentActivity();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    final recents = store.purchases.take(3).toList();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VeEyebrow(
          hint: 'Lo último que guardaste en tu libro.',
          right: VeBtn(
            variant: VeBtnVariant.ghost,
            size: VeBtnSize.sm,
            onPressed: () => context.go('/historial'),
            child: const Text('Ver historial'),
          ),
          child: const Text('ACTIVIDAD RECIENTE'),
        ),
        if (recents.isEmpty)
          _EmptyPanel(
            icon: LucideIcons.history,
            title: 'Aún no hay movimientos',
            body:
                'Tus compras cerradas aparecen aquí, con su tasa y su tienda.',
            action: 'Ir al historial',
            onAction: () => context.go('/historial'),
          )
        else
          for (final p in recents)
            InkWell(
              onTap: () => context.go('/historial'),
              borderRadius: BorderRadius.circular(10),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Row(
                  children: [
                    StoreAvatar(
                      (p.store ?? '').trim().isEmpty ? 'Sin tienda' : p.store!,
                      size: 30,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (p.store ?? '').trim().isEmpty
                                ? 'Sin tienda'
                                : p.store!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${fmtDate(p.date)} · ${p.items.length} artículos',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      fmtUSD(p.totalUSD),
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        fontFeatures: const [FontFeature.tabularFigures()],
                      ),
                    ),
                  ],
                ),
              ),
            ),
      ],
    );
  }
}

class _EmptyPanel extends ConsumerWidget {
  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.body,
    required this.action,
    required this.onAction,
  });

  final IconData icon;
  final String title;
  final String body;
  final String action;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 22, color: scheme.onSurfaceVariant),
          const SizedBox(height: 8),
          Text(
            title,
            style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 2),
          Text(
            body,
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          VeBtn(
            variant: VeBtnVariant.ghost,
            size: VeBtnSize.sm,
            onPressed: onAction,
            child: Text(action),
          ),
        ],
      ),
    );
  }
}
