/// ─── AlertEngine · picos, metas, brecha, cambio diario (§7) ─────────────────
/// Reglas del web: spikes con cooldown 30 min/fuente y umbral
/// max(setting, 0.5 %); metas BCV/paralelo con histéresis (avisa 1 vez al
/// cruzar ≥target, rearma al bajar); brecha >15 %; cambio diario >5 %;
/// recordatorio diario. Umbrales en prefs (valorave.alert-thresholds) y
/// disparadas en valorave.alert-fired (~60 s dedupe).
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/currencies.dart';
import '../core/fmt.dart';
import '../core/models.dart';
import '../data/store.dart';
import 'notifications.dart';

/// Callback opcional para escribir cada aviso al centro de notificaciones
/// del store (AppStore.pushNotification). Se inyecta como función desde
/// app_state para no crear imports cíclicos y para que los caminos sin
/// store (workmanager en background) sigan funcionando igual que antes.
typedef AlertPersist = void Function(NotifKind kind, String title, String body);

class AlertEngine {
  AlertEngine(this._prefs) {
    _loadFired();
  }

  final SharedPreferences _prefs;
  final Map<String, DateTime> _fired = {};

  static const _kFired = 'valorave.alert-fired';
  static const _kThresholds = 'valorave.alert-thresholds';

  // Recordatorio diario (prefs, no modelo — igual que los coach-marks).
  static const _kReminderEnabled = 'valorave.reminder.enabled';
  static const _kReminderHour = 'valorave.reminder.hour';

  bool get reminderEnabled => _prefs.getBool(_kReminderEnabled) ?? false;
  int get reminderHour => _prefs.getInt(_kReminderHour) ?? 9;

  void setReminderEnabled(bool v) => _prefs.setBool(_kReminderEnabled, v);
  void setReminderHour(int h) => _prefs.setInt(_kReminderHour, h);

  /// Dispara el recordatorio diario: se llama desde evaluate() (app abierta,
  /// evaluado en cada ciclo del tablero) y desde la tarea horaria de
  /// workmanager (app cerrada — precisión ±1 h, honesta para un aviso de
  /// rutina). El claim por día evita duplicados entre ambos caminos.
  void reminderCheck(NotificationsService notifs, {DateTime? now, AlertPersist? persist}) {
    if (!reminderEnabled) return;
    final t = now ?? DateTime.now();
    if (t.hour != reminderHour) return;
    if (!_claim('reminder.${SnapshotPoint.dayKey(t)}')) return;
    _notify(
      notifs,
      kind: NotifKind.reminder,
      channelId: 'reminders',
      title: '¿Ya registraste los precios de hoy?',
      body: 'Un minuto en Productos mantiene tu libro al día '
          '(y tus metas de precio útiles).',
      persist: persist,
    );
  }

  double get gapThreshold => _prefs.getDouble('$_kThresholds.gap') ?? 15;
  double get dailyThreshold => _prefs.getDouble('$_kThresholds.daily') ?? 5;

  /// Umbral de subida de precio por PRODUCTO (v17.5): % mínimo de alza
  /// vs el último registro anterior para avisar. Default 10 %.
  double get productRiseThreshold =>
      _prefs.getDouble('$_kThresholds.product') ?? 10;

  void setThreshold(String key, double value) =>
      _prefs.setDouble('$_kThresholds.$key', value);

  void _loadFired() {
    final raw = _prefs.getStringList(_kFired) ?? const [];
    for (final item in raw) {
      final parts = item.split('|');
      if (parts.length == 2) {
        final at = DateTime.tryParse(parts[1]);
        if (at != null) _fired[parts[0]] = at;
      }
    }
  }

  void _saveFired() {
    _prefs.setStringList(
        _kFired, _fired.entries.map((e) => '${e.key}|${e.value.toIso8601String()}').toList());
  }

  /// Dedupe ~60 s por clave (antiduplicado del web §7).
  bool _claim(String key) {
    final now = DateTime.now();
    final last = _fired[key];
    if (last != null && now.difference(last).inSeconds < 60) return false;
    _fired[key] = now;
    // Poda: disparadas de más de 1 día.
    _fired.removeWhere((_, at) => now.difference(at).inMinutes > 1440);
    _saveFired();
    return true;
  }

  final Map<String, DateTime> _spikeCooldown = {};
  final Map<String, double> _baseline = {}; // fuente → última tasa vista

  /// Evaluación tras cada board (spikes solo con fuentes cambiadas).
  /// [persist] (opcional) escribe cada aviso también en el centro de
  /// notificaciones del store — mapeo 1:1 de kinds del §7: pico→spike,
  /// meta→target, brecha→gap, daily→daily, recordatorio→reminder.
  void evaluate({
    required AppStore store,
    required List<String> changed,
    required NotificationsService notifs,
    AlertPersist? persist,
  }) {
    final s = store.settings;
    final ctx = store.contextOf();
    final now = DateTime.now();

    // ── Picos (spikes) ──
    if (s.spikeAlerts) {
      final threshold = s.spikeThreshold < 0.5 ? 0.5 : s.spikeThreshold;
      for (final id in s.spikeWatch) {
        final rate = store.board.sources[id]?.rate;
        if (rate == null) continue;
        final base = _baseline[id] ?? rate;
        _baseline[id] = rate;
        if (base <= 0) continue;
        final pct = (rate / base - 1) * 100;
        if (pct.abs() < threshold) continue;
        final lastSpike = _spikeCooldown[id];
        if (lastSpike != null && now.difference(lastSpike).inMinutes < 30) continue;
        _spikeCooldown[id] = now;
        if (!_claim('spike.$id')) continue;
        final label = RateSource.of(id)?.label ?? id;
        _notify(
          notifs,
          kind: NotifKind.spike,
          channelId: 'rate_alerts',
          title: 'Pico en $label',
          body: 'La tasa de $label movió ${pct.toStringAsFixed(1)} % '
              '(de ${base.toStringAsFixed(2)} a ${rate.toStringAsFixed(2)}).',
          persist: persist,
        );
      }
    } else {
      // La baseline SIEMPRE avanza (§7).
      for (final id in s.spikeWatch) {
        final rate = store.board.sources[id]?.rate;
        if (rate != null) _baseline[id] = rate;
      }
    }

    // ── Metas de tasa (histéresis) ──
    _targetRate(notifs, 'bcv', 'ves-bcv', s.targetBcv, store, 'BCV', persist);
    _targetRate(notifs, 'parallel', 'ves-parallel', s.targetParallel, store, 'Paralelo', persist);

    // ── Brecha BCV↔Paralelo ──
    final gap = ctx.gapPct();
    if (gap != null && gap.abs() >= gapThreshold) {
      if (_claim('gap')) {
        _notify(
          notifs,
          kind: NotifKind.gap,
          channelId: 'rate_alerts',
          title: 'Brecha BCV ↔ Paralelo',
          body: 'La brecha está en ${gap.toStringAsFixed(1)} % '
              '(umbral ${gapThreshold.toStringAsFixed(0)} %).',
          persist: persist,
        );
      }
    }

    // ── Cambio del día (BCV vs snapshot de ayer) ──
    final today = SnapshotPoint.dayKey(now);
    final yesterday = SnapshotPoint.dayKey(now.subtract(const Duration(days: 1)));
    final t = store.snapshots.where((p) => p.sourceId == 'ves-bcv').toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    final todayP = t.where((p) => p.day == today).firstOrNull;
    final yestP = t.where((p) => p.day == yesterday).firstOrNull;
    if (todayP != null && yestP != null && yestP.rate > 0) {
      final pct = (todayP.rate / yestP.rate - 1) * 100;
      if (pct.abs() >= dailyThreshold && _claim('daily.$today')) {
        _notify(
          notifs,
          kind: NotifKind.daily,
          channelId: 'rate_alerts',
          title: 'Cambio del día en BCV',
          body: 'La tasa oficial movió ${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)} % hoy.',
          persist: persist,
        );
      }
    }

    // ── Recordatorio diario (app abierta) ──
    reminderCheck(notifs, now: now, persist: persist);
  }

  /// Subida de precio por producto (v17.5 · hueco real del consultor:
  /// «alertas de subida de precio»). Se llama tras registrar un precio
  /// nuevo (ficha de producto o checkout con producto vinculado): si el
  /// precio USD sube ≥ [productRiseThreshold] % vs el registro anterior,
  /// avisa por canal del sistema + centro de notificaciones. Dedupe por
  /// producto+day (claim 60 s del engine) para no molestar dos veces.
  void checkProductRise({
    required NotificationsService notifs,
    AlertPersist? persist,
    required String productId,
    required String productName,
    required double oldPrice,
    required double newPrice,
    String? storeName,
  }) {
    if (oldPrice <= 0 || newPrice <= 0) return;
    final pct = (newPrice / oldPrice - 1) * 100;
    if (pct < productRiseThreshold) return;
    if (!_claim(
        'product-rise.$productId.${SnapshotPoint.dayKey(DateTime.now())}')) {
      return;
    }
    final donde =
        (storeName == null || storeName.isEmpty) ? '' : ' en $storeName';
    _notify(
      notifs,
      kind: NotifKind.threshold,
      channelId: 'rate_alerts',
      title: 'Subió $productName',
      body: 'Nuevo precio ${fmtUSD(newPrice)}$donde · '
          '${fmtPct(pct)} vs el anterior (${fmtUSD(oldPrice)}).',
      persist: persist,
    );
  }

  /// Histéresis de metas: avisa una vez al cruzar, rearma al bajar.
  void _targetRate(NotificationsService notifs, String key, String sourceId,
      double? target, AppStore store, String label,
      [AlertPersist? persist]) {
    if (target == null || target <= 0) return;
    final rate = store.board.sources[sourceId]?.rate;
    if (rate == null || rate <= 0) return;
    final armed = _prefs.getBool('valorave.target-armed.$key') ?? true;
    if (rate >= target) {
      if (armed && _claim('target.$key')) {
        _prefs.setBool('valorave.target-armed.$key', false); // dispara y desarma
        _notify(
          notifs,
          kind: NotifKind.target,
          channelId: 'rate_alerts',
          title: '$label alcanzó tu meta',
          body: 'La tasa de $label llegó a ${rate.toStringAsFixed(2)} '
              '(meta ${target.toStringAsFixed(2)}).',
          persist: persist,
        );
      }
    } else {
      // Bajó de la meta: rearma para el próximo cruce.
      if (!armed) _prefs.setBool('valorave.target-armed.$key', true);
    }
  }

  /// Emite el aviso por el canal del sistema SIEMPRE, y además lo escribe
  /// al centro de notificaciones del store cuando hay callback [persist]
  /// (mismo kind/title/body — ver contrato AlertPersist).
  void _notify(
    NotificationsService notifs, {
    required NotifKind kind,
    required String channelId,
    required String title,
    required String body,
    AlertPersist? persist,
  }) {
    unawaited(notifs.show(channelId: channelId, title: title, body: body, tag: 'valorave-$kind'));
    persist?.call(kind, title, body);
    debugPrint('[alertas] $title · $body');
  }
}
