/// ─── Integration tests (MVP Fase 7 · §Fase 9 checklist) ────────────────────
/// Flujos completos. Se ejecutan LOCAL antes de cada tag (docs/RELEASE.md);
/// CI corre solo unit+widget. Correr con:
///   `flutter test integration_test/app_test.dart -d <emulador>`   (ideal)
///   `flutter test integration_test/app_test.dart -d flutter-tester`
/// (en host los canales de plataforma están degradados: main() los tolera
/// y cada test hidrata Hive en un directorio temporal propio)
library;

import 'dart:convert';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/currencies.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/data/backup.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/lowder_entry.dart' as lowder;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // Canal home_widget simulado (solo infra de test): el flujo del tablero
  // llama a WidgetService.updateBcv tras cada fetch; en host no hay canal
  // real, así que respondemos OK para ejercitar la ruta completa.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('home_widget'),
          (call) async => true);

  group('Flujo completo · rama Lowder (Fase 4)', () {
    testWidgets('entry Lowder → la pantalla del .low renderiza', (tester) async {
      // En esta rama el entry es el de Lowder (lib/lowder_entry.dart):
      // el flujo UI de la app real se valida en fix/v1.1.0-dp4-paridad.
      // Aquí se verifica que la solución carga del .low y pinta su landing.
      await lowder.main();
      var aparecio = false;
      for (int i = 0; i < 20 && !aparecio; i++) {
        await tester.pump(const Duration(milliseconds: 200));
        aparecio = find.text('Hola desde un .low').evaluate().isNotEmpty;
      }
      expect(aparecio, isTrue,
          reason: 'assets/lowder/demo.low debía cargar su pantalla inicial');
    });

    testWidgets('conversión EUR→COP con arista', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('valorave_it');
      final store = AppStore();
      await store.hydrate(testDir: dir.path);
      store.setRateBoard(RateBoard(sources: {
        'eur-cop': RateEntry(rate: 4500, updatedAt: DateTime.now()),
        'cop-trm': RateEntry(rate: 4000, updatedAt: DateTime.now()),
      }));
      final ctx = store.contextOf();
      final plan = ctx.plan(Currency.eur, Currency.cop);
      expect(plan, isNotNull);
      // Arista directa eur-cop=4500: 100 EUR → 450.000 COP, y la inversa
      // 100 COP → 100/4500 EUR. El promedio ves-avg no interviene aquí.
      expect(ctx.convert(100, Currency.eur, Currency.cop), closeTo(450000, 0.01));
      expect(ctx.convert(100, Currency.cop, Currency.eur), closeTo(100 / 4500, 0.0001));
    });

    testWidgets('alta de producto → registro de precio → meta cumplida', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('valorave_it');
      final store = AppStore();
      await store.hydrate(testDir: dir.path);
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
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('valorave_it');
      final store = AppStore();
      await store.hydrate(testDir: dir.path);
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
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('valorave_it');
      final store = AppStore();
      await store.hydrate(testDir: dir.path);
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
