/// Tests de los helpers puros de Análisis (§9.7 · TASK de reestructura):
/// rankings de compras por día/moneda · proyección DAMP · heatmap diario ·
/// CSV de brecha. Sin IO ni widgets — solo cálculo honesto.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/data/history_api.dart';
import 'package:valorave/features/insights/insights_utils.dart';

Purchase _p(String id, DateTime date, List<PurchaseItem> items,
        {double totalUSD = 0, String? paidCurrency}) =>
    Purchase(
      id: id,
      date: date,
      items: items,
      totalUSD: totalUSD,
      totalBS: 0,
      rate: 1,
      paidCurrency: paidCurrency,
    );

PurchaseItem _item(String name, double original, String currency,
        {double usd = 1, int qty = 1}) =>
    PurchaseItem(
      name: name,
      quantity: qty,
      priceUSD: usd,
      originalPrice: original,
      currency: currency,
    );

void main() {
  _gastosGroup();
  group('weekdaySpend · gasto por día de la semana', () {
    test('agrupa por weekday con total USD efectivo y conteo', () {
      // Lunes 2026-09-07 · viernes 2026-09-11 · lunes 2026-09-14.
      final ps = [
        _p('a', DateTime(2026, 9, 7), [_item('x', 10, 'USD', usd: 10)], totalUSD: 10),
        _p('b', DateTime(2026, 9, 11), [_item('y', 20, 'USD', usd: 20)], totalUSD: 20),
        _p('c', DateTime(2026, 9, 14), [_item('z', 5, 'USD', usd: 5)], totalUSD: 5),
      ];
      final rows = weekdaySpend(ps);
      expect(rows.length, 7);
      expect(rows[0].day, 'Lun'); // índice 0 = lunes
      expect(rows[0].totalUSD, 15); // 10 + 5
      expect(rows[0].count, 2);
      expect(rows[4].day, 'Vie');
      expect(rows[4].totalUSD, 20);
      expect(rows[4].count, 1);
      expect(rows[6].day, 'Dom');
      expect(rows[6].totalUSD, 0);
    });

    test('paidTotal (ajustado) manda sobre totalUSD', () {
      final ps = [
        Purchase(
          id: 'a',
          date: DateTime(2026, 9, 7),
          items: [_item('x', 10, 'USD', usd: 10)],
          totalUSD: 10,
          totalBS: 0,
          rate: 1,
          paidTotal: 12,
        ),
      ];
      expect(weekdaySpend(ps)[0].totalUSD, 12);
    });
  });

  group('currencySpend · gasto por divisa', () {
    test('suma por moneda original y ordena por USD', () {
      final ps = [
        _p('a', DateTime(2026, 9, 7), [
          _item('pan', 40, 'VES', usd: 1),
          _item('queso', 2, 'USD', usd: 2),
        ]),
        _p('b', DateTime(2026, 9, 8), [
          _item('café', 5000, 'COP', usd: 1.25, qty: 2),
        ]),
      ];
      final rows = currencySpend(ps);
      expect(rows.length, 3);
      // Orden por USD: COP(1.25×2=2.5) > USD(2) > VES(1).
      expect(rows.first.currency, 'COP');
      expect(rows.first.totalOriginal, 10000); // 5000 × 2
      expect(rows.first.totalUSD, 2.5);
      expect(rows.first.items, 1);
      expect(rows[1].currency, 'USD');
      expect(rows[1].totalOriginal, 2);
      expect(rows[2].currency, 'VES');
      expect(rows[2].totalOriginal, 40);
    });

    test('vacío sin compras', () => expect(currencySpend([]), isEmpty));
  });

  group('dampProjection · proyección amortiguada (φ 0.85)', () {
    test('null con <2 puntos o <4 días (estable, no inventa)', () {
      expect(dampProjection([]), isNull);
      expect(
          dampProjection([
            (day: DateTime(2026, 9, 1), value: 10),
          ]),
          isNull);
      expect(
          dampProjection([
            (day: DateTime(2026, 9, 1), value: 10),
            (day: DateTime(2026, 9, 2), value: 11),
          ]),
          isNull); // 1 día de historia
    });

    test('misma semántica que predictPrice: media por tramos amortiguada', () {
      // 10 → 12 en 6 días: pct tramo = 0.2, amortiguado 0.17; lineal 30 d.
      final proj = dampProjection([
        (day: DateTime(2026, 9, 1), value: 10),
        (day: DateTime(2026, 9, 7), value: 12),
      ])!;
      expect(proj.dailyPct, closeTo(17.0, 0.001)); // 0.2 × 0.85 × 100
      expect(proj.points.length, 30);
      expect(proj.points.first.day, DateTime(2026, 9, 8));
      // v_k = 12 × (1 + 0.17 × k) — acumulación LINEAL.
      expect(proj.points.first.value, closeTo(12 * 1.17, 0.001));
      expect(proj.points.last.value, closeTo(12 * (1 + 0.17 * 30), 0.001));
    });

    test('ordena la serie de entrada (nunca confía en el orden)', () {
      final proj = dampProjection([
        (day: DateTime(2026, 9, 7), value: 12),
        (day: DateTime(2026, 9, 1), value: 10),
      ])!;
      expect(proj.points.first.day, DateTime(2026, 9, 8));
    });
  });

  group('devaluationDaily · heatmap de devaluación', () {
    test('pct vs el día anterior con datos', () {
      final out = devaluationDaily([
        const SnapshotPoint(sourceId: 'ves-bcv', day: '2026-09-01', rate: 40),
        const SnapshotPoint(sourceId: 'ves-bcv', day: '2026-09-02', rate: 42),
        const SnapshotPoint(sourceId: 'ves-bcv', day: '2026-09-04', rate: 42),
      ]);
      // 02: +5 % · 04: 0 % (vs 02, el día 03 no existe).
      expect(out.length, 2);
      expect(out[0].day, '2026-09-02');
      expect(out[0].pct, closeTo(5.0, 0.001));
      expect(out[1].day, '2026-09-04');
      expect(out[1].pct, closeTo(0.0, 0.001));
    });

    test('nunca divide por cero (tasas ≤ 0 se saltan)', () {
      final out = devaluationDaily([
        const SnapshotPoint(sourceId: 'ves-bcv', day: '2026-09-01', rate: 0),
        const SnapshotPoint(sourceId: 'ves-bcv', day: '2026-09-02', rate: 42),
        const SnapshotPoint(sourceId: 'ves-bcv', day: '2026-09-03', rate: -1),
      ]);
      expect(out, isEmpty);
    });
  });

  group('gapCsvRows · exportGapCsv', () {
    test('solo días con ambas tasas; brecha = paralelo/BCV − 1', () {
      final rows = gapCsvRows([
        const HistPoint(date: '2026-09-01', rate: 40),
        const HistPoint(date: '2026-09-02', rate: 40),
      ], [
        const HistPoint(date: '2026-09-01', rate: 45),
        const HistPoint(date: '2026-09-03', rate: 50), // sin BCV: fuera
      ]);
      expect(rows.length, 2); // encabezado + 01
      expect(rows[0], ['Dia', 'BCV', 'Paralelo', 'Brecha %']);
      expect(rows[1][0], '2026-09-01');
      expect(rows[1][1], '40.0000');
      expect(rows[1][2], '45.0000');
      expect(rows[1][3], '12.50');
    });

    test('encabezado solo cuando no hay pares completos', () {
      final rows = gapCsvRows([], [const HistPoint(date: '2026-09-01', rate: 45)]);
      expect(rows.length, 1);
      expect(rows.first.first, 'Dia');
    });
  });
}

/// ── Gastos de compras (v17.8): monthSpend + storeSpend ─────────────────────
/// Ancla «Gastos» de Análisis — agregados puros sobre Purchase.
void _gastosGroup() {
  group('monthSpend · gasto por mes (v17.8)', () {
    test('buckets cronológicos aunque las etiquetas no lo sean alfabético', () {
      // ene < abr < dic: alfabético daría abr/ene/dic (mal) — cronológico manda.
      final ps = [
        _p('a', DateTime(2026, 1, 15), [], totalUSD: 10),
        _p('b', DateTime(2026, 4, 2), [], totalUSD: 20),
        _p('c', DateTime(2026, 12, 9), [], totalUSD: 30),
      ];
      final out = monthSpend(ps, months: 12);
      expect(out.length, 3);
      expect(out.first.month, contains('ene'));
      expect(out.last.month, contains('dic'));
      expect(out.map((m) => m.totalUSD), [10, 20, 30]);
    });

    test('suma varias compras del MISMO mes en un bucket', () {
      final ps = [
        _p('a', DateTime(2026, 9, 1), [], totalUSD: 4),
        _p('b', DateTime(2026, 9, 18), [], totalUSD: 6),
      ];
      final out = monthSpend(ps, months: 6);
      expect(out.length, 1);
      expect(out.first.totalUSD, 10);
      expect(out.first.count, 2);
    });

    test('fuera de la ventana: ni bucket ni suma', () {
      final ps = [
        _p('viejo', DateTime(2020, 1, 1), [], totalUSD: 999),
      ];
      expect(monthSpend(ps, months: 6), isEmpty);
    });

    test('usa el total EFECTIVO (paidUSD) cuando se ajustó el pago', () {
      final p = _p('a', DateTime(2026, 9, 5), [], totalUSD: 100)
          .copyWith(paidTotal: 90);
      final out = monthSpend([p], months: 6);
      expect(out.first.totalUSD, 90);
    });
  });

  group('storeSpend · gasto por tienda (v17.8)', () {
    test('agrupa por tienda con top + «Otras» agrupadas', () {
      final ps = [
        _p('a', DateTime(2026, 9, 1), [], totalUSD: 50),
        _p('b', DateTime(2026, 9, 2), [], totalUSD: 30),
      ];
      // _p no lleva store → todos caen en 'Sin tienda' (un solo bucket).
      var out = storeSpend(ps);
      expect(out.length, 1);
      expect(out.first.store, 'Sin tienda');
      expect(out.first.totalUSD, 80);

      // Ahora sí con tiendas distintas + límite 2 → «Otras» agrupa.
      final withStores = [
        _p('a', DateTime(2026, 9, 1), [], totalUSD: 50).copyWith(store: 'A'),
        _p('b', DateTime(2026, 9, 1), [], totalUSD: 40).copyWith(store: 'B'),
        _p('c', DateTime(2026, 9, 1), [], totalUSD: 20).copyWith(store: 'C'),
        _p('d', DateTime(2026, 9, 1), [], totalUSD: 10).copyWith(store: 'D'),
      ];
      out = storeSpend(withStores, limit: 2);
      expect(out.length, 3); // A, B, Otras
      expect(out.first.store, 'A');
      expect(out.last.store, 'Otras');
      expect(out.last.totalUSD, 30); // C + D
    });

    test('compra multitienda reparte los ítems con SU tienda', () {
      final items = [
        _item('café', 10, 'USD', usd: 10, qty: 2),
        _item('pan', 5, 'USD', usd: 5, qty: 1),
      ];
      final multi = Purchase(
        id: 'm',
        date: DateTime(2026, 9, 3),
        items: [
          items[0].copyWith(store: 'Cafetería'),
          items[1].copyWith(store: 'Panadería'),
        ],
        totalUSD: 25,
        totalBS: 0,
        rate: 1,
      );
      final out = storeSpend([multi]);
      expect(out.length, 2);
      expect(out.first.store, 'Cafetería'); // 20 USD (10×2)
      expect(out.first.totalUSD, 20);
      expect(out.last.store, 'Panadería');
      expect(out.last.totalUSD, 5);
    });
  });
}
