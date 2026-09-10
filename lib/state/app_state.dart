/// ─── Estado de la app: store + tema + ciclo de tasas ────────────────────────
/// Provider como DI (decisión cerrada). AppStore hidrata Hive al arrancar;
/// RatesPoller consulta las 4 regiones cada 60 s (autoRefresh) con apagado
/// idle tras 10 min en background, y alimenta snapshots 180 días.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:nested/nested.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../data/board.dart';
import '../data/rate_history.dart';
import '../data/store.dart';
import '../services/alerts.dart';
import '../services/widget_service.dart';
import '../services/notifications.dart';

/// Controlador de tema (light/dark/system — vive FUERA de Settings, igual
/// que next-themes en la web: el modelo §1.8 no tiene theme).
class ThemeController extends ChangeNotifier {
  ThemeMode _mode = ThemeMode.system;
  ThemeMode get mode => _mode;

  Future<void> load(SharedPreferences prefs) async {
    final s = prefs.getString('valorave.themeMode') ?? 'system';
    _mode = switch (s) { 'light' => ThemeMode.light, 'dark' => ThemeMode.dark, _ => ThemeMode.system };
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
}

/// Ciclo de tasas: poll 60 s (respetando ahorro de datos), apagado idle 10
/// min, primero al arrancar. Emite flashes de cambios al AlertEngine.
class RatesPoller extends ChangeNotifier {
  RatesPoller(this._store, this._notifs, this._alerts);

  final AppStore _store;
  final NotificationsService _notifs;
  final AlertEngine _alerts;

  Timer? _timer;
  Timer? _idleTimer;
  bool _loading = false;
  bool _stale = false;
  bool _networkBlocked = false;
  bool get loading => _loading;
  bool get stale => _stale;
  bool get networkBlocked => _networkBlocked;

  /// Última lista de fuentes cambiadas (para flashes del tablero).
  List<String> lastChanged = [];

  Future<void> refreshNow() async {
    if (_loading) return;
    _loading = true;
    _stale = false;
    notifyListeners();
    try {
      final result = await fetchBoard(_store.board);
      _store.setRateBoard(result.board);
      lastChanged = result.changed;
      // Snapshots 180 días.
      appendSnapshots(_store.snapshots, result.board);
      _store.persistSnapshots();
      // Motor de alertas (spikes, metas, brecha, daily).
      _alerts.evaluate(
        store: _store,
        changed: result.changed,
        notifs: _notifs,
      );
      // Widget BCV 4×1 (home_widget).
      unawaited(WidgetService.updateBcv(
        bcv: result.board.sources['ves-bcv']?.rate,
        parallel: result.board.sources['ves-parallel']?.rate,
      ));
      _networkBlocked = false;
    } catch (_) {
      // Sin red o fuente caída: la UI cae al tablero vivo + manuales,
      // y a los 15 min el banner de salud aparece (stale).
      if (_store.board.isEmpty) _networkBlocked = true;
      _stale = true;
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  void startAuto() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 60), (_) {
      if (!_store.settings.autoRefresh) return;
      refreshNow();
    });
  }

  void stopAuto() {
    _timer?.cancel();
    _idleTimer?.cancel();
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
    _timer?.cancel();
    _idleTimer?.cancel();
    super.dispose();
  }
}

/// Raíz de proveedores de la app.
List<SingleChildWidget> appProviders({
  required AppStore store,
  required ThemeController theme,
  required NotificationsService notifs,
  required SharedPreferences prefs,
}) {
  final alerts = AlertEngine(prefs);
  return [
    ChangeNotifierProvider.value(value: store),
    ChangeNotifierProvider.value(value: theme),
    Provider.value(value: notifs),
    Provider<SharedPreferences>.value(value: prefs),
    ChangeNotifierProvider(create: (_) => RatesPoller(store, notifs, alerts)),
    Provider<AlertEngine>.value(value: alerts),
  ];
}
