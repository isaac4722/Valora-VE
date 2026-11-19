/// Tests de tasas personalizadas nombradas (GUI simple, patrón CalculaYa):
/// CRUD + límite 8 + brecha + merge de respaldo por id.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:valorave/data/backup.dart';
import 'package:valorave/data/store.dart';

void main() {
  late Directory tmp;
  late AppStore store;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('valorave_cr_test');
    store = AppStore();
    await store.hydrate(testDir: tmp.path);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  group('Tasas personalizadas (CRUD)', () {
    test('agrega, actualiza y elimina', () {
      expect(store.addCustomRate('Zelle', 42.5), isTrue);
      expect(store.customRates, hasLength(1));
      expect(store.customRates.single.name, 'Zelle');
      expect(store.customRates.single.bsPerUsd, 42.5);

      final id = store.customRates.single.id;
      store.updateCustomRate(id, name: 'Zelle+', bsPerUsd: 43);
      expect(store.customRates.single.name, 'Zelle+');
      expect(store.customRates.single.bsPerUsd, 43);

      store.removeCustomRate(id);
      expect(store.customRates, isEmpty);
    });

    test('rechaza vacíos y no-positivos', () {
      expect(store.addCustomRate('  ', 40), isFalse);
      expect(store.addCustomRate('X', 0), isFalse);
      expect(store.addCustomRate('X', -1), isFalse);
      expect(store.customRates, isEmpty);
    });

    test('límite de 8 tasas', () {
      for (var i = 0; i < 10; i++) {
        store.addCustomRate('T$i', 40 + i.toDouble());
      }
      expect(store.customRates, hasLength(AppStore.kMaxCustomRates));
    });

    test('brecha vs BCV disponible desde el tablero', () {
      store.setRateBoard(RateBoard(sources: {
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now()),
      }));
      expect(store.bcvRate, 40);
      store.addCustomRate('Efectivo', 44);
      // brecha = (44/40 - 1)*100 = 10 %
      final gap = (store.customRates.single.bsPerUsd / store.bcvRate! - 1) * 100;
      expect(gap, closeTo(10, 0.001));
    });

    test('round-trip JSON tolerante (respaldo viejo sin customRates)', () {
      store.addCustomRate('Binance', 41);
      final json = store.data.toJson();
      expect((json['customRates'] as List), isNotEmpty);
      // JSON sin la clave → lista vacía (backups antiguos cargan igual)
      final old = Map<String, dynamic>.from(json)..remove('customRates');
      final fromOld = AppData.fromJson(old);
      expect(fromOld.customRates, isEmpty);
      // y con la clave → ida y vuelta exacta
      final back = AppData.fromJson(Map<String, dynamic>.from(json));
      expect(back.customRates.single.name, 'Binance');
      expect(back.customRates.single.bsPerUsd, 41);
    });
  });

  group('Merge de respaldo (unión por id, no local-only)', () {
    test('instalación limpia + merge conserva las tasas del respaldo', () {
      final incoming = const AppData();
      // construir incoming con 2 tasas
      final withRates = AppData.fromJson(
        const AppData().toJson()..['customRates'] = [
          {'id': 'a1', 'name': 'Zelle', 'bsPerUsd': 42.0},
          {'id': 'a2', 'name': 'Binance', 'bsPerUsd': 41.0},
        ],
      );
      final r = mergeBackupData(incoming, withRates);
      expect(r.data.customRates, hasLength(2));
      expect(r.data.customRates.map((e) => e.name), containsAll(['Zelle', 'Binance']));
    });

    test('merge deduplica por id (empate = local)', () {
      final local = AppData.fromJson(
        const AppData().toJson()..['customRates'] = [
          {'id': 'a1', 'name': 'Zelle local', 'bsPerUsd': 42.0},
        ],
      );
      final incoming = AppData.fromJson(
        const AppData().toJson()..['customRates'] = [
          {'id': 'a1', 'name': 'Zelle respaldo', 'bsPerUsd': 50.0},
          {'id': 'a2', 'name': 'Binance', 'bsPerUsd': 41.0},
        ],
      );
      final r = mergeBackupData(local, incoming);
      expect(r.data.customRates, hasLength(2));
      final zelle = r.data.customRates.singleWhere((e) => e.id == 'a1');
      expect(zelle.name, 'Zelle local'); // empate → gana local
    });
  });
}
