/// Tests del ciclo offline REAL (v17.8 · connectivity_plus + RatesPoller).
/// La señal del dueño: «client-side + offline es una de las principales
/// funciones y constantemente no se logra». Aquí se prueba el contrato:
/// · Sin red: ni loading falso ni consulta ni martilleo de reintentos.
/// · Vuelve la red: refresco automático (si el usuario lo permite).
/// · Arranque SIN red: el flag nace verdadero (no espera una transición).
/// · Degradación honesta: sin canal de plataforma queda «online».
library;

import 'dart:async';

import 'package:connectivity_plus_platform_interface/connectivity_plus_platform_interface.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/connectivity.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';

/// Plataforma falsa: estado controlable + stream manual.
class _FakeConnPlatform extends ConnectivityPlatform {
  final StreamController<List<ConnectivityResult>> _changes =
      StreamController<List<ConnectivityResult>>.broadcast();
  List<ConnectivityResult> state = const [ConnectivityResult.wifi];

  void emit() => _changes.add(state);

  @override
  Future<List<ConnectivityResult>> checkConnectivity() async => state;

  @override
  Stream<List<ConnectivityResult>> get onConnectivityChanged => _changes.stream;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('servicio tolerante: sin canal de plataforma queda «online»', () async {
    // Sin fake: el canal real no existe en el host de pruebas → catch → true.
    final svc = ConnectivityService();
    await svc.init();
    expect(svc.isOnline, isTrue);
    expect(svc.recheck(), completion(isTrue));
    svc.dispose();
  });

  testWidgets('arranque SIN red: el flag nace verdadero y NO se consulta', (
    tester,
  ) async {
    final fake = _FakeConnPlatform()..state = const [ConnectivityResult.none];
    ConnectivityPlatform.instance = fake;
    final svc = ConnectivityService();
    await svc.init();
    expect(svc.isOnline, isFalse);

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore.withData(const AppData());
    final poller = RatesPoller(
      store,
      NotificationsService(),
      AlertEngine(prefs),
      connectivity: svc,
    );
    expect(poller.offlineNet, isTrue, reason: 'nace sin red, sin transición');

    var notifications = 0;
    poller.addListener(() => notifications++);
    await poller.refreshNow();
    await tester.pump(const Duration(milliseconds: 100));
    // Ni loading fingido ni consulta: CERO ruido de notificaciones.
    expect(notifications, 0);
    expect(poller.loading, isFalse);
    expect(poller.networkBlocked, isFalse, reason: 'nunca intentó consultar');
    poller.dispose();
    svc.dispose();
    await fake._changes.close();
  });

  testWidgets('vuelve la red: refresco automático y estado honesto', (
    tester,
  ) async {
    final fake = _FakeConnPlatform()..state = const [ConnectivityResult.none];
    ConnectivityPlatform.instance = fake;
    final svc = ConnectivityService();
    await svc.init();

    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore.withData(const AppData());
    final poller = RatesPoller(
      store,
      NotificationsService(),
      AlertEngine(prefs),
      connectivity: svc,
    );
    addTearDown(svc.dispose);
    addTearDown(fake._changes.close);

    // La red vuelve (wifi).
    fake.state = const [ConnectivityResult.wifi];
    fake.emit();
    await tester.pump(const Duration(milliseconds: 50));
    expect(poller.offlineNet, isFalse);

    // El refresco automático corrió: en el host de pruebas todas las
    // fuentes fallan y se ingiere un tablero VACÍO (fallo por fuente, no
    // de red) — la evidencia del intento es el reloj de frescura vivo.
    await tester.pump(const Duration(milliseconds: 700));
    expect(
      poller.lastBoardOk,
      isNotNull,
      reason: 'consultó al volver la red (ciclo completo)',
    );
    expect(poller.loading, isFalse);
    expect(poller.offlineNet, isFalse);
    // El latido auto quedó programado (startAuto): se cancela ANTES del
    // fin del cuerpo — el invariant !timersPending corre antes de los
    // tearDown.
    poller.dispose();
  });

  testWidgets(
    'modo offline ELEGIDO sigue mandando: la red que vuelve no consulta',
    (tester) async {
      final fake = _FakeConnPlatform()..state = const [ConnectivityResult.none];
      ConnectivityPlatform.instance = fake;
      final svc = ConnectivityService();
      await svc.init();

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore.withData(const AppData());
      store.setOfflineMode(true); // decisión del dueño: NADA de consultas
      final poller = RatesPoller(
        store,
        NotificationsService(),
        AlertEngine(prefs),
        connectivity: svc,
      );
      addTearDown(svc.dispose);
      addTearDown(fake._changes.close);

      fake.state = const [ConnectivityResult.wifi];
      fake.emit();
      await tester.pump(const Duration(milliseconds: 700));
      // Volvió la red pero el modo offline manda: ni consulta (reloj de
      // frescura intacto) ni loading. Dispose en el cuerpo: cero timers.
      expect(
        poller.lastBoardOk,
        isNull,
        reason: 'modo offline manda sobre la red',
      );
      expect(poller.loading, isFalse);
      poller.dispose();
    },
  );
}
