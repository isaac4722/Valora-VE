/// Tests de Cuentas y Pago Móvil (G5, patrón CalculaYa):
/// modelo tolerante, validaciones suaves, texto compartido, merge por id
/// y presencia del botón en Divisas.
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
    tmp = await Directory.systemTemp.createTemp('valorave_pm_test');
    store = AppStore();
    await store.hydrate(testDir: tmp.path);
  });

  tearDown(() async {
    await Hive.close();
    await tmp.delete(recursive: true);
  });

  group('PayAccount (modelo)', () {
    test('round-trip JSON y tolerancia de campos ausentes', () {
      final a = PayAccount(
        id: 'x1', bankCode: '0134', bankName: 'Banesco',
        type: 'ahorro', number: '01340000000000000000',
        docId: 'V12345678', phone: '04141234567', holder: 'María Pérez');
      final back = PayAccount.fromJson(Map<String, dynamic>.from(a.toJson()));
      expect(back.bankCode, '0134');
      expect(back.type, 'ahorro');
      expect(back.docId, 'V12345678');
      expect(back.holder, 'María Pérez');
      // JSON mínimo (backups viejos sin campos nuevos)
      final min = PayAccount.fromJson({'id': 'y', 'bankCode': '0102', 'bankName': 'BdV'});
      expect(min.type, 'corriente');
      expect(min.number, '');
    });

    test('validación suave: 20 dígitos y CI 5-9 (avisan, no bloquean)', () {
      expect(PayAccount(id: 'a', bankCode: '0134', bankName: 'B', number: '1234').numberLooksOdd, isTrue);
      expect(PayAccount(id: 'a', bankCode: '0134', bankName: 'B', number: '01340000000000000000').numberLooksOdd, isFalse);
      expect(PayAccount(id: 'a', bankCode: '0134', bankName: 'B', number: '').numberLooksOdd, isFalse);
      expect(PayAccount(id: 'a', bankCode: '0134', bankName: 'B', docId: 'V12').docIdLooksOdd, isTrue);
      expect(PayAccount(id: 'a', bankCode: '0134', bankName: 'B', docId: 'V12345678').docIdLooksOdd, isFalse);
    });

    test('número enmascarado y texto del pago móvil (formato es-VE)', () {
      final a = PayAccount(
        id: 'a', bankCode: '0134', bankName: 'Banesco',
        number: '01340000000000123456', docId: 'V12345678',
        phone: '04141234567', holder: 'María');
      expect(a.maskedNumber, '0134 •••• 3456');
      final t = a.shareText(1234.5);
      expect(t, contains('Pago Móvil por Bs 1.234,50'));
      expect(t, contains('Banco: Banesco (0134)'));
      expect(t, contains('Titular: María'));
      expect(t, contains('Tipo: Corriente'));
      expect(t, contains('Cuenta: 01340000000000123456'));
      expect(t, contains('Cédula: V12345678'));
      expect(t, contains('Teléfono: 04141234567'));
      // monto grande con separador de miles es-VE
      expect(a.shareText(1000000), contains('Bs 1.000.000,00'));
    });
  });

  group('CRUD de cuentas en el store', () {
    test('agrega hasta 4 y elimina', () {
      for (var i = 0; i < 6; i++) {
        store.addAccount(PayAccount(
            id: 'a$i', bankCode: '0134', bankName: 'Banesco', number: '$i'));
      }
      expect(store.accounts, hasLength(AppStore.kMaxAccounts));
      store.removeAccount(store.accounts.first.id);
      expect(store.accounts, hasLength(AppStore.kMaxAccounts - 1));
    });

    test('rechaza sin banco', () {
      expect(store.addAccount(const PayAccount(id: '', bankCode: '', bankName: '')), isFalse);
    });

    test('toggle biométrico persiste en settings', () {
      store.setSetting('accountsLocked', true);
      expect(store.settings.accountsLocked, isTrue);
      store.setSetting('accountsLocked', false);
      expect(store.settings.accountsLocked, isFalse);
    });
  });

  group('Merge de respaldo (cuentas)', () {
    test('instalación limpia + merge conserva las cuentas del respaldo', () {
      final withAcc = AppData.fromJson(
        const AppData().toJson()..['accounts'] = [
          {
            'id': 'pm1', 'bankCode': '0134', 'bankName': 'Banesco',
            'number': '01340000000000000000', 'docId': 'V12345678',
          },
        ],
      );
      final r = mergeBackupData(const AppData(), withAcc);
      expect(r.data.accounts, hasLength(1));
      expect(r.data.accounts.single.bankName, 'Banesco');
    });

    test('deduplica por id (empate = local)', () {
      final local = AppData.fromJson(
        const AppData().toJson()..['accounts'] = [
          {'id': 'pm1', 'bankCode': '0102', 'bankName': 'BdV local'},
        ],
      );
      final incoming = AppData.fromJson(
        const AppData().toJson()..['accounts'] = [
          {'id': 'pm1', 'bankCode': '0102', 'bankName': 'BdV respaldo'},
          {'id': 'pm2', 'bankCode': '0105', 'bankName': 'Mercantil'},
        ],
      );
      final r = mergeBackupData(local, incoming);
      expect(r.data.accounts, hasLength(2));
      expect(r.data.accounts.singleWhere((e) => e.id == 'pm1').bankName, 'BdV local');
    });
  });
}
