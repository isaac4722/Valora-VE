/// ─── Router declarativo (GUI simple: shell 5 pestañas + 9 ramas) ────────
/// home:/ · conversor:/conversor · lista:/lista · productos:/productos ·
/// mas:/mas (hub) · finanzas:/finanzas · análisis:/analisis ·
/// historial:/historial · ajustes:/ajustes (+ push: sala, constancia,
/// escáner, legal, ticket).
/// Design doc: docs/designs/2026-11-20-gui-simple.md — /mas se inserta como
/// rama índice 4 para que el mapeo tab↔rama sea 1:1 en las pestañas 0-3.
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
import '../features/finance/finance_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/legal/legal_screen.dart';
import '../features/lista/lista_screen.dart';
import '../features/more/more_screen.dart';
import '../features/products/products_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/welcome/welcome_screen.dart';

/// Claves para widget tests (GUI dp4).
const kNavBarKey = Key('nav-bar');
const kHeaderActionsKey = Key('header-actions');

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
          // Hub «Más» (índice 4): Finanzas/Análisis/Historial/Ajustes salen del
          // navbar y viven aquí; el tab «Más» se resalta también en sus ramas.
          StatefulShellBranch(routes: [
            GoRoute(path: '/mas', builder: (_, _) => const MoreScreen()),
          ]),
          StatefulShellBranch(routes: [
            GoRoute(path: '/finanzas', builder: (_, _) => const FinanceScreen()),
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
    ],
  );
}
