/// Tests de Cuentas y Pago Móvil (v23 · comparativa CalculaYa): modelo
/// PayAccount (round-trip + tolerante), store (alta/borrado/tope),
/// merge de respaldo por id, formato del mensaje de cobro es-VE y la
/// puerta del Conversor (botón solo con destino VES + hoja con datos).
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart'
    show rootBundle, FontLoader, ByteData;
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/data/backup.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/converter/converter_screen.dart';
import 'package:valorave/features/converter/pago_movil_sheet.dart'
    show pagoMovilMessage;
import 'package:valorave/features/settings/settings_screen.dart'
    show CuentasPagoMovil, pagoMovilSoftWarnings;
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:shadcn_ui/shadcn_ui.dart' show ShadApp;
import 'package:valorave/core/shad_theme.dart';
import 'package:valorave/core/theme.dart';

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

  group('Modelo PayAccount', () {
    test('round-trip toJson/tryParse completo', () {
      const a = PayAccount(
        id: 'a1',
        bank: 'Banesco',
        type: 'corriente',
        number: '01340000000000000000',
        docId: 'V12345678',
        phone: '04141234567',
      );
      final parsed = PayAccount.tryParse(Map<String, dynamic>.from(a.toJson()));
      expect(parsed, isNotNull);
      expect(parsed!.bank, 'Banesco');
      expect(parsed.type, 'corriente');
      expect(parsed.typeLabel, 'Corriente');
      expect(parsed.number, '01340000000000000000');
    });

    test('tryParse tolerante: tipo raro cae a corriente; basura no entra', () {
      final parsed = PayAccount.tryParse(const {
        'id': 'x',
        'bank': 'Mercantil',
        'type': 'otra cosa',
        'number': '0105...',
      });
      expect(parsed!.type, 'corriente');
      expect(PayAccount.tryParse({'id': '', 'bank': 'B', 'number': '1'}), isNull);
    });

    test('AppData viejo sin accounts carga vacío + round-trip', () {
      final d = AppData.fromJson({'version': 1});
      expect(d.accounts, isEmpty);
      final d2 = AppData.fromJson(Map<String, dynamic>.from(
        AppData(accounts: const [
          PayAccount(id: 'z', bank: 'Banesco', type: 'ahorro', number: '123'),
        ]).toJson(),
      ));
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
          store.addAccount(PayAccount(
            id: 'a$i',
            bank: 'Banco $i',
            type: 'corriente',
            number: '0$i',
          )),
          isTrue,
        );
      }
      expect(store.addAccount(PayAccount(
        id: 'a4', bank: 'Banco 4', type: 'corriente', number: '04',
      )), isFalse);
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
      final local = AppData(accounts: const [
        PayAccount(id: 'keep', bank: 'Banesco', type: 'corriente', number: '1'),
      ]);
      final incoming = AppData(accounts: const [
        PayAccount(id: 'keep', bank: 'LOCAL', type: 'corriente', number: '9'),
        PayAccount(id: 'nueva', bank: 'Mercantil', type: 'ahorro', number: '2'),
      ]);
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

  group('Mensaje de cobro', () {
    test('formato es-VE con todos los datos', () {
      const a = PayAccount(
        id: 'a',
        bank: 'Banco de Venezuela (BDV)',
        type: 'corriente',
        number: '01020000000000000000',
        docId: 'V12345678',
        phone: '04141234567',
      );
      final msg = pagoMovilMessage(1234.5, a);
      expect(msg, contains('Bs 1.234,50'));
      expect(msg, contains('Banco: Banco de Venezuela (BDV)'));
      expect(msg, contains('Cuenta corriente: 01020000000000000000'));
      expect(msg, contains('CI: V12345678'));
      expect(msg, contains('Teléfono: 04141234567'));
    });

    test('sin CI ni teléfono: líneas ausentes, sin campos vacíos', () {
      const a = PayAccount(
        id: 'a',
        bank: 'Banesco',
        type: 'ahorro',
        number: '123',
      );
      final msg = pagoMovilMessage(100, a);
      expect(msg, contains('Cuenta ahorro: 123'));
      expect(msg, isNot(contains('CI:')));
      expect(msg, isNot(contains('Teléfono:')));
    });
  });

  group('Validación suave (diseño P4: cuenta 20 · CI 5-9 · teléfono 11)', () {
    test('todo bien → sin avisos', () {
      expect(
        pagoMovilSoftWarnings(
          number: '01341234567890123456',
          docId: 'V12345678',
          phone: '04141234567',
        ),
        isEmpty,
      );
    });

    test('cuenta corta, CI corto y teléfono corto → un aviso por campo', () {
      final avisos = pagoMovilSoftWarnings(
        number: '123',
        docId: 'V123',
        phone: '0414',
      );
      expect(avisos, hasLength(3));
      expect(avisos[0], contains('no 20'));
      expect(avisos[1], contains('no entre 5 y 9'));
      expect(avisos[2], contains('no 11'));
    });

    test('CI: la letra no cuenta; 5 y 9 dígitos son válidos; vacío no avisa',
        () {
      expect(
        pagoMovilSoftWarnings(
          number: '0' * 20,
          docId: 'V12345',
          phone: '04141234567',
        ),
        isEmpty,
      );
      expect(
        pagoMovilSoftWarnings(
          number: '0' * 20,
          docId: 'E123456789',
          phone: '04141234567',
        ),
        isEmpty,
      );
      expect(
        pagoMovilSoftWarnings(number: '0' * 20, docId: '', phone: ''),
        isEmpty,
      );
    });

    test('espacios y guiones no cuentan como dígitos (teléfono 10 avisa)', () {
      final avisos = pagoMovilSoftWarnings(
        number: '0' * 20,
        docId: 'V12345678',
        phone: '0414 123 45',
      );
      expect(avisos, hasLength(1));
      expect(avisos.single, contains('no 11'));
    });
  });

  group('Alta de cuenta: aviso suave, jamás bloqueo (H2)', () {
    late AppStore store;

    // Como pumpConverter: la sección usa componentes Ve que leen el tema
    // shadcn — el harness replica el ShadApp.custom de la app. Superficie
    // de teléfono real (390×844) como la puerta del Conversor.
    Future<void> pumpCuentas(WidgetTester tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider(create: (_) => ThemeController()),
          ],
          child: ShadApp.custom(
            theme: ShadThemeVe.light(),
            darkTheme: ShadThemeVe.dark(),
            appBuilder: (context) => MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(
                body: SingleChildScrollView(child: CuentasPagoMovil()),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('CI corto: snackbar avisa y la cuenta se guarda igual', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      store = AppStore.withData(
        AppData(settings: const Settings(onboarded: true)),
      );
      await pumpCuentas(tester);

      await tester.tap(find.text('Agregar cuenta'));
      await tester.pumpAndSettle();
      // v23.3: el alta es VeField/VeInput (rótulo fuera del campo) — los
      // tres EditableText de la hoja en orden: número · cédula · teléfono.
      await tester.enterText(find.byType(EditableText).at(0), '123');
      await tester.enterText(find.byType(EditableText).at(1), 'V123');
      await tester.enterText(find.byType(EditableText).at(2), '0414');
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      // Avisos suaves en el snackbar (uno por campo raro)...
      expect(find.textContaining('no 20'), findsOneWidget);
      expect(find.textContaining('no entre 5 y 9'), findsOneWidget);
      expect(find.textContaining('no 11'), findsOneWidget);
      // ...y la cuenta quedó guardada igual (jamás bloqueo).
      expect(store.data.accounts, hasLength(1));
      expect(store.data.accounts.single.docId, 'V123');
    });

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
      await tester.enterText(find.byType(EditableText).at(0), '01341234567890123456');
      await tester.enterText(find.byType(EditableText).at(1), 'V12345678');
      await tester.enterText(find.byType(EditableText).at(2), '04141234567');
      await tester.tap(find.text('Guardar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));

      expect(find.textContaining('Ojo:'), findsNothing);
      expect(store.data.accounts, hasLength(1));
      // La fila de la cuenta ya vive en Ajustes (banco · tipo + CI).
      expect(find.textContaining('CI V12345678'), findsOneWidget);
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
      poller = RatesPoller(
        store,
        NotificationsService(),
        AlertEngine(prefs),
      );
    });

    Future<void> pumpConverter(WidgetTester tester) async {
      // v23.2: superficie de teléfono real (390×844) — el botón y el piso
      // de teclado conviven sin pantallas gigantes.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider(create: (_) => ThemeController()),
            ChangeNotifierProvider.value(value: poller),
          ],
          child: ShadApp.custom(
            theme: ShadThemeVe.light(),
            darkTheme: ShadThemeVe.dark(),
            appBuilder: (context) => MaterialApp(
              theme: AppTheme.light(),
              home: const Scaffold(body: ConverterScreen()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('con destino VES: botón visible, hoja arma el cobro', (
      tester,
    ) async {
      store.setRateBoard(RateBoard(sources: {
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026, 9, 17)),
      }));
      store.setConverterPair('usd', 'ves');
      store.addAccount(const PayAccount(
        id: 'a1',
        bank: 'Banesco',
        type: 'corriente',
        number: '01341234567890123456',
        docId: 'V12345678',
      ));
      await pumpConverter(tester);
      expect(find.text('Pago Móvil'), findsOneWidget);
      await tester.tap(find.text('Pago Móvil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // El monto (1 USD × 40) y los datos de la cuenta en la hoja.
      expect(find.text('Compartir Pago Móvil'), findsOneWidget);
      expect(find.text('Bs 40,00'), findsOneWidget);
      expect(find.textContaining('Cuenta corriente: 01341234567890123456'), findsOneWidget);
      expect(find.textContaining('quien reciba el mensaje'), findsOneWidget);
    });

    testWidgets('sin destino VES: el botón no existe (par USD→COP)', (
      tester,
    ) async {
      store.setRateBoard(RateBoard(sources: {
        'cop-trm': RateEntry(rate: 4000, updatedAt: DateTime(2026, 9, 17)),
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026, 9, 17)),
      }));
      store.setConverterPair('usd', 'cop');
      await pumpConverter(tester);
      expect(find.text('Pago Móvil'), findsNothing);
    });

    testWidgets('sin cuentas: la hoja invita a Ajustes', (tester) async {
      store.setRateBoard(RateBoard(sources: {
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026, 9, 17)),
      }));
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
