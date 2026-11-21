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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:valorave/core/models.dart';
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
import 'package:valorave/providers/providers.dart';

/// Carga las fuentes reales (Inter · SpaceGrotesk · JetBrains · Lucide ·
/// MaterialIcons) para que los goldens no salgan en Ahem.
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
  await _cargarMaterialIcons();
}

/// v23.3 (gate visual): MaterialIcons NO es un asset de la app — en tests la
/// familia cae a Ahem y TODOS los `Icons.*` salían como tofu □ en los goldens
/// (pestañas de Análisis, swap del Conversor, chevrons de moneda…). El OTF
/// vive en el caché del SDK: primero vía FLUTTER_ROOT (la variable que el
/// tool exporta a los tests) y si no, caminando hacia arriba desde el
/// ejecutable (flutter_tester vive en `<root>/bin/cache/artifacts/engine/…`);
/// si no aparece, se omite sin fallar (estado previo, no peor).
Future<void> _cargarMaterialIcons() async {
  try {
    final paths = <String>[];
    final envRoot = Platform.environment['FLUTTER_ROOT'];
    if (envRoot != null && envRoot.isNotEmpty) {
      paths.add(
        '$envRoot/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf',
      );
    }
    var dir = File(Platform.resolvedExecutable).parent;
    for (var i = 0; i < 7; i++) {
      paths.add(
        '${dir.path}/bin/cache/artifacts/material_fonts/'
        'MaterialIcons-Regular.otf',
      );
      dir = dir.parent;
    }
    File? otf;
    for (final p in paths) {
      final f = File(p);
      if (f.existsSync()) {
        otf = f;
        break;
      }
    }
    if (otf == null) return;
    final bytes = await otf.readAsBytes();
    final loader = FontLoader('MaterialIcons')
      ..addFont(Future<void>.value().then((_) => ByteData.sublistView(bytes)));
    await loader.load();
  } catch (_) {
    // Sin la fuente del SDK en esta máquina: la familia queda como estaba.
  }
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
          // Id REAL del paralelo (ves-parallel): con 'ves-paralelo' la
          // fila salía «sin tasa» en los goldens y el VLM lo marcaba.
          'ves-parallel': RateEntry(rate: 44.2, updatedAt: ahora),
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
          // Marcado: el golden enseña el tachado de comprado (gate VLM).
          checked: true,
          checkedBy: 'Yo',
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
      ProviderScope(
        overrides: [
          appStoreProvider.overrideWith((ref) => store, disposeNotifier: false),
          themeControllerProvider.overrideWith((ref) => ThemeController(), disposeNotifier: false),
          ratesPollerProvider.overrideWith((ref) => poller, disposeNotifier: false),
          sharedPreferencesProvider.overrideWithValue(prefs),
          roomControllerProvider.overrideWith((ref) => RoomController(store), disposeNotifier: false),
        ],
        child: MaterialApp.router(
                // v20: sin banner DEBUG — la cinta diagonal roja
                // ensuciaba los goldens (VLM la marcó como slop).
                debugShowCheckedModeBanner: false,
                theme: AppTheme.light(),
                routerConfig: router,
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
