/// Tests de las tasas personalizadas con nombre (v23 · comparativa
/// CalculaYa): CRUD del store, aplicación por el mecanismo manual, merge de
/// respaldo por id, round-trip del modelo y la fila del Inicio con GapChip.
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/currencies.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/backup.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/rates/rates_screen.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:valorave/providers/providers.dart';

AppData _conRates(List<CustomRate> rates) =>
    AppData(customRates: rates, settings: const Settings(onboarded: true));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Modelo CustomRate', () {
    test('round-trip toJson/tryParse', () {
      const r = CustomRate(id: 'a1', name: 'Zelle', bsPerUsd: 46.5);
      final parsed = CustomRate.tryParse(Map<String, dynamic>.from(r.toJson()));
      expect(parsed, isNotNull);
      expect(parsed!.name, 'Zelle');
      expect(parsed.bsPerUsd, 46.5);
    });

    test('tryParse tolerante: basura no entra', () {
      expect(CustomRate.tryParse({}), isNull);
      expect(
        CustomRate.tryParse({'id': 'x', 'name': '  ', 'bsPerUsd': 10}),
        isNull,
      );
      expect(
        CustomRate.tryParse({'id': 'x', 'name': 'Ok', 'bsPerUsd': -3}),
        isNull,
      );
    });

    test('AppData viejo sin customRates carga vacío (tolerante)', () {
      final d = AppData.fromJson({'version': 1});
      expect(d.customRates, isEmpty);
      // Round-trip del agregado.
      final d2 = AppData.fromJson(
        Map<String, dynamic>.from(
          _conRates(const [
            CustomRate(id: 'z', name: 'Zelle', bsPerUsd: 40),
          ]).toJson(),
        ),
      );
      expect(d2.customRates, hasLength(1));
      expect(d2.customRates.first.name, 'Zelle');
    });
  });

  group('Store: CRUD y aplicar', () {
    late Directory tmp;
    late AppStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tmp = await Directory.systemTemp.createTemp('valorave_cr');
      store = AppStore();
      await store.hydrate(testDir: tmp.path);
    });

    tearDown(() async {
      await Hive.close();
      await tmp.delete(recursive: true);
    });

    test('addCustomRate valida nombre, valor y tope de 8', () {
      expect(store.addCustomRate('Zelle', 46.5), isTrue);
      // Nombre repetido (case-insensitive, como CalculaYa).
      expect(store.addCustomRate('zelle', 50), isFalse);
      // Vacío / inválido.
      expect(store.addCustomRate('  ', 40), isFalse);
      expect(store.addCustomRate('Mal', -1), isFalse);
      // Tope.
      for (final n in ['B', 'C', 'D', 'E', 'F', 'G', 'H']) {
        expect(store.addCustomRate(n, 40), isTrue);
      }
      expect(store.addCustomRate('I', 40), isFalse);
      expect(store.data.customRates, hasLength(8));
    });

    test('removeCustomRate retira por id y persiste el resto', () {
      store.addCustomRate('Zelle', 46.5);
      store.addCustomRate('Efectivo', 48);
      final id = store.data.customRates.first.id;
      store.removeCustomRate(id);
      expect(store.data.customRates, hasLength(1));
      expect(store.data.customRates.first.name, 'Efectivo');
    });

    test('applyCustomRate: reusa el mecanismo manual (cero core)', () {
      store.addCustomRate('Zelle', 46.5);
      store.applyCustomRate(store.data.customRates.first);
      // La tasa viaja por la fuente manual EXISTENTE…
      expect(store.data.manualRates['ves-manual'], 46.5);
      // …y queda ACTIVA como fuente de VES, como el editor de siempre.
      expect(store.sourceFor(CurrencyX.from('VES')), 'ves-manual');
    });
  });

  group('Merge de respaldo', () {
    test('unión por id: la tasa del respaldo sobrevive (no local-only)', () {
      final local = _conRates(const [
        CustomRate(id: 'keep', name: 'Zelle', bsPerUsd: 46),
      ]);
      final incoming = AppData(
        customRates: const [
          CustomRate(id: 'keep', name: 'Zelle', bsPerUsd: 99), // empate=local
          CustomRate(id: 'nueva', name: 'Binance', bsPerUsd: 52),
        ],
      );
      final res = mergeBackupData(local, incoming);
      expect(res.data.customRates, hasLength(2));
      expect(
        res.data.customRates.firstWhere((r) => r.id == 'keep').bsPerUsd,
        46,
      );
      expect(
        res.data.customRates.firstWhere((r) => r.id == 'nueva').name,
        'Binance',
      );
    });

    test('sin customRates en el respaldo: las locales intactas', () {
      final local = _conRates(const [
        CustomRate(id: 'keep', name: 'Zelle', bsPerUsd: 46),
      ]);
      final res = mergeBackupData(local, AppData());
      expect(res.data.customRates, hasLength(1));
    });
  });

  group('Tasas: fila de tasa propia + GapChip', () {
    // Patrón de app_widgets_test: AppStore.withData (sin Hive) + un poller
    // por prueba; _persist sin caja abierta es seguro (solo notifica).
    late AppStore store;
    late RatesPoller poller;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      store = AppStore.withData(
        AppData(settings: const Settings(onboarded: true)),
      );
      poller = RatesPoller(store, NotificationsService(), AlertEngine(prefs));
    });

    Future<void> pumpRates(WidgetTester tester) async {
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
              (ref) => poller,
              disposeNotifier: false,
            ),
          ],
          // Mismo shell que la app (main.dart): ShadTheme arriba del
          // MaterialApp — la GUI «Ve» lo exige.
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(child: RatesBoard()),
            ),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
    }

    testWidgets('fila con nombre, brecha vs BCV y tap aplica la manual', (
      tester,
    ) async {
      store.setRateBoard(
        RateBoard(
          sources: {
            'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026, 9, 17)),
          },
        ),
      );
      store.addCustomRate('Zelle', 46.4);
      await pumpRates(tester);
      // Grupo «TUS TASAS» con el nombre y la brecha (46,4/40 − 1 = +16,0 %).
      expect(find.text('TUS TASAS'), findsOneWidget);
      expect(find.text('Zelle'), findsOneWidget);
      expect(find.text('+16,0 % vs BCV'), findsOneWidget);
      // Tocar la fila aplica por el mecanismo manual y la activa.
      await tester.tap(find.text('Zelle'));
      await tester.pump(const Duration(milliseconds: 300));
      expect(store.data.manualRates['ves-manual'], 46.4);
      expect(store.sourceFor(CurrencyX.from('VES')), 'ves-manual');
    });

    testWidgets('sin BCV no hay brecha: jamás un «NaN»', (tester) async {
      // Tablero sin ves-bcv: la fila vive, el chip no.
      store.setRateBoard(
        RateBoard(
          sources: {
            'cop-trm': RateEntry(rate: 4000, updatedAt: DateTime(2026, 9, 17)),
          },
        ),
      );
      store.addCustomRate('Efectivo', 48);
      await pumpRates(tester);
      expect(find.text('Efectivo'), findsOneWidget);
      expect(find.textContaining('% vs BCV'), findsNothing);
    });
  });
}
