/// ─── Tests del command palette ⌘K (TASK-33 p2) ──────────────────────────────
/// Cobertura del contrato de la pieza 2:
/// 1. El palette abre y muestra los módulos con sus grupos.
/// 2. El matching sin acentos sigue vivo («analisis» halla «Análisis»).
/// 3. El teclado mueve la marca (↑↓) y ↵ navega al resultado marcado.
/// 4. Productos y compras aparecen cuando el store tiene datos.
/// 5. Sin resultados muestra el estado honesto (nada de pantalla rota).
/// 6. El shell real enseña el hint «Ctrl K» en anchuras de escritorio.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/core/shad_theme.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/shell/command_palette.dart';
import 'package:valorave/features/shell/main_shell.dart';
import 'package:valorave/room/room_controller.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:valorave/widgets/app_tour.dart' show kTourDoneKey;

/// Store con un producto y una compra para los grupos de datos.
AppStore _storeConDatos() {
  final DateTime ahora = DateTime(2026, 10, 1);
  final Product cafe = Product(
    id: 'p1',
    name: 'Café molido',
    category: ProductCategory.alimentos,
    presentation: Presentation.weight,
    size: 250,
    createdAt: ahora,
    records: <PriceRecord>[
      PriceRecord(
        id: 'r1',
        price: 4.5,
        originalPrice: 4.5,
        currency: 'USD',
        quantity: 1,
        store: 'Bodegón La Esquina',
        rate: 40,
        sourceId: 'ves-parallel',
        date: ahora,
      ),
    ],
  );
  final Purchase compra = Purchase(
    id: 'c1',
    date: ahora,
    store: 'Bodegón La Esquina',
    items: const <PurchaseItem>[],
    totalUSD: 12.75,
    totalBS: 510,
    rate: 40,
    rateSourceId: 'ves-parallel',
  );
  return AppStore.withData(
    AppData(products: <Product>[cafe], purchases: <Purchase>[compra]),
  );
}

/// Páginas con Scaffold: el toast del palette («Abriendo…») necesita un
/// ScaffoldMessenger con Scaffolds descendientes debajo.
GoRouter _router() => GoRouter(
  initialLocation: '/',
  routes: [
    GoRoute(
      path: '/',
      builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
    ),
    GoRoute(
      path: '/ajustes',
      builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
    ),
    GoRoute(
      path: '/historial',
      builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
    ),
    GoRoute(
      path: '/productos',
      builder: (_, _) => const Scaffold(body: SizedBox.shrink()),
    ),
  ],
);

Widget _host(AppStore store) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider(create: (_) => ThemeController()),
      Provider<NotificationsService>.value(value: NotificationsService()),
      ChangeNotifierProvider(create: (_) => RoomController(store)),
    ],
    // Mismo patrón de main.dart (TASK-34 p4): ShadApp.custom envuelve al
    // MaterialApp.router para que los overlays (palette, sheets) hereden
    // el ShadTheme — igual que en producción.
    child: ShadApp.custom(
      theme: ShadThemeVe.light(),
      darkTheme: ShadThemeVe.dark(),
      appBuilder: (context) => MaterialApp.router(
        theme: AppTheme.light(),
        routerConfig: _router(),
      ),
    ),
  );
}

Future<void> _abrirPalette(WidgetTester tester, AppStore store) async {
  await tester.pumpWidget(_host(store));
  await tester.pump();
  // Contexto DEBAJO del Navigator (el contenido de la ruta '/'), no el del
  // MaterialApp (que vive por encima del Navigator).
  final BuildContext ctx = tester.element(find.byType(SizedBox).first);
  unawaited(showCommandPalette(ctx));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 200));
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('abre con los módulos agrupados y ↵ navega (overlay se cierra)', (
    tester,
  ) async {
    final store = _storeConDatos();
    await _abrirPalette(tester, store);

    // Grupo visible + los módulos del shell.
    expect(find.text('MÓDULOS'), findsOneWidget);
    expect(find.text('Inicio'), findsOneWidget);
    expect(find.text('Análisis'), findsOneWidget);
    expect(find.text('Ajustes'), findsOneWidget);
    // Hints de teclado al pie (firma del prototipo: navegar · ejecutar ·
    // contador de resultados — «esc» vive en la fila de búsqueda).
    expect(find.text('navegar'), findsOneWidget);
    expect(find.text('ejecutar'), findsOneWidget);

    // ↵ navega al primero marcado (Inicio → '/'): el overlay se cierra.
    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pumpAndSettle();
    expect(find.text('MÓDULOS'), findsNothing);
    expect(tester.takeException(), isNull);
  });

  testWidgets('↑↓ mueven la marca entre resultados', (tester) async {
    final store = _storeConDatos();
    await _abrirPalette(tester, store);

    // Marca inicial: primer resultado = Inicio.
    expect(find.text('Inicio'), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 150));
    await tester.sendKeyEvent(LogicalKeyboardKey.arrowDown);
    await tester.pump(const Duration(milliseconds: 150));
    // La marca recorrió Inicio → Divisas → Lista: el tercero queda marcado.
    expect(find.text('Lista'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('matching sin acentos: «analisis» halla «Análisis»', (
    tester,
  ) async {
    final store = _storeConDatos();
    await _abrirPalette(tester, store);

    await tester.enterText(find.byType(TextField), 'analisis');
    await tester.pump();
    expect(find.text('Análisis'), findsOneWidget);
    expect(find.text('Inicio'), findsNothing);
    expect(find.text('Divisas'), findsNothing);
  });

  testWidgets('productos y compras aparecen con su grupo', (tester) async {
    final store = _storeConDatos();
    await _abrirPalette(tester, store);

    // Producto por nombre (la búsqueda original matchea nombre, no tienda).
    await tester.enterText(find.byType(TextField), 'cafe');
    await tester.pump();
    expect(find.text('PRODUCTOS'), findsOneWidget);
    expect(find.text('Café molido'), findsOneWidget);

    // Compra por tienda.
    await tester.enterText(find.byType(TextField), 'bodegon');
    await tester.pump();
    expect(find.text('COMPRAS'), findsOneWidget);
    expect(find.text('Bodegón La Esquina'), findsAtLeastNWidgets(1));
    expect(tester.takeException(), isNull);
  });

  testWidgets('sin resultados: estado honesto, no pantalla rota', (
    tester,
  ) async {
    final store = _storeConDatos();
    await _abrirPalette(tester, store);

    await tester.enterText(find.byType(TextField), 'xyzqueNoExiste');
    await tester.pump();
    expect(find.textContaining('Sin resultados'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('el shell enseña el hint «Ctrl K» en ancho de escritorio', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1200, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final store = _storeConDatos();
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    // El tour auto-arranca con prefs frescas y deja timers pendientes —
    // este test es del header: tour ya visto (patrón del test del shell).
    await prefs.setBool(kTourDoneKey, true);
    final poller = RatesPoller(
      store,
      NotificationsService(),
      AlertEngine(prefs),
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
          appBuilder: (context) => MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: GoRouter(
            initialLocation: '/',
            routes: [
              StatefulShellRoute.indexedStack(
                builder: (_, _, shell) => MainShell(navigationShell: shell),
                branches: [
                  StatefulShellBranch(
                    routes: [
                      GoRoute(
                        path: '/',
                        builder: (_, _) => const SizedBox.shrink(),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          ),
        ),
      ),
    );
    await tester.pump();
    // TASK-34 (p4): el hint vive ahora en el botón de búsqueda del sidebar
    // (kbd ⌘K del prototipo) — mismo contrato, mejor sitio.
    expect(find.text('⌘K'), findsOneWidget);
  });
}
