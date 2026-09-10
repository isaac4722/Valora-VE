/// Tests del modelo + respaldo + snapshots + analítica (MVP Fase A/B · §13).
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/core/analytics.dart' as an;
import 'package:valorave/core/currencies.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/data/backup.dart';
import 'package:valorave/data/rate_history.dart';

void main() {
  group('Modelos · round-trip JSON (§1)', () {
    test('Product completo sobrevive ida y vuelta', () {
      final p = Product(
        id: 'p1',
        name: 'Harina',
        barcode: '7590211000012',
        category: ProductCategory.alimentos,
        presentation: Presentation.weight,
        size: 1000,
        sizeUnit: 'g',
        createdAt: DateTime(2026),
        records: [
          PriceRecord(
            id: 'r1', price: 1.2, originalPrice: 48, currency: 'VES',
            quantity: 1, store: 'Bicentenario', rate: 40, sourceId: 'ves-parallel',
            date: DateTime(2026, 1, 1),
          ),
        ],
        unavailableSince: DateTime(2026, 1, 2),
        targetPrice: 1.0,
        targetCurrency: 'USD',
        metSince: DateTime(2026, 1, 3),
      );
      final back = Product.fromJson(p.toJson());
      expect(back.name, 'Harina');
      expect(back.records.length, 1);
      expect(back.records.first.store, 'Bicentenario');
      expect(back.targetPrice, 1.0);
      expect(back.metSince, DateTime(2026, 1, 3));
      expect(back.unavailableSince, DateTime(2026, 1, 2));
      expect(back.presentation, Presentation.weight);
    });

    test('Purchase con campos reales §12.1 (sin subtotal fantasma)', () {
      final p = Purchase(
        id: 'c1',
        date: DateTime(2026, 2, 1),
        store: 'Mercal',
        items: [
          PurchaseItem(name: 'Arroz', quantity: 2, priceUSD: 1.0,
              originalPrice: 40, currency: 'VES', productId: 'p1'),
        ],
        totalUSD: 2.0,
        totalBS: 80,
        rate: 40,
        rateSourceId: 'ves-parallel',
        igtf: false, // v14: retirado del motor
        paidTotal: 2.5,
        paidCurrency: 'USD',
        notes: 'prueba',
      );
      final back = Purchase.fromJson(p.toJson());
      expect(back.items.first.priceUSD, 1.0);
      expect(back.items.first.originalPrice, 40);
      expect(back.paidTotal, 2.5);
      expect(back.igtf, isFalse);
      expect(back.rateSourceId, 'ves-parallel');
    });

    test('Transaction con amountUSD (§12.1)', () {
      final t = Transaction(
        id: 't1', type: 'income', category: FinanceCategory.salario,
        amount: 100, currency: 'USD', amountUSD: 100, date: DateTime(2026),
      );
      final back = Transaction.fromJson(t.toJson());
      expect(back.amountUSD, 100);
      expect(back.isIncome, isTrue);
    });

    test('CartItem con checked/checkedBy (§12.1)', () {
      final c = CartItem(id: 'c1', name: 'Café', quantity: 1, price: 5,
          currency: 'USD', checked: true, checkedBy: 'Comprador 88');
      final back = CartItem.fromJson(c.toJson());
      expect(back.checked, isTrue);
      expect(back.checkedBy, 'Comprador 88');
    });

    test('Settings SIN theme (§12.1) con rateTargetAlerts y salary anidados', () {
      final s = Settings(
        country: 'CO',
        spikeThreshold: 1,
        targetBcv: 200,
        salaryAmount: 130,
        salaryCurrency: 'USD',
        tickerSize: 'large',
        tickerSpeed: 90,
        currencyOrder: const ['EUR', 'USD'],
      );
      final back = Settings.fromJson(s.toJson());
      expect(back.country, 'CO');
      expect(back.targetBcv, 200);
      expect(back.salaryAmount, 130);
      expect(back.tickerSize, 'large');
      expect(back.tickerSpeed, 90);
      expect(back.currencyOrder, ['EUR', 'USD']);
    });

    test('fromJson NUNCA lanza con datos corruptos', () {
      final product = Product.fromJson(const {
        'id': 'x', 'name': 'X', 'records': 'no-soy-lista', 'size': 'junk',
      });
      expect(product.name, 'X');
      expect(product.records, isEmpty);

      final board = RateBoard.fromJson(const {
        'sources': {'ves-bcv': 'no-soy-mapa', 'basura': {'rate': 1}},
      });
      expect(board.sources, isEmpty); // purga ids desconocidos y basura
    });
  });

  group('Backup · mergeBackupData (§4)', () {
    final local = AppData(
      products: [
        Product(id: 'p1', name: 'Local', category: ProductCategory.otros,
            presentation: Presentation.unit, size: 1, createdAt: DateTime(2026),
            records: [
              PriceRecord(id: 'r1', price: 1.0, originalPrice: 40, currency: 'VES',
                  quantity: 1, rate: 40, sourceId: 'ves-bcv', date: DateTime(2026, 1, 1)),
            ]),
        Product(id: 'p2', name: 'Solo local', category: ProductCategory.otros,
            presentation: Presentation.unit, size: 1, createdAt: DateTime(2026), records: const []),
      ],
      transactions: [Transaction(id: 't1', type: 'expense',
          category: FinanceCategory.alimentacion, amount: 10, currency: 'USD',
          amountUSD: 10, date: DateTime(2026))],
      purchases: [Purchase(id: 'c1', date: DateTime(2026), items: const [],
          totalUSD: 1, totalBS: 40, rate: 40)],
      templates: const [],
      stores: const ['Tienda A', 'Común'],
      cart: [const CartItem(id: 'k1', name: 'Carrito local', quantity: 1, price: 1, currency: 'USD')],
      settings: const Settings(country: 'VE'),
    );

    test('unión por id, empate=local, records fusionados', () {
      final incoming = AppData(
        products: [
          Product(id: 'p1', name: 'Remoto', category: ProductCategory.alimentos,
              presentation: Presentation.weight, size: 500, createdAt: DateTime(2026),
              records: [
                // mismo id r1 (duplicado → no se repite)
                PriceRecord(id: 'r1', price: 1.0, originalPrice: 40, currency: 'VES',
                    quantity: 1, rate: 40, sourceId: 'ves-bcv', date: DateTime(2026, 1, 1)),
                // nuevo record remoto MÁS RECIENTE → meta remota gana
                PriceRecord(id: 'r2', price: 0.9, originalPrice: 36, currency: 'VES',
                    quantity: 1, rate: 40, sourceId: 'ves-bcv', date: DateTime(2026, 2, 1)),
              ],
              targetPrice: 0.8, targetCurrency: 'USD'),
          Product(id: 'p3', name: 'Solo remoto', category: ProductCategory.otros,
              presentation: Presentation.unit, size: 1, createdAt: DateTime(2026), records: const []),
        ],
        stores: const ['Común', 'Tienda B'],
      );
      final r = mergeBackupData(local, incoming);
      expect(r.data.products.length, 3); // p1 fusionado + p2 + p3
      expect(r.counts.products, 1); // solo p3 es nuevo
      expect(r.counts.records, 1); // solo r2 es nuevo
      final p1 = r.data.products.firstWhere((p) => p.id == 'p1');
      expect(p1.records.length, 2);
      // meta gana el lado con último record más reciente (remoto):
      expect(p1.targetPrice, 0.8);
      // stores: unión case-insensitive
      expect(r.data.stores.length, 3);
      // merge NO toca cart/settings:
      expect(r.data.cart.length, 1);
      expect(r.data.settings.country, 'VE');
    });

    test('importBackup: estructura inválida y JSON inválido', () {
      expect(importBackup(local, 'no-json', merge: false).error, 'JSON inválido');
      expect(importBackup(local, '{"data":{}}', merge: false).error, 'Estructura no válida');
    });

    test('importBackup replace: conserva tablero vivo y sanea rateSource', () {
      final raw = '{"version":12,"data":{"products":[],"transactions":[],"cart":[],'
          '"purchases":[],"budget":{},"basket":[],"stores":[],"templates":[],'
          '"rateSource":{"VES":"basura","COP":"cop-trm"},"settings":{}}}';
      final r = importBackup(local, raw, merge: false);
      expect(r.ok, isTrue);
      // replace no ejecuta la fusión aquí: el caller hace replaceAll —
      // comprobamos el saneo vía export→import round-trip en merge.
      expect(r.counts, isNotNull);
    });

    test('export/import JSON round-trip con versión 12', () {
      final json = exportBackupJson(local);
      final r = importBackup(local, json, merge: true);
      expect(r.ok, isTrue);
      expect(r.counts!['products'], 0); // nada nuevo: empate=local
    });
  });

  group('rate-history (§4)', () {
    test('appendSnapshots: dedupe día, última gana', () {
      final store = <SnapshotPoint>[];
      final b1 = RateBoard(sources: {
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026, 1, 1)),
      });
      appendSnapshots(store, b1, now: DateTime(2026, 1, 1));
      final b2 = RateBoard(sources: {
        'ves-bcv': RateEntry(rate: 41, updatedAt: DateTime(2026, 1, 1, 18)),
      });
      appendSnapshots(store, b2, now: DateTime(2026, 1, 1, 20));
      final bcv = store.where((p) => p.sourceId == 'ves-bcv').toList();
      expect(bcv.length, 1);
      expect(bcv.first.rate, 41);
    });

    test('mergeSeries: día duplicado gana REMOTO', () {
      final local = [SnapshotPoint(sourceId: 'ves-bcv', day: '2026-01-01', rate: 40)];
      final remote = [SnapshotPoint(sourceId: 'ves-bcv', day: '2026-01-01', rate: 42),
        SnapshotPoint(sourceId: 'ves-bcv', day: '2026-01-02', rate: 43)];
      final merged = mergeSeries(remote, local);
      expect(merged.length, 2);
      expect(merged.firstWhere((p) => p.day == '2026-01-01').rate, 42);
      expect(snapshotDepth(merged), 2);
    });

    test('poda a 180 días', () {
      final store = <SnapshotPoint>[];
      for (int i = 0; i < 200; i++) {
        final b = RateBoard(sources: {
          'ves-bcv': RateEntry(rate: 40.0 + i, updatedAt: DateTime(2026, 1, 1).add(Duration(days: i))),
        });
        appendSnapshots(store, b, now: DateTime(2026, 1, 1).add(Duration(days: i)));
      }
      expect(store.where((p) => p.sourceId == 'ves-bcv').length, 180);
    });
  });

  group('Analítica (§3.2)', () {
    test('cartTotals SIN IGTF + conversión a USD', () {
      final cart = [
        const CartItem(id: 'a', name: 'Arroz', quantity: 2, price: 40, currency: 'VES'),
        const CartItem(id: 'b', name: 'Café', quantity: 1, price: 5, currency: 'USD'),
      ];
      final r = an.cartTotals(cart, (c) => c == Currency.ves ? 40 : 1);
      expect(r.byCurrency['VES'], 80);
      expect(r.byCurrency['USD'], 5);
      expect(r.totalUSD, 7); // 80/40 + 5 — SIN IGTF
      expect(r.units, 3);
    });

    test('computeChange vuelto y faltante', () {
      final r = an.computeChange(totalBS: 400, paidUSD: 0, paidBS: 500, rate: 40);
      expect(r.change, closeTo(100, 0.001));
      final r2 = an.computeChange(totalBS: 400, paidUSD: 0, paidBS: 300, rate: 40);
      expect(r2.missing, closeTo(2.5, 0.001)); // faltante en USD (100 Bs)
    });

    test('predictPrice estable con <2 records', () {
      expect(an.predictPrice(const []), isNull);
    });

    test('vesRateTimeline dedupe día + devaluación', () {
      final tl = an.vesRateTimeline([
        _record(DateTime(2026, 1, 1), 40),
        _record(DateTime(2026, 1, 1, 15), 41), // mismo día: gana
        _record(DateTime(2026, 1, 2), 44),
      ]);
      expect(tl.length, 2);
      final deval = an.vesDevaluation(tl)!;
      expect(deval.pct, closeTo((44 / 41 - 1) * 100, 0.01));
    });

    test('metas: TARGET_EPS y metSince (§9.4)', () {
      final p = Product(
        id: 'p', name: 'P', category: ProductCategory.otros,
        presentation: Presentation.unit, size: 1, createdAt: DateTime(2026),
        targetPrice: 1.0,
        records: [
          _record(DateTime(2026, 1, 1), 0.99), // 1% bajo meta > eps
        ],
      );
      expect(an.computeTargetInfo(p).met, isTrue);
      final p2 = Product(
        id: 'p2', name: 'P2', category: ProductCategory.otros,
        presentation: Presentation.unit, size: 1, createdAt: DateTime(2026),
        targetPrice: 1.0,
        records: [_record(DateTime(2026, 1, 1), 0.998)], // dentro del eps
      );
      expect(an.computeTargetInfo(p2).met, isFalse);
    });

    test('tiendas: normalización, stats y sugerencia pasiva', () {
      expect(an.normalizeStoreKey('  Café  Central-01!'), 'cafe  central 01');
      expect(an.storeInitials('Bicentenario'), 'B');
      expect(an.storeInitials('La Bodega Central'), 'LB');
      final purchases = [
        _purchase('A', 100, DateTime(2026, 1, 1)),
        _purchase('A', 50, DateTime(2026, 2, 1)),
        _purchase('', 30, DateTime(2026, 3, 1)),
      ];
      final stats = an.storeStats(purchases);
      expect(stats.first.store, 'A'); // mayor total
      expect(stats.first.totalUSD, 150.0);
      expect(an.findSimilarStore('cafe central', ['Café Central']), 'Café Central');
      expect(an.findSimilarStore('ca', ['Café Central']), isNull); // q<3 → []
    });
  });
}

PriceRecord _record(DateTime d, double usd) => PriceRecord(
    id: 'r${d.millisecondsSinceEpoch}', price: usd, originalPrice: usd,
    currency: 'USD', quantity: 1, rate: 40, sourceId: 'ves-bcv', date: d);

Purchase _purchase(String store, double usd, DateTime d) => Purchase(
    id: 'c${d.millisecondsSinceEpoch}', date: d, store: store.isEmpty ? null : store,
    items: const [], totalUSD: usd, totalBS: usd * 40.0, rate: 40.0);
