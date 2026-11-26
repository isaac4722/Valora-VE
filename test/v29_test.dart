/// Tests v29 · Parte 3 — Conversor (orden del dueño, HALLAZGOS_v29):
/// bug del borrado «1.000»→«100» (V-3 + R-29c), swap vacío sin «0» (H-27 +
/// R-29b/R-29e: inspección de CONTROLADORES), selector de fecha
/// Ayer·Hoy·Mañana·Fecha con su contexto (H-22), título solo (H-21),
/// símbolos en AMBOS campos gemelos (H-23/V-1), notas inline con
/// persistencia (H-28), atajos eliminados (H-25), precisión uniforme
/// (H-26), píldora del segmented clavada a su casilla (H-44) y patrón
/// calculadora sin scroll en 390×844 (H-30).
///
/// R-29d: las fuentes del ASSET se cargan ANTES de los widget tests — el
/// fallback de test mide cada glifo al ancho del fontSize y fabrica
/// overflows falsos.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FontLoader, ByteData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/currencies.dart';
import 'package:valorave/core/fmt.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/converter/converter_screen.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:valorave/providers/providers.dart';
import 'package:valorave/widgets/ui.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Store ligero para widget tests (sin Hive: FakeAsync no hace file IO).
AppStore _pumpedStore() {
  SharedPreferences.setMockInitialValues({});
  return AppStore.withData(const AppData());
}

final NotificationsService _notifs = NotificationsService();
late RatesPoller _poller;
late AlertEngine _alerts;
late SharedPreferences _prefs;

/// Prepara los servicios singleton con prefs mock (await en cada test).
/// El store recibe las prefs: los respaldos de prefs (notas del
/// conversor) también funcionan en el harness.
Future<void> _initServices(AppStore store) async {
  SharedPreferences.setMockInitialValues({});
  _prefs = await SharedPreferences.getInstance();
  store.prefs = _prefs;
  _alerts = AlertEngine(_prefs);
  _poller = RatesPoller(store, _notifs, _alerts);
}

Widget _wrap(Widget child, {required AppStore store}) {
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
      sharedPreferencesProvider.overrideWithValue(_prefs),
    ],
    child: MaterialApp(
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: child,
    ),
  );
}

/// Conversor en teléfono real, con tablero BCV 40 listo.
Future<void> _pumpConverter(
  WidgetTester tester,
  AppStore store, {
  Size size = const Size(390, 844),
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  store.setRateBoard(
    RateBoard(
      sources: {
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026, 9, 17)),
        'ves-parallel': RateEntry(rate: 44, updatedAt: DateTime(2026, 9, 17)),
      },
    ),
  );
  store.setConverterPair('usd', 'ves');
  await tester.pumpWidget(_wrap(const ConverterScreen(), store: store));
  await tester.pumpAndSettle();
}

Finder _tecla(String k) =>
    find.descendant(of: find.byType(VeKeypad), matching: find.text(k));

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // R-29d: fuentes REALES del asset (el fallback fabrica falsos overflows).
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

  group('V-3 · MoneyField: el modo borrado', () {
    testWidgets('borrar un dígito de «1.000» deja «100», jamás «1,00»', (
      tester,
    ) async {
      final store = _pumpedStore();
      await _initServices(store);
      await _pumpConverter(tester, store);
      // Teclado único: «1» de cortesía + 0, 0, 0 → «1.000».
      for (final k in ['0', '0', '0']) {
        await tester.tap(_tecla(k));
        await tester.pump();
      }
      expect(find.text('1.000'), findsOneWidget);
      // ⌫: el texto intermedio «1.00» NO se re-interpreta como 1 coma 00 —
      // la intención de edición se conserva: son 100.
      await tester.tap(_tecla('⌫'));
      await tester.pump();
      expect(find.text('100'), findsOneWidget);
      expect(find.text('1,00'), findsNothing);
    });

    testWidgets('R-29c: REPLACE completo («3.5» pegado) NO es borrado', (
      tester,
    ) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: MoneyField(
                controller: ctrl,
                maxDecimals: 6,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      // Escenario del hallazgo: «1.000,5» en el campo y un pegado completo
      // más corto («3.5») — hábito EN: el punto es decimal, es 3,5.
      ctrl.text = '1.000,5';
      await tester.pump();
      expect(ctrl.text, '1.000,5');
      ctrl.text = '3.5';
      await tester.pump();
      expect(ctrl.text, '3,5');
    });

    testWidgets('modo borrado a nivel de campo: «1.000» → «1.00» → «100»', (
      tester,
    ) async {
      final ctrl = TextEditingController();
      addTearDown(ctrl.dispose);
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: MoneyField(
                controller: ctrl,
                maxDecimals: 6,
                onChanged: (_) {},
              ),
            ),
          ),
        ),
      );
      ctrl.text = '1.000';
      await tester.pump();
      expect(ctrl.text, '1.000');
      // Borrado (subsecuencia): los puntos siguen siendo miles.
      ctrl.text = '1.00';
      await tester.pump();
      expect(ctrl.text, '100');
      // Y borrar la coma decimal de «1,5» junta los dígitos (calculadora).
      ctrl.text = '1,5';
      await tester.pump();
      expect(ctrl.text, '1,5');
      ctrl.text = '15';
      await tester.pump();
      expect(ctrl.text, '15');
    });
  });

  group('H-27 · Swap con campos vacíos (la regla del 0)', () {
    testWidgets('vacío entra, vacío sale — sin «0», sin «0,00», sin herencia', (
      tester,
    ) async {
      final store = _pumpedStore();
      await _initServices(store);
      await _pumpConverter(tester, store);
      // Limpia el campo de origen (⌫ largo) y SWAP con ambos lados vacíos.
      await tester.longPress(_tecla('⌫'));
      await tester.pump();
      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pumpAndSettle();
      expect(store.data.converter.from, 'VES');
      expect(store.data.converter.to, 'USD');
      // R-29e: la aserción inspecciona los CONTROLADORES de los MoneyField
      // (find.text('0') pilla la tecla «0» del teclado).
      final fields = find.byType(MoneyField);
      final desde = tester.widget<MoneyField>(fields.first).controller!;
      final hasta = tester.widget<MoneyField>(fields.at(1)).controller!;
      expect(desde.text, '');
      expect(hasta.text, '');
      expect(find.text('0,00'), findsNothing);
    });

    testWidgets('con monto: el swap lleva el resultado y el pasivo se rellena solo', (
      tester,
    ) async {
      final store = _pumpedStore();
      await _initServices(store);
      await _pumpConverter(tester, store);
      // 1 USD = 40 Bs → swap → origen «40,00» Bs y pasivo «1,0000» USD.
      await tester.tap(find.byIcon(Icons.swap_vert));
      await tester.pumpAndSettle();
      expect(store.data.converter.from, 'VES');
      expect(find.text('40,00'), findsOneWidget);
      expect(find.text('1,0000'), findsOneWidget);
      // R-29b: el guard no salta la limpieza — el pasivo (USD) muestra SOLO
      // el cálculo nuevo, nunca texto heredado del lado viejo.
      expect(find.text('40.000,0000'), findsNothing);
    });
  });

  group('H-22 · Selector de fecha', () {
    testWidgets('Ayer · Hoy · Mañana · Fecha con rótulo y píldora de 44', (
      tester,
    ) async {
      final store = _pumpedStore();
      await _initServices(store);
      await _pumpConverter(tester, store);
      expect(find.text('FECHA DE LA TASA'), findsOneWidget);
      for (final s in ['Ayer', 'Hoy', 'Mañana', 'Fecha']) {
        expect(find.text(s), findsOneWidget);
      }
      // «Hace 7 días» FUERA (cualquier día via «Fecha»).
      expect(find.text('Hace 7 días'), findsNothing);
      // Segmentos de 44 px (H-22) — el control de fecha es el único
      // VeSegmented del Conversor.
      expect(
        find.byWidgetPredicate((w) => w is VeSegmented && w.height == 44),
        findsOneWidget,
      );
      // «Mañana» no consulta histórico: la tasa viva de hoy sigue mandando
      // (resultado «40,0000» con la precisión por defecto) y el contexto
      // dice la intención.
      await tester.tap(find.text('Mañana'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Para mañana · cobro planificado con la tasa de hoy'),
        findsOneWidget,
      );
      expect(find.text('40,0000'), findsOneWidget);
    });
  });

  group('H-21/H-23 · Título solo y campos gemelos', () {
    testWidgets('título «Conversor» SOLO — la tasa vive en su selector', (
      tester,
    ) async {
      final store = _pumpedStore();
      await _initServices(store);
      await _pumpConverter(tester, store);
      expect(find.text('Conversor'), findsOneWidget);
      // El subtítulo gris completo del v28 NO existe.
      expect(
        find.text('Dólar Oficial · 1 USD = 40,0000 VES'),
        findsNothing,
      );
      expect(find.textContaining('Sin tasa disponible'), findsNothing);
      // H-24: el selector delineado lleva sello + nombre + tasa + chevron.
      expect(find.text('BCV · Oficial'), findsOneWidget);
      expect(
        find.textContaining('1 USD = 40,0000 VES · '),
        findsOneWidget,
      );
      expect(find.byIcon(LucideIcons.chevronDown), findsOneWidget);
    });

    testWidgets('símbolos en AMBOS campos, estilo display 30', (tester) async {
      final store = _pumpedStore();
      await _initServices(store);
      await _pumpConverter(tester, store);
      // V-1: el campo destino también pinta su símbolo tras el número.
      final usd = tester.widget<Text>(find.text(r'$'));
      final bs = tester.widget<Text>(find.text('Bs'));
      expect(usd.style?.fontSize, 30);
      expect(bs.style?.fontSize, 30);
      expect(usd.style?.fontFamily, 'SpaceGrotesk');
      expect(bs.style?.fontFamily, 'SpaceGrotesk');
    });
  });

  group('H-28 · Notas inline', () {
    testWidgets('una línea bajo el resultado, pegada al cálculo y persiste', (
      tester,
    ) async {
      final store = _pumpedStore();
      await _initServices(store);
      await _pumpConverter(tester, store);
      // La nota vive INLINE (una línea, sin hoja «Notas»).
      expect(find.text('Nota de esta conversión'), findsOneWidget);
      expect(find.text('NOTAS'), findsNothing);
      // Escribe y espera el debounce de 600 ms (persistencia intacta).
      await tester.enterText(
        find.byType(TextField).last,
        'Cobro del lunes con la tasa del BCV',
      );
      await tester.pump(const Duration(milliseconds: 700));
      expect(
        store.readConversionNotes(),
        'Cobro del lunes con la tasa del BCV',
      );
    });
  });

  group('H-25 · Atajos eliminados (NUNCA aparecen)', () {
    testWidgets('sin fichas, sin ajustes rápidos, sin numMode', (tester) async {
      final store = _pumpedStore();
      await _initServices(store);
      await _pumpConverter(tester, store);
      for (final t in [
        'Limpiar',
        'Fuentes',
        'Tabla',
        'Recientes',
        'Redondear',
        'Decimales',
        '+10 %',
        '−10 %',
        '+100',
        '−100',
        'Hace 7 días',
      ]) {
        expect(find.text(t), findsNothing, reason: t);
      }
      expect(find.byType(VeChip), findsNothing);
      // El teclado es la única vía de entrada.
      expect(find.byType(VeKeypad), findsOneWidget);
    });
  });

  group('H-26 · Precisión uniforme (escala UNA)', () {
    test('fmtNumFull: todos los decimales reales, sin ceros de relleno', () {
      expect(fmtNumFull(40), '40');
      expect(fmtNumFull(40.0), '40');
      expect(fmtNumFull(922.5637), '922,5637');
      expect(fmtNumFull(1234567.5), '1.234.567,5');
      expect(fmtNumFull(0.1), '0,1');
    });

    test('realDecimals: la medida del recorte de la vista', () {
      expect(realDecimals(40), 0);
      expect(realDecimals(43.25), 2);
      expect(realDecimals(43.2563), 4);
    });

    test('fmtMoneyPrecise clamp 2..6 con «Completo» sin relleno', () {
      const ves = Currency.ves;
      expect(fmtMoneyPrecise(43.2563, ves, 2), '43,26');
      expect(fmtMoneyPrecise(43.2563, ves, 3), '43,256');
      expect(fmtMoneyPrecise(43.2563, ves, 4), '43,2563');
      expect(fmtMoneyPrecise(43.2563, ves, 6), '43,2563');
      expect(fmtMoneyPrecise(40, ves, 6), '40');
      // COP conserva 0 por formato local.
      expect(fmtMoneyPrecise(43.2563, Currency.cop, 6), '43');
    });

    test('fmtRatePrecise con «Completo» tampoco rellena', () {
      expect(fmtRatePrecise(40, 4), '40,0000');
      expect(fmtRatePrecise(40, 6), '40');
      expect(fmtRatePrecise(922.5637, 6), '922,5637');
    });
  });

  group('H-44 · Píldora del segmented clavada a su casilla', () {
    testWidgets('VeSegmented: la píldora coincide EXACTO con el segmento', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Center(
              child: SizedBox(
                width: 300,
                child: VeSegmented<int>(
                  value: 1,
                  onChanged: (_) {},
                  segments: const [
                    VeSegment(value: 0, label: 'Ayer'),
                    VeSegment(value: 1, label: 'Hoy'),
                    VeSegment(value: 2, label: 'Mañana'),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final align = tester.widget<AnimatedAlign>(find.byType(AnimatedAlign));
      final pill = tester.getRect(find.byWidget(align.child!));
      final casilla = tester.getRect(
        find
            .ancestor(
              of: find.text('Hoy'),
              matching: find.byType(GestureDetector),
            )
            .first,
      );
      expect(pill.left, closeTo(casilla.left, 0.5));
      expect(pill.right, closeTo(casilla.right, 0.5));
      expect(pill.top, closeTo(casilla.top, 0.5));
      expect(pill.bottom, closeTo(casilla.bottom, 0.5));
    });
  });

  group('H-30 · Patrón calculadora sin scroll (390×844)', () {
    testWidgets('el cuerpo cabe: maxScrollExtent 0 y sin overflow', (
      tester,
    ) async {
      final store = _pumpedStore();
      await _initServices(store);
      await _pumpConverter(tester, store);
      expect(tester.takeException(), isNull);
      final scrollable = find
          .descendant(
            of: find.byType(SingleChildScrollView),
            matching: find.byType(Scrollable),
          )
          .first;
      final state = tester.state<ScrollableState>(scrollable);
      expect(
        state.position.maxScrollExtent,
        0,
        reason: 'sin subtítulo, sin atajos y sin fichas el cuerpo no scrollea',
      );
    });
  });
}
