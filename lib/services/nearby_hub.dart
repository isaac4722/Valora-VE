/// ─── NearbyHub · Google Nearby Connections (WiFi-Direct/BT/BLE, P2P_STAR) ──
/// Creador de sala = anfitrión (advertise) que retransmite (hub); invitados
/// hacen discover+requestConnection. El protocolo lista-sync viaja como
/// payloads de bytes JSON 1:1 igual que el servidor socket.io.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:nearby_connections/nearby_connections.dart';

import '../room/room_transport.dart';

class NearbyHubImpl {
  RoomStatus _status = RoomStatus.disconnected;
  final _events = StreamController<RoomEvent>.broadcast();
  final _statuses = StreamController<RoomStatus>.broadcast();
  final Map<String, String> _endpoints = {}; // endpointId → nombre
  bool _isHost = false;
  String _myName = 'Comprador';
  String _roomCode = '';

  RoomStatus get status => _status;
  Stream<RoomEvent> get events => _events.stream;
  Stream<RoomStatus> get statusStream => _statuses.stream;

  void _setStatus(RoomStatus s) {
    _status = s;
    _statuses.add(s);
  }

  Future<bool> _granted() async {
    // permisos: BLUETOOTH_SCAN/ADVERTISE/CONNECT (31+), FINE_LOCATION (<31),
    // NEARBY_WIFI_DEVICES (33+) — gestionados por permission_handler en la app.
    return true;
  }

  Future<void> connect({required String roomCode, required String myName}) async {
    if (!await _granted()) {
      _setStatus(RoomStatus.error);
      return;
    }
    _myName = myName;
    _roomCode = roomCode;
    _isHost = roomCode.isEmpty;
    _setStatus(RoomStatus.connecting);
    final strategy = Strategy.P2P_STAR;

    if (_isHost) {
      // Anfitrión: anuncia con su nombre; el «código» es su endpointName.
      final ok = await Nearby().startAdvertising(
        'VALORAVE',
        strategy,
        serviceId: 've.valorave.listasync',
        onConnectionInitiated: _onConnInitiated,
        onConnectionResult: (id, result) {
          if (result == Status.CONNECTED) {
            if (_status != RoomStatus.connected) {
              _setStatus(RoomStatus.connected);
              // room_created local: el anfitrión ya tiene su estado.
              _events.add(RoomEvent('room_created', {
                'code': _roomCode,
                'members': [
                  {'id': 'host', 'name': _myName}
                ],
                'items': <dynamic>[],
              }));
            }
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
    } else {
      // Invitado: descubre anfitriones y conecta al primero que hable de la sala.
      final ok = await Nearby().startDiscovery(
        'VALORAVE',
        strategy,
        serviceId: 've.valorave.listasync',
        onEndpointFound: (id, name, serviceId2) async {
          await Nearby().requestConnection(
            _myName,
            id,
            onConnectionInitiated: _onConnInitiated,
            onConnectionResult: (rid, result) {
              if (result == Status.CONNECTED) {
                _setStatus(RoomStatus.connected);
              }
            },
            onDisconnected: (rid) {
              _setStatus(RoomStatus.error);
            },
          );
        },
        onEndpointLost: (id) {
          if (id != null) {
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
          _events.add(RoomEvent.fromMap(m));
        } catch (_) {/* línea corrupta: se descarta */}
      },
    );
  }

  /// Emite al anfitrión (invitado) o a todos (anfitrión-hub retransmite).
  Future<Map<String, dynamic>?> emit(String type, Map<String, dynamic> payload) async {
    final msg = jsonEncode({'type': type, ...payload});
    final bytes = Uint8List.fromList(utf8.encode(msg));
    for (final id in _endpoints.keys) {
      await Nearby().sendBytesPayload(id, bytes);
    }
    return {'type': 'ok'};
  }

  Future<void> disconnect() async {
    await Nearby().stopAllEndpoints();
    await Nearby().stopAdvertising();
    await Nearby().stopDiscovery();
    _endpoints.clear();
    _setStatus(RoomStatus.disconnected);
  }

  Future<List<String>> discover() async => _endpoints.keys.toList();
}
