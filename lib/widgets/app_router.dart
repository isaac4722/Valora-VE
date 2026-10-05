/// ─── Router declarativo (GUI dp4: shell 5 pestañas móvil + 7 rutas) ─────────
/// home:/ · conversor:/conversor · lista:/lista · productos:/productos ·
/// análisis:/analisis · historial:/historial · ajustes:/ajustes
/// (+ push: sala, constancia, escáner, legal, ticket).
/// v17.8: la pestaña Finanzas se retiró (orden del dueño) — los gastos
/// viven en Análisis → «Gastos», alimentados por las compras de Lista.
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
import '../features/converter/converter_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/legal/legal_screen.dart';
import '../features/lista/lista_screen.dart';
import '../features/products/products_screen.dart';
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

GoRouter buildRouter({required AppStore store}) {
  return GoRouter(
    // Deep link web (v20.3): go_router solo restaura la URL del navegador
    // cuando NO se pasa initialLocation — pasarla siempre mandaba cualquier
    // ruta profunda (/conversor, /sala…) de vuelta a Inicio. El gate de
    // onboarding lo resuelve el redirect de abajo (nativo incluido: sin URL
    // el default es '/' y el redirect manda a /bienvenida si falta).
    initialLocation: store.settings.onboarded ? null : '/bienvenida',
    // El store (ChangeNotifier) re-evalúa el redirect en cada mutación sin
    // perder el estado de navegación: onboarding 0→1 con setCountry ya no
    // rebota al paso 0, y el tutorial rejugable vuelve a enganchar solo.
    refreshListenable: store,
    redirect: (context, state) {
      final onboarded = store.settings.onboarded;
      final inWelcome = state.matchedLocation == '/bienvenida';
      if (!onboarded && !inWelcome) return '/bienvenida';
      if (onboarded && inWelcome) return '/';
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
                path: '/productos',
                builder: (_, _) => const ProductsScreen(),
              ),
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
          // Rutas extra (sin tab, acceso por header/CTA).
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
      GoRoute(
        path: '/legal',
        pageBuilder: (context, s) => vePage(context, s, const LegalScreen()),
      ),
      // Tickets (dp6): galería de fotos de recibos de las compras.
      GoRoute(
        path: '/tickets',
        pageBuilder: (context, s) =>
            vePage(context, s, const TicketsScreen()),
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
        pageBuilder: (context, s) =>
            vePage(context, s, const SalaVivaScreen()),
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
