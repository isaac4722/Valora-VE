/// ─── Router declarativo (GUI dp4: shell 5 pestañas móvil + 7 rutas) ─────────
/// home:/ · conversor:/conversor · lista:/lista · productos:/productos ·
/// análisis:/analisis · historial:/historial · ajustes:/ajustes
/// (+ push: sala, constancia, legal, ticket, actualizaciones).
/// v17.8: la pestaña Finanzas se retiró (orden del dueño) — los gastos
/// viven en Análisis → «Gastos», alimentados por las compras de Lista.
/// v30 (H-41/H-42): la ruta huérfana `/escanear` salió del router (el
/// escáner vive donde se usa: captura de Lista y ficha de Productos) y
/// las subpantallas de Ajustes murieron — solo `/ajustes/cuentas`
/// sobrevive como deep link (redirige a la pantalla única).
///
/// ⚠️ CONTRATO DE CICLO DE VIDA: el GoRouter se crea UNA SOLA VEZ por sesión
/// (desde ValoraApp, nunca dentro de build()) — recrearlo en cada rebuild
/// reseteaba la navegación a initialLocation y dejaba al usuario atrapado en
/// el onboarding (cada mutación del store — setCountry, tasas nuevas cada
/// 60 s — fabricaba un router nuevo). El estado `onboarded` se resuelve con
/// `refreshListenable` + `redirect`, el patrón canónico de go_router para
/// flujos de acceso: la navegación viva se conserva y el redirect solo
/// empuja /bienvenida ↔ / cuando de verdad cambia el flag.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/theme.dart';
import '../data/store.dart';
import '../features/actualizaciones/actualizaciones_screen.dart';
import '../features/converter/converter_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/legal/legal_screen.dart';
import '../features/more/more_screen.dart';
import '../features/lista/lista_screen.dart';
import '../features/products/products_screen.dart';
import '../features/rates/rates_screen.dart';
import '../features/room/room_screen.dart';
import '../features/room/sala_viva.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/tickets/tickets_screen.dart';
import '../features/welcome/welcome_screen.dart';

/// Claves para widget tests (GUI dp4) y anclas del tour (v17.8: GlobalKeys
/// reales — el motor del tour mide su rect en pantalla).
final GlobalKey kNavBarKey = GlobalKey(debugLabel: 'nav-bar');
final GlobalKey kHeaderActionsKey = GlobalKey(debugLabel: 'header-actions');
final GlobalKey kHeroRateKey = GlobalKey(debugLabel: 'hero-rate');

/// Rutas top-level válidas para deep link web (v24.1). Fuera de la lista
/// (rutas inexistentes o assets) el router decide con su mecanismo propio.
const Set<String> kDeepLinkRoutes = <String>{
  '/',
  '/bienvenida',
  '/conversor',
  '/lista',
  '/productos',
  '/analisis',
  '/historial',
  '/ajustes',
  '/mas',
  '/tasas',
  '/legal',
  '/actualizaciones',
  '/tickets',
  '/sala',
};

/// v24.1 — Normaliza la ruta de entrada del motor a una ruta de la app:
/// acepta «/conversor» y variantes con hash («#/conversor»), descarta
/// assets/query y devuelve null si no hay ruta profunda válida.
String? _deepRouteOf(String raw) {
  var ruta = raw.split('?').first.trim();
  if (ruta.startsWith('#')) ruta = ruta.substring(1);
  if (ruta.isEmpty || ruta == '/') return null;
  if (!ruta.startsWith('/')) return null;
  return kDeepLinkRoutes.contains(ruta) ? ruta : null;
}

/// v24.1 — Ruta con la que se ABRÓ la página en web, capturada en main()
/// antes del primer boot del framework (ver main.dart). Null = sin deep
/// link (arranque por '/' o en nativo).
String? webEntryRoute;

/// Captura la ruta de entrada desde la URL real del navegador. Se llama
/// UNA SOLA VEZ desde main() (kIsWeb guard en el llamador).
void captureWebEntryRoute(Uri base) {
  final ruta = base.hasScheme ? base.path : base.toString();
  webEntryRoute ??= _deepRouteOf(ruta);
}

/// Subpantallas de Ajustes retiradas (v30 · H-42): redirigen a la
/// pantalla única `/ajustes`.
const Set<String> _kAjustesLegacy = <String>{
  '/ajustes/general',
  '/ajustes/tasas',
  '/ajustes/apariencia',
  '/ajustes/datos',
};

GoRouter buildRouter({required AppStore store}) {
  // v24.1 — Deep link web: el histórico por defecto (hash) del framework
  // reescribe la URL (/conversor → '/') ANTES de que el router exista, así
  // que Uri.base llega tarde. La verdad de entrada es defaultRouteName: la
  // captura PRISTINA que el motor hizo de la URL al abrir la página. Con
  // ella explícita + overridePlatformDefaultLocation el eco de la sesión
  // previa ya no pisa el deep link.
  final String? entradaWeb = webEntryRoute;
  return GoRouter(
    // Deep link web (v20.3→v24.1): la ruta de arranque es la URL REAL del
    // navegador (explicita) o, en nativo, el mecanismo propio del router.
    // El gate de onboarding lo resuelve el redirect de abajo (nativo
    // incluido: sin URL el default es '/' y el redirect manda a /bienvenida
    // si falta).
    initialLocation: !store.settings.onboarded ? '/bienvenida' : entradaWeb,
    overridePlatformDefaultLocation: entradaWeb != null,
    // El store (ChangeNotifier) re-evalúa el redirect en cada mutación sin
    // perder el estado de navegación: onboarding 0→1 con setCountry ya no
    // rebota al paso 0, y el tutorial rejugable vuelve a enganchar solo.
    refreshListenable: store,
    redirect: (context, state) {
      final onboarded = store.settings.onboarded;
      final inWelcome = state.matchedLocation == '/bienvenida';
      if (!onboarded && !inWelcome) return '/bienvenida';
      if (onboarded && inWelcome) return '/';
      // v30 (H-42): las subpantallas de Ajustes murieron — sus rutas
      // redirigen a la pantalla única (deep links viejos incluidos).
      if (_kAjustesLegacy.contains(state.matchedLocation)) return '/ajustes';
      return null;
    },
    routes: [
      GoRoute(
        path: '/bienvenida',
        builder: (context, state) => const WelcomeScreen(),
      ),
      StatefulShellRoute.indexedStack(
        builder: (context, state, shell) => MainShell(navigationShell: shell),
        branches: [
          StatefulShellBranch(
            routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/conversor',
                builder: (_, _) => const ConverterScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/lista', builder: (_, _) => const ListaScreen()),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/analisis',
                builder: (_, _) => const InsightsScreen(),
              ),
            ],
          ),
          // v27: la quinta pestaña es el hub «Más» — el resto de módulos
          // vive a un toque y con buscador propio.
          StatefulShellBranch(
            routes: [
              GoRoute(path: '/mas', builder: (_, _) => const MoreScreen()),
            ],
          ),
          // Rutas extra (sin tab): se abren desde Más, el Inicio o el tour.
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/productos',
                builder: (_, _) => const ProductsScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/historial',
                builder: (_, _) => const HistoryScreen(),
              ),
            ],
          ),
          StatefulShellBranch(
            routes: [
              GoRoute(
                path: '/ajustes',
                builder: (_, _) => const SettingsScreen(),
              ),
            ],
          ),
        ],
      ),
      // v27 · Tasas: la cotización completa, fuera del Inicio.
      GoRoute(
        path: '/tasas',
        pageBuilder: (context, s) => vePage(context, s, const RatesScreen()),
      ),
      // v30 (H-42): deep link de cuentas — la pantalla única de Ajustes
      // con «Cuentas y cobro» PRIMERO. Las subpantallas v27
      // (general|tasas|apariencia|datos) redirigen arriba en el redirect.
      GoRoute(
        path: '/ajustes/cuentas',
        pageBuilder: (context, s) =>
            vePage(context, s, const SettingsScreen()),
      ),
      GoRoute(
        path: '/legal',
        pageBuilder: (context, s) => vePage(context, s, const LegalScreen()),
      ),
      // Actualizaciones del canal dev (v22.3): la app lee las Releases de
      // GitHub del propio repo y ofrece descargar el APK de cada ronda.
      GoRoute(
        path: '/actualizaciones',
        pageBuilder: (context, s) =>
            vePage(context, s, const ActualizacionesScreen()),
      ),
      // Tickets (dp6): galería de fotos de recibos de las compras.
      GoRoute(
        path: '/tickets',
        pageBuilder: (context, s) => vePage(context, s, const TicketsScreen()),
      ),
      // Sala en vivo: PANTALLA COMPLETA (v17.2, decisión del dueño — no
      // vuelve a ser un sheet deslizable). v18.0: esta ruta es la
      // CONFIGURACIÓN de la sala; la sala EN VIVO tiene pantalla propia.
      GoRoute(
        path: '/sala',
        pageBuilder: (context, s) => vePage(context, s, const RoomScreen()),
      ),
      // Sala Viva (v18.0): la sala en vivo — código+QR, miembros con roles,
      // gobierno del anfitrión y regreso automático a la Lista.
      GoRoute(
        path: '/sala-viva',
        pageBuilder: (context, s) => vePage(context, s, const SalaVivaScreen()),
      ),
    ],
  );
}

/// ─── Transición unificada de pantallas EMPUJADAS (v21.2) ───────────────────
/// Las rutas fuera del shell (legal, tickets, sala, sala-viva) comparten un
/// solo gesto: fade + subida de 10 px con el easing propio de la app
/// (kEaseVe, 220 ms — el mismo del resto del sistema). Antes cada push usaba
/// la transición por defecto de la plataforma y la app se sentía distinta
/// según el sistema. Las TABS del shell quedan INTACTAS (IndexedStack sin
/// transición — el cambio de pestaña es instantáneo por diseño) y el test de
/// notch del dueño no se toca.
CustomTransitionPage<void> vePage(
  BuildContext context,
  GoRouterState state,
  Widget child,
) {
  return CustomTransitionPage<void>(
    key: state.pageKey,
    child: child,
    transitionDuration: const Duration(milliseconds: 220),
    reverseTransitionDuration: const Duration(milliseconds: 180),
    transitionsBuilder: (context, animation, reverse, child) {
      final curved = CurvedAnimation(parent: animation, curve: kEaseVe);
      return FadeTransition(
        opacity: curved,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.03),
            end: Offset.zero,
          ).animate(curved),
          child: child,
        ),
      );
    },
  );
}
