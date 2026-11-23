/// Tests v27 · precisión decimal, cuentas con alias/principal e insignias
/// de banco. Cubren lo nuevo del GUI/UX sin depender de Hive.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/core/banks_ve.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/data/store.dart';

void main() {
  group('Precisión decimal (REA CalculaYa)', () {
    test('default 2 · setPrecision clamp 2..4 · persiste en JSON', () {
      const s = Settings(onboarded: true);
      expect(s.precision, 2);
      expect(s.copyWith(precision: 4).toJson()['precision'], 4);
      final parsed = Settings.fromJson({'precision': 9});
      expect(parsed.precision, 4);
      expect(Settings.fromJson(const {}).precision, 2);
    });

    test('AppStore.setPrecision actualiza el ajuste', () {
      final store = AppStore.withData(const AppData());
      store.setPrecision(3);
      expect(store.settings.precision, 3);
      store.setPrecision(1);
      expect(store.settings.precision, 2);
    });
  });

  group('Cuentas de cobro (v27)', () {
    test('alias y cuenta principal viajan en el JSON', () {
      const a = PayAccount(
        id: 'a1',
        bank: 'Banesco',
        type: 'ahorro',
        number: '0134',
        label: 'Principal',
        isDefault: true,
      );
      final parsed = PayAccount.tryParse(Map<String, dynamic>.from(a.toJson()));
      expect(parsed!.label, 'Principal');
      expect(parsed.isDefault, isTrue);
      expect(parsed.displayLabel, 'Principal');
      expect(parsed.typeLabel, 'Ahorro');
    });

    test(
      'la primera cuenta es principal; setDefaultAccount mueve la estrella',
      () {
        final store = AppStore.withData(const AppData());
        store.addAccount(
          const PayAccount(
            id: 'a',
            bank: 'Banesco',
            type: 'corriente',
            number: '1',
          ),
        );
        store.addAccount(
          const PayAccount(
            id: 'b',
            bank: 'Mercantil',
            type: 'ahorro',
            number: '2',
          ),
        );
        expect(store.defaultAccount?.id, 'a');
        store.setDefaultAccount('b');
        expect(store.defaultAccount?.id, 'b');
        expect(store.data.accounts.first.isDefault, isFalse);
      },
    );

    test('borrar la principal promueve a la primera que queda', () {
      final store = AppStore.withData(const AppData());
      store.addAccount(
        const PayAccount(
          id: 'a',
          bank: 'Banesco',
          type: 'corriente',
          number: '1',
        ),
      );
      store.addAccount(
        const PayAccount(
          id: 'b',
          bank: 'Mercantil',
          type: 'ahorro',
          number: '2',
        ),
      );
      store.removeAccount('a');
      expect(store.defaultAccount?.id, 'b');
      expect(store.defaultAccount?.isDefault, isTrue);
    });
  });

  group('Insignias de banco', () {
    test('27 bancos con asset original y claves exactas', () {
      expect(kVkBanks.length, 27);
      expect(kBankBadgeColors.length, 27);
      for (final b in kVkBanks) {
        expect(kBankBadgeColors[b], isNotNull, reason: b);
        expect(kBankBadgeColors[b], greaterThan(0xFF000000));
      }
    });

    test('iniciales de respaldo sin depender del PNG', () {
      expect(bankInitials('Banesco'), 'BAN');
      expect(bankInitials('Banco de Venezuela (BDV)'), 'BV');
      expect(bankInitials('BFC Banco Fondo Común'), 'BFC');
    });
  });
}
