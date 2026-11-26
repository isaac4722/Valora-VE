/// Tests v30 · Parte 5 — Análisis · Más · Ajustes (HALLAZGOS_v30):
/// cuentas por TIPO (H-43: modelo · migración · AND · mensajes · hoja sin
/// Zelle · alta que reordena campos), Ajustes en UNA pantalla con los
/// redirects del router (H-42 · R-30a) y el tour al día (R-30h). La
/// geometría de la píldora (H-44) ya vive en v29_test — no se duplica.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FontLoader, ByteData;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/converter/converter_screen.dart';
import 'package:valorave/features/settings/settings_screen.dart'
    show CuentasPagoMovil, SettingsScreen;
import 'package:valorave/features/converter/pago_movil_sheet.dart'
    show pagoMovilMessage;
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:valorave/providers/providers.dart';
import 'package:valorave/widgets/app_router.dart';
import 'package:valorave/widgets/app_tour.dart';
import 'package:valorave/widgets/ui.dart' show VeSegmented;

/// Store ligero para widget tests (sin Hive: FakeAsync no hace file IO).
AppStore _pumpedStore() {
  SharedPreferences.setMockInitialValues({});
  return AppStore.withData(const AppData());
}

final NotificationsService _notifs = NotificationsService();
late RatesPoller _poller;
late SharedPreferences _prefs;

Future<void> _initServices(AppStore store) async {
  SharedPreferences.setMockInitialValues({});
  _prefs = await SharedPreferences.getInstance();
  _poller = RatesPoller(store, _notifs, AlertEngine(_prefs));
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

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Fuentes REALES (patrón v29): el fallback mide glifos al ancho del
  // fontSize y fabrica overflows falsos.
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

  group('H-43 · modelo por tipo: dataLines es la única fuente', () {
    test('Pago Móvil: Banco · Cédula · Teléfono (sin tipo ni número)', () {
      const a = PayAccount(
        id: 'pm',
        kind: PayAccountKind.pagoMovil,
        bank: 'Banesco',
        docId: 'V12345678',
        phone: '04141234567',
      );
      expect(
        a.dataLines,
        [('Banco', 'Banesco'), ('Cédula', 'V12345678'), ('Teléfono', '04141234567')],
      );
      expect(a.cobraEnBs, isTrue);
      expect(a.displayLabel, 'Banesco · Pago Móvil');
      expect(a.missingFields, isEmpty);
    });

    test('Transferencia: Banco · Cuenta · Cédula (R-30b: sin Teléfono)', () {
      const a = PayAccount(
        id: 'tr',
        kind: PayAccountKind.transferencia,
        bank: 'Mercantil',
        type: 'ahorro',
        number: '01050000000000000000',
        docId: 'E12345678',
        phone: '04141234567', // exista o no: jamás se renderiza
      );
      expect(
        a.dataLines,
        [
          ('Banco', 'Mercantil'),
          ('Cuenta ahorro', '01050000000000000000'),
          ('Cédula', 'E12345678'),
        ],
      );
      expect(a.cobraEnBs, isTrue);
      expect(a.displayLabel, 'Mercantil · Ahorro');
    });

    test('Zelle: Titular · Zelle (en dólares — no cobra en Bs)', () {
      const a = PayAccount(
        id: 'ze',
        kind: PayAccountKind.zelle,
        holderName: 'María Pérez',
        phone: 'maria@correo.com',
      );
      expect(a.dataLines, [('Titular', 'María Pérez'), ('Zelle', 'maria@correo.com')]);
      expect(a.cobraEnBs, isFalse);
      expect(a.displayLabel, 'Zelle · María Pérez');
    });
  });

  group('H-43 · migración de respaldos viejos (única vía: Hive y respaldo)', () {
    test('sin kind: con número → transferencia; con teléfono → pago móvil', () {
      // JSON crudo del respaldo viejo (v23-v29): sin «kind».
      final viejaConNumero = PayAccount.tryParse(const {
        'id': 'old1',
        'bank': 'Banesco',
        'type': 'corriente',
        'number': '01340000000000000000',
        'docId': 'V12345678',
        'phone': '04141234567',
        'holderName': 'María Pérez',
        'label': 'Principal',
        'isDefault': true,
      });
      expect(viejaConNumero!.kind, PayAccountKind.transferencia);
      // Sin pérdida de datos: TODO el JSON viejo sobrevive.
      expect(viejaConNumero.label, 'Principal');
      expect(viejaConNumero.holderName, 'María Pérez');
      expect(viejaConNumero.docId, 'V12345678');
      expect(viejaConNumero.phone, '04141234567');
      expect(viejaConNumero.isDefault, isTrue);

      final viejaSinNumero = PayAccount.tryParse(const {
        'id': 'old2',
        'bank': 'Mercantil',
        'phone': '04141234567',
      });
      expect(viejaSinNumero!.kind, PayAccountKind.pagoMovil);
      expect(viejaSinNumero.number, '');

      // Round-trip: el JSON migrado lleva kind (estable en adelante).
      final again = PayAccount.tryParse(
        Map<String, dynamic>.from(viejaSinNumero.toJson()),
      );
      expect(again!.kind, PayAccountKind.pagoMovil);
    });
  });

  group('H-43 · R-30d: pago móvil valida banco AND cédula AND teléfono', () {
    test('addAccount rechaza cualquier combinación incompleta del tipo', () {
      final store = AppStore.withData(const AppData());
      // Banco + teléfono (la validación vieja era «banco O teléfono»):
      expect(
        store.addAccount(
          const PayAccount(
            id: '1',
            kind: PayAccountKind.pagoMovil,
            bank: 'Banesco',
            phone: '04141234567',
          ),
        ),
        isFalse,
      );
      // Banco + cédula, sin teléfono:
      expect(
        store.addAccount(
          const PayAccount(
            id: '2',
            kind: PayAccountKind.pagoMovil,
            bank: 'Banesco',
            docId: 'V12345678',
          ),
        ),
        isFalse,
      );
      // Cédula + teléfono, sin banco:
      expect(
        store.addAccount(
          const PayAccount(
            id: '3',
            kind: PayAccountKind.pagoMovil,
            docId: 'V12345678',
            phone: '04141234567',
          ),
        ),
        isFalse,
      );
      // Los TRES: entra.
      expect(
        store.addAccount(
          const PayAccount(
            id: '4',
            kind: PayAccountKind.pagoMovil,
            bank: 'Banesco',
            docId: 'V12345678',
            phone: '04141234567',
          ),
        ),
        isTrue,
      );
      expect(store.data.accounts, hasLength(1));
    });
  });

  group('H-43 · mensajes por tipo (dataLines en el cobro)', () {
    test('pago móvil y zelle: el mensaje lleva SOLO las líneas del tipo', () {
      const pm = PayAccount(
        id: 'pm',
        kind: PayAccountKind.pagoMovil,
        bank: 'BDV',
        docId: 'V12345678',
        phone: '04141234567',
      );
      final msgPm = pagoMovilMessage(915.38, pm);
      expect(msgPm, startsWith('Pago Móvil · 915,38 Bs'));
      expect(msgPm, contains('Banco: BDV'));
      expect(msgPm, contains('Cédula: V12345678'));
      expect(msgPm, contains('Teléfono: 04141234567'));
      expect(msgPm, isNot(contains('Cuenta')));

      const ze = PayAccount(
        id: 'ze',
        kind: PayAccountKind.zelle,
        holderName: 'María Pérez',
        phone: 'maria@correo.com',
      );
      final msgZe = pagoMovilMessage(9.99, ze);
      expect(msgZe, contains('Titular: María Pérez'));
      expect(msgZe, contains('Zelle: maria@correo.com'));
      expect(msgZe, isNot(contains('Banco:')));
    });
  });

  group('H-43 · la hoja del Conversor cobra solo en Bs (cobraEnBs)', () {
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

    testWidgets('solo Zelle: la hoja invita a configurar (sin datos Zelle)', (
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
          id: 'z1',
          kind: PayAccountKind.zelle,
          holderName: 'María Pérez',
          phone: 'maria@correo.com',
        ),
      );
      await pumpConverter(tester);
      await tester.tap(find.text('Pago Móvil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // La hoja NO arma un cobro con el Zelle (USD): invita a Ajustes.
      expect(find.textContaining('Agrega tu cuenta'), findsOneWidget);
      expect(find.textContaining('Zelle: maria'), findsNothing);
      expect(find.text('Ir a Ajustes'), findsOneWidget);
    });

    testWidgets('mixtas: solo las cuentas en Bs entran a la hoja', (
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
          id: 'z1',
          kind: PayAccountKind.zelle,
          holderName: 'María Pérez',
          phone: 'maria@correo.com',
          isDefault: true,
        ),
      );
      store.addAccount(
        const PayAccount(
          id: 'pm1',
          kind: PayAccountKind.pagoMovil,
          bank: 'Banesco',
          docId: 'V12345678',
          phone: '04141234567',
        ),
      );
      await pumpConverter(tester);
      await tester.tap(find.text('Pago Móvil'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // El Zelle (aunque sea la principal) no aparece ni como chip ni en
      // el mensaje: la hoja arma el cobro con el pago móvil en Bs.
      expect(find.textContaining('Zelle'), findsNothing);
      expect(find.textContaining('Teléfono: 04141234567'), findsOneWidget);
      expect(find.text('40,00 Bs'), findsOneWidget);
    });
  });

  group('H-43 · el alta elige el tipo PRIMERO y reordena sus campos', () {
    late AppStore store;

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

    testWidgets('picker de 44 px primero; cada tipo muestra SOLO su forma', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      store = AppStore.withData(
        AppData(settings: const Settings(onboarded: true)),
      );
      await pumpCuentas(tester);

      await tester.tap(find.text('Agregar cuenta'));
      await tester.pumpAndSettle();
      // El picker del tipo es PRIMERO y es de 44 px (H-43).
      expect(
        find.byWidgetPredicate((w) => w is VeSegmented && w.height == 44),
        findsOneWidget,
      );
      // Pago móvil (default): banco + cédula + teléfono — sin número.
      expect(find.text('CÉDULA'), findsOneWidget);
      expect(find.text('TELÉFONO'), findsOneWidget);
      expect(find.text('NÚMERO DE CUENTA'), findsNothing);
      expect(find.text('TITULAR (NOMBRE COMPLETO)'), findsNothing);

      // Zelle: titular + contacto — sin banco ni cédula.
      await tester.tap(find.text('Zelle'));
      await tester.pumpAndSettle();
      expect(find.text('TITULAR (NOMBRE COMPLETO)'), findsOneWidget);
      expect(find.text('CORREO O TELÉFONO DE EE. UU.'), findsOneWidget);
      expect(find.text('CÉDULA'), findsNothing);
      expect(find.text('BANCO'), findsNothing);

      // Transferencia: banco + tipo + número + cédula — sin teléfono.
      await tester.tap(find.text('Transferencia'));
      await tester.pumpAndSettle();
      expect(find.text('BANCO'), findsOneWidget);
      expect(find.text('NÚMERO DE CUENTA'), findsOneWidget);
      expect(find.text('CÉDULA'), findsOneWidget);
      expect(find.text('TELÉFONO'), findsNothing);
    });
  });

  group('H-42 · Ajustes en una pantalla: el router obedece', () {
    testWidgets('Cuentas y cobro PRIMERO en la hoja única', (tester) async {
      final store = _pumpedStore();
      await _initServices(store);
      await tester.pumpWidget(_wrap(const SettingsScreen(), store: store));
      await tester.pumpAndSettle();
      expect(find.byType(SettingsScreen), findsOneWidget);
      // La sección 1 vive ARRIBA de la 2 — el deep link del Conversor
      // (→ /ajustes/cuentas) aterriza sin scrollear.
      final cuentas = tester.getTopLeft(find.text('CUENTAS Y COBRO'));
      final tasas = tester.getTopLeft(find.text('TASAS Y FUENTES'));
      expect(cuentas.dy, lessThan(tasas.dy));
    });

    testWidgets(
      'las subpantallas redirigen a /ajustes y /ajustes/cuentas sobrevive; '
      '/escanear salió del router',
      (tester) async {
        final store = AppStore.withData(
          const AppData(settings: Settings(onboarded: true)),
        );
        await _initServices(store);
        final router = buildRouter(store: store);
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
                (ref) => _poller,
                disposeNotifier: false,
              ),
              sharedPreferencesProvider.overrideWithValue(_prefs),
            ],
            child: MaterialApp.router(
              theme: AppTheme.light(),
              routerConfig: router,
            ),
          ),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 400));

        // La ruta huérfana del escáner NO existe (H-41).
        final paths = {
          for (final r in router.configuration.routes)
            if (r is GoRoute) r.path,
        };
        expect(paths, isNot(contains('/escanear')));
        expect(paths, contains('/ajustes/cuentas'));

        // Las subpantallas viejas REDIRIGEN a la pantalla única.
        for (final vieja in [
          '/ajustes/general',
          '/ajustes/tasas',
          '/ajustes/apariencia',
          '/ajustes/datos',
        ]) {
          router.go(vieja);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 300));
          expect(
            router.routerDelegate.currentConfiguration.uri.toString(),
            '/ajustes',
            reason: vieja,
          );
          // La pantalla única: cinco secciones en la MISMA hoja.
          expect(find.byType(SettingsScreen), findsOneWidget);
        }

        // R-30a: go('/ajustes') desde Tasas es un cambio de rama (sin
        // apilar) — el redirect no duplica la clave de página.
        router.go('/tasas');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        router.go('/ajustes');
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 300));
        expect(
          router.routerDelegate.currentConfiguration.uri.toString(),
          '/ajustes',
        );
      },
    );
  });

  group('R-30h · el tour habla del v30', () {
    test('Más y conexión al día; Análisis con las 4 secciones', () {
      final navbar = kTourSegments
          .firstWhere((s) => s.location == '/')
          .steps
          .firstWhere((s) => s.id == 'inicio.navbar');
      // «Más» reúne los 5 módulos de verdad (H-41).
      expect(navbar.body, contains('Privacidad'));
      expect(navbar.body, isNot(contains('Sala')));

      final analisis = kTourSegments
          .firstWhere((s) => s.location == '/analisis')
          .steps
          .firstWhere((s) => s.id == 'analisis.anclas');
      // H-40: 4 secciones — «productos» salió del copy.
      expect(analisis.body, contains('canasta'));
      expect(analisis.body, isNot(contains('productos')));

      final rango = kTourSegments
          .firstWhere((s) => s.location == '/analisis')
          .steps
          .firstWhere((s) => s.id == 'analisis.rango');
      // El rango es una barra (no chips) y no existe en Canasta.
      expect(rango.body, contains('barra'));
      expect(rango.body, contains('Canasta'));

      final conexion = kTourSegments
          .firstWhere((s) => s.location == '/ajustes')
          .steps
          .firstWhere((s) => s.id == 'ajustes.conexion');
      // Ajustes en una pantalla (H-42).
      expect(conexion.body, contains('UNA pantalla'));
    });
  });
}
