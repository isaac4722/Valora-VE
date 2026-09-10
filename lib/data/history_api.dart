/// ─── Histórico remoto de tasas (capa de DATOS, con dio) ────────────────────
/// VE/EUR: ve.dolarapi.com/v1/historicos · CO: datos.gov.co (TRM) ·
/// BRL/MXN: AwesomeAPI → Frankfurter (BCE). Caché en memoria de 10 min por
/// endpoint (como la web). Si todo falla, la UI cae a los snapshots locales
/// (RateHistory) — el gráfico nunca queda vacío, solo degradado.
library;

import 'package:dio/dio.dart';

// (independiente del store: solo dio)

final Dio _dio = Dio(BaseOptions(
  connectTimeout: const Duration(seconds: 9),
  receiveTimeout: const Duration(seconds: 9),
  headers: {'Accept': 'application/json', 'User-Agent': 'ValoraVE/17'},
  validateStatus: (s) => s != null && s < 500,
));

Future<dynamic> _fetch(Uri uri) async {
  final res = await _dio.getUri<dynamic>(uri);
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
  return res.data;
}

bool _ok(num? r) => r != null && r.isFinite && r > 0;
bool _isIsoDate(String s) => RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(s);

/// Punto de serie histórica (fecha ISO día + tasa).
class HistPoint {
  final String date; // YYYY-MM-DD
  final double rate;
  const HistPoint({required this.date, required this.rate});
}

class HistoryResult {
  final List<HistPoint> points;
  final String provider;
  const HistoryResult(this.points, this.provider);
}

/// Caché en memoria (10 min) por endpoint — el array crudo sirve a todas las
/// consultas del módulo Análisis sin repetir red.
final _cache = <String, (DateTime, HistoryResult)>{};

HistoryResult? _cached(String key) {
  final hit = _cache[key];
  if (hit == null) return null;
  if (DateTime.now().difference(hit.$1) > const Duration(minutes: 10)) {
    return null;
  }
  return hit.$2;
}

void _store(String key, HistoryResult r) => _cache[key] = (DateTime.now(), r);

/// Venezuela: USD (oficial/paralelo) o EUR (oficial/paralelo).
Future<HistoryResult> veHistory(
    {required bool eur, required bool paralelo, int days = 90}) async {
  final kind = eur ? 'euros' : 'dolares';
  final key = 've-$kind-${paralelo ? 'par' : 'of'}-$days';
  final cached = _cached(key);
  if (cached != null) return cached;
  final rows =
      await _fetch(Uri.parse('https://ve.dolarapi.com/v1/historicos/$kind'));
  if (rows is! List) throw Exception('formato inesperado');
  final fuente = paralelo ? 'paralelo' : 'oficial';
  final points = <HistPoint>[];
  for (final row in rows.whereType<Map>()) {
    final f = '${row['fuente'] ?? ''}';
    final fecha = '${row['fecha'] ?? ''}';
    if (f != fuente || !_isIsoDate(fecha)) continue;
    final rate = ((row['promedio'] as num?) ?? 0).toDouble();
    if (_ok(rate)) points.add(HistPoint(date: fecha, rate: rate));
  }
  if (points.isEmpty) throw Exception('serie vacía');
  final res = HistoryResult(
      points.sublist(points.length > days ? points.length - days : 0),
      've.dolarapi.com');
  _store(key, res);
  return res;
}

/// Colombia: TRM diaria (datos.gov.co · Socrata, público y sin clave).
Future<HistoryResult> copHistory(int days) async {
  final key = 'cop-$days';
  final cached = _cached(key);
  if (cached != null) return cached;
  final limit = days + 2 < 120 ? days + 2 : 120;
  final data = await _fetch(Uri.parse(
      'https://www.datos.gov.co/resource/32sa-8pi3.json?\$limit=$limit&\$order=vigenciadesde%20DESC'));
  if (data is! List) throw Exception('sin datos');
  final points = <HistPoint>[];
  for (final row in data.whereType<Map>()) {
    final rate = num.tryParse('${row['valor']}');
    final fecha = '${row['vigenciadesde'] ?? ''}';
    if (!_ok(rate) || fecha.length < 10) continue;
    points.add(
        HistPoint(date: fecha.substring(0, 10), rate: rate!.toDouble()));
  }
  if (points.isEmpty) throw Exception('TRM sin puntos');
  final res = HistoryResult(points.reversed.toList(), 'datos.gov.co · TRM');
  _store(key, res);
  return res;
}

/// BRL/MXN: AwesomeAPI con respaldo Frankfurter (BCE, gratis y sin clave).
Future<HistoryResult> dailyHistory(String pair, int days) async {
  final key = 'daily-$pair-$days';
  final cached = _cached(key);
  if (cached != null) return cached;
  // 1) AwesomeAPI
  try {
    final capped = days < 180 ? days : 180;
    final data = await _fetch(Uri.parse(
        'https://economia.awesomeapi.com.br/json/daily/USD-$pair/$capped'));
    if (data is List) {
      final points = <HistPoint>[];
      for (final row in data.whereType<Map>()) {
        final rate = num.tryParse('${row['bid']}');
        final ts = num.tryParse('${row['timestamp']}')?.toDouble();
        if (!_ok(rate) || ts == null || ts <= 0) continue;
        final date = DateTime.fromMillisecondsSinceEpoch((ts * 1000).round())
            .toIso8601String()
            .substring(0, 10);
        points.add(HistPoint(date: date, rate: rate!.toDouble()));
      }
      if (points.isNotEmpty) {
        final res =
            HistoryResult(points.reversed.toList(), 'AwesomeAPI · USD-$pair');
        _store(key, res);
        return res;
      }
    }
  } catch (_) {/* sigue a Frankfurter */}
  // 2) Frankfurter
  final start = DateTime.now()
      .subtract(Duration(days: days + 12))
      .toIso8601String()
      .substring(0, 10);
  final data = await _fetch(Uri.parse(
      'https://api.frankfurter.dev/v1/$start..?base=USD&symbols=$pair'));
  final byDate = data is Map ? data['rates'] : null;
  if (byDate is! Map) throw Exception('sin datos');
  final points = <HistPoint>[];
  byDate.forEach((date, rates) {
    final rate = rates is Map ? (rates[pair] as num?) : null;
    if (_isIsoDate('$date') && _ok(rate)) {
      points.add(HistPoint(date: '$date', rate: rate!.toDouble()));
    }
  });
  if (points.isEmpty) throw Exception('serie vacía');
  points.sort((a, b) => a.date.compareTo(b.date));
  final res = HistoryResult(points, 'Frankfurter (BCE) · $pair');
  _store(key, res);
  return res;
}

/// Serie de una divisa según su fuente seleccionada (para «Histórico de
/// divisas» del Análisis y la fecha histórica del Conversor).
Future<HistoryResult> seriesForSource(String sourceId, int days) async {
  return switch (sourceId) {
    'ves-bcv' => veHistory(eur: false, paralelo: false, days: days),
    'ves-parallel' => veHistory(eur: false, paralelo: true, days: days),
    'eur-ves-oficial' => veHistory(eur: true, paralelo: false, days: days),
    'eur-ves-paralelo' => veHistory(eur: true, paralelo: true, days: days),
    'cop-trm' => copHistory(days),
    'cop-market' => copHistory(days),
    'brl-br' => dailyHistory('BRL', days),
    'mxn-banxico' => dailyHistory('MXN', days),
    _ => throw Exception('sin serie para $sourceId'),
  };
}

/// Tasa de una fecha exacta (o del último día hábil anterior) — motor de la
/// «fecha histórica» del Conversor. Fuente: serie remota, respaldo snapshots.
Future<HistPoint?> rateOn(String sourceId, String date,
    {HistPoint? Function(String, String)? localFallback}) async {
  // Punto de hoy (viva) si la fecha es hoy.
  final res = await seriesForSource(sourceId, 180);
  for (var i = res.points.length - 1; i >= 0; i--) {
    if (res.points[i].date.compareTo(date) <= 0) return res.points[i];
  }

  return localFallback?.call(sourceId, date);
}
