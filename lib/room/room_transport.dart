/// ─── RoomTransport · interfaz común de la sala (decisión §4.10) ─────────────
/// Tres transportes con el MISMO protocolo lista-sync (MVP §6):
///  a) SocketIoTransport — servidor socket.io con URL configurada por el
///     usuario (server/lista-sync/ listo para desplegar).
///  b) NearbyTransport — Google Nearby Connections (WiFi-Direct/BT/BLE,
///     P2P_STAR) vía nearby_connections: sin internet.
///  c) LanTransport — mismo WiFi: NSD/mDNS o IP directa.
/// El protocolo es idéntico; solo cambia cómo viajan los bytes.
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../core/models.dart';
import '../data/store.dart';
import '../services/lan_hub.dart';
import '../services/nearby_hub.dart';

export '../services/lan_hub.dart' show LanHubImpl;
export '../services/nearby_hub.dart' show NearbyHubImpl;

/// Evento normalizado del protocolo lista-sync (SIN acoplarse al transporte).
class RoomEvent {
  final String type;
  final Map<String, dynamic> payload;

  const RoomEvent(this.type, this.payload);

  factory RoomEvent.fromMap(Map<String, dynamic> m) =>
      RoomEvent('${m['type'] ?? 'unknown'}', m);

  Map<String, dynamic> toMap() => {'type': type, ...payload};
}

/// Estados de la sala.
enum RoomStatus { disconnected, connecting, connected, error }

/// Contrato de transporte: conectar, emitir, stream, descubrir.
abstract class RoomTransport {
  String get name; // 'Servidor' | 'Cerca' | 'WiFi local'
  RoomStatus get status;
  Stream<RoomEvent> get events;
  Stream<RoomStatus> get statusStream;

  Future<void> connect({required String roomCode, required String myName});
  Future<Map<String, dynamic>?> emit(String type, Map<String, dynamic> payload); // con ack
  Future<void> disconnect();
  Future<List<String>> discover(); // códigos visibles (opcional)
}

/// ─── (a) Servidor socket.io (URL del usuario en Ajustes) ───────────────────
class SocketIoTransport extends RoomTransport {
  SocketIoTransport({required this.serverUrl});

  final String serverUrl;
  sio.Socket? _socket;
  RoomStatus _status = RoomStatus.disconnected;
  final _events = StreamController<RoomEvent>.broadcast();
  final _statuses = StreamController<RoomStatus>.broadcast();

  @override
  String get name => 'Servidor';
  @override
  RoomStatus get status => _status;
  @override
  Stream<RoomEvent> get events => _events.stream;
  @override
  Stream<RoomStatus> get statusStream => _statuses.stream;

  void _setStatus(RoomStatus s) {
    _status = s;
    _statuses.add(s);
  }

  @override
  Future<void> connect({required String roomCode, required String myName}) async {
    _setStatus(RoomStatus.connecting);
    final connected = Completer<bool>();
    _socket = sio.io(
      serverUrl,
      sio.OptionBuilder()
          .setTransports(['websocket'])
          .setPath('/')
          .enableForceNew()
          .build(),
    );
    _socket!
      ..onConnect((_) {
        if (!connected.isCompleted) connected.complete(true);
      })
      ..onConnectError((e) {
        _setStatus(RoomStatus.error);
        if (!connected.isCompleted) connected.complete(false);
      })
      ..onAny((event, data) {
        if (data.isNotEmpty && data.first is Map) {
          final m = Map<String, dynamic>.from(data.first as Map);
          if (event == 'room_error') {
            _events.add(const RoomEvent('room_error', {'reason': 'error'}));
            return;
          }
          // item_* / list_* / member_* / presence / typing llevan 'type'.
          if (m.containsKey('type')) {
            _events.add(RoomEvent.fromMap(m));
          }
        }
      });

    final ok = await connected.future.timeout(const Duration(seconds: 8), onTimeout: () => false);
    if (!ok) return;

    // create_room o join_room con ack (§6).
    final isNew = roomCode.isEmpty;
    final ack = await emit(
        isNew ? 'create_room' : 'join_room',
        isNew ? {'name': myName} : {'code': roomCode, 'name': myName});
    if (ack != null && (ack['type'] == 'room_created' || ack['type'] == 'room_joined')) {
      _setStatus(RoomStatus.connected);
    } else {
      _setStatus(RoomStatus.error);
      _events.add(RoomEvent(
          'room_error',
          ack ?? const {'reason': 'not_found'}));
    }
  }

  @override
  Future<Map<String, dynamic>?> emit(String type, Map<String, dynamic> payload) async {
    if (_socket == null) return null;
    final completer = Completer<Map<String, dynamic>?>();
    _socket!.emitWithAck(type, payload, ack: (data) {
      if (data is Map) completer.complete(Map<String, dynamic>.from(data));
    });
    return completer.future.timeout(const Duration(seconds: 8), onTimeout: () => null);
  }

  @override
  Future<void> disconnect() async {
    _socket?.dispose();
    _socket = null;
    _setStatus(RoomStatus.disconnected);
  }

  @override
  Future<List<String>> discover() async => const [];
}

/// ─── (b) Google Nearby Connections (P2P, sin internet) ──────────────────────
/// El CREADOR hace advertise (anfitrión-hub) y los invitados discover+connect.
/// Mensajes: payloads JSON (bytes) con el MISMO protocolo; el hub retransmite.
class NearbyTransport extends RoomTransport {
  NearbyTransport({required this.hub});

  /// El hub vive en services/nearby_hub.dart: puente al paquete
  /// nearby_connections con advertise/discover/send.
  final NearbyHubImpl hub;

  @override
  String get name => 'Cerca';
  @override
  RoomStatus get status => hub.status;
  @override
  Stream<RoomEvent> get events => hub.events;
  @override
  Stream<RoomStatus> get statusStream => hub.statusStream;

  @override
  Future<void> connect({required String roomCode, required String myName}) =>
      hub.connect(roomCode: roomCode, myName: myName);

  @override
  Future<Map<String, dynamic>?> emit(String type, Map<String, dynamic> payload) =>
      hub.emit(type, payload);

  @override
  Future<void> disconnect() => hub.disconnect();

  @override
  Future<List<String>> discover() => hub.discover();
}

/// ─── (c) WiFi LAN: mismo SSID — broadcast UDP (descubrimiento) + TCP ────────
/// El creador escucha en el puerto 48130 y anuncia «VALORAVE|CÓDIGO|puerto»
/// por broadcast. Invitados: escuchan y conectan por TCP. Protocolo: líneas
/// JSON lista-sync idénticas al servidor. Hub en services/lan_hub.dart.
class LanTransport extends RoomTransport {
  LanTransport({required this.hub});
  final LanHubImpl hub;

  @override
  String get name => 'WiFi local';
  @override
  RoomStatus get status => hub.status;
  @override
  Stream<RoomEvent> get events => hub.events;
  @override
  Stream<RoomStatus> get statusStream => hub.statusStream;

  @override
  Future<void> connect({required String roomCode, required String myName}) =>
      hub.connect(roomCode: roomCode, myName: myName);

  @override
  Future<Map<String, dynamic>?> emit(String type, Map<String, dynamic> payload) =>
      hub.emit(type, payload);

  @override
  Future<void> disconnect() => hub.disconnect();

  @override
  Future<List<String>> discover() => hub.discover();
}

/// ─── Utilidades del protocolo (idénticas al servidor) ───────────────────────
class RoomProtocol {
  /// Límite de payload 16 KB (§6).
  static bool tooLarge(Map<String, dynamic> payload) =>
      utf8.encode(jsonEncode(payload)).length > 16 * 1024;

  /// Código de 6 letras sin O/I (el cliente genera para Nearby/LAN).
  static String newCode([int Function(int max)? nextInt]) {
    const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = nextInt ?? ((max) => DateTime.now().microsecondsSinceEpoch % max);
    var code = '';
    for (var i = 0; i < 6; i++) {
      code += alphabet[rnd(alphabet.length)];
    }
    return code;
  }

  /// Nombre limpio ≤24 (cleanName del servidor).
  static String cleanName(String raw) {
    final s = raw.trim();
    return s.isEmpty ? 'Comprador' : (s.length > 24 ? s.substring(0, 24) : s);
  }

  /// Sanea ítem entrante (sanitizeItem del servidor) — null si inválido.
  static Map<String, dynamic>? sanitizeItem(dynamic raw, String by) {
    if (raw is! Map) return null;
    final m = Map<String, dynamic>.from(raw);
    final id = m['id'];
    final name = '${m['name'] ?? ''}'.trim();
    final qty = (m['quantity'] as num?)?.toDouble() ?? -1;
    final price = (m['price'] as num?)?.toDouble() ?? -1;
    final currency = '${m['currency'] ?? ''}';
    final validId = id is String && id.isNotEmpty && id.length <= 64;
    final validCur = RegExp(r'^[A-Z]{3}$').hasMatch(currency);
    if (!validId || name.isEmpty || name.length > 200 || qty < 1 || qty > 999 || price < 0 || !validCur) {
      return null;
    }
    final out = <String, dynamic>{
      'id': id,
      'name': name,
      'quantity': qty.round(),
      'price': price,
      'currency': currency,
      'by': by,
    };
    if (m['checked'] is bool) out['checked'] = m['checked'];
    if (m['checkedBy'] is String) {
      final cb = (m['checkedBy'] as String).trim();
      if (cb.isNotEmpty && cb.length <= 24) out['checkedBy'] = cb;
    }
    return out;
  }

  /// Errores humanos (not_found → No existe esa sala, etc.).
  static String errorMessage(String reason) => switch (reason) {
        'not_found' => 'No existe esa sala',
        'room_full' => 'La sala está llena (8 personas)',
        'too_large' => 'El mensaje pesa más de 16 KB',
        'bad_item' => 'Ítem inválido',
        'bad_update' => 'Cambio inválido',
        'bad_remove' => 'No se puede quitar ese ítem',
        'bad_items' => 'Lista inválida',
        'list_full' => 'La sala llegó a 120 ítems',
        'not_in_room' => 'No estás en ninguna sala',
        _ => 'Error: $reason',
      };
}

/// ─── Controlador de la sala para la UI ──────────────────────────────────────
/// Estado + guard baseline+suppress (los remotos llegan por applyRemoteRoomEvent
/// del store y NUNCA se re-emitir) + outbox offline.
class RoomController extends ChangeNotifier {
  RoomController(this._store);

  final AppStore _store;
  RoomTransport? _transport;
  RoomStatus _status = RoomStatus.disconnected;
  String _code = '';
  String _myName = 'Comprador';
  String _mode = 'server'; // server | nearby | lan
  final List<RoomMember> _members = [];


  RoomStatus get status => _status;
  String get code => _code;
  String get myName => _myName;
  String get mode => _mode;
  bool get connected => _status == RoomStatus.connected;
  List<RoomMember> get members => List.unmodifiable(_members);
  StreamSubscription<RoomEvent>? _sub;
  StreamSubscription<RoomStatus>? _statusSub;

  void setMode(String m) {
    _mode = m;
    notifyListeners();
  }

  void setServerUrl(String url) => _store.prefs?.setString('valorave.liveServerUrl', url);
  String get serverUrl => _store.prefs?.getString('valorave.liveServerUrl') ?? '';

  /// Crea (code vacío) o se une con código.
  Future<String?> join({required String code, required String name, required String mode}) async {
    _myName = RoomProtocol.cleanName(name);
    _mode = mode;
    final RoomTransport transport;
    switch (mode) {
      case 'nearby':
        transport = NearbyTransport(hub: NearbyHubImpl());
      case 'lan':
        transport = LanTransport(hub: LanHubImpl());
      default:
        final url = serverUrl;
        if (url.isEmpty) return 'Configura la URL del servidor en Ajustes → Sala';
        transport = SocketIoTransport(serverUrl: url);
    }
    _transport = transport;
    _statusSub = transport.statusStream.listen((s) {
      _status = s;
      notifyListeners();
    });
    _sub = transport.events.listen(_onEvent);
    _status = RoomStatus.connecting;
    notifyListeners();

    try {
      await transport.connect(roomCode: code, myName: _myName);
      if (_status != RoomStatus.connected) {
        await leave();
        return code.isEmpty ? 'No se pudo crear la sala' : 'No existe esa sala';
      }
      return null; // OK
    } catch (e) {
      return 'Sin conexión: $e';
    }
  }

  /// Guard baseline+suppress: los eventos remotos solo aplican al store.
  void _onEvent(RoomEvent ev) {
    switch (ev.type) {
      case 'room_created' || 'room_joined':
        _code = '${ev.payload['code'] ?? ev.payload['id'] ?? _code}';
        _status = RoomStatus.connected;
        _members
          ..clear()
          ..addAll(((ev.payload['members'] as List?) ?? const [])
              .whereType<Map>()
              .map((m) => RoomMember.fromMap(Map<String, dynamic>.from(m))));
        // El joiner RECIBE el estado del servidor y PIERDE su lista previa (§6).
        final items = (ev.payload['items'] as List?) ?? const [];
        _store.applyRemoteRoomEvent('list_replace', {'items': items});
      case 'member_joined':
        final m = ev.payload['member'];
        if (m is Map) {
          _members.add(RoomMember.fromMap(Map<String, dynamic>.from(m)));
          _store.pushNotification(
              kind: NotifKind.info,
              title: 'Se unió ${m['name']}',
              body: 'Ahora hay ${_members.length} personas en la sala.');
        }
      case 'member_left':
        _members.removeWhere((m) => m.id == '${ev.payload['id']}');
      case 'presence':
        final online = ((ev.payload['online'] as List?) ?? const []).map((e) => '$e').toSet();
        for (final m in _members) {
          m.online = online.contains(m.id);
        }
      case 'typing':
        final names = ((ev.payload['names'] as List?) ?? const []).map((e) => '$e').toSet();
        for (final m in _members) {
          m.typing = names.contains(m.name);
        }
      case 'item_add' ||
            'item_update' ||
            'item_remove' ||
            'list_clear' ||
            'list_replace':
        _store.applyRemoteRoomEvent(ev.type, ev.payload);
      case 'room_error':
        _status = RoomStatus.error;
    }
    notifyListeners();
  }

  /// Emite con outbox: sin conexión → encola (outbox offline §7/§12.2).
  Future<void> emit(String type, Map<String, dynamic> payload) async {
    if (_transport == null || !connected) {
      _store.outbox
          .add({'type': type, ...payload, 'code': _code, 'queuedAt': DateTime.now().toIso8601String()});
      _store.persistOutbox();
      return;
    }
    if (RoomProtocol.tooLarge(payload)) return;
    await _transport!.emit(type, payload);
  }

  /// Presence cada 10 s + typing con throttle 1.2 s (UI manda la señal).
  Future<void> flushOutbox() async {
    if (!connected || _store.outbox.isEmpty) return;
    final queue = [..._store.outbox];
    for (final msg in queue) {
      await _transport!.emit('${msg['type']}', msg);
      _store.outbox.remove(msg);
    }
    _store.persistOutbox();
  }

  Future<void> leave() async {
    await _transport?.emit('leave_room', {});
    await _transport?.disconnect();
    _sub?.cancel();
    _statusSub?.cancel();
    _transport = null;
    _status = RoomStatus.disconnected;
    _members.clear();
    notifyListeners();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _statusSub?.cancel();
    _transport?.disconnect();
    super.dispose();
  }
}



class RoomMember {
  RoomMember({required this.id, required this.name, this.online = true, this.typing = false});

  final String id;
  final String name;
  bool online;
  bool typing;

  factory RoomMember.fromMap(Map<String, dynamic> m) => RoomMember(
        id: '${m['id'] ?? ''}',
        name: '${m['name'] ?? ''}',
      );
}
