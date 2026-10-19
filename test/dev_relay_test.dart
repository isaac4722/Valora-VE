/// Tests del puente sin PC (v21.7): lógica pura (URL del relay, hello) y el
/// despachador de comandos contra el servidor de pruebas REAL (HTTP de
/// loopback, puerto efímero). Sin TestWidgetsFlutterBinding a propósito —
/// igual que dev_bridge_test.dart: ese binding intercepta HttpClient con
/// 400 falsos y aquí `appcmd` necesita sockets de verdad.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/services/dev_bridge_vm.dart';
import 'package:valorave/services/dev_relay_proto.dart';
import 'package:valorave/services/dev_relay_vm.dart';

void main() {
  late AppStore store;

  setUp(() async {
    store = AppStore.withData(const AppData());
    final ok = await DevBridge.start(store: store, port: 0);
    expect(ok, isTrue, reason: 'el servidor de pruebas debe escuchar');
  });

  tearDown(() async {
    await DevBridge.stop();
  });

  group('relayWsUrl (pura)', () {
    test('https del preview → wss con rol bridge y token', () {
      expect(
        relayWsUrl('https://preview-abc.space-z.ai', 'tok1'),
        'wss://preview-abc.space-z.ai/api/ws?role=bridge&token=tok1',
      );
    });

    test('dominio pelado asume https → wss; slash final se ignora', () {
      expect(
        relayWsUrl('preview-abc.space-z.ai/', 'tok1'),
        'wss://preview-abc.space-z.ai/api/ws?role=bridge&token=tok1',
      );
    });

    test('http local → ws (relay en la propia PC)', () {
      expect(
        relayWsUrl('http://127.0.0.1:3000', 't2'),
        'ws://127.0.0.1:3000/api/ws?role=bridge&token=t2',
      );
    });

    test('token viaja codificado y llega entero', () {
      final u = Uri.parse(relayWsUrl('https://p.space-z.ai', 'a b/c'));
      expect(u.queryParameters['token'], 'a b/c');
      expect(u.queryParameters['role'], 'bridge');
    });

    test('esquema ajeno al web y vacío → FormatException honesto', () {
      expect(
        () => relayWsUrl('ftp://ejemplo.com', 't'),
        throwsFormatException,
      );
      expect(() => relayWsUrl('   ', 't'), throwsFormatException);
    });
  });

  group('relayHello (pura)', () {
    test('forma que el piloto ya consume: model + resolution + source app', () {
      final h = relayHello(model: 'TECNO BF6', w: 720, h: 1600);
      expect(h['type'], 'hello');
      final dev = h['device'] as Map<String, dynamic>;
      expect(dev['model'], 'TECNO BF6');
      expect(dev['resolution'], {'w': 720, 'h': 1600});
      expect(dev['source'], 'app');
    });
  });

  group('handleCmd contra el servidor de pruebas real', () {
    test('appcmd /health llega al DevBridge de loopback', () async {
      final (res, bin) = await DevRelay.handleCmd(<String, dynamic>{
        'type': 'cmd',
        'id': 'c1',
        'action': 'appcmd',
        'args': {'path': '/health'},
      });
      expect(bin, isNull);
      expect(res['ok'], isTrue);
      final data = res['data'] as Map<String, dynamic>;
      expect(data['status'], 200);
      expect((data['json'] as Map<String, dynamic>)['app'], 'ValoraVE');
    });

    test('appcmd /erase sin token → la app responde 403 (protegido)', () async {
      DevBridge.setTokenForSession('tok-de-prueba');
      final (res, _) = await DevRelay.handleCmd(<String, dynamic>{
        'type': 'cmd',
        'id': 'c2',
        'action': 'appcmd',
        'args': {'path': '/erase'},
      });
      expect(res['ok'], isTrue, reason: 'el comando SÍ se despachó');
      expect(
        (res['data'] as Map<String, dynamic>)['status'],
        403,
        reason: 'y la app exigió el token de /erase',
      );
    });

    test('appcmd con servidor de pruebas apagado → error honesto', () async {
      await DevBridge.stop();
      final (res, _) = await DevRelay.handleCmd(<String, dynamic>{
        'type': 'cmd',
        'id': 'c3',
        'action': 'appcmd',
        'args': {'path': '/health'},
      });
      expect(res['ok'], isFalse);
      expect((res['error'] as String), contains('apagado'));
    });

    test('tap/swipe/text/key/shell → honesto: este puente no inyecta entrada',
        () async {
      for (final action in ['tap', 'swipe', 'text', 'key', 'shell']) {
        final (res, _) = await DevRelay.handleCmd(<String, dynamic>{
          'type': 'cmd',
          'id': 'x-$action',
          'action': action,
          'args': <String, dynamic>{},
        });
        expect(res['ok'], isFalse, reason: action);
        expect(
          (res['error'] as String),
          contains('USB'),
          reason: 'el error debe mandar al dueño al camino USB',
        );
      }
    });

    test('acción desconocida → error con el nombre', () async {
      final (res, _) = await DevRelay.handleCmd(<String, dynamic>{
        'type': 'cmd',
        'id': 'z',
        'action': 'volar',
        'args': <String, dynamic>{},
      });
      expect(res['ok'], isFalse);
      expect((res['error'] as String), contains('volar'));
    });

    test('stream on/off alterna el flag sin dejar timers colgados', () async {
      final (on, _) = await DevRelay.handleCmd(<String, dynamic>{
        'type': 'cmd',
        'id': 's1',
        'action': 'stream',
        'args': {'on': true},
      });
      expect((on['data'] as Map<String, dynamic>)['streaming'], isTrue);
      final (off, _) = await DevRelay.handleCmd(<String, dynamic>{
        'type': 'cmd',
        'id': 's2',
        'action': 'stream',
        'args': {'on': false},
      });
      expect((off['data'] as Map<String, dynamic>)['streaming'], isFalse);
    });
  });
}
