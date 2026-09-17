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
        'ves-parallel': RateEntry(rate: 260.00, updatedAt: DateTime(2026, 9, 12)),
        'brl-br': RateEntry(rate: 5.10, updatedAt: DateTime(2026, 9, 12)),
      });
      // Las regiones caen igual que en producción: bloque con fuentes vacías
      // + su lista de errores (el catch de cada bloque se queda con el error).
      final dead = List.generate(4, (_) => const (<String, RateEntry>{}, <String>['HTTP 503'], <String>[]));
      final result = mergeRegionBlocks(dead, prev);
      expect(result.board.sources['ves-bcv']!.rate, closeTo(234.89, 1e-9));
      expect(result.board.sources['ves-parallel']!.rate, closeTo(260.00, 1e-9));
      expect(result.board.sources['brl-br']!.rate, closeTo(5.10, 1e-9));
      // Nada cambió de tasa: cero cambios reportados y la caída sí queda
      // registrada en degraded (el usuario la ve, el tablero no la inventa).
      expect(result.changed, isEmpty);
      expect(result.board.degraded, isNotEmpty);
    });

    test('la fuente fresca pisa a la vieja; la región caída conserva la suya', () {
      final prev = boardOf({
        'ves-bcv': RateEntry(rate: 234.89, updatedAt: DateTime(2026, 9, 12)),
        'brl-br': RateEntry(rate: 5.10, updatedAt: DateTime(2026, 9, 13)),
      });
      final blocks = <RegionBlock>[
        (
          {'ves-bcv': RateEntry(rate: 240.00, updatedAt: DateTime(2026, 9, 15))},
          <String>[],
          <String>['dolarapi.com'],
        ),
        const (<String, RateEntry>{}, <String>['brl-br: HTTP 500'], <String>[]),
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
    });

    test('sin previous la fusión se comporta igual que siempre', () {
      final blocks = <RegionBlock>[
        (
          {'ves-bcv': RateEntry(rate: 240.00, updatedAt: DateTime(2026, 9, 15))},
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
}
