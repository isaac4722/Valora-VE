/// ─── BtHub · Bluetooth clásico RFCOMM/SPP para la Sala Viva (v18.0) ──────
/// Puente Dart ↔ BtSppPlugin.kt (hecho a mano: ningún paquete de pub.dev
/// soporta el ROL SERVIDOR sobre RFCOMM — flutter_bluetooth_serial lleva
/// congelado desde 2021 y solo expone el lado cliente).
///
/// Protocolo: líneas JSON lista-sync (idéntico al servidor/LAN/Nearby) sobre
/// el socket RFCOMM del servicio «ValoraVE». El anfitrión acepta VARIOS
/// invitados (ids «btN»); el invitado abre UN socket (su anfitrión es
/// «host»).
///
/// Watchdogs: el invitado espera hasta 45 s el emparejamiento previo
/// (diálogo del sistema) y 15 s el connect; sin datos del anfitrión por
/// 60 s se declara host_lost. El host cierra pares muertos al fallar la
/// escritura. El re-discovery del lobby lo re-dispara el controlador cada
/// 12 s (Android termina un discovery solo).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/services.dart';

import '../room/room_transport.dart' show RoomEvent, RoomStatus;

/// Hub Bluetooth clásico: mismo contrato que LanHubImpl/NearbyHubImpl.
class BtHubImpl {
  BtHubImpl();

  static const MethodChannel _m = MethodChannel('valorave/bt_spp');
  static const EventChannel _e = EventChannel('valorave/bt_spp/events');

  /// Espera máx. del emparejamiento previo (diálogo del sistema).
  static const Duration kBondTimeout = Duration(seconds: 45);

  /// Espera máx. del connect RFCOMM en sí.
  static const Duration kConnectTimeout = Duration(seconds: 15);

  /// Sin datos del anfitrión por este tiempo → host_lost (guest).
  static const Duration kHostSilence = Duration(seconds: 60);

  final _events = StreamController<RoomEvent>.broadcast();
  final _statuses = StreamController<RoomStatus>.broadcast();
  final _ads = StreamController<Map<String, dynamic>>.broadcast();
  StreamSubscription<dynamic>? _sub;

  RoomStatus _status = RoomStatus.disconnected;
  bool _isHost = false;

  /// Buffers por par para el cortado de líneas JSON.
  final Map<String, BytesBuilder> _rx = {};

  /// Watchdog del invitado: último dato recibido del anfitrión.
  DateTime? _lastHostData;
  Timer? _watchdog;

  bool get isHost => _isHost;
  RoomStatus get status => _status;
  Stream<RoomEvent> get events => _events.stream;
  Stream<RoomStatus> get statusStream => _statuses.stream;
  Stream<Map<String, dynamic>> get roomAds => _ads.stream;

  void _setStatus(RoomStatus s) {
    _status = s;
    _statuses.add(s);
  }

  void _fail(String code) {
    _setStatus(RoomStatus.error);
    _events.add(RoomEvent('room_error', {'reason': code}));
  }

  // ── Host: servidor RFCOMM ────────────────────────────────────────────────

  /// Anfitrión: abre el servidor RFCOMM «ValoraVE» y queda a la escucha.
  Future<void> connect({
    required String roomCode,
    required String myName,
    String roomName = '',
    String emoji = '',
    bool isPublic = true,
  }) async {
    _isHost = true;
    _listen();
    final ok = await _m.invokeMethod<bool>('serverStart') ?? false;
    if (ok) {
      _setStatus(RoomStatus.connected);
      // Los invitados llegan como eventos accepted → el controlador los
      // maneja con join_room/verify igual que LAN/Nearby.
    }
    // Si falló, el plugin ya emitió error{code} → _fail() por el stream.
  }

  // ── Guest: emparejar + conectar al anfitrión ─────────────────────────────

  /// Invitado: empareja si hace falta (diálogo del sistema) y conecta al
  /// RFCOMM del anfitrión. Devuelve null si quedó conectado; si no, el
  /// código de error humano ('off', 'permissions', 'bt_connect'…).
  Future<String?> connectToHost({
    required String address,
    required String roomCode,
    required String myName,
  }) async {
    _isHost = false;
    _listen();

    final state = await _m.invokeMethod<String>('state') ?? 'unavailable';
    if (state == 'unavailable') return 'unavailable';
    if (state != 'on') return 'off';

    final granted = await _m.invokeMethod<bool>('hasPermissions', {'scan': false}) ?? false;
    if (!granted) {
      await _m.invokeMethod<void>('requestPermissions', {'scan': false});
      return 'permissions';
    }

    // Emparejamiento previo (RFCOMM a un dispositivo sin emparejar falla
    // o dispara un diálogo a medias): se empareja PRIMERO y se espera el
    // resultado hasta 45 s.
    final bonded = await _m.invokeMethod<bool>('isBonded', {'address': address}) ?? false;
    if (!bonded) {
      final started = await _m.invokeMethod<bool>('bond', {'address': address}) ?? false;
      if (!started) return 'bt_connect';
      final ok = await _waitFor(
        _e.receiveBroadcastStream(),
        kBondTimeout,
        (m) => m is Map && m['kind'] == 'bonded' && m['address'] == address,
        onMiss: (m) =>
            m is Map && m['kind'] == 'bondFailed' && m['address'] == address,
      );
      if (ok != true) return 'bt_connect';
    }

    final connected = Completer<String?>();
    late final StreamSubscription<dynamic> sub;
    sub = _e.receiveBroadcastStream().listen((m) {
      if (m is! Map) return;
      if (m['kind'] == 'connected') {
        if (!connected.isCompleted) connected.complete(null);
      } else if (m['kind'] == 'error') {
        if (!connected.isCompleted) connected.complete('${m['code'] ?? 'bt_connect'}');
      }
    });
    final started = await _m.invokeMethod<bool>('connect', {'address': address}) ?? false;
    if (!started) {
      await sub.cancel();
      return 'bt_connect';
    }
    final err = await connected.future.timeout(kConnectTimeout,
        onTimeout: () => 'bt_timeout');
    await sub.cancel();
    if (err != null) return err;

    _setStatus(RoomStatus.connected);
    _lastHostData = DateTime.now();
    _watchdog?.cancel();
    _watchdog = Timer.periodic(const Duration(seconds: 10), (_) {
      final last = _lastHostData;
      if (!isHost && last != null && DateTime.now().difference(last) > kHostSilence) {
        _watchdog?.cancel();
        _fail('host_lost');
      }
    });
    return null;
  }

  /// Espera un evento del stream que cumpla [hit] (o [miss] para fallar
  /// antes del plazo). Devuelve true / false / null (timeout).
  Future<bool?> _waitFor(
    Stream<dynamic> stream,
    Duration timeout,
    bool Function(dynamic) hit, {
    bool Function(dynamic)? onMiss,
  }) {
    final done = Completer<bool?>();
    late final StreamSubscription<dynamic> sub;
    sub = stream.listen((m) {
      if (done.isCompleted) return;
      if (hit(m)) {
        done.complete(true);
      } else if (onMiss != null && onMiss(m)) {
        done.complete(false);
      }
    });
    final t = Timer(timeout, () {
      if (!done.isCompleted) done.complete(null);
    });
    return done.future.whenComplete(() {
      t.cancel();
      sub.cancel();
    });
  }

  // ── Stream compartido de eventos del plugin ──────────────────────────────

  void _listen() {
    _sub?.cancel();
    _sub = _e.receiveBroadcastStream().listen(_onNative, onError: (_) {});
  }

  void _onNative(dynamic raw) {
    if (raw is! Map) return;
    final kind = '${raw['kind'] ?? ''}';
    switch (kind) {
      case 'data':
        final id = '${raw['id'] ?? 'host'}';
        final data = raw['data'];
        if (data is Uint8List) {
          if (!isHost) _lastHostData = DateTime.now();
          _feed(id, data);
        }
      case 'accepted':
        // Anfitrión: un invitado conectó (el join_room llega por datos).
        _trackPeer('${raw['id'] ?? ''}', true);
      case 'connected':
        break; // consumido por connectToHost
      case 'closed':
        // Invitado: el anfitrión cortó.
        if (!isHost) _fail('host_lost');
      case 'peerClosed':
        // Anfitrión: un invitado se fue → member_left para el controlador.
        final pid = '${raw['id'] ?? ''}';
        _rx.remove(pid);
        _trackPeer(pid, false);
        if (isHost) {
          _events.add(RoomEvent('member_left', {'id': pid}));
        }
      case 'found':
        final address = '${raw['address'] ?? ''}';
        final name = '${raw['name'] ?? ''}';
        if (address.isNotEmpty) {
          _ads.add({
            'via': 'bt',
            'code': 'BT${address.replaceAll(':', '').takeLast(4)}',
            'name': name,
            'host': address,
            'pub': true,
          });
        }
      case 'error':
        _fail('${raw['code'] ?? 'bt_connect'}');
      case 'state':
        if ('${raw['value'] ?? ''}' == 'off') {
          _setStatus(RoomStatus.error);
        }
      case 'bonded' || 'bondFailed' || 'discoveryDone':
        break; // consumidos por connectToHost / startDiscovery
    }
  }

  /// Corta el stream de bytes en líneas JSON y las convierte en RoomEvents.
  void _feed(String id, Uint8List bytes) {
    final b = (_rx[id] ??= BytesBuilder());
    b.add(bytes);
    // Corta por '\n' — puede haber varias líneas o líneas parciales.
    var pending = b.takeBytes();
    var start = 0;
    for (var i = 0; i < pending.length; i++) {
      if (pending[i] == 0x0A) {
        final line = pending.sublist(start, i);
        start = i + 1;
        if (line.isNotEmpty) {
          try {
            final m = jsonDecode(utf8.decode(line));
            if (m is Map<String, dynamic>) {
              _events.add(RoomEvent('${m['type'] ?? 'unknown'}', {...m, 'fromId': id}));
            }
          } catch (_) {/* línea corrupta: se descarta */}
        }
      }
    }
    if (start > 0) b.add(pending.sublist(start));
  }

  // ── Emisión ──────────────────────────────────────────────────────────────

  /// Broadcast: el anfitrión escribe a TODOS sus pares; el invitado, al host.
  Future<Map<String, dynamic>?> emit(String type, Map<String, dynamic> payload) async {
    if (isHost) {
      // Copia local: no mutar el mapa del llamante.
      for (final id in _peers()) {
        await _sendTo(id, type, payload);
      }
      return <String, dynamic>{'ok': true};
    }
    return _sendTo('host', type, payload);
  }

  /// 1:1: [targetId] es un peer «btN» (anfitrión) o «host» (invitado).
  Future<Map<String, dynamic>?> emitTo(
      String targetId, String type, Map<String, dynamic> payload) async {
    if (!isHost && targetId != 'host') return null;
    return _sendTo(targetId, type, payload);
  }

  Future<Map<String, dynamic>?> _sendTo(
      String id, String type, Map<String, dynamic> payload) async {
    try {
      final line = jsonEncode({...payload, 'type': type});
      final bytes = Uint8List.fromList(utf8.encode('$line\n'));
      final ok = await _m.invokeMethod<bool>('write', {'id': id, 'data': bytes}) ?? false;
      return ok ? <String, dynamic>{'ok': true} : null;
    } on PlatformException {
      return null;
    }
  }

  /// Ids de pares conectados: el anfitrión no puede preguntarle al plugin
  /// (no expone lista), así que se rastrea por los eventos accepted/peerClosed.
  final Set<String> _knownPeers = {};

  Iterable<String> _peers() {
    if (!_isHost) return const ['host'];
    return _knownPeers;
  }

  // ── Escaneo (lobby) ──────────────────────────────────────────────────────

  /// Descubre dispositivos Bluetooth cercanos + ya emparejados. El
  /// controlador re-dispara el discovery cada 12 s (Android lo corta solo).
  Future<void> startScan() async {
    _listen(); // garantiza el stream vivo para found/error
    final state = await _m.invokeMethod<String>('state') ?? 'unavailable';
    if (state == 'unavailable') {
      _ads.add({'via': 'bt', 'error': 'unavailable'});
      return;
    }
    if (state != 'on') {
      _ads.add({'via': 'bt', 'error': 'off'});
      return;
    }
    final granted = await _m.invokeMethod<bool>('hasPermissions', {'scan': true}) ?? false;
    if (!granted) {
      await _m.invokeMethod<void>('requestPermissions', {'scan': true});
      _ads.add({'via': 'bt', 'error': 'permissions'});
      return;
    }
    // Los YA emparejados son candidatos inmediatos (sin esperar discovery).
    final bonded = await _m.invokeMethod<List<dynamic>>('bondedDevices') ?? const [];
    for (final d in bonded) {
      if (d is Map) {
        final address = '${d['address'] ?? ''}';
        if (address.isNotEmpty) {
          _ads.add({
            'via': 'bt',
            'code': 'BT${address.replaceAll(':', '').takeLast(4)}',
            'name': '${d['name'] ?? ''}',
            'host': address,
            'pub': true,
          });
        }
      }
    }
    await startDiscovery();
  }

  /// Re-discovery (idempotente: si ya está descubriendo, el plugin lo ignora).
  Future<void> startDiscovery() async {
    try {
      await _m.invokeMethod<bool>('startDiscovery');
    } on PlatformException {
      // sin permiso/adapter: los ads ya lo reportaron
    }
  }

  Future<void> stopScan() async {
    try {
      await _m.invokeMethod<void>('cancelDiscovery');
    } on PlatformException {
      // nada
    }
  }

  /// Códigos «visibles» (contrato del transporte): dispositivos encontrados.
  Future<List<String>> discover() async => const [];

  // ── Cierre ───────────────────────────────────────────────────────────────

  Future<void> disconnect() async {
    _watchdog?.cancel();
    _watchdog = null;
    await stopScan();
    try {
      await _m.invokeMethod<void>(isHost ? 'serverStop' : 'disconnect');
    } on PlatformException {
      // plugin ya caído
    }
    _knownPeers.clear();
    _rx.clear();
    _lastHostData = null;
    _setStatus(RoomStatus.disconnected);
  }

  /// Cierra TODO (server + cliente + discovery) — fin de la sala.
  Future<void> destroy() async {
    try {
      await _m.invokeMethod<void>('destroy');
    } on PlatformException {
      // plugin ya caído
    }
    _watchdog?.cancel();
    _watchdog = null;
    _knownPeers.clear();
    _rx.clear();
    _setStatus(RoomStatus.disconnected);
  }

  /// Rastrea los pares aceptados/perdidos para el broadcast del anfitrión.
  /// Se llama desde _onNative vía _trackPeers.
  void _trackPeer(String id, bool up) {
    if (up) {
      _knownPeers.add(id);
    } else {
      _knownPeers.remove(id);
    }
  }
}

extension on String {
  /// Últimos [n] caracteres (para códigos únicos por dispositivo).
  String takeLast(int n) => length <= n ? this : substring(length - n);
}
