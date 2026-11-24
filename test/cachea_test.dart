/// Tests del Modo Cachea (v27.3): inicial + cuotas sin intereses.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/core/cachea.dart';

void main() {
  group('CacheaQuote', () {
    test('inicial 40 % + 3 cuotas: 40 + 20 + 20 + 20', () {
      final q = cacheaQuote(total: 100, initialPct: 40, quotas: 3)!;
      expect(q.initial, closeTo(40, 1e-9));
      expect(q.remaining, closeTo(60, 1e-9));
      expect(q.quota, closeTo(20, 1e-9));
      expect(q.totalWithInterest, closeTo(100, 1e-9));
      expect(q.payments, 4);
    });

    test('inicial 0 %: todo en cuotas; inicial 100 %: sin cuota pendiente', () {
      final a = cacheaQuote(total: 300, initialPct: 0, quotas: 6)!;
      expect(a.initial, 0);
      expect(a.quota, closeTo(50, 1e-9));
      final b = cacheaQuote(total: 300, initialPct: 100, quotas: 6)!;
      expect(b.initial, 300);
      expect(b.quota, 0);
    });

    test('datos inválidos → null (nunca lanza)', () {
      expect(cacheaQuote(total: 0, initialPct: 40, quotas: 3), isNull);
      expect(cacheaQuote(total: -10, initialPct: 40, quotas: 3), isNull);
      expect(cacheaQuote(total: 100, initialPct: 101, quotas: 3), isNull);
      expect(cacheaQuote(total: 100, initialPct: 40, quotas: 0), isNull);
      expect(cacheaQuote(total: double.nan, initialPct: 40, quotas: 3), isNull);
    });

    test('constantes del mercado: iniciales y cuotas', () {
      expect(kCacheaInitials, [20, 30, 40, 50]);
      expect(kCacheaQuotas, [3, 6, 9, 12]);
    });
  });
}
