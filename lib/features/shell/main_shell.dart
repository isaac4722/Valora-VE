/// ─── Shell · cabecera + cinta (solo Inicio) + barra inferior 6 pestañas ────
/// Port del GUI dp4 con estado real: ticker del tablero vivo, campana del
/// centro de notificaciones persistido, badge carrito, banner de salud.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../core/models.dart';
import '../../data/store.dart';
import '../../state/app_state.dart';
import '../../widgets/ui.dart';
import 'notifs_center.dart';
import '../../widgets/app_router.dart' show kNavBarKey, kHeaderActionsKey;

/// Ítems del ticker según modo: featured (protagonistas+EUR) / focus (orden
/// usuario) / off (no se monta).
List<({Currency flag, String label, double value, String unit, bool isEur})>
    tickerItems(AppStore store) {
  final ctx = store.contextOf();
  final b = store.board;
  final items = <({Currency flag, String label, double value, String unit, bool isEur})>[];

  final mode = store.settings.tickerMode;
  if (mode == 'featured') {
    // Fuentes protagonistas del país + arista EUR del país VE.
    for (final id in CountryX.from(store.settings.country).featured) {
      final s = RateSource.of(id);
      final e = b.sources[id];
      if (s == null || e == null) continue;
      items.add((
        flag: s.currency,
        label: convSourceNames[id] ?? s.label,
        value: e.rate,
        unit: s.currency == Currency.eur ? 'Bs/EUR' : 'Bs',
        isEur: s.currency == Currency.eur,
      ));
    }
    if (CountryX.from(store.settings.country) == Country.VE) {
      final pair = b.sources['eur-ves-oficial'];
      if (pair != null) {
        items.add((flag: Currency.eur, label: 'Euro Oficial', value: pair.rate, unit: 'Bs', isEur: true));
      }
    }
    return items;
  }
  // focus: divisas del foco en su orden configurado, 1 USD = X de la divisa.
  final order = CurrencyX.focusOrder(store.settings.currencyOrder);
  for (final c in order) {
    if (c == Currency.usd) continue;
    final u = ctx.unitsPerUSD(c);
    if (u == null || u <= 0) continue;
    items.add((
      flag: c,
      label: c.code,
      value: u,
      unit: c == Currency.ves ? 'Bs' : 'USD',
      isEur: c == Currency.eur,
    ));
  }
  return items;
}

class MainShell extends StatelessWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_TabSpec> _tabs = [
    _TabSpec(location: '/', icon: Icons.home_outlined, activeIcon: Icons.home, label: 'Inicio'),
    _TabSpec(location: '/conversor', icon: Icons.swap_horiz, activeIcon: Icons.swap_horiz, label: 'Divisas'),
    _TabSpec(location: '/lista', icon: Icons.shopping_cart_outlined, activeIcon: Icons.shopping_cart, label: 'Lista'),
    _TabSpec(location: '/productos', icon: Icons.inventory_2_outlined, activeIcon: Icons.inventory_2, label: 'Productos'),
    _TabSpec(location: '/finanzas', icon: Icons.account_balance_wallet_outlined, activeIcon: Icons.account_balance_wallet, label: 'Finanzas'),
    _TabSpec(location: '/analisis', icon: Icons.bar_chart_outlined, activeIcon: Icons.bar_chart, label: 'Análisis'),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int current = navigationShell.currentIndex;
    // Rate-health (§5): el banner se monta SIEMPRE encima del body y decide
    // solo su visibilidad (rateStale = se vio tablero OK hace >15 min).
    final RatesPoller poller = context.watch<RatesPoller>();

    return Scaffold(
      body: Column(
        children: [
          _Header(activeIndex: current),
          RateHealthBanner(stale: poller.rateStale, onRetry: () => poller.refreshNow()),
          if (current == 0) _HomeTicker(),
          Expanded(child: navigationShell),
        ],
      ),
      bottomNavigationBar: Container(
        key: kNavBarKey,
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          border: Border(top: BorderSide(color: scheme.outlineVariant)),
        ),
        child: SafeArea(
          top: false,
          child: Row(
            children: [
              for (int i = 0; i < _tabs.length; i++)
                Expanded(
                  child: _TabButton(
                    spec: _tabs[i],
                    active: i == current,
                    badge: i == 2 ? _cartCount(context) : 0,
                    onTap: () => navigationShell.goBranch(i, initialLocation: i == current),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }

  int _cartCount(BuildContext context) {
    final store = context.watch<AppStore>();
    return store.cart.fold<int>(0, (acc, c) => acc + c.quantity);
  }
}

class _TabSpec {
  const _TabSpec({required this.location, required this.icon, required this.activeIcon, required this.label});
  final String location;
  final IconData icon;
  final IconData activeIcon;
  final String label;
}

class _TabButton extends StatelessWidget {
  const _TabButton({required this.spec, required this.active, required this.onTap, this.badge = 0});

  final _TabSpec spec;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TapScale(
      onTap: onTap,
      child: SizedBox(
        height: 58,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Container(
                  width: 46,
                  height: 27,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active ? scheme.primary.withValues(alpha: 0.20) : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                    border: active ? Border.all(color: scheme.primary.withValues(alpha: 0.25)) : null,
                  ),
                  child: Icon(active ? spec.activeIcon : spec.icon, size: 19,
                      color: active ? scheme.primary : scheme.onSurfaceVariant),
                ),
                if (badge > 0)
                  Positioned(
                    right: -4,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: scheme.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        badge > 9 ? '9+' : '$badge',
                        style: TextStyle(
                          fontSize: 9,
                          fontWeight: FontWeight.w800,
                          color: scheme.onPrimary,
                          fontFamily: 'Inter',
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 2),
            Text(spec.label, style: TextStyle(
                fontSize: 11, fontWeight: FontWeight.w700, letterSpacing: -0.1,
                color: active ? scheme.primary : scheme.onSurfaceVariant)),
          ],
        ),
      ),
    );
  }
}

/// Cinta solo-Inicio con las fuentes del tablero vivo. Sin datos NO hace
/// shrink aquí: el placeholder anti-CLS vive dentro de RateTicker (misma
/// altura, «Cargando cotizaciones…») para que la cinta no salte el layout.
class _HomeTicker extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return RateTicker(
      items: tickerItems(store),
      mode: store.settings.tickerMode,
      size: store.settings.tickerSize,
      speed: store.settings.tickerSpeed,
    );
  }
}

/// Cabecera: marca ValoraVE + píldora live + frescura + búsqueda/tema/
/// campana/ajustes. Tap en la marca → refresca el tablero manualmente.
class _Header extends StatelessWidget {
  const _Header({required this.activeIndex});
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    final RatesPoller poller = context.watch<RatesPoller>();
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final unread = store.notifs.where((n) => !n.read).length;

    // Píldora live (§8): live = última fetch OK hace <2 min; si no, apagada
    // (LiveBadge se oculta sola) y queda la frescura «hace X min» como pista.
    final DateTime? fetchedAt = store.board.fetchedAt;
    final DateTime? lastOk = poller.lastBoardOk;
    final bool live = lastOk != null && DateTime.now().difference(lastOk).inMinutes < 2;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        bottom: false,
        child: SizedBox(
          height: 54,
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(children: [
              TapScale(
                onTap: () => poller.refreshNow(),
                child: Tooltip(
                  message: 'Actualizar tasas',
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      const LogoMark(),
                      const SizedBox(width: 8),
                      const Flag(Currency.ves, size: 14),
                      const SizedBox(width: 7),
                      LiveBadge(live: live),
                      if (fetchedAt != null) ...[
                        const SizedBox(width: 6),
                        Text(
                          timeAgo(fetchedAt),
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ]),
                  ),
                ),
              ),
              const Spacer(),
              Container(
                key: kHeaderActionsKey,
                child: Row(children: [
                  _HeaderIcon(
                    icon: Icons.search,
                    tooltip: 'Buscar en la app',
                    onTap: () => showGlobalSearch(context),
                  ),
                  _HeaderIcon(
                    icon: dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined,
                    tooltip: 'Cambiar tema',
                    onTap: () => context.read<ThemeController>().setMode(
                        dark ? ThemeMode.light : ThemeMode.dark,
                        context.read<SharedPreferences>()),
                  ),
                  _HeaderIcon(
                    icon: Icons.notifications_outlined,
                    tooltip: 'Notificaciones',
                    badge: unread,
                    onTap: () => showNotificationCenter(context),
                  ),
                  _HeaderIcon(
                    icon: Icons.settings_outlined,
                    tooltip: 'Ajustes',
                    onTap: () => context.go('/ajustes'),
                  ),
                ]),
              ),
              const SizedBox(width: 10),
            ]),
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({required this.icon, required this.onTap, this.tooltip, this.badge = 0});

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(9),
      child: Container(
        width: 36,
        height: 36,
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Icon(icon, size: 19, color: scheme.onSurfaceVariant),
            if (badge > 0)
              Positioned(
                right: -4,
                top: -3,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
                  decoration: BoxDecoration(color: scheme.primary, borderRadius: BorderRadius.circular(999)),
                  child: Text(badge > 9 ? '9+' : '$badge',
                      style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: scheme.onPrimary, fontFamily: 'Inter')),
                ),
              ),
          ],
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Búsqueda global (módulos + productos + notificaciones).
void showGlobalSearch(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const _GlobalSearchSheet(),
  );
}

class _GlobalSearchSheet extends StatefulWidget {
  const _GlobalSearchSheet();

  @override
  State<_GlobalSearchSheet> createState() => _GlobalSearchSheetState();
}

class _GlobalSearchSheetState extends State<_GlobalSearchSheet> {
  String _q = '';

  static const List<(String, String, IconData)> _modules = [
    ('Inicio', '/', Icons.home_outlined),
    ('Conversor', '/conversor', Icons.swap_horiz),
    ('Lista', '/lista', Icons.shopping_cart_outlined),
    ('Productos', '/productos', Icons.inventory_2_outlined),
    ('Historial', '/historial', Icons.receipt_long_outlined),
    ('Finanzas', '/finanzas', Icons.account_balance_wallet_outlined),
    ('Análisis', '/analisis', Icons.bar_chart_outlined),
    ('Ajustes', '/ajustes', Icons.settings_outlined),
  ];

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final q = fold(_q.trim().toLowerCase());
    bool match(String s) => q.isEmpty || fold(s.toLowerCase()).contains(q);

    final modules = _modules.where((m) => match(m.$1)).toList();
    final products = q.isEmpty
        ? const <Product>[]
        : store.products.where((p) => match(p.name) || (p.barcode ?? '').contains(_q)).take(6).toList();
    final notifs = q.isEmpty
        ? const <NotificationItem>[]
        : store.notifs.where((n) => match(n.title)).take(4).toList();

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.75,
        maxChildSize: 0.92,
        builder: (context, scroll) => Column(children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: TextField(
              autofocus: true,
              onChanged: (v) => setState(() => _q = v),
              decoration: const InputDecoration(
                hintText: 'Módulos, productos, compras, avisos…',
                prefixIcon: Icon(Icons.search, size: 18),
              ),
            ),
          ),
          Expanded(
            child: ListView(
              controller: scroll,
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              children: [
                if (modules.isNotEmpty) ...[
                  Text('Módulos', style: VeText.labelCaps(10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  for (final m in modules)
                    ListTile(
                      dense: true,
                      leading: Icon(m.$3, size: 19, color: Theme.of(context).colorScheme.primary),
                      title: Text(m.$1, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                      onTap: () {
                        Navigator.pop(context);
                        context.go(m.$2);
                      },
                    ),
                ],
                if (products.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Productos', style: VeText.labelCaps(10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  for (final p in products)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.inventory_2_outlined, size: 19),
                      title: Text(p.name, style: const TextStyle(fontSize: 13.5)),
                      subtitle: Text(p.barcode ?? p.category.label, style: const TextStyle(fontSize: 11.5)),
                      onTap: () {
                        Navigator.pop(context);
                        context.go('/productos');
                      },
                    ),
                ],
                if (notifs.isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Text('Notificaciones', style: VeText.labelCaps(10, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 6),
                  for (final n in notifs)
                    ListTile(
                      dense: true,
                      leading: const Icon(Icons.notifications_outlined, size: 19),
                      title: Text(n.title, style: const TextStyle(fontSize: 13)),
                      onTap: () {
                        Navigator.pop(context);
                        showNotificationCenter(context);
                      },
                    ),
                ],
                if (modules.isEmpty && products.isEmpty && notifs.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 40),
                    child: Text('Sin resultados para «$_q»',
                        textAlign: TextAlign.center,
                        style: TextStyle(fontSize: 13, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
