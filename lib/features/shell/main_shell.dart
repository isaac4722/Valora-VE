/// ─── Shell «Linear» · top bar mínima + cinta (solo Inicio) + nav pill ────
/// Port del GUI dp4 reconstruido con lenguaje Linear/Vercel (orden del dueño
/// TASK-33): cabecera de 52 px con marca tipográfica y acciones fantasma,
/// command palette ⌘K para buscar en toda la app, barra inferior pill con
/// tintas Lucide. Estado real intacto: ticker del tablero vivo, campana del
/// centro de notificaciones persistido, badge carrito, banner de salud,
/// anclas del tour (kNavBarKey · kHeaderActionsKey).
/// v17.8: Finanzas se retiró como pestaña (orden del dueño) — sus gráficos
/// de gastos viven ahora en Análisis, alimentados por las compras.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/currencies.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../state/app_state.dart';
import '../../widgets/app_tour.dart';
import '../../widgets/ui.dart';
import 'command_palette.dart';
import 'notifs_center.dart';
import '../../widgets/app_router.dart' show kNavBarKey, kHeaderActionsKey;

/// Ítems del ticker según modo: featured (protagonistas+EUR) / focus (orden
/// usuario) / off (no se monta).
List<({Currency flag, String label, double value, String unit, bool isEur})>
tickerItems(AppStore store) {
  final ctx = store.contextOf();
  final b = store.board;
  final items =
      <
        ({Currency flag, String label, double value, String unit, bool isEur})
      >[];

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
        items.add((
          flag: Currency.eur,
          label: 'Euro Oficial',
          value: pair.rate,
          unit: 'Bs',
          isEur: true,
        ));
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
    _TabSpec(location: '/', icon: LucideIcons.home, label: 'Inicio'),
    _TabSpec(
      location: '/conversor',
      icon: LucideIcons.arrowLeftRight,
      label: 'Divisas',
    ),
    _TabSpec(
      location: '/lista',
      icon: LucideIcons.shoppingCart,
      label: 'Lista',
    ),
    _TabSpec(
      location: '/productos',
      icon: LucideIcons.package,
      label: 'Productos',
    ),
    _TabSpec(
      location: '/analisis',
      icon: LucideIcons.chartColumn,
      label: 'Análisis',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int current = navigationShell.currentIndex;
    // Rate-health (§5): el banner se monta SIEMPRE encima del body y decide
    // solo su visibilidad (rateStale = se vio tablero OK hace >15 min).
    final RatesPoller poller = context.watch<RatesPoller>();
    final AppStore store = context.watch<AppStore>();

    // v19 (orden del dueño): la tasa MANUAL es una tasa personalizada, NO un
    // estado «sin conexión». Si la fuente activa del país es manual — o el
    // usuario eligió no consultar APIs — el banner de salud no aparece: la
    // app funciona normal y natural con SU tasa.
    final countryCur = CountryX.from(store.settings.country).currency;
    final manualActive =
        RateSource.of(store.sourceFor(countryCur))?.category ==
        SourceCategory.manual;
    final chosenOffline = store.settings.offlineMode;
    final showHealth = !manualActive && !chosenOffline;

    return CallbackShortcuts(
      // ⌘K/Ctrl+K abre el command palette (firma SaaS · Linear/Vercel).
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            showCommandPalette(context),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            showCommandPalette(context),
      },
      child: Scaffold(
        body: Column(
          children: [
            _Header(activeIndex: current),
            // v19 · anti-salto: el banner ya no empuja el contenido de golpe —
            // AnimatedSize lo despliega/pliega en 300 ms.
            AnimatedSize(
              duration: kLayoutDur,
              curve: kEaseVe,
              alignment: Alignment.topCenter,
              child: showHealth
                  ? RateHealthBanner(
                      stale: poller.rateStale,
                      offline: poller.offlineNet,
                      onRetry: poller.offlineNet
                          ? null
                          : () => poller.refreshNow(),
                    )
                  : const SizedBox(width: double.infinity),
            ),
            if (current == 0) _HomeTicker(),
            const _TourTrigger(),
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
                      onTap: () => navigationShell.goBranch(
                        i,
                        initialLocation: i == current,
                      ),
                    ),
                  ),
              ],
            ),
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

/// Dispara el tour completo UNA vez por instalación (v17.8): al primer
/// arranque del shell, tras la bienvenida o en la primera apertura tras la
/// actualización. Replay manual en Ajustes → Tutorial. Widget de cero
/// píxeles; tolerante sin `Provider<SharedPreferences>` (tests/previews).
class _TourTrigger extends StatefulWidget {
  const _TourTrigger();

  @override
  State<_TourTrigger> createState() => _TourTriggerState();
}

class _TourTriggerState extends State<_TourTrigger> {
  @override
  void initState() {
    super.initState();
    // Post-frame: el layout del shell ya existe — las anclas del primer
    // segmento se pueden medir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      maybeRunTourOnce(context);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

class _TabSpec {
  const _TabSpec({
    required this.location,
    required this.icon,
    required this.label,
  });
  final String location;
  final IconData icon;
  final String label;
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.spec,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  final _TabSpec spec;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TapScale(
      onTap: onTap,
      // minHeight en vez de altura fija: con tamaños de accesibilidad
      // (textScale >=2.35) la etiqueta supera los 58 px y se recortaba en
      // la barra de navegación (fix a11y heredado). mainAxisSize.min —
      // con .max la Column llenaría TODO el alto del slot bottomNavigationBar.
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 58),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                // Pill Linear: tintado al 10 %, SIN borde — más plano que el
                // dp4 (que usaba 20 % + borde 25 %).
                Container(
                  width: 44,
                  height: 26,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: active
                        ? scheme.primary.withValues(alpha: 0.10)
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Icon(
                    spec.icon,
                    size: 18,
                    color: active ? scheme.primary : scheme.onSurfaceVariant,
                  ),
                ),
                if (badge > 0)
                  Positioned(
                    right: -4,
                    top: -3,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 4,
                        vertical: 1,
                      ),
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
            Text(
              spec.label,
              style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                letterSpacing: -0.1,
                color: active ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
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

/// Cabecera Linear: 52 px, marca tipográfica a la izquierda y acciones
/// fantasma a la derecha. Sin logo (lo pone el ícono del launcher), sin
/// píldora «en vivo», sin frescura — la frescura vive en el héroe de Inicio
/// y en RateHealthBanner. El botón de búsqueda lleva el hint «Ctrl K» en
/// pantallas anchas (donde hay teclado físico) — firma SaaS.
class _Header extends StatelessWidget {
  const _Header({required this.activeIndex});
  final int activeIndex;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final bool wide = MediaQuery.sizeOf(context).width >= 700;
    final unread = store.notifs.where((n) => !n.read).length;

    return Container(
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLowest,
        border: Border(bottom: BorderSide(color: scheme.outlineVariant)),
      ),
      child: SafeArea(
        bottom: false,
        // minHeight (ídem tab bar): el header crece con textScale de
        // accesibilidad en vez de recortar la marca (fix a11y heredado).
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 52),
          child: Padding(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              children: [
                // Marca tipográfica pura: «Valora» + «VE» en tinta primaria.
                // Tap → Inicio.
                InkWell(
                  onTap: () => context.go('/'),
                  borderRadius: BorderRadius.circular(10),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: RichText(
                      text: TextSpan(
                        style: VeText.displayNum(
                          17,
                          color: scheme.onSurface,
                          weight: FontWeight.w700,
                        ),
                        children: <InlineSpan>[
                          const TextSpan(text: 'Valora'),
                          TextSpan(
                            text: 'VE',
                            style: TextStyle(color: scheme.primary),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const Spacer(),
                Container(
                  key: kHeaderActionsKey,
                  child: Row(
                    children: [
                      // Búsqueda → command palette ⌘K (dp4 era pantalla
                      // completa; TASK-33 la vuelve palette Linear).
                      _HeaderIcon(
                        icon: LucideIcons.search,
                        tooltip: 'Buscar en la app (Ctrl K)',
                        onTap: () => showCommandPalette(context),
                        trailing: wide ? 'Ctrl K' : null,
                      ),
                      _HeaderIcon(
                        icon: dark ? LucideIcons.sun : LucideIcons.moon,
                        tooltip: dark ? 'Tema claro' : 'Tema oscuro',
                        spin: dark ? 1 : -1,
                        onTap: () => context.read<ThemeController>().setMode(
                          dark ? ThemeMode.light : ThemeMode.dark,
                          context.read<SharedPreferences>(),
                        ),
                      ),
                      _HeaderIcon(
                        icon: LucideIcons.bell,
                        tooltip: 'Notificaciones',
                        badge: unread,
                        onTap: () => showNotificationCenter(context),
                      ),
                      _HeaderIcon(
                        icon: LucideIcons.settings,
                        tooltip: 'Ajustes',
                        onTap: () => context.go('/ajustes'),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _HeaderIcon extends StatelessWidget {
  const _HeaderIcon({
    required this.icon,
    required this.onTap,
    this.tooltip,
    this.badge = 0,
    this.trailing,
    this.spin,
  });

  final IconData icon;
  final VoidCallback onTap;
  final String? tooltip;
  final int badge;

  /// Hint de teclado a la derecha del icono (Linear lo usa para ⌘K).
  final String? trailing;

  /// Dirección del giro al cambiar de tema (-1 luna → 1 sol): hace legible
  /// qué tema queda activo sin leer el tooltip.
  final int? spin;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final Widget button = InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Container(
        height: 34,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        alignment: Alignment.center,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                if (spin != null)
                  TweenAnimationBuilder<double>(
                    tween: Tween<double>(begin: 0, end: spin!.toDouble()),
                    duration: const Duration(milliseconds: 240),
                    curve: kEaseVe,
                    builder: (context, v, child) =>
                        Transform.rotate(angle: v * 0.6, child: child),
                    child: Icon(icon, size: 17, color: scheme.onSurfaceVariant),
                  )
                else
                  Icon(icon, size: 17, color: scheme.onSurfaceVariant),
                if (trailing != null) ...[
                  const SizedBox(width: 6),
                  Text(
                    trailing!,
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.2,
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ],
            ),
            if (badge > 0)
              Positioned(
                right: trailing != null ? -6 : -6,
                top: -6,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 1,
                  ),
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
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}
