/// Tests del selector de TASA visual (v19.0): lista agrupada USD/EUR del
/// Inicio, filas [Bandera][Nombre][Precio + símbolo] con color de categoría
/// y acceso a la tasa manual SIN ir a Ajustes (encargo del dueño).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/currencies.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/home/home_screen.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:valorave/widgets/rate_sheet.dart';

AppStore _storeConTablero() {
  final store = AppStore.withData(const AppData());
  store.setRateBoard(RateBoard(sources: {
    'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026, 9, 16, 10)),
    'ves-parallel': RateEntry(rate: 44, updatedAt: DateTime(2026, 9, 16, 10)),
    'cop-trm': RateEntry(rate: 4200, updatedAt: DateTime(2026, 9, 16, 10)),
    'eur-ves-oficial': RateEntry(rate: 45, updatedAt: DateTime(2026, 9, 16, 10)),
  }));
  return store;
}

void main() {
  final notifs = NotificationsService();

  Future<RatesPoller> makePoller(AppStore store) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    return RatesPoller(store, notifs, AlertEngine(prefs));
  }

  void noop() {}

  testWidgets('Home: lista de cotización agrupada USD/EUR con filas visuales', (tester) async {
    final store = _storeConTablero();
    final poller = await makePoller(store);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: poller),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: HomeScreen())),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    // Encabezados de grupo: USD y EUR (banderas + código).
    expect(find.text('USD'), findsWidgets); // héroe + encabezado de grupo
    expect(find.text('EUR'), findsOneWidget);
    // Filas: nombre de la fuente + precio con símbolo de la divisa quote.
    expect(find.text('BCV'), findsWidgets); // héroe + fila
    expect(find.text('Paralelo'), findsWidgets);
    expect(find.text('TRM'), findsOneWidget);
    // La fila EUR puede quedar bajo el pliegue: scroll hasta ella.
    await tester.scrollUntilVisible(
      find.text('EUR Oficial a Bs'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('EUR Oficial a Bs'), findsOneWidget);
    // La fila Manual del país SIEMPRE visible (acceso rápido).
    expect(find.text('Manual'), findsOneWidget);
    // Tocar una fila la activa (fuente global de su divisa).
    await tester.tap(find.text('Paralelo'));
    await tester.pump();
    expect(store.sourceFor(Currency.ves), 'ves-parallel');
  });

  testWidgets('Home: tasa manual desde la fila, SIN ir a Ajustes', (tester) async {
    final store = _storeConTablero();
    final poller = await makePoller(store);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: poller),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const Scaffold(body: HomeScreen())),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    // Lápiz de la fila Manual → editor inline con MoneyField.
    await tester.tap(find.byIcon(Icons.edit_outlined).first);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Tasa manual VES'), findsOneWidget);
    await tester.enterText(find.byType(TextField), '42,5');
    await tester.pump();
    await tester.tap(find.text('Guardar'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    // Guardada y ACTIVADA al instante.
    expect(store.data.manualRates['ves-manual'], 42.5);
    expect(store.sourceFor(Currency.ves), 'ves-manual');
  });

  testWidgets('RateTile: precio + símbolo y estado sin definir', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.light(),
      home: Scaffold(
        body: ListView(children: <Widget>[
          RateTile(sourceId: 'ves-bcv', rate: 40.25, selected: true, onTap: noop),
          RateTile(sourceId: 'ves-manual', rate: 0, selected: false, onTap: noop),
        ]),
      ),
    ));
    expect(find.text('BCV'), findsWidgets); // héroe + fila
    expect(find.text('Manual'), findsOneWidget);
    expect(find.text('40,2500'), findsOneWidget); // fmtRate: 4 decimales ≥ 1
    expect(find.text('—'), findsOneWidget); // manual sin definir
    expect(find.text('Toca el lápiz para fijar tu tasa'), findsOneWidget);
  });
}
