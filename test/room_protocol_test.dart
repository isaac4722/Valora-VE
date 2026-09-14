/// Tests del protocolo lista-sync (§6) con transports falsos en memoria.
/// Los mocks de transport SOLO viven en test/ (AGENT.md §5.5).
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/room/room_transport.dart';

/// Transporte falso en memoria: emite y recibe localmente.
class FakeTransport extends RoomTransport {
  final _events = StreamController<RoomEvent>.broadcast();
  final _statuses = StreamController<RoomStatus>.broadcast();
  final sent = <({String type, Map<String, dynamic> payload})>[];
  RoomStatus _status = RoomStatus.disconnected;
  Map<String, dynamic> Function(String, Map<String, dynamic>)? onEmit;

  @override
  String get name => 'Fake';
  @override
  RoomStatus get status => _status;
  @override
  Stream<RoomEvent> get events => _events.stream;
  @override
  Stream<RoomStatus> get statusStream => _statuses.stream;

  void serverEmit(RoomEvent ev) => _events.add(ev);
  void setStatus(RoomStatus s) {
    _status = s;
    _statuses.add(s);
  }

  @override
  Future<void> connect({required String roomCode, required String myName}) async {
    setStatus(RoomStatus.connecting);
    setStatus(RoomStatus.connected);
  }

  @override
  Future<Map<String, dynamic>?> emit(String type, Map<String, dynamic> payload) async {
    sent.add((type: type, payload: payload));
    return onEmit?.call(type, payload);
  }

  @override
  Future<void> disconnect() async => setStatus(RoomStatus.disconnected);

  @override
  Future<List<String>> discover() async => const [];
}

void main() {
  group('RoomProtocol · reglas del servidor (§6)', () {
    test('código de 6 letras sin O/I', () {
      var seed = 0;
      final code = RoomProtocol.newCode((max) => seed++ % max);
      expect(code.length, 6);
      expect(code.contains('O'), isFalse);
      expect(code.contains('I'), isFalse);
      expect(RegExp(r'^[A-HJ-NP-Z2-9]{6}$').hasMatch(code), isTrue);
    });

    test('límite de payload 16 KB', () {
      expect(RoomProtocol.tooLarge({'x': 'a' * 17 * 1024}), isTrue);
      expect(RoomProtocol.tooLarge({'x': 'a' * 100}), isFalse);
    });

    test('cleanName ≤24 y nunca vacío', () {
      expect(RoomProtocol.cleanName('   '), 'Comprador');
      expect(RoomProtocol.cleanName('a' * 30), 'a' * 24);
      expect(RoomProtocol.cleanName('  Ana  '), 'Ana');
    });

    test('sanitizeItem: qty 1–999, price≥0, moneda 3 mayúsculas', () {
      final ok = RoomProtocol.sanitizeItem(
          {'id': 'i1', 'name': 'Arroz', 'quantity': 2, 'price': 40, 'currency': 'VES'}, 'm1');
      expect(ok, isNotNull);
      expect(ok!['quantity'], 2);

      expect(RoomProtocol.sanitizeItem(
          {'id': 'i1', 'name': 'X', 'quantity': 0, 'price': 1, 'currency': 'VES'}, 'm'), isNull);
      expect(RoomProtocol.sanitizeItem(
          {'id': 'i1', 'name': 'X', 'quantity': 1000, 'price': 1, 'currency': 'VES'}, 'm'), isNull);
      expect(RoomProtocol.sanitizeItem(
          {'id': 'i1', 'name': 'X', 'quantity': 1, 'price': -1, 'currency': 'VES'}, 'm'), isNull);
      expect(RoomProtocol.sanitizeItem(
          {'id': 'i1', 'name': 'X', 'quantity': 1, 'price': 1, 'currency': 'ves'}, 'm'), isNull);
      expect(RoomProtocol.sanitizeItem(
          {'id': 'i1', 'name': 'a' * 250, 'quantity': 1, 'price': 1, 'currency': 'USD'}, 'm'), isNull);
    });

    test('mensajes humanos de error', () {
      expect(RoomProtocol.errorMessage('not_found'), 'No existe esa sala');
      expect(RoomProtocol.errorMessage('room_full'), contains('llena'));
      expect(RoomProtocol.errorMessage('list_full'), contains('120'));
    });

    // v18.0 · Bluetooth RFCOMM real: errores humanos del camino BT.
    test('mensajes humanos de error BT', () {
      expect(RoomProtocol.errorMessage('unavailable'),
          'Este teléfono no tiene Bluetooth');
      expect(RoomProtocol.errorMessage('off'),
          'Enciende el Bluetooth para usar este modo');
      expect(RoomProtocol.errorMessage('bt_timeout'),
          'El otro teléfono no respondió a tiempo');
      expect(RoomProtocol.errorMessage('bt_connect'),
          'No se pudo conectar por Bluetooth');
      expect(RoomProtocol.errorMessage('kicked'), 'Te sacaron de la sala');
      expect(RoomProtocol.errorMessage('room_closed'), 'La sala se cerró');
    });

    // v18.0 · Sala Viva: roles viajan en el wire (host|editor|viewer).
    test('RoomMember: rol con round-trip y default editor', () {
      final m = RoomMember(id: 'bt1', name: 'Ana');
      expect(m.role, 'editor');
      final host = RoomMember.fromMap({'id': 'host', 'name': 'Yo', 'role': 'host'});
      expect(host.role, 'host');
      final viewer = RoomMember.fromMap({'id': 'bt2', 'name': 'Bob', 'role': 'viewer'});
      expect(viewer.role, 'viewer');
      // Round-trip: toMap conserva el rol.
      final rt = RoomMember.fromMap(viewer.toMap());
      expect(rt.role, 'viewer');
      // Sin rol en el mapa (server de referencia viejo) → editor.
      expect(RoomMember.fromMap({'id': 'x', 'name': 'X'}).role, 'editor');
    });
  });

  group('RoomEvent', () {
    test('fromMap usa el campo type', () {
      final ev = RoomEvent.fromMap({'type': 'item_add', 'item': {'id': 'a'}});
      expect(ev.type, 'item_add');
      expect(ev.payload['item'], {'id': 'a'});
    });
  });

  group('RoomStatus flujo', () {
    test('statusStream emite cambios', () async {
      final t = FakeTransport();
      final seen = <RoomStatus>[];
      final sub = t.statusStream.listen(seen.add);
      await t.connect(roomCode: 'ABC234', myName: 'Tester');
      await Future<void>.delayed(const Duration(milliseconds: 10));
      await sub.cancel();
      expect(seen, [RoomStatus.connecting, RoomStatus.connected]);
    });
  });
}
