/// ─── Snapshots diarios de tasas (§4 rate-history.ts) ────────────────────────
/// Máx 180 días por fuente. appendSnapshots tras cada fetch OK (dedupe día:
/// la última gana), snapshotSeries(sourceId, days), mergeSeries (día gana
/// remoto), snapshotDepth (len bcv ?? parallel).
library;

import '../core/models.dart';

const int kMaxDays = 180;

/// Añade snapshots del board (dedupe día, última gana).
void appendSnapshots(List<SnapshotPoint> store, RateBoard board, {DateTime? now}) {
  now ??= DateTime.now();
  final day = SnapshotPoint.dayKey(now);
  for (final e in board.sources.entries) {
    final idx = store.indexWhere((p) => p.sourceId == e.key && p.day == day);
    final point = SnapshotPoint(sourceId: e.key, day: day, rate: e.value.rate);
    if (idx >= 0) {
      store[idx] = point; // última gana
    } else {
      store.add(point);
    }
  }
  _prune(store, now);
}

/// Poda a MAX_DAYS por fuente.
void _prune(List<SnapshotPoint> store, DateTime now) {
  final bySource = <String, List<SnapshotPoint>>{};
  for (final p in store) {
    (bySource[p.sourceId] ??= []).add(p);
  }
  final kept = <SnapshotPoint>[];
  for (final e in bySource.entries) {
    final days = e.value.toList()
      ..sort((a, b) => a.day.compareTo(b.day));
    if (days.length > kMaxDays) {
      days.removeRange(0, days.length - kMaxDays);
    }
    kept.addAll(days);
  }
  store
    ..clear()
    ..addAll(kept);
}

/// Serie de una fuente a [days] días (asc por día).
List<SnapshotPoint> snapshotSeries(List<SnapshotPoint> store, String sourceId, int days) {
  return store
      .where((p) => p.sourceId == sourceId)
      .toList()
      ..sort((a, b) => a.day.compareTo(b.day))
    ..removeWhere((p) => p.day.isEmpty);
}

/// mergeSeries: si el mismo día existe en remoto y local, GANA REMOTO.
List<SnapshotPoint> mergeSeries(List<SnapshotPoint> remote, List<SnapshotPoint> local) {
  final byKey = <String, SnapshotPoint>{};
  for (final p in local) {
    byKey['${p.sourceId}|${p.day}'] = p;
  }
  for (final p in remote) {
    byKey['${p.sourceId}|${p.day}'] = p; // remoto gana
  }
  return byKey.values.toList()
    ..sort((a, b) => a.day.compareTo(b.day));
}

/// Profundidad de historial disponible (len bcv ?? parallel, §4).
int snapshotDepth(List<SnapshotPoint> store) {
  final bcv = store.where((p) => p.sourceId == 'ves-bcv').length;
  if (bcv > 0) return bcv;
  return store.where((p) => p.sourceId == 'ves-parallel').length;
}
