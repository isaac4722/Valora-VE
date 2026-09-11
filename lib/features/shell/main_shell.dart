/// ─── Shell · cabecera + cinta (solo Inicio) + barra inferior 6 pestañas ────
/// Port del GUI dp4 con estado real: ticker del tablero vivo, campana del
/// centro de notificaciones persistido, badge carrito, banner de salud.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/currencies.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../state/app_state.dart';
import '../../widgets/ui.dart';
import '../../widgets/walkthrough.dart';
import '../../widgets/walkthroughs_content.dart';
import 'notifs_center.dart';
import 'global_search_screen.dart';
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
          _WalkthroughTrigger(current: current),
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

/// Dispara el walkthrough del módulo al entrar a su pestaña (UNA vez por
/// instalación; replay manual en Ajustes). Widget de cero píxeles.
class _WalkthroughTrigger extends StatefulWidget {
  const _WalkthroughTrigger({required this.current});
  final int current;

  @override
  State<_WalkthroughTrigger> createState() => _WalkthroughTriggerState();
}

class _WalkthroughTriggerState extends State<_WalkthroughTrigger> {
  int? _last;

  static const _locations = ['/', '/conversor', '/lista', '/productos', '/finanzas', '/analisis'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
  }

  @override
  void didUpdateWidget(_WalkthroughTrigger old) {
    super.didUpdateWidget(old);
    if (old.current != widget.current) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShow());
    }
  }

  void _maybeShow() {
    if (!mounted || _last == widget.current) return;
    _last = widget.current;
    if (widget.current < 0 || widget.current >= _locations.length) return;
    final location = _locations[widget.current];
    final wt = kWalkthroughs[location];
    if (wt == null) return;
    // Tolerante: sin Provider<SharedPreferences> (tests, previews) se salta.
    final SharedPreferences prefs;
    try {
      prefs = context.read<SharedPreferences>();
    } on ProviderNotFoundException {
      return;
    }
    maybeRunWalkthrough(context, prefs, location, wt.title, wt.steps);
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
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

/// Cabecera mínima del dp4: SOLO el nombre «ValoraVE» en tipografía
/// display + acciones esenciales. Sin logo (lo pone el ícono del
/// launcher), sin píldora «en vivo», sin frescura — menos ruido, más
/// aire. La frescura vive en el héroe de Inicio y en RateHealthBanner.
class _Header extends StatelessWidget {
  const _Header({required this.activeIndex});
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final unread = store.notifs.where((n) => !n.read).length;

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
              // Marca tipográfica pura, patrón dp4: «Valora» + «VE» en
              // tinta primaria. Tap → Inicio.
              InkWell(
                onTap: () => context.go('/'),
                borderRadius: BorderRadius.circular(10),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
                  child: RichText(
                    text: TextSpan(
                      style: VeText.displayNum(18, color: scheme.onSurface, weight: FontWeight.w700),
                      children: <InlineSpan>[
                        const TextSpan(text: 'Valora'),
                        TextSpan(text: 'VE', style: TextStyle(color: scheme.primary)),
                      ],
                    ),
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
                    // dp4: búsqueda global como pantalla completa (módulos,
                    // productos, compras con tienda y avisos).
                    onTap: () => Navigator.of(context).push(
                      MaterialPageRoute<void>(builder: (_) => const GlobalSearchScreen()),
                    ),
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

