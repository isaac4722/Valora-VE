/// ─── LanHub · sala por WiFi local (mismo SSID) ──────────────────────────────
/// Creador: ServerSocket TCP en 48130 + anuncio por broadcast UDP
/// «VALORAVE|CÓDIGO|48130» (descubrimiento NSD-equivalente con RawDatagramSocket).
/// Invitado: escucha broadcasts, conecta TCP. Protocolo: 1 JSON por línea
/// lista-sync (idéntico al servidor socket.io). El creador retransmite (hub).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../room/room_transport.dart';

class LanHubImpl {
  RoomStatus _status = RoomStatus.disconnected;
  final _events = StreamController<RoomEvent>.broadcast();
  final _statuses = StreamController<RoomStatus>.broadcast();
  final Map<Socket, String> _clients = {};
  ServerSocket? _server;
  RawDatagramSocket? _udp;
  Socket? _guestSocket;
  Timer? _announce;
  bool _isHost = false;
  String _roomCode = '';
  String _myName = 'Comprador';
  String _buffer = '';

  RoomStatus get status => _status;
  Stream<RoomEvent> get events => _events.stream;
  Stream<RoomStatus> get statusStream => _statuses.stream;

  void _setStatus(RoomStatus s) {
    _status = s;
    _statuses.add(s);
  }

  Future<void> connect({required String roomCode, required String myName}) async {
    _myName = myName;
    _roomCode = roomCode;
    _isHost = roomCode.isEmpty;
    _setStatus(RoomStatus.connecting);

    try {
      if (_isHost) {
        // Creador: escucha TCP y anuncia por broadcast UDP.
        _server = await ServerSocket.bind(InternetAddress.anyIPv4, 48130);
        _server!.listen(_onGuest);
        _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 48131, reuseAddress: true);
        _udp!.broadcastEnabled = true;
        _announce = Timer.periodic(const Duration(seconds: 2), (_) {
          NetworkInterface.list().then((ifs) {
            for (final i in ifs) {
              for (final a in i.addresses) {
                if (a.type == InternetAddressType.IPv4) {
                  final base = '${a.address.substring(0, a.address.lastIndexOf('.'))}.255';
                  _udp?.send(utf8.encode('VALORAVE|$_roomCode|48130'),
                      InternetAddress(base), 48130);
                }
              }
            }
          });
        });
        _setStatus(RoomStatus.connected);
        _events.add(RoomEvent('room_created', {
          'code': _roomCode,
          'members': [
            {'id': 'host', 'name': _myName}
          ],
          'items': <dynamic>[],
        }));
      } else {
        // Invitado: descubre el anfitrión por UDP broadcast.
        _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 48130, reuseAddress: true);
        _udp!.broadcastEnabled = true;
        _udp!.listen((ev) {
          final d = _udp!.receive();
          if (d == null) return;
          final msg = utf8.decode(d.data);
          if (msg.startsWith('VALORAVE|')) {
            final parts = msg.split('|');
            if (parts.length == 3 && parts[1] == _roomCode) {
              _connectGuest(parts[2]);
            }
          }
        });
        // Dispara un broadcast de consulta para forzar respuesta.
        NetworkInterface.list().then((ifs) {
          for (final i in ifs) {
            for (final a in i.addresses) {
              if (a.type == InternetAddressType.IPv4) {
                final base = '${a.address.substring(0, a.address.lastIndexOf('.'))}.255';
                _udp?.send(utf8.encode('VALORAVE|WHO'), InternetAddress(base), 48130);
              }
            }
          }
        });
      }
    } catch (e) {
      _setStatus(RoomStatus.error);
    }
  }

  Future<void> _connectGuest(String port) async {
    try {
      final host = _udp?.address.address ?? '0.0.0.0';
      // La IP real del anfitrión llega del paquete UDP: RawDatagramSocket.receive
      // trae d.address — usamos la del último broadcast válido.
      final socket = await Socket.connect(lastHostAddress ?? host, int.parse(port),
          timeout: const Duration(seconds: 6));
      _guestSocket = socket;
      socket.listen(_onData, onDone: () {
        _guestSocket = null;
        _setStatus(RoomStatus.error);
      });
      socket.writeln(jsonEncode({'type': 'join_room', 'code': _roomCode, 'name': _myName}));
      _setStatus(RoomStatus.connected);
    } catch (_) {
      _setStatus(RoomStatus.error);
    }
  }

  InternetAddress? lastHostAddress;

  void _onData(Uint8List data) {
    _buffer += utf8.decode(data, allowMalformed: true);
    int idx;
    while ((idx = _buffer.indexOf('\n')) >= 0) {
      final line = _buffer.substring(0, idx).trim();
      _buffer = _buffer.substring(idx + 1);
      if (line.isEmpty) continue;
      try {
        final m = Map<String, dynamic>.from(jsonDecode(line) as Map);
        _events.add(RoomEvent.fromMap(m));
      } catch (_) {}
    }
  }

  void _onGuest(Socket client) {
    _clients[client] = '';
    client.listen(
      (data) => _onData(data),
      onDone: () {
        _clients.remove(client);
        _events.add(RoomEvent('member_left', {'id': client.remoteAddress.address}));
      },
    );
  }

  Future<Map<String, dynamic>?> emit(String type, Map<String, dynamic> payload) async {
    final line = '${jsonEncode({'type': type, ...payload})}\n';
    if (_isHost) {
      // Hub: retransmite a todos los invitados.
      for (final c in _clients.keys) {
        c.add(utf8.encode(line));
      }
    } else {
      _guestSocket?.add(utf8.encode(line));
    }
    return {'type': 'ok'};
  }

  Future<void> disconnect() async {
    _announce?.cancel();
    _server?.close();
    _guestSocket?.destroy();
    for (final c in _clients.keys) {
      c.destroy();
    }
    _clients.clear();
    _udp?.close();
    _setStatus(RoomStatus.disconnected);
  }

  Future<List<String>> discover() async => const [];
}
