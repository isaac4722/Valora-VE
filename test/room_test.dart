/// ─── Tests de la sala P2P (v19.0 · reescrita desde 0) ───────────────────────
/// El seam RoomLink permite probar TODO el protocolo sin red ni
/// plataforma: un enlace falso graba lo enviado y deja inyectar lo que
/// llega. Se cubre: crear (host), unirse (hello→welcome), el bug histórico
/// del rol ambiguo (un host NUNCA arranca como descubridor), gobierno de
/// roles, cierre, caída del anfitrión y las reglas del protocolo.
library;

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/room/room_controller.dart';
import 'package:valorave/room/room_transport.dart';

/// Enlace falso: implementa el SEAM tal cual — el controlador no sabe que
/// no hay radio de por medio.
class FakeLink implements RoomLink {
  FakeLink(this.modeId);

  @override
  final String modeId;

  final sent = <({String to, String type, Map<String, dynamic> payload})>[];
  final _events = StreamController<RoomEvent>.broadcast();
  final _statuses = StreamController<RoomStatus>.broadcast();

  @override
  RoomStatus status = RoomStatus.disconnected;

  bool hostStarted = false;
  bool dialed = false;
  String? lastDialedCode;

  @override
  Stream<RoomEvent> get events => _events.stream;
  @override
  Stream<RoomStatus> get statusStream => _statuses.stream;

  void setStatus(RoomStatus s) {
    status = s;
    _statuses.add(s);
  }

  /// Simula la llegada de un mensaje de un par (con fromId).
  void inject(String type, Map<String, dynamic> payload, [String fromId = '']) {
    _events.add(
      RoomEvent(type, {...payload, if (fromId.isNotEmpty) 'fromId': fromId}),
    );
  }

  @override
  Future<void> startHost({
    required String roomCode,
    required String myName,
    required String roomName,
    required bool isPublic,
  }) async {
    hostStarted = true;
    lastDialedCode = roomCode; // el código real viaja al anuncio
    setStatus(RoomStatus.connected);
  }

  @override
  Future<void> dial({
    required String roomCode,
    required String myName,
    String? host,
    int? port,
    String? endpointId,
  }) async {
    dialed = true;
    lastDialedCode = roomCode;
    setStatus(RoomStatus.connected);
  }

  @override
  Future<void> send(String type, Map<String, dynamic> payload) async {
    sent.add((to: '*', type: type, payload: payload));
  }

  @override
  Future<void> sendTo(
    String id,
    String type,
    Map<String, dynamic> payload,
  ) async {
    sent.add((to: id, type: type, payload: payload));
  }

  @override
  Future<void> disconnect() async {
    setStatus(RoomStatus.disconnected);
  }
}

AppStore _store() => AppStore.withData(const AppData());

void main() {
  group('RoomProtocol · reglas del servidor (§6)', () {
    test('código de 6 letras sin O/I', () {
      final code = RoomProtocol.newCode((max) => 3);
      expect(code, hasLength(6));
      expect(code, isNot(contains('O')));
      expect(code, isNot(contains('I')));
    });

    test('límite de payload 16 KB', () {
      expect(RoomProtocol.tooLarge({'x': 'a' * 1024}), isFalse);
      expect(RoomProtocol.tooLarge({'x': 'a' * (16 * 1024)}), isTrue);
    });

    test('cleanName ≤24 y nunca vacío', () {
      expect(RoomProtocol.cleanName('  '), 'Comprador');
      expect(RoomProtocol.cleanName('a' * 40), hasLength(24));
    });

    test('sanitizeItem: qty 1–999, price≥0, moneda 3 mayúsculas', () {
      final ok = RoomProtocol.sanitizeItem({
        'id': 'i1',
        'name': 'Café',
        'quantity': 2,
        'price': 3.5,
        'currency': 'USD',
      }, 'me');
      expect(ok, isNotNull);
      expect(
        RoomProtocol.sanitizeItem({
          'id': 'i1',
          'name': 'X',
          'quantity': 0,
          'price': 1,
          'currency': 'USD',
        }, 'me'),
        isNull,
      );
      expect(
        RoomProtocol.sanitizeItem({
          'id': 'i1',
          'name': 'X',
          'quantity': 1,
          'price': 1,
          'currency': 'usd',
        }, 'me'),
        isNull,
      );
    });

    test('mensajes humanos de error (incluye BT)', () {
      expect(RoomProtocol.errorMessage('not_found'), 'No existe esa sala');
      expect(
        RoomProtocol.errorMessage('bt_timeout'),
        'El otro teléfono no respondió a tiempo',
      );
      expect(RoomProtocol.errorMessage('host_lost'), 'Se perdió al anfitrión');
    });

    test('RoomMember: rol con round-trip y default editor', () {
      final m = RoomMember.fromMap(RoomMember(id: 'g1', name: 'Ana').toMap());
      expect(m.role, 'editor');
      expect(m.id, 'g1');
    });
  });

  group('RoomController · protocolo hello→welcome (enlace falso)', () {
    test(
      'crear: el enlace arranca como ANFITRIÓN con su código real',
      () async {
        final link = FakeLink('cerca');
        final c = RoomController(_store(), linkFactory: (_) => link);
        final err = await c.create(
          name: 'Isa',
          roomName: 'Compras',
          isPublic: true,
        );
        expect(err, isNull, reason: 'crear no debe fallar');
        expect(c.connected, isTrue);
        expect(c.code, hasLength(6));
        expect(c.isHost, isTrue);
        expect(c.myRole, 'host');
        // EL bug histórico: el host debe anunciar (startHost), NUNCA descubrir.
        expect(
          link.hostStarted,
          isTrue,
          reason: 'el host NO puede arrancar como descubridor',
        );
        expect(link.dialed, isFalse);
        expect(
          link.lastDialedCode,
          c.code,
          reason: 'el anuncio lleva el código real',
        );
        expect(c.visibleMembers.first.role, 'host');
        await c.leave();
      },
    );

    test('unirse: hello→welcome y SOLO entonces conectado', () async {
      final link = FakeLink('cerca');
      final c = RoomController(_store(), linkFactory: (_) => link);
      final future = c.join(name: 'Ana', code: 'ABC234');
      // El join NO resuelve hasta que el anfitrión conteste welcome.
      await Future<void>.delayed(const Duration(milliseconds: 30));
      expect(c.connected, isFalse);
      // El hello salió con código y nombre.
      expect(link.sent.any((m) => m.type == 'hello' && m.to == '*'), isTrue);
      // El anfitrión responde: welcome con identidad y estado completo.
      link.inject('welcome', {
        'code': 'ABC234',
        'roomName': 'Compras',
        'you': 'g7',
        'yourRole': 'editor',
        'members': [
          {'id': 'host', 'name': 'Isa', 'role': 'host'},
        ],
        'items': <dynamic>[],
      });
      final err = await future;
      expect(err, isNull);
      expect(c.connected, isTrue);
      expect(c.myId, 'g7');
      expect(c.roomName, 'Compras');
      expect(c.isHost, isFalse);
      expect(c.visibleMembers.length, 1); // el anfitrión
      await c.leave();
    });

    test(
      'unirse a una sala equivocada: error humano, sin sala fantasma',
      () async {
        final link = FakeLink('cerca');
        final c = RoomController(_store(), linkFactory: (_) => link);
        final future = c.join(name: 'Ana', code: 'ZZZ999');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        link.inject('room_error', {'reason': 'not_found'});
        final err = await future;
        expect(err, 'No existe esa sala');
        expect(c.connected, isFalse);
        expect(c.status, RoomStatus.disconnected);
      },
    );

    test('anfitrión: hello válido → welcome + members al resto', () async {
      final link = FakeLink('wifi');
      final c = RoomController(_store(), linkFactory: (_) => link);
      await c.create(name: 'Isa');
      link.inject('hello', {'code': c.code, 'name': 'Ana'}, 'g1');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      // welcome 1:1 al nuevo.
      final welcome = link.sent.firstWhere((m) => m.type == 'welcome');
      expect(welcome.to, 'g1');
      expect(welcome.payload['you'], 'g1');
      expect(welcome.payload['yourRole'], 'editor');
      expect((welcome.payload['members'] as List).length, 2); // host + Ana
      // members difundido al resto (aquí nadie más: broadcast vacío).
      expect(c.visibleMembers.length, 2);
      // hello con código incorrecto → not_found 1:1, sala intacta.
      link.inject('hello', {'code': 'OTRO99', 'name': 'X'}, 'g2');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(
        link.sent.any(
          (m) => m.type == 'room_error' && m.payload['reason'] == 'not_found',
        ),
        isTrue,
      );
      expect(c.visibleMembers.length, 2);
      await c.leave();
    });

    test(
      'roles: viewer no toca la lista; your_role cambia en caliente',
      () async {
        final link = FakeLink('cerca');
        final c = RoomController(_store(), linkFactory: (_) => link);
        final future = c.join(name: 'Ana', code: 'ABC234');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        link.inject('welcome', {
          'code': 'ABC234',
          'you': 'g1',
          'yourRole': 'editor',
          'members': <dynamic>[],
          'items': <dynamic>[],
        });
        await future;
        expect(c.isViewer, isFalse);
        // El anfitrión lo degrada a observador (el evento llega por el stream:
        // se espera un microtask antes de afirmar).
        link.inject('your_role', {'role': 'viewer'});
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(c.isViewer, isTrue);
        await c.leave();
      },
    );

    test(
      'cierre del anfitrión: room_closed llega y el invitado se va',
      () async {
        final link = FakeLink('cerca');
        final c = RoomController(_store(), linkFactory: (_) => link);
        final future = c.join(name: 'Ana', code: 'ABC234');
        await Future<void>.delayed(const Duration(milliseconds: 20));
        link.inject('welcome', {
          'code': 'ABC234',
          'you': 'g1',
          'yourRole': 'editor',
          'members': <dynamic>[],
          'items': <dynamic>[],
        });
        await future;
        expect(c.connected, isTrue);
        link.inject('room_closed', {'reason': 'purchase'});
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(c.connected, isFalse);
        expect(c.lastError, contains('compra'));
      },
    );

    test('caída del anfitrión (host_lost): salida honesta, no limbo', () async {
      final link = FakeLink('bt');
      final c = RoomController(_store(), linkFactory: (_) => link);
      final future = c.join(name: 'Ana', code: 'ABC234');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      link.inject('welcome', {
        'code': 'ABC234',
        'you': 'g1',
        'yourRole': 'editor',
        'members': <dynamic>[],
        'items': <dynamic>[],
      });
      await future;
      expect(c.connected, isTrue);
      // El enlace muere (watchdog del hub).
      link.setStatus(RoomStatus.error);
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.connected, isFalse);
      expect(c.lastError, 'Se perdió al anfitrión');
    });

    test('gobierno: kick y cambio de rol del anfitrión', () async {
      final link = FakeLink('wifi');
      final c = RoomController(_store(), linkFactory: (_) => link);
      await c.create(name: 'Isa');
      link.inject('hello', {'code': c.code, 'name': 'Ana'}, 'g1');
      link.inject('hello', {'code': c.code, 'name': 'Beto'}, 'g2');
      await Future<void>.delayed(const Duration(milliseconds: 20));
      expect(c.visibleMembers.length, 3); // host + Ana + Beto
      // Rol: your_role 1:1 al afectado, role_change al RESTO.
      await c.setMemberRole('g1', 'viewer');
      expect(
        link.sent.any((m) => m.type == 'your_role' && m.to == 'g1'),
        isTrue,
      );
      expect(
        link.sent.any((m) => m.type == 'role_change' && m.to == 'g2'),
        isTrue,
      );
      // Kick: solo al afectado; el resto sigue.
      await c.kickMember('g1');
      expect(link.sent.any((m) => m.type == 'kicked' && m.to == 'g1'), isTrue);
      expect(c.visibleMembers.length, 2); // host + Beto
      await c.leave();
    });
  });

  group('RoomEvent / RoomStatus', () {
    test('fromMap usa el campo type', () {
      final e = RoomEvent.fromMap({'type': 'ping', 'x': 1});
      expect(e.type, 'ping');
      expect(e.payload['x'], 1);
    });
  });
}
