/// ─── LanHub · sala por WiFi local (mismo SSID, sin internet) ────────────────
/// Creador: ServerSocket TCP en 48130 + anuncio por broadcast UDP cada 2 s
/// «VALORAVE2|{json}» (code, port, name, host, emoji, pub). Las salas
/// PRIVADAS no se anuncian: solo responden a la sonda «VALORAVE2|WHO|CODE».
/// Invitado: escucha broadcasts (o entra por IP:puerto directo) y conecta TCP.
/// Protocolo: 1 JSON por línea, lista-sync idéntico al servidor socket.io;
/// cada línea llega etiquetada con `fromId` («ip:puerto») para que el
/// controlador-anfitrión pueda responder 1:1 con [emitTo] (verificación
/// PIN+emoji, acks de sala) sin tocar al resto de invitados.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../room/room_transport.dart';

class LanHubImpl {
  /// TCP de la sala (el host escucha aquí) y UDP donde escuchan los invitados.
  static const int kTcpPort = 48130;

  /// UDP donde anuncia/escucha el anfitrión (y responde sondas WHO).
  static const int kUdpPort = 48131;
  static const String kAdPrefix = 'VALORAVE2|';
  static const String kWho = 'VALORAVE2|WHO';
  static const String kLegacyAdPrefix = 'VALORAVE|';

  RoomStatus _status = RoomStatus.disconnected;
  final _events = StreamController<RoomEvent>.broadcast();
  final _statuses = StreamController<RoomStatus>.broadcast();
  final _ads = StreamController<Map<String, dynamic>>.broadcast();

  /// Anfitrión: fromId («ip:puerto») → socket. Buffer parcial por cliente.
  final Map<String, Socket> _clients = {};
  final Map<String, String> _buffers = {};
  ServerSocket? _server;
  RawDatagramSocket? _udp; // host: 48131 · invitado: 48130 (escucha pasiva)
  RawDatagramSocket? _scanSocket; // efímero: sondas WHO y respuestas
  Socket? _guestSocket;
  String _guestBuffer = '';
  Timer? _announce;
  Timer? _probe;
  bool _isHost = false;
  bool _joining = false;
  bool _scanning = false;
  String _roomCode = '';
  String _myName = 'Comprador';
  String _roomName = '';
  String _emoji = '';
  bool _roomPublic = true;
  String? _hostIp;

  RoomStatus get status => _status;
  Stream<RoomEvent> get events => _events.stream;
  Stream<RoomStatus> get statusStream => _statuses.stream;

  /// Anuncios de salas vistas (escaneo): {via, code, ip, port, name, host,
  /// emoji, pub}. Solo el consumidor (RoomController) filtra privadas.
  Stream<Map<String, dynamic>> get roomAds => _ads.stream;

  bool get isHost => _isHost;

  /// IP local del anfitrión (primera IPv4 de sitio), para «usar este teléfono
  /// como servidor» y el QR de la sala.
  static Future<String?> localIPv4() async {
    try {
      final ifs = await NetworkInterface.list();
      for (final i in ifs) {
        for (final a in i.addresses) {
          if (a.type == InternetAddressType.IPv4 && !a.isLoopback) return a.address;
        }
      }
    } catch (_) {}
    return null;
  }

  String? get hostIp => _hostIp;

  void _setStatus(RoomStatus s) {
    _status = s;
    _statuses.add(s);
  }

  static Future<List<String>> _broadcastAddrs() async {
    final out = <String>{'255.255.255.255'};
    try {
      final ifs = await NetworkInterface.list();
      for (final i in ifs) {
        for (final a in i.addresses) {
          if (a.type == InternetAddressType.IPv4 && !a.isLoopback) {
            final base = a.address.substring(0, a.address.lastIndexOf('.'));
            out.add('$base.255');
          }
        }
      }
    } catch (_) {}
    return out.toList();
  }

  /// Conecta como anfitrión (roomCode vacío) o invitado por código. El
  /// invitado descubre al anfitrión por broadcast/sondas; para entrar directo
  /// usa [connectToHost].
  Future<void> connect({
    required String roomCode,
    required String myName,
    String roomName = '',
    String emoji = '',
    bool isPublic = true,
  }) async {
    _myName = myName;
    _roomCode = roomCode;
    _roomName = roomName;
    _emoji = emoji;
    _roomPublic = isPublic;
    _isHost = roomCode.isEmpty;
    _setStatus(RoomStatus.connecting);
    try {
      if (_isHost) {
        await _startHost();
      } else {
        await _startGuestDiscovery();
        _startProbes(_kWhoRoom);
      }
    } catch (_) {
      _setStatus(RoomStatus.error);
    }
  }

  String get _kWhoRoom => '$kWho|$_roomCode';

  /// Unión directa por IP:puerto (desde el panel «entrar por IP» o un
  /// resultado del escaneo) — sin esperar broadcasts.
  Future<bool> connectToHost({
    required String host,
    required int port,
    required String roomCode,
    required String myName,
  }) async {
    _myName = myName;
    _roomCode = roomCode;
    _isHost = false;
    _setStatus(RoomStatus.connecting);
    try {
      await _connectGuest(host, '$port');
      return _status == RoomStatus.connected;
    } catch (_) {
      return false;
    }
  }

  // ── Anfitrión: TCP + anuncios UDP ─────────────────────────────────────────

  Future<void> _startHost() async {
    _server = await ServerSocket.bind(InternetAddress.anyIPv4, kTcpPort);
    _server!.listen(_onGuest, onError: (_) {});
    _hostIp = await localIPv4();
    _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, kUdpPort, reuseAddress: true);
    _udp!.broadcastEnabled = true;
    _udp!.listen((_) => _pumpUdp(_udp));
    _announce = Timer.periodic(const Duration(seconds: 2), (_) => _announceRoom());
    _setStatus(RoomStatus.connected);
    _events.add(RoomEvent('room_created', {
      'code': _roomCode,
      'members': [
        {'id': 'host', 'name': _myName}
      ],
      'items': <dynamic>[],
    }));
  }

  Map<String, dynamic> get _adPayload => {
        'code': _roomCode,
        'port': kTcpPort,
        'name': _roomName,
        'host': _myName,
        'emoji': _emoji,
        'pub': _roomPublic ? 1 : 0,
      };

  Future<void> _announceRoom() async {
    if (_udp == null || !_roomPublic) return; // privadas: solo respuesta a WHO|CODE
    final line = '$kAdPrefix${jsonEncode(_adPayload)}';
    final bytes = utf8.encode(line);
    for (final b in await _broadcastAddrs()) {
      try {
        _udp?.send(bytes, InternetAddress(b), kTcpPort);
      } catch (_) {}
    }
  }

  /// Sondas WHO del invitado (descubrimiento activo) — el anfitrión responde
  /// unicast con su anuncio si la sala es pública o si el código coincide.
  void _startProbes(String who) {
    _probe?.cancel();
    _probe = Timer.periodic(const Duration(seconds: 3), (_) async {
      if (_scanning) return; // el escaneo tiene su propio socket
      final socket = _scanSocket;
      if (socket == null) return;
      for (final b in await _broadcastAddrs()) {
        try {
          socket.send(utf8.encode(who), InternetAddress(b), kUdpPort);
        } catch (_) {}
      }
    });
  }

  void _onUdpHostPacket(Datagram d) {
    final msg = utf8.decode(d.data, allowMalformed: true).trim();
    if (msg == kWho) {
      if (_roomPublic) _udp?.send(utf8.encode('$kAdPrefix${jsonEncode(_adPayload)}'), d.address, d.port);
    } else if (msg.startsWith('$kWho|')) {
      // WHO|CODE: responde también a salas privadas si el código coincide.
      if (msg.substring(kWho.length + 1) == _roomCode) {
        _udp?.send(utf8.encode('$kAdPrefix${jsonEncode(_adPayload)}'), d.address, d.port);
      }
    }
  }

  // ── Invitado: descubrimiento + TCP ────────────────────────────────────────

  Future<void> _startGuestDiscovery() async {
    if (_udp == null) {
      _udp = await RawDatagramSocket.bind(InternetAddress.anyIPv4, kTcpPort, reuseAddress: true);
      _udp!.broadcastEnabled = true;
      _udp!.listen((_) => _pumpUdp(_udp));
    }
    if (_scanSocket == null) {
      // Socket efímero: las respuestas WHO llegan aquí (evita la ambigüedad
      // del puerto fijo compartido entre varios invitados).
      _scanSocket = await RawDatagramSocket.bind(InternetAddress.anyIPv4, 0);
      _scanSocket!.broadcastEnabled = true;
      _scanSocket!.listen((_) => _pumpUdp(_scanSocket));
    }
  }

  void _pumpUdp(RawDatagramSocket? socket) {
    final d = socket?.receive();
    if (d == null) return;
    if (_isHost) {
      _onUdpHostPacket(d);
      return;
    }
    final ad = _adFrom(d);
    if (ad == null) return;
    if (_scanning) {
      _ads.add(ad);
      return;
    }
    if (ad['code'] == _roomCode) {
      _connectGuest('${ad['ip']}', '${ad['port']}');
    }
  }

  Map<String, dynamic>? _adFrom(Datagram d) {
    final ad = parseAd(utf8.decode(d.data, allowMalformed: true));
    if (ad == null) return null;
    ad['ip'] = d.address.address;
    ad['via'] = 'lan';
    return ad;
  }

  /// Parsea «VALORAVE2|{json}» y el formato viejo «VALORAVE|code|port».
  /// null = no es un anuncio de la app.
  static Map<String, dynamic>? parseAd(String raw) {
    raw = raw.trim();
    try {
      if (raw.startsWith(kAdPrefix)) {
        final m = jsonDecode(raw.substring(kAdPrefix.length));
        if (m is Map && m['code'] is String && (m['code'] as String).length >= 4) {
          return {
            'code': m['code'],
            'port': (m['port'] as num?)?.toInt() ?? kTcpPort,
            'name': '${m['name'] ?? ''}',
            'host': '${m['host'] ?? 'Anfitrión'}',
            'emoji': '${m['emoji'] ?? ''}',
            'pub': m['pub'] == 1 || m['pub'] == true || m['pub'] == '1',
          };
        }
        return null;
      }
      if (raw.startsWith(kLegacyAdPrefix)) {
        final p = raw.substring(kLegacyAdPrefix.length).split('|');
        if (p.length >= 2) {
          return {
            'code': p[0],
            'port': int.tryParse(p[1]) ?? kTcpPort,
            'name': '',
            'host': 'Anfitrión',
            'emoji': '',
            'pub': true,
          };
        }
      }
    } catch (_) {}
    return null;
  }

  Future<void> _connectGuest(String ip, String port) async {
    if (_joining || _guestSocket != null) return;
    _joining = true;
    try {
      final socket = await Socket.connect(ip, int.tryParse(port) ?? kTcpPort,
          timeout: const Duration(seconds: 6));
      _guestSocket = socket;
      socket.listen(_onGuestData, onError: (_) {}, onDone: () {
        _guestSocket = null;
        _setStatus(RoomStatus.error);
      });
      _setStatus(RoomStatus.connected);
    } catch (_) {
      _setStatus(RoomStatus.error);
    } finally {
      _joining = false;
    }
  }

  void _onGuestData(Uint8List data) {
    _guestBuffer += utf8.decode(data, allowMalformed: true);
    int idx;
    while ((idx = _guestBuffer.indexOf('\n')) >= 0) {
      final line = _guestBuffer.substring(0, idx).trim();
      _guestBuffer = _guestBuffer.substring(idx + 1);
      if (line.isEmpty) continue;
      try {
        final m = Map<String, dynamic>.from(jsonDecode(line) as Map);
        _events.add(RoomEvent.fromMap(m));
      } catch (_) {/* línea corrupta: se descarta */}
    }
  }

  // ── Escaneo de salas (sin unirse) ─────────────────────────────────────────

  /// Escucha pasiva + sondas WHO. Los anuncios llegan por [roomAds].
  Future<bool> startScan() async {
    if (_scanning) return true;
    if (_status != RoomStatus.disconnected) return false; // no se escanea en sala activa
    _scanning = true;
    try {
      await _startGuestDiscovery();
      for (final b in await _broadcastAddrs()) {
        try {
          _scanSocket?.send(utf8.encode(kWho), InternetAddress(b), kUdpPort);
        } catch (_) {}
      }
      _probe?.cancel();
      _probe = Timer.periodic(const Duration(seconds: 3), (_) async {
        if (!_scanning) return;
        for (final b in await _broadcastAddrs()) {
          try {
            _scanSocket?.send(utf8.encode(kWho), InternetAddress(b), kUdpPort);
          } catch (_) {}
        }
      });
      return true;
    } catch (_) {
      _scanning = false;
      return false;
    }
  }

  Future<void> stopScan() async {
    _scanning = false;
    _probe?.cancel();
    _probe = null;
    try {
      _scanSocket?.close();
    } catch (_) {}
    _scanSocket = null;
  }

  // ── Anfitrión: TCP por cliente ────────────────────────────────────────────

  void _onGuest(Socket client) {
    final id = '${client.remoteAddress.address}:${client.remotePort}';
    _clients[id] = client;
    _buffers[id] = '';
    client.listen(
      (data) => _onHostData(id, data),
      onError: (_) => _dropClient(id),
      onDone: () => _dropClient(id),
    );
  }

  void _dropClient(String id) {
    final s = _clients.remove(id);
    _buffers.remove(id);
    try {
      s?.destroy();
    } catch (_) {}
    if (s != null) _events.add(RoomEvent('member_left', {'id': id}));
  }

  void _onHostData(String id, Uint8List data) {
    _buffers[id] = (_buffers[id] ?? '') + utf8.decode(data, allowMalformed: true);
    int idx;
    while ((idx = _buffers[id]!.indexOf('\n')) >= 0) {
      final line = _buffers[id]!.substring(0, idx).trim();
      _buffers[id] = _buffers[id]!.substring(idx + 1);
      if (line.isEmpty) continue;
      try {
        final m = Map<String, dynamic>.from(jsonDecode(line) as Map);
        m['fromId'] = id;
        _events.add(RoomEvent.fromMap(m));
      } catch (_) {}
    }
  }

  // ── Emisión ───────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>?> emit(String type, Map<String, dynamic> payload) async {
    final bytes = utf8.encode('${jsonEncode({'type': type, ...payload})}\n');
    if (_isHost) {
      for (final c in _clients.values) {
        try {
          c.add(bytes);
        } catch (_) {}
      }
    } else {
      _guestSocket?.add(bytes);
    }
    return {'type': 'ok'};
  }

  /// Emisión 1:1 (solo tiene efecto en el anfitrión). El invitado cae al
  /// broadcast normal (su único par es el anfitrión).
  Future<Map<String, dynamic>?> emitTo(String targetId, String type, Map<String, dynamic> payload) async {
    if (!_isHost) return emit(type, payload);
    final c = _clients[targetId];
    if (c == null) return null;
    try {
      c.add(utf8.encode('${jsonEncode({'type': type, ...payload})}\n'));
    } catch (_) {}
    return {'type': 'ok'};
  }

  Future<void> disconnect() async {
    _announce?.cancel();
    _announce = null;
    await stopScan();
    _probe?.cancel();
    _probe = null;
    try {
      _server?.close();
    } catch (_) {}
    _server = null;
    try {
      _guestSocket?.destroy();
    } catch (_) {}
    _guestSocket = null;
    for (final c in _clients.values) {
      try {
        c.destroy();
      } catch (_) {}
    }
    _clients.clear();
    _buffers.clear();
    try {
      _udp?.close();
    } catch (_) {}
    _udp = null;
    _hostIp = null;
    _isHost = false;
    _setStatus(RoomStatus.disconnected);
  }

  /// Códigos vistos recientemente (contrato discover()).
  Future<List<String>> discover() async => const [];
}
