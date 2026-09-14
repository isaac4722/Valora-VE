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
    initialLocation: store.settings.onboarded ? '/' : '/bienvenida',
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
          StatefulShellBranch(routes: [
            GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/conversor', builder: (_, _) => const ConverterScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/lista', builder: (_, _) => const ListaScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/productos', builder: (_, _) => const ProductsScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/analisis', builder: (_, _) => const InsightsScreen()),
          ]),
          // Rutas extra (sin tab, acceso por header/CTA).
          StatefulShellBranch(routes: [
            GoRoute(path: '/historial', builder: (_, _) => const HistoryScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/ajustes', builder: (_, _) => const SettingsScreen()),
          ]),
        ],
      ),
      GoRoute(path: '/legal', builder: (_, _) => const LegalScreen()),
      // Tickets (dp6): galería de fotos de recibos de las compras.
      GoRoute(path: '/tickets', builder: (_, _) => const TicketsScreen()),
      // Sala en vivo: PANTALLA COMPLETA (v17.2, decisión del dueño — no
      // vuelve a ser un sheet deslizable). v18.0: esta ruta es la
      // CONFIGURACIÓN de la sala; la sala EN VIVO tiene pantalla propia.
      GoRoute(path: '/sala', builder: (_, _) => const RoomScreen()),
      // Sala Viva (v18.0): la sala en vivo — código+QR, miembros con roles,
      // gobierno del anfitrión y regreso automático a la Lista.
      GoRoute(path: '/sala-viva', builder: (_, _) => const SalaVivaScreen()),
    ],
  );
}
