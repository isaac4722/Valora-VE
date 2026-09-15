/// ─── Tablero de tasas en cliente (capa de DATOS) ────────────────────────────
/// Consulta directa con `dio` a las 4 regiones de DolarAPI (+ respaldo
/// pyDolarVenezuela), con reintentos anti-ráfaga, punto medio compra/venta,
/// degradación por región y diff de cambios para flashes/alertas. Sustituye
/// al middleware Next.js /api/rates: la app nativa habla directo con las
/// fuentes públicas.
library;

import 'dart:async';

import 'package:dio/dio.dart';

import 'package:valorave/core/models.dart';

final Dio _dio = () {
  final d = Dio(BaseOptions(
    connectTimeout: const Duration(seconds: 7),
    receiveTimeout: const Duration(seconds: 7),
    sendTimeout: const Duration(seconds: 7),
    headers: {
      'Accept': 'application/json',
      'User-Agent': 'ValoraVE/17 (Android)'
    },
    validateStatus: (s) => s != null && s < 500, // 4xx se maneja como dato
  ));
  d.interceptors.add(InterceptorsWrapper(
    onError: (e, handler) async {
      // Reintento único con backoff para 429/5xx/timeout (anti-ráfaga).
      final retriable = e.response == null ||
          (e.response?.statusCode ?? 0) >= 500 ||
          e.type == DioExceptionType.connectionTimeout;
      final tried = (e.requestOptions.extra['retried'] as bool?) ?? false;
      if (retriable && !tried) {
        final req = e.requestOptions;
        await Future.delayed(
            Duration(milliseconds: req.extra['attempt'] == 1 ? 1300 : 650));
        try {
          final res = await _fetchRaw(req.uri, attempt: 2);
          return handler.resolve(res);
        } catch (_) {/* cae al error original */}
      }
      return handler.next(e);
    },
  ));
  return d;
}();

Future<Response<dynamic>> _fetchRaw(Uri uri, {int attempt = 1}) async {
  final opts = Options()..extra = {'attempt': attempt, 'retried': attempt > 1};
  return _dio.getUri<dynamic>(uri, options: opts);
}

Future<dynamic> _fetchJson(Uri uri,
    {Duration timeout = const Duration(seconds: 7)}) async {
  final res = await _fetchJsonResponse(uri, timeout: timeout);
  return res.data;
}

Future<Response<dynamic>> _fetchJsonResponse(Uri uri,
    {Duration timeout = const Duration(seconds: 7)}) async {
  final res = await _dio.getUri<dynamic>(uri).timeout(timeout);
  if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
  return res;
}

class SourceEntryX {
  static RateEntry? entry(num? rate, [String? updatedAt]) {
    final r = (rate ?? 0).toDouble();
    if (!r.isFinite || r <= 0) return null;
    return RateEntry(
        rate: r, updatedAt: DateTime.tryParse(updatedAt ?? '') ?? DateTime.now());
  }
}

/// Punto medio compra/venta (o fix/valor/promedio).
double _mid(dynamic q) {
  if (q is! Map) return 0;
  double n(String k) =>
      ((q[k] as num?) ?? num.tryParse('${q[k]}') ?? 0).toDouble();
  final compra = n('compra') > 0 ? n('compra') : n('compraDolar');
  final venta = n('venta') > 0 ? n('venta') : n('ventaDolar');
  if (compra > 0 && venta > 0) return (compra + venta) / 2;
  if (venta > 0) return venta;
  if (compra > 0) return compra;
  return n('fix') > 0
      ? n('fix')
      : (n('valor') > 0 ? n('valor') : n('promedio'));
}

List<Map<String, dynamic>> _asList(dynamic v) => v is List
    ? v.whereType<Map<String, dynamic>>().toList()
    : (v is Map ? [Map<String, dynamic>.from(v)] : []);

/// Venezuela: USD oficial/paralelo + EUR oficial/paralelo (respaldo pyDolar).
Future<(Map<String, RateEntry>, List<String>)> _veBlock() async {
  final sources = <String, RateEntry>{};
  final errors = <String>[];
  try {
    final dolares =
        await _fetchJson(Uri.parse('https://ve.dolarapi.com/v1/dolares'));
    if (dolares is List) {
      for (final row in dolares.whereType<Map>()) {
        final fuente = '${row['fuente'] ?? ''}';
        final e = SourceEntryX.entry(
            row['promedio'] as num?, row['fechaActualizacion'] as String?);
        if (fuente == 'oficial' && e != null) sources['ves-bcv'] = e;
        if (fuente == 'paralelo' && e != null) sources['ves-parallel'] = e;
      }
    }
  } catch (e) {
    errors.add('ve.dolarapi/dolares: $e');
  }
  if (!sources.containsKey('ves-bcv') || !sources.containsKey('ves-parallel')) {
    try {
      final data = await _fetchJson(
          Uri.parse('https://pydolarve.org/api/v1/dollar'),
          timeout: const Duration(seconds: 4));
      final monitors = (data is Map ? data['monitors'] : null) as Map?;
      final bcv = monitors?['bcv'] as Map?;
      final paralelo = monitors?['enparalelovzla'] as Map?;
      final b = SourceEntryX.entry(bcv?['price'] as num?);
      final p = SourceEntryX.entry(paralelo?['price'] as num?);
      if (b != null) sources.putIfAbsent('ves-bcv', () => b);
      if (p != null) sources.putIfAbsent('ves-parallel', () => p);
    } catch (e) {
      errors.add('pydolarve (respaldo VE): $e');
    }
  }
  try {
    final euros =
        await _fetchJson(Uri.parse('https://ve.dolarapi.com/v1/euros'));
    if (euros is List) {
      for (final row in euros.whereType<Map>()) {
        final fuente = '${row['fuente'] ?? ''}';
        final e = SourceEntryX.entry(
            row['promedio'] as num?, row['fechaActualizacion'] as String?);
        if (fuente == 'oficial' && e != null) sources['eur-ves-oficial'] = e;
        if (fuente == 'paralelo' && e != null) sources['eur-ves-paralelo'] = e;
      }
    }
  } catch (e) {
    errors.add('ve.dolarapi/euros: $e');
  }
  return (sources, errors);
}

/// Colombia: TRM oficial + UNA sola consulta de cotizaciones (v19, orden del
/// dueño: un endpoint devuelve TODAS las monedas — no una llamada por cada
/// una). La lista trae USD y EUR (y más) con compra/venta: punto medio.
Future<(Map<String, RateEntry>, List<String>)> _coBlock() async {
  final sources = <String, RateEntry>{};
  final errors = <String>[];

  // 1) TRM oficial (Superfinanciera) — endpoint propio.
  try {
    final v = await _fetchJson(Uri.parse('https://co.dolarapi.com/v1/trm'));
    final e = SourceEntryX.entry(v is Map ? (v['valor'] as num?) : null,
        v is Map ? v['fechaActualizacion'] as String? : null);
    if (e != null) sources['cop-trm'] = e;
  } catch (err) {
    errors.add('cop-trm: $err');
  }

  // 2) TODAS las cotizaciones de mercado en UNA consulta (USD → cop-market,
  //    EUR → eur-cop).
  try {
    final rows = _asList(await _fetchJson(
        Uri.parse('https://co.dolarapi.com/v1/cotizaciones')));
    for (final q in rows) {
      final code = '${q['moneda'] ?? ''}';
      final e = SourceEntryX.entry(
          _mid(q), q['fechaActualizacion'] as String?);
      if (e == null) continue;
      if (code == 'USD') sources['cop-market'] = e;
      if (code == 'EUR') sources['eur-cop'] = e;
    }
  } catch (err) {
    errors.add('cotizaciones CO: $err');
  }
  return (sources, errors);
}

/// México: USD fix (Banxico vía DolarAPI).
Future<(Map<String, RateEntry>, List<String>)> _mxBlock() async {
  final sources = <String, RateEntry>{};
  final errors = <String>[];
  try {
    final v = await _fetchJson(
        Uri.parse('https://mx.dolarapi.com/v1/cotizaciones/usd'));
    final q = _asList(v).firstOrNull;
    final e = SourceEntryX.entry(_mid(q), q?['fechaActualizacion'] as String?);
    if (e != null) sources['mxn-banxico'] = e;
  } catch (err) {
    errors.add('mxn-banxico: $err');
  }
  return (sources, errors);
}

/// Brasil: UNA sola consulta con TODAS las cotizaciones (v19: USD y EUR
/// llegan juntos — antes eran dos llamadas).
Future<(Map<String, RateEntry>, List<String>)> _brBlock() async {
  final sources = <String, RateEntry>{};
  final errors = <String>[];
  try {
    final rows = _asList(
        await _fetchJson(Uri.parse('https://br.dolarapi.com/v1/cotacoes')));
    for (final q in rows) {
      final code = '${q['moeda'] ?? q['moneda'] ?? ''}';
      final e = SourceEntryX.entry(
          _mid(q), (q['dataAtualizacao'] ?? q['fechaActualizacion']) as String?);
      if (e == null) continue;
      if (code == 'USD') sources['brl-br'] = e;
      if (code == 'EUR') sources['eur-brl'] = e;
    }
  } catch (err) {
    errors.add('cotacoes BR: $err');
  }
  return (sources, errors);
}

class BoardResult {
  final RateBoard board;
  final List<String> changed;
  const BoardResult(this.board, this.changed);
}

const changeEps = 0.0005;

/// Consulta las 4 regiones en paralelo y compara contra [previous].
Future<BoardResult> fetchBoard([RateBoard? previous]) async {
  final results =
      await Future.wait([_veBlock(), _coBlock(), _mxBlock(), _brBlock()]);
  return _mergeBlocks(results, previous);
}

/// Fusión pura de bloques (testeable sin red).
BoardResult _mergeBlocks(
    List<(Map<String, RateEntry>, List<String>)> results, RateBoard? previous) {
  final sources = <String, RateEntry>{};
  final providers = <String>[];
  final degraded = <String>[];
  for (final (s, e) in results) {
    sources.addAll(s);
    degraded.addAll(e);
    if (s.isNotEmpty) providers.add('dolarapi.com');
  }
  final changed = <String>[];
  final prev = previous?.sources ?? const {};
  if (prev.isEmpty) {
    changed.addAll(sources.keys);
  } else {
    for (final e in sources.entries) {
      final before = prev[e.key];
      if (before == null) {
        changed.add(e.key);
      } else if ((e.value.rate - before.rate).abs() / before.rate > changeEps) {
        changed.add(e.key);
      }
    }
    for (final id in prev.keys) {
      if (!sources.containsKey(id)) changed.add(id);
    }
  }
  final now = DateTime.now();
  final board = RateBoard(
    sources: sources,
    providers: providers.toSet().toList(),
    degraded: degraded,
    lastUpdate: now,
    fetchedAt: now,
  );
  return BoardResult(board, changed);
}

/// ─── Diagnóstico de fuentes (mejora 8) ─────────────────────────────────────
/// Ping por región con latencia y número de fuentes obtenidas: Ajustes →
/// «Diagnóstico de fuentes» muestra qué está vivo y qué latencia tiene.
Future<List<RegionHealth>> diagnoseRegions() async {
  const blocks = [
    ('VE', 'Venezuela'),
    ('CO', 'Colombia'),
    ('MX', 'México'),
    ('BR', 'Brasil')
  ];
  final out = <RegionHealth>[];
  await Future.wait(blocks.map((b) async {
    final sw = Stopwatch()..start();
    int count = 0;
    String? error;
    try {
      final (sources, _) = switch (b.$1) {
        'VE' => await _veBlock(),
        'CO' => await _coBlock(),
        'MX' => await _mxBlock(),
        _ => await _brBlock(),
      };
      count = sources.length;
    } catch (e) {
      error = '$e';
    }
    sw.stop();
    out.add(RegionHealth(
      code: b.$1,
      label: b.$2,
      ok: count > 0,
      sources: count,
      latencyMs: sw.elapsedMilliseconds,
      error: error,
    ));
  }));
  out.sort((a, b) => a.code.compareTo(b.code));
  return out;
}

class RegionHealth {
  final String code;
  final String label;
  final bool ok;
  final int sources;
  final int latencyMs;
  final String? error;
  const RegionHealth(
      {required this.code,
      required this.label,
      required this.ok,
      required this.sources,
      required this.latencyMs,
      this.error});
}
