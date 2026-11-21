/// Tests de los App Widgets — los de la PANTALLA DE INICIO de Android
/// (v19.6): galería con previews fieles, pin al launcher (canal
/// «valorave/widgets») y guía manual de respaldo. Los widgets
/// configurables DENTRO de la app se retiraron por orden del dueño: el
/// Inicio vuelve a sus secciones fijas y el «+» abre esta galería.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/core/shad_theme.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:valorave/widgets/app_router.dart';
import 'package:valorave/widgets/app_tour.dart' show kTourDoneKey;

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
  final sheetScroll = find
      .descendant(
        of: find.byType(DraggableScrollableSheet),
        matching: find.byType(Scrollable),
      )
      .first;

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

  Future<void> pumpHome(WidgetTester tester) async {
    final router = buildRouter(store: store);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          // TASK-35 (p2): la cabecera de Inicio y el sidebar observan el
          // tema (toggle claro/oscuro) — como appProviders en producción.
          ChangeNotifierProvider<ThemeController>.value(
            value: ThemeController(),
          ),
          Provider<SharedPreferences>.value(value: prefs),
          ChangeNotifierProvider.value(value: poller),
        ],
        // La app real arranca bajo ShadApp.custom + MaterialApp.router
        // (main.dart · TASK-34 p4): ShadTheme arriba, Material de verdad.
        child: ShadApp.custom(
          theme: ShadThemeVe.light(),
          darkTheme: ShadThemeVe.dark(),
          appBuilder: (context) => MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
  }

  /// Despliega «Ver todo» (v23: lo cotidiano-ocasional vive tras el pliegue)
  /// y lleva la tarjeta «+» a la vista para abrir la galería. Bombeo
  /// acotado (NO pumpAndSettle): el LoadingState con tablero vacío nunca
  /// asienta y el ticker del Inicio anima siempre.
  /// El scroll del Inicio: el Scrollable QUE ENVUELVE al pliegue «Todo lo
  /// demás» (tras expandir aparecen scrollables nuevos dentro de las
  /// secciones y un `.last` dejaría de apuntar a la lista).
  Finder homeScroll() => find
      .ancestor(of: find.text('TODO LO DEMÁS'), matching: find.byType(Scrollable))
      .first;

  Future<void> abrirGaleria(WidgetTester tester) async {
    await tester.scrollUntilVisible(
      find.text('Ver todo'),
      200,
      scrollable: homeScroll(),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ver todo'));
    await tester.pump(const Duration(milliseconds: 400));
    // La tarjeta «+» vive al fondo del contenido desplegado: el pliegue es
    // UN hijo de la lista y construye TODAS sus secciones de una vez — el
    // finder las halla aunque estén fuera del viewport y el
    // scrollUntilVisible se da por satisfecho. Arrastre manual acotado
    // hasta que la tarjeta entre en pantalla.
    final tarjeta = find.text('App Widgets');
    for (var i = 0; i < 10; i++) {
      final box = tester.renderObject<RenderBox>(tarjeta);
      if (box.localToGlobal(Offset.zero).dy < 520) break;
      await tester.drag(homeScroll(), const Offset(0, -300));
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(tarjeta);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.byType(DraggableScrollableSheet), findsOneWidget);
    expect(
      find.textContaining('viven en tu pantalla de inicio de Android'),
      findsOneWidget,
    );
  }

  testWidgets('el Inicio resume en bloques y «Ver todo» no quita nada', (
    tester,
  ) async {
    await pumpHome(tester);
    // A la vista: lo que el usuario viene a ver (B2 cotiza). v23.2: las
    // divisas del foco y el resumen del mes también viven tras «Ver todo» —
    // la Cotización compacta queda de primera pantalla.
    expect(find.text('COTIZACIÓN PRINCIPAL'), findsOneWidget);
    expect(find.text('DIVISAS DEL FOCO'), findsNothing);
    expect(find.text('RESUMEN DEL MES'), findsNothing);
    // v23: despliegue progresivo — plegado por defecto, a un toque.
    expect(find.text('TODO LO DEMÁS'), findsOneWidget);
    expect(find.text('Ver todo'), findsOneWidget);
    expect(find.text('ALERTAS DE PRECIOS'), findsNothing);
    expect(find.text('TUS TIENDAS'), findsNothing);
    expect(find.text('HERRAMIENTAS'), findsNothing);
    // Desplegar expone las secciones de siempre, en su orden.
    await tester.scrollUntilVisible(
      find.text('Ver todo'),
      200,
      scrollable: homeScroll(),
    );
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Ver todo'));
    await tester.pump(const Duration(milliseconds: 400));
    // v23.2: divisas y resumen también viven tras «Ver todo».
    expect(find.text('DIVISAS DEL FOCO'), findsOneWidget);
    expect(find.text('RESUMEN DEL MES'), findsOneWidget);
    expect(find.text('ALERTAS DE PRECIOS'), findsOneWidget);
    expect(find.text('TUS TIENDAS'), findsOneWidget);
    expect(find.text('REGISTROS RECIENTES'), findsOneWidget);
    expect(find.text('HERRAMIENTAS'), findsOneWidget);
    // La única puerta de widgets: la tarjeta de App Widgets.
    expect(find.text('App Widgets'), findsOneWidget);
    expect(find.textContaining('Tasa BCV, Paralelo y Brecha'), findsOneWidget);
    // Cerrar replega sin perder nada del árbol.
    await tester.ensureVisible(find.text('Cerrar'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Cerrar'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('ALERTAS DE PRECIOS'), findsNothing);
    // Nada del sistema retirado: sin selectores de tamaño ni altas/bajas.
    expect(find.byType(SegmentedButton<dynamic>), findsNothing);
    expect(find.text('En Inicio'), findsNothing);
    expect(find.text('Inicio limpio'), findsNothing);
  });

  testWidgets('Libro: la sección del sidebar también vive en móvil', (
    tester,
  ) async {
    // Viewport móvil 390×844: sin sidebar, la única puerta a Historial/
    // Tickets/Ajustes es el bloque «Libro» al pie del Inicio (v23).
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    await pumpHome(tester);
    expect(find.text('LIBRO'), findsOneWidget);
    expect(find.text('Historial'), findsOneWidget);
    expect(find.text('Tickets'), findsOneWidget);
    expect(find.text('Ajustes'), findsWidgets);
    // La puerta de Tickets navega a la galería (ruta fuera del shell).
    await tester.ensureVisible(find.text('Tickets'));
    await tester.pump(const Duration(milliseconds: 300));
    await tester.tap(find.text('Tickets'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Galería'), findsOneWidget);
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
    await pumpHome(tester);
    await abrirGaleria(tester);
    // La hoja se pinta SOBRE el Inicio: los asserts de cifras van
    // acotados a su interior (el Home de atrás también las muestra).
    final sheet = find.byType(DraggableScrollableSheet);
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
    await pumpHome(tester);
    await abrirGaleria(tester);
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

    await pumpHome(tester);
    await abrirGaleria(tester);
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
