/// Widget tests: shell + pantallas principales + componentes de ui.dart
/// (MVP Fase 7 · todas las pantallas y componentes).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FontLoader, ByteData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/currencies.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/converter/converter_screen.dart';
import 'package:valorave/features/home/home_screen.dart';
import 'package:valorave/features/insights/insights_screen.dart';
import 'package:valorave/features/legal/legal_screen.dart';
import 'package:valorave/features/lista/checkout_modal.dart';
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
import 'package:valorave/providers/providers.dart';

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
  return ProviderScope(
    overrides: [
      appStoreProvider.overrideWith((ref) => store, disposeNotifier: false),
      themeControllerProvider.overrideWith(
        (ref) => ThemeController(),
        disposeNotifier: false,
      ),
      ratesPollerProvider.overrideWith(
        (ref) => _poller,
        disposeNotifier: false,
      ),
      alertsProvider.overrideWith((ref) => _alerts),
      notificationsProvider.overrideWith((ref) => _notifs),
      // v19.4: el Inicio lee las prefs de widgets (como appProviders en
      // la app real — siempre están).
      sharedPreferencesProvider.overrideWithValue(_prefs),
      // v18.0 · Sala Viva: controlador de sala a nivel app (como en
      // appProviders) — la Lista y la sala lo comparten.
      roomControllerProvider.overrideWith(
        (ref) => RoomController(store),
        disposeNotifier: false,
      ),
    ],
    // TASK-34 (p5+p6): Inicio y Conversor usan el kit «Ve» (shadcn_ui
    // real), que necesita ShadTheme en el árbol — como en la app
    // (ShadApp.custom en main.dart monta MaterialApp dentro). El harness
    // replica ese shell.
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: mode,
      localizationsDelegates: const [],
      home: child,
    ),
  );
}

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Fuentes REALES (patrón de gui_correcta_test): la fuente por defecto
  // de test mide cada glifo al ancho del fontSize y fabrica overflows
  // falsos en los chips expandidos («+10 %» = 60 px en fallback, ~34 en
  // Inter) — con las fuentes del asset las medidas son las del teléfono.
  final root = rootBundle;
  Future<void> una(String family, List<Future<ByteData>> assets) async {
    final loader = FontLoader(family);
    for (final a in assets) {
      loader.addFont(a);
    }
    await loader.load();
  }

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

    testWidgets('CurrencySelect abre hoja y emite selección', (tester) async {
      Currency picked = Currency.usd;
      // v20: el selector ahora abre una HOJA «Ve» (showCurrencySheet) que
      // exige ShadTheme en el árbol — mismo shell de producción.
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
      // La hoja lista las divisas con bandera + nombre; elegir Euro.
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
      // v19.6 (bug del dueño): el 5.º dígito sobre «4.000» — el punto a
      // medio grupo de miles ya no se vuelve decimal («4,0000» = 4).
      // (9P·auditoría: se verifica también el estado base «4.000» = 4000.)
      await tester.enterText(field, '4.000');
      await tester.pump();
      expect(find.text('4.000'), findsOneWidget);
      expect(valor, 4000);
      await tester.enterText(field, '4.0000');
      await tester.pump();
      expect(find.text('40.000'), findsOneWidget);
      expect(valor, 40000);
      // Y el 6.º: «40.0000» → 400 mil.
      await tester.enterText(field, '40.0000');
      await tester.pump();
      expect(find.text('400.000'), findsOneWidget);
      expect(valor, 400000);
      // 9P: el mismo 6.º dígito sobre «4.000» con 5 ceros («4.00000»).
      await tester.enterText(field, '4.00000');
      await tester.pump();
      expect(find.text('400.000'), findsOneWidget);
      expect(valor, 400000);
      // Tasas chiquitas con punto (hábito EN): «0.0001» sigue decimal.
      await tester.enterText(field, '0.0001');
      await tester.pump();
      expect(find.text('0,0001'), findsOneWidget);
      expect(valor, closeTo(0.0001, 1e-9));
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
        ProviderScope(
          overrides: [
            appStoreProvider.overrideWith(
              (ref) => store,
              disposeNotifier: false,
            ),
            themeControllerProvider.overrideWith(
              (ref) => ThemeController(),
              disposeNotifier: false,
            ),
            ratesPollerProvider.overrideWith(
              (ref) => _poller,
              disposeNotifier: false,
            ),
            sharedPreferencesProvider.overrideWithValue(_prefs),
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
      // v21.4: en el slide 1 «Atrás» está en el árbol pero DESVANECIDO e
      // inerte (control muerto fuera de la vista; el hueco se reserva).
      final atrasSlide1 = find.text('Atrás');
      expect(atrasSlide1, findsOneWidget);
      expect(
        tester
            .widget<AnimatedOpacity>(
              find
                  .ancestor(
                    of: atrasSlide1,
                    matching: find.byType(AnimatedOpacity),
                  )
                  .first,
            )
            .opacity,
        0,
      );
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
      expect(find.text('TU MES'), findsOneWidget);
      expect(find.text('Convertir'), findsWidgets);
    });

    testWidgets('Conversor: dual + swap + selector de tasa', (tester) async {
      // v23.2: superficie de teléfono real — el piso de teclado convive con
      // el contenido sin pantallas gigantes.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
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
      // v29 (H-28): Fuentes/Tabla/Recientes ya NO viven como fichas — la
      // hoja de fuentes se abre desde el SELECTOR DE TASA (H-24): sello +
      // nombre «BCV · Oficial» + «1 USD = 40,0000 VES» + chevron.
      expect(find.text('Fuentes'), findsNothing);
      expect(find.text('Tabla'), findsNothing);
      expect(find.text('Recientes'), findsNothing);
      await tester.tap(find.text('BCV · Oficial'));
      await tester.pumpAndSettle();
      expect(find.text('Fuente de tasa · Bolívar'), findsOneWidget);
      // La fuente ACTIVA queda marcada (check de selección en la fila BCV).
      final bcvRow = find.ancestor(
        of: find.text('BCV'),
        matching: find.byType(InkWell),
      );
      expect(
        find.descendant(
          of: bcvRow,
          matching: find.byIcon(Icons.check_circle_rounded),
        ),
        findsOneWidget,
      );
    });

    testWidgets('v29 VeKeypad: teclas escriben, borran y ⌫ largo limpia', (
      tester,
    ) async {
      final store = _pumpedStore(tester, dir: 'w3k');
      await _initServices(store);
      store.setRateBoard(
        RateBoard(
          sources: {'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now())},
        ),
      );
      // Par limpio USD → VES para leer el monto de origen sin ruido.
      store.setConverterPair('usd', 'ves');
      // v23.2: teclado como PISO FIJO — cabe en un teléfono REAL
      // (390×844): dual input arriba, teclado al fondo, sin subir/bajar.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const ConverterScreen(), store: store));
      await tester.pumpAndSettle();
      // v29 (H-25/H-26): sin fichas y sin numMode — el teclado es la única
      // vía de entrada y la precisión es la escala única de Ajustes.
      Finder tecla(String k) =>
          find.descendant(of: find.byType(VeKeypad), matching: find.text(k));
      expect(find.byType(VeKeypad), findsOneWidget);
      expect(find.text('Redondear'), findsNothing);
      expect(find.text('Decimales'), findsNothing);
      expect(find.byType(VeChip), findsNothing);
      // El campo de origen arranca en «1»: teclas 2 y 4 → «124».
      await tester.tap(tecla('2'));
      await tester.pump();
      await tester.tap(tecla('4'));
      await tester.pump();
      expect(find.text('124'), findsWidgets);
      // ⌫ borra el último dígito → «12».
      await tester.tap(tecla('⌫'));
      await tester.pump();
      expect(find.text('12'), findsWidgets);
      expect(find.text('124'), findsNothing);
      // Coma decimal es-VE + un decimal → «12,7».
      await tester.tap(tecla(','));
      await tester.pump();
      await tester.tap(tecla('7'));
      await tester.pump();
      expect(find.text('12,7'), findsWidgets);
      // v29 (H-25): ⌫ con PULSACIÓN LARGA limpia el campo activo — sin
      // ficha «Limpiar», la convención de calculadora manda (la aserción
      // inspecciona el CONTROLADOR del MoneyField — R-29e).
      await tester.longPress(tecla('⌫'));
      await tester.pump();
      final field = tester.widget<MoneyField>(find.byType(MoneyField).first);
      expect(field.controller?.text ?? '', '');
      expect(find.text('12,7'), findsNothing);
    });

    testWidgets('v26 horizontal: el pad pasa a PANEL derecho y todo cabe', (
      tester,
    ) async {
      final store = _pumpedStore(tester, dir: 'w3h');
      await _initServices(store);
      store.setRateBoard(
        RateBoard(
          sources: {'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now())},
        ),
      );
      // Par limpio USD → VES para leer el monto de origen sin ruido.
      store.setConverterPair('usd', 'ves');
      // v26 (dispositivos nuevos): móvil GIRADO (844×390) — el Conversor
      // reparte la pantalla: cifras/fichas a la izquierda, acciones +
      // teclado como PANEL fijo a la derecha, sin comerse el display.
      tester.view.physicalSize = const Size(844, 390);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const ConverterScreen(), store: store));
      await tester.pumpAndSettle();
      expect(find.byType(VeKeypad), findsOneWidget);
      // El pad vive a la DERECHA del título (panel lateral, no piso).
      final pad = tester.getTopLeft(find.byType(VeKeypad));
      final titulo = tester.getTopLeft(find.text('Conversor'));
      expect(pad.dx, greaterThan(500));
      expect(titulo.dx, lessThan(pad.dx));
      // El selector de tasa comparte fila con el panel (queda a la
      // izquierda — v29: H-24 lo pinta a todo lo ancho del cuerpo).
      expect(
        tester.getTopLeft(find.text('BCV · Oficial')).dx,
        lessThan(pad.dx),
      );
      // Y el pad FUNCIONA en su nueva casa: teclas 2 + 4 → «124».
      Finder tecla(String k) =>
          find.descendant(of: find.byType(VeKeypad), matching: find.text(k));
      await tester.tap(tecla('2'));
      await tester.pump();
      await tester.tap(tecla('4'));
      await tester.pump();
      expect(find.text('124'), findsWidgets);
    });

    testWidgets('v30 (H-42): Ajustes en UNA pantalla por secciones', (
      tester,
    ) async {
      final store = _pumpedStore(tester, dir: 'w26c');
      await _initServices(store);
      store.setRateBoard(
        RateBoard(
          sources: {'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now())},
        ),
      );
      // Ajustes enteros (v30 · H-42): una sola pantalla, cinco secciones —
      // sin hub de fichas ni subpantallas.
      await tester.pumpWidget(_wrap(const SettingsScreen(), store: store));
      await tester.pumpAndSettle();
      expect(find.textContaining('Cinta de cotizaciones'), findsNothing);
      expect(find.text('PERSONALIZACIÓN'), findsNothing);
      expect(find.text('Ajustes'), findsOneWidget);
      // Cuentas y cobro PRIMERO (deep link del Conversor e Inicio).
      expect(find.text('CUENTAS Y COBRO'), findsOneWidget);
      // La lista es perezosa: se baja hasta cada una para construirla.
      final lista = find.byType(Scrollable).first;
      for (final seccion in [
        'TASAS Y FUENTES',
        'GENERAL',
        'APARIENCIA',
        'DATOS Y ACERCA DE',
      ]) {
        await tester.scrollUntilVisible(
          find.text(seccion),
          300,
          scrollable: lista,
        );
        await tester.pumpAndSettle();
        expect(find.text(seccion), findsOneWidget);
      }
    });

    testWidgets('v29 precisión uniforme: 2 · 3 · Completo sin relleno', (
      tester,
    ) async {
      final store = _pumpedStore(tester, dir: 'w3r');
      await _initServices(store);
      store.setRateBoard(
        RateBoard(
          sources: {
            // 1 USD = 43,2563 → la vista recorta con 2 y 3 decimales
            // (la línea «≈» aparece); con «Completo» muestra 43,2563 tal
            // cual y la línea desaparece (V-2/H-26).
            'ves-bcv': RateEntry(rate: 43.2563, updatedAt: DateTime.now()),
          },
        ),
      );
      store.setConverterPair('usd', 'ves');
      // v23.2: viewport de teléfono real — el piso de teclado no exige
      // pantallas gigantes.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(_wrap(const ConverterScreen(), store: store));
      await tester.pumpAndSettle();
      // Escala 2: el pasivo redondea y la «≈» conserva la cifra exacta.
      store.setPrecision(2);
      await tester.pumpAndSettle();
      expect(find.text('43,26'), findsOneWidget);
      expect(find.text('≈ 43,2563'), findsOneWidget);
      // Escala 3.
      store.setPrecision(3);
      await tester.pumpAndSettle();
      expect(find.text('43,256'), findsOneWidget);
      expect(find.text('≈ 43,2563'), findsOneWidget);
      // «Completo» (6): todos los decimales reales, sin ceros de relleno —
      // y sin línea «≈» (la vista ya no recorta nada real).
      store.setPrecision(6);
      await tester.pumpAndSettle();
      expect(find.text('43,2563'), findsOneWidget);
      expect(find.textContaining('≈'), findsNothing);
      expect(store.settings.precision, 6);
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
        // v23.2: teléfono real — dual input y selects a la vista.
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(_wrap(const ConverterScreen(), store: store));
        await tester.pumpAndSettle();
        // Par inicial USD → VES. Escribir 1000 arriba → abajo 40.000 en vivo.
        // v24.1 (patrón calculadora): los campos son de SOLO LECTURA — se
        // escriben con el VeKeypad; tocar un campo cambia el lado ACTIVO.
        Finder tecla(String k) =>
            find.descendant(of: find.byType(VeKeypad), matching: find.text(k));
        Future<void> escribir(
          WidgetTester t,
          Finder campo,
          String cifras,
        ) async {
          await t.tap(campo); // cambia el driver al lado tocado
          await t.pump();
          for (final k in cifras.split('')) {
            await t.tap(tecla(k));
            await t.pump();
          }
        }

        final fields = find.byType(MoneyField);
        // El campo de origen arranca con «1» de cortesía: v29 (H-25) el
        // ⌫ LARGO limpia el campo activo (antes era la ficha «Limpiar»);
        // la entrada nueva queda abierta para escribir.
        await tester.longPress(tecla('⌫'));
        await tester.pump();
        await escribir(tester, fields.first, '1000');
        await tester.pump();
        expect(find.text('1.000'), findsOneWidget);
        expect(find.text('40.000,0000'), findsOneWidget);
        // BIDIRECCIONAL: tocar ABAJO y escribir 80.000 → arriba 2.000.
        await escribir(tester, fields.at(1), '80000');
        await tester.pump();
        expect(find.text('80.000'), findsOneWidget);
        expect(find.text('2.000,0000'), findsOneWidget);
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

    testWidgets('Lista: agregar producto, total y checkout (v29)', (
      tester,
    ) async {
      // TASK-34 (p7): la Lista vive en teléfono — superficie real 390×844
      // (a 800×600 el botón de alta queda bajo la barra pegadiza).
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
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
      // v29 (H-35/H-36): plantillas y toggle «Más» NUNCA aparecen.
      expect(find.text('Plantillas'), findsNothing);
      expect(find.text('Más'), findsNothing);
      expect(find.text('TOTALES'), findsNothing);
      // agrega un ítem (TASK-34: campos VeInput anclados por Key — el
      // placeholder sigue en pantalla para el usuario)
      await tester.enterText(find.byKey(const Key('lista-nombre')), 'Café');
      await tester.enterText(find.byKey(const Key('lista-precio')), '40');
      // La zona de captura vive más abajo (tarjeta del total + presupuesto +
      // cálculos + alta rápida encima): se baja hasta el botón antes de
      // tocarlo y se arrastra UN POCO MÁS para que quede del todo dentro
      // del viewport (el tap del centro caería fuera si queda al borde).
      await tester.scrollUntilVisible(
        find.text('Agregar a la lista'),
        200,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.drag(
        find.byType(Scrollable).first,
        const Offset(0, -120),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Agregar a la lista'));
      await tester.pumpAndSettle();
      expect(store.cart.length, 1);
      // Vuelve al héroe para verificar el total (la fila nueva empujó el
      // contenido hacia abajo).
      await tester.drag(find.byType(Scrollable).first, const Offset(0, 600));
      await tester.pumpAndSettle();
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
      // MoneyField (formato de miles en vivo). TASK-34: «Actualizar precio»
      // pasó a ser «Registrar precio» (lenguaje del prototipo).
      await tester.tap(find.text(store.products.first.name));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.text('REGISTRAR PRECIO'), findsOneWidget);
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
      // Sección Gastos (v17.8): sin carga manual, con compras entra la vista.
      await tester.tap(find.text('Gastos'));
      await tester.pumpAndSettle();
      expect(find.text('Gastado · 1 M'), findsOneWidget);
      expect(find.text('POR TIENDA'), findsOneWidget);
    });

    testWidgets('Análisis (v30 · H-39): 4 secciones conmutan y el rango es '
        'condicional', (tester) async {
      final store = _pumpedStore(tester, dir: 'w7');
      await _initServices(store);
      await tester.pumpWidget(_wrap(const InsightsScreen(), store: store));
      await tester.pumpAndSettle();
      // La barra de secciones es el MISMO control del Conversor: 44 px con
      // píldora — y SOLO 4 secciones.
      expect(
        find.byWidgetPredicate((w) => w is VeSegmented<int> && w.height == 44),
        findsOneWidget,
      );
      for (final s in ['Divisas', 'Inflación', 'Canasta', 'Gastos']) {
        expect(find.text(s), findsOneWidget, reason: s);
      }
      // H-40: «Productos» y «Tasa» salieron del tablero.
      expect(find.text('Tasa'), findsNothing);
      // El rango existe en Divisas…
      expect(
        find.byWidgetPredicate((w) => w is Offstage && w.offstage),
        findsNothing,
      );
      // …y NO en Canasta (R-30f: Offstage — montado, invisible).
      await tester.tap(find.text('Canasta'));
      await tester.pumpAndSettle();
      expect(find.text('Canasta vacía'), findsOneWidget);
      expect(
        find.byWidgetPredicate((w) => w is Offstage && w.offstage),
        findsOneWidget,
      );
      // H-40: el lookup de fecha del Conversor ya no se repite aquí.
      expect(find.text('Consultar tasa por fecha'), findsNothing);
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
          Consumer(
            builder: (context, ref, _) => Center(
              child: ElevatedButton(
                onPressed: () => showNotificationCenter(context, ref),
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
      // TASK-34 (p4): shell adaptativo — este test es de la BARRA MÓVIL,
      // así que la superficie se fija a un teléfono (390×844 lógicos).
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
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
        ProviderScope(
          overrides: [
            appStoreProvider.overrideWith(
              (ref) => store,
              disposeNotifier: false,
            ),
            themeControllerProvider.overrideWith(
              (ref) => ThemeController(),
              disposeNotifier: false,
            ),
            ratesPollerProvider.overrideWith(
              (ref) => _poller,
              disposeNotifier: false,
            ),
            sharedPreferencesProvider.overrideWithValue(_prefs),
            // v18.0: la Lista lee el controlador de sala del árbol.
            roomControllerProvider.overrideWith(
              (ref) => RoomController(store),
              disposeNotifier: false,
            ),
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
      // v30 (H-42): las tasas manuales viven en la sección «TASAS Y
      // FUENTES» de la pantalla única — se scrollea hasta ellas.
      await tester.pumpWidget(_wrap(const SettingsScreen(), store: store));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      // Scroll hasta la sección de manuales.
      await tester.scrollUntilVisible(
        find.text('Tasa manual VES'),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.textContaining('1 USD = 41,5'), findsOneWidget);
      expect(tester.takeException(), isNull, reason: 'sin desbordes a 320 px');
      // Tocar abre el editor compartido (MoneyField).
      await tester.tap(find.text('Tasa manual VES'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(find.text('Tasa manual VES', findRichText: true), findsWidgets);
    });
  });

  group('Banderas (v19 + v23.2): fiat con asset real, cripto pintada', () {
    testWidgets('Flag fiat pinta la imagen; cripto pinta su sello propio', (
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
      // Las 6 divisas fiat tienen asset real (assets/flags): ninguna cae al
      // fallback (ColoredBox del errorBuilder).
      final fiat = Currency.values.where((c) => c != Currency.usdt).length;
      expect(find.byType(Image), findsNWidgets(fiat));
      expect(find.byType(ColoredBox), findsNothing);
      // v23.2: USDT se PINTA con su sello exacto (no cualquier paint).
      expect(
        find.byWidgetPredicate(
          (w) => w is CustomPaint && w.painter is CryptoFlagPainter,
        ),
        findsOneWidget,
      );
    });
  });

  group('Home v26: sin línea de fecha, sin saltos y manual no es offline', () {
    testWidgets('v26: SIN fecha — el usuario ya sabe qué día es', (
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
      // v26 (orden del dueño): ni la fecha larga ni la corta — el reloj del
      // sistema ya las dice; el papel arranca con las acciones y el saludo.
      expect(find.textContaining(' de septiembre de '), findsNothing);
      expect(
        find.textContaining(RegExp(r'^[a-záéíóú]{3} \d{1,2} [a-z]{3}')),
        findsNothing,
      );
      // El saludo (titular del papel, 24 px Space Grotesk) sigue ahí.
      expect(
        find.textContaining(RegExp(r'^Buen(os días|as tardes|as noches)$')),
        findsOneWidget,
      );
      // La cotización sigue a la vista — las tasas viven aquí, ya no en una
      // cinta superior.
      expect(find.text('TU MES'), findsOneWidget);
      expect(find.text('Convertir'), findsWidgets);
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

    testWidgets('v28 · el tour NUNCA arranca solo (sin sobrecapas)', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = _pumpedStore(tester, dir: 'w10');
      await _initServices(store);
      // Onboarding YA hecho: el router arranca en '/' y el shell monta con
      // su _TourTrigger. Con la regla v28 del dueño («sin sobrecapas»), el
      // tour automático quedó DESACTIVADO: el shell monta LIMPIO y el flag
      // se marca para que ningún disparo futuro reintente el overlay.
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
        ProviderScope(
          overrides: [
            appStoreProvider.overrideWith(
              (ref) => store,
              disposeNotifier: false,
            ),
            themeControllerProvider.overrideWith(
              (ref) => ThemeController(),
              disposeNotifier: false,
            ),
            ratesPollerProvider.overrideWith(
              (ref) => _poller,
              disposeNotifier: false,
            ),
            sharedPreferencesProvider.overrideWithValue(prefs),
            // v18.0: el shell/Lista leen el controlador de sala del árbol.
            roomControllerProvider.overrideWith(
              (ref) => RoomController(store),
              disposeNotifier: false,
            ),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      // Frames de sobra: si algún overlay intentara montarse, aparecería.
      for (var i = 0; i < 30; i++) {
        await tester.pump(const Duration(milliseconds: 150));
      }
      // NINGÚN coach mark sobre la pantalla.
      expect(find.text('Tus datos viven en tu teléfono'), findsNothing);
      expect(find.text('1/12'), findsNothing);
      // El disparador marcó el tour como visto (una sola oportunidad).
      expect(isTourDone(prefs), isTrue);
      // El usuario sigue donde estaba: sin navegación forzada.
      expect(router.routerDelegate.currentConfiguration.uri.toString(), '/');
    });
  });

  group('Burbuja de coach mark (TIPs/Tutorial)', () {
    // v25 «HOJA»: popover PLANO — radio 20 · elevación 0 · sin borde. El
    // Material de la tarjeta es el único con radius 20 + elev 0 del overlay.
    final cardFinder = find.byWidgetPredicate(
      (w) =>
          w is Material &&
          w.elevation == 0 &&
          w.borderRadius == BorderRadius.circular(20),
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
      expect(
        size.height,
        lessThan(260),
        reason: 'la tarjeta encoge a su texto',
      );
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

  group('Checkout de Lista (v21.5 · micro-espaciados con carrito real)', () {
    // El teclado del CLI no escribe en campos Flutter, así que la pasada
    // GUI del dueño no pudo ver el checkout CON ítems: estos tests seedean
    // el carrito por store y miden la geometría real del sheet (390×844,
    // el viewport del contrato).
    Future<void> abrirCheckout(
      WidgetTester tester, {
      required List<CartItem> items,
    }) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final store = _pumpedStore(tester, dir: 'wco');
      await _initServices(store);
      for (final it in items) {
        store.addToCart(it);
      }
      await tester.pumpWidget(
        _wrap(const Scaffold(body: SizedBox()), store: store),
      );
      await tester.pumpWidget(
        _wrap(
          Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => showCheckoutSheet(context),
                child: const Text('abrir'),
              ),
            ),
          ),
          store: store,
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();
    }

    testWidgets('recibo por tienda: las filas del desglose respiran', (
      tester,
    ) async {
      // Antes de v21.5 las LedgerRow del desglose iban sin padding: el
      // hueco entre filas medía 0 px. Ahora el ritmo de recibo es 6 px
      // (3 arriba + 3 abajo, patrón de home_screen).
      await abrirCheckout(
        tester,
        items: const [
          CartItem(
            id: 'a',
            name: 'Arroz',
            quantity: 2,
            price: 2,
            currency: 'USD',
          ),
          CartItem(
            id: 'b',
            name: 'Pasta',
            quantity: 1,
            price: 3,
            currency: 'USD',
          ),
        ],
      );
      expect(find.text('2 ítems · 3 unidades · 1 monedas'), findsOneWidget);
      final arroz = tester.getRect(find.text('2 × Arroz'));
      final pasta = tester.getRect(find.text('1 × Pasta'));
      expect(
        pasta.top - arroz.bottom,
        closeTo(6, 0.5),
        reason: 'ritmo vertical del recibo: 3+3 de padding, no filas pegadas',
      );
    });

    testWidgets('héroe del total: rótulo USD en la línea base de la cifra', (
      tester,
    ) async {
      await abrirCheckout(
        tester,
        items: const [
          CartItem(
            id: 'a',
            name: 'Arroz',
            quantity: 1,
            price: 2,
            currency: 'USD',
          ),
        ],
      );
      // El héroe vive en el primer ReadWindow del modal («Total a
      // guardar»); la fila debe alinear por baseline, no al centro.
      final heroRow = tester.widget<Row>(
        find
            .descendant(of: find.byType(ReadWindow), matching: find.byType(Row))
            .first,
      );
      expect(heroRow.crossAxisAlignment, CrossAxisAlignment.baseline);
      expect(heroRow.textBaseline, TextBaseline.alphabetic);
    });

    testWidgets('multitienda: primer campo de tienda abre con lead-in mayor', (
      tester,
    ) async {
      // Un ítem ya trae tienda → el modal nace multitienda ON, un solo
      // grupo con dos campos: el primero abre con 10 px (cierra el recibo
      // el subtotal) y el segundo conserva el ritmo de 6 px.
      await abrirCheckout(
        tester,
        items: const [
          CartItem(
            id: 'a',
            name: 'Arroz',
            quantity: 1,
            price: 2,
            currency: 'USD',
            store: 'Bicentenario',
          ),
          CartItem(
            id: 'b',
            name: 'Pasta',
            quantity: 1,
            price: 3,
            currency: 'USD',
            store: 'Bicentenario',
          ),
        ],
      );
      expect(find.text('Tienda de Arroz'), findsOneWidget);
      expect(find.text('Tienda de Pasta'), findsOneWidget);
      expect(
        find.byWidgetPredicate(
          (w) => w is Padding && w.padding == const EdgeInsets.only(top: 10),
        ),
        findsOneWidget,
        reason: 'solo el primer campo del grupo abre con 10 px',
      );
      expect(
        find.byWidgetPredicate(
          (w) => w is Padding && w.padding == const EdgeInsets.only(top: 6),
        ),
        findsOneWidget,
        reason: 'los siguientes campos conservan el ritmo de 6 px',
      );
    });
  });
}
