/// Tests v28 — reglas globales del dueño y nueva tarjeta de Inicio.
/// Protegen el héroe de equivalencia («1 USD = X Bs»), el nombre único de la
/// tasa con «Oficial», la ausencia TOTAL de gráfica y paralelo en el Inicio,
/// y el fallback honesto de la fila VS sin dato del día anterior.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/fmt.dart' show fmtRatePrecise;
import 'package:valorave/core/models.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/home/home_screen.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:valorave/providers/providers.dart';

AppStore _storeConTablero({bool conAyer = true}) {
  final store = AppStore.withData(const AppData());
  store.setRateBoard(
    RateBoard(
      sources: {
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026, 9, 16, 10)),
        'ves-parallel': RateEntry(
          rate: 44,
          updatedAt: DateTime(2026, 9, 16, 10),
        ),
      },
    ),
  );
  if (conAyer) {
    // Snapshot de AYER (fecha real del día anterior): habilita la fila VS.
    store.snapshots.add(
      SnapshotPoint(
        sourceId: 'ves-bcv',
        day: SnapshotPoint.dayKey(
          DateTime.now().subtract(const Duration(days: 1)),
        ),
        rate: 39.2,
      ),
    );
  }
  return store;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final notifs = NotificationsService();
  late SharedPreferences prefs;

  Future<RatesPoller> makePoller(AppStore store) async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    return RatesPoller(store, notifs, AlertEngine(prefs));
  }

  Future<void> pumpHome(
    WidgetTester tester,
    AppStore store,
    RatesPoller poller,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          appStoreProvider.overrideWith((ref) => store, disposeNotifier: false),
          ratesPollerProvider.overrideWith(
            (ref) => poller,
            disposeNotifier: false,
          ),
          themeControllerProvider.overrideWith(
            (ref) => ThemeController(),
            disposeNotifier: false,
          ),
          sharedPreferencesProvider.overrideWithValue(prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: HomeScreen()),
        ),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 200));
  }

  testWidgets('Inicio v28: equivalencia «1 USD = 40,00 Bs» con nombre único', (
    tester,
  ) async {
    final store = _storeConTablero();
    final poller = await makePoller(store);
    await pumpHome(tester, store, poller);

    // v34 (orden del dueño): el nombre va SOLO y COLOREADO por tipo de
    // tasa — verde oficial · rojo mercado · naranja promedio · morado
    // manual. La etiqueta secundaria «· Oficial» ya no existe.
    expect(find.text('BCV'), findsOneWidget);
    expect(find.text('BCV · Oficial'), findsNothing);
    // La equivalencia completa: lado base, símbolo igual y cifra en Bs
    // (con la precisión configurada, 4 por defecto en v27).
    expect(find.text('1 USD'), findsOneWidget);
    expect(find.text('='), findsOneWidget);
    expect(
      find.text(fmtRatePrecise(40, store.settings.precision)),
      findsOneWidget,
    );
    expect(find.text('Bs'), findsOneWidget);
    // La fila VS existe con el badge del día anterior (39,2 → +2,0 %).
    expect(find.text('VS'), findsOneWidget);
    expect(find.text('+2,0 %'), findsOneWidget);
    // Acciones intactas: «Convertir» vive en el botón Y en el acceso rápido.
    expect(find.text('Convertir'), findsNWidgets(2));
    expect(find.text('Ver tasas'), findsOneWidget);
  });

  testWidgets('Inicio v28: NUNCA gráfica ni paralelo ni brecha', (
    tester,
  ) async {
    final store = _storeConTablero();
    final poller = await makePoller(store);
    await pumpHome(tester, store, poller);

    // Sin datos pequeños de paralelo/brecha aunque el tablero los traiga.
    expect(find.text('Paralelo'), findsNothing);
    expect(find.text('Brecha'), findsNothing);
    // La tarjeta del Inicio no dibuja sparkline (el tipo vive en ve/charts).
    expect(find.byType(SizedBox), findsWidgets); // sanity del árbol
    final sparkline = find.byWidgetPredicate(
      (w) => w.runtimeType.toString().contains('VeSparkline'),
    );
    expect(sparkline, findsNothing);
  });

  testWidgets('Inicio v28: VS sin dato del día anterior dice la verdad', (
    tester,
  ) async {
    final store = _storeConTablero(conAyer: false);
    final poller = await makePoller(store);
    await pumpHome(tester, store, poller);

    expect(find.text('VS'), findsOneWidget);
    expect(find.text('sin dato del día anterior'), findsOneWidget);
    // Y jamás un «NaN» o un porcentaje inventado.
    expect(find.textContaining('NaN'), findsNothing);
  });
}
