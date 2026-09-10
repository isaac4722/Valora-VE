/// ─── ValoraVE · Analítica pura (§3.2 + §4) ─────────────────────────────────
/// Proyección de precios, inflación personal, timeline de tasas, devaluación,
/// totales de carrito sin IGTF, vuelto y estadísticas de tiendas.
/// Todo puro: sin IO, testeable sin red ni Hive.
library;

import 'package:decimal/decimal.dart';

import 'currencies.dart';
import 'fmt.dart'; // fold()
import 'models.dart';

const double kTargetEps = 0.005; // tolerancia de meta (§9.4 TARGET_EPS)

/// Dinero exacto simple: toUSD del web (rate<=0 → 0).
double toUSD(double amount, double rate) {
  if (rate <= 0) return 0;
  return amount / rate;
}

/// cartTotals del web (§3.2): SIN IGTF — total == subtotal siempre en
/// compras nuevas. [usdOf] normaliza cada moneda a USD (motor activo).
/// Dinero exacto (§3.2 decimal.js): la suma se hace con Decimal y se
/// redondea a 6 decimales solo al salir (los USD normalizados pueden
/// necesitar 4+ decimales para el precio por unidad).
({double totalUSD, Map<String, double> byCurrency, int units})
    cartTotals(List<CartItem> cart, double Function(Currency c) usdOf) {
  final byCurrency = <String, Decimal>{};
  var totalUSD = Decimal.zero;
  var units = 0;
  for (final item in cart) {
    final line = Decimal.fromInt(item.quantity) * Decimal.parse(item.price.toString());
    byCurrency[item.currency] = (byCurrency[item.currency] ?? Decimal.zero) + line;
    final c = CurrencyX.from(item.currency);
    final u = usdOf(c);
    if (u > 0) {
      totalUSD += line / Decimal.parse(u.toString());
    }
    units += item.quantity;
  }
  return (
    totalUSD: (totalUSD.toDouble() * 1e6).roundToDouble() / 1e6,
    byCurrency: byCurrency.map((k, v) => MapEntry(k, (v.toDouble() * 1e6).roundToDouble() / 1e6)),
    units: units,
  );
}

/// Vuelto (§3.2 computeChange): {paid, diff, missing, change}.
/// Pagó en USD y/o Bs; la cuenta en Bs con la tasa activa.
/// División/multiplicación con Decimal para no arrastrar el error binario.
({double paid, double diff, double missing, double change}) computeChange({
  required double totalBS,
  required double paidUSD,
  required double paidBS,
  required double rate,
}) {
  if (rate <= 0) {
    return (paid: paidUSD + paidBS, diff: 0, missing: 0, change: 0);
  }
  final r = Decimal.parse(rate.toString());
  final totalUsd = Decimal.parse(totalBS.toString()) / r;
  final paidTotal = Decimal.parse(paidUSD.toString()) + Decimal.parse(paidBS.toString()) / r;
  final diff = paidTotal - totalUsd;
  if (diff < Decimal.zero) {
    return (paid: paidTotal.toDouble(), diff: diff.toDouble(), missing: -diff.toDouble(), change: 0);
  }
  return (paid: paidTotal.toDouble(), diff: diff.toDouble(), missing: 0, change: (diff * r).toDouble());
}

// ─── Precios: variación y proyección ───────────────────────────────────────

/// % de variación entre dos precios (>0 subió).
double priceVariation(double from, double to) {
  if (from <= 0) return 0;
  return (to / from - 1) * 100;
}

/// Variación total del historial (primero vs último).
double totalVariation(List<PriceRecord> records) {
  if (records.length < 2) return 0;
  return priceVariation(records.first.price, records.last.price);
}

/// Proyección (§3.2 predictPrice): subida media diaria; <2 records o <4 días
/// → estable (null). Devuelve precio proyectado a [days] días.
/// DAMP_PHI=0.85 amortigua el momentum (§9.7).
const double dampPhi = 0.85;

double? predictPrice(List<PriceRecord> records, {int days = 7}) {
  if (records.length < 2) return null;
  final last = records.last.date;
  final first = records.first.date;
  if (last.difference(first).inDays < 4) return null;
  // Media diaria por tramos entre registros consecutivos.
  var sumDaily = 0.0;
  var daysCount = 0;
  for (var i = 1; i < records.length; i++) {
    final gap = records[i].date.difference(records[i - 1].date).inDays;
    if (gap <= 0) continue;
    final pct = priceVariation(records[i - 1].price, records[i].price) / 100;
    sumDaily += pct * dampPhi; // amortigua
    daysCount++;
  }
  if (daysCount == 0) return null;
  final daily = sumDaily / daysCount;
  return records.last.price * (1 + daily * days);
}

/// Inflación personal (§3.2): en USD y su equivalente en Bs con [rateUSD].
({double usd, double? bs}) personalInflation(List<Product> products, {double? rateUSD}) {
  var usd = 0.0;
  var count = 0;
  for (final p in products) {
    if (p.records.length < 2) continue;
    usd += totalVariation(p.records);
    count++;
  }
  final usdAvg = count > 0 ? usd / count : 0.0;
  final bs = rateUSD != null && rateUSD > 0 ? usdAvg * rateUSD : null;
  return (usd: usdAvg, bs: bs);
}

/// Timeline de VES por día (dedupe día — la última gana, §3.2).
List<PriceRecord> vesRateTimeline(List<PriceRecord> records) {
  final byDay = <String, PriceRecord>{};
  for (final r in records) {
    byDay[SnapshotPoint.dayKey(r.date)] = r; // última gana
  }
  final out = byDay.values.toList()..sort((a, b) => a.date.compareTo(b.date));
  return out;
}

/// Devaluación VES: % entre primer y último punto + fechas.
({double pct, double from, double to, DateTime fromAt, DateTime toAt})?
    vesDevaluation(List<PriceRecord> timeline) {
  if (timeline.length < 2) return null;
  final first = timeline.first, last = timeline.last;
  if (first.price <= 0) return null;
  return (
    pct: (last.price / first.price - 1) * 100,
    from: first.price,
    to: last.price,
    fromAt: first.date,
    toAt: last.date,
  );
}

/// Precio en Bs del record con la tasa que usó al registrarse.
double recordPriceBS(PriceRecord r) => r.currency == 'VES'
    ? r.originalPrice
    : (r.rate > 0 ? r.price * r.rate : 0);

// ─── Metas de precio (§9.4) ────────────────────────────────────────────────

/// Estado de la meta del producto vs su último record en USD.
/// TARGET_EPS=0.005: bajo meta si last < target*(1-eps).
({bool met, double? pct}) computeTargetInfo(Product p) {
  final last = p.latestRecord;
  if (p.targetPrice == null || last == null || p.targetPrice! <= 0) {
    return (met: false, pct: null);
  }
  final pct = priceVariation(p.targetPrice!, last.price);
  return (met: last.price < p.targetPrice! * (1 - kTargetEps), pct: pct);
}

// ─── Tiendas (§4 stores.ts, tienda derivada pura) ──────────────────────────

/// Clave de normalización: NFD→lower→[^a-z0-9]→espacio (fold incluido).
String normalizeStoreKey(String s) {
  final folded = fold(s.trim().toLowerCase());
  return folded.replaceAll(RegExp(r'[^a-z0-9]'), ' ').trim();
}

/// Iniciales para el avatar (máx 2 letras).
String storeInitials(String name) {
  final words = name
      .trim()
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .take(2)
      .map((w) => w[0].toUpperCase())
      .join();
  return words.isEmpty ? 'TI' : words;
}

/// Estadísticas por tienda: total USD, nº compras, última fecha.
/// Bucket '' = «Sin tienda». Orden: total↓, compras↓, fecha↓.
List<({String store, double totalUSD, int count, DateTime? last})> storeStats(
    List<Purchase> purchases) {
  final map = <String, ({double total, int count, DateTime? last})>{};
  for (final p in purchases) {
    final key = p.store ?? '';
    final cur = map[key];
    map[key] = (
      total: (cur?.total ?? 0) + p.totalUSD,
      count: (cur?.count ?? 0) + 1,
      last: (cur?.last == null || (p.date.isAfter(cur!.last!))) ? p.date : cur.last,
    );
  }
  final out = map.entries
      .map((e) => (store: e.key, totalUSD: e.value.total, count: e.value.count, last: e.value.last))
      .toList()
    ..sort((a, b) {
      final byTotal = b.totalUSD.compareTo(a.totalUSD);
      if (byTotal != 0) return byTotal;
      final byCount = b.count.compareTo(a.count);
      if (byCount != 0) return byCount;
      return (b.last ?? DateTime(0)).compareTo(a.last ?? DateTime(0));
    });
  return out;
}

/// Detalle de una tienda (match trim exacto sobre compras, orden fecha↓).
List<Purchase> storeDetail(List<Purchase> purchases, String store) {
  final key = store.trim();
  final out = purchases.where((p) => (p.store ?? '').trim() == key).toList()
    ..sort((a, b) => b.date.compareTo(a.date));
  return out;
}

/// Último precio del producto por tienda (descarta quantity>1, barato primero).
List<({String store, double priceUSD, DateTime date})> productStorePrices(Product p) {
  final byStore = <String, PriceRecord>{};
  for (final r in p.records) {
    if (r.quantity > 1) continue;
    final s = r.store ?? '';
    final cur = byStore[s];
    if (cur == null || r.date.isAfter(cur.date)) byStore[s] = r;
  }
  final out = byStore.entries
      .map((e) => (store: e.key.isEmpty ? 'Sin tienda' : e.key, priceUSD: e.value.price, date: e.value.date))
      .toList()
    ..sort((a, b) => a.priceUSD.compareTo(b.priceUSD));
  return out;
}

/// Sugerencia pasiva de tienda similar (q<3 → [], nunca bloquea).
String? findSimilarStore(String query, List<String> stores) {
  final q = normalizeStoreKey(query);
  if (q.length < 3) return null;
  for (final s in stores) {
    if (normalizeStoreKey(s) == q) return s;
  }
  return null;
}

/// Tiendas presentes en catálogo + compras (para chips y sheet).
List<String> storesInUse(List<Product> products, List<Purchase> purchases) {
  final set = <String>{};
  for (final p in products) {
    for (final r in p.records) {
      if ((r.store ?? '').trim().isNotEmpty) set.add(r.store!.trim());
    }
  }
  for (final p in purchases) {
    if ((p.store ?? '').trim().isNotEmpty) set.add(p.store!.trim());
  }
  return set.toList()..sort();
}
