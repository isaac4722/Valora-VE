/// Tests de Cuentas y Pago Móvil (v23 → v30): modelo PayAccount por TIPO
/// (round-trip + tolerante + migración de respaldos viejos), store
/// (alta/borrado/tope con validación por tipo), merge de respaldo por id,
/// formato del mensaje de cobro es-VE (líneas del tipo), avisos suaves por
/// tipo (`accountSoftWarnings`) y la puerta del Conversor (botón solo con
/// destino VES + hoja con datos).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FontLoader, ByteData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/data/backup.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/converter/converter_screen.dart';
import 'package:valorave/features/converter/pago_movil_sheet.dart'
    show pagoMovilMessage;
import 'package:valorave/widgets/ui.dart' show VeKeypad;
import 'package:valorave/features/settings/settings_screen.dart'
    show CuentasPagoMovil, accountSoftWarnings;
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/providers/providers.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Fuentes REALES (patrón de widgets_test/gui_correcta): el fallback de
  // test mide cada glifo al ancho del fontSize y fabrica overflows falsos
  // en los chips expandidos del conversor — con Inter las medidas son las
  // del teléfono.
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

  group('Modelo PayAccount (v30 · H-43: el tipo decide los datos)', () {
    test('round-trip toJson/tryParse completo (transferencia)', () {
      const a = PayAccount(
        id: 'a1',
        kind: PayAccountKind.transferencia,
        bank: 'Banesco',
        type: 'corriente',
        number: '01340000000000000000',
        docId: 'V12345678',
        phone: '04141234567',
      );
      final parsed = PayAccount.tryParse(
        Map<String, dynamic>.from(a.toJson()),
      );
      expect(parsed, isNotNull);
      expect(parsed!.kind, PayAccountKind.transferencia);
      expect(parsed.bank, 'Banesco');
      expect(parsed.type, 'corriente');
      expect(parsed.typeLabel, 'Corriente');
      expect(parsed.number, '01340000000000000000');
      // R-30b: el teléfono puede existir en el modelo, pero la
      // transferencia JAMÁS lo renderiza.
      expect(
        parsed.dataLines.map((e) => e.$1).contains('Teléfono'),
        isFalse,
      );
      expect(parsed.phone, '04141234567'); // sin pérdida de datos
    });

    test('tryParse tolerante: tipo raro cae a corriente; basura no entra', () {
      final parsed = PayAccount.tryParse(const {
        'id': 'x',
        'kind': 'transferencia',
        'bank': 'Mercantil',
        'type': 'otra cosa',
        'number': '0105...',
      });
      expect(parsed!.type, 'corriente');
      expect(
        PayAccount.tryParse({
          'id': '',
          'kind': 'zelle',
          'phone': 'a@b.com',
        }),
        isNull,
      );
    });

    test(
      'migración de respaldos VIEJOS sin kind: con número → transferencia; '
      'sin número y con teléfono → pago móvil (sin pérdida de datos)',
      () {
        // Vieja cuenta completa: banco + tipo + número + CI + teléfono.
        final vieja = PayAccount.tryParse(const {
          'id': 'old1',
          'bank': 'Banesco',
          'type': 'ahorro',
          'number': '01340000000000000000',
          'docId': 'V12345678',
          'phone': '04141234567',
        });
        expect(vieja!.kind, PayAccountKind.transferencia);
        expect(vieja.type, 'ahorro');
        expect(vieja.number, '01340000000000000000');
        expect(vieja.docId, 'V12345678');
        expect(vieja.phone, '04141234567'); // sin pérdida de datos
        // Vieja cuenta de puro pago móvil: banco + teléfono, sin número.
        final viejaPm = PayAccount.tryParse(const {
          'id': 'old2',
          'bank': 'Mercantil',
          'phone': '04141234567',
        });
        expect(viejaPm!.kind, PayAccountKind.pagoMovil);
        expect(viejaPm.bank, 'Mercantil');
        expect(viejaPm.number, '');
        expect(viejaPm.phone, '04141234567');
      },
    );

    test('AppData viejo sin accounts carga vacío + round-trip', () {
      final d = AppData.fromJson({'version': 1});
      expect(d.accounts, isEmpty);
      final d2 = AppData.fromJson(
        Map<String, dynamic>.from(
          AppData(
            accounts: const [
              PayAccount(
                id: 'z',
                kind: PayAccountKind.transferencia,
                bank: 'Banesco',
                type: 'ahorro',
                number: '123',
              ),
            ],
          ).toJson(),
        ),
      );
      expect(d2.accounts, hasLength(1));
      expect(d2.accounts.first.typeLabel, 'Ahorro');
    });

    test('accountsBiometric default OFF (opt-in)', () {
      expect(const Settings().accountsBiometric, isFalse);
      expect(Settings.fromJson({}).accountsBiometric, isFalse);
      expect(
        Settings.fromJson({'accountsBiometric': true}).accountsBiometric,
        isTrue,
      );
    });
  });

  group('Store: cuentas', () {
    late Directory tmp;
    late AppStore store;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      tmp = await Directory.systemTemp.createTemp('valorave_pm');
      store = AppStore();
      await store.hydrate(testDir: tmp.path);
    });

    tearDown(() async {
      await Hive.close();
      await tmp.delete(recursive: true);
    });

    test('addAccount acepta hasta 4 y removeAccount retira', () {
      for (var i = 0; i < 4; i++) {
        expect(
          store.addAccount(
            PayAccount(
              id: 'a$i',
              kind: PayAccountKind.pagoMovil,
              bank: 'Banco $i',
              docId: 'V12345678',
              phone: '0414123456$i',
            ),
          ),
          isTrue,
        );
      }
      expect(
        store.addAccount(
          PayAccount(
            id: 'a4',
            kind: PayAccountKind.pagoMovil,
            bank: 'Banco 4',
            docId: 'V12345678',
            phone: '04141234564',
          ),
        ),
        isFalse,
      );
      store.removeAccount('a2');
      expect(store.data.accounts, hasLength(3));
      expect(store.data.accounts.map((a) => a.id), isNot(contains('a2')));
    });

    test('setAccountsBiometric persiste el candado', () {
      store.setAccountsBiometric(true);
      expect(store.data.settings.accountsBiometric, isTrue);
      store.setAccountsBiometric(false);
      expect(store.data.settings.accountsBiometric, isFalse);
    });
  });

  group('Merge de respaldo', () {
    test('accounts: unión por id, la del respaldo sobrevive', () {
      final local = AppData(
        accounts: const [
          PayAccount(
            id: 'keep',
            kind: PayAccountKind.transferencia,
            bank: 'Banesco',
            type: 'corriente',
            number: '1',
          ),
        ],
      );
      final incoming = AppData(
        accounts: const [
          PayAccount(
            id: 'keep',
            kind: PayAccountKind.transferencia,
            bank: 'LOCAL',
            type: 'corriente',
            number: '9',
          ),
          PayAccount(
            id: 'nueva',
            kind: PayAccountKind.transferencia,
            bank: 'Mercantil',
            type: 'ahorro',
            number: '2',
          ),
        ],
      );
      final res = mergeBackupData(local, incoming);
      expect(res.data.accounts, hasLength(2));
      expect(
        res.data.accounts.firstWhere((a) => a.id == 'keep').bank,
        'Banesco',
      );
      expect(
        res.data.accounts.firstWhere((a) => a.id == 'nueva').bank,
        'Mercantil',
      );
    });
  });

  group('Mensaje de cobro (v30: las líneas del tipo)', () {
    test('transferencia completa: Banco · Cuenta · Cédula (SIN Teléfono)', () {
      const a = PayAccount(
        id: 'a',
        kind: PayAccountKind.transferencia,
        bank: 'Banco de Venezuela (BDV)',
        type: 'corriente',
        number: '01020000000000000000',
        docId: 'V12345678',
        phone: '04141234567',
      );
      final msg = pagoMovilMessage(1234.5, a);
      // v29 (V-4): el símbolo va SIEMPRE tras el número.
      expect(msg, startsWith('Pago Móvil · 1.234,50 Bs'));
      expect(msg, isNot(contains('Bs 1.234,50')));
      expect(msg, contains('Banco: Banco de Venezuela (BDV)'));
      expect(msg, contains('Cuenta corriente: 01020000000000000000'));
      expect(msg, contains('Cédula: V12345678'));
      // R-30b: el teléfono del pago móvil NO se filtra a transferencias —
      // la línea no existe ni con el campo poblado.
      expect(msg, isNot(contains('Teléfono:')));
      // Sin fecha planificada: ninguna línea «Fecha:».
      expect(msg, isNot(contains('Fecha:')));
    });

    test('pago móvil: Banco · Cédula · Teléfono (SIN cuenta)', () {
      const a = PayAccount(
        id: 'a',
        kind: PayAccountKind.pagoMovil,
        bank: 'Banesco',
        docId: 'V12345678',
        phone: '04141234567',
      );
      final msg = pagoMovilMessage(100, a);
      expect(msg, contains('Banco: Banesco'));
      expect(msg, contains('Cédula: V12345678'));
      expect(msg, contains('Teléfono: 04141234567'));
      expect(msg, isNot(contains('Cuenta')));
    });

    test('zelle: Titular · Zelle', () {
      const a = PayAccount(
        id: 'a',
        kind: PayAccountKind.zelle,
        holderName: 'María Pérez',
        phone: 'maria@correo.com',
      );
      final msg = pagoMovilMessage(9.99, a);
      expect(msg, contains('Titular: María Pérez'));
      expect(msg, contains('Zelle: maria@correo.com'));
      expect(msg, isNot(contains('Banco:')));
    });

    test('sin cédula (respaldo viejo): líneas ausentes, sin campos vacíos', () {
      const a = PayAccount(
        id: 'a',
        kind: PayAccountKind.transferencia,
        bank: 'Banesco',
        type: 'ahorro',
        number: '123',
      );
      final msg = pagoMovilMessage(100, a);
      expect(msg, contains('Cuenta ahorro: 123'));
      expect(msg, isNot(contains('Cédula:')));
      expect(msg, isNot(contains('Teléfono:')));
    });

    test('v29 · «Mañana»: el cobro viaja fechado (DD/MM y la palabra)', () {
      const a = PayAccount(
        id: 'a',
        kind: PayAccountKind.transferencia,
        bank: 'Banesco',
        type: 'corriente',
        number: '123',
      );
      final msg = pagoMovilMessage(
        40,
        a,
        para: DateTime(2026, 9, 18),
      );
      expect(msg, startsWith('Pago Móvil · 40,00 Bs'));
      expect(msg, contains('Fecha: 18/09 (mañana)'));
    });
  });

  group('Validación dura por tipo (v30 · R-30c/R-30d)', () {
    late AppStore store;

    setUp(() {
      SharedPreferences.setMockInitialValues({});
      store = AppStore.withData(const AppData());
    });

    test(
      'R-30d: pago móvil exige banco AND cédula AND teléfono (los tres)',
      () {
        // Solo banco + teléfono (la validación vieja era banco O...):
        expect(
          store.addAccount(
            const PayAccount(
              id: 'pm1',
              kind: PayAccountKind.pagoMovil,
              bank: 'Banesco',
              phone: '04141234567',
            ),
          ),
          isFalse,
          reason: 'falta la cédula',
        );
        // Banco + cédula, sin teléfono:
        expect(
          store.addAccount(
            const PayAccount(
              id: 'pm2',
              kind: PayAccountKind.pagoMovil,
              bank: 'Banesco',
              docId: 'V12345678',
            ),
          ),
          isFalse,
          reason: 'falta el teléfono',
        );
        // Los tres: entra.
        expect(
          store.addAccount(
            const PayAccount(
              id: 'pm3',
              kind: PayAccountKind.pagoMovil,
              bank: 'Banesco',
              docId: 'V12345678',
              phone: '04141234567',
            ),
          ),
          isTrue,
        );
        expect(store.data.accounts, hasLength(1));
      },
    );

    test('mensajes por tipo: qué falta, campo por campo', () {
      const pm = PayAccount(
        id: 'x',
        kind: PayAccountKind.pagoMovil,
        bank: 'Banesco',
        phone: '0414',
      );
      expect(pm.missingFields, ['la cédula']);
      const tr = PayAccount(
        id: 'x',
        kind: PayAccountKind.transferencia,
        bank: 'Banesco',
        type: 'corriente',
      );
      expect(tr.missingFields, ['el número de cuenta', 'la cédula']);
      const ze = PayAccount(id: 'x', kind: PayAccountKind.zelle);
      expect(ze.missingFields, ['el titular', 'el correo o teléfono de EE. UU.']);
    });
  });

  group('Avisos suaves por tipo (accountSoftWarnings, v30)', () {
    PayAccount pm({
      String docId = 'V12345678',
      String phone = '04141234567',
    }) => PayAccount(
      id: 'a',
      kind: PayAccountKind.pagoMovil,
      bank: 'Banesco',
      docId: docId,
      phone: phone,
    );

    PayAccount tr({
      String number = '00000000000000000000',
      String docId = 'V12345678',
    }) => PayAccount(
      id: 'a',
      kind: PayAccountKind.transferencia,
      bank: 'Banesco',
      type: 'corriente',
      number: number,
      docId: docId,
    );

    PayAccount zelle(String contact) => PayAccount(
      id: 'a',
      kind: PayAccountKind.zelle,
      holderName: 'María Pérez',
      phone: contact,
    );

    test('todo bien → sin avisos (cada tipo con sus campos sanos)', () {
      expect(accountSoftWarnings(pm()), isEmpty);
      expect(accountSoftWarnings(tr()), isEmpty);
      expect(accountSoftWarnings(zelle('maria@correo.com')), isEmpty);
      expect(accountSoftWarnings(zelle('+1 555 123 4567')), isEmpty);
    });

    test('cuenta corta · CI corto · teléfono corto → un aviso por campo', () {
      final avisosPm = accountSoftWarnings(
        pm(docId: 'V123', phone: '0414'),
      );
      expect(avisosPm, hasLength(2));
      expect(avisosPm[0], contains('no entre 5 y 9'));
      expect(avisosPm[1], contains('no 11'));
      final avisosTr = accountSoftWarnings(tr(number: '123'));
      expect(avisosTr, hasLength(1));
      expect(avisosTr.single, contains('no 20'));
    });

    test('Zelle: correo sin dominio o teléfono raro avisa (suave)', () {
      expect(
        accountSoftWarnings(zelle('maria@correo')),
        everyElement(contains('correo')),
      );
      // 12 dígitos no es un teléfono US (10 local · 11 con el +1).
      final avisos = accountSoftWarnings(zelle('041412345678'));
      expect(avisos, hasLength(1));
      expect(avisos.single, contains('no 10'));
    });

    test(
      'CI: la letra no cuenta; 5 y 9 dígitos son válidos; vacío no avisa',
      () {
        expect(accountSoftWarnings(pm(docId: 'V12345')), isEmpty);
        expect(accountSoftWarnings(pm(docId: 'E123456789')), isEmpty);
        expect(
          accountSoftWarnings(pm(docId: '', phone: '')),
          isEmpty,
        );
      },
    );

    test('espacios y guiones no cuentan como dígitos (teléfono 10 avisa)', () {
      final avisos = accountSoftWarnings(pm(phone: '0414 123 45'));
      expect(avisos, hasLength(1));
      expect(avisos.single, contains('no 11'));
    });
  });

  group('Alta de cuenta (v30 · H-43: el tipo decide los campos)', () {
    late AppStore store;

    // Como pumpConverter: la sección usa componentes Ve que leen el tema
    // shadcn — el harness replica el ShadApp.custom de la app. Superficie
    // de teléfono real (390×844) como la puerta del Conversor.
    Future<void> pumpCuentas(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
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
          ],
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(
              body: SingleChildScrollView(child: CuentasPagoMovil()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets(
      'R-30c: pago móvil sin cédula ni teléfono → snackbar dice QUÉ falta '
      'y la cuenta NO se guarda',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        store = AppStore.withData(
          AppData(settings: const Settings(onboarded: true)),
        );
        await pumpCuentas(tester);

        await tester.tap(find.text('Agregar cuenta'));
        await tester.pumpAndSettle();
        // El alta nace en Pago móvil (el picker de 44 px manda primero).
        expect(find.text('Pago móvil'), findsOneWidget);
        expect(find.text('Transferencia'), findsOneWidget);
        expect(find.text('Zelle'), findsOneWidget);
        await tester.tap(find.text('Guardar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // El snackbar dice qué falta por tipo (banco viene por defecto)...
        expect(find.textContaining('Falta la cédula'), findsOneWidget);
        expect(find.textContaining('falta el teléfono'), findsOneWidget);
        // ...y nada se guardó (el AND de R-30d manda).
        expect(store.data.accounts, isEmpty);
      },
    );

    testWidgets(
      'R-30b: la transferencia no pide (ni guarda) teléfono',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        store = AppStore.withData(
          AppData(settings: const Settings(onboarded: true)),
        );
        await pumpCuentas(tester);

        await tester.tap(find.text('Agregar cuenta'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Transferencia'));
        await tester.pumpAndSettle();
        // La hoja muestra SOLO los campos del tipo: sin «TELÉFONO» (R-30b).
        expect(find.text('TELÉFONO'), findsNothing);
        expect(find.text('NÚMERO DE CUENTA'), findsOneWidget);
        expect(find.text('CÉDULA'), findsOneWidget);
        // Rellena banco (por defecto) + número + cédula y guarda.
        await tester.enterText(find.byType(EditableText).at(1), '01341234567890123456');
        await tester.enterText(find.byType(EditableText).at(2), 'V12345678');
        await tester.tap(find.text('Guardar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));
        expect(store.data.accounts, hasLength(1));
        expect(store.data.accounts.single.kind, PayAccountKind.transferencia);
        // El campo cruzado (teléfono) jamás se filtra al guardar.
        expect(store.data.accounts.single.phone, isEmpty);
      },
    );

    testWidgets(
      'CI corto: aviso suave en el snackbar y la cuenta se guarda igual',
      (tester) async {
        SharedPreferences.setMockInitialValues({});
        store = AppStore.withData(
          AppData(settings: const Settings(onboarded: true)),
        );
        await pumpCuentas(tester);

        await tester.tap(find.text('Agregar cuenta'));
        await tester.pumpAndSettle();
        // Pago móvil: nombre(0) · cédula(1) · teléfono(2) — el banco vive
        // en VeSelect (sin EditableText).
        await tester.enterText(find.byType(EditableText).at(1), 'V123');
        await tester.enterText(find.byType(EditableText).at(2), '0414');
        await tester.tap(find.text('Guardar'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // Avisos suaves en el snackbar (uno por campo raro)...
        expect(find.textContaining('no entre 5 y 9'), findsOneWidget);
        expect(find.textContaining('no 11'), findsOneWidget);
        // ...y la cuenta quedó guardada igual (jamás bloqueo).
        expect(store.data.accounts, hasLength(1));
        expect(store.data.accounts.single.docId, 'V123');
      },
    );

    testWidgets('datos completos: sin snackbar, guarda silencioso', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      store = AppStore.withData(
        AppData(settings: const Settings(onboarded: true)),
      );
      await pumpCuentas(tester);

      await tester.tap(find.text('Agregar cuenta'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(EditableText).at(1), 'V12345678');
      await tester.enterText(find.byType(EditableText).at(2), '04141234567');
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Ojo:'), findsNothing);
      expect(store.data.accounts, hasLength(1));
      // La fila renderiza las líneas del tipo (banco · cédula · teléfono).
      expect(find.textContaining('Cédula: V12345678'), findsOneWidget);
      expect(find.textContaining('Teléfono: 04141234567'), findsOneWidget);
    });
  });

  group('Conversor: puerta de Pago Móvil', () {
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

    Future<void> pumpConverter(WidgetTester tester) async {
      // v23.2: superficie de teléfono real (390×844) — el botón y el piso
      // de teclado conviven sin pantallas gigantes.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
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
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: ConverterScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('con destino VES: botón visible, hoja arma el cobro', (
      tester,
    ) async {
      store.setRateBoard(
        RateBoard(
          sources: {
            'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026, 9, 17)),
          },
        ),
      );
      store.setConverterPair('usd', 'ves');
      store.addAccount(
        const PayAccount(
          id: 'a1',
          kind: PayAccountKind.transferencia,
          bank: 'Banesco',
          type: 'corriente',
          number: '01341234567890123456',
          docId: 'V12345678',
        ),
      );
      await pumpConverter(tester);
      expect(find.text('Pago Móvil'), findsOneWidget);
      await tester.tap(find.text('Pago Móvil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // v29 (H-29): título «Pago Móvil», cifra con símbolo al FINAL y las
      // DOS acciones de la regla global (Compartir imagen · Copiar texto).
      expect(find.text('Pago Móvil'), findsWidgets);
      expect(find.text('40,00 Bs'), findsOneWidget);
      expect(find.text('Compartir'), findsOneWidget);
      expect(find.text('Copiar'), findsOneWidget);
      expect(
        find.textContaining('Cuenta corriente: 01341234567890123456'),
        findsOneWidget,
      );
      // R-30b: la transferencia no renderiza «Teléfono» en el cobro.
      expect(find.textContaining('Teléfono:'), findsNothing);
      expect(find.textContaining('quien reciba el mensaje'), findsOneWidget);
    });

    testWidgets('v29 · con ORIGEN VES: la puerta cobra el MONTO ESCRITO', (
      tester,
    ) async {
      store.setRateBoard(
        RateBoard(
          sources: {
            'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026, 9, 17)),
          },
        ),
      );
      // Par VES → USD: el bolívar entra por el ORIGEN — el cobro toma el
      // monto escrito en Bs (no el resultado en USD).
      store.setConverterPair('ves', 'usd');
      store.addAccount(
        const PayAccount(
          id: 'a1',
          kind: PayAccountKind.pagoMovil,
          bank: 'Banesco',
          docId: 'V12345678',
          phone: '04141234567',
        ),
      );
      await pumpConverter(tester);
      // Escribir 40 Bs arriba (teclado único: ⌫ largo limpia la cortesía
      // «1» y se teclea el monto).
      Finder tecla(String k) =>
          find.descendant(of: find.byType(VeKeypad), matching: find.text(k));
      await tester.longPress(tecla('⌫'));
      await tester.pump();
      for (final k in ['4', '0']) {
        await tester.tap(tecla(k));
        await tester.pump();
      }
      expect(find.text('Pago Móvil'), findsOneWidget);
      await tester.tap(find.text('Pago Móvil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.text('40,00 Bs'), findsOneWidget);
      expect(find.text('Compartir'), findsOneWidget);
      expect(find.text('Copiar'), findsOneWidget);
    });

    testWidgets('v29 · «Mañana»: el cobro viaja fechado', (tester) async {
      store.setRateBoard(
        RateBoard(
          sources: {
            'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026, 9, 17)),
          },
        ),
      );
      store.setConverterPair('usd', 'ves');
      store.addAccount(
        const PayAccount(
          id: 'a1',
          kind: PayAccountKind.transferencia,
          bank: 'Banesco',
          type: 'corriente',
          number: '01341234567890123456',
          docId: 'V12345678',
        ),
      );
      await pumpConverter(tester);
      // Segmento «Mañana»: planifica el cobro con la tasa viva de hoy.
      await tester.tap(find.text('Mañana'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(
        find.text('Para mañana · cobro planificado con la tasa de hoy'),
        findsOneWidget,
      );
      await tester.tap(find.text('Pago Móvil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // La tasa viva de hoy viaja intacta (40,00 Bs) y la línea de fecha
      // del día siguiente aparece en el mensaje.
      expect(find.text('40,00 Bs'), findsOneWidget);
      final manana = DateTime.now().add(const Duration(days: 1));
      final dia =
          '${manana.day.toString().padLeft(2, '0')}/'
          '${manana.month.toString().padLeft(2, '0')}';
      expect(find.textContaining('Fecha: $dia (mañana)'), findsOneWidget);
    });

    testWidgets('sin VES en el par: el botón no existe (USD→COP)', (
      tester,
    ) async {
      store.setRateBoard(
        RateBoard(
          sources: {
            'cop-trm': RateEntry(rate: 4000, updatedAt: DateTime(2026, 9, 17)),
            'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026, 9, 17)),
          },
        ),
      );
      store.setConverterPair('usd', 'cop');
      await pumpConverter(tester);
      expect(find.text('Pago Móvil'), findsNothing);
    });

    testWidgets('sin cuentas: la hoja invita a Ajustes', (tester) async {
      store.setRateBoard(
        RateBoard(
          sources: {
            'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026, 9, 17)),
          },
        ),
      );
      store.setConverterPair('usd', 'ves');
      await pumpConverter(tester);
      await tester.tap(find.text('Pago Móvil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      expect(find.textContaining('Agrega tu cuenta'), findsOneWidget);
      expect(find.text('Ir a Ajustes'), findsOneWidget);
    });
  });
}
