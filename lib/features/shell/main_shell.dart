/// ─── Shell «Ve» · sidebar desktop + tabs móviles del prototipo (TASK-34) ──
/// Port del App.tsx de referencia: en escritorio (≥700 px) sidebar de 224 px
/// con marca, búsqueda ⌘K, navegación de 5 pestañas + sección «Libro»
/// (Historial · Tickets · Ajustes) y pie de tasas con punto en vivo; en móvil
/// barra inferior de 5 pestañas plana (tinta activa / faint inactivo) y FAB
/// de búsqueda flotante — oculto en las pantallas con búsqueda propia, como
/// el original. El fondo ambiental (radiales + puntos) vive detrás de todo.
/// Estado real intacto: banner de salud, campana del centro de
/// notificaciones, badge del carrito y anclas del tour
/// (kNavBarKey · kHeaderActionsKey).
/// v26 (orden del dueño): la CINTA de cotizaciones de Inicio SE RETIRA —
/// las tasas ya viven en la Cotización y el papel gana su espacio; sus
/// tres ajustes (modo/tamaño/velocidad) salieron con ella.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../state/app_state.dart';
import '../../widgets/app_tour.dart';
import '../../widgets/cache_banner.dart';
import '../../widgets/ui.dart';
import 'command_palette.dart';
import '../../widgets/app_router.dart' show kNavBarKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorave/providers/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:valorave/core/ve_theme.dart';

/// Ítems de tasas del PIE del sidebar (escritorio): fuentes protagonistas
/// del país + arista EUR cuando el país es VE. (v26: la cinta del Inicio
/// se retiró con sus modos — este listado alimenta solo las dos filas
/// del pie del sidebar, siempre las mismas.)
List<({Currency flag, String label, double value, String unit, bool isEur})>
tickerItems(AppStore store) {
  final b = store.board;
  final items =
      <
        ({Currency flag, String label, double value, String unit, bool isEur})
      >[];

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

/// Umbral de escritorio: sidebar a partir de 700 px (md del prototipo).
const double kWideShell = 700;

/// ¿El brillo EFECTIVO es oscuro? (resuelve `system` contra la plataforma).
/// Para pintar el icono del toggle de tema donde se necesite.
bool veEffectiveDark(WidgetRef ref) {
  final mode = ref.watch(themeControllerProvider).mode;
  if (mode != ThemeMode.system) return mode == ThemeMode.dark;
  return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
      Brightness.dark;
}

/// Alterna claro ↔ oscuro (TASK-35 · p2 · orden del dueño): vuelve el botón
/// de tema de la cabecera. Resuelve el brillo EFECTIVO (system incluido) y
/// fija el opuesto explícito — un toque hace lo que el ojo espera.
void toggleVeTheme(WidgetRef ref) {
  final theme = ref.read(themeControllerProvider);
  final prefs = ref.read(sharedPreferencesProvider);
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
class MainShell extends ConsumerWidget {
  const MainShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  static const List<_TabSpec> _tabs = [
    _TabSpec(location: '/', icon: LucideIcons.home, label: 'Inicio'),
    _TabSpec(
      location: '/conversor',
      icon: LucideIcons.arrowLeftRight,
      // v22.0 (GUI clara · orden del dueño): la pestaña móvil decía
      // «Divisas» pero la ruta, el sidebar y la paleta dicen «Conversor»
      // — un solo nombre para la misma pantalla.
      label: 'Conversor',
    ),
    _TabSpec(
      location: '/lista',
      icon: LucideIcons.shoppingCart,
      label: 'Lista',
    ),
    _TabSpec(
      location: '/analisis',
      icon: LucideIcons.chartColumn,
      label: 'Análisis',
    ),
    // v27: la quinta pestaña es «Más» — el hub con buscador que reúne
    // Productos, Historial, Tickets, Sala, Cuentas y Ajustes.
    _TabSpec(location: '/mas', icon: LucideIcons.layoutGrid, label: 'Más'),
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final int current = navigationShell.currentIndex;
    // Rate-health (§5): el banner se monta SIEMPRE encima del body y decide
    // solo su visibilidad (rateStale = se vio tablero OK hace >15 min).
    final RatesPoller poller = ref.watch(ratesPollerProvider);
    // v22.0 (rendimiento): el shell solo observa los CAMBIOS que pinta —
    // antes watch<AppStore>() reconstruía TODO el shell (Scaffold, fondo
    // ambiental, tabs) en cada mutación del store: cada tap del carrito,
    // cada tecla del conversor, cada tick del poller. Ahora solo se
    // reconstruye cuando cambia el país, el modo offline o el CONTADOR del
    // carrito (los pantallazos se suscriben por su cuenta).
    final String country = ref.watch(
      appStoreProvider.select((s) => s.settings.country),
    );
    final bool chosenOffline = ref.watch(
      appStoreProvider.select((s) => s.settings.offlineMode),
    );
    final int cartCount = ref.watch(
      appStoreProvider.select(
        (s) => s.cart.fold<int>(0, (acc, c) => acc + c.quantity),
      ),
    );

    // v19 (orden del dueño): la tasa MANUAL es una tasa personalizada, NO un
    // estado «sin conexión». Si la fuente activa del país es manual — o el
    // usuario eligió no consultar APIs — el banner de salud no aparece.
    final countryCur = CountryX.from(country).currency;
    final sourceId = ref.watch(
      appStoreProvider.select((s) => s.sourceFor(countryCur)),
    );
    final manualActive =
        RateSource.of(sourceId)?.category == SourceCategory.manual;
    final showHealth = !manualActive && !chosenOffline;

    final bool wide =
        MediaQuery.sizeOf(context).width >= kWideShell &&
        // v26 (dispositivos nuevos): en un móvil GIRADO el alto útil es
        // corto (~320-430 px) — el sidebar de 224 px se comería el ancho
        // del paisaje. Con pestañas inferiores el Conversor puede repartir
        // cifras + teclado en dos paneles con espacio de verdad. El sidebar
        // es para pantallas holgadas en AMBOS ejes: tablets, plegables
        // abiertos y escritorio.
        MediaQuery.sizeOf(context).height >= 500;

    // Columna principal compartida: banner de salud + área de navegación.
    final Widget mainColumn = Column(
      children: [
        const CacheModeBanner(),
        AnimatedSize(
          duration: kLayoutDur,
          curve: kEaseVe,
          alignment: Alignment.topCenter,
          child: showHealth
              ? RateHealthBanner(
                  stale: poller.rateStale,
                  offline: poller.offlineNet,
                  onRetry: poller.offlineNet ? null : () => poller.refreshNow(),
                )
              : const SizedBox(width: double.infinity),
        ),
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
                onBranch: (i) =>
                    navigationShell.goBranch(i, initialLocation: i == current),
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
          // v25 «HOJA»: fondo PLANO — fuera el ambiente (radiales/puntos),
          // la pantalla es una hoja de papel continua.
          body: SafeArea(
            // Abajo lo resuelven la barra de tabs (móvil) o — v26 — el
            // propio SafeArea en modo ancho: en un móvil girado con
            // sidebar la barra de gestos queda bajo el contenido, no
            // encima. En escritorio el inset es 0 (no-op).
            bottom: wide,
            child: content,
          ),
          bottomNavigationBar: wide
              ? null
              : _MobileTabs(
                  current: current,
                  cartCount: cartCount,
                  onTab: (i) {
                    // v21.2: confirmación táctil del cambio de pestaña —
                    // vibración sutil (no-op en web). El layout del shell
                    // NO se toca (test de notch = guardián).
                    HapticFeedback.selectionClick();
                    navigationShell.goBranch(i, initialLocation: i == current);
                  },
                ),
        ),
      ),
    );
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
  _SideItem(icon: LucideIcons.home, label: 'Inicio', location: '/', branch: 0),
  _SideItem(
    icon: LucideIcons.arrowLeftRight,
    label: 'Conversor',
    location: '/conversor',
    branch: 1,
  ),
  _SideItem(
    icon: LucideIcons.shoppingCart,
    label: 'Lista',
    location: '/lista',
    branch: 2,
  ),
  _SideItem(
    icon: LucideIcons.chartColumn,
    label: 'Análisis',
    location: '/analisis',
    branch: 3,
  ),
];

const List<_SideItem> _sideLibro = [
  _SideItem(
    icon: LucideIcons.package,
    label: 'Productos',
    location: '/productos',
    branch: 5,
  ),
  _SideItem(
    icon: LucideIcons.history,
    label: 'Historial',
    location: '/historial',
    branch: 6,
  ),
  _SideItem(icon: LucideIcons.receipt, label: 'Tickets', location: '/tickets'),
  _SideItem(
    icon: LucideIcons.settings,
    label: 'Ajustes',
    location: '/ajustes',
    branch: 7,
  ),
];

/// Sidebar de 224 px del prototipo (App.tsx): marca, búsqueda ⌘K, navegación
/// con indicador de tinta, sección «Libro» y pie con las tasas del país.
class _VeSidebar extends ConsumerWidget {
  const _VeSidebar({required this.current, required this.onBranch});

  /// Branch activo del shell (0–6) o −1 si la ruta está fuera (Tickets).
  final int current;

  /// Cambia de branch del shell (pestañas y rutas internas).
  final ValueChanged<int> onBranch;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.ve.colorScheme;
    // v25 «HOJA»: sidebar TRANSPARENTE sobre el papel con hairline derecho
    // al 65 % — filas de texto plano, sin relleno ambiental.
    return Container(
      width: 224,
      decoration: BoxDecoration(
        border: Border(
          right: BorderSide(color: scheme.border.withValues(alpha: 0.65)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Marca: 56 px, logo rombo + palabra.
          Container(
            height: 56,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              border: Border(
                bottom: BorderSide(
                  color: scheme.border.withValues(alpha: 0.65),
                ),
              ),
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
                    badge: item.branch == 2 ? _cartCount(ref) : 0,
                    onTap: () => onBranch(item.branch!),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(10, 16, 10, 6),
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

  int _cartCount(WidgetRef ref) {
    // v22.0: select del CONTADOR — el sidebar no se reconstruye con el
    // store entero, solo cuando cambia la cantidad visible del badge.
    return ref.watch(
      appStoreProvider.select(
        (s) => s.cart.fold<int>(0, (acc, c) => acc + c.quantity),
      ),
    );
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
class _SidebarThemeToggle extends ConsumerWidget {
  const _SidebarThemeToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bool dark = veEffectiveDark(ref);
    return VeIconBtn(
      icon: dark ? LucideIcons.sun : LucideIcons.moon,
      label: dark ? 'Tema claro' : 'Tema oscuro',
      size: 28,
      iconSize: 14,
      onTap: () => toggleVeTheme(ref),
    );
  }
}

/// Logo del prototipo (Onboarding.tsx): rombo de tinta con núcleo de fondo.
class VeLogo extends ConsumerWidget {
  const VeLogo({super.key, this.size = 22});

  final double size;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.ve.colorScheme;
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

class _SidebarSearch extends ConsumerWidget {
  const _SidebarSearch({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.ve.colorScheme;
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          // v25 «HOJA»: tonal muted SIN borde (píldora secundaria).
          decoration: BoxDecoration(
            color: scheme.muted,
            borderRadius: BorderRadius.circular(999),
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

class _SideNavButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.ve.colorScheme;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: Container(
          height: 36,
          margin: const EdgeInsets.only(bottom: 2),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          // v25 «HOJA»: fila de texto PLANA — el activo se lee por la tinta
          // plena y el indicador, sin píldora de fondo.
          decoration: const BoxDecoration(),
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
class _SidebarRates extends ConsumerWidget {
  const _SidebarRates();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.ve.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final store = ref.watch(appStoreProvider);
    final poller = ref.watch(ratesPollerProvider);
    final items = tickerItems(store).take(2).toList();

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: scheme.border.withValues(alpha: 0.65)),
        ),
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
class _MobileTabs extends ConsumerWidget {
  const _MobileTabs({
    required this.current,
    required this.cartCount,
    required this.onTab,
  });

  final int current;
  final int cartCount;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // v25 «HOJA»: barra plana — papel sólido (tapa el scroll) + hairline
    // superior al 65 %; SIN píldora de indicador, SIN sombra.
    final scheme = context.ve.colorScheme;

    // v27: en las rutas sin pestaña propia (Productos · Historial ·
    // Ajustes) la barra marca «Más», que es la puerta desde la que se llegó.
    final int effective = current >= 4 ? 4 : current;
    return Container(
      key: kNavBarKey,
      decoration: BoxDecoration(
        color: scheme.background,
        border: Border(
          top: BorderSide(color: scheme.border.withValues(alpha: 0.65)),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            for (int i = 0; i < MainShell._tabs.length; i++)
              Expanded(
                child: _TabButton(
                  spec: MainShell._tabs[i],
                  active: i == effective,
                  badge: i == 2 ? cartCount : 0,
                  activeColor: scheme.foreground,
                  inactiveColor: scheme.onSurfaceVariant,
                  onTap: () => onTab(i),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _TabButton extends ConsumerWidget {
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
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.ve.colorScheme;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Semantics(
        button: true,
        selected: active,
        label: spec.label,
        // v21.1: píldora activa — el tab vivo se apoya en `--subtle`
        // (scheme.secondary) con la curva firma; el inactivo queda plano.
        //
        // ESTRUCTURA SENSIBLE: aquí NADA puede expandirse al alto ofertado
        // (Scaffold → bottomNavigationBar pasa constraints holgadas hasta
        // el alto completo). Un Container/Align/Center con alignment se
        // expandiría y dejaba el body en 0 px — el bug que el test de
        // notch caza. Por eso la píldora es decoración pura dentro del
        // ConstrainedBox de siempre y el Padding la hace respirar.
        child: Padding(
          padding: const EdgeInsets.fromLTRB(6, 7, 6, 5),
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 64),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              curve: kEaseVe,
              // v25 «HOJA»: SIN píldora de indicador — el tab vivo se lee
              // solo por la tinta (plena vs muted) y el peso del label.
              decoration: const BoxDecoration(),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Stack(
                    clipBehavior: Clip.none,
                    children: [
                      Icon(
                        spec.icon,
                        size: 22,
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
                                color: scheme.background,
                              ),
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(
                    spec.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 10.5,
                      fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                      color: active ? activeColor : inactiveColor,
                    ),
                  ),
                ],
              ),
            ),
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
class _TourTrigger extends ConsumerStatefulWidget {
  const _TourTrigger();

  @override
  ConsumerState<_TourTrigger> createState() => _TourTriggerState();
}

class _TourTriggerState extends ConsumerState<_TourTrigger> {
  @override
  void initState() {
    super.initState();
    // Post-frame: el layout del shell ya existe — las anclas del primer
    // segmento se pueden medir.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      maybeRunTourOnce(context, ref);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
