/// Tests de los App Widgets — los de la PANTALLA DE INICIO de Android
/// (v19.6): galería con previews fieles, pin al launcher (canal
/// «valorave/widgets») y guía manual de respaldo. Los widgets
/// configurables DENTRO de la app se retiraron por orden del dueño: el
/// Inicio vuelve a sus secciones fijas y el «+» abre esta galería.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:valorave/widgets/app_router.dart';
import 'package:valorave/features/home/app_widgets.dart';
import 'package:valorave/features/more/more_screen.dart';
import 'package:valorave/widgets/app_tour.dart' show kTourDoneKey;
import 'package:valorave/providers/providers.dart';

Purchase _compra(int i) => Purchase(
  id: 'c$i',
  date: DateTime(2026, 9, 1 + i),
  store: 'Tienda $i',
  items: const <PurchaseItem>[],
  totalUSD: 1.0 + i,
  totalBS: 0,
  rate: 1,
);

Transaction _ingreso(int i) => Transaction(
  id: 't$i',
  type: 'income',
  category: FinanceCategory.otrosIngresos,
  amount: 10,
  currency: 'USD',
  amountUSD: 10,
  date: DateTime(2026, 9, 2 + i),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const pinChannel = MethodChannel('valorave/widgets');

  late AppStore store;
  late RatesPoller poller;
  late SharedPreferences prefs;

  /// El scroll de la hoja de la galería.
  final sheetScroll = find.byType(Scrollable).first;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    // El tour auto-arrancaría y taparía la UI: ya visto.
    await prefs.setBool(kTourDoneKey, true);
    store = AppStore.withData(
      AppData(
        settings: const Settings(onboarded: true),
        purchases: <Purchase>[for (var i = 0; i < 5; i++) _compra(i)],
        transactions: <Transaction>[for (var i = 0; i < 5; i++) _ingreso(i)],
      ),
    );
    // Tablero con el par BCV/paralelo — la preview de la galería pinta
    // las MISMAS cifras que el widget nativo (fetchedAt lo pone el store).
    store.setRateBoard(
      RateBoard(
        sources: {
          'ves-bcv': RateEntry(rate: 234.89, updatedAt: DateTime(2026, 9, 17)),
          'ves-parallel': RateEntry(
            rate: 260.00,
            updatedAt: DateTime(2026, 9, 17),
          ),
        },
        providers: const ['dolarapi.com'],
      ),
    );
    final notifs = NotificationsService();
    final alerts = AlertEngine(prefs);
    poller = RatesPoller(store, notifs, alerts);
  });

  Future<GoRouter> pumpHome(WidgetTester tester) async {
    final router = buildRouter(store: store);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStoreProvider.overrideWith((ref) => store, disposeNotifier: false),
          // TASK-35 (p2): la cabecera de Inicio y el sidebar observan el
          // tema (toggle claro/oscuro) — como appProviders en producción.
          themeControllerProvider.overrideWith(
            (ref) => ThemeController(),
            disposeNotifier: false,
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
          ratesPollerProvider.overrideWith(
            (ref) => poller,
            disposeNotifier: false,
          ),
        ],
        // La app real arranca bajo ShadApp.custom + MaterialApp.router
        // (main.dart · TASK-34 p4): ShadTheme arriba, Material de verdad.
        child: MaterialApp.router(
          theme: AppTheme.light(),
          routerConfig: router,
        ),
      ),
    );
    await tester.pump();
    return router;
  }

  /// Despliega «Ver todo» (v23: lo cotidiano-ocasional vive tras el pliegue)
  /// y lleva la tarjeta «+» a la vista para abrir la galería. Bombeo
  /// acotado (NO pumpAndSettle): el LoadingState con tablero vacío nunca
  /// asienta y el ticker del Inicio anima siempre.
  Future<void> abrirGaleria(WidgetTester tester, GoRouter router) async {
    // v30 (H-42): la galería vive en Ajustes → General → Widgets de
    // Android (la subpantalla `/ajustes/general` redirige a `/ajustes`).
    router.go('/ajustes');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    await tester.scrollUntilVisible(
      find.text('Añadir un widget'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Añadir un widget'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AppWidgetsPage), findsOneWidget);
    expect(
      find.textContaining('viven en tu pantalla de inicio de Android'),
      findsOneWidget,
    );
  }

  testWidgets('Inicio: tasa, acciones, tu mes y actividad — sin acordeones', (
    tester,
  ) async {
    // Viewport alto para que la lista pinte todos los bloques (es un test
    // de contenido, no de scroll).
    tester.view.physicalSize = const Size(390, 1600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpHome(tester);
    // v27: el Inicio es una pantalla de inicio de verdad: una cifra, cuatro
    // acciones, el mes y la actividad. La cotización completa vive en Tasas.
    expect(find.text('TU MES'), findsOneWidget);
    expect(find.text('ACTIVIDAD RECIENTE'), findsOneWidget);
    expect(find.text('Convertir'), findsWidgets);
    expect(find.text('Cuentas'), findsOneWidget);
    expect(find.text('TODO LO DEMÁS'), findsNothing);
    expect(find.text('COTIZACIÓN PRINCIPAL'), findsNothing);
    expect(find.text('DIVISAS DEL FOCO'), findsNothing);
    expect(find.text('ALERTAS DE PRECIOS'), findsNothing);
    expect(find.text('HERRAMIENTAS'), findsNothing);
    // Sin el sistema retirado de widgets configurables.
    expect(find.byType(SegmentedButton<dynamic>), findsNothing);
    expect(find.text('En Inicio'), findsNothing);
    expect(find.text('Inicio limpio'), findsNothing);
  });

  testWidgets('Más (v30 · H-41): SOLO los módulos autónomos, sin buscador', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = await pumpHome(tester);
    router.go('/mas');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Más'), findsWidgets);
    // Scoped a la pantalla (la barra del shell tiene su propia pestaña
    // «Análisis» y «Más»).
    final mas = find.byType(MoreScreen);
    Finder enMas(String t) => find.descendant(of: mas, matching: find.text(t));
    // Los 5 módulos que quedan.
    for (final m in [
      'Productos',
      'Tickets',
      'Ajustes',
      'Actualizaciones',
      'Privacidad y licencias',
    ]) {
      expect(enMas(m), findsOneWidget, reason: m);
    }
    // H-41: duplicados y no-autónomos FUERA — Análisis, Historial, Sala en
    // vivo, Cuentas y Escanear viven en sus sitios, no aquí.
    for (final fuera in [
      'Análisis',
      'Historial',
      'Sala en vivo',
      'Cuentas y Pago Móvil',
      'Escanear',
    ]) {
      expect(enMas(fuera), findsNothing, reason: fuera);
    }
    // Sin buscador: 5 módulos no lo necesitan.
    expect(
      find.descendant(of: mas, matching: find.byType(TextField)),
      findsNothing,
    );
  });

  testWidgets('la galería muestra los 3 widgets con preview fiel', (
    tester,
  ) async {
    // v23.3: la galería vive en showVeHalfSheet — en escritorio (≥700) la
    // media pantalla se vuelve diálogo; el contexto honesto de una
    // galería de widgets de ANDROID es el teléfono (390×844).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = await pumpHome(tester);
    await abrirGaleria(tester, router);
    // La hoja se pinta SOBRE el Inicio: los asserts de cifras van
    // acotados a su interior (el Home de atrás también las muestra).
    final sheet = find.byType(AppWidgetsPage);
    Finder enHoja(String t) =>
        find.descendant(of: sheet, matching: find.text(t));
    // Las dos primeras entradas quedan a la vista al abrir la hoja.
    expect(enHoja('Tasa BCV'), findsOneWidget);
    expect(enHoja('BCV · USD'), findsOneWidget);
    expect(enHoja('PARALELO · USD'), findsOneWidget);
    // Preview fiel: las MISMAS cifras es-VE que el widget nativo pinta
    // con este tablero (234,89 · 260,00 — fmtNum, decimales 2).
    expect(enHoja('234,89'), findsOneWidget);
    expect(enHoja('Paralelo 260,00'), findsOneWidget);
    expect(enHoja('BCV 234,89'), findsOneWidget);
    // La tercera (Brecha) vive bajo el pliegue: se scrollea a la vista.
    await tester.scrollUntilVisible(
      enHoja('BRECHA BCV ↔ PARALELO'),
      300,
      scrollable: sheetScroll,
    );
    await tester.pump();
    expect(enHoja('BRECHA BCV ↔ PARALELO'), findsOneWidget);
    // La nota de resizing del launcher vive al pie de la hoja.
    await tester.scrollUntilVisible(
      find.textContaining('Se estiran'),
      300,
      scrollable: sheetScroll,
    );
    await tester.pump();
    expect(
      find.descendant(of: sheet, matching: find.textContaining('Se estiran')),
      findsOneWidget,
    );
  });

  testWidgets('añadir pide el pin al canal nativo del launcher', (
    tester,
  ) async {
    final calls = <MethodCall>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(pinChannel, (
      message,
    ) async {
      calls.add(message);
      return true;
    });
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pinChannel,
        null,
      ),
    );

    // v23.3: contexto móvil (ver nota del test de la galería).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final router = await pumpHome(tester);
    await abrirGaleria(tester, router);
    // El botón de la primera entrada (Tasa BCV).
    await tester.ensureVisible(find.text('Tasa BCV'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Añadir').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // El pin llegó al nativo con el proveedor correcto…
    expect(calls, hasLength(1));
    expect(calls.first.method, 'pinWidget');
    expect(calls.first.arguments, <String, dynamic>{
      'provider': 'BcvWidgetProvider',
    });
    // …y el aviso de confirmación del launcher salió.
    expect(
      find.textContaining('el launcher pide confirmar el widget'),
      findsOneWidget,
    );
  });

  testWidgets('launcher sin soporte → guía manual de 3 pasos', (tester) async {
    // v23.3: contexto móvil (ver nota del test de la galería).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      pinChannel,
      (message) async =>
          throw PlatformException(code: 'unsupported', message: 'no pin'),
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        pinChannel,
        null,
      ),
    );

    final router = await pumpHome(tester);
    await abrirGaleria(tester, router);
    await tester.ensureVisible(find.text('Tasa BCV'));
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.text('Añadir').first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    // La guía manual, con los pasos del sistema.
    expect(find.text('Añadir a mano'), findsOneWidget);
    expect(
      find.textContaining('Mantén presionado un espacio vacío'),
      findsOneWidget,
    );
    expect(find.textContaining('Busca ValoraVE'), findsOneWidget);
    // Cierre del diálogo (el «Listo» del AlertDialog, no el de la hoja):
    // dos bombeos — arranca y termina la animación de salida.
    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Listo'),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(AlertDialog), findsNothing);
  });
}
