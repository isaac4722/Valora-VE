/// ─── Estado de la app: store + tema + ciclo de tasas ────────────────────────
/// Provider como DI (decisión cerrada). AppStore hidrata Hive al arrancar;
/// RatesPoller consulta las 4 regiones cada 60 s (autoRefresh) con apagado
/// idle tras 10 min en background, y alimenta snapshots 180 días.
library;

import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/models.dart';
import '../data/board.dart';
import '../data/rate_history.dart';
import '../data/sse_stream.dart';
import '../data/store.dart';
import '../room/room_controller.dart';
import '../services/alerts.dart';
import '../services/connectivity.dart';
import '../services/widget_service.dart';
import '../services/notifications.dart';

/// Controlador de tema (light/dark/system — vive FUERA de Settings, igual
/// que next-themes en la web: el modelo §1.8 no tiene theme).
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  /// Material You (dp6 · mejora 2): opt-in. Con true, Android 12+ tiñe
  /// botones/selección con la paleta del sistema armonizada; superficies y
  /// semántica de dinero siguen siendo tokens de marca (ver AppTheme).
  bool _dynamicColor = false;
  bool get dynamicColor => _dynamicColor;

  Future<void> load(SharedPreferences prefs) async {
    final s = prefs.getString('valorave.themeMode') ?? 'system';
    _mode = switch (s) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _dynamicColor = prefs.getBool('valorave.dynamicColor') ?? false;
    notifyListeners();
  }

  Future<void> setMode(ThemeMode m, SharedPreferences prefs) async {
    _mode = m;
    await prefs.setString('valorave.themeMode', switch (m) {
      ThemeMode.light => 'light',
      ThemeMode.dark => 'dark',
      _ => 'system',
    });
    notifyListeners();
  }

  Future<void> setDynamicColor(bool v, SharedPreferences prefs) async {
    _dynamicColor = v;
    await prefs.setBool('valorave.dynamicColor', v);
    notifyListeners();
  }
}

/// Ciclo de tasas: poll 60 s (respetando ahorro de datos), apagado idle 10
/// min, primero al arrancar. Emite flashes de cambios al AlertEngine.
/// OFFLINE REAL (v17.8): con [ConnectivityService] la señal de red manda —
/// sin red NO se consulta (cero timeouts de 7 s fingiendo carga), NO se
/// reintenta en bucle (se detiene el martilleo) y al volver la red se
/// refresca solo. SSE EN VIVO opcional (17.7): si settings.sseUrl apunta a
/// un despliegue web ValoraVE, el tablero también se empuja por
/// `/api/rates/stream` (push del servidor); el polling SIGUE como latido y
/// respaldo — si el stream muere, la app no se entera de nada malo.
class RatesPoller extends ChangeNotifier {
  RatesPoller(
    this._store,
    this._notifs,
    this._alerts, {
    ConnectivityService? connectivity,
  }) {
    _store.addListener(_onStoreChanged);
    _connectivity = connectivity;
    // Estado INICIAL de red (v17.8): si la app arranca SIN red no habrá
    // transición que escuchar — el flag nace con la verdad del día uno.
    _offlineNet = !(connectivity?.isOnline ?? true);
    _netSub = connectivity?.onLineChanged.listen(_onNetChanged);
  }

  final AppStore _store;
  final NotificationsService _notifs;
  final AlertEngine _alerts;
  ConnectivityService? _connectivity;
  StreamSubscription<bool>? _netSub;

  Timer? _timer;
  Timer? _idleTimer;
  bool _loading = false;
  bool _stale = false;
  bool _networkBlocked = false;
  bool _disposed = false;
  bool get loading => _loading;
  bool get stale => _stale;
  bool get networkBlocked => _networkBlocked;

  /// SIN red según connectivity_plus (v17.8). La app sigue funcionando con
  /// los datos guardados — esto solo calma las consultas y los estados.
  bool _offlineNet = false;
  bool get offlineNet => _offlineNet;

  /// Cambio de red (v17.8): sin red → se detiene el ciclo (nada de
  /// martillar 60 s contra un muro); con red → refresco inmediato si el
  /// usuario permite las consultas.
  void _onNetChanged(bool online) {
    if (_disposed) return;
    final changed = _offlineNet == online;
    _offlineNet = !online;
    if (online) {
      // Volvió la red: solo si el ciclo está permitido (modo offline ELEGIDO
      // y autoRefresh respetados — el dueño manda, no la red).
      if (!_store.settings.offlineMode && _store.settings.autoRefresh) {
        unawaited(refreshNow());
        startAuto();
      }
    } else {
      // Sin red: se cancela el latido (el stream SSE también se apaga —
      // _syncSse lo respeta).
      _timer?.cancel();
      _timer = null;
      _stopSse();
    }
    if (changed) notifyListeners();
  }

  // ── SSE en vivo (opcional) ──
  RatesStream? _sse;
  StreamSubscription<Map<String, dynamic>>? _sseSub;
  Timer? _sseRetry;
  String? _sseLiveUrl; // URL con la que el stream actual se abrió
  String? _sseSeenUrl; // última configuración vista (detecta cambios)
  bool _sseConnected = false;

  /// ¿El stream SSE está recibiendo tableros? (punto de estado en Ajustes)
  bool get sseConnected => _sseConnected;

  /// Reacciona a cambios de settings relevantes (sseUrl/offlineMode) sin
  /// reaccionar a cada mutación de productos/compras (comparación barata).
  void _onStoreChanged() {
    if (_disposed) return;
    final s = _store.settings;
    if (s.sseUrl != _sseSeenUrl) {
      _sseSeenUrl = s.sseUrl;
      _syncSse();
    }
  }

  /// Último fetch OK (§5 rate-health): null = jamás se vio el tablero vivo.
  DateTime? _lastBoardOk;
  DateTime? get lastBoardOk => _lastBoardOk;

  /// ¿Tasas viejas? SOLO si se vieron antes y llevan >15 min sin refrescar
  /// (regla §5: la caída se declara cuando hubo frescura y desapareció;
  /// sin primera vista no hay «caída», hay «sin datos» → networkBlocked).
  bool get rateStale =>
      _lastBoardOk != null &&
      DateTime.now().difference(_lastBoardOk!).inMinutes > 15;

  /// Última lista de fuentes cambiadas (para flashes del tablero).
  List<String> lastChanged = [];

  bool get offlineActive => _store.settings.offlineMode;

  /// Ingesta común de un tablero nuevo (poll o SSE): store + snapshots +
  /// alertas + widget BCV + reloj de frescura. Un solo camino, una sola
  /// verdad — el SSE nunca escribe por detrás del motor.
  void _ingestBoard(RateBoard board, List<String> changed) {
    _store.setRateBoard(board);
    lastChanged = changed;
    // Rate-health: fetch OK → reloj de frescura al día (§5).
    _lastBoardOk = DateTime.now();
    // Snapshots 180 días.
    appendSnapshots(_store.snapshots, board);
    _store.persistSnapshots();
    // Motor de alertas (spikes, metas, brecha, daily). El callback
    // persist escribe cada aviso al centro de notificaciones del store
    // (sin import ciclos: el engine solo recibe la función).
    _alerts.evaluate(
      store: _store,
      changed: changed,
      notifs: _notifs,
      persist: (kind, title, body) =>
          _store.pushNotification(kind: kind, title: title, body: body),
    );
    // Widget BCV 4×1 (home_widget).
    unawaited(
      WidgetService.updateBcv(
        bcv: board.sources['ves-bcv']?.rate,
        parallel: board.sources['ves-parallel']?.rate,
      ),
    );
    _networkBlocked = false;
  }

  /// Cambios vs el tablero vigente (misma regla changeEps del fetch).
  List<String> _changedVs(Map<String, RateEntry> next) {
    final prev = _store.board.sources;
    if (prev.isEmpty) return next.keys.toList();
    final out = <String>[];
    for (final e in next.entries) {
      final before = prev[e.key];
      if (before == null) {
        out.add(e.key);
      } else if (before.rate > 0 &&
          (e.value.rate - before.rate).abs() / before.rate > changeEps) {
        out.add(e.key);
      }
    }
    for (final id in prev.keys) {
      if (!next.containsKey(id)) out.add(id);
    }
    return out;
  }

  /// Abre/cierra el stream SSE según settings (idempotente).
  void _syncSse() {
    if (_disposed) return;
    final base = _store.settings.sseUrl;
    final url = base.isEmpty
        ? ''
        : '${base.replaceAll(RegExp(r'/+$'), '')}/api/rates/stream';
    if (url == _sseLiveUrl) return;
    _stopSse();
    // v17.8: sin red no se abre el stream (reintenta al volver la red).
    if (url.isEmpty || _store.settings.offlineMode || _offlineNet) return;
    _sseLiveUrl = url;
    _sse = RatesStream(dio: Dio(), url: url);
    _sseSub = _sse!.boards.listen(
      (board) {
        if (_disposed) return;
        // Payload del servidor web: {sources, providers, degraded}. Se
        // normaliza con el MISMO parser del store (ids desconocidos fuera,
        // tasas ≤ 0 fuera) y entra por la ingesta común.
        final sources = <String, RateEntry>{};
        final raw = board['sources'];
        if (raw is Map) {
          for (final e in raw.entries) {
            final v = e.value;
            if (v is Map) {
              final entry = RateEntry.tryParse(Map<String, dynamic>.from(v));
              if (entry != null) sources['$e.key'] = entry;
            }
          }
        }
        if (sources.isEmpty) return; // payload vacío: nada que ingerir
        final changed = _changedVs(sources);
        final now = DateTime.now();
        _ingestBoard(
          RateBoard(
            sources: sources,
            providers: const ['sse'],
            degraded: const [],
            lastUpdate: now,
            fetchedAt: now,
          ),
          changed,
        );
        if (!_sseConnected) {
          _sseConnected = true;
          notifyListeners();
        }
      },
      onDone: _sseDown,
      onError: (_) => _sseDown(),
    );
    _sse!.start();
  }

  /// El stream cayó: se apaga limpio y se reintenta más tarde mientras la
  /// URL siga configurada (el polling nunca dejó de correr). Reintento a
  /// 60 s si llegó a conectar; a 5 min si nunca conectó (no martilla un
  /// endpoint roto).
  void _sseDown() {
    if (_disposed) return;
    final wasConnected = _sseConnected;
    _stopSse();
    _sseConnected = false;
    if (wasConnected) notifyListeners();
    if (_store.settings.sseUrl.isEmpty || _store.settings.offlineMode) return;
    _sseRetry?.cancel();
    _sseRetry = Timer(
      wasConnected ? const Duration(seconds: 60) : const Duration(minutes: 5),
      () {
        _sseLiveUrl = null; // fuerza reapertura en _syncSse
        _syncSse();
      },
    );
  }

  void _stopSse() {
    _sseSub?.cancel();
    _sseSub = null;
    _sse?.stop();
    _sse = null;
    _sseRetry?.cancel();
    _sseRetry = null;
    _sseLiveUrl = null;
  }

  /// Reintento MANUAL (v17.8): el botón «Reintentar» nunca queda mudo —
  /// re-consulta la red AHORA y solo consulta las APIs si de verdad hay
  /// señal. Si la red volvió, la transición ya disparó el refresco solo.
  Future<void> retryNow() async {
    final c = _connectivity;
    if (c == null) return refreshNow(); // sin señal: ciclo clásico
    final wasOffline = _offlineNet;
    final online = await c.recheck();
    if (!online) {
      _offlineNet = true;
      notifyListeners(); // reconfirmado sin red: estado honesto al día
      return;
    }
    if (wasOffline) return; // la señal de transición ya refrescó
    return refreshNow();
  }

  Future<void> refreshNow() async {
    if (_loading) return;
    if (_store.settings.offlineMode) {
      // Modo offline total: ninguna consulta a APIs. Lo visible sale del
      // libro local + tasas manuales (v17.2, decisión del dueño).
      return;
    }
    if (_offlineNet) {
      // SIN red (v17.8): no se finge una carga de 7 s que va a fallar.
      // La UI muestra el estado offline honesto; la reconexión dispara
      // el refresco sola (_onNetChanged).
      return;
    }
    _loading = true;
    _stale = false;
    notifyListeners();
    try {
      final result = await fetchBoard(_store.board);
      _ingestBoard(result.board, result.changed);
    } catch (_) {
      // Sin red o fuente caída: la UI cae al tablero vivo + manuales,
      // y el banner de salud (rateStale) aparece cuando la última vista
      // OK envejece >15 min — NUNCA antes de haber visto el tablero.
      if (_store.board.isEmpty) _networkBlocked = true;
      _stale = true;
      // Reintento rápido SOLO si hay red (si la red se fue, la señal de
      // conectividad reposiciona el ciclo — no martillamos a ciegas).
      if (!_offlineNet) _scheduleNext(fast: true);
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  /// Temporizador AUTO-reprogramado: lee el intervalo real de settings en
  /// cada ciclo (v17.2 «consultas esporádicas» configurables por el dueño).
  /// En fallo de red reintenta a los 60 s como máximo (no espera 30 min) y
  /// en éxito espera el intervalo elegido.
  void _scheduleNext({bool fast = false}) {
    _timer?.cancel();
    if (!_store.settings.autoRefresh || _store.settings.offlineMode) return;
    final mins = _store.settings.pollMinutes.clamp(1, 60);
    final delay = fast || mins == 1
        ? const Duration(seconds: 60)
        : Duration(minutes: mins);
    _timer = Timer(delay, () async {
      await refreshNow();
      _scheduleNext();
    });
  }

  void startAuto() {
    if (_store.settings.offlineMode) return;
    _scheduleNext();
    _syncSse(); // SSE en vivo cuando hay URL configurada (17.7)
  }

  void stopAuto() {
    _timer?.cancel();
    _idleTimer?.cancel();
    _stopSse(); // idle/background: ni poll ni stream gastan batería
  }

  /// App en background: 10 min sin tocar → pausa (§5 pipeline).
  void markIdle() {
    _idleTimer?.cancel();
    _idleTimer = Timer(const Duration(minutes: 10), stopAuto);
  }

  void markActive() {
    _idleTimer?.cancel();
    startAuto();
  }

  @override
  void dispose() {
    _disposed = true;
    _store.removeListener(_onStoreChanged);
    _netSub?.cancel();
    _timer?.cancel();
    _idleTimer?.cancel();
    _stopSse();
    super.dispose();
  }
}

/// Raíz de proveedores de la app.
List<SingleChildWidget> appProviders({
  required AppStore store,
  required ThemeController theme,
  required NotificationsService notifs,
  required SharedPreferences prefs,
  ConnectivityService? connectivity,
}) {
  final alerts = AlertEngine(prefs);
  return [
    ChangeNotifierProvider.value(value: store),
    ChangeNotifierProvider.value(value: theme),
    Provider.value(value: notifs),
    Provider<SharedPreferences>.value(value: prefs),
    if (connectivity != null)
      Provider<ConnectivityService>.value(value: connectivity),
    ChangeNotifierProvider(
      create: (_) =>
          RatesPoller(store, notifs, alerts, connectivity: connectivity),
    ),
    Provider<AlertEngine>.value(value: alerts),
    // v18.0 · Sala Viva: controlador de APLICACIÓN — la Lista, la
    // configuración de sala y la Sala Viva comparten el MISMO estado.
    ChangeNotifierProvider(create: (_) => RoomController(store)),
  ];
}
