/// ─── Tests del tablero: parsers de RESPALDO (v19.0) ─────────────────────────
/// Los respaldos se prueban como funciones PURAS (sin red): AwesomeAPI,
/// Frankfurter y la TRM de datos.gov.co. Formatos reales verificados con curl
/// (verificados en vivo el 2026-09-15; AwesomeAPI con cuota agotada desde el
/// datacenter devuelve {"status":429,...} sin `bid` → null, sin lanzar).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/data/board.dart';
import 'package:valorave/core/models.dart';

void main() {
  group('parseAwesomePair (respaldo USD/EUR → BRL, USD → COP)', () {
    test('formato real json/last: bid + create_date', () {
      final v = {
        'USDBRL': {
          'code': 'USD',
          'codein': 'BRL',
          'bid': '5.1484',
          'timestamp': '1789400000',
          'create_date': '2026-09-14 21:59:59',
        },
      };
      final e = parseAwesomePair(v, 'USDBRL');
      expect(e, isNotNull);
      expect(e!.rate, closeTo(5.1484, 1e-9));
      expect(e.updatedAt.year, 2026);
    });

    test('par ausente o cuota agotada → null (nunca lanza)', () {
      expect(
        parseAwesomePair({'status': 429, 'message': 'Quota'}, 'USDBRL'),
        isNull,
      );
      expect(parseAwesomePair(null, 'USDBRL'), isNull);
      expect(
        parseAwesomePair({
          'USDBRL': {'bid': 'x'},
        }, 'USDBRL'),
        isNull,
      );
      expect(
        parseAwesomePair({
          'USDBRL': {'bid': '0'},
        }, 'USDBRL'),
        isNull,
      );
    });
  });

  group('parseFrankfurterUsd (respaldo MXN)', () {
    test('formato real v1/latest: rates + date', () {
      final v = {
        'amount': 1.0,
        'base': 'USD',
        'date': '2026-09-14',
        'rates': {'MXN': 17.0721},
      };
      final e = parseFrankfurterUsd(v, 'MXN');
      expect(e, isNotNull);
      expect(e!.rate, closeTo(17.0721, 1e-9));
      expect(e.updatedAt, DateTime(2026, 9, 14));
    });

    test('sin rates o valor inválido → null', () {
      expect(parseFrankfurterUsd({'message': 'not found'}, 'COP'), isNull);
      expect(parseFrankfurterUsd({'rates': {}}, 'MXN'), isNull);
      expect(
        parseFrankfurterUsd({
          'rates': {'MXN': 'x'},
        }, 'MXN'),
        isNull,
      );
    });
  });

  group('parseDolarVzlaBcv (respaldo BCV USD/EUR · v21.3)', () {
    // Payload REAL de rates.dolarvzla.com/bcv/current.json (curl 05/10/2026).
    final real = {
      'current': {
        'date': '2026-10-05',
        'usd': 871.3689,
        'eur': 981.17880877,
      },
      'previous': {'date': '2026-10-02', 'usd': 866.5612, 'eur': 973.92813268},
      'changePercentage': {'usd': 0.5548021305362009, 'eur': 0.7444775283416522},
    };

    test('formato real bcv/current.json: usd y eur de current', () {
      final usd = parseDolarVzlaBcv(real, euro: false);
      expect(usd, isNotNull);
      expect(usd!.rate, closeTo(871.3689, 1e-9));
      expect(usd.updatedAt, DateTime(2026, 10, 5));
      final eur = parseDolarVzlaBcv(real, euro: true);
      expect(eur, isNotNull);
      expect(eur!.rate, closeTo(981.17880877, 1e-9));
    });

    test('sin current, tasa inválida o cero → null (nunca lanza)', () {
      expect(parseDolarVzlaBcv(null, euro: false), isNull);
      expect(parseDolarVzlaBcv(<dynamic, dynamic>{}, euro: false), isNull);
      expect(
        parseDolarVzlaBcv({
          'current': {'date': '2026-10-05'},
        }, euro: false),
        isNull,
      );
      expect(
        parseDolarVzlaBcv({
          'current': {'usd': 0},
        }, euro: false),
        isNull,
      );
      expect(
        parseDolarVzlaBcv({
          'current': {'eur': -1},
        }, euro: true),
        isNull,
      );
    });
  });

  group('parseTrmGob (respaldo TRM · Superfinanciera)', () {
    test('formato real datos.gov.co: valor + vigenciadesde', () {
      final v = [
        {
          'valor': '3109.3',
          'unidad': 'COP',
          'vigenciadesde': '2026-09-15T00:00:00.000',
        },
      ];
      final e = parseTrmGob(v);
      expect(e, isNotNull);
      expect(e!.rate, closeTo(3109.3, 1e-9));
      expect(e.updatedAt, DateTime(2026, 9, 15));
    });

    test('vacío o sin valor → null', () {
      expect(parseTrmGob(<dynamic>[]), isNull);
      expect(
        parseTrmGob([
          {'unidad': 'COP'},
        ]),
        isNull,
      );
      expect(
        parseTrmGob([
          {'valor': '-1'},
        ]),
        isNull,
      );
    });
  });

  group('fusión de bloques con proveedores reales', () {
    test('los respaldos cuentan su origen y el diff marca cambios', () {
      final prev = RateBoard(
        sources: {
          'brl-br': RateEntry(rate: 5.10, updatedAt: DateTime(2026, 9, 13)),
        },
        providers: const ['dolarapi.com'],
        degraded: const [],
        lastUpdate: DateTime(2026, 9, 13),
        fetchedAt: DateTime(2026, 9, 13),
      );
      final blocks = <RegionBlock>[
        (
          {'brl-br': RateEntry(rate: 5.20, updatedAt: DateTime(2026, 9, 15))},
          <String>['brl-br: HTTP 500'],
          <String>['awesomeapi.com.br'],
        ),
      ];
      // La fusión es pura y pública (seam de tests): providers del bloque +
      // changed por movimiento > eps.
      final result = mergeRegionBlocks(blocks, prev);
      expect(result.board.providers, contains('awesomeapi.com.br'));
      expect(result.board.providers, isNot(contains('dolarapi.com')));
      expect(result.changed, contains('brl-br')); // 5.10 → 5.20 (> 0.05 %)
    });
  });

  group('fusión offline (v19.5): región caída no borra el tablero', () {
    RateBoard boardOf(Map<String, RateEntry> s) => RateBoard(
      sources: s,
      providers: const ['dolarapi.com'],
      degraded: const [],
      lastUpdate: DateTime(2026, 9, 12),
      fetchedAt: DateTime(2026, 9, 12),
    );

    test('red totalmente caída → las fuentes previas sobreviven intactas', () {
      final prev = boardOf({
        'ves-bcv': RateEntry(rate: 234.89, updatedAt: DateTime(2026, 9, 12)),
        'ves-parallel': RateEntry(
          rate: 260.00,
          updatedAt: DateTime(2026, 9, 12),
        ),
        'brl-br': RateEntry(rate: 5.10, updatedAt: DateTime(2026, 9, 12)),
      });
      // Las regiones caen igual que en producción: bloque con fuentes vacías
      // + su lista de errores (el catch de cada bloque se queda con el error).
      final dead = List.generate(
        4,
        (_) => const (<String, RateEntry>{}, <String>['HTTP 503'], <String>[]),
      );
      final result = mergeRegionBlocks(dead, prev);
      expect(result.board.sources['ves-bcv']!.rate, closeTo(234.89, 1e-9));
      expect(result.board.sources['ves-parallel']!.rate, closeTo(260.00, 1e-9));
      expect(result.board.sources['brl-br']!.rate, closeTo(5.10, 1e-9));
      // Nada cambió de tasa: cero cambios reportados y la caída sí queda
      // registrada en degraded (el usuario la ve, el tablero no la inventa).
      expect(result.changed, isEmpty);
      expect(result.board.degraded, isNotEmpty);
    });

    test(
      'la fuente fresca pisa a la vieja; la región caída conserva la suya',
      () {
        final prev = boardOf({
          'ves-bcv': RateEntry(rate: 234.89, updatedAt: DateTime(2026, 9, 12)),
          'brl-br': RateEntry(rate: 5.10, updatedAt: DateTime(2026, 9, 13)),
        });
        final blocks = <RegionBlock>[
          (
            {
              'ves-bcv': RateEntry(
                rate: 240.00,
                updatedAt: DateTime(2026, 9, 15),
              ),
            },
            <String>[],
            <String>['dolarapi.com'],
          ),
          const (
            <String, RateEntry>{},
            <String>['brl-br: HTTP 500'],
            <String>[],
          ),
        ];
        final result = mergeRegionBlocks(blocks, prev);
        // La fresca pisa; la caída sobrevive con su valor anterior y su
        // updatedAt original (quién está fresco queda a la vista).
        expect(result.board.sources['ves-bcv']!.rate, closeTo(240.00, 1e-9));
        expect(result.board.sources['brl-br']!.rate, closeTo(5.10, 1e-9));
        expect(
          result.board.sources['brl-br']!.updatedAt,
          DateTime(2026, 9, 13),
        );
        expect(result.changed, contains('ves-bcv'));
        expect(result.changed, isNot(contains('brl-br')));
      },
    );

    test('sin previous la fusión se comporta igual que siempre', () {
      final blocks = <RegionBlock>[
        (
          {
            'ves-bcv': RateEntry(
              rate: 240.00,
              updatedAt: DateTime(2026, 9, 15),
            ),
          },
          <String>[],
          <String>['dolarapi.com'],
        ),
      ];
      final result = mergeRegionBlocks(blocks, null);
      expect(result.board.sources.keys, containsAll(['ves-bcv']));
      expect(result.board.sources.length, 1);
      expect(result.changed, contains('ves-bcv'));
    });
  });

  group('parseCalculayaTasas (v23.2 · respaldo VE + USDT P2P)', () {
    // Payload REAL del Worker https://calculaya-api.jalvarezgw19.workers.dev
    // /tasas (curl 21/11/2026). `usd` coincide AL DÍGITO con el oficial de
    // DolarAPI ese mismo minuto (918.7662) — atribución verificada en vivo.
    final real = {
      'usd': 918.7662,
      'eur': 1009.07172979,
      'usdt': 1075.67,
      'rate_date': '2026-11-20',
      'has_tomorrow': false,
      'date': '2026-11-20T20:21:31.014Z',
      'source': 'cloudflare_edge',
      'remesas': {
        'COP': {
          'code': 'COP',
          'name': 'Peso Colombiano',
          'rate_per_usd': 3345.3929,
          'rate_bs': 0.321538,
        },
        'BRL': {
          'code': 'BRL',
          'rate_per_usd': 5.8932,
          'rate_bs': 182.52732,
        },
      },
    };

    test('formato real: oficiales + USDT P2P + remesas COP', () {
      final out = parseCalculayaTasas(real);
      expect(out['ves-bcv']!.rate, closeTo(918.7662, 1e-9));
      expect(out['eur-ves-oficial']!.rate, closeTo(1009.07172979, 1e-9));
      expect(out['usdt-ves']!.rate, closeTo(1075.67, 1e-9));
      expect(out['cop-market']!.rate, closeTo(3345.3929, 1e-9));
      // El sello usa la fecha de publicación del Worker (rate_date).
      expect(out['ves-bcv']!.updatedAt, DateTime(2026, 11, 20));
      // NO inventa claves que el Worker no dio: BRL oficial no va aquí.
      expect(out.containsKey('brl-br'), isFalse);
      expect(out.length, 4);
    });

    test('malformado o vacío → mapa vacío (nunca lanza)', () {
      expect(parseCalculayaTasas(null), isEmpty);
      expect(parseCalculayaTasas({'error': 'not found'}), isEmpty);
      expect(
        parseCalculayaTasas({
          'usd': 'x',
          'usdt': 0,
          'remesas': 'no-map',
        }),
        isEmpty,
      );
    });
  });

  group('parseCoinGeckoUsd (v23.2 · cripto global sin clave)', () {
    // Payload REAL de simple/price (curl 21/11/2026).
    final real = {
      'tether': {'usd': 0.998651},
      'ethereum': {'usd': 1611.41},
    };

    test('formato real: tether y ethereum en USD', () {
      final eth = parseCoinGeckoUsd(real, 'ethereum');
      expect(eth, isNotNull);
      expect(eth!.rate, closeTo(1611.41, 1e-9));
      final tether = parseCoinGeckoUsd(real, 'tether');
      expect(tether!.rate, closeTo(0.998651, 1e-9));
    });

    test('coin ausente o inválido → null', () {
      expect(parseCoinGeckoUsd(null, 'ethereum'), isNull);
      expect(parseCoinGeckoUsd({}, 'bitcoin'), isNull);
      expect(
        parseCoinGeckoUsd({
          'ethereum': {'usd': 'x'},
        }, 'ethereum'),
        isNull,
      );
      expect(
        parseCoinGeckoUsd({
          'ethereum': {'usd': 0},
        }, 'ethereum'),
        isNull,
      );
    });
  });

  group('deriveUsdtVesFromGlobal (v23.2 · último recurso)', () {
    test('Bs por USDT = paralelo × precio global del tether', () {
      final derived = deriveUsdtVesFromGlobal(
        RateEntry(rate: 0.9986, updatedAt: DateTime(2026, 11, 21)),
        RateEntry(rate: 1069.737113, updatedAt: DateTime(2026, 11, 20)),
      );
      expect(derived, isNotNull);
      expect(derived!.rate, closeTo(1069.737113 * 0.9986, 1e-6));
      // v23.3 (pez 2-b P1-4): sello honesto — un valor derivado solo es
      // tan fresco como su insumo MÁS VIEJO (antes afirmábamos el máx y
      // el now() de CoinGecko pintaba «hace 0 min» sobre un paralelo
      // con horas de antigüedad).
      expect(derived.updatedAt, DateTime(2026, 11, 20));
    });

    test('guards: tether fuera de rango o paralelo muerto → null', () {
      // Un tether a 5 USD es basura (hack/API rota) — no se deriva.
      expect(
        deriveUsdtVesFromGlobal(
          RateEntry(rate: 5.0, updatedAt: DateTime(2026, 11, 21)),
          RateEntry(rate: 1069.73, updatedAt: DateTime(2026, 11, 20)),
        ),
        isNull,
      );
      expect(
        deriveUsdtVesFromGlobal(
          RateEntry(rate: 0.9986, updatedAt: DateTime(2026, 11, 21)),
          null,
        ),
        isNull,
      );
      expect(
        deriveUsdtVesFromGlobal(
          RateEntry(rate: 0.9986, updatedAt: DateTime(2026, 11, 21)),
          RateEntry(rate: 0, updatedAt: DateTime(2026, 11, 20)),
        ),
        isNull,
      );
    });

    test('v23.3: bordes EXACTOS de la guardia 0.2–2 y finitud (pez 2-b)', () {
      final par = RateEntry(rate: 1069.73, updatedAt: DateTime(2026, 11, 20));
      // Tether exactamente en los bordes del rango: basura, no se deriva.
      expect(deriveUsdtVesFromGlobal(RateEntry(rate: 0.2, updatedAt: DateTime(2026, 11, 21)), par), isNull);
      expect(deriveUsdtVesFromGlobal(RateEntry(rate: 2.0, updatedAt: DateTime(2026, 11, 21)), par), isNull);
      // Paralelo negativo: no se deriva.
      expect(
        deriveUsdtVesFromGlobal(
          RateEntry(rate: 0.9986, updatedAt: DateTime(2026, 11, 21)),
          RateEntry(rate: -1069.73, updatedAt: DateTime(2026, 11, 20)),
        ),
        isNull,
      );
      // Paralelo no finito (P2-4): jamás llega Infinity a la UI.
      expect(
        deriveUsdtVesFromGlobal(
          RateEntry(rate: 0.9986, updatedAt: DateTime(2026, 11, 21)),
          RateEntry(rate: double.infinity, updatedAt: DateTime(2026, 11, 20)),
        ),
        isNull,
      );
      expect(
        deriveUsdtVesFromGlobal(
          RateEntry(rate: double.infinity, updatedAt: DateTime(2026, 11, 21)),
          par,
        ),
        isNull,
      );
    });
  });

  group('mergeSseSources (v23.3 · pez 2-b P1-1: el SSE fusiona, no reemplaza)', () {
    test('payload PARCIAL: lo ausente sobrevive (cripto/CO del poll viven)', () {
      final current = {
        'ves-bcv': RateEntry(rate: 918.76, updatedAt: DateTime(2026, 11, 21, 8)),
        'usdt-ves': RateEntry(rate: 1075.67, updatedAt: DateTime(2026, 11, 21, 8)),
        'cop-market': RateEntry(rate: 3345.39, updatedAt: DateTime(2026, 11, 21, 8)),
      };
      // Push de un despliegue web SIN las fuentes v23.2.
      final incoming = {
        'ves-bcv': RateEntry(rate: 919.01, updatedAt: DateTime(2026, 11, 21, 8, 5)),
      };
      final merged = mergeSseSources(current, incoming);
      expect(merged.length, 3); // NADA se pierde
      expect(merged['usdt-ves']!.rate, 1075.67);
      expect(merged['cop-market']!.rate, 3345.39);
      expect(merged['ves-bcv']!.rate, 919.01); // la fresca del push gana
    });

    test('push VIEJO no pisa dato fresco del poll (updatedAt decide)', () {
      final current = {
        'ves-bcv': RateEntry(rate: 919.01, updatedAt: DateTime(2026, 11, 21, 8, 5)),
      };
      final incoming = {
        'ves-bcv': RateEntry(rate: 915.00, updatedAt: DateTime(2026, 11, 21, 7)), // más viejo
      };
      final merged = mergeSseSources(current, incoming);
      expect(merged['ves-bcv']!.rate, 919.01);
    });

    test('misma marca de tiempo: gana el push (empate no regresa)', () {
      final t = DateTime(2026, 11, 21, 8);
      final merged = mergeSseSources(
        {'ves-bcv': RateEntry(rate: 918.76, updatedAt: t)},
        {'ves-bcv': RateEntry(rate: 918.80, updatedAt: t)},
      );
      expect(merged['ves-bcv']!.rate, 918.80);
    });
  });

  group('mergeRegionBlocks (v23.3 · contrato de claves internas)', () {
    test('un bloque con __tetherDerive__ JAMÁS lo publica como fuente', () {
      final block = (
        <String, RateEntry>{
          'usdt-usd': RateEntry(rate: 0.9986, updatedAt: DateTime(2026, 11, 21)),
          '__tetherDerive__': RateEntry(rate: 0.9986, updatedAt: DateTime(2026, 11, 21)),
        },
        <String>[],
        <String>['coingecko.com'],
      );
      final result = mergeRegionBlocks([block], null);
      expect(result.board.sources.containsKey('__tetherDerive__'), isFalse);
      expect(result.board.sources.containsKey('usdt-usd'), isTrue);
    });
  });

  group('parseCalculayaTasas (v23.3 · tolerancia extra, pez 2-b gaps)', () {
    test('números como STRING («usd»: "918.76") se toleran', () {
      final v = {
        'usd': '918.76',
        'eur': '1009.07',
        'usdt': '1075.67',
        'rate_date': '2026-11-20',
      };
      final out = parseCalculayaTasas(v);
      expect(out['ves-bcv']!.rate, closeTo(918.76, 1e-9));
      expect(out['eur-ves-oficial']!.rate, closeTo(1009.07, 1e-9));
      expect(out['usdt-ves']!.rate, closeTo(1075.67, 1e-9));
    });

    test('sin rate_date: el sello cae a ahora() sin lanzar', () {
      final out = parseCalculayaTasas({'usd': 918.76});
      expect(out['ves-bcv'], isNotNull);
      expect(
        DateTime.now().difference(out['ves-bcv']!.updatedAt).inMinutes,
        lessThan(1),
      );
    });
  });

  group('parseCoinGeckoUsd (v23.3 · bordes, pez 2-b gaps)', () {
    test('moneda sin clave usd y valor negativo → null', () {
      expect(parseCoinGeckoUsd({'tether': {}}, 'tether'), isNull);
      expect(parseCoinGeckoUsd({'tether': {'usd': -1}}, 'tether'), isNull);
      expect(parseCoinGeckoUsd({'tether': {'usd': 'x'}}, 'tether'), isNull);
      expect(
        parseCoinGeckoUsd({'tether': {'usd': 0.9986}}, 'tether')!.rate,
        closeTo(0.9986, 1e-9),
      );
    });
  });
}
