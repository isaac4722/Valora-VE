/// ─── Inicio (v28 · equivalencia) ──────────────────────────────────────────
/// Una pantalla de inicio de verdad: el ojo cae en UNA cifra (la equivalencia
/// «1 USD = X Bs» de la fuente activa del país — BCV por defecto, cambiable
/// en Ajustes), luego en las cuatro acciones que usa la gente y después en su
/// mes. Sin gráfica, sin paralelo en pequeño y sin ningún otro dato en la
/// tarjeta (v28 · orden del dueño). Cada bloque se explica solo y cabe en
/// 390 px.
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
import '../../state/app_state.dart';
import '../../widgets/app_router.dart' show kHeroRateKey;
import '../../widgets/app_tips.dart';
import '../../widgets/app_tour.dart' show TourKeys;
import '../../widgets/ui.dart';
// v32: la lupa salió del header — el import del command palette muere aquí
// (el sidebar de escritorio sigue teniendo su ⌘K propio).
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

/// Cabecera: saludo + acciones que importan (avisos, tema, ajustes).
/// v32: SIN lupa (orden del dueño). Ajustes queda a un toque en la
/// cabecera y también en Más (v27.3).
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
                    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
                      saludo(DateTime.now()),
                      maxLines: 1,
                      style: VeText.displayNum(
                        30,
                        color: scheme.onSurface,
                        weight: FontWeight.w600,
                      ),
                    )),
                    const SizedBox(height: 2),
                    Text(
                      'Tu dinero, en orden.',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 13.5,
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
                // v32 (orden del dueño): header de Inicio SIN lupa — la
                // búsqueda vive en el sidebar de escritorio (⌘K) y muere en
                // el móvil. Los iconos que quedan son GRANDES (40/18) y
                // quedan centrados contra el bloque del saludo.
                size: 40,
                iconSize: 18,
                onTap: () => showNotificationCenter(context, ref),
              ),
              const SizedBox(width: 2),
              VeIconBtn(
                icon: dark ? LucideIcons.sun : LucideIcons.moon,
                label: dark ? 'Tema claro' : 'Tema oscuro',
                size: 40,
                iconSize: 18,
                onTap: () => toggleVeTheme(ref),
              ),
              const SizedBox(width: 2),
              VeIconBtn(
                icon: LucideIcons.settings,
                label: 'Ajustes',
                size: 40,
                iconSize: 18,
                onTap: () => context.go('/ajustes'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Tarjeta protagonista (v28 · orden del dueño): UNA sola moneda y su
/// equivalencia — «1 USD = X Bs» — de la fuente activa del país (BCV por
/// defecto, configurable en Ajustes → Tasas). Sin gráfica, sin paralelo y
/// sin ningún otro dato: la conversión, la comparación VS ayer y las dos
/// salidas (Convertir · Ver tasas). El nombre de la tasa aparece UNA sola
/// vez y en una sola forma, conservando siempre «Oficial».
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

    // Nombre ÚNICO en una línea (v28): «BCV · Oficial» o «Paralelo ·
    // Mercado» — la categoría entra en la MISMA forma, nunca un segundo
    // nombre debajo. En oficiales la palabra «Oficial» siempre está. Si el
    // label ya contiene la palabra de categoría no se duplica.
    final String nombre = s.label.contains(s.category.label)
        ? s.label
        : '${s.label} · ${s.category.label}';

    return KeyedSubtree(
      key: TourKeys.cotizacion,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
        decoration: BoxDecoration(
          color: scheme.surface,
          border: Border.all(color: context.ve.colorScheme.border),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // ── Nombre de la tasa (una sola forma) + frescura ──
            Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      nombre,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
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
            const SizedBox(height: 18),
            // ── La equivalencia (héroe): 1 USD = 915,38 Bs ──
            // El «=» como pieza gráfica en tinta primaria compone la
            // lectura de conversión: jamás se lee «BCV a 900 USD».
            Semantics(
              label:
                  '1 ${s.base.code} igual a ${fmtRatePrecise(displayRate, precision)} ${s.quote.code}',
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Row(
                  // Baseline (v28.1 · hallazgo Goldfish): la cifra y el «=»
                  // de 30 comparten línea de base con «1 USD» y «Bs» de 17 —
                  // lectura tipográfica firme, sin piezas flotando.
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Text(
                      '1 ${s.base.code}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        color: scheme.onSurfaceVariant,
                        letterSpacing: 0.2,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '=',
                      style: VeText.displayNum(
                        30,
                        color: scheme.primary,
                        weight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      fmtRatePrecise(displayRate, precision),
                      key: kHeroRateKey,
                      style: VeText.displayNum(30, color: scheme.onSurface),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      s.quote.symbol,
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            // ── Composición VS + porcentaje (vs ayer) ──
            Row(
              children: [
                Text(
                  'VS',
                  style: VeText.labelCaps(11, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                if (vsAyer != null) ...[
                  Container(
                    width: 1,
                    height: 12,
                    color: scheme.outlineVariant,
                  ),
                  const SizedBox(width: 8),
                  TrendBadge(vsAyer),
                  const SizedBox(width: 6),
                  Text(
                    'ayer',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ] else
                  Flexible(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'sin dato del día anterior',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 16),
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
            style: VeText.labelCaps(11, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            poller.loading ? 'Buscando tasas…' : 'Sin tasa todavía',
            style: VeText.displayNum(
              30,
              color: scheme.onSurface,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            poller.offlineNet
                ? 'Sin red. Pega una tasa manual y sigue trabajando.'
                : 'Cuando llegue el tablero, la cifra aparece aquí.',
            style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
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
              // v28.1 (hallazgo Goldfish): el botón «Tasa manual» SOLO si la
              // fuente manual existe para la divisa del país (p. ej. no hay
              // 'usd-manual' para el país Global).
              if (RateSource.of(manualId) != null) ...[
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
            ],
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
                  // v27.3: límite visible en los accesos rápidos, no en toda la UI.
                  border: Border.all(color: context.ve.colorScheme.border),
                ),
                // v28.1: icono en la escala title (17) — el tamaño canónico
                // de iconos de acción, centrado en su caja circular.
                child: Icon(
                  action.icon,
                  size: 17,
                  color: context.ve.colorScheme.foreground,
                ),
              ),
              const SizedBox(height: 7),
              FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
                action.label,
                maxLines: 1,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: scheme.onSurface,
                ),
              )),
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
                    FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
                      '${purchases.length} ${purchases.length == 1 ? 'compra' : 'compras'}'
                      '${top.isEmpty ? '' : ' · ${top.first.key}'}',
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    )),
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
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
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
                          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
                            (p.store ?? '').trim().isEmpty
                                ? 'Sin tienda'
                                : p.store!,
                            maxLines: 1,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          )),
                          FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
                            '${fmtDate(p.date)} · ${p.items.length} artículos',
                            maxLines: 1,
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          )),
                        ],
                      ),
                    ),
                    Text(
                      fmtUSD(p.totalUSD),
                      style: TextStyle(
                        fontSize: 13.5,
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
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
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
