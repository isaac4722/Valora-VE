/// Tests de formato es-VE (§3.3): números, fechas, parsers tolerantes,
/// búsqueda sin acentos y CSV.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/core/currencies.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/core/fmt.dart';

void main() {
  group('fmtNum es-VE', () {
    test('punto de miles y coma decimal', () {
      expect(fmtNum(1234.56), '1.234,56');
      expect(fmtNum(1000000, decimals: 0), '1.000.000');
      expect(fmtNum(0.5, decimals: 2), '0,50');
      expect(fmtNum(-5.5), '−5,50');
    });

    test('smartDecimals: COP 0 · <1 → 4 · resto moneda', () {
      expect(smartDecimals(4200000, CurrencyX.from('COP')), 0);
      expect(smartDecimals(0.5, CurrencyX.from('USD')), 4);
      expect(smartDecimals(915.38, CurrencyX.from('USD')), 2);
    });

    test('fmtRate: ≥100 → 2 · ≥1 → 4 · <1 → 6', () {
      expect(fmtRate(915.381234), '915,38');
      expect(fmtRate(43.401234), '43,4012');
      expect(fmtRate(0.5), '0,500000');
    });

    test('fmtEurRate: siempre 4 decimales', () {
      expect(fmtEurRate(43.4), '43,4000');
    });

    test('fmtPct con signo', () {
      expect(fmtPct(2.14), '+2,1 %');
      expect(fmtPct(-3.2), '−3,2 %');
    });
  });

  group('fechas es-VE', () {
    test('fmtDate «02-feb-2026»', () {
      expect(fmtDate(DateTime(2026, 2, 2)), '02-feb-2026');
    });

    test('fmtDateLong completo', () {
      // sábado 6 de septiembre de 2026
      expect(fmtDateLong(DateTime(2026, 9, 5)),
          'sábado, 5 de septiembre de 2026');
    });

    test('timeAgo: instantes/min/horas/días', () {
      final now = DateTime(2026, 9, 10, 12);
      expect(timeAgo(now, now), 'hace instantes');
      expect(timeAgo(now.subtract(const Duration(minutes: 5)), now), 'hace 5 min');
      expect(timeAgo(now.subtract(const Duration(hours: 3)), now), 'hace 3 h');
      expect(timeAgo(now.subtract(const Duration(days: 2)), now), 'hace 2 d');
    });

    test('saludo por hora', () {
      expect(saludo(DateTime(2026, 1, 1, 9)), 'Buenos días');
      expect(saludo(DateTime(2026, 1, 1, 14)), 'Buenas tardes');
      expect(saludo(DateTime(2026, 1, 1, 21)), 'Buenas noches');
    });
  });

  group('parsers tolerantes (§3.3)', () {
    test('parseLocaleNum acepta formatos mixtos', () {
      expect(parseLocaleNum('1.234,56'), 1234.56);
      expect(parseLocaleNum('1234.56'), 1234.56);
      expect(parseLocaleNum('1.234'), 1234); // separador de miles
      expect(parseLocaleNum('1234'), 1234);
      expect(parseLocaleNum('\$915,38'), 915.38);
      expect(parseLocaleNum('Bs. 40'), 40);
      expect(parseLocaleNum('−5'), -5);
      expect(parseLocaleNum(''), isNull);
      expect(parseLocaleNum('abc'), isNull);
      expect(parseLocaleNum(null), isNull);
    });

    test('parseDateField ISO', () {
      expect(parseDateField('2026-09-10'), DateTime(2026, 9, 10));
      expect(parseDateField('nada'), isNull);
      expect(parseDateField(null), isNull);
    });
  });

  group('búsqueda sin acentos (fold)', () {
    test('fold normaliza acentos y mayúsculas', () {
      expect(fold('HIGIENE'), 'higiene');
      expect(fold('Alimentación'), 'alimentacion');
      expect(fold('píceas'), 'piceas');
    });

    test('coincidencias sin acentos', () {
      expect(fold('Café molido'.toLowerCase()).contains(fold('cafe')), isTrue);
    });
  });

  group('CSV (toCSV/parseCSV)', () {
    test('round-trip con delimitador coma', () {
      final rows = [
        ['Producto', 'Precio'],
        ['Café "especial"', '9,50'],
      ];
      final text = toCSV(rows);
      final parsed = parseCSV(text);
      expect(parsed[0][0], 'Producto');
      expect(parsed[1][0], 'Café "especial"');
    });

    test('delimitador punto y coma (Excel es-VE)', () {
      final parsed = parseCSV('a;b\nc;d');
      expect(parsed.length, 2);
      expect(parsed[1], ['c', 'd']);
    });

    test('salto de línea embebido en comillas', () {
      final parsed = parseCSV('a,"línea1\nlínea2",c');
      expect(parsed[0][1], 'línea1\nlínea2');
      expect(parsed[0][2], 'c');
    });

    test('BOM se descarta', () {
      final parsed = parseCSV('\ufeffa,b');
      expect(parsed[0][0], 'a');
    });
  });

  group('presentationLabel', () {
    test('peso 1000 g → «1 kg»', () {
      final p = Product(
        id: '1', name: 'Harina', category: ProductCategory.alimentos,
        presentation: Presentation.weight, size: 1000,
        createdAt: DateTime(2026), records: const [],
      );
      expect(presentationLabel(p), '1 kg');
    });

    test('volumen 2000 ml → «2 L»', () {
      final p = Product(
        id: '2', name: 'Refresco', category: ProductCategory.bebidas,
        presentation: Presentation.volume, size: 2000,
        createdAt: DateTime(2026), records: const [],
      );
      expect(presentationLabel(p), '2 L');
    });
  });
}
