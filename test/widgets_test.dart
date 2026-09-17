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
import 'package:valorave/features/settings/settings_screen.dart';
import 'package:valorave/features/shell/main_shell.dart';
import 'package:valorave/features/shell/notifs_center.dart';
import 'package:valorave/room/room_controller.dart';
import 'package:valorave/widgets/app_router.dart';
import 'package:valorave/widgets/app_tour.dart';
import 'package:valorave/widgets/coach_mark.dart';
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
late SharedPreferences _prefs;

/// Prepara los servicios singleton con prefs mock (await en cada test).
Future<void> _initServices(AppStore store) async {
  SharedPreferences.setMockInitialValues({});
  _prefs = await SharedPreferences.getInstance();
  _alerts = AlertEngine(_prefs);
  _poller = RatesPoller(store, _notifs, _alerts);
}

Widget _wrap(
  Widget child, {
  required AppStore store,
  ThemeMode mode = ThemeMode.light,
}) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider.value(value: store),
      ChangeNotifierProvider(create: (_) => ThemeController()),
      ChangeNotifierProvider(create: (_) => _poller),
      Provider<AlertEngine>.value(value: _alerts),
      Provider<NotificationsService>.value(value: _notifs),
      // v19.4: el Inicio lee las prefs de widgets (como appProviders en
      // la app real — siempre están).
      Provider<SharedPreferences>.value(value: _prefs),
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
    testWidgets('Stamp · ReadWindow · LedgerRow · TrendBadge renderizan', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Column(
              children: const [
                Stamp('bcv', icon: Icons.account_balance),
                ReadWindow(child: Text('1.234,56')),
                LedgerRow(label: 'Arroz', value: '\$ 1,00'),
                TrendBadge(2.1),
              ],
            ),
          ),
        ),
      );
      expect(find.text('BCV'), findsOneWidget);
      expect(find.text('Arroz'), findsOneWidget);
      expect(find.text('+2,1 %'), findsOneWidget);
    });

    testWidgets('AnimatedNumber odómetro anima entre valores', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(
            body: AnimatedNumber(100, style: TextStyle(fontSize: 30)),
          ),
        ),
      );
      expect(find.text('100,00'), findsOneWidget);
    });

    testWidgets('CurrencySelect abre menú y emite selección', (tester) async {
      Currency picked = Currency.usd;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: CurrencySelect(
                value: Currency.usd,
                onChanged: (c) => picked = c,
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.byType(CurrencySelect));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Euro').last);
      await tester.pumpAndSettle();
      expect(picked, Currency.eur);
    });

    testWidgets('SegmentedChips marca el activo y notifica', (tester) async {
      var value = 'a';
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => SegmentedChips<String>(
                options: const ['a', 'b'],
                value: value,
                onChanged: (v) => setState(() => value = v),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('b'));
      await tester.pump();
      expect(value, 'b');
    });

    testWidgets('MoneyField formatea miles en vivo (es-VE) y emite el número', (
      tester,
    ) async {
      double? valor;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: MoneyField(onChanged: (v) => valor = v, hintText: 'Monto'),
          ),
        ),
      );
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
    testWidgets('Bienvenida: 4 slides PageView, avanzar/retroceder y país', (
      tester,
    ) async {
      final store = _pumpedStore(tester, dir: 'w1');
      await _initServices(store);
      final router2 = GoRouter(
        initialLocation: '/bienvenida',
        routes: [
          GoRoute(
            path: '/bienvenida',
            builder: (_, _) => const WelcomeScreen(),
          ),
          GoRoute(path: '/', builder: (_, _) => const HomeScreen()),
        ],
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider(create: (_) => ThemeController()),
            ChangeNotifierProvider.value(value: _poller),
            Provider<SharedPreferences>.value(value: _prefs),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router2,
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      // v19.0: la bienvenida es un PageView de 4 slides (orden del dueño).
      expect(find.byType(PageView), findsOneWidget);
      // Slide 1: marca (RichText «Valora»+«VE») y su subtítulo.
      expect(find.text('Precios y divisas de Venezuela'), findsOneWidget);
      expect(find.text('Siguiente'), findsOneWidget);
      // Avanzar slide por slide hasta el país.
      for (var i = 0; i < 3; i++) {
        await tester.tap(find.text('Siguiente'));
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pumpAndSettle(const Duration(milliseconds: 100));
      }
      // Slide 4: chips de país con banderas + botón Comenzar.
      expect(find.text('Comenzar'), findsOneWidget);
      expect(find.text('Atrás'), findsOneWidget);
      await tester.tap(find.text('Colombia'));
      await tester.pump();
      // Retroceder y volver: el país elegido se conserva.
      await tester.tap(find.text('Atrás'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.text('Siguiente'));
      await tester.pump(const Duration(milliseconds: 350));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      await tester.tap(find.text('Comenzar'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.settings.country, 'CO');
      expect(store.settings.onboarded, isTrue);
    });

    testWidgets('Home: héroe + resumen de compras + herramientas', (
      tester,
    ) async {
      final store = _pumpedStore(tester, dir: 'w2');
      await _initServices(store);
      // v17.8: el resumen del mes se alimenta de COMPRAS (el módulo Finanzas
      // se retiró) — sin registro manual.
      store.addPurchase(
        Purchase(
          id: 'p1',
          date: DateTime.now(),
          store: 'Súper A',
          items: const [],
          totalUSD: 25,
          totalBS: 1000,
          rate: 40,
        ),
      );
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
      store.setRateBoard(
        RateBoard(
          sources: {
            'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now()),
            'ves-parallel': RateEntry(rate: 44, updatedAt: DateTime.now()),
          },
        ),
      );
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

    testWidgets(
      'Conversor BIDIRECCIONAL: escribir abajo calcula arriba + sin misma moneda',
      (tester) async {
        final store = _pumpedStore(tester, dir: 'w3b');
        await _initServices(store);
        store.setRateBoard(
          RateBoard(
            sources: {
              'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now()),
              'ves-parallel': RateEntry(rate: 44, updatedAt: DateTime.now()),
            },
          ),
        );
        await tester.pumpWidget(_wrap(const ConverterScreen(), store: store));
        await tester.pumpAndSettle();
        // Par inicial USD → VES. Escribir 1000 arriba → abajo 40.000 en vivo.
        final fields = find.byType(MoneyField);
        await tester.enterText(fields.first, '1000');
        await tester.pump();
        expect(find.text('1.000'), findsOneWidget);
        expect(find.text('40.000,00'), findsOneWidget);
        // BIDIRECCIONAL: escribir 80.000 ABAJO → arriba 2.000.
        await tester.enterText(fields.at(1), '80000');
        await tester.pump();
        expect(find.text('80.000'), findsOneWidget);
        expect(find.text('2.000,00'), findsOneWidget);
        // Elegir la divisa del OTRO lado INTERCAMBIA (jamás USD → USD).
        final fromCode = store.data.converter.from;
        final toCode = store.data.converter.to;
        await tester.tap(find.byType(CurrencySelect).first);
        await tester.pumpAndSettle();
        await tester.tap(find.text(toCode == 'USD' ? 'Dólar' : 'Bolívar').last);
        await tester.pumpAndSettle();
        expect(store.data.converter.from, toCode);
        expect(store.data.converter.to, fromCode);
        expect(store.data.converter.from == store.data.converter.to, isFalse);
      },
    );

    testWidgets('Lista: agregar producto, plantilla, vuelto, dividir', (
      tester,
    ) async {
      final store = _pumpedStore(tester, dir: 'w4');
      await _initServices(store);
      store.setRateBoard(
        RateBoard(
          sources: {
            'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now()),
            'ves-parallel': RateEntry(rate: 44, updatedAt: DateTime.now()),
          },
        ),
      );
      await tester.pumpWidget(_wrap(const ListaScreen(), store: store));
      await tester.pumpAndSettle();
      expect(find.text('Lista de compras'), findsOneWidget);
      // agrega un ítem
      await tester.enterText(
        find.widgetWithText(TextField, 'Producto'),
        'Café',
      );
      await tester.enterText(
        find.widgetWithText(TextField, 'Precio unitario'),
        '40',
      );
      await tester.tap(find.text('Agregar a la lista'));
      await tester.pumpAndSettle();
      expect(store.cart.length, 1);
      // v19: total en moneda de cálculo + USD de extra al lado.
      store.setSetting('calcCurrency', 'VES');
      await tester.pumpAndSettle();
      expect(find.text('TOTAL DE LA COMPRA'), findsOneWidget);
      expect(find.textContaining('≈'), findsWidgets);
      // v19: Vuelto y Dividir viven en el CHECKOUT (jerarquía post-compra).
      expect(find.text('Calculadora de vuelto'), findsNothing);
      expect(find.text('Dividir la cuenta'), findsNothing);
    });

    testWidgets('Productos: semilla catálogo, filtro por chip, ficha', (
      tester,
    ) async {
      final store = _pumpedStore(tester, dir: 'w5');
      await _initServices(store);
      await tester.pumpWidget(_wrap(const ProductsScreen(), store: store));
      await tester.pumpAndSettle();
      // semilla de 21 productos en primer arranque (datos, no viewport)
      expect(store.products.length, 21);
      // filtro por categoría (datos)
      expect(
        store.products
            .where((p) => p.category == ProductCategory.bebidas)
            .length,
        4,
      );
      // v19: la ficha abre con las secciones en Cards y el precio usa
      // MoneyField (formato de miles en vivo).
      await tester.tap(find.text(store.products.first.name));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('ACTUALIZAR PRECIO'), findsOneWidget);
      expect(find.byType(MoneyField), findsAtLeastNWidgets(1));
      // Ajustes vive al final de la ficha: scroll hasta la sección.
      await tester.scrollUntilVisible(
        find.text('AJUSTES DEL PRODUCTO'),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('AJUSTES DEL PRODUCTO'), findsOneWidget);
    });

    testWidgets('Análisis: Gastos alimentado por compras de Lista', (
      tester,
    ) async {
      final store = _pumpedStore(tester, dir: 'w6');
      await _initServices(store);
      store.addPurchase(
        Purchase(
          id: 'p1',
          date: DateTime.now(),
          store: 'Súper A',
          items: const [],
          totalUSD: 25,
          totalBS: 1000,
          rate: 40,
        ),
      );
      store.addPurchase(
        Purchase(
          id: 'p2',
          date: DateTime.now().subtract(const Duration(days: 1)),
          store: 'Bodega B',
          items: const [],
          totalUSD: 10,
          totalBS: 400,
          rate: 40,
        ),
      );
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
      await tester.pumpWidget(
        _wrap(const Scaffold(body: SizedBox()), store: store),
      );
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showNotificationCenter(context),
                child: const Text('abrir'),
              ),
            ),
          ),
          store: store,
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
      expect(find.text('Todo tranquilo'), findsOneWidget);
      expect(find.text('Configurar alertas'), findsOneWidget);
    });

    testWidgets('Legal: privacidad y licencias', (tester) async {
      await tester.pumpWidget(
        MaterialApp(theme: AppTheme.light(), home: const LegalScreen()),
      );
      await tester.pumpAndSettle();
      expect(find.text('Privacidad'), findsOneWidget);
      expect(find.text('Licencias'), findsOneWidget);
    });
  });

  group('Shell', () {
    testWidgets('navega 5 pestañas y badge de carrito', (tester) async {
      final store = _pumpedStore(tester, dir: 'w9');
      await _initServices(store);
      // El tour auto-arranca con prefs frescas (como en la app real) y su
      // barrera bloquea el navbar: este test es de NAVEGACIÓN — el tour
      // ya visto, como un usuario que lo completó.
      await _prefs.setBool(kTourDoneKey, true);
      store.addToCart(
        const CartItem(
          id: 'k',
          name: 'X',
          quantity: 3,
          price: 1,
          currency: 'USD',
        ),
      );
      final router = GoRouter(
        initialLocation: '/',
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
                  GoRoute(
                    path: '/lista',
                    builder: (_, _) => const ListaScreen(),
                  ),
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
            ],
          ),
        ],
      );
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider(create: (_) => ThemeController()),
            ChangeNotifierProvider.value(value: _poller),
            Provider<SharedPreferences>.value(value: _prefs),
            // v18.0: la Lista lee el controlador de sala del árbol.
            ChangeNotifierProvider(create: (_) => RoomController(store)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      // v17.6: la rama Home del shell tiene board vacío → LoadingState
      // (spinner indefinido). Bombeo acotado en lugar de pumpAndSettle.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.byKey(kNavBarKey), findsOneWidget);
      expect(find.text('3'), findsOneWidget); // badge carrito
      // navega a Lista — al navbar, no a la tarjeta «Lista» de las
      // Herramientas del Inicio (ambas dicen «Lista» desde v19.4).
      await tester.tap(
        find.descendant(
          of: find.byKey(kNavBarKey),
          matching: find.text('Lista'),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Lista de compras'), findsOneWidget);
    });
  });

  group('Ajustes v19: tasas manuales sin desbordes', () {
    testWidgets('fila manual flexible con valor y editor compartido', (
      tester,
    ) async {
      final store = _pumpedStore(tester, dir: 'w13');
      await _initServices(store);
      store.setManualRate('ves-manual', 41.5);
      // Pantalla angosta (320 px, el caso que desbordaba con ancho fijo).
      tester.view.physicalSize = const Size(320, 800);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const SettingsScreen(), store: store));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      // Scroll hasta la sección de manuales.
      await tester.scrollUntilVisible(
        find.text('Tasa manual VES'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.textContaining('1 USD = 41,5'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'sin desbordes a 320 px');
      // Tocar abre el editor compartido (MoneyField).
      await tester.tap(find.text('Tasa manual VES'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Tasa manual VES', findRichText: true), findsWidgets);
    });
  });

  group('Banderas (v19): las 6 divisas cargan su asset real', () {
    testWidgets('Flag de cada divisa pinta la imagen, no el fallback', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Wrap(
              children: [for (final c in Currency.values) Flag(c, size: 24)],
            ),
          ),
        ),
      );
      // Las 6 divisas del foco tienen asset real (assets/flags): ninguna
      // cae al fallback (ColoredBox del errorBuilder).
      expect(find.byType(Image), findsNWidgets(Currency.values.length));
      expect(find.byType(ColoredBox), findsNothing);
    });
  });

  group('Home v19: fecha simple, sin saltos y manual no es offline', () {
    testWidgets('fecha corta «lun 15 sep · HH:MM» sin fecha larga', (
      tester,
    ) async {
      final store = _pumpedStore(tester, dir: 'w11');
      await _initServices(store);
      store.setRateBoard(
        RateBoard(
          sources: {
            'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now()),
            'ves-parallel': RateEntry(rate: 44, updatedAt: DateTime.now()),
          },
        ),
      );
      await tester.pumpWidget(_wrap(const HomeScreen(), store: store));
      await tester.pumpAndSettle();
      // La fecha larga («lunes, 15 de septiembre de 2026») ya NO existe.
      expect(find.textContaining(' de septiembre de '), findsNothing);
      // El formato corto vive en UNA línea: «dia DD mes · HH:MM».
      expect(
        find.textContaining(
          RegExp(r'^[a-záéíóú]{3} \d{1,2} [a-z]{3} · \d{2}:\d{2}$'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('tasa manual activa → SIN banner de salud (no es offline)', (
      tester,
    ) async {
      final store = _pumpedStore(tester, dir: 'w12');
      await _initServices(store);
      store.setManualRate('ves-manual', 42);
      store.setRateSource(Currency.ves, 'ves-manual');
      await tester.pumpWidget(_wrap(const HomeScreen(), store: store));
      await tester.pumpAndSettle();
      expect(find.textContaining('Sin conexión'), findsNothing);
      expect(find.textContaining('no se actualiza'), findsNothing);
      // La fila Manual está ACTIVA en la lista de cotización.
      expect(find.text('Manual'), findsOneWidget);
    });
  });

  group('Tour completo (v19.0 · motor propio, un solo tutorial)', () {
    test('integridad: 6 segmentos, ids únicos, anclas GlobalKeys', () {
      // El tour es UNO y cubre toda la app: 5 pestañas + Ajustes.
      expect(kTourSegments.map((s) => s.location).toList(), [
        '/',
        '/conversor',
        '/lista',
        '/productos',
        '/analisis',
        '/ajustes',
      ]);
      final ids = [
        for (final s in kTourSegments)
          for (final st in s.steps) st.id,
      ];
      expect(ids.toSet().length, ids.length, reason: 'ids de pasos únicos');
      expect(ids.length, greaterThanOrEqualTo(12));
      // v19: SOLO la introducción va sin ancla (tarjeta centrada arriba);
      // todo lo demás enfoca su zona real — nada de focos muertos.
      final sinAncla = [
        for (final s in kTourSegments)
          for (final st in s.steps)
            if (st.anchor == null) st.id,
      ];
      expect(sinAncla, [
        'inicio.bienvenida',
      ], reason: 'solo el primer paso es centrado; el resto enfoca zonas');
      // Las anclas son únicas (un GlobalKey no puede enfocar dos widgets).
      final anchors = [
        for (final s in kTourSegments)
          for (final st in s.steps) st.anchor,
      ];
      expect(
        anchors.toSet().length,
        anchors.length,
        reason: 'anclas sin duplicar',
      );
    });

    test('flag una-sola-vez: marcar hecho y no repetir', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      expect(isTourDone(prefs), isFalse);
      await markTourDone(prefs);
      expect(isTourDone(prefs), isTrue);
    });

    testWidgets('arranca tras montar el shell, salta y restaura', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _pumpedStore(tester, dir: 'w10');
      await _initServices(store);
      // Onboarding YA hecho: el router arranca en '/' y el shell monta con
      // su _TourTrigger (el tour auto-arranca tras la bienvenida real).
      store.finishOnboarding();
      store.setRateBoard(
        RateBoard(
          sources: {
            'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now()),
            'ves-parallel': RateEntry(rate: 44, updatedAt: DateTime.now()),
          },
        ),
      );
      final router = buildRouter(store: store);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider(create: (_) => ThemeController()),
            ChangeNotifierProvider.value(value: _poller),
            Provider<SharedPreferences>.value(value: prefs),
            // v18.0: el shell/Lista leen el controlador de sala del árbol.
            ChangeNotifierProvider(create: (_) => RoomController(store)),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      // El shell monta → _TourTrigger dispara el tour. La cadena
      // (350 ms de respiro → ensureVisible → overlay) necesita algunos
      // frames: se espera por condición. El motor propio NO tiene
      // animaciones infinitas, pero el ticker del shell puede seguir vivo
      // — por eso condición y no pumpAndSettle.
      for (
        var i = 0;
        i < 30 &&
            find.text('Tus datos viven en tu teléfono').evaluate().isEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Tus datos viven en tu teléfono'), findsOneWidget);
      expect(find.text('1/13'), findsOneWidget);
      // Se marcó ANTES de mostrarse (una oportunidad, no un bucle).
      expect(isTourDone(prefs), isTrue);
      // Saltar corta TODO el tour y restaura la petaña de origen.
      await tester.tap(find.text('Saltar'));
      for (
        var i = 0;
        i < 30 &&
            find.text('Tus datos viven en tu teléfono').evaluate().isNotEmpty;
        i++
      ) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      expect(find.text('Tus datos viven en tu teléfono'), findsNothing);
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
    });
  });

  group('Tarjeta de coach mark (TIPs/Tutorial)', () {
    // El Material de la tarjeta es el único con elevation 6 en el overlay.
    final cardFinder = find.byWidgetPredicate(
      (w) => w is Material && w.elevation == 6,
    );

    testWidgets('mide su contenido: sin espacio en blanco bajo el texto', (
      tester,
    ) async {
      // Pantalla 800×600: ancla ARRIBA → el hueco de la tarjeta es el resto
      // de la pantalla (~510 px). Con texto corto la tarjeta debe medir su
      // contenido, no llenar el hueco (fix del aire muerto).
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.topCenter,
              child: SizedBox(
                key: key,
                width: 220,
                height: 44,
                child: const ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      );
      final future = showCoachMark(
        tester.element(find.byType(Scaffold)),
        anchor: key,
        card: const CoachCardData(
          segment: 'TIP',
          title: 'Título corto',
          body: 'Cuerpo de dos líneas como máximo.',
          cta: 'Entendido',
        ),
      );
      await tester.pump();
      expect(cardFinder, findsOneWidget);
      final size = tester.getSize(cardFinder);
      // Antes del fix: ~510 px (todo el hueco). Ahora: contenido + botones.
      expect(size.height, lessThan(260), reason: 'la tarjeta encoge a su texto');
      // Cuelga del borde superior del hueco: arranca justo bajo el ancla.
      expect(
        tester.getTopLeft(cardFinder).dy,
        closeTo(44 + 10 + 14, 2),
        reason: 'pegada al foco, sin aire arriba',
      );
      await tester.tap(find.text('Entendido'));
      await tester.pump();
      expect(await future, isTrue);
    });

    testWidgets('sobre el foco se apoya en su borde inferior', (tester) async {
      // Ancla ABAJO → la tarjeta vive en el hueco superior y debe quedarse
      // pegada al foco por abajo (bottomCenter del hueco), no colgada del
      // techo de la pantalla dejando el aire en el medio.
      final key = GlobalKey();
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Align(
              alignment: Alignment.bottomCenter,
              child: SizedBox(
                key: key,
                width: 220,
                height: 44,
                child: const ColoredBox(color: Colors.red),
              ),
            ),
          ),
        ),
      );
      final future = showCoachMark(
        tester.element(find.byType(Scaffold)),
        anchor: key,
        card: const CoachCardData(
          segment: 'INICIO',
          title: 'Otro título',
          body: 'Cuerpo corto igual.',
        ),
      );
      await tester.pump();
      expect(cardFinder, findsOneWidget);
      expect(
        tester.getBottomLeft(cardFinder).dy,
        closeTo(600 - 44 - 10 - 14, 2),
        reason: 'apoyada sobre el foco',
      );
      await tester.tap(find.text('Saltar'));
      await tester.pump();
      expect(await future, isFalse);
    });
  });
}
