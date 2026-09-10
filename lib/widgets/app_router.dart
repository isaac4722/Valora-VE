/// ─── Router declarativo (GUI dp4: shell 6 pestañas móvil + 8 rutas) ─────────
/// home:/ · conversor:/conversor · lista:/lista · productos:/productos ·
/// historial:/historial · finanzas:/finanzas · análisis:/analisis ·
/// ajustes:/ajustes (+ push: sala, constancia, escáner, legal, ticket).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../features/converter/converter_screen.dart';
import '../features/finance/finance_screen.dart';
import '../features/history/history_screen.dart';
import '../features/home/home_screen.dart';
import '../features/insights/insights_screen.dart';
import '../features/legal/legal_screen.dart';
import '../features/lista/lista_screen.dart';
import '../features/products/products_screen.dart';
import '../features/settings/settings_screen.dart';
import '../features/shell/main_shell.dart';
import '../features/welcome/welcome_screen.dart';

/// Claves para widget tests (GUI dp4).
const kNavBarKey = Key('nav-bar');
const kHeaderActionsKey = Key('header-actions');

GoRouter buildRouter({required bool onboarded}) {
  return GoRouter(
    initialLocation: onboarded ? '/' : '/bienvenida',
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
