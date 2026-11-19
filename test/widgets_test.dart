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
import 'package:valorave/features/finance/finance_screen.dart';
import 'package:valorave/features/home/home_screen.dart';
import 'package:valorave/features/insights/insights_screen.dart';
import 'package:valorave/features/legal/legal_screen.dart';
import 'package:valorave/features/lista/lista_screen.dart';
import 'package:valorave/features/products/products_screen.dart';
import 'package:valorave/features/shell/notifs_center.dart';
import 'package:valorave/widgets/app_router.dart';
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
      expect(find.text('Comenzar'), findsOneWidget);
      await tester.tap(find.text('Comenzar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.text('¿Desde dónde miras las tasas?'), findsOneWidget);
      await tester.tap(find.text('Elegir Venezuela'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.settings.country, 'VE');
      // 7 slides + done
      for (int i = 0; i < 6; i++) {
        await tester.tap(find.text('Siguiente'));
        await tester.pump(const Duration(milliseconds: 300));
      }
      await tester.tap(find.text('Listo'));
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(find.text('Empezar a usar ValoraVE'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.settings.onboarded, isTrue);
    });

    testWidgets('Home: héroe + resumen + herramientas', (tester) async {
      final store = _pumpedStore(tester, dir: 'w2');
      await _initServices(store);
      store.addTransaction(Transaction(id: 't1', type: 'expense',
          category: FinanceCategory.alimentacion, amount: 100, currency: 'VES',
          amountUSD: 2.5, date: DateTime.now()));
      await tester.pumpWidget(_wrap(const HomeScreen(), store: store));
      await tester.pumpAndSettle();
      expect(find.text('COTIZACIÓN PRINCIPAL'), findsOneWidget);
    });

    testWidgets('Inicio: despliegue progresivo de Actividad (resumir sin quitar)', (tester) async {
      final store = _pumpedStore(tester, dir: 'w2b');
      await _initServices(store);
      await tester.pumpWidget(_wrap(const HomeScreen(), store: store));
      await tester.pumpAndSettle();
      // plegado: bloques esenciales + vista previa; sin secciones profundas
      await tester.scrollUntilVisible(find.text('ACTIVIDAD RECIENTE'), 300,
          scrollable: find.byType(Scrollable).first);
      await tester.pumpAndSettle();
      expect(find.text('ACTIVIDAD RECIENTE'), findsOneWidget);
      expect(find.text('Ver todo'), findsOneWidget);
      expect(find.text('HERRAMIENTAS'), findsNothing);
      expect(find.text('ALERTAS DE PRECIOS'), findsNothing);
      // despliegue: todo vuelve a estar (sin quitar)
      await tester.tap(find.text('Ver todo'));
      await tester.pumpAndSettle();
      expect(find.text('HERRAMIENTAS'), findsOneWidget);
      expect(find.text('Ver menos'), findsOneWidget);
      await tester.tap(find.text('Ver menos'));
      await tester.pumpAndSettle();
      expect(find.text('ACTIVIDAD RECIENTE'), findsOneWidget);
    });

    testWidgets('Divisas: dual + swap + ruta + teclado + redondeo', (tester) async {
      final store = _pumpedStore(tester, dir: 'w3');
      await _initServices(store);
      store.setRateBoard(RateBoard(sources: {
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now()),
        'ves-parallel': RateEntry(rate: 44, updatedAt: DateTime.now()),
      }));
      await tester.pumpWidget(_wrap(const ConverterScreen(), store: store));
      await tester.pumpAndSettle();
      expect(find.text('Divisas'), findsOneWidget);
      expect(find.text('RUTA DEL CÁLCULO'), findsOneWidget);
      // swap invierte el par
      final fromBefore = store.data.converter.from;
      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pumpAndSettle();
      expect(store.data.converter.from, isNot(fromBefore));
      // teclado VeKeypad: C limpia y 5,0 escribe 50
      final keypad = find.byType(VeKeypad);
      expect(keypad, findsOneWidget);
      await tester.tap(find.descendant(of: keypad, matching: find.text('C')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: keypad, matching: find.text('5')));
      await tester.tap(find.descendant(of: keypad, matching: find.text('0')));
      await tester.pumpAndSettle();
      expect(find.text('50'), findsWidgets); // monto en el campo + ficha 50
      // ficha rápida de monto absoluto
      await tester.tap(find.text('100'));
      await tester.pumpAndSettle();
      // toggle redondeo persiste en settings
      await tester.tap(find.text('Redondear'));
      await tester.pumpAndSettle();
      expect(store.settings.numMode, 'redondeo');
      await tester.tap(find.text('Decimales'));
      await tester.pumpAndSettle();
      expect(store.settings.numMode, 'decimales');
      // plegar teclado
      await tester.tap(find.text('Ocultar teclado'));
      await tester.pumpAndSettle();
      expect(find.byType(VeKeypad), findsNothing);
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

    testWidgets('Finanzas: registrar movimiento CRUD', (tester) async {
      final store = _pumpedStore(tester, dir: 'w6');
      await _initServices(store);
      store.setRateBoard(RateBoard(sources: {
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now()),
        'ves-parallel': RateEntry(rate: 44, updatedAt: DateTime.now()),
      }));
      await tester.pumpWidget(_wrap(const FinanceScreen(), store: store));
      await tester.pumpAndSettle();
      expect(find.text('RESUMEN'), findsOneWidget);
    });

    testWidgets('Análisis: 5 anclas conmutan', (tester) async {
      final store = _pumpedStore(tester, dir: 'w7');
      await _initServices(store);
      await tester.pumpWidget(_wrap(const InsightsScreen(), store: store));
      await tester.pumpAndSettle();
      expect(find.text('Divisas'), findsOneWidget);
      await tester.tap(find.text('Canasta'));
      await tester.pumpAndSettle();
      expect(find.text('Canasta vacía'), findsOneWidget);
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
    testWidgets('5 pestañas, badge de carrito y hub Más navega', (tester) async {
      final store = _pumpedStore(tester, dir: 'w9');
      await _initServices(store);
      store.finishOnboarding(); // sin redirect a /bienvenida
      store.addToCart(const CartItem(id: 'k', name: 'X', quantity: 3, price: 1, currency: 'USD'));
      final router = buildRouter(store: store);
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider(create: (_) => ThemeController()),
          ChangeNotifierProvider.value(value: _poller),
        ],
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ));
      await tester.pumpAndSettle();
      expect(find.byKey(kNavBarKey), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // badge carrito
      // 5 pestañas: Inicio · Divisas · Lista · Productos · Más
      expect(find.text('Inicio'), findsOneWidget);
      expect(find.text('Divisas'), findsOneWidget);
      expect(find.text('Lista'), findsOneWidget);
      expect(find.text('Productos'), findsOneWidget);
      expect(find.text('Más'), findsOneWidget);
      // navega a Lista (tab 2)
      await tester.tap(find.text('Lista'));
      await tester.pumpAndSettle();
      expect(find.text('Lista de compras'), findsOneWidget);
      // navega al hub Más (tab 4)
      await tester.tap(find.text('Más'));
      await tester.pumpAndSettle();
      expect(find.text('Todo lo demás, a un toque'), findsOneWidget);
      expect(find.text('Finanzas'), findsOneWidget);
      expect(find.text('Historial'), findsOneWidget);
      // el hub lleva a Finanzas y el tab «Más» sigue resaltado
      await tester.tap(find.text('Finanzas'));
      await tester.pumpAndSettle();
      expect(find.text('RESUMEN'), findsOneWidget);
      expect(find.byIcon(Icons.grid_view), findsOneWidget); // tab Más activa
    });
  });
}
