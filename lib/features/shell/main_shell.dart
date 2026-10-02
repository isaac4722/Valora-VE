/// ─── Shell «Ve» · sidebar desktop + tabs móviles del prototipo (TASK-34) ──
/// Port del App.tsx de referencia: en escritorio (≥700 px) sidebar de 224 px
/// con marca, búsqueda ⌘K, navegación de 5 pestañas + sección «Libro»
/// (Historial · Tickets · Ajustes) y pie de tasas con punto en vivo; en móvil
/// barra inferior de 5 pestañas plana (tinta activa / faint inactivo) y FAB
/// de búsqueda flotante — oculto en las pantallas con búsqueda propia, como
/// el original. El fondo ambiental (radiales + puntos) vive detrás de todo.
/// Estado real intacto: ticker del tablero, banner de salud, campana del
/// centro de notificaciones, badge del carrito y anclas del tour
/// (kNavBarKey · kHeaderActionsKey).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../state/app_state.dart';
import '../../widgets/app_tour.dart';
import '../../widgets/ui.dart';
import 'command_palette.dart';
import '../../widgets/app_router.dart' show kNavBarKey;

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

/// Umbral de escritorio: sidebar a partir de 700 px (md del prototipo).
const double kWideShell = 700;

/// ¿El brillo EFECTIVO es oscuro? (resuelve `system` contra la plataforma).
/// Para pintar el icono del toggle de tema donde se necesite.
bool veEffectiveDark(BuildContext context) {
  final mode = context.watch<ThemeController>().mode;
  if (mode != ThemeMode.system) return mode == ThemeMode.dark;
  return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;
}

/// Alterna claro ↔ oscuro (TASK-35 · p2 · orden del dueño): vuelve el botón
/// de tema de la cabecera. Resuelve el brillo EFECTIVO (system incluido) y
/// fija el opuesto explícito — un toque hace lo que el ojo espera.
void toggleVeTheme(BuildContext context) {
  final theme = context.read<ThemeController>();
  final prefs = context.read<SharedPreferences>();
  final platformDark =
      WidgetsBinding.instance.platformDispatcher.platformBrightness ==
          Brightness.dark;
  final dark =
      theme.mode == ThemeMode.dark ||
      (theme.mode == ThemeMode.system && platformDark);
  theme.setMode(dark ? ThemeMode.light : ThemeMode.dark, prefs);
}

/// Rutas con búsqueda propia donde el FAB móvil NO aparece (como el
/// prototipo: lista · productos · análisis · historial).
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
    // usuario eligió no consultar APIs — el banner de salud no aparece.
    final countryCur = CountryX.from(store.settings.country).currency;
    final manualActive =
        RateSource.of(store.sourceFor(countryCur))?.category ==
        SourceCategory.manual;
    final chosenOffline = store.settings.offlineMode;
    final showHealth = !manualActive && !chosenOffline;

    final bool wide = MediaQuery.sizeOf(context).width >= kWideShell;

    // Columna principal compartida: banner de salud + cinta (solo Inicio) +
    // área de navegación.
    final Widget mainColumn = Column(
      children: [
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
        // v20 (orden del dueño): la LUPA flotante móvil SE RETIRA — tapaba
        // contenido en pantallas que no la necesitan. La paleta ⌘K sigue
        // en escritorio (sidebar) y teclado físico.
        Expanded(child: navigationShell),
      ],
    );

    // Contenido protegido del notch (TASK-35 · p2): el fondo ambiental
    // sigue de borde a borde, pero sidebar + columnas nacen BAJO la barra
    // de estado. En móvil el inset inferior lo consume la barra de tabs
    // (bottomNavigationBar): se anula aquí para que las sticky bars de
    // las pantallas no lo dupliquen; en escritorio el inset inferior es
    // de las pantallas (no hay barra debajo).
    final Widget content = wide
        ? Row(
            children: [
              _VeSidebar(
                current: current,
                onBranch: (i) => navigationShell.goBranch(
                  i,
                  initialLocation: i == current,
                ),
              ),
              Expanded(child: mainColumn),
            ],
          )
        : MediaQuery.removePadding(
            context: context,
            removeBottom: true,
            child: mainColumn,
          );

    return CallbackShortcuts(
      // ⌘K/Ctrl+K abre el command palette (firma SaaS · Linear/Vercel).
      bindings: <ShortcutActivator, VoidCallback>{
        const SingleActivator(LogicalKeyboardKey.keyK, control: true): () =>
            showCommandPalette(context),
        const SingleActivator(LogicalKeyboardKey.keyK, meta: true): () =>
            showCommandPalette(context),
      },
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        // Iconos de la barra de estado según el tema (sin AppBar que lo
        // haga): oscuro → iconos claros; claro → iconos oscuros.
        value: Theme.of(context).brightness == Brightness.dark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
        child: Scaffold(
          backgroundColor: scheme.surfaceContainerLowest,
          body: Stack(
            children: [
              // Fondo ambiental del prototipo: radiales pos/warn + puntos.
              const Positioned.fill(child: VeAmbient()),
              Positioned.fill(
                child: SafeArea(
                  // Abajo lo resuelven la barra de tabs (móvil) o las
                  // propias pantallas (escritorio).
                  bottom: false,
                  child: content,
                ),
              ),
            ],
          ),
          bottomNavigationBar: wide
              ? null
              : _MobileTabs(
                  current: current,
                  cartCount: _cartCount(context),
                  onTab: (i) => navigationShell.goBranch(
                    i,
                    initialLocation: i == current,
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

// ─────────────────────────────────────────────────────────── Sidebar ───────

/// Ítem del sidebar: pestaña principal (branch del shell) o ruta libre
/// (Tickets vive fuera del shell).
class _SideItem {
  const _SideItem({
    required this.icon,
    required this.label,
    required this.location,
    this.branch,
  });

  final IconData icon;
  final String label;
  final String location;

  /// Índice de branch del StatefulShellRoute; null → `go()` directo.
  final int? branch;
}

const List<_SideItem> _sideMain = [
  _SideItem(
      icon: LucideIcons.home, label: 'Inicio', location: '/', branch: 0),
  _SideItem(
      icon: LucideIcons.arrowLeftRight,
      label: 'Conversor',
      location: '/conversor',
      branch: 1),
  _SideItem(
      icon: LucideIcons.shoppingCart,
      label: 'Lista',
      location: '/lista',
      branch: 2),
  _SideItem(
      icon: LucideIcons.package,
      label: 'Productos',
      location: '/productos',
      branch: 3),
  _SideItem(
      icon: LucideIcons.chartColumn,
      label: 'Análisis',
      location: '/analisis',
      branch: 4),
];

const List<_SideItem> _sideLibro = [
  _SideItem(
      icon: LucideIcons.history,
      label: 'Historial',
      location: '/historial',
      branch: 5),
  _SideItem(
      icon: LucideIcons.receipt, label: 'Tickets', location: '/tickets'),
  _SideItem(
      icon: LucideIcons.settings,
      label: 'Ajustes',
      location: '/ajustes',
      branch: 6),
];

/// Sidebar de 224 px del prototipo (App.tsx): marca, búsqueda ⌘K, navegación
/// con indicador de tinta, sección «Libro» y pie con las tasas del país.
class _VeSidebar extends StatelessWidget {
  const _VeSidebar({required this.current, required this.onBranch});

  /// Branch activo del shell (0–6) o −1 si la ruta está fuera (Tickets).
  final int current;

  /// Cambia de branch del shell (pestañas y rutas internas).
  final ValueChanged<int> onBranch;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Container(
      width: 224,
      decoration: BoxDecoration(
        color: scheme.card.withValues(alpha: 0.92),
        border: Border(right: BorderSide(color: scheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Marca: 56 px, logo rombo + palabra.
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(bottom: BorderSide(color: scheme.border)),
            ),
            child: Row(
              children: [
                const VeLogo(size: 22),
                const SizedBox(width: 10),
                Text(
                  'ValoraVE',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    color: scheme.foreground,
                  ),
                ),
                const Spacer(),
                // Toggle de tema a la vista en escritorio (TASK-35 · p2):
                // mismo interruptor que la cabecera móvil de Inicio.
                const _SidebarThemeToggle(),
              ],
            ),
          ),
          // Búsqueda → command palette ⌘K.
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
            child: _SidebarSearch(onTap: () => showCommandPalette(context)),
          ),
          // Navegación: pestañas + sección «Libro».
          Expanded(
            child: ListView(
              padding: const EdgeInsets.all(8),
              children: [
                for (final item in _sideMain)
                  _SideNavButton(
                    item: item,
                    active: current == item.branch,
                    badge: item.branch == 2 ? _cartCount(context) : 0,
                    onTap: () => onBranch(item.branch!),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    10, 16, 10, 6,
                  ),
                  child: Text(
                    'LIBRO',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.84,
                      color: scheme.mutedForeground,
                    ),
                  ),
                ),
                for (final item in _sideLibro)
                  _SideNavButton(
                    item: item,
                    active: _isActive(context, item),
                    onTap: () => item.branch != null
                        ? onBranch(item.branch!)
                        : context.go(item.location),
                  ),
              ],
            ),
          ),
          // Pie de tasas del país + estado de red.
          const _SidebarRates(),
        ],
      ),
    );
  }

  int _cartCount(BuildContext context) {
    final store = context.watch<AppStore>();
    return store.cart.fold<int>(0, (acc, c) => acc + c.quantity);
  }

  /// Tickets vive fuera del shell: se compara la ruta actual.
  bool _isActive(BuildContext context, _SideItem item) {
    if (item.branch != null) return current == item.branch;
    final path = GoRouterState.of(context).uri.path;
    return path == item.location;
  }
}

/// Toggle de tema del sidebar (escritorio): sol/luna según el brillo
/// efectivo; un toque cambia al opuesto (mismo interruptor de Inicio).
class _SidebarThemeToggle extends StatelessWidget {
  const _SidebarThemeToggle();

  @override
  Widget build(BuildContext context) {
    final bool dark = veEffectiveDark(context);
    return VeIconBtn(
      icon: dark ? LucideIcons.sun : LucideIcons.moon,
      label: dark ? 'Tema claro' : 'Tema oscuro',
      size: 28,
      iconSize: 14,
      onTap: () => toggleVeTheme(context),
    );
  }
}

/// Logo del prototipo (Onboarding.tsx): rombo de tinta con núcleo de fondo.
class VeLogo extends StatelessWidget {
  const VeLogo({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final side = size * 34 / 48;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: 45 * 3.14159265 / 180,
            child: Container(
              width: side,
              height: side,
              decoration: BoxDecoration(
                color: scheme.foreground,
                borderRadius: BorderRadius.circular(size * 9 / 48),
              ),
            ),
          ),
          Container(
            width: size * 12 / 48,
            height: size * 12 / 48,
            decoration: BoxDecoration(
              color: scheme.background,
              shape: BoxShape.circle,
            ),
          ),
        ],
      ),
    );
  }
}

class _SidebarSearch extends StatelessWidget {
  const _SidebarSearch({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 32,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: scheme.background.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: scheme.border),
          ),
          child: Row(
            children: [
              Icon(LucideIcons.search, size: 13, color: scheme.mutedForeground),
              const SizedBox(width: 10),
              Text(
                'Buscar…',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: scheme.mutedForeground,
                ),
              ),
              const Spacer(),
              const VeKbd(label: '⌘K'),
            ],
          ),
        ),
      ),
    );
  }
}

class _SideNavButton extends StatelessWidget {
  const _SideNavButton({
    required this.item,
    required this.active,
    required this.onTap,
    this.badge = 0,
  });

  final _SideItem item;
  final bool active;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 32,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: active ? scheme.accent : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            children: [
              // Indicador de tinta (3 px × 16) del prototipo.
              if (active)
                Container(
                  width: 3,
                  height: 16,
                  margin: const EdgeInsets.only(right: 10),
                  decoration: BoxDecoration(
                    color: scheme.foreground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
              Icon(
                item.icon,
                size: 15,
                color: active ? scheme.foreground : scheme.mutedForeground,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: active ? scheme.foreground : scheme.mutedForeground,
                  ),
                ),
              ),
              if (badge > 0)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  decoration: BoxDecoration(
                    color: scheme.foreground,
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    '$badge',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: FontWeight.w600,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: scheme.background,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Pie del sidebar: dos tasas del país (tabular) + punto en vivo.
class _SidebarRates extends StatelessWidget {
  const _SidebarRates();

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final store = context.watch<AppStore>();
    final poller = context.watch<RatesPoller>();
    final items = tickerItems(store).take(2).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: scheme.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final it in items)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  Flexible(
                    child: Text(
                      it.label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 12,
                        color: scheme.mutedForeground,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    fmtNum(it.value),
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      fontFeatures: const [FontFeature.tabularFigures()],
                      color: scheme.foreground,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 2),
          Row(
            children: [
              VePulseDot(
                color: poller.offlineNet ? ink.warn : ink.pos,
                size: 6,
              ),
              const SizedBox(width: 6),
              Text(
                poller.offlineNet ? 'Sin red · última lectura' : 'En vivo',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: scheme.mutedForeground,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ──────────────────────────────────────────────────────── Tabs móviles ─────

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

/// Barra inferior móvil del prototipo: 5 pestañas planas, icono 20 + label
/// 10.5, activo en tinta / inactivo en faint, badge del carrito sobre el
/// icono. Altura flexible por accesibilidad (fix a11y heredado).
class _MobileTabs extends StatelessWidget {
  const _MobileTabs({
    required this.current,
    required this.cartCount,
    required this.onTab,
  });

  final int current;
  final int cartCount;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final bool dark = ShadTheme.of(context).brightness == Brightness.dark;
    final Color faint = dark ? VeColors.faintDark : VeColors.faintLight;

    return Container(
      key: kNavBarKey,
      decoration: BoxDecoration(
        color: scheme.card,
        border: Border(top: BorderSide(color: scheme.border)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (int i = 0; i < MainShell._tabs.length; i++)
              Expanded(
                child: _TabButton(
                  spec: MainShell._tabs[i],
                  active: i == current,
                  badge: i == 2 ? cartCount : 0,
                  activeColor: scheme.foreground,
                  inactiveColor: faint,
                  onTap: () => onTab(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends StatelessWidget {
  const _TabButton({
    required this.spec,
    required this.active,
    required this.onTap,
    required this.activeColor,
    required this.inactiveColor,
    this.badge = 0,
  });

  final _TabSpec spec;
  final bool active;
  final VoidCallback onTap;
  final Color activeColor;
  final Color inactiveColor;
  final int badge;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: active,
        label: spec.label,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: 58),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Stack(
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    spec.icon,
                    size: 20,
                    color: active ? activeColor : inactiveColor,
                  ),
                  if (badge > 0)
                    Positioned(
                      right: -6,
                      top: -4,
                      child: Container(
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: activeColor,
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          badge > 9 ? '9+' : '$badge',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 9.5,
                            fontWeight: FontWeight.w600,
                            color: ShadTheme.of(context).colorScheme.background,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                spec.label,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w500,
                  color: active ? activeColor : inactiveColor,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// (v20) FAB de búsqueda móvil retirado por orden del dueño: la lupa
// flotante tapaba contenido en pantallas que no la necesitaban.

// ────────────────────────────────────────────────────── Disparadores ───────

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
