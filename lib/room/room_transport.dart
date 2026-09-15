/// ─── Sala P2P (v19.0 · reescrita desde CERO, orden del dueño) ───────────────
/// «Las conexiones son para que sincronicen en forma P2P, y todo posible sin
/// conexión a internet. Reescribe todo sobre esto desde 0 para evitar
/// inconsistencias o problemas.»
///
/// TRES modos, todos P2P y sin internet, cada uno con SU tecnología:
///  · Cerca  — Google Nearby Connections (WiFi-Direct/BT/BLE, P2P_STAR):
///             sin configurar nada; requiere Google Play Services.
///  · WiFi   — misma red WiFi o el Hotspot del anfitrión: broadcast UDP
///             (descubrimiento) + TCP (protocolo).
///  · Bltth  — Bluetooth clásico RFCOMM/SPP nativo (BtSppPlugin.kt):
///             sin Play Services, con emparejamiento previo.
///
/// El modo «Servidor» (socket.io) queda FUERA: no es P2P y necesita
/// internet — exactamente lo que el dueño pidió evitar. Dependencia
/// socket_io_client retirada de la app.
///
/// PROTOCOLO (determinista, sin bailes):
///  · El anfitrión ES la sala: valida, asigna roles y retransmite (estrella).
///  · Invitado: dial → hello{code,name} → espera welcome (10 s) — solo
///    entonces está «en sala». Sin PIN/emoji: el código de 6 letras ES el
///    secreto de una lista de compras.
///  · Items: item_add/item_update/item_remove/list_replace con suppress
///    local (los remotos aplican al store y nunca se re-emiten).
///  · Presencia: ping cada 8 s; el anfitrión barre cada 5 s y dropped a los
///    silenciosos de 30 s. Gobierno v18.0 intacto: renombrar, cerrar
///    (también auto-cierre tras compra), expulsar, roles editor/viewer.
library;

import 'dart:async';
import 'dart:convert';

import '../services/bt_hub.dart';
import '../services/lan_hub.dart';
import '../services/nearby_hub.dart';

export '../services/bt_hub.dart' show BtHubImpl;
export '../services/lan_hub.dart' show LanHubImpl;
export '../services/nearby_hub.dart' show NearbyHubImpl;

/// Evento normalizado del protocolo (SIN acoplarse al transporte).
/// Los hubs añaden `fromId` al payload de lo que llega de cada par.
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

/// Modos P2P (v19.0): tres tecnologías, cero internet.
enum RoomMode { cerca, wifi, bt }

extension RoomModeX on RoomMode {
  String get id => switch (this) {
        RoomMode.cerca => 'cerca',
        RoomMode.wifi => 'wifi',
        RoomMode.bt => 'bt',
      };

  /// Etiqueta humana del modo.
  String get label => switch (this) {
        RoomMode.cerca => 'Cerca',
        RoomMode.wifi => 'WiFi o Hotspot',
        RoomMode.bt => 'Bluetooth',
      };

  /// Qué tecnología usa (para la UI del lobby).
  String get tech => switch (this) {
        RoomMode.cerca => 'Nearby · WiFi-Direct/BT/BLE',
        RoomMode.wifi => 'UDP + TCP en tu red',
        RoomMode.bt => 'Bluetooth clásico RFCOMM',
      };

  /// Qué necesita del usuario.
  String get hint => switch (this) {
        RoomMode.cerca => 'Sin configurar nada. Requiere Google Play '
            'Services (casi todo teléfono lo tiene).',
        RoomMode.wifi => 'Mismo WiFi — o el Hotspot del anfitrión con los '
            'invitados conectados a él.',
        RoomMode.bt => 'Empareja los teléfonos primero (Ajustes de Android). '
            'Sirve sin Google Play Services.',
      };

  static RoomMode from(String? s) => switch (s?.toLowerCase()) {
        'wifi' => RoomMode.wifi,
        'bt' => RoomMode.bt,
        _ => RoomMode.cerca,
      };
}

/// ─── Seam de ENLACE (el corazón de la reescritura) ──────────────────────────
/// Una interfaz con DOS entradas explícitas: [startHost] y [dial]. El bug
/// histórico del «crear sala» venía de inferir el rol por un parámetro
/// ambiguo: el anfitrión pasaba su código generado y los hubs lo arrancaban
/// como DESCUBRIDOR (nadie anunciaba, nadie encontraba nada). Aquí el rol se
/// declara, no se adivina. Y los tests pueden meter un enlace falso.
abstract class RoomLink {
  String get modeId; // 'cerca' | 'wifi' | 'bt'
  RoomStatus get status;
  Stream<RoomEvent> get events;
  Stream<RoomStatus> get statusStream;

  /// Anfitrión: la sala queda VIVA (escuchando/anunciando) cuando resuelve.
  /// Lanza/entra en error si no pudo (puerto tomado, BT apagado, permisos…).
  Future<void> startHost({
    required String roomCode,
    required String myName,
    required String roomName,
    required bool isPublic,
  });

  /// Invitado: conecta al anfitrión de ese código (o directo por
  /// host/port/endpointId del escaneo). Resuelve al ENLACE conectado.
  Future<void> dial({
    required String roomCode,
    required String myName,
    String? host,
    int? port,
    String? endpointId,
  });

  /// Enviar a todos (anfitrión) / al anfitrión (invitado).
  Future<void> send(String type, Map<String, dynamic> payload);

  /// Envío 1:1 (solo anfitrión; el invitado cae a [send]).
  Future<void> sendTo(String id, String type, Map<String, dynamic> payload);

  Future<void> disconnect();
}

/// ─── (a) Cerca — Nearby Connections ─────────────────────────────────────────
class NearbyLink implements RoomLink {
  NearbyLink({NearbyHubImpl? hub}) : hub = hub ?? NearbyHubImpl();
  final NearbyHubImpl hub;

  @override
  String get modeId => 'cerca';
  @override
  RoomStatus get status => hub.status;
  @override
  Stream<RoomEvent> get events => hub.events;
  @override
  Stream<RoomStatus> get statusStream => hub.statusStream;

  @override
  Future<void> startHost({
    required String roomCode,
    required String myName,
    required String roomName,
    required bool isPublic,
  }) =>
      hub.startHost(
          roomCode: roomCode,
          myName: myName,
          roomName: roomName,
          isPublic: isPublic);

  @override
  Future<void> dial({
    required String roomCode,
    required String myName,
    String? host,
    int? port,
    String? endpointId,
  }) =>
      hub.dial(
          roomCode: roomCode, myName: myName, targetEndpointId: endpointId);

  @override
  Future<void> send(String type, Map<String, dynamic> payload) =>
      hub.emit(type, payload);

  @override
  Future<void> sendTo(String id, String type, Map<String, dynamic> payload) =>
      hub.emitTo(id, type, payload);

  @override
  Future<void> disconnect() => hub.disconnect();
}

/// ─── (b) WiFi o Hotspot — UDP broadcast + TCP ───────────────────────────────
class LanLink implements RoomLink {
  LanLink({LanHubImpl? hub}) : hub = hub ?? LanHubImpl();
  final LanHubImpl hub;

  @override
  String get modeId => 'wifi';
  @override
  RoomStatus get status => hub.status;
  @override
  Stream<RoomEvent> get events => hub.events;
  @override
  Stream<RoomStatus> get statusStream => hub.statusStream;

  @override
  Future<void> startHost({
    required String roomCode,
    required String myName,
    required String roomName,
    required bool isPublic,
  }) =>
      hub.startHost(
          roomCode: roomCode,
          myName: myName,
          roomName: roomName,
          isPublic: isPublic);

  @override
  Future<void> dial({
    required String roomCode,
    required String myName,
    String? host,
    int? port,
    String? endpointId,
  }) async {
    if (host != null && host.trim().isNotEmpty) {
      final ok = await hub.connectToHost(
        host: host.trim(),
        port: port ?? LanHubImpl.kTcpPort,
        roomCode: roomCode,
        myName: myName,
      );
      if (!ok) throw Exception('Sin respuesta del anfitrión');
      return;
    }
    await hub.dial(roomCode: roomCode, myName: myName);
  }

  @override
  Future<void> send(String type, Map<String, dynamic> payload) =>
      hub.emit(type, payload);

  @override
  Future<void> sendTo(String id, String type, Map<String, dynamic> payload) =>
      hub.emitTo(id, type, payload);

  @override
  Future<void> disconnect() => hub.disconnect();
}

/// ─── (c) Bluetooth clásico RFCOMM/SPP ───────────────────────────────────────
class BtLink implements RoomLink {
  BtLink({BtHubImpl? hub}) : hub = hub ?? BtHubImpl();
  final BtHubImpl hub;

  @override
  String get modeId => 'bt';
  @override
  RoomStatus get status => hub.status;
  @override
  Stream<RoomEvent> get events => hub.events;
  @override
  Stream<RoomStatus> get statusStream => hub.statusStream;

  @override
  Future<void> startHost({
    required String roomCode,
    required String myName,
    required String roomName,
    required bool isPublic,
  }) =>
      hub.connect(roomCode: roomCode, myName: myName); // BT: connect = host

  @override
  Future<void> dial({
    required String roomCode,
    required String myName,
    String? host,
    int? port,
    String? endpointId,
  }) async {
    // Invitado BT: la MAC del anfitrión llega como host/endpointId.
    final address = (endpointId ?? host ?? '').trim();
    if (address.isEmpty) {
      throw Exception('Elige el dispositivo del anfitrión en la lista');
    }
    final err = await hub.connectToHost(
        address: address, roomCode: roomCode, myName: myName);
    if (err != null) throw Exception(err);
  }

  @override
  Future<void> send(String type, Map<String, dynamic> payload) =>
      hub.emit(type, payload);

  @override
  Future<void> sendTo(String id, String type, Map<String, dynamic> payload) =>
      hub.emitTo(id, type, payload);

  @override
  Future<void> disconnect() => hub.disconnect();
}

/// ─── Utilidades del protocolo ───────────────────────────────────────────────
class RoomProtocol {
  static const int maxMembers = 10;

  /// Límite de payload 16 KB (§6).
  static bool tooLarge(Map<String, dynamic> payload) =>
      utf8.encode(jsonEncode(payload)).length > 16 * 1024;

  /// Código de 6 letras sin O/I.
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

  /// Errores humanos.
  static String errorMessage(String reason) => switch (reason) {
        'not_found' => 'No existe esa sala',
        'room_full' => 'La sala está llena (10 personas)',
        'too_large' => 'El mensaje pesa más de 16 KB',
        'bad_item' => 'Ítem inválido',
        'bad_update' => 'Cambio inválido',
        'bad_remove' => 'No se puede quitar ese ítem',
        'bad_items' => 'Lista inválida',
        'list_full' => 'La sala llegó a 120 ítems',
        'host_lost' => 'Se perdió al anfitrión',
        'permissions' => 'La sala necesita permiso de Bluetooth/Nearby (y '
            'ubicación en Android antiguo). Concédelo cuando lo pida y reintenta',
        'unavailable' => 'Este teléfono no tiene Bluetooth',
        'off' => 'Enciende el Bluetooth para usar este modo',
        'bt_timeout' => 'El otro teléfono no respondió a tiempo',
        'bt_connect' => 'No se pudo conectar por Bluetooth',
        'kicked' => 'Te sacaron de la sala',
        'room_closed' => 'La sala se cerró',
        _ => 'Error: $reason',
      };
}

/// Miembro de la sala (rol: host | editor | viewer).
class RoomMember {
  RoomMember({
    required this.id,
    required this.name,
    this.role = 'editor',
    this.online = true,
    this.typing = false,
  });

  final String id;
  final String name;
  String role;
  bool online;
  bool typing;

  factory RoomMember.fromMap(Map<String, dynamic> m) => RoomMember(
        id: '${m['id'] ?? ''}',
        name: '${m['name'] ?? ''}',
        role: '${m['role'] ?? 'editor'}',
        online: m['online'] is bool ? m['online'] as bool : true,
      );

  Map<String, dynamic> toMap() =>
      {'id': id, 'name': name, 'role': role, 'online': online};
}

/// Sala pública avistada cerca (escaneo del lobby).
class RoomAd {
  const RoomAd({
    required this.mode,
    required this.code,
    required this.roomName,
    required this.hostName,
    required this.isPublic,
    required this.seen,
    this.host = '',
    this.port = LanHubImpl.kTcpPort,
    this.endpointId = '',
  });

  final RoomMode mode;
  final String code;
  final String roomName;
  final String hostName;
  final bool isPublic;

  /// LAN: IP del anfitrión · BT: MAC · Cerca: endpointId (viaja en endpointId).
  final String host;
  final int port;
  final String endpointId;
  final DateTime seen;

  String get key => '$mode-$code';
  bool get stale => DateTime.now().difference(seen) > const Duration(seconds: 18);

  String get label => roomName.isNotEmpty
      ? roomName
      : (hostName.isNotEmpty ? hostName : 'Sala $code');
}
