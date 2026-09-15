/// Widget tests: shell + pantallas principales + componentes de ui.dart
/// (MVP Fase 7 · todas las pantallas y componentes).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/currencies.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/converter/converter_screen.dart';
import 'package:valorave/features/home/home_screen.dart';
import 'package:valorave/features/insights/insights_screen.dart';
import 'package:valorave/features/legal/legal_screen.dart';
import 'package:valorave/features/lista/lista_screen.dart';
import 'package:valorave/features/products/products_screen.dart';
import 'package:valorave/features/shell/main_shell.dart';
import 'package:valorave/features/shell/notifs_center.dart';
import 'package:valorave/room/room_transport.dart';
import 'package:valorave/widgets/app_router.dart';
import 'package:valorave/widgets/app_tour.dart';
import 'package:valorave/features/welcome/welcome_screen.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:valorave/widgets/ui.dart';

/// Store ligero para widget tests (sin Hive: FakeAsync no hace file IO).
AppStore _pumpedStore(WidgetTester tester, {String dir = 'w'}) {
  SharedPreferences.setMockInitialValues({});
  return AppStore.withData(const AppData());
}

final NotificationsService _notifs = NotificationsService();
late RatesPoller _poller;
late AlertEngine _alerts;

/// Prepara los servicios singleton con prefs mock (await en cada test).
Future<void> _initServices(AppStore store) async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  _alerts = AlertEngine(prefs);
  _poller = RatesPoller(store, _notifs, _alerts);
}

Widget _wrap(Widget child, {required AppStore store, ThemeMode mode = ThemeMode.light}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider(create: (_) => _poller),
      Provider<AlertEngine>.value(value: _alerts),
      Provider<NotificationsService>.value(value: _notifs),
      // v18.0 · Sala Viva: controlador de sala a nivel app (como en
      // appProviders) — la Lista y la sala lo comparten.
      ChangeNotifierProvider(create: (_) => RoomController(store)),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      localizationsDelegates: const [],
      home: child,
    ),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Componentes de ui.dart', () {
    testWidgets('Stamp · ReadWindow · LedgerRow · TrendBadge renderizan', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Column(children: const [
            Stamp('bcv', icon: Icons.account_balance),
            ReadWindow(child: Text('1.234,56')),
            LedgerRow(label: 'Arroz', value: '\$ 1,00'),
            TrendBadge(2.1),
          ]),
        ),
      ));
      expect(find.text('BCV'), findsOneWidget);
      expect(find.text('Arroz'), findsOneWidget);
      expect(find.text('+2,1 %'), findsOneWidget);
    });

    testWidgets('AnimatedNumber odómetro anima entre valores', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const Scaffold(
          body: AnimatedNumber(100, style: TextStyle(fontSize: 30)),
        ),
      ));
      expect(find.text('100,00'), findsOneWidget);
    });

    testWidgets('CurrencySelect abre menú y emite selección', (tester) async {
      Currency picked = Currency.usd;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: Center(child: CurrencySelect(
            value: Currency.usd,
            onChanged: (c) => picked = c,
          )),
        ),
      ));
      await tester.tap(find.byType(CurrencySelect));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Euro').last);
      await tester.pumpAndSettle();
      expect(picked, Currency.eur);
    });

    testWidgets('SegmentedChips marca el activo y notifica', (tester) async {
      var value = 'a';
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: StatefulBuilder(builder: (context, setState) => SegmentedChips<String>(
            options: const ['a', 'b'],
            value: value,
            onChanged: (v) => setState(() => value = v),
          )),
        ),
      ));
      await tester.tap(find.text('b'));
      await tester.pump();
      expect(value, 'b');
    });

    testWidgets('MoneyField formatea miles en vivo (es-VE) y emite el número', (tester) async {
      double? valor;
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MoneyField(onChanged: (v) => valor = v, hintText: 'Monto'),
        ),
      ));
      final field = find.byType(TextField);
      // «1000» → «1.000»
      await tester.enterText(field, '1000');
      await tester.pump();
      expect(find.text('1.000'), findsOneWidget);
      expect(valor, 1000);
      // «1000000» → «1.000.000»
      await tester.enterText(field, '1000000');
      await tester.pump();
      expect(find.text('1.000.000'), findsOneWidget);
      expect(valor, 1000000);
      // Coma decimal: «1.000,5» (canon 1000,5)
      await tester.enterText(field, '1000,5');
      await tester.pump();
      expect(find.text('1.000,5'), findsOneWidget);
      expect(valor, 1000.5);
      // Punto tecleado = decimal (hábito EN) → «3,5»
      await tester.enterText(field, '3.5');
      await tester.pump();
      expect(find.text('3,5'), findsOneWidget);
      expect(valor, 3.5);
      // Coma inicial → «0,5»
      await tester.enterText(field, ',5');
      await tester.pump();
      expect(find.text('0,5'), findsOneWidget);
      expect(valor, 0.5);
      // Vacío → 0, sin caracteres rarios.
      await tester.enterText(field, '');
      await tester.pump();
      expect(valor, 0);
    });


  });

  group('Pantallas', () {
    testWidgets('Bienvenida: país obligatorio y flujo completo', (tester) async {
      final store = _pumpedStore(tester, dir: 'w1');
      await _initServices(store);
      final router2 = GoRouter(
        initialLocation: '/bienvenida',
        routes: [
          GoRoute(path: '/bienvenida', builder: (_, _) => const WelcomeScreen()),
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        ],
      );
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider.value(value: _poller),
        ],
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router2),
      ));
      await tester.pump(const Duration(milliseconds: 300));
      // v18.0: SIN PageView — la bienvenida es UNA sola pantalla; el país
      // se preselecciona con chips de bandera y «Comenzar en …» lo fija.
      expect(find.byType(PageView), findsNothing);
      expect(find.text('Comenzar en Venezuela'), findsOneWidget);
      // El chip de Colombia puede quedar bajo el pliegue: scroll hasta él.
      await tester.scrollUntilVisible(
        find.text('Colombia'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(find.text('Colombia'));
      await tester.pump();
      expect(find.text('Comenzar en Colombia'), findsOneWidget);
      await tester.tap(find.text('Comenzar en Colombia'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.settings.country, 'CO');
      // v18.0: del país se pasa directo al cierre.
      expect(find.text('Todo listo'), findsOneWidget);
      await tester.tap(find.text('Empezar a usar ValoraVE'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.settings.onboarded, isTrue);
    });

    testWidgets('Home: héroe + resumen de compras + herramientas', (tester) async {
      final store = _pumpedStore(tester, dir: 'w2');
      await _initServices(store);
      // v17.8: el resumen del mes se alimenta de COMPRAS (el módulo Finanzas
      // se retiró) — sin registro manual.
      store.addPurchase(Purchase(
        id: 'p1',
        date: DateTime.now(),
        store: 'Súper A',
        items: const [],
        totalUSD: 25,
        totalBS: 1000,
        rate: 40,
      ));
      await tester.pumpWidget(_wrap(const HomeScreen(), store: store));
      // v17.6: con tablero vacío Home muestra LoadingState (spinner
      // INDEFINIDO) — pumpAndSettle nunca terminaría. Bombeo acotado.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('COTIZACIÓN PRINCIPAL'), findsOneWidget);
    });

    testWidgets('Conversor: dual + swap + ruta + notas', (tester) async {
      final store = _pumpedStore(tester, dir: 'w3');
      await _initServices(store);
      store.setRateBoard(RateBoard(sources: {
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now()),
        'ves-parallel': RateEntry(rate: 44, updatedAt: DateTime.now()),
      }));
      await tester.pumpWidget(_wrap(const ConverterScreen(), store: store));
      await tester.pumpAndSettle();
      expect(find.text('Conversor'), findsOneWidget);
      // swap invierte el par (está arriba, visible en el viewport de prueba)
      final fromBefore = store.data.converter.from;
      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pumpAndSettle();
      expect(store.data.converter.from, isNot(fromBefore));
      // La ruta del cálculo quedó MÁS ABAJO (v17.2 añade fecha de tasas +
      // fuente encima): baja hasta ella antes de afirmar.
      await tester.dragUntilVisible(
        find.text('RUTA DEL CÁLCULO'),
        find.byType(ListView).first,
        const Offset(0, -250),
      );
      await tester.pumpAndSettle();
      expect(find.text('RUTA DEL CÁLCULO'), findsOneWidget);
    });

    testWidgets('Lista: agregar producto, plantilla, vuelto, dividir', (tester) async {
      final store = _pumpedStore(tester, dir: 'w4');
      await _initServices(store);
      store.setRateBoard(RateBoard(sources: {
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now()),
        'ves-parallel': RateEntry(rate: 44, updatedAt: DateTime.now()),
      }));
      await tester.pumpWidget(_wrap(const ListaScreen(), store: store));
      await tester.pumpAndSettle();
      expect(find.text('Lista de compras'), findsOneWidget);
      // agrega un ítem
      await tester.enterText(find.widgetWithText(TextField, 'Producto'), 'Café');
      await tester.enterText(find.widgetWithText(TextField, 'Precio unitario'), '40');
      await tester.tap(find.text('Agregar a la lista'));
      await tester.pumpAndSettle();
      expect(store.cart.length, 1);
      // total y agregar: on-screen tras pump
    });

    testWidgets('Productos: semilla catálogo, filtro por chip, ficha', (tester) async {
      final store = _pumpedStore(tester, dir: 'w5');
      await _initServices(store);
      await tester.pumpWidget(_wrap(const ProductsScreen(), store: store));
      await tester.pumpAndSettle();
      // semilla de 21 productos en primer arranque (datos, no viewport)
      expect(store.products.length, 21);
      // filtro por categoría (datos)
      expect(store.products.where((p) => p.category == ProductCategory.bebidas).length, 4);
    });

    testWidgets('Análisis: Gastos alimentado por compras de Lista', (tester) async {
      final store = _pumpedStore(tester, dir: 'w6');
      await _initServices(store);
      store.addPurchase(Purchase(
        id: 'p1',
        date: DateTime.now(),
        store: 'Súper A',
        items: const [],
        totalUSD: 25,
        totalBS: 1000,
        rate: 40,
      ));
      store.addPurchase(Purchase(
        id: 'p2',
        date: DateTime.now().subtract(const Duration(days: 1)),
        store: 'Bodega B',
        items: const [],
        totalUSD: 10,
        totalBS: 400,
        rate: 40,
      ));
      await tester.pumpWidget(_wrap(const InsightsScreen(), store: store));
      await tester.pumpAndSettle();
      // Ancla Gastos (v17.8): sin carga manual, con compras entra la vista.
      await tester.tap(find.text('Gastos'));
      await tester.pumpAndSettle();
      expect(find.text('Gastado · 1 M'), findsOneWidget);
      expect(find.text('POR TIENDA'), findsOneWidget);
    });

    testWidgets('Análisis: 6 anclas conmutan', (tester) async {
      final store = _pumpedStore(tester, dir: 'w7');
      await _initServices(store);
      await tester.pumpWidget(_wrap(const InsightsScreen(), store: store));
      await tester.pumpAndSettle();
      expect(find.text('Divisas'), findsOneWidget);
      await tester.tap(find.text('Canasta'));
      await tester.pumpAndSettle();
      expect(find.text('Canasta vacía'), findsOneWidget);
    });

    testWidgets('Análisis: Gastos vacío honesto sin compras', (tester) async {
      final store = _pumpedStore(tester, dir: 'w7b');
      await _initServices(store);
      await tester.pumpWidget(_wrap(const InsightsScreen(), store: store));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Gastos'));
      await tester.pumpAndSettle();
      expect(find.text('Sin compras en el rango'), findsOneWidget);
    });

    testWidgets('Centro de notificaciones vacío honesto', (tester) async {
      final store = _pumpedStore(tester, dir: 'w8');
      await _initServices(store);
      await tester.pumpWidget(_wrap(const Scaffold(body: SizedBox()), store: store));
      await tester.pumpWidget(_wrap(
        Builder(builder: (context) => Center(child: ElevatedButton(
          onPressed: () => showNotificationCenter(context),
          child: const Text('abrir'),
        ))),
        store: store,
      ));
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Todo tranquilo'), findsOneWidget);
      expect(find.text('Configurar alertas'), findsOneWidget);
    });

    testWidgets('Legal: privacidad y licencias', (tester) async {
      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        home: const LegalScreen(),
      ));
      await tester.pumpAndSettle();
      expect(find.text('Privacidad'), findsOneWidget);
      expect(find.text('Licencias'), findsOneWidget);
    });
  });

  group('Shell', () {
    testWidgets('navega 5 pestañas y badge de carrito', (tester) async {
      final store = _pumpedStore(tester, dir: 'w9');
      await _initServices(store);
      store.addToCart(const CartItem(id: 'k', name: 'X', quantity: 3, price: 1, currency: 'USD'));
      final router = GoRouter(
        initialLocation: '/',
        routes: [
          StatefulShellRoute.indexedStack(
            builder: (_, _, shell) => MainShell(navigationShell: shell),
            branches: [
              StatefulShellBranch(routes: [GoRoute(path: '/', builder: (_, _) => const HomeScreen())]),
              StatefulShellBranch(routes: [GoRoute(path: '/conversor', builder: (_, _) => const ConverterScreen())]),
              StatefulShellBranch(routes: [GoRoute(path: '/lista', builder: (_, _) => const ListaScreen())]),
              StatefulShellBranch(routes: [GoRoute(path: '/productos', builder: (_, _) => const ProductsScreen())]),
              StatefulShellBranch(routes: [GoRoute(path: '/analisis', builder: (_, _) => const InsightsScreen())]),
            ],
          ),
        ],
      );
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider.value(value: _poller),
          // v18.0: la Lista lee el controlador de sala del árbol.
          ChangeNotifierProvider(create: (_) => RoomController(store)),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ));
      // v17.6: la rama Home del shell tiene board vacío → LoadingState
      // (spinner indefinido). Bombeo acotado en lugar de pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(kNavBarKey), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // badge carrito
      // navega a Lista
      await tester.tap(find.text('Lista'));
      await tester.pumpAndSettle();
      expect(find.text('Lista de compras'), findsOneWidget);
    });
  });

  group('Tour completo (v17.8 · tutorial_coach_mark, un solo tutorial)', () {
    test('integridad: 6 segmentos, ids únicos, anclas GlobalKeys', () {
      // El tour es UNO y cubre toda la app: 5 pestañas + Ajustes.
      expect(kTourSegments.map((s) => s.location).toList(),
          ['/', '/conversor', '/lista', '/productos', '/analisis', '/ajustes']);
      final ids = [for (final s in kTourSegments) for (final st in s.steps) st.id];
      expect(ids.toSet().length, ids.length, reason: 'ids de pasos únicos');
      expect(ids.length, greaterThanOrEqualTo(12));
      // Todo paso lleva ancla (nada flota sin foco — nada fuera de pantalla).
      for (final s in kTourSegments) {
        for (final st in s.steps) {
          expect(st.anchor, isA<GlobalKey>(),
              reason: '«${st.id}» sin ancla');
        }
      }
      // Las anclas son únicas (un GlobalKey no puede enfocar dos widgets).
      final anchors = [
        for (final s in kTourSegments)
          for (final st in s.steps) st.anchor,
      ];
      expect(anchors.toSet().length, anchors.length,
          reason: 'anclas sin duplicar');
    });

    test('flag una-sola-vez: marcar hecho y no repetir', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(isTourDone(prefs), isFalse);
      await markTourDone(prefs);
      expect(isTourDone(prefs), isTrue);
    });

    testWidgets('arranca tras montar el shell, salta y restaura', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _pumpedStore(tester, dir: 'w10');
      await _initServices(store);
      // Onboarding YA hecho: el router arranca en '/' y el shell monta con
      // su _TourTrigger (el tour auto-arranca tras la bienvenida real).
      store.finishOnboarding();
      store.setRateBoard(RateBoard(sources: {
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now()),
        'ves-parallel': RateEntry(rate: 44, updatedAt: DateTime.now()),
      }));
      final router = buildRouter(store: store);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider.value(value: _poller),
          Provider<SharedPreferences>.value(value: prefs),
          // v18.0: el shell/Lista leen el controlador de sala del árbol.
          ChangeNotifierProvider(create: (_) => RoomController(store)),
        ],
        child: MaterialApp.router(theme: AppTheme.light(), routerConfig: router),
      ));
      // El shell monta → _TourTrigger dispara el tour. La cadena
      // (350 ms de respiro → overlay → postFrame → animación de foco
      // 420 ms → build de la tarjeta) necesita VARIOS frames: se espera por
      // condición, NUNCA pumpAndSettle (el pulso del foco es infinito).
      for (var i = 0;
          i < 30 && find.text('Tu tablero, sin cuentas ni nube').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Tu tablero, sin cuentas ni nube'), findsOneWidget);
      expect(find.text('1/13'), findsOneWidget);
      // Se marcó ANTES de mostrarse (una oportunidad, no un bucle).
      expect(isTourDone(prefs), isTrue);
      // Saltar corta TODO el tour y restaura la pestaña de origen.
      await tester.tap(find.text('Saltar'));
      for (var i = 0;
          i < 30 && find.text('Tu tablero, sin cuentas ni nube').evaluate().isNotEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Tu tablero, sin cuentas ni nube'), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
    });
  });
}
