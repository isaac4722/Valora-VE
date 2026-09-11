/// ─── RoomTransport · interfaz común de la sala (decisión §4.10) ─────────────
/// Tres caminos con el MISMO protocolo lista-sync (MVP §6):
///  a) SocketIoTransport — servidor socket.io con host:puerto configurado
///     por el usuario (server/lista-sync/ listo para desplegar).
///  b) NearbyTransport — Google Nearby Connections (WiFi-Direct/BT/BLE,
///     P2P_STAR) vía nearby_connections: sin internet.
///  c) LanTransport — mismo WiFi: broadcast UDP (descubrimiento) + TCP.
/// El protocolo es idéntico; solo cambia cómo viajan los bytes.
///
/// v1.1.0 (sala P2P completa): verificación PIN+emoji (RoomPairing) en los
/// caminos directos, anfitrión-hub que retransmite y sincroniza su lista
/// (room_joined con items), presencia/typing locales cuando no hay server,
/// diff del store → item_* con outbox, escaneo de salas cercanas (RoomAd)
/// y servidor propio: «usar este teléfono como servidor» = host LAN.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as sio;

import '../core/models.dart';
import '../data/store.dart';
import '../services/lan_hub.dart';
import '../services/nearby_hub.dart';

export '../services/lan_hub.dart' show LanHubImpl;
export '../services/nearby_hub.dart' show NearbyHubImpl;

/// Evento normalizado del protocolo lista-sync (SIN acoplarse al transporte).
/// Los hubs directos añaden `fromId` («ip:puerto» / endpointId de Nearby) al
/// payload de lo que emite cada par — el anfitrión lo usa para responder 1:1.
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

  /// Emisión 1:1 a un par concreto (verificación PIN, acks del anfitrión).
  /// Default: broadcast (el servidor socket.io enruta solo).
  Future<Map<String, dynamic>?> emitTo(String targetId, String type, Map<String, dynamic> payload) =>
      emit(type, payload);
}

/// ─── (a) Servidor socket.io (host:puerto del usuario) ───────────────────────
class SocketIoTransport extends RoomTransport {
  SocketIoTransport({required this.serverUrl});

  final String serverUrl;
  sio.Socket? _socket;
  RoomStatus _status = RoomStatus.disconnected;
  final _events = StreamController<RoomEvent>.broadcast();
  final _statuses = StreamController<RoomStatus>.broadcast();

  /// Ack de create_room/join_room que produjo esta conexión (el server
  /// responde {type, code, members, items}) — el controlador lo consume.
  Map<String, dynamic>? lastAck;

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
  Future<void> connect({
    required String roomCode,
    required String myName,
    String roomName = '',
    bool isPublic = true,
  }) async {
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

    // create_room o join_room con ack (§6). roomName/isPublic viajan como
    // extras: el server de referencia los ignora; uno futuro los aplicará.
    final isNew = roomCode.isEmpty;
    final ack = await emit(
        isNew ? 'create_room' : 'join_room',
        isNew
            ? {'name': myName, 'roomName': roomName, 'isPublic': isPublic}
            : {'code': roomCode, 'name': myName});
    if (ack != null && (ack['type'] == 'room_created' || ack['type'] == 'room_joined')) {
      lastAck = ack;
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

  /// Prueba de conexión: abre el websocket (6 s máx) y cierra. null = OK.
  Future<String?> probe() async {
    _setStatus(RoomStatus.connecting);
    final done = Completer<String?>();
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
        if (!done.isCompleted) done.complete(null);
      })
      ..onConnectError((e) {
        if (!done.isCompleted) done.complete('No se pudo conectar');
      });
    final res = await done.future.timeout(const Duration(seconds: 6),
        onTimeout: () => 'Sin respuesta en 6 s');
    await disconnect();
    return res;
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
  Future<void> connect({
    required String roomCode,
    required String myName,
    String roomName = '',
    String emoji = '',
    bool isPublic = true,
    String? targetEndpointId,
  }) =>
      hub.connect(
        roomCode: roomCode,
        myName: myName,
        roomName: roomName,
        emoji: emoji,
        isPublic: isPublic,
        targetEndpointId: targetEndpointId,
      );

  @override
  Future<Map<String, dynamic>?> emit(String type, Map<String, dynamic> payload) =>
      hub.emit(type, payload);

  @override
  Future<Map<String, dynamic>?> emitTo(String targetId, String type, Map<String, dynamic> payload) =>
      hub.emitTo(targetId, type, payload);

  @override
  Future<void> disconnect() => hub.disconnect();

  @override
  Future<List<String>> discover() => hub.discover();
}

/// ─── (c) WiFi LAN: mismo SSID — broadcast UDP (descubrimiento) + TCP ────────
/// El creador escucha en el puerto 48130 y anuncia por broadcast; las salas
/// privadas solo responden a la sonda «VALORAVE2|WHO|CÓDIGO». Invitados:
/// escuchan, sondean o entran por IP:puerto directo y conectan TCP.
/// Protocolo: líneas JSON lista-sync idénticas al servidor. Hub en
/// services/lan_hub.dart.
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
  Future<void> connect({
    required String roomCode,
    required String myName,
    String roomName = '',
    String emoji = '',
    bool isPublic = true,
  }) =>
      hub.connect(
        roomCode: roomCode,
        myName: myName,
        roomName: roomName,
        emoji: emoji,
        isPublic: isPublic,
      );

  /// Unión directa por IP:puerto (sin esperar el broadcast).
  Future<bool> connectDirect({
    required String host,
    required int port,
    required String roomCode,
    required String myName,
  }) =>
      hub.connectToHost(
        host: host,
        port: port,
        roomCode: roomCode,
        myName: myName,
      );

  @override
  Future<Map<String, dynamic>?> emit(String type, Map<String, dynamic> payload) =>
      hub.emit(type, payload);

  @override
  Future<Map<String, dynamic>?> emitTo(String targetId, String type, Map<String, dynamic> payload) =>
      hub.emitTo(targetId, type, payload);

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
        'room_full' => 'La sala está llena (10 personas)',
        'too_large' => 'El mensaje pesa más de 16 KB',
        'bad_item' => 'Ítem inválido',
        'bad_update' => 'Cambio inválido',
        'bad_remove' => 'No se puede quitar ese ítem',
        'bad_items' => 'Lista inválida',
        'list_full' => 'La sala llegó a 120 ítems',
        'not_in_room' => 'No estás en ninguna sala',
        'bad_pin' => 'PIN o emoji incorrecto — se canceló la conexión',
        'host_lost' => 'Se perdió al anfitrión',
        _ => 'Error: $reason',
      };
}

/// ─── Verificación PIN + emoji (caminos directos) ────────────────────────────
/// El anfitrión genera un PIN de 4 dígitos y un animal de la lista fija y los
/// comparte de palabra/con pantalla. El invitado debe escribir el PIN y
/// elegir el emoji que coincide; si no coincide, el anfitrión rechaza SOLO a
/// ese par (room_error bad_pin) y el invitado corta su conexión sin tocar al
/// resto. En modo Servidor la verificación la aplicaría el server (el server
/// de referencia aún no la trae: la sala queda protegida por su código).
class RoomPairing {
  const RoomPairing._();

  /// Máximo de miembros de los caminos directos (el #11 es rechazado con
  /// room_full; el server de referencia aplica su propio tope de 8).
  static const int maxMembers = 10;

  static const List<String> emojis = ['🐆', '🦜', '🐬', '🦊', '🐢', '🐝', '🦋', '🐳'];

  /// PIN de 4 dígitos (1000–9999) con Random.secure.
  static String newPin() {
    final rnd = Random.secure();
    return '${1000 + rnd.nextInt(9000)}';
  }

  static String randomEmoji() => emojis[Random.secure().nextInt(emojis.length)];
}

/// ─── Sala pública avistada cerca (escaneo Nearby + UDP LAN) ─────────────────
class RoomAd {
  const RoomAd({
    required this.mode,
    required this.code,
    required this.roomName,
    required this.hostName,
    required this.emoji,
    required this.isPublic,
    required this.seen,
    this.host = '',
    this.port = LanHubImpl.kTcpPort,
    this.endpointId = '',
  });

  final String mode; // 'nearby' | 'lan'
  final String code;
  final String roomName;
  final String hostName;
  final String emoji;
  final bool isPublic;
  final String host; // LAN: IP del anfitrión
  final int port; // LAN: puerto TCP
  final String endpointId; // Nearby: para requestConnection directo
  final DateTime seen;

  String get key => '$mode-$code';
  bool get stale => DateTime.now().difference(seen) > const Duration(seconds: 18);

  String get label => roomName.isNotEmpty
      ? roomName
      : (hostName.isNotEmpty ? hostName : 'Sala $code');
}

/// ─── Controlador de la sala para la UI ──────────────────────────────────────
/// Estado + guard baseline+suppress (los remotos llegan por applyRemoteRoomEvent
/// del store y NUNCA se re-emitir) + outbox offline + diff del store → item_*.
/// Cuando el transporte es directo (LAN/Nearby), el anfitrión hace de server:
/// responde join_room con el reto room_verify, valida PIN+emoji, entrega su
/// lista en room_joined, retransmite las operaciones y calcula presencia.
class RoomController extends ChangeNotifier {
  RoomController(this._store);

  final AppStore _store;
  RoomTransport? _transport;
  RoomStatus _status = RoomStatus.disconnected;
  String _code = '';
  String _myName = 'Comprador';
  String _mode = 'server'; // server | nearby | lan | bt
  final List<RoomMember> _members = [];

  bool _isHost = false;
  String _roomName = '';
  bool _isPublic = true;
  String _pin = '';
  String _emoji = RoomPairing.emojis.first;
  final Map<String, String> _pendingVerify = {}; // parId → nombre (host)
  bool _needsPairing = false; // invitado: esperando entrada de PIN+emoji
  bool _verifying = false; // invitado: PIN enviado, esperando respuesta
  String? _pairingError;
  String? _lastError;

  // Presencia local (host directo) — mismos umbrales del server de referencia.
  static const int _staleMs = 35000;
  static const int _typingMs = 3000;
  final Map<String, int> _lastSeenMs = {};
  final Map<String, int> _typingUntilMs = {};
  String _presenceSig = '';
  String _typingSig = '';

  // Diff del store → item_* (guard contra ecos remotos).
  List<Map<String, dynamic>> _snapshot = const [];
  bool _suppress = false;

  // Escaneo de salas cercanas.
  final List<RoomAd> _foundRooms = [];
  bool _scanning = false;
  LanHubImpl? _lanScanner;
  NearbyHubImpl? _nearScanner;
  StreamSubscription<Map<String, dynamic>>? _lanAdSub;
  StreamSubscription<Map<String, dynamic>>? _nearAdSub;
  Timer? _scanTimer;

  Timer? _pingTimer;
  Timer? _scanTimerPresence;
  Timer? _verifyTimer;
  StreamSubscription<RoomEvent>? _sub;
  StreamSubscription<RoomStatus>? _statusSub;

  RoomStatus get status => _status;
  String get code => _code;
  String get myName => _myName;
  String get mode => _mode;
  bool get connected => _status == RoomStatus.connected;
  List<RoomMember> get members => List.unmodifiable(_members);
  bool get isHost => _isHost;
  String get roomName => _roomName;
  bool get isPublic => _isPublic;
  String get pin => _pin;
  String get emoji => _emoji;
  bool get needsPairing => _needsPairing;
  bool get verifying => _verifying;
  String? get pairingError => _pairingError;
  String? get lastError => _lastError;
  bool get scanning => _scanning;
  List<RoomAd> get foundRooms => List.unmodifiable(_foundRooms);
  List<String> get pendingNames => List.unmodifiable(_pendingVerify.values);

  /// Etiqueta humana del modo activo.
  String get modeLabel => switch (_mode) {
        'server' => 'Servidor',
        'nearby' => 'Cerca',
        'lan' => 'WiFi local',
        'bt' => 'Bluetooth',
        _ => _mode,
      };

  void setMode(String m) {
    _mode = m;
    notifyListeners();
  }

  /// Nombre del participante (lobby). Vacío → «Comprador N» por defecto.
  void setMyName(String v) {
    final t = v.trim();
    _myName = t.isEmpty ? 'Comprador' : (t.length > 24 ? t.substring(0, 24) : t);
    notifyListeners();
  }

  /// Nombre de la sala que se crea (host).
  void setRoomName(String v) {
    _roomName = v.trim().length > 32 ? v.trim().substring(0, 32) : v.trim();
    notifyListeners();
  }

  /// Pública (aparece en descubrimiento) o privada (solo por código).
  void setPublic(bool v) {
    _isPublic = v;
    notifyListeners();
  }

  void setServerUrl(String url) => _store.prefs?.setString('valorave.liveServerUrl', url);
  String get serverUrl => _store.prefs?.getString('valorave.liveServerUrl') ?? '';

  // ── Config del servidor propio (host:puerto + token opcional) ────────────

  void setServerAddress(String v) => _store.prefs?.setString('valorave.liveServerAddr', v);
  String get serverAddress => _store.prefs?.getString('valorave.liveServerAddr') ?? '';

  void setServerToken(String v) => _store.prefs?.setString('valorave.liveServerToken', v);
  String get serverToken => _store.prefs?.getString('valorave.liveServerToken') ?? '';

  /// URL final: «host:puerto» → http://host:puerto (token por query; el
  /// server de referencia lo ignora). Compat: si solo hay la clave vieja
  /// (URL completa de Ajustes), se usa tal cual.
  String? resolveServerUrl() {
    final addr = serverAddress.trim();
    if (addr.isNotEmpty) {
      final withScheme = addr.contains('://') ? addr : 'http://$addr';
      final token = serverToken.trim();
      return token.isEmpty ? withScheme : '$withScheme?token=${Uri.encodeQueryComponent(token)}';
    }
    return serverUrl;
  }

  /// Prueba la conexión del server configurado. null = OK.
  Future<String?> probeServer() async {
    final url = resolveServerUrl();
    if (url == null || url.isEmpty) return 'Escribe host:puerto primero';
    final t = SocketIoTransport(serverUrl: url);
    try {
      return await t.probe();
    } catch (e) {
      return 'Sin conexión: $e';
    }
  }

  /// «Usar este teléfono como servidor»: IP:puerto del hub LAN activo.
  String get lanAddress {
    if (_mode != 'lan' || !_isHost) return '';
    final hub = _transport is LanTransport ? (_transport as LanTransport).hub : null;
    final ip = hub?.hostIp;
    return (ip == null || ip.isEmpty) ? '' : '$ip:${LanHubImpl.kTcpPort}';
  }

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;
  String get _myId => (_isHost && _mode != 'server') ? 'host' : 'me';

  // ── Unirse / crear ────────────────────────────────────────────────────────

  /// Crea (code vacío) o se une con código. En los caminos directos el
  /// anfitrión genera código, PIN y emoji; el invitado pasa por la
  /// verificación (room_verify) antes de recibir room_joined.
  Future<String?> join({
    required String name,
    String code = '',
    String? mode,
    String roomName = '',
    bool isPublic = true,
    String? directHost,
    int? directPort,
    String? targetEndpointId,
  }) async {
    if (_status == RoomStatus.connecting) return 'Ya hay una conexión en curso';
    final m = (mode ?? _mode).toLowerCase();
    if (!['server', 'nearby', 'lan', 'bt'].contains(m)) return 'Modo desconocido';
    if (name.trim().isEmpty) return 'Escribe tu nombre';
    // El escaneo debe morir antes de conectar: Nearby no admite discovery
    // doble y el hub LAN cambia de rol.
    await stopScan();

    _myName = RoomProtocol.cleanName(name);
    _mode = m;
    _isHost = code.trim().isEmpty;
    _roomName = roomName.trim();
    _isPublic = isPublic;
    _code = _isHost ? (m == 'server' ? '' : RoomProtocol.newCode()) : code.trim().toUpperCase();
    if (_isHost) {
      _pin = RoomPairing.newPin();
      _emoji = RoomPairing.randomEmoji();
    }
    _pendingVerify.clear();
    _needsPairing = false;
    _verifying = false;
    _pairingError = null;
    _lastError = null;
    _verifyTimer?.cancel();

    final RoomTransport transport;
    switch (m) {
      case 'nearby' || 'bt':
        transport = NearbyTransport(hub: NearbyHubImpl());
      case 'lan':
        transport = LanTransport(hub: LanHubImpl());
      default:
        final url = resolveServerUrl();
        if (url == null || url.isEmpty) {
          return 'Configura el servidor (host:puerto) en esta pantalla';
        }
        transport = SocketIoTransport(serverUrl: url);
    }
    await _teardownTransport();
    _transport = transport;
    _statusSub = transport.statusStream.listen((s) {
      _status = s;
      notifyListeners();
    });
    _sub = transport.events.listen(_onEvent);
    _status = RoomStatus.connecting;
    notifyListeners();

    try {
      if (transport is LanTransport && !_isHost && directHost != null && directHost.trim().isNotEmpty) {
        await transport.connectDirect(
          host: directHost.trim(),
          port: directPort ?? LanHubImpl.kTcpPort,
          roomCode: _code,
          myName: _myName,
        );
      } else if (transport is SocketIoTransport) {
        await transport.connect(
            roomCode: _code, myName: _myName, roomName: _roomName, isPublic: _isPublic);
      } else if (transport is NearbyTransport) {
        await transport.connect(
          roomCode: _code,
          myName: _myName,
          roomName: _roomName,
          emoji: _emoji,
          isPublic: _isPublic,
          targetEndpointId: targetEndpointId,
        );
      } else if (transport is LanTransport) {
        await transport.connect(
          roomCode: _code,
          myName: _myName,
          roomName: _roomName,
          emoji: _emoji,
          isPublic: _isPublic,
        );
      }

      // Espera al enlace (el invitado LAN descubre por UDP: puede tardar).
      final timeout = Duration(
          seconds: switch ((m, _isHost)) {
                ('nearby', false) || ('bt', false) => 25,
                ('lan', false) => 15,
                _ => 8,
              });
      final linked = await _waitForLink(timeout);
      if (!linked) {
        await leave();
        return _isHost ? 'No se pudo crear la sala' : 'No se encontró esa sala';
      }

      if (m == 'server') {
        final ack = transport is SocketIoTransport ? transport.lastAck : null;
        if (ack != null &&
            (ack['type'] == 'room_created' || ack['type'] == 'room_joined')) {
          _code = '${ack['code'] ?? ack['id'] ?? _code}';
          _applyMembers(ack['members']);
          _suppress = true;
          _store.applyRemoteRoomEvent('list_replace', {'items': (ack['items'] as List?) ?? const []});
          _suppress = false;
          _startRoomTimers();
          unawaited(flushOutbox());
        } else {
          await leave();
          return _isHost ? 'El servidor rechazó la sala' : 'No existe esa sala';
        }
      } else if (!_isHost) {
        // Los hubs directos NO envían join_room solos: el reto de verificación
        // llega del anfitrión (room_verify) y después room_joined.
        await transport.emit('join_room', {'code': _code, 'name': _myName});
      } else {
        _snapshot = _sanitizedCart();
      }
      attachStoreListener(); // diff del store → item_* con outbox
      notifyListeners();
      return null;
    } catch (e) {
      await leave();
      return 'Sin conexión: $e';
    }
  }

  /// Espera a que el transporte quede conectado (o error) dentro del plazo.
  Future<bool> _waitForLink(Duration timeout) async {
    if (_status == RoomStatus.connected) return true;
    if (_status == RoomStatus.error) return false;
    final c = Completer<bool>();
    late final StreamSubscription<RoomStatus> sub;
    sub = _transport!.statusStream.listen((s) {
      if (c.isCompleted) return;
      if (s == RoomStatus.connected) {
        c.complete(true);
      } else if (s == RoomStatus.error) {
        c.complete(false);
      }
    });
    final t = Timer(timeout, () {
      if (!c.isCompleted) c.complete(false);
    });
    final r = await c.future;
    await sub.cancel();
    t.cancel();
    return r;
  }

  // ── Timers de sala (ping + presencia local del anfitrión) ─────────────────

  void _startRoomTimers() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 10), (_) {
      if (connected) unawaited(emit('presence_ping', {}));
    });
    if (_isHost && _mode != 'server') {
      _lastSeenMs
        ..clear()
        ..['host'] = _nowMs;
      _typingUntilMs.clear();
      _presenceSig = '';
      _typingSig = '';
      _scanTimerPresence?.cancel();
      _scanTimerPresence = Timer.periodic(const Duration(seconds: 5), (_) => _scanPresence());
    } else {
      _scanTimerPresence?.cancel();
      _scanTimerPresence = null;
    }
  }

  /// Espejo del escáner del server (§6): presencia + «escribiendo…» con
  /// emisión solo al cambiar la firma.
  void _scanPresence() {
    if (!(_isHost && connected && _mode != 'server')) return;
    final now = _nowMs;
    _lastSeenMs['host'] = now;
    final online = <String>['host'];
    for (final m in _members) {
      if (m.id == 'host') continue;
      final t = _lastSeenMs[m.id];
      if (t != null && now - t < _staleMs) online.add(m.id);
    }
    final sig = online.join(',');
    if (sig != _presenceSig) {
      _presenceSig = sig;
      unawaited(emit('presence', {'online': online}));
    }
    final typing = <String>[];
    for (final m in _members) {
      final t = _typingUntilMs[m.id];
      if (t != null && t > now) typing.add(m.name);
    }
    final tsig = typing.join(',');
    if (tsig != _typingSig) {
      _typingSig = tsig;
      unawaited(emit('typing', {'names': typing}));
    }
    _applyPresence(online);
    _applyTyping(typing);
    notifyListeners();
  }

  void _touch(String id) {
    if (id.isEmpty || id == 'host') return;
    _lastSeenMs[id] = _nowMs;
  }

  // ── Eventos entrantes ─────────────────────────────────────────────────────

  /// Guard baseline+suppress: los eventos remotos solo aplican al store.
  void _onEvent(RoomEvent ev) {
    final fromId = '${ev.payload['fromId'] ?? ''}';
    if (fromId.isNotEmpty) _touch(fromId);
    switch (ev.type) {
      case 'room_created' || 'room_joined':
        if (!_isHost) {
          // Invitado directo: el anfitrión entrega el estado completo.
          _code = '${ev.payload['code'] ?? ev.payload['id'] ?? _code}';
          _applyMembers(ev.payload['members']);
          _suppress = true;
          _store.applyRemoteRoomEvent('list_replace', {'items': (ev.payload['items'] as List?) ?? const []});
          _suppress = false;
          _status = RoomStatus.connected;
          _needsPairing = false;
          _verifying = false;
          _pairingError = null;
          _verifyTimer?.cancel();
          _startRoomTimers();
          unawaited(flushOutbox());
        } else {
          // Anfitrión directo: su hub creó la sala localmente.
          _applyMembers(ev.payload['members']);
          _status = RoomStatus.connected;
          _startRoomTimers();
          _snapshot = _sanitizedCart();
        }

      // ── Rol server del anfitrión directo ──
      case 'join_room' when _isHost && _mode != 'server':
        _hostOnJoinRoom(fromId, ev.payload);
      case 'verify' when _isHost && _mode != 'server':
        _hostOnVerify(fromId, ev.payload);
      case 'presence_ping' when _isHost && _mode != 'server':
        _touch(fromId);

      // ── Invitado: reto de verificación ──
      case 'room_verify':
        if (!_isHost) {
          _needsPairing = true;
          _verifying = false;
        }

      case 'presence':
        _applyPresence(((ev.payload['online'] as List?) ?? const []).map((e) => '$e').toList());
      case 'typing':
        _applyTyping(((ev.payload['names'] as List?) ?? const []).map((e) => '$e').toList());
        if (_isHost && _mode != 'server' && fromId.isNotEmpty) {
          _typingUntilMs[fromId] = _nowMs + _typingMs;
          _scanPresence(); // como el server: escanea en caliente (<1 s)
        }

      case 'item_add' ||
            'item_update' ||
            'item_remove' ||
            'list_clear' ||
            'list_replace':
        _suppress = true;
        _store.applyRemoteRoomEvent(ev.type, ev.payload);
        _suppress = false;
        // El anfitrión directo retransmite al resto (el server lo hace solo).
        if (_isHost && _mode != 'server' && fromId.isNotEmpty) {
          _relayToOthers(ev.type, ev.payload, fromId);
        }

      case 'member_joined':
        final m = ev.payload['member'];
        if (m is Map) {
          final mm = Map<String, dynamic>.from(m);
          final id = '${mm['id'] ?? ''}';
          if (id.isNotEmpty && !_members.any((x) => x.id == id)) {
            _members.add(RoomMember.fromMap(mm));
            if (id != _myId && id != 'host') {
              _store.pushNotification(
                  kind: NotifKind.info,
                  title: 'Se unió ${mm['name']}',
                  body: 'Ahora hay ${_members.length} personas en la sala.');
            }
          }
        }
      case 'member_left':
        if (fromId.isEmpty) {
          final id = '${ev.payload['id']}';
          _members.removeWhere((m) => m.id == id);
          _pendingVerify.remove(id);
          _lastSeenMs.remove(id);
          _typingUntilMs.remove(id);
          // El anfitrión directo avisa al resto (el hub solo vio la caída).
          if (_isHost && _mode != 'server' && id.isNotEmpty) {
            unawaited(emit('member_left', {'id': id}));
          }
        }

      case 'room_error':
        final reason = '${ev.payload['reason'] ?? 'error'}';
        _verifying = false;
        _verifyTimer?.cancel();
        if (reason == 'bad_pin' || reason == 'room_full' || reason == 'host_lost') {
          _pairingError = RoomProtocol.errorMessage(reason);
          _lastError = _pairingError;
          _needsPairing = false;
          _pendingVerify.remove(fromId);
          unawaited(leave()); // «si no coincide → cancela la conexión»
        } else {
          _status = RoomStatus.error;
          _lastError = RoomProtocol.errorMessage(reason);
        }
    }
    notifyListeners();
  }

  // ── Rol server del anfitrión directo ──────────────────────────────────────

  Future<void> _hostOnJoinRoom(String fromId, Map<String, dynamic> payload) async {
    if (fromId.isEmpty) return;
    if (_members.length >= RoomPairing.maxMembers) {
      await _transport?.emitTo(fromId, 'room_error', {'reason': 'room_full'});
      return;
    }
    _pendingVerify[fromId] = RoomProtocol.cleanName('${payload['name'] ?? ''}');
    await _transport?.emitTo(fromId, 'room_verify', {});
    notifyListeners();
  }

  Future<void> _hostOnVerify(String fromId, Map<String, dynamic> payload) async {
    final name = _pendingVerify[fromId];
    if (name == null) return; // no estaba verificándose: se ignora
    final pinOk = '${payload['pin'] ?? ''}' == _pin;
    final emojiOk = '${payload['emoji'] ?? ''}' == _emoji;
    _pendingVerify.remove(fromId);
    if (pinOk && emojiOk) {
      _members.add(RoomMember(id: fromId, name: name));
      _lastSeenMs[fromId] = _nowMs;
      await _transport?.emitTo(fromId, 'room_joined', {
        'code': _code,
        'members': _members.map((m) => {'id': m.id, 'name': m.name}).toList(),
        'items': _sanitizedCart(), // el anfitrión comparte su lista (§6)
      });
      for (final m in _members) {
        if (m.id != fromId && m.id != 'host') {
          unawaited(_transport
              ?.emitTo(m.id, 'member_joined', {'member': {'id': fromId, 'name': name}}));
        }
      }
      _store.pushNotification(
          kind: NotifKind.info,
          title: 'Se unió $name',
          body: 'Verificación OK · ${_members.length} personas en la sala.');
    } else {
      // Solo este par es rechazado; el resto de la sala sigue intacta.
      unawaited(_transport?.emitTo(fromId, 'room_error', {'reason': 'bad_pin'}));
    }
    notifyListeners();
  }

  void _relayToOthers(String type, Map<String, dynamic> payload, String fromId) {
    for (final m in _members) {
      if (m.id == fromId || m.id == 'host') continue;
      unawaited(_transport?.emitTo(m.id, type, {...payload, 'byId': fromId}));
    }
  }

  void _applyMembers(dynamic raw) {
    _members
      ..clear()
      ..addAll(((raw as List?) ?? const [])
          .whereType<Map>()
          .map((m) => RoomMember.fromMap(Map<String, dynamic>.from(m))));
  }

  void _applyPresence(List<String> online) {
    final set = online.toSet();
    for (final m in _members) {
      m.online = set.contains(m.id);
    }
  }

  void _applyTyping(List<String> names) {
    final set = names.toSet();
    for (final m in _members) {
      m.typing = set.contains(m.name);
    }
  }

  // ── Acciones de la UI ─────────────────────────────────────────────────────

  /// Invitado: envía PIN + emoji elegido para la verificación.
  void submitPairing(String pin, String emoji) {
    if (!connected || !_needsPairing || _verifying) return;
    _verifying = true;
    _pairingError = null;
    unawaited(emit('verify', {'pin': pin.trim(), 'emoji': emoji}));
    _verifyTimer?.cancel();
    _verifyTimer = Timer(const Duration(seconds: 12), () {
      if (_verifying) {
        _verifying = false;
        _pairingError = 'No hubo respuesta del anfitrión';
        notifyListeners();
      }
    });
    notifyListeners();
  }

  /// Señal «escribiendo…» (el server o el anfitrión la agregan).
  void sendTyping() {
    if (!connected) return;
    if (_isHost && _mode != 'server') {
      _typingUntilMs['host'] = _nowMs + _typingMs;
    }
    unawaited(emit('typing', {}));
  }

  /// Empuja la lista local completa a la sala (list_replace §6).
  Future<void> pushMyList() async {
    if (!connected) return;
    final items = _sanitizedCart();
    await emit('list_replace', {'items': items, 'byId': _myId});
    _snapshot = items;
  }

  Map<String, dynamic>? _itemToMap(CartItem c) => RoomProtocol.sanitizeItem({
        'id': c.id,
        'name': c.name,
        'quantity': c.quantity,
        'price': c.price,
        'currency': c.currency,
        'checked': c.checked,
        if ((c.checkedBy ?? '').isNotEmpty) 'checkedBy': c.checkedBy,
      }, _myId);

  List<Map<String, dynamic>> _sanitizedCart() =>
      _store.cart.map(_itemToMap).whereType<Map<String, dynamic>>().toList();

  /// Diff del store → item_add/item_update/item_remove (operaciones
  /// granulares §6). Las mutaciones REMOTAS llegan suprimidas y solo
  /// refrescan el snapshot.
  void _onStoreChanged() {
    final now = _sanitizedCart();
    final wasSuppressed = _suppress || !connected || _transport == null;
    if (!wasSuppressed) {
      final prev = {for (final m in _snapshot) '${m['id']}': m};
      final next = {for (final m in now) '${m['id']}': m};
      for (final m in now) {
        final old = prev['${m['id']}'];
        if (old == null) {
          unawaited(emit('item_add', {'item': m, 'byId': _myId}));
        } else {
          final patch = <String, dynamic>{};
          for (final k in ['name', 'quantity', 'price', 'currency', 'checked', 'checkedBy']) {
            if (old[k] != m[k]) patch[k] = m[k];
          }
          if (patch.isNotEmpty) {
            unawaited(emit('item_update', {'id': m['id'], 'patch': patch, 'byId': _myId}));
          }
        }
      }
      for (final id in prev.keys) {
        if (!next.containsKey(id)) {
          unawaited(emit('item_remove', {'id': id, 'byId': _myId}));
        }
      }
    }
    _snapshot = now;
  }

  // ── Escaneo de salas cercanas (lobby) ─────────────────────────────────────

  /// Escanea salas públicas: Nearby discovery + sondas UDP LAN. Los privados
  /// no aparecen: se entra por código o IP.
  Future<void> startScan() async {
    if (_scanning || connected || _status == RoomStatus.connecting) return;
    _scanning = true;
    _foundRooms.clear();
    notifyListeners();
    _lanScanner ??= LanHubImpl();
    _nearScanner ??= NearbyHubImpl();
    await _lanAdSub?.cancel();
    await _nearAdSub?.cancel();
    _lanAdSub = _lanScanner!.roomAds.listen(_onAd);
    _nearAdSub = _nearScanner!.roomAds.listen(_onAd);
    await _lanScanner!.startScan();
    await _nearScanner!.startScan();
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pruneAds());
  }

  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    await _lanAdSub?.cancel();
    await _nearAdSub?.cancel();
    _lanAdSub = null;
    _nearAdSub = null;
    await _lanScanner?.stopScan();
    await _nearScanner?.stopScan();
    if (_scanning) {
      _scanning = false;
      notifyListeners();
    }
  }

  void _onAd(Map<String, dynamic> ad) {
    final code = '${ad['code'] ?? ''}';
    if (code.isEmpty || code.length < 4) return;
    final isPublic = ad['pub'] == true || ad['pub'] == 1;
    if (!isPublic) return; // privadas: solo por código o IP
    final key = '${ad['via']}-$code';
    final idx = _foundRooms.indexWhere((r) => r.key == key);
    final built = RoomAd(
      mode: '${ad['via']}',
      code: code,
      roomName: '${ad['name'] ?? ''}',
      hostName: '${ad['host'] ?? ''}',
      emoji: '${ad['emoji'] ?? ''}',
      isPublic: true,
      seen: DateTime.now(),
      host: '${ad['ip'] ?? ''}',
      port: (ad['port'] as num?)?.toInt() ?? LanHubImpl.kTcpPort,
      endpointId: '${ad['endpointId'] ?? ''}',
    );
    if (idx >= 0) {
      _foundRooms[idx] = built;
    } else {
      _foundRooms.add(built);
    }
    _pruneAds();
    notifyListeners();
  }

  void _pruneAds() {
    final before = _foundRooms.length;
    _foundRooms.removeWhere((r) => r.stale);
    if (_foundRooms.length != before) notifyListeners();
  }

  /// Unirse a una sala avistada en el escaneo.
  Future<String?> joinAd(RoomAd ad, String name) => join(
        name: name,
        code: ad.code,
        mode: ad.mode,
        directHost: ad.host.isEmpty ? null : ad.host,
        directPort: ad.host.isEmpty ? null : ad.port,
        targetEndpointId: ad.endpointId.isEmpty ? null : ad.endpointId,
      );

  // ── Emisión con outbox: sin conexión → encola (outbox offline §7/§12.2) ──

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

  /// Vacía el outbox al reconectar (contrato actual).
  Future<void> flushOutbox() async {
    if (!connected || _store.outbox.isEmpty || _transport == null) return;
    final queue = [..._store.outbox];
    for (final msg in queue) {
      await _transport!.emit('${msg['type']}', msg);
      _store.outbox.remove(msg);
    }
    _store.persistOutbox();
  }

  Future<void> leave() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _scanTimerPresence?.cancel();
    _scanTimerPresence = null;
    _verifyTimer?.cancel();
    _verifyTimer = null;
    _store.removeListener(_onStoreChanged);
    await _teardownTransport();
    _status = RoomStatus.disconnected;
    _members.clear();
    _pendingVerify.clear();
    _needsPairing = false;
    _verifying = false;
    _lastSeenMs.clear();
    _typingUntilMs.clear();
    _snapshot = const [];
    notifyListeners();
  }

  Future<void> _teardownTransport() async {
    _sub?.cancel();
    _statusSub?.cancel();
    _sub = null;
    _statusSub = null;
    final t = _transport;
    _transport = null;
    try {
      await t?.disconnect();
    } catch (_) {}
  }

  /// Engancha el diff del store (se llama al entrar a la vista de sala).
  void attachStoreListener() {
    _store.removeListener(_onStoreChanged);
    _store.addListener(_onStoreChanged);
    _snapshot = _sanitizedCart();
  }

  void detachStoreListener() => _store.removeListener(_onStoreChanged);

  @override
  void dispose() {
    _pingTimer?.cancel();
    _scanTimerPresence?.cancel();
    _verifyTimer?.cancel();
    _scanTimer?.cancel();
    _store.removeListener(_onStoreChanged);
    unawaited(stopScan());
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

  Map<String, dynamic> toMap() => {'id': id, 'name': name};
}
