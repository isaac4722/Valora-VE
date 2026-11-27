/// ─── Tablero de tasas en cliente (capa de DATOS) ────────────────────────────
/// Consulta directa con `dio` a las 4 regiones de DolarAPI con RESPALDO por
/// región si cae (v19.0, orden del dueño): VE → DolarVZLA (rates.dolarvzla.com,
/// v21.3 — pydolarve.org caducó 07/2025 y ya resuelve NXDOMAIN) · CO →
/// Superfinanciera (datos.gov.co) + AwesomeAPI · MX → Frankfurter · BR →
/// AwesomeAPI. Reintentos anti-ráfaga, punto medio compra/venta, degradación
/// por región y diff de cambios para flashes/alertas. Sustituye al middleware
/// Next.js /api/rates: la app nativa habla directo con las fuentes públicas.
library;

import 'dart:async';

import 'package:dio/dio.dart';

import 'package:valorave/core/models.dart';
import 'package:valorave/services/ve_log.dart';

final Dio _dio = () {
  final d = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 7),
      receiveTimeout: const Duration(seconds: 7),
      sendTimeout: const Duration(seconds: 7),
      headers: {
        'Accept': 'application/json',
        'User-Agent': 'ValoraVE/17 (Android)',
      },
      validateStatus: (s) => s != null && s < 500, // 4xx se maneja como dato
    ),
  );
  d.interceptors.add(
    InterceptorsWrapper(
      onError: (e, handler) async {
        // Reintento único con backoff para 429/5xx/timeout (anti-ráfaga).
        // v23.3 (pez 2-b): las CANCELACIONES no se reintentan — el timeout
        // de _fetchJsonResponse cancela el token y un retry sería una
        // segunda petición fantasma sobre la misma URL.
        final retriable =
            e.type != DioExceptionType.cancel &&
            (e.response == null ||
                (e.response?.statusCode ?? 0) >= 500 ||
                e.type == DioExceptionType.connectionTimeout);
        final tried = (e.requestOptions.extra['retried'] as bool?) ?? false;
        if (retriable && !tried) {
          await Future.delayed(const Duration(milliseconds: 650));
          try {
            final res = await _fetchRaw(e.requestOptions.uri, attempt: 2);
            return handler.resolve(res);
          } catch (_) {
            /* cae al error original */
          }
        }
        return handler.next(e);
      },
    ),
  );
  return d;
}();

Future<Response<dynamic>> _fetchRaw(Uri uri, {int attempt = 1}) async {
  final opts = Options()..extra = {'attempt': attempt, 'retried': attempt > 1};
  return _dio.getUri<dynamic>(uri, options: opts);
}

Future<dynamic> _fetchJson(
  Uri uri, {
  Duration timeout = const Duration(seconds: 7),
}) async {
  final res = await _fetchJsonResponse(uri, timeout: timeout);
  return res.data;
}

Future<Response<dynamic>> _fetchJsonResponse(
  Uri uri, {
  Duration timeout = const Duration(seconds: 7),
}) async {
  // v23.3 (pez 2-b P2-1): al vencer el timeout se CANCELA la petición
  // subyacente (CancelToken) — antes seguía viva en segundo plano y el
  // reintento podía apilar una consulta fantasma sobre la misma URL.
  final ct = CancelToken();
  try {
    final res = await _dio
        .getUri<dynamic>(uri, cancelToken: ct)
        .timeout(
          timeout,
          onTimeout: () {
            ct.cancel('timeout');
            throw Exception('timeout ${uri.host}');
          },
        );
    if (res.statusCode != 200) throw Exception('HTTP ${res.statusCode}');
    return res;
  } on DioException {
    if (ct.isCancelled) throw Exception('timeout ${uri.host}');
    rethrow;
  }
}

class SourceEntryX {
  static RateEntry? entry(num? rate, [String? updatedAt]) {
    final r = (rate ?? 0).toDouble();
    if (!r.isFinite || r <= 0) return null;
    return RateEntry(
      rate: r,
      updatedAt: DateTime.tryParse(updatedAt ?? '') ?? DateTime.now(),
    );
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

// ─── Parsers de RESPALDO (puros, testeables sin red) ───────────────────────

/// AwesomeAPI `json/last/USD-BRL`: {"USDBRL":{"bid":"5.14","create_date":…}}
/// (mismo servicio que ya usa el histórico diario — solo cae aquí si DolarAPI
/// murió). Acepta cuota agotada (429 llega como objeto sin `bid` → null).
RateEntry? parseAwesomePair(dynamic v, String pairKey) {
  if (v is! Map) return null;
  final m = v[pairKey];
  if (m is! Map) return null;
  final bid = num.tryParse('${m['bid'] ?? ''}');
  if (bid == null || bid <= 0) return null;
  final created = DateTime.tryParse('${m['create_date'] ?? ''}');
  return RateEntry(
    rate: bid.toDouble(),
    updatedAt:
        created ??
        DateTime.fromMillisecondsSinceEpoch(
          (int.tryParse('${m['timestamp'] ?? ''}') ?? 0) * 1000,
          isUtc: true,
        ),
  );
}

/// Frankfurter `v1/latest?base=USD&symbols=MXN`: {"date":…,"rates":{"MXN":17.1}}
RateEntry? parseFrankfurterUsd(dynamic v, String symbol) {
  if (v is! Map || v['rates'] is! Map) return null;
  final r = (v['rates'] as Map)[symbol];
  if (r is! num || r <= 0) return null;
  return RateEntry(
    rate: r.toDouble(),
    updatedAt: DateTime.tryParse('${v['date'] ?? ''}') ?? DateTime.now(),
  );
}

/// Superfinanciera (datos.gov.co 32sa-8pi3): [{"valor":"3109.3",
/// "vigenciadesde":"2026-09-15T00:00:00.000"}] — la TRM oficial colombiana.
RateEntry? parseTrmGob(dynamic v) {
  final row = _asList(v).firstOrNull;
  if (row == null) return null;
  final valor = num.tryParse('${row['valor'] ?? ''}');
  if (valor == null || valor <= 0) return null;
  return RateEntry(
    rate: valor.toDouble(),
    updatedAt:
        DateTime.tryParse('${row['vigenciadesde'] ?? ''}') ?? DateTime.now(),
  );
}

/// DolarVZLA CDN `bcv/current.json` (v21.3, respaldo VE — pydolarve.org
/// caducó): {"current":{"date":"2026-10-05","usd":871.3689,"eur":981.17},
/// "previous":…,"changePercentage":…}. JSON estático de CDN, sin auth, CORS
/// abierto (verificado 05/10/2026). Publica SOLO el oficial BCV — el
/// paralelo no tiene tercera fuente pública estable, y eso está bien: el
/// respaldo existe para que el tablero y el conversor nunca se queden sin
/// la tasa oficial.
RateEntry? parseDolarVzlaBcv(dynamic v, {required bool euro}) {
  if (v is! Map) return null;
  final current = v['current'];
  if (current is! Map) return null;
  final rate = (current[euro ? 'eur' : 'usd'] as num?)?.toDouble();
  if (rate == null || !rate.isFinite || rate <= 0) return null;
  return RateEntry(
    rate: rate,
    // `date` es la fecha de publicación (sin hora) — basta para el sello.
    updatedAt: DateTime.tryParse('${current['date'] ?? ''}') ?? DateTime.now(),
  );
}

/// Worker público de CalculaYa `/tasas` (v23.2 — REA del APK 1.1.0, endpoint
/// hallado en libapp-strings y VERIFICADO con curl 21/11/2026):
/// {"usd":918.7662,"eur":1009.07,"usdt":1075.67,"rate_date":"2026-11-20",
///  "remesas":{"COP":{…,"rate_per_usd":3345.3929,…},…}}
/// Atribución verificada EN VIVO: `usd` = BCV oficial (idéntico a DolarAPI
/// ese mismo minuto) y `usdt` = referencia P2P del mercado (~+0.5 % sobre el
/// paralelo) — NO se disfraza de paralelo: tiene fuente propia. El mapa
/// devuelve TODAS las claves posibles; el bloque decide cuáles faltaban
/// (el respaldo nunca pisa dato fresco).
Map<String, RateEntry> parseCalculayaTasas(dynamic v) {
  final out = <String, RateEntry>{};
  if (v is! Map) return out;
  final date = DateTime.tryParse('${v['rate_date'] ?? ''}');
  RateEntry? e(dynamic n) => SourceEntryX.entry(
    n is num ? n : (n == null ? null : num.tryParse('$n')),
    date?.toIso8601String(),
  );
  final usd = e(v['usd']);
  if (usd != null) out['ves-bcv'] = usd;
  final eur = e(v['eur']);
  if (eur != null) out['eur-ves-oficial'] = eur;
  final usdt = e(v['usdt']);
  if (usdt != null) out['usdt-ves'] = usdt;
  final remesas = v['remesas'];
  if (remesas is Map) {
    final cop = remesas['COP'];
    if (cop is Map) {
      final ce = e(cop['rate_per_usd']);
      if (ce != null) out['cop-market'] = ce;
    }
  }
  return out;
}

/// CoinGecko `simple/price` (v23.2 — cripto global, sin clave):
/// {"tether":{"usd":0.9986},"ethereum":{"usd":1611.41}} — USD por unidad.
RateEntry? parseCoinGeckoUsd(dynamic v, String coinId) {
  if (v is! Map) return null;
  final coin = v[coinId];
  if (coin is! Map) return null;
  // Tolerante (nunca cast que lance): la red puede mandar strings o basura.
  final raw = coin['usd'];
  final double? r = raw is num ? raw.toDouble() : double.tryParse('$raw');
  if (r == null || !r.isFinite || r <= 0) return null;
  return RateEntry(rate: r, updatedAt: DateTime.now());
}

/// Derivación honesta de último recurso (v23.2): Bs por USDT = Bs por USD
/// (paralelo vivo) × USD por USDT (precio global del tether). Publicada
/// como función PURA para el test — se usa solo si el Worker de CalculaYa
/// no dio la referencia P2P.
RateEntry? deriveUsdtVesFromGlobal(RateEntry? usdtUsd, RateEntry? parallel) {
  if (usdtUsd == null || parallel == null) return null;
  // Guard sanidad: el tether ronda 1 USD (0.2–2). Fuera de rango, el dato
  // es basura y NO se deriva nada.
  if (usdtUsd.rate <= 0.2 || usdtUsd.rate >= 2) return null;
  // v23.3 (pez 2-b P2-4): finitud explícita — un paralelo finito pero
  // gigante × tether puede desbordar a Infinity y colarse en la UI.
  if (!usdtUsd.rate.isFinite || !parallel.rate.isFinite) return null;
  if (parallel.rate <= 0) return null;
  final rate = parallel.rate * usdtUsd.rate;
  if (!rate.isFinite || rate <= 0) return null;
  // v23.3 (pez 2-b P1-4): un valor derivado solo es tan fresco como su
  // insumo MÁS VIEJO — el sello honesto es el mín (antes el máx pintaba
  // «hace 0 min» solo porque CoinGecko estampa ahora()).
  final oldest = parallel.updatedAt.isBefore(usdtUsd.updatedAt)
      ? parallel.updatedAt
      : usdtUsd.updatedAt;
  return RateEntry(rate: rate, updatedAt: oldest);
}

/// Memo del Worker de CalculaYa (v23.3, pez 2-b P2-3): VE, CO y cripto
/// pueden pedir /tasas en la MISMA ronda (y corren en paralelo) — UNA
/// consulta por ventana de 30 s compartida por todos: la primera llamada
/// dispara el fetch, el resto espera el mismo futuro, y un Worker caído
/// no se martilla 3 veces por ronda (se cachea el vacío hasta la próxima
/// ventana — degradación honesta).
Map<String, RateEntry>? _calculayaMemo;
DateTime _calculayaMemoAt = DateTime(0);
Future<Map<String, RateEntry>>? _calculayaFetching;

Future<Map<String, RateEntry>> _calculayaTasas() {
  if (DateTime.now().difference(_calculayaMemoAt) <
      const Duration(seconds: 30)) {
    return Future.value(_calculayaMemo ?? const {});
  }
  return _calculayaFetching ??= () async {
    try {
      final v = await _fetchJson(
        Uri.parse('https://calculaya-api.jalvarezgw19.workers.dev/tasas'),
        timeout: const Duration(seconds: 4),
      );
      _calculayaMemo = parseCalculayaTasas(v);
    } catch (_) {
      _calculayaMemo = const {}; // caído en esta ventana: nada que aportar
    }
    _calculayaMemoAt = DateTime.now();
    return _calculayaMemo!;
  }().whenComplete(() => _calculayaFetching = null);
}

/// Resultado de un bloque regional: fuentes, errores y proveedores usados
/// (v19.0: los respaldos cuentan su origen real en el tablero).
typedef RegionBlock = (Map<String, RateEntry>, List<String>, List<String>);

/// Venezuela: USD oficial/paralelo + EUR oficial/paralelo (respaldo DolarVZLA).
Future<RegionBlock> _veBlock() async {
  final sources = <String, RateEntry>{};
  final errors = <String>[];
  final providers = <String>{};
  var dolarapiVivo = false;
  try {
    final dolares = await _fetchJson(
      Uri.parse('https://ve.dolarapi.com/v1/dolares'),
    );
    if (dolares is List) {
      for (final row in dolares.whereType<Map>()) {
        final fuente = '${row['fuente'] ?? ''}';
        final e = SourceEntryX.entry(
          row['promedio'] as num?,
          row['fechaActualizacion'] as String?,
        );
        if (fuente == 'oficial' && e != null) sources['ves-bcv'] = e;
        if (fuente == 'paralelo' && e != null) sources['ves-parallel'] = e;
      }
    }
    dolarapiVivo = sources.isNotEmpty;
  } catch (e) {
    errors.add('ve.dolarapi/dolares: $e');
    VeLog.e('board', e);
  }
  // Respaldo VE (v21.3): DolarVZLA — solo si el OFICIAL no llegó, porque no
  // publica paralelo. Cubre USD y EUR oficiales en una sola llamada; si el
  // bloque de euros de DolarAPI vive, su dato (más fresco) sobreescribe el
  // nuestro más abajo.
  if (!sources.containsKey('ves-bcv')) {
    try {
      final data = await _fetchJson(
        Uri.parse('https://rates.dolarvzla.com/bcv/current.json'),
        timeout: const Duration(seconds: 4),
      );
      final b = parseDolarVzlaBcv(data, euro: false);
      final eur = parseDolarVzlaBcv(data, euro: true);
      if (b != null) sources['ves-bcv'] = b;
      if (eur != null && !sources.containsKey('eur-ves-oficial')) {
        sources['eur-ves-oficial'] = eur;
      }
      if (b != null || eur != null) providers.add('dolarvzla.com');
    } catch (e) {
      errors.add('dolarvzla (respaldo VE): $e');
      VeLog.e('board', e);
    }
  }
  if (dolarapiVivo) providers.add('dolarapi.com');
  try {
    final euros = await _fetchJson(
      Uri.parse('https://ve.dolarapi.com/v1/euros'),
    );
    if (euros is List) {
      for (final row in euros.whereType<Map>()) {
        final fuente = '${row['fuente'] ?? ''}';
        final e = SourceEntryX.entry(
          row['promedio'] as num?,
          row['fechaActualizacion'] as String?,
        );
        if (fuente == 'oficial' && e != null) sources['eur-ves-oficial'] = e;
        if (fuente == 'paralelo' && e != null) sources['eur-ves-paralelo'] = e;
      }
      if (euros.isNotEmpty) providers.add('dolarapi.com');
    }
  } catch (e) {
    errors.add('ve.dolarapi/euros: $e');
    VeLog.e('board', e);
  }
  // Respaldo VE #2 (v23.2): el Worker público de CalculaYa — mismo valor
  // oficial que DolarAPI (verificado en vivo). Solo llena los oficiales que
  // SIGAN FALTANDO: el respaldo nunca pisa dato fresco. La referencia USDT
  // P2P vive en el bloque cripto (_cryptoBlock), no aquí.
  // v23.3 (pez 2-b P1-3): este bloque vive DESPUÉS del fetch de euros —
  // antes la condición se evaluaba con «eur-ves-oficial» todavía ausente
  // (los euros se pedían más abajo) y el Worker se consultaba en TODAS las
  // rondas aunque DolarAPI estuviera sano. Y la consulta pasa por el memo
  // (_calculayaTasas): 1 por ronda, compartida con CO y cripto.
  if (!sources.containsKey('ves-bcv') ||
      !sources.containsKey('eur-ves-oficial')) {
    final calc = await _calculayaTasas();
    if (!sources.containsKey('ves-bcv') && calc['ves-bcv'] != null) {
      sources['ves-bcv'] = calc['ves-bcv']!;
      providers.add('calculaya.workers.dev');
    }
    if (!sources.containsKey('eur-ves-oficial') &&
        calc['eur-ves-oficial'] != null) {
      sources['eur-ves-oficial'] = calc['eur-ves-oficial']!;
      providers.add('calculaya.workers.dev');
    }
  }
  return (sources, errors, providers.toList());
}

/// Colombia: TRM (DolarAPI → Superfinanciera datos.gov.co) + USD mercado
/// (→ AwesomeAPI) + EUR.
Future<RegionBlock> _coBlock() async {
  final sources = <String, RateEntry>{};
  final errors = <String>[];
  final providers = <String>{};
  try {
    final v = await _fetchJson(Uri.parse('https://co.dolarapi.com/v1/trm'));
    final e = SourceEntryX.entry(
      v is Map ? (v['valor'] as num?) : null,
      v is Map ? v['fechaActualizacion'] as String? : null,
    );
    if (e != null) {
      sources['cop-trm'] = e;
      providers.add('dolarapi.com');
    }
  } catch (err) {
    errors.add('cop-trm: $err');
  }
  // Respaldo TRM: la Superfinanciera misma (datos.gov.co, oficial).
  if (!sources.containsKey('cop-trm')) {
    try {
      final v = await _fetchJson(
        Uri.parse('https://www.datos.gov.co/resource/32sa-8pi3.json?\$limit=1'),
      );
      final e = parseTrmGob(v);
      if (e != null) {
        sources['cop-trm'] = e;
        providers.add('datos.gov.co');
      }
    } catch (err) {
      errors.add('cop-trm respaldo gob: $err');
    }
  }
  // v19 (integración): TODAS las cotizaciones de mercado en UNA consulta
  // (/v1/cotizaciones trae USD y EUR juntos) — antes eran dos llamadas.
  try {
    final rows = _asList(
      await _fetchJson(Uri.parse('https://co.dolarapi.com/v1/cotizaciones')),
    );
    for (final q in rows) {
      final code = '${q['moneda'] ?? ''}';
      final e = SourceEntryX.entry(_mid(q), q['fechaActualizacion'] as String?);
      if (e == null) continue;
      if (code == 'USD') {
        sources['cop-market'] = e;
        providers.add('dolarapi.com');
      }
      if (code == 'EUR') {
        sources['eur-cop'] = e;
        providers.add('dolarapi.com');
      }
    }
  } catch (err) {
    errors.add('cotizaciones CO: $err');
  }
  // Respaldo COP mercado: AwesomeAPI (bid USD-COP).
  if (!sources.containsKey('cop-market')) {
    try {
      final v = await _fetchJson(
        Uri.parse('https://economia.awesomeapi.com.br/json/last/USD-COP'),
      );
      final e = parseAwesomePair(v, 'USDCOP');
      if (e != null) {
        sources['cop-market'] = e;
        providers.add('awesomeapi.com.br');
      }
    } catch (err) {
      errors.add('cop-market respaldo awesome: $err');
    }
  }
  // Respaldo COP mercado #2 (v23.2): remesas COP del Worker de CalculaYa.
  // v23.3 (pez 2-b P2-3): consulta por el memo — la misma ventana de 30 s
  // que VE y cripto (nada de 3 hits idénticos al Worker por ronda).
  if (!sources.containsKey('cop-market')) {
    try {
      final e = (await _calculayaTasas())['cop-market'];
      if (e != null) {
        sources['cop-market'] = e;
        providers.add('calculaya.workers.dev');
      }
    } catch (err) {
      errors.add('cop-market respaldo calculaya: $err');
    }
  }
  return (sources, errors, providers.toList());
}

/// Cripto (v23.2): USDT P2P (Worker de CalculaYa) + tether global
/// (CoinGecko). El manual del usuario cubre la referencia local.
Future<RegionBlock> _cryptoBlock() async {
  final sources = <String, RateEntry>{};
  final errors = <String>[];
  final providers = <String>{};
  var calculayaUsdt = false;
  try {
    // v23.3 (pez 2-b P2-3): mismo memo que VE/CO — 1 consulta al Worker
    // por ventana de 30 s aunque los 3 bloques corran en paralelo.
    final e = (await _calculayaTasas())['usdt-ves'];
    if (e != null) {
      sources['usdt-ves'] = e;
      providers.add('calculaya.workers.dev');
      calculayaUsdt = true;
    }
  } catch (err) {
    errors.add('usdt-ves calculaya: $err');
  }
  try {
    final v = await _fetchJson(
      Uri.parse(
        'https://api.coingecko.com/api/v3/simple/price'
        '?ids=tether&vs_currencies=usd',
      ),
    );
    final tether = parseCoinGeckoUsd(v, 'tether');
    if (tether != null) {
      sources['usdt-usd'] = tether;
      providers.add('coingecko.com');
      // Último recurso para la referencia local: se deriva en fetchBoard
      // cuando el paralelo vivo ya llegó (el bloque corre en paralelo).
      if (!calculayaUsdt) sources['__tetherDerive__'] = tether;
    }
  } catch (err) {
    errors.add('cripto coingecko: $err');
  }
  return (sources, errors, providers.toList());
}

/// México: USD fix (DolarAPI → Frankfurter como respaldo).
Future<RegionBlock> _mxBlock() async {
  final sources = <String, RateEntry>{};
  final errors = <String>[];
  final providers = <String>{};
  try {
    final v = await _fetchJson(
      Uri.parse('https://mx.dolarapi.com/v1/cotizaciones/usd'),
    );
    final q = _asList(v).firstOrNull;
    final e = SourceEntryX.entry(_mid(q), q?['fechaActualizacion'] as String?);
    if (e != null) {
      sources['mxn-banxico'] = e;
      providers.add('dolarapi.com');
    }
  } catch (err) {
    errors.add('mxn-banxico: $err');
  }
  if (!sources.containsKey('mxn-banxico')) {
    try {
      final v = await _fetchJson(
        Uri.parse('https://api.frankfurter.dev/v1/latest?base=USD&symbols=MXN'),
      );
      final e = parseFrankfurterUsd(v, 'MXN');
      if (e != null) {
        sources['mxn-banxico'] = e;
        providers.add('frankfurter.dev');
      }
    } catch (err) {
      errors.add('mxn-banxico respaldo frankfurter: $err');
    }
  }
  return (sources, errors, providers.toList());
}

/// Brasil: USD + EUR (DolarAPI → AwesomeAPI como respaldo).
Future<RegionBlock> _brBlock() async {
  final sources = <String, RateEntry>{};
  final errors = <String>[];
  final providers = <String>{};
  // v19 (integración): TODAS las cotizaciones en UNA consulta
  // (/v1/cotacoes trae USD y EUR juntos, claves PT moeda/dataAtualizacao).
  try {
    final rows = _asList(
      await _fetchJson(Uri.parse('https://br.dolarapi.com/v1/cotacoes')),
    );
    for (final q in rows) {
      final code = '${q['moeda'] ?? q['moneda'] ?? ''}';
      final e = SourceEntryX.entry(
        _mid(q),
        (q['dataAtualizacao'] ?? q['fechaActualizacion']) as String?,
      );
      if (e == null) continue;
      if (code == 'USD') {
        sources['brl-br'] = e;
        providers.add('dolarapi.com');
      }
      if (code == 'EUR') {
        sources['eur-brl'] = e;
        providers.add('dolarapi.com');
      }
    }
  } catch (err) {
    errors.add('cotacoes BR: $err');
  }
  // Respaldo BRL: AwesomeAPI (bid USD-BRL y EUR-BRL).
  // v23.3 (pez 2-b P2-2): fuera el try/catch exterior muerto — el loop ya
  // tiene su propio try/catch por par y el envoltorio solo ocultaría un
  // error real del loop (código muerto desde v19).
  final pairs = [
    ('brl-br', 'USD-BRL', 'USDBRL'),
    ('eur-brl', 'EUR-BRL', 'EURBRL'),
  ];
  for (final (id, pair, key) in pairs) {
    if (sources.containsKey(id)) continue;
    try {
      final v = await _fetchJson(
        Uri.parse('https://economia.awesomeapi.com.br/json/last/$pair'),
      );
      final e = parseAwesomePair(v, key);
      if (e != null) {
        sources[id] = e;
        providers.add('awesomeapi.com.br');
      }
    } catch (err) {
      errors.add('$id respaldo awesome: $err');
    }
  }
  return (sources, errors, providers.toList());
}

class BoardResult {
  final RateBoard board;
  final List<String> changed;
  const BoardResult(this.board, this.changed);
}

const changeEps = 0.0005;

/// v23.3 (pez 2-b P1-1): fusión PURA del payload SSE contra el tablero
/// vigente (seam de test). El stream puede llegar PARCIAL (un despliegue
/// web sin las fuentes cripto/CO) — lo ausente SOBREVIVE y por clave
/// presente gana el `updatedAt` más reciente: un push viejo jamás pisa
/// un dato fresco del poll.
Map<String, RateEntry> mergeSseSources(
  Map<String, RateEntry> current,
  Map<String, RateEntry> incoming,
) {
  final merged = <String, RateEntry>{...current};
  incoming.forEach((id, entry) {
    final cur = merged[id];
    if (cur == null || !entry.updatedAt.isBefore(cur.updatedAt)) {
      merged[id] = entry;
    }
  });
  return merged;
}

/// Consulta las 4 regiones + cripto en paralelo y compara contra [previous].
Future<BoardResult> fetchBoard([RateBoard? previous]) async {
  final results = await Future.wait([
    _veBlock(),
    _coBlock(),
    _mxBlock(),
    _brBlock(),
    _cryptoBlock(),
  ]);
  // v23.2 — USDT de último recurso: si el Worker de CalculaYa no dio la
  // referencia P2P, deriva Bs por USDT = paralelo vivo × tether global
  // (derivación honesta con guard; el sello sigue diciendo «Mercado»).
  var crypto = results[4];
  final pendingDerive = crypto.$1.remove('__tetherDerive__');
  if (pendingDerive != null && !crypto.$1.containsKey('usdt-ves')) {
    final derived = deriveUsdtVesFromGlobal(
      pendingDerive,
      results[0].$1['ves-parallel'],
    );
    if (derived != null) {
      crypto = ({...crypto.$1, 'usdt-ves': derived}, crypto.$2, [...crypto.$3]);
    }
  }
  return mergeRegionBlocks([...results.take(4), crypto], previous);
}

/// Fusión pura de bloques (pública: seam de tests, sin red). Los proveedores
/// son los ORÍGENES reales que llenaron cada fuente (dolarapi.com + respaldos).
BoardResult mergeRegionBlocks(List<RegionBlock> results, RateBoard? previous) {
  final sources = <String, RateEntry>{};
  final providers = <String>{};
  final degraded = <String>[];
  // Offline (v19.5): siembra las fuentes de la ronda ANTERIOR para que una
  // región caída no borre sus tasas del tablero; las frescas las pisan
  // encima. La entrada preservada conserva su updatedAt original y la
  // región fallida queda listada en `degraded` — nada se inventa.
  if (previous != null) sources.addAll(previous.sources);
  for (final (s, e, p) in results) {
    sources.addAll(s);
    degraded.addAll(e);
    providers.addAll(p);
  }
  // v23.3 (pez 2-b): las claves internas de puente (`__tetherDerive__`) NO
  // son fuentes — el filtro vive AQUÍ para que el contrato no dependa del
  // caller (antes solo fetchBoard lo respetaba).
  sources.removeWhere((k, _) => k.startsWith('__'));
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
    providers: providers.toList(),
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
    ('BR', 'Brasil'),
    ('CR', 'Cripto'),
  ];
  final out = <RegionHealth>[];
  await Future.wait(
    blocks.map((b) async {
      final sw = Stopwatch()..start();
      int count = 0;
      String? error;
      try {
        final (sources, _, _) = switch (b.$1) {
          'VE' => await _veBlock(),
          'CO' => await _coBlock(),
          'MX' => await _mxBlock(),
          'BR' => await _brBlock(),
          _ => await _cryptoBlock(),
        };
        // Las claves internas (puente de derivación) no son fuentes reales.
        count = sources.keys.where((k) => !k.startsWith('__')).length;
      } catch (e) {
        error = '$e';
      }
      sw.stop();
      out.add(
        RegionHealth(
          code: b.$1,
          label: b.$2,
          ok: count > 0,
          sources: count,
          latencyMs: sw.elapsedMilliseconds,
          error: error,
        ),
      );
    }),
  );
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
  const RegionHealth({
    required this.code,
    required this.label,
    required this.ok,
    required this.sources,
    required this.latencyMs,
    this.error,
  });
}
