/// ─── RoomController (v19.0 · protocolo hello→welcome, sin PIN) ──────────────
/// Estado + gobierno de la sala sobre cualquier [RoomLink] P2P. Reescrito
/// desde 0 junto al seam de enlaces: el anfitrión ES la autoridad (valida,
/// asigna roles, retransmite) y el invitado solo está «en sala» cuando
/// recibió `welcome` — join() JAMÁS devuelve éxito sin la confirmación del
/// anfitrión (el viejo devolvía null apenas emitía join_room: quedaban
/// salas fantasma). Guard baseline+suppress + diff del store → item_* con
/// outbox offline.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/models.dart';
import '../data/store.dart';
import 'room_transport.dart';

class RoomController extends ChangeNotifier {
  RoomController(this._store, {RoomLink Function(RoomMode)? linkFactory})
      : _linkFactory = linkFactory ?? _defaultLink;

  final AppStore _store;
  final RoomLink Function(RoomMode) _linkFactory;

  RoomLink? _link;
  RoomStatus _status = RoomStatus.disconnected;
  String _code = '';
  String _myName = 'Comprador';
  RoomMode _mode = RoomMode.cerca;
  final List<RoomMember> _members = [];
  bool _isHost = false;
  String _roomName = '';
  bool _isPublic = true;
  String? _lastError;
  String _myPeerId = '';
  String _myRole = 'editor';

  /// Invitado: handshake hello→welcome en curso (null cuando no aplica).
  Completer<String?>? _welcome;

  // Presencia (anfitrión): ping 8 s · barrido 5 s · silencio mata a los 30 s.
  static const int _staleMs = 30000;
  static const int _typingMs = 3000;
  final Map<String, int> _lastSeenMs = {};
  final Map<String, int> _typingUntilMs = {};

  // Diff del store → item_* (guard contra ecos remotos).
  List<Map<String, dynamic>> _snapshot = const [];
  bool _suppress = false;

  // Escaneo de salas cercanas.
  final List<RoomAd> _foundRooms = [];
  bool _scanning = false;
  LanHubImpl? _lanScanner;
  NearbyHubImpl? _nearScanner;
  BtHubImpl? _btScanner;
  StreamSubscription<Map<String, dynamic>>? _lanAdSub;
  StreamSubscription<Map<String, dynamic>>? _nearAdSub;
  StreamSubscription<Map<String, dynamic>>? _btAdSub;
  Timer? _scanTimer;
  Timer? _btRescanTimer;

  Timer? _pingTimer;
  Timer? _sweepTimer;
  StreamSubscription<RoomEvent>? _sub;
  StreamSubscription<RoomStatus>? _statusSub;

  static RoomLink _defaultLink(RoomMode m) => switch (m) {
        RoomMode.cerca => NearbyLink(),
        RoomMode.wifi => LanLink(),
        RoomMode.bt => BtLink(),
      };

  // ── Lectura para la UI (superficie compatible con Lista/Checkout/SalaViva)

  RoomStatus get status => _status;
  String get code => _code;
  String get myName => _myName;
  RoomMode get mode => _mode;
  bool get connected => _status == RoomStatus.connected;
  List<RoomMember> get members => List.unmodifiable(_members);
  bool get isHost => _isHost;
  String get roomName => _roomName;
  bool get isPublic => _isPublic;
  String? get lastError => _lastError;
  bool get scanning => _scanning;
  List<RoomAd> get foundRooms => List.unmodifiable(_foundRooms);

  /// Identidad propia dentro de la sala.
  String get myId =>
      _myPeerId.isNotEmpty ? _myPeerId : (_isHost ? 'host' : 'me');

  /// Rol propio: 'host' | 'editor' | 'viewer'.
  String get myRole => _myRole;

  /// El anfitrión administra (renombrar/cerrar/expulsar/roles).
  bool get canAdmin => _isHost;

  /// Un observador ve la lista pero no la toca (gate en _emit).
  bool get isViewer => _myRole == 'viewer';

  /// Etiqueta humana del modo activo.
  String get modeLabel => _mode.label;

  /// Miembros normalizados: anfitrión SIEMPRE arriba, yo primero entre
  /// invitados, cada uno con su rol.
  List<RoomMember> get visibleMembers {
    final hostEntry = _isHost
        ? RoomMember(id: 'host', name: _myName, role: 'host')
        : (_members.where((m) => m.id == 'host').firstOrNull ??
            RoomMember(id: 'host', name: 'Anfitrión', role: 'host'));
    final rest = _members.where((m) => m.id != 'host').toList()
      ..sort((a, b) {
        final meA = a.id == _myPeerId ? 0 : 1;
        final meB = b.id == _myPeerId ? 0 : 1;
        if (meA != meB) return meA - meB;
        return a.name.compareTo(b.name);
      });
    return [hostEntry, ...rest];
  }

  /// Anfitrión WiFi: IP:puerto de su hub («este teléfono es la sala»).
  String get lanAddress {
    if (_mode != RoomMode.wifi || !_isHost) return '';
    final hub = _link is LanLink ? (_link as LanLink).hub : null;
    final ip = hub?.hostIp;
    return (ip == null || ip.isEmpty) ? '' : '$ip:${LanHubImpl.kTcpPort}';
  }

  // ── Config del lobby ──────────────────────────────────────────────────────

  void setMode(RoomMode m) {
    _mode = m;
    notifyListeners();
  }

  void setMyName(String v) {
    _myName = RoomProtocol.cleanName(v);
    notifyListeners();
  }

  void setRoomName(String v) {
    _roomName = v.trim().length > 32 ? v.trim().substring(0, 32) : v.trim();
    notifyListeners();
  }

  void setPublic(bool v) {
    _isPublic = v;
    notifyListeners();
  }

  // ── Crear / Unirse (deterministas) ────────────────────────────────────────

  /// Crea la sala: el enlace arranca como ANFITRIÓN (rol explícito — nunca
  /// se infiere). Devuelve null si la sala quedó viva.
  Future<String?> create({
    required String name,
    String roomName = '',
    bool isPublic = true,
    RoomMode? mode,
  }) async {
    if (_status == RoomStatus.connecting) return 'Ya hay una conexión en curso';
    if (name.trim().isEmpty) return 'Escribe tu nombre';
    await stopScan();

    _myName = RoomProtocol.cleanName(name);
    _mode = mode ?? _mode;
    _isHost = true;
    _roomName = roomName.trim();
    _isPublic = isPublic;
    _code = RoomProtocol.newCode();
    _myPeerId = 'host';
    _myRole = 'host';
    _lastError = null;
    _members.clear();

    final link = _linkFactory(_mode);
    await _teardown();
    _link = link;
    _wire(link);
    _status = RoomStatus.connecting;
    notifyListeners();

    try {
      await link.startHost(
        roomCode: _code,
        myName: _myName,
        roomName: _roomName,
        isPublic: _isPublic,
      );
      // BT falla por stream (serverStart false → status error): se le da un
      // instante para que llegue antes de declarar victoria.
      await Future<void>.delayed(const Duration(milliseconds: 400));
      if (_status == RoomStatus.error) {
        final reason = _lastError ?? 'No se pudo crear la sala';
        await leave();
        return reason;
      }
      _status = RoomStatus.connected;
      _snapshot = _sanitizedCart();
      attachStoreListener();
      _startTimers();
      notifyListeners();
      return null;
    } catch (e) {
      await leave();
      _lastError = RoomProtocol.errorMessage(
          e is Exception && '$e'.length < 40 ? '$e' : 'bt_connect');
      // Mensaje humano si el Exception trae un reason conocido.
      final raw = '$e'.replaceAll('Exception: ', '');
      _lastError = RoomProtocol.errorMessage(raw) == 'Error: $raw'
          ? 'No se pudo crear la sala: revisa Bluetooth/red'
          : RoomProtocol.errorMessage(raw);
      notifyListeners();
      return _lastError;
    }
  }

  /// Se une a una sala por código (o a un anuncio del escaneo). Solo hay
  /// éxito cuando el ANFITRIÓN contestó con `welcome` — sin salas fantasma.
  Future<String?> join({
    required String name,
    required String code,
    RoomMode? mode,
    RoomAd? ad,
  }) async {
    if (_status == RoomStatus.connecting) return 'Ya hay una conexión en curso';
    if (name.trim().isEmpty) return 'Escribe tu nombre';
    final c = code.trim().toUpperCase();
    if (c.length < 4) return 'El código de la sala tiene 6 letras';
    await stopScan();

    _myName = RoomProtocol.cleanName(name);
    _mode = ad?.mode ?? mode ?? _mode;
    _isHost = false;
    _code = ad?.code ?? c;
    _roomName = ad?.roomName ?? '';
    _isPublic = true;
    _myPeerId = '';
    _myRole = 'editor';
    _lastError = null;
    _members.clear();

    final link = _linkFactory(_mode);
    await _teardown();
    _link = link;
    _wire(link);
    _status = RoomStatus.connecting;
    notifyListeners();

    try {
      await link.dial(
        roomCode: _code,
        myName: _myName,
        host: ad?.host,
        port: ad?.port,
        endpointId: ad?.endpointId,
      );
      // Enlace a nivel transporte (BT puede tardar por el emparejamiento).
      final linked = await _waitForStatus(link, _dialTimeout());
      if (!linked) {
        await leave();
        return _mode == RoomMode.bt
            ? RoomProtocol.errorMessage('bt_timeout')
            : 'No se encontró esa sala';
      }
      // Handshake: hello → welcome. Sin respuesta del anfitrión no hay sala.
      _welcome = Completer<String?>();
      await link.send('hello', {'code': _code, 'name': _myName});
      final err = await _welcome!.future.timeout(
        const Duration(seconds: 10),
        onTimeout: () => 'El anfitrión no respondió (¿código correcto?)',
      );
      _welcome = null;
      if (err != null) {
        await leave();
        return err;
      }
      attachStoreListener();
      _startTimers();
      notifyListeners();
      return null;
    } catch (e) {
      await leave();
      final raw = '$e'.replaceAll('Exception: ', '');
      final human = RoomProtocol.errorMessage(raw);
      return human == 'Error: $raw'
          ? 'No se pudo conectar: $raw'
          : human;
    }
  }

  /// Plazo del enlace por modo (BT: emparejamiento hasta 45 s).
  Duration _dialTimeout() => switch (_mode) {
        RoomMode.bt => const Duration(seconds: 50),
        RoomMode.cerca => const Duration(seconds: 25),
        RoomMode.wifi => const Duration(seconds: 15),
      };

  /// Espera a que el enlace quede conectado o falle dentro del plazo.
  Future<bool> _waitForStatus(RoomLink link, Duration timeout) async {
    if (link.status == RoomStatus.connected) return true;
    if (link.status == RoomStatus.error) return false;
    final c = Completer<bool>();
    late final StreamSubscription<RoomStatus> sub;
    sub = link.statusStream.listen((s) {
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

  // ── Cableado del enlace ───────────────────────────────────────────────────

  void _wire(RoomLink link) {
    _sub = link.events.listen(_onEvent);
    _statusSub = link.statusStream.listen((s) {
      if (s == RoomStatus.error && _status == RoomStatus.connected && !_isHost) {
        // Invitado conectado cuyo enlace murió: host_lost honesto, no limbo.
        _lastError = RoomProtocol.errorMessage('host_lost');
        _store.pushNotification(
            kind: NotifKind.info,
            title: 'Se perdió al anfitrión',
            body: 'La sala se cerró. Vuelve a la lista.');
        unawaited(leave());
        return;
      }
      // El ANFITRIÓN vive con su enlace. El INVITADO NO: su estado de sala
      // solo cambia con welcome/room_error (el «conectado» del transporte es
      // apenas el cable — sin la confirmación del anfitrión no hay sala).
      if (_isHost) _status = s;
      notifyListeners();
    });
  }

  // ── Eventos entrantes (protocolo v19) ─────────────────────────────────────

  void _onEvent(RoomEvent ev) {
    final fromId = '${ev.payload['fromId'] ?? ''}';
    if (fromId.isNotEmpty) _touch(fromId);
    switch (ev.type) {
      // ── Anfitrión: un invitado llama a la puerta ──
      case 'hello' when _isHost:
        _hostOnHello(fromId, ev.payload);

      case 'ping' when _isHost:
        _touch(fromId);

      case 'typing':
        if (_isHost && fromId.isNotEmpty) {
          _typingUntilMs[fromId] = _nowMs + _typingMs;
        }

      // ── Invitado: la sala existe ──
      case 'welcome':
        _onWelcome(ev.payload);

      case 'members':
        _applyMembers(ev.payload['members']);

      case 'room_renamed':
        final n = '${ev.payload['name'] ?? ''}'.trim();
        if (n.isNotEmpty) _roomName = n;

      case 'room_closed':
        final reason = '${ev.payload['reason'] ?? 'closed'}';
        _lastError = reason == 'purchase'
            ? 'La compra se cerró: la sala terminó'
            : 'El anfitrión cerró la sala';
        _store.pushNotification(
            kind: NotifKind.info,
            title: 'La sala se cerró',
            body: reason == 'purchase'
                ? 'La compra se guardó y la sala terminó. Vuelve a la lista.'
                : 'El anfitrión terminó la sala.');
        unawaited(leave());

      case 'role_change':
        final id = '${ev.payload['id'] ?? ''}';
        final role = '${ev.payload['role'] ?? 'editor'}';
        if (id.isNotEmpty && ['editor', 'viewer'].contains(role)) {
          final m = _members.where((x) => x.id == id).firstOrNull;
          if (m != null) m.role = role;
        }

      case 'your_role':
        final role = '${ev.payload['role'] ?? 'editor'}';
        if (['editor', 'viewer'].contains(role)) {
          _myRole = role;
          _store.pushNotification(
              kind: NotifKind.info,
              title: role == 'viewer' ? 'Ahora eres observador' : 'Ahora puedes editar',
              body: role == 'viewer'
                  ? 'Puedes VER la lista, pero no modificarla.'
                  : 'El anfitrión te devolvió la edición de la lista.');
        }

      case 'kicked':
        _lastError = RoomProtocol.errorMessage('kicked');
        unawaited(leave());

      case 'item_add' || 'item_update' || 'item_remove' || 'list_clear' || 'list_replace':
        _suppress = true;
        _store.applyRemoteRoomEvent(ev.type, ev.payload);
        _suppress = false;
        // El anfitrión valida y retransmite al resto (rol de server).
        if (_isHost) {
          if (ev.type == 'item_add') {
            final item = RoomProtocol.sanitizeItem(
                ev.payload['item'], fromId.isNotEmpty ? fromId : 'host');
            if (item == null) {
              if (fromId.isNotEmpty) {
                unawaited(_link?.sendTo(fromId, 'room_error', {'reason': 'bad_item'}));
              }
              return;
            }
            _relay(ev.type, {'item': item, 'byId': fromId}, fromId);
          } else {
            _relay(ev.type, ev.payload, fromId);
          }
        }

      case 'member_left':
        // El enlace vio caer a un par (solo importa del lado del anfitrión).
        if (_isHost) {
          final id = fromId.isNotEmpty ? fromId : '${ev.payload['id'] ?? ''}';
          if (id.isEmpty || id == 'host') return;
          _dropMember(id);
        }

      case 'room_error':
        final reason = '${ev.payload['reason'] ?? 'error'}';
        if (_welcome != null && !_welcome!.isCompleted) {
          _welcome!.complete(RoomProtocol.errorMessage(reason));
          return;
        }
        _status = RoomStatus.error;
        _lastError = RoomProtocol.errorMessage(reason);
    }
    notifyListeners();
  }

  /// Anfitrión: valida código y cupo, asigna rol y entrega el estado COMPLETO.
  Future<void> _hostOnHello(String fromId, Map<String, dynamic> p) async {
    if (fromId.isEmpty) return;
    final code = '${p['code'] ?? ''}'.trim().toUpperCase();
    if (code != _code) {
      await _link?.sendTo(fromId, 'room_error', {'reason': 'not_found'});
      return;
    }
    if (_members.length >= RoomProtocol.maxMembers) {
      await _link?.sendTo(fromId, 'room_error', {'reason': 'room_full'});
      return;
    }
    if (_members.any((m) => m.id == fromId)) return; // ya dentro
    final name = RoomProtocol.cleanName('${p['name'] ?? ''}');
    _members.add(RoomMember(id: fromId, name: name, role: 'editor'));
    _lastSeenMs[fromId] = _nowMs;
    await _link?.sendTo(fromId, 'welcome', {
      'code': _code,
      'roomName': _roomName,
      'you': fromId,
      'yourRole': 'editor',
      'members': _allMembers(),
      'items': _sanitizedCart(),
    });
    _broadcast('members', {'members': _allMembers()});
    _store.pushNotification(
        kind: NotifKind.info,
        title: 'Se unió $name',
        body: '${_members.length + 1} personas en la sala.');
  }

  /// Invitado: el anfitrión entregó la sala completa — AHORA está en sala.
  void _onWelcome(Map<String, dynamic> p) {
    if (_isHost) return;
    _code = '${p['code'] ?? _code}';
    _roomName = '${p['roomName'] ?? ''}';
    final you = '${p['you'] ?? ''}';
    if (you.isNotEmpty) _myPeerId = you;
    _myRole = '${p['yourRole'] ?? 'editor'}';
    _applyMembers(p['members']);
    _suppress = true;
    _store.applyRemoteRoomEvent(
        'list_replace', {'items': (p['items'] as List?) ?? const []});
    _suppress = false;
    _status = RoomStatus.connected;
    if (_welcome != null && !_welcome!.isCompleted) _welcome!.complete(null);
    unawaited(flushOutbox());
  }

  void _applyMembers(dynamic raw) {
    _members
      ..clear()
      ..addAll(((raw as List?) ?? const [])
          .whereType<Map>()
          .map((m) => RoomMember.fromMap(Map<String, dynamic>.from(m))));
  }

  /// Lista completa de miembros (anfitrión incluido) para difusión.
  List<Map<String, dynamic>> _allMembers() => [
        {'id': 'host', 'name': _myName, 'role': 'host', 'online': true},
        for (final m in _members)
          {'id': m.id, 'name': m.name, 'role': m.role, 'online': m.online},
      ];

  void _relay(String type, Map<String, dynamic> payload, String fromId) {
    // Copia: los sends abren microtasks y otro evento puede mutar la lista
    // mientras se recorre (concurrencia de hello's simultáneos).
    for (final m in [..._members]) {
      if (m.id == fromId) continue;
      unawaited(_link?.sendTo(m.id, type, payload));
    }
  }

  void _dropMember(String id) {
    final m = _members.where((x) => x.id == id).firstOrNull;
    _members.removeWhere((x) => x.id == id);
    _lastSeenMs.remove(id);
    _typingUntilMs.remove(id);
    if (m != null) {
      _broadcast('members', {'members': _allMembers()});
      _store.pushNotification(
          kind: NotifKind.info,
          title: '${m.name} se fue',
          body: '${_members.length + 1} personas en la sala.');
    }
  }

  // ── Timers: ping del invitado · barrido del anfitrión ─────────────────────

  void _startTimers() {
    _pingTimer?.cancel();
    _sweepTimer?.cancel();
    if (!_isHost) {
      _pingTimer = Timer.periodic(const Duration(seconds: 8), (_) {
        if (connected) unawaited(_link?.send('ping', {}));
      });
    } else {
      _lastSeenMs
        ..clear()
        ..['host'] = _nowMs;
      _sweepTimer = Timer.periodic(const Duration(seconds: 5), (_) => _sweep());
    }
  }

  /// Anfitrión: presencia (silencio > 30 s fuera) + typing agregado.
  void _sweep() {
    if (!(_isHost && connected)) return;
    final now = _nowMs;
    _lastSeenMs['host'] = now;
    var changed = false;
    for (final m in [..._members]) {
      final t = _lastSeenMs[m.id];
      if (t == null || now - t > _staleMs) {
        _dropMember(m.id);
        changed = true;
      } else {
        final online = m.online != false; // sigue vivo
        m.online = true;
        if (!online) changed = true;
      }
    }
    final typing = <String>[
      for (final m in _members)
        if ((_typingUntilMs[m.id] ?? 0) > now) m.name,
    ];
    if (changed) _broadcast('members', {'members': _allMembers()});
    if (typing.isNotEmpty) {
      _broadcast('typing', {'names': typing});
    }
    notifyListeners();
  }

  void _touch(String id) {
    if (id.isEmpty || id == 'host') return;
    _lastSeenMs[id] = _nowMs;
  }

  int get _nowMs => DateTime.now().millisecondsSinceEpoch;

  // ── Gobierno de la sala (v18.0 intacto) ───────────────────────────────────

  /// Anfitrión: renombra la sala (todos lo ven al instante).
  Future<void> renameRoom(String name) async {
    if (!canAdmin || !connected) return;
    final n = name.trim();
    if (n.isEmpty) return;
    _roomName = n.length > 32 ? n.substring(0, 32) : n;
    unawaited(_broadcast('room_renamed', {'name': _roomName}));
    notifyListeners();
  }

  /// Anfitrión: cierra la sala para todos (ellos vuelven solos a la Lista).
  Future<void> closeRoom({String reason = 'closed'}) async {
    if (!canAdmin || !connected) return;
    try {
      await _broadcast('room_closed', {'reason': reason});
    } finally {
      await leave();
    }
  }

  /// Anfitrión: cierra la sala al guardar una compra (auto-cierre v18.0).
  Future<void> closeAfterPurchase() async {
    if (!_isHost || !connected) return;
    try {
      await closeRoom(reason: 'purchase');
    } catch (_) {/* la compra manda */}
  }

  /// Anfitrión: saca a un miembro (solo a él; el resto sigue).
  Future<void> kickMember(String id) async {
    if (!canAdmin || !connected || id == 'host' || id == _myPeerId) return;
    await _link?.sendTo(id, 'kicked', {});
    _dropMember(id);
  }

  /// Anfitrión: cambia el rol de un miembro (editor ↔ viewer).
  Future<void> setMemberRole(String id, String role) async {
    if (!canAdmin || !connected || id == 'host') return;
    if (!['editor', 'viewer'].contains(role)) return;
    final m = _members.where((x) => x.id == id).firstOrNull;
    if (m == null || m.role == role) return;
    m.role = role;
    unawaited(_broadcast('role_change', {'id': id, 'role': role}, exclude: id));
    unawaited(_link?.sendTo(id, 'your_role', {'role': role}));
    notifyListeners();
  }

  // ── Acciones de la UI ─────────────────────────────────────────────────────

  /// Señal «escribiendo…» (el anfitrión la agrega y difunde).
  void sendTyping() {
    if (!connected) return;
    unawaited(_link?.send('typing', {'name': _myName}));
  }

  /// Empuja la lista local completa a la sala (list_replace §6).
  Future<void> pushMyList() async {
    if (!connected || isViewer) return;
    final items = _sanitizedCart();
    await _emit('list_replace', {'items': items, 'byId': myId});
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
      }, myId);

  List<Map<String, dynamic>> _sanitizedCart() =>
      _store.cart.map(_itemToMap).whereType<Map<String, dynamic>>().toList();

  /// Diff del store → item_add/item_update/item_remove. Las mutaciones
  /// REMOTAS llegan suprimidas y solo refrescan el snapshot.
  void _onStoreChanged() {
    final now = _sanitizedCart();
    final wasSuppressed = _suppress || !connected || _link == null;
    if (!wasSuppressed) {
      final prev = {for (final m in _snapshot) '${m['id']}': m};
      final next = {for (final m in now) '${m['id']}': m};
      for (final m in now) {
        final old = prev['${m['id']}'];
        if (old == null) {
          unawaited(_emit('item_add', {'item': m, 'byId': myId}));
        } else {
          final patch = <String, dynamic>{};
          for (final k in ['name', 'quantity', 'price', 'currency', 'checked', 'checkedBy']) {
            if (old[k] != m[k]) patch[k] = m[k];
          }
          if (patch.isNotEmpty) {
            unawaited(_emit('item_update', {'id': m['id'], 'patch': patch, 'byId': myId}));
          }
        }
      }
      for (final id in prev.keys) {
        if (!next.containsKey(id)) {
          unawaited(_emit('item_remove', {'id': id, 'byId': myId}));
        }
      }
    }
    _snapshot = now;
  }

  // ── Escaneo de salas cercanas (lobby) ─────────────────────────────────────

  /// Escanea salas del modo activo (públicas). BT re-descubre cada 12 s
  /// (Android corta el discovery solo).
  Future<void> startScan() async {
    if (_scanning || connected || _status == RoomStatus.connecting) return;
    _scanning = true;
    _foundRooms.clear();
    notifyListeners();
    switch (_mode) {
      case RoomMode.cerca:
        _nearScanner ??= NearbyHubImpl();
        await _nearAdSub?.cancel();
        _nearAdSub = _nearScanner!.roomAds.listen(_onAd);
        await _nearScanner!.startScan();
      case RoomMode.wifi:
        _lanScanner ??= LanHubImpl();
        await _lanAdSub?.cancel();
        _lanAdSub = _lanScanner!.roomAds.listen(_onAd);
        await _lanScanner!.startScan();
      case RoomMode.bt:
        _btScanner ??= BtHubImpl();
        await _btAdSub?.cancel();
        _btAdSub = _btScanner!.roomAds.listen(_onAd);
        await _btScanner!.startScan();
        _btRescanTimer?.cancel();
        _btRescanTimer = Timer.periodic(
            const Duration(seconds: 12), (_) => _btScanner?.startDiscovery());
    }
    _scanTimer?.cancel();
    _scanTimer = Timer.periodic(const Duration(seconds: 4), (_) => _pruneAds());
  }

  Future<void> stopScan() async {
    _scanTimer?.cancel();
    _scanTimer = null;
    _btRescanTimer?.cancel();
    _btRescanTimer = null;
    await _lanAdSub?.cancel();
    await _nearAdSub?.cancel();
    await _btAdSub?.cancel();
    _lanAdSub = null;
    _nearAdSub = null;
    _btAdSub = null;
    await _lanScanner?.stopScan();
    await _nearScanner?.stopScan();
    await _btScanner?.stopScan();
    if (_scanning) {
      _scanning = false;
      notifyListeners();
    }
  }

  void _onAd(Map<String, dynamic> ad) {
    final code = '${ad['code'] ?? ''}';
    if (code.isEmpty || code.length < 4) return;
    final isPublic = ad['pub'] == true || ad['pub'] == 1;
    if (!isPublic) return; // privadas: solo por código
    final via = '${ad['via'] ?? ''}';
    final mode = via == 'bt'
        ? RoomMode.bt
        : (via == 'lan' ? RoomMode.wifi : RoomMode.cerca);
    final built = RoomAd(
      mode: mode,
      code: code,
      roomName: '${ad['name'] ?? ''}',
      hostName: '${ad['host'] ?? ''}',
      isPublic: true,
      seen: DateTime.now(),
      host: '${ad['ip'] ?? ad['address'] ?? ''}',
      port: (ad['port'] as num?)?.toInt() ?? LanHubImpl.kTcpPort,
      endpointId: '${ad['endpointId'] ?? ''}',
    );
    final idx = _foundRooms.indexWhere((r) => r.key == built.key);
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

  // ── Emisión con outbox: sin conexión → encola ─────────────────────────────

  Future<void> _emit(String type, Map<String, dynamic> payload) async {
    // Gate de observador: un viewer VE la lista pero no la toca.
    if (isViewer &&
        (type.startsWith('item_') ||
            type == 'list_replace' ||
            type == 'list_clear')) {
      return;
    }
    if (_link == null || !connected) {
      _store.outbox.add({
        'type': type,
        ...payload,
        'code': _code,
        'queuedAt': DateTime.now().toIso8601String()
      });
      _store.persistOutbox();
      return;
    }
    if (RoomProtocol.tooLarge(payload)) return;
    await _link!.send(type, payload);
  }

  /// Envía a todos los pares (anfitrión), salvo [exclude] (pe. quien ya
  /// recibió el evento 1:1).
  Future<void> _broadcast(String type, Map<String, dynamic> payload,
      {String? exclude}) async {
    if (_link == null) return;
    if (_isHost) {
      // Copia: cada send abre microtasks y un hello simultáneo puede
      // mutar _members en medio de la iteración.
      for (final m in [..._members]) {
        if (exclude != null && m.id == exclude) continue;
        await _link!.sendTo(m.id, type, payload);
      }
    } else {
      await _link!.send(type, payload);
    }
  }

  /// Vacía el outbox al reconectar (contrato actual).
  Future<void> flushOutbox() async {
    if (!connected || _store.outbox.isEmpty || _link == null) return;
    final queue = [..._store.outbox];
    for (final msg in queue) {
      await _link!.send('${msg['type']}', msg);
      _store.outbox.remove(msg);
    }
    _store.persistOutbox();
  }

  Future<void> leave() async {
    _pingTimer?.cancel();
    _pingTimer = null;
    _sweepTimer?.cancel();
    _sweepTimer = null;
    _welcome = null;
    _store.removeListener(_onStoreChanged);
    await _teardown();
    _status = RoomStatus.disconnected;
    _members.clear();
    _myPeerId = '';
    _myRole = 'editor';
    _lastSeenMs.clear();
    _typingUntilMs.clear();
    _snapshot = const [];
    notifyListeners();
  }

  Future<void> _teardown() async {
    _sub?.cancel();
    _statusSub?.cancel();
    _sub = null;
    _statusSub = null;
    final l = _link;
    _link = null;
    try {
      await l?.disconnect();
    } catch (_) {}
  }

  /// Engancha el diff del store (al entrar en sala).
  void attachStoreListener() {
    _store.removeListener(_onStoreChanged);
    _store.addListener(_onStoreChanged);
    _snapshot = _sanitizedCart();
  }

  @override
  void dispose() {
    _pingTimer?.cancel();
    _sweepTimer?.cancel();
    _scanTimer?.cancel();
    _btRescanTimer?.cancel();
    _store.removeListener(_onStoreChanged);
    unawaited(stopScan());
    _sub?.cancel();
    _statusSub?.cancel();
    _link?.disconnect();
    super.dispose();
  }
}
