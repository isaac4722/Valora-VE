/// ─── Análisis · helpers puros (Task 7-i) ────────────────────────────────────
/// Cálculos puros del módulo Análisis (sin IO, sin widgets, testeables):
/// · Inflación personal de la CANASTA ponderada por costo (Σ qty × precio)
///   entre el «snapshot más antiguo común» y el último registro de cada uno.
/// · Promedio simple de PRODUCTOS con ≥2 registros en el rango.
/// · Serie de costo de la canasta (forward-fill honesto, nunca inventa días).
/// · Brecha diaria BCV↔paralelo (nunca divide por cero).
/// · Etiquetas de COBERTURA REAL (nunca «365 días» sin datos).
/// Reutiliza an.priceVariation (core/analytics.dart) para cada variación.
library;

import '../../core/analytics.dart' as an;
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../data/history_api.dart';

/// «12 feb» — día + mes abreviado es-VE (sin año).
String fmtDayShort(DateTime d) => '${d.day} ${fmtMesCorto(d.month)}';

/// «12 feb» o «12 feb 2025» si no es el año en curso (tooltips/paneles).
String fmtDayLabel(DateTime d) =>
    '${fmtDayShort(d)}${d.year == DateTime.now().year ? '' : ' ${d.year}'}';

/// Nombre del rango solicitado (chips del módulo: 1 M · 6 M · 1 Año · Máximo).
String rangeName(int days) => days <= 31
    ? '1 M'
    : days <= 190
    ? '6 M'
    : days <= 400
    ? '1 Año'
    : 'Máximo';

/// ¿[d] cae dentro del rango? Máximo (3650+) = sin corte.
bool _inRange(DateTime d, int days) =>
    days >= 3650 || d.isAfter(DateTime.now().subtract(Duration(days: days)));

/// Registros de [p] dentro del rango (conserva el orden asc del producto).
List<PriceRecord> recordsInRange(Product p, int days) =>
    p.records.where((r) => _inRange(r.date, days)).toList();

/// Variación % de un producto dentro del rango (primer vs último registro del
/// rango). Reutiliza an.priceVariation. null si no hay evidencia: <2 registros
/// o precio viejo ≤ 0 (no se inventa variación).
double? variationInRange(Product p, int days) {
  final rs = recordsInRange(p, days);
  if (rs.length < 2 || rs.first.price <= 0) return null;
  return an.priceVariation(rs.first.price, rs.last.price);
}

/// Desglose de un producto de la canasta dentro del rango.
typedef BasketBreak = ({
  String name,
  String productId,
  double pct,
  double oldPrice,
  double newPrice,
  int qty,
});

/// Último precio del producto en o antes de [day] (comparación por día
/// YYYY-MM-DD; los registros van asc). 0 si aún no tiene ninguno.
double _priceAt(Product p, DateTime day) {
  final key = SnapshotPoint.dayKey(day);
  PriceRecord? best;
  for (final r in p.records) {
    if (SnapshotPoint.dayKey(r.date).compareTo(key) <= 0) best = r;
  }
  return best?.price ?? 0;
}

/// Inflación personal de la CANASTA en el rango: variación ponderada del
/// costo (Σ qty × precio) entre el «snapshot más antiguo común» — el día MÁS
/// TARDÍO de los primeros registros, desde el que TODOS los productos medidos
/// tienen precio (forward-fill honesto) — y el último registro de cada uno.
/// Devuelve null si ningún producto de la canasta aporta evidencia medible.
({
  double pct,
  double oldCost,
  double newCost,
  DateTime fromAt,
  int measured,
  int skipped,
  List<BasketBreak> breaks,
})?
basketInflation(
  List<BasketItem> basket,
  List<Product> products, {
  required int days,
}) {
  final measured = <(Product, int, BasketBreak)>[]; // producto × qty × desglose
  var skipped = 0;
  for (final b in basket) {
    final p = products.where((x) => x.id == b.productId).firstOrNull;
    if (p == null) {
      skipped++;
      continue;
    }
    final rs = recordsInRange(p, days);
    if (rs.length < 2) {
      skipped++;
      continue;
    }
    final pct = variationInRange(p, days);
    if (pct == null) {
      skipped++;
      continue;
    }
    measured.add((
      p,
      b.quantity,
      (
        name: p.name,
        productId: p.id,
        pct: pct,
        oldPrice: rs.first.price,
        newPrice: rs.last.price,
        qty: b.quantity,
      ),
    ));
  }
  if (measured.isEmpty) return null;
  var common = DateTime.fromMillisecondsSinceEpoch(0);
  for (final (p, _, _) in measured) {
    final first = recordsInRange(p, days).first.date;
    if (first.isAfter(common)) common = first;
  }
  final oldCost = measured.fold<double>(
    0,
    (s, e) => s + e.$2 * _priceAt(e.$1, common),
  );
  final newCost = measured.fold<double>(0, (s, e) => s + e.$2 * e.$3.newPrice);
  if (oldCost <= 0) return null;
  return (
    pct: (newCost / oldCost - 1) * 100,
    oldCost: oldCost,
    newCost: newCost,
    fromAt: common,
    measured: measured.length,
    skipped: skipped,
    breaks: measured.map((e) => e.$3).toList(),
  );
}

/// Inflación de PRODUCTOS (todos, no solo la canasta) en el rango: promedio
/// SIMPLE de la variación de cada producto con ≥2 registros en el rango
/// (reutiliza an.priceVariation). null si no hay ninguno medible.
({double pct, int products})? productsInflation(
  List<Product> products, {
  required int days,
}) {
  final pcts = <double>[];
  for (final p in products) {
    final v = variationInRange(p, days);
    if (v != null) pcts.add(v);
  }
  if (pcts.isEmpty) return null;
  return (
    pct: pcts.fold<double>(0, (s, v) => s + v) / pcts.length,
    products: pcts.length,
  );
}

/// Serie del COSTO de la canasta (USD) en el rango: para cada día con
/// registro de cualquier producto medido (y hoy) suma qty × último precio
/// vigente por producto (forward-fill). Arranca en el «snapshot más antiguo
/// común»: antes de ese día la canasta incompleta NO se grafica.
List<({DateTime day, double cost, int items})> basketCostSeries(
  List<BasketItem> basket,
  List<Product> products, {
  required int days,
}) {
  final measured = <(Product, int)>[];
  for (final b in basket) {
    final p = products.where((x) => x.id == b.productId).firstOrNull;
    if (p == null) continue;
    if (recordsInRange(p, days).isEmpty) continue;
    measured.add((p, b.quantity));
  }
  if (measured.isEmpty) return const [];
  var common = DateTime.fromMillisecondsSinceEpoch(0);
  for (final (p, _) in measured) {
    final first = recordsInRange(p, days).first.date;
    if (first.isAfter(common)) common = first;
  }
  final cutoff = SnapshotPoint.dayKey(common);
  final dayKeys = <String>{SnapshotPoint.dayKey(DateTime.now())};
  for (final (p, _) in measured) {
    for (final r in recordsInRange(p, days)) {
      final k = SnapshotPoint.dayKey(r.date);
      if (k.compareTo(cutoff) >= 0) dayKeys.add(k);
    }
  }
  final out = <({DateTime day, double cost, int items})>[];
  for (final k in dayKeys.toList()..sort()) {
    final d = DateTime.parse(k);
    final cost = measured.fold<double>(
      0,
      (s, e) => s + e.$2 * _priceAt(e.$1, d),
    );
    out.add((day: d, cost: cost, items: measured.length));
  }
  return out;
}

/// Brecha % de un día (paralelo/BCV − 1). null si falta una de las dos tasas
/// ese día o si alguna es ≤ 0 — NUNCA divide por cero.
({double bcv, double parallel, double pct})? gapForDay(
  List<HistPoint> bcv,
  List<HistPoint> parallel,
  String day,
) {
  final b = bcv.where((p) => p.date == day).firstOrNull;
  final p = parallel.where((x) => x.date == day).firstOrNull;
  if (b == null || p == null || b.rate <= 0 || p.rate <= 0) return null;
  return (bcv: b.rate, parallel: p.rate, pct: (p.rate / b.rate - 1) * 100);
}

/// Etiqueta de COBERTURA REAL (§ etiquetas honestas):
/// «1 Año · 214 días con datos (paralelo desde 12 feb) · cobertura parcial».
/// [points] = puntos reales de la serie; [first] = primer día con datos;
/// [sinceSubject] opcional («paralelo», «canasta», «BCV»…). Si la serie cubre
/// menos que [requestedDays], lo dice: nunca inventa cobertura.
String coverageText({
  required String rangeLabel,
  required int requestedDays,
  required int points,
  DateTime? first,
  String? sinceSubject,
}) {
  if (points <= 0) return '$rangeLabel · sin datos aún';
  final partial = points < requestedDays ? ' · cobertura parcial' : '';
  final paren = first == null
      ? ''
      : ' (${sinceSubject == null ? 'desde' : '$sinceSubject desde'} ${fmtDayShort(first)})';
  return '$rangeLabel · $points días con datos$paren$partial';
}

// ── Rankings de compras (§9.7): por día de semana y por moneda ─────────────

/// Días de la semana es-VE (índice = DateTime.weekday − 1, lunes primero).
const List<String> kWeekdayLabels = [
  'Lun',
  'Mar',
  'Mié',
  'Jue',
  'Vie',
  'Sáb',
  'Dom',
];

/// Gasto por día de la semana (USD efectivo pagado, [Purchase.paidUSD]):
/// distribución Lun→Dom con total y número de compras. Orden cronológico;
/// el UI destaca el día con más gasto (el «ranking» honesto).
List<({String day, double totalUSD, int count})> weekdaySpend(
  List<Purchase> purchases,
) {
  final totals = List<double>.filled(7, 0);
  final counts = List<int>.filled(7, 0);
  for (final p in purchases) {
    final i = p.date.weekday - 1;
    if (i < 0 || i > 6) continue;
    totals[i] += p.paidUSD;
    counts[i]++;
  }
  return [
    for (var i = 0; i < 7; i++)
      (day: kWeekdayLabels[i], totalUSD: totals[i], count: counts[i]),
  ];
}

/// Gasto por moneda (lo que pagaste en CADA divisa, §9.7): suma de los
/// ítems del historial en su moneda original (precio original × cantidad)
/// con su equivalente USD (precio normalizado) para el ORDEN del ranking.
/// Devuelve [] si no hay ítems.
List<({String currency, double totalOriginal, double totalUSD, int items})>
currencySpend(List<Purchase> purchases) {
  final map = <String, ({double original, double usd, int items})>{};
  for (final p in purchases) {
    for (final it in p.items) {
      final cur = it.currency.toUpperCase();
      final prev = map[cur] ?? (original: 0.0, usd: 0.0, items: 0);
      map[cur] = (
        original: prev.original + it.originalPrice * it.quantity,
        usd: prev.usd + it.priceUSD * it.quantity,
        items: prev.items + 1,
      );
    }
  }
  final out =
      map.entries
          .map(
            (e) => (
              currency: e.key,
              totalOriginal: e.value.original,
              totalUSD: e.value.usd,
              items: e.value.items,
            ),
          )
          .toList()
        ..sort((a, b) => b.totalUSD.compareTo(a.totalUSD));
  return out;
}

// ── Proyección DAMP (§3.2/§9.7 · misma semántica que an.predictPrice) ──────

/// Proyección amortiguada sobre una serie diaria genérica (canasta, costo,
/// tasa): media por tramos entre puntos consecutivos amortiguada por
/// dampPhi (0.85) y acumulación LINEAL (v_k = último × (1 + diario × k)),
/// exactamente como el motor predictPrice de productos. <2 puntos o <4 días
/// de historia → null (estable, no se inventa tendencia).
({List<({DateTime day, double value})> points, double dailyPct})?
dampProjection(List<({DateTime day, double value})> series, {int days = 30}) {
  if (series.length < 2) return null;
  final sorted = [...series]..sort((a, b) => a.day.compareTo(b.day));
  final last = sorted.last;
  final first = sorted.first;
  if (last.day.difference(first.day).inDays < 4) return null;
  var sumDaily = 0.0;
  var segments = 0;
  for (var i = 1; i < sorted.length; i++) {
    final gap = sorted[i].day.difference(sorted[i - 1].day).inDays;
    if (gap <= 0 || sorted[i - 1].value <= 0) continue;
    final pct = (sorted[i].value / sorted[i - 1].value - 1);
    sumDaily += pct * an.dampPhi; // amortigua el momentum
    segments++;
  }
  if (segments == 0 || last.value <= 0) return null;
  final daily = sumDaily / segments;
  final points = <({DateTime day, double value})>[
    for (var k = 1; k <= days; k++)
      (
        day: last.day.add(Duration(days: k)),
        value: last.value * (1 + daily * k),
      ),
  ];
  return (points: points, dailyPct: daily * 100);
}

// ── Heatmap de devaluación (§9.7 · calendario 6 m) ─────────────────────────

/// % de devaluación DIARIA del BCV (subida de la tasa vs el día anterior
/// con datos). Serie asc por día; el primer punto no tiene anterior.
/// NUNCA divide por cero: días con tasa ≤ 0 se saltan.
List<({String day, double pct})> devaluationDaily(
  List<SnapshotPoint> bcvSeries,
) {
  final sorted = [...bcvSeries]..sort((a, b) => a.day.compareTo(b.day));
  final out = <({String day, double pct})>[];
  for (var i = 1; i < sorted.length; i++) {
    if (sorted[i - 1].rate <= 0 || sorted[i].rate <= 0) continue;
    out.add((
      day: sorted[i].day,
      pct: (sorted[i].rate / sorted[i - 1].rate - 1) * 100,
    ));
  }
  return out;
}

// ── CSV de brecha (§9.7 exportGapCsv) ──────────────────────────────────────

/// Filas de la brecha BCV↔paralelo por día (solo días con AMBAS tasas > 0;
/// brecha = paralelo/BCV − 1). Encabezado es-VE con ';' como el histórico.
List<List<String>> gapCsvRows(List<HistPoint> bcv, List<HistPoint> parallel) {
  final byDay = <String, ({double b, double p})>{};
  for (final h in bcv) {
    if (h.rate > 0) byDay[h.date] = (b: h.rate, p: byDay[h.date]?.p ?? 0);
  }
  for (final h in parallel) {
    if (h.rate > 0) {
      byDay[h.date] = (b: byDay[h.date]?.b ?? 0, p: h.rate);
    }
  }
  final rows = <List<String>>[
    ['Dia', 'BCV', 'Paralelo', 'Brecha %'],
  ];
  final days =
      byDay.entries.where((e) => e.value.b > 0 && e.value.p > 0).toList()
        ..sort((a, b) => a.key.compareTo(b.key));
  for (final e in days) {
    rows.add([
      e.key,
      e.value.b.toStringAsFixed(4),
      e.value.p.toStringAsFixed(4),
      ((e.value.p / e.value.b - 1) * 100).toStringAsFixed(2),
    ]);
  }
  return rows;
}

// ── Gastos de compras (v17.8 · ancla «Gastos» de Análisis) ─────────────────
// Finanzas se retiró como módulo: estos agregados puros alimentan la vista
// resumida de gastos con las COMPRAS de Lista (cero carga manual).

/// Gasto por mes calendario (USD efectivo pagado, [Purchase.paidUSD]):
/// buckets 'mmm/aa' de los últimos [months] meses, en ORDEN CRONOLÓGICO
/// (por fecha del bucket, nunca por la etiqueta — 'abr' < 'ene' alfabético
/// pero no en el calendario). Devuelve [] si no hay compras en la ventana.
List<({String month, double totalUSD, int count})> monthSpend(
  List<Purchase> purchases, {
  int months = 6,
}) {
  final now = DateTime.now();
  final first = DateTime(now.year, now.month - (months - 1), 1);
  final map = <String, ({double total, int count, DateTime bucket})>{};
  for (final p in purchases) {
    if (p.date.isBefore(first)) continue;
    final bucket = DateTime(p.date.year, p.date.month, 1);
    final key = '${fmtMesCorto(bucket.month)}/${bucket.year % 100}';
    final prev = map[key];
    map[key] = (
      total: (prev?.total ?? 0) + p.paidUSD,
      count: (prev?.count ?? 0) + 1,
      bucket: bucket,
    );
  }
  final entries = map.entries.toList()
    ..sort((a, b) => a.value.bucket.compareTo(b.value.bucket));
  return [
    for (final e in entries)
      (month: e.key, totalUSD: e.value.total, count: e.value.count),
  ];
}

/// Gasto por tienda dentro de una lista de compras (USD efectivo):
/// top [limit] tiendas por total; el resto se agrupa en «Otras».
/// 'Sin tienda' bucket para compras sin nombre. Devuelve [] si no hay compras.
List<({String store, double totalUSD, int count})> storeSpend(
  List<Purchase> purchases, {
  int limit = 6,
}) {
  final map = <String, double>{};
  final counts = <String, int>{};
  for (final p in purchases) {
    final raw = (p.store ?? '').trim();
    // Multitienda: los ítems reparten su tienda cuando la compra no la tiene.
    if (raw.isEmpty && p.items.any((i) => (i.store ?? '').trim().isNotEmpty)) {
      for (final it in p.items) {
        final s = (it.store ?? '').trim();
        if (s.isEmpty) continue;
        map[s] = (map[s] ?? 0) + it.priceUSD * it.quantity;
        counts[s] = (counts[s] ?? 0) + 1;
      }
      continue;
    }
    final k = raw.isEmpty ? 'Sin tienda' : raw;
    map[k] = (map[k] ?? 0) + p.paidUSD;
    counts[k] = (counts[k] ?? 0) + 1;
  }
  final entries = map.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  if (entries.length <= limit) {
    return [
      for (final e in entries)
        (store: e.key, totalUSD: e.value, count: counts[e.key] ?? 0),
    ];
  }
  final top = entries.take(limit).toList();
  final restTotal = entries.skip(limit).fold<double>(0, (a, e) => a + e.value);
  final restCount = entries
      .skip(limit)
      .fold<int>(0, (a, e) => a + (counts[e.key] ?? 0));
  return [
    for (final e in top)
      (store: e.key, totalUSD: e.value, count: counts[e.key] ?? 0),
    (store: 'Otras', totalUSD: restTotal, count: restCount),
  ];
}
