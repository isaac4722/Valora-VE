/// ─── VISUAL GATE · capturas del shell «Ve» (TASK-34 · temporal) ─────────────
/// Estado 3.5 del ciclo: monta el SHELL REAL (MainShell) con las pantallas
/// reales vía StatefulShellRoute y captura goldens con fuentes reales para
/// auditar contra slop con VLM. BORRAR tras el gate (AGENT.md 3.5).
///
/// Uso: flutter test scripts/visual_gate/visual_gate_test.dart
/// Genera: goldens/vg_*.png (móvil 390×844 · escritorio 1280×860 · claro).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:valorave/core/models.dart';
import 'package:valorave/core/shad_theme.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/converter/converter_screen.dart';
import 'package:valorave/features/home/home_screen.dart';
import 'package:valorave/features/insights/insights_screen.dart';
import 'package:valorave/features/lista/lista_screen.dart';
import 'package:valorave/features/products/products_screen.dart';
import 'package:valorave/features/shell/main_shell.dart';
import 'package:valorave/room/room_controller.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:valorave/widgets/app_tour.dart' show kTourDoneKey;

/// Carga las fuentes reales (Inter · Space Grotesk · JetBrains · Lucide) para
/// que los goldens no salgan en Ahem.
Future<void> _cargarFuentes() async {
  Future<void> una(String family, List<Future<ByteData>> assets) async {
    final loader = FontLoader(family);
    for (final a in assets) {
      loader.addFont(a);
    }
    await loader.load();
  }

  final root = rootBundle;
  await una('Inter', [
    root.load('assets/fonts/Inter-Regular.ttf'),
    root.load('assets/fonts/Inter-Medium.ttf'),
    root.load('assets/fonts/Inter-SemiBold.ttf'),
    root.load('assets/fonts/Inter-Bold.ttf'),
  ]);
  await una('SpaceGrotesk', [
    root.load('assets/fonts/SpaceGrotesk-Medium.ttf'),
    root.load('assets/fonts/SpaceGrotesk-Bold.ttf'),
  ]);
  await una('JetBrainsMono', [root.load('assets/fonts/JetBrainsMono.ttf')]);
  await una('packages/lucide_icons_flutter/Lucide', [
    root.load('packages/lucide_icons_flutter/assets/lucide.ttf'),
  ]);
}

/// Store honesto con datos de muestra: tablero VE (BCV + paralelo), dos
/// productos con precios, carrito con 2 ítems y modo offline (cero ruido de
/// red en las capturas).
AppStore _storeConDatos() {
  final ahora = DateTime(2026, 10, 1, 11, 30);

  PriceRecord precio(double p, String t) => PriceRecord(
    id: 'r$t',
    price: p,
    originalPrice: p,
    currency: 'USD',
    quantity: 1,
    store: t,
    rate: 1,
    sourceId: 'manual',
    date: ahora,
  );
  final arroz = Product(
    id: 'p1',
    name: 'Arroz 1 kg',
    category: ProductCategory.alimentos,
    presentation: Presentation.pack,
    size: 1000,
    sizeUnit: 'g',
    createdAt: ahora,
    records: [precio(1.85, 'Bodegón Central'), precio(2.10, 'Mercadito')],
    targetPrice: 1.9,
    targetCurrency: 'USD',
  );
  final leche = Product(
    id: 'p2',
    name: 'Leche en polvo 1 kg',
    category: ProductCategory.alimentos,
    presentation: Presentation.pack,
    size: 1000,
    sizeUnit: 'g',
    createdAt: ahora,
    records: [precio(6.4, 'Mercadito')],
  );
  return AppStore.withData(
    AppData(
      board: RateBoard(
        sources: {
          'ves-bcv': RateEntry(rate: 36.51, updatedAt: ahora),
          'ves-paralelo': RateEntry(rate: 44.2, updatedAt: ahora),
        },
        providers: const ['ve.dolarapi.com'],
        lastUpdate: ahora,
        fetchedAt: ahora,
      ),
      products: [arroz, leche],
      cart: [
        CartItem(
          id: 'c1',
          productId: 'p1',
          name: 'Arroz 1 kg',
          quantity: 2,
          price: 1.85,
          currency: 'USD',
        ),
        CartItem(
          id: 'c2',
          name: 'Pan de sandwich',
          quantity: 1,
          price: 2.3,
          currency: 'USD',
        ),
      ],
      settings: const Settings(onboarded: true, offlineMode: true),
    ),
  );
}

void main() {
  final Directory out = Directory('goldens')..createSync(recursive: true);

  setUpAll(_cargarFuentes);

  Future<void> captura(
    WidgetTester tester, {
    required String nombre,
    required Size size,
    required String ruta,
  }) async {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _storeConDatos();
    // Harness de captura manual (se corre con `flutter test scripts/…`):
    // llamada legítima a la API de pruebas fuera de test/ — falso positivo
    // del hint visibleForTesting en este archivo.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(kTourDoneKey, true);
    final poller = RatesPoller(
      store,
      NotificationsService(),
      AlertEngine(prefs),
    );

    final router = GoRouter(
      initialLocation: ruta,
      routes: [
        StatefulShellRoute.indexedStack(
          builder: (_, _, shell) => MainShell(navigationShell: shell),
          branches: [
            StatefulShellBranch(
              routes: [
                GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
              ],
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
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/historial',
                  builder: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
            StatefulShellBranch(
              routes: [
                GoRoute(
                  path: '/ajustes',
                  builder: (_, _) => const SizedBox.shrink(),
                ),
              ],
            ),
          ],
        ),
      ],
    );

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider.value(value: poller),
          Provider<SharedPreferences>.value(value: prefs),
          ChangeNotifierProvider(create: (_) => RoomController(store)),
        ],
        child: ShadApp.custom(
          theme: ShadThemeVe.light(),
          darkTheme: ShadThemeVe.dark(),
          appBuilder: (context) =>
              MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 600));
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('${out.path}/$nombre.png'),
    );
  }

  testWidgets('VG móvil · inicio', (tester) async {
    await captura(
      tester,
      nombre: 'vg_movil_inicio',
      size: const Size(390, 844),
      ruta: '/',
    );
  });

  testWidgets('VG escritorio · inicio con sidebar', (tester) async {
    await captura(
      tester,
      nombre: 'vg_desktop_inicio',
      size: const Size(1280, 860),
      ruta: '/',
    );
  });

  testWidgets('VG móvil · lista', (tester) async {
    await captura(
      tester,
      nombre: 'vg_movil_lista',
      size: const Size(390, 844),
      ruta: '/lista',
    );
  });

  testWidgets('VG móvil · conversor', (tester) async {
    await captura(
      tester,
      nombre: 'vg_movil_conversor',
      size: const Size(390, 844),
      ruta: '/conversor',
    );
  });

  testWidgets('VG escritorio · productos', (tester) async {
    await captura(
      tester,
      nombre: 'vg_desktop_productos',
      size: const Size(1280, 860),
      ruta: '/productos',
    );
  });

  testWidgets('VG móvil · análisis', (tester) async {
    await captura(
      tester,
      nombre: 'vg_movil_analisis',
      size: const Size(390, 844),
      ruta: '/analisis',
    );
  });
}
