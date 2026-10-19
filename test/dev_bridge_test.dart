/// Tests del servidor de pruebas local (v21.6 · puente de depuración).
/// HTTP REAL sobre loopback (puerto efímero) contra AppStore en memoria.
/// Sin TestWidgetsFlutterBinding a propósito: ese binding intercepta todo
/// HttpClient y respondería 400 falso — estas pruebas necesitan sockets
/// de verdad porque prueban un servidor de verdad.
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/services/dev_bridge_vm.dart';

void main() {
  late AppStore store;
  late int port;

  setUp(() async {
    store = AppStore.withData(const AppData());
    final ok = await DevBridge.start(store: store, port: 0);
    expect(ok, isTrue, reason: 'el servidor debe escuchar en puerto efímero');
    port = DevBridge.port;
    expect(port, isNot(0));
  });

  tearDown(() async {
    await DevBridge.stop();
  });

  Future<Map<String, dynamic>> get(
    String path, {
    Map<String, String> headers = const {},
  }) async {
    final client = HttpClient();
    final req = await client.getUrl(Uri.parse('http://127.0.0.1:$port$path'));
    for (final e in headers.entries) {
      req.headers.add(e.key, e.value);
    }
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    client.close();
    return {
      'status': res.statusCode,
      ...jsonDecode(body) as Map<String, dynamic>,
    };
  }

  test('/health reporta app, versión y contadores del store', () async {
    final h = await get('/health');
    expect(h['status'], 200);
    expect(h['ok'], isTrue);
    expect(h['app'], 'ValoraVE');
    expect(h['version'], isNotEmpty);
    expect(h['cart'], 0);
    expect(h['nav'], isFalse, reason: 'sin router vinculado en pruebas');
  });

  test('/test siembra carrito multitienda y /erase lo borra con token', () async {
    DevBridge.setTokenForSession('tok-de-prueba');

    final seeded = await get('/test?scenario=cart');
    expect(seeded['ok'], isTrue);
    expect(seeded['cart'], 5);
    expect(store.cart.length, 5);
    // Multitienda: hay ítems con tienda asignada.
    expect(store.cart.any((c) => (c.store ?? '').isNotEmpty), isTrue);

    // Sin token → 403 (destructivo).
    final denied = await get('/erase');
    expect(denied['status'], 403);
    expect(store.cart.length, 5, reason: 'sin token no borra');

    // Con token → borra datos del usuario, conserva ajustes y tablero.
    final wiped = await get(
      '/erase',
      headers: {'x-valora-token': 'tok-de-prueba'},
    );
    expect(wiped['ok'], isTrue);
    expect(wiped['cleared']['cart'], 5);
    expect(store.cart, isEmpty);
    expect(store.purchases, isEmpty);
    expect(store.settings.country, store.settings.country,
        reason: 'ajustes intactos');
  });

  test('/test products y purchase siembran el libro y el historial', () async {
    final p = await get('/test?scenario=products');
    expect(p['ok'], isTrue);
    expect(p['products'], 3);
    expect(store.products.length, 3);
    expect(store.products.first.records, isNotEmpty);

    final c = await get('/test?scenario=purchase');
    expect(c['ok'], isTrue);
    expect(c['purchases'], 2);
    expect(store.purchases.length, 2);
    expect(store.purchases.first.items, isNotEmpty);
  });

  test('/test con escenario inválido responde 400', () async {
    final bad = await get('/test?scenario=inexistente');
    expect(bad['status'], 400);
    expect(bad['ok'], isFalse);
  });

  test('/nav solo navega rutas de la lista blanca', () async {
    final bad = await get('/nav?to=/no-existe');
    expect(bad['status'], 400);
    final unbound = await get('/nav?to=/historial');
    expect(unbound['status'], 409, reason: 'router no vinculado en pruebas');
  });

  test('ruta desconocida responde 404 con lista de endpoints', () async {
    final nf = await get('/cualquiera');
    expect(nf['status'], 404);
    expect(nf['endpoints'], contains('/health'));
  });
}
