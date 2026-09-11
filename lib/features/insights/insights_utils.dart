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
String rangeName(int days) =>
    days <= 31 ? '1 M' : days <= 190 ? '6 M' : days <= 400 ? '1 Año' : 'Máximo';

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
})? basketInflation(List<BasketItem> basket, List<Product> products,
    {required int days}) {
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
  final oldCost =
      measured.fold<double>(0, (s, e) => s + e.$2 * _priceAt(e.$1, common));
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
({double pct, int products})? productsInflation(List<Product> products,
    {required int days}) {
  final pcts = <double>[];
  for (final p in products) {
    final v = variationInRange(p, days);
    if (v != null) pcts.add(v);
  }
  if (pcts.isEmpty) return null;
  return (pct: pcts.fold<double>(0, (s, v) => s + v) / pcts.length,
      products: pcts.length);
}

/// Serie del COSTO de la canasta (USD) en el rango: para cada día con
/// registro de cualquier producto medido (y hoy) suma qty × último precio
/// vigente por producto (forward-fill). Arranca en el «snapshot más antiguo
/// común»: antes de ese día la canasta incompleta NO se grafica.
List<({DateTime day, double cost, int items})> basketCostSeries(
    List<BasketItem> basket, List<Product> products,
    {required int days}) {
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
    final cost = measured.fold<double>(0, (s, e) => s + e.$2 * _priceAt(e.$1, d));
    out.add((day: d, cost: cost, items: measured.length));
  }
  return out;
}

/// Brecha % de un día (paralelo/BCV − 1). null si falta una de las dos tasas
/// ese día o si alguna es ≤ 0 — NUNCA divide por cero.
({double bcv, double parallel, double pct})? gapForDay(
    List<HistPoint> bcv, List<HistPoint> parallel, String day) {
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
