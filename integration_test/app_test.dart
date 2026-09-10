/// ─── Integration tests (MVP Fase 7 · §Fase 9 checklist) ────────────────────
/// Flujos completos. Se ejecutan LOCAL antes de cada tag (docs/RELEASE.md);
/// CI corre solo unit+widget. Correr con:
///   `flutter test integration_test/app_test.dart -d <emulador>`
library;

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/currencies.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/data/backup.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  group('Flujo completo · primer arranque', () {
    testWidgets('arranque → onboarding → tablero honesto sin red', (tester) async {
      SharedPreferences.setMockInitialValues({});
      await app.main();
      await tester.pumpAndSettle(const Duration(seconds: 2));
      // Onboarding si no se ha completado.
      if (find.text('Comenzar').evaluate().isNotEmpty) {
        await tester.tap(find.text('Comenzar'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Elegir Venezuela'));
        await tester.pumpAndSettle();
        for (int i = 0; i < 6; i++) {
          await tester.tap(find.text('Siguiente'));
          await tester.pumpAndSettle();
        }
        await tester.tap(find.text('Listo'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Empezar a usar ValoraVE'));
        await tester.pumpAndSettle();
      }
      // Tablero: sin red muestra estado honesto (con semilla real pendiente).
      expect(find.text('COTIZACIÓN PRINCIPAL'), findsOneWidget);
    });

    testWidgets('conversión EUR→COP con arista', (tester) async {
      final store = AppStore();
      await store.hydrate();
      store.setRateBoard(RateBoard(sources: {
        'eur-cop': RateEntry(rate: 4500, updatedAt: DateTime.now()),
        'cop-trm': RateEntry(rate: 4000, updatedAt: DateTime.now()),
      }));
      final ctx = store.contextOf();
      final plan = ctx.plan(Currency.eur, Currency.cop);
      expect(plan, isNotNull);
      expect(ctx.convert(100, Currency.eur, Currency.cop), closeTo(100 * 4000 / 4500, 0.01));
    });

    testWidgets('alta de producto → registro de precio → meta cumplida', (tester) async {
      final store = AppStore();
      await store.hydrate();
      final p = store.addProduct(
        Product(id: '', name: 'Producto Integration', category: ProductCategory.otros,
            presentation: Presentation.unit, size: 1, createdAt: DateTime.now(), records: const []),
        null,
      );
      store.setTarget(p.id, 10);
      store.addRecord(p.id, PriceRecord(id: '', price: 9.0, originalPrice: 9, currency: 'USD',
          quantity: 1, rate: 1, sourceId: 'usd', date: DateTime.now()));
      expect(store.products.first.latestRecord!.price, 9.0);
      expect(store.products.first.metSince, isNotNull);
    });

    testWidgets('compra completa → checkout → asiento en historial', (tester) async {
      final store = AppStore();
      await store.hydrate();
      store.setRateBoard(RateBoard(sources: {
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime.now()),
        'ves-parallel': RateEntry(rate: 44, updatedAt: DateTime.now()),
      }));
      store.addToCart(const CartItem(id: '', name: 'Arroz', quantity: 2, price: 40, currency: 'VES'));
      final ctx = store.contextOf();
      final totals = (
        usd: 2.0,
        byCurrency: <Currency, double>{Currency.ves: 80},
        units: 2,
      );
      final purchase = Purchase(
        id: '', date: DateTime.now(), store: 'Integration Market',
        items: [PurchaseItem(name: 'Arroz', quantity: 2, priceUSD: 1.0,
            originalPrice: 40, currency: 'VES')],
        totalUSD: totals.usd, totalBS: totals.usd * 40, rate: 40,
        rateSourceId: ctx.sel(Currency.ves),
      );
      store.addPurchase(purchase);
      store.clearCart();
      expect(store.purchases.length, 1);
      expect(store.purchases.first.store, 'Integration Market');
      expect(store.cart, isEmpty);
    });

    testWidgets('respaldo → borrar todo → fusión recupera', (tester) async {
      final store = AppStore();
      await store.hydrate();
      store.addProduct(
        Product(id: 'prod-1', name: 'Para respaldo', category: ProductCategory.otros,
            presentation: Presentation.unit, size: 1, createdAt: DateTime.now(), records: const []),
        null,
      );
      final json = exportBackupJson(store.data);
      store.resetAll();
      expect(store.products, isEmpty);
      final r = importBackup(store.data, json, merge: true);
      expect(r.ok, isTrue);
      final incoming = AppData.fromJson(
          Map<String, dynamic>.from((jsonDecode(json) as Map)['data'] as Map));
      final merged = mergeBackupData(store.data, incoming);
      store.replaceAll(merged.data);
      expect(store.products.any((p) => p.id == 'prod-1'), isTrue);
    });
  });
}
