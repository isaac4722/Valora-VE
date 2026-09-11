/// ─── NearbyHub · Google Nearby Connections (WiFi-Direct/BT/BLE, P2P_STAR) ──
/// Creador de sala = anfitrión (advertise) que retransmite (hub); invitados
/// hacen discover+requestConnection. El protocolo lista-sync viaja como
/// payloads de bytes JSON 1:1 igual que el servidor socket.io.
///
/// Filtrado «solo esta app»: el serviceId es exclusivo de ValoraVE
/// ([kServiceId]) y el endpointName lleva la identidad + metadata de la sala
/// («VALORAVE|{json}») — el descubrimiento solo muestra endpoints cuyo nombre
/// parsea como anuncio de la app. La verificación PIN+emoji ocurre después,
/// a nivel protocolo (room_transport).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

import '../room/room_transport.dart';

class NearbyHubImpl {
  /// ServiceId existente del proyecto — separa a ValoraVE de cualquier otra
  /// app que use Nearby en el mismo lugar.
  static const String kServiceId = 've.valorave.listasync';
  static const String kAdPrefix = 'VALORAVE|';
  static const int kMaxMembers = 10;

  RoomStatus _status = RoomStatus.disconnected;
  final _events = StreamController<RoomEvent>.broadcast();
  final _statuses = StreamController<RoomStatus>.broadcast();
  final _ads = StreamController<Map<String, dynamic>>.broadcast();
  final Map<String, String> _endpoints = {}; // endpointId → nombre
  bool _isHost = false;
  bool _joined = false;
  bool _scanning = false;
  String _myName = 'Comprador';
  String _roomCode = '';
  String _roomName = '';
  String _emoji = '';
  bool _roomPublic = true;
  String? _targetEndpointId;

  RoomStatus get status => _status;
  Stream<RoomEvent> get events => _events.stream;
  Stream<RoomStatus> get statusStream => _statuses.stream;

  /// Anuncios de salas vistas (escaneo): {via, code, endpointId, name, host,
  /// emoji, pub}. Solo salas públicas llegan aquí con metadata completa.
  Stream<Map<String, dynamic>> get roomAds => _ads.stream;

  bool get isHost => _isHost;
  int get endpointCount => _endpoints.length;

  void _setStatus(RoomStatus s) {
    _status = s;
    _statuses.add(s);
  }

  Future<bool> _granted() async {
    // permisos: BLUETOOTH_SCAN/ADVERTISE/CONNECT (31+), FINE_LOCATION (<31),
    // NEARBY_WIFI_DEVICES (33+) — gestionados por permission_handler en la
    // pantalla de sala (diálogo explicativo antes del permiso).
    return true;
  }

  /// Nombre del endpoint anfitrión: identidad + metadata de la sala.
  /// «VALORAVE|{"c":CODE,"n":nombre,"e":emoji,"p":0|1,"h":anfitrión}»
  String _adName() {
    final meta = jsonEncode({
      'c': _roomCode,
      'n': _roomName,
      'e': _emoji,
      'p': _roomPublic ? 1 : 0,
      'h': _myName,
    });
    return '$kAdPrefix$meta';
  }

  /// Parsea el endpointName de la app. null = dispositivo ajeno (se oculta).
  static Map<String, dynamic>? parseAdName(String name) {
    if (!name.startsWith(kAdPrefix)) return null;
    try {
      final m = jsonDecode(name.substring(kAdPrefix.length));
      if (m is Map && m['c'] is String) return Map<String, dynamic>.from(m);
    } catch (_) {}
    return null;
  }

  /// Conecta como anfitrión (roomCode vacío → advertise) o invitado
  /// (descubre y conecta al endpoint de ese código; [targetEndpointId]
  /// permite entrar directo a un resultado del escaneo).
  Future<void> connect({
    required String roomCode,
    required String myName,
    String roomName = '',
    String emoji = '',
    bool isPublic = true,
    String? targetEndpointId,
  }) async {
    if (!await _granted()) {
      _setStatus(RoomStatus.error);
      return;
    }
    _myName = myName;
    _roomCode = roomCode;
    _roomName = roomName;
    _emoji = emoji;
    _roomPublic = isPublic;
    _targetEndpointId = targetEndpointId;
    _isHost = roomCode.isEmpty;
    _joined = false;
    _setStatus(RoomStatus.connecting);
    final strategy = Strategy.P2P_STAR;

    if (_isHost) {
      // Anfitrión: anuncia con su metadata; el hub retransmite.
      final ok = await Nearby().startAdvertising(
        _adName(),
        strategy,
        serviceId: kServiceId,
        onConnectionInitiated: _onConnInitiated,
        onConnectionResult: (id, result) {
          if (result != Status.CONNECTED) {
            _endpoints.remove(id);
          }
        },
        onDisconnected: (id) {
          _endpoints.remove(id);
          _events.add(RoomEvent('member_left', {'id': id}));
        },
      );
      if (!ok) {
        _setStatus(RoomStatus.error);
        return;
      }
      // La sala existe desde que se anuncia (paridad con el host LAN).
      _setStatus(RoomStatus.connected);
      _events.add(RoomEvent('room_created', {
        'code': _roomCode,
        'members': [
          {'id': 'host', 'name': _myName}
        ],
        'items': <dynamic>[],
      }));
    } else {
      final ok = await Nearby().startDiscovery(
        _myName,
        strategy,
        serviceId: kServiceId,
        onEndpointFound: (id, name, serviceId2) async {
          if (serviceId2 != kServiceId) return;
          final meta = parseAdName(name);
          if (meta == null) return; // dispositivo ajeno a la app: se ignora
          if (_scanning) {
            _ads.add({
              'via': 'nearby',
              'endpointId': id,
              'code': meta['c'],
              'name': '${meta['n'] ?? ''}',
              'host': '${meta['h'] ?? 'Anfitrión'}',
              'emoji': '${meta['e'] ?? ''}',
              'pub': meta['p'] == 1,
            });
            return;
          }
          if (_joined) return;
          final byTarget = _targetEndpointId != null && id == _targetEndpointId;
          final byCode = '${meta['c']}' == _roomCode;
          if (!byTarget && !byCode) return;
          _joined = true;
          await Nearby().requestConnection(
            _myName,
            id,
            onConnectionInitiated: _onConnInitiated,
            onConnectionResult: (rid, result) {
              if (result == Status.CONNECTED) {
                _setStatus(RoomStatus.connected);
              } else {
                _joined = false;
                _setStatus(RoomStatus.error);
              }
            },
            onDisconnected: (rid) {
              _joined = false;
              _setStatus(RoomStatus.error);
              _events.add(const RoomEvent('room_error', {'reason': 'host_lost'}));
            },
          );
        },
        onEndpointLost: (id) {
          if (id != null && _joined && id == _targetEndpointId) {
            _setStatus(RoomStatus.error);
            _events.add(const RoomEvent('room_error', {'reason': 'host_lost'}));
          }
        },
      );
      if (!ok) {
        _setStatus(RoomStatus.error);
        return;
      }
    }
  }

  Future<void> _onConnInitiated(String id, ConnectionInfo info) async {
    _endpoints[id] = info.endpointName;
    await Nearby().acceptConnection(
      id,
      onPayLoadRecieved: (endid, payload) async {
        if (payload.type != PayloadType.BYTES) return;
        final text = String.fromCharCodes(payload.bytes as Uint8List);
        try {
          final m = Map<String, dynamic>.from(jsonDecode(text) as Map);
          m['fromId'] = endid; // el anfitrión usa este id para responder 1:1
          _events.add(RoomEvent.fromMap(m));
        } catch (_) {/* línea corrupta: se descarta */}
      },
    );
  }

  /// Escaneo de salas públicas cercanas (sin unirse). Los anuncios llegan
  /// por [roomAds]. No corre durante una sala activa.
  Future<bool> startScan() async {
    if (_scanning) return true;
    if (_status != RoomStatus.disconnected) return false;
    _scanning = true;
    final ok = await Nearby().startDiscovery(
      'VALORAVE',
      Strategy.P2P_STAR,
      serviceId: kServiceId,
      onEndpointFound: (id, name, serviceId2) {
        if (serviceId2 != kServiceId) return;
        final meta = parseAdName(name);
        if (meta == null) return; // solo endpoints que responden a la app
        _ads.add({
          'via': 'nearby',
          'endpointId': id,
          'code': meta['c'],
          'name': '${meta['n'] ?? ''}',
          'host': '${meta['h'] ?? 'Anfitrión'}',
          'emoji': '${meta['e'] ?? ''}',
          'pub': meta['p'] == 1,
        });
      },
      onEndpointLost: (_) {},
    );
    if (!ok) _scanning = false;
    return ok;
  }

  Future<void> stopScan() async {
    if (!_scanning) return;
    _scanning = false;
    try {
      await Nearby().stopDiscovery();
    } catch (_) {}
  }

  /// Emite al anfitrión (invitado) o a todos (anfitrión-hub retransmite).
  Future<Map<String, dynamic>?> emit(String type, Map<String, dynamic> payload) async {
    final msg = jsonEncode({'type': type, ...payload});
    final bytes = Uint8List.fromList(utf8.encode(msg));
    for (final id in _endpoints.keys) {
      try {
        await Nearby().sendBytesPayload(id, bytes);
      } catch (_) {}
    }
    return {'type': 'ok'};
  }

  /// Emisión 1:1 (solo tiene efecto en el anfitrión).
  Future<Map<String, dynamic>?> emitTo(String targetId, String type, Map<String, dynamic> payload) async {
    if (!_isHost) return emit(type, payload);
    if (!_endpoints.containsKey(targetId)) return null;
    try {
      await Nearby().sendBytesPayload(
          targetId, Uint8List.fromList(utf8.encode(jsonEncode({'type': type, ...payload}))));
    } catch (_) {}
    return {'type': 'ok'};
  }

  Future<void> disconnect() async {
    await Nearby().stopAllEndpoints();
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    _endpoints.clear();
    _scanning = false;
    _joined = false;
    _setStatus(RoomStatus.disconnected);
  }

  Future<List<String>> discover() async => _endpoints.keys.toList();
}
