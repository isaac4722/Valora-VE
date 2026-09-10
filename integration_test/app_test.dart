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
import 'package:valorave/main.dart' as app;

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
  binding.framePolicy = LiveTestWidgetsFlutterBindingFramePolicy.fullyLive;

  // Canal home_widget simulado (solo infra de test): el flujo del tablero
  // llama a WidgetService.updateBcv tras cada fetch; en host no hay canal
  // real, así que respondemos OK para ejercitar la ruta completa.
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(const MethodChannel('home_widget'),
          (call) async => true);

  group('Flujo completo · primer arranque', () {
    testWidgets('arranque → onboarding → tablero honesto sin red', (tester) async {
      // En host (flutter-tester) el binding live NO despacha taps a la vista
      // (multi-view de Flutter 3.47): este flujo UI se valida en emulador o
      // dispositivo real (docs/RELEASE.md §2); el onboarding queda cubierto
      // además por widget tests en test/. En host se salta con motivo.
      if (!Platform.isAndroid && !Platform.isIOS) {
        // ignore: avoid_print
        print('SKIP host: flujo UI de onboarding requiere emulador/dispositivo '
            '(binding live sin dispatch de taps); ver docs/RELEASE.md §2.');
        return;
      }
      SharedPreferences.setMockInitialValues({});
      final dir = await Directory.systemTemp.createTemp('valorave_it');
      await app.main(documentsDir: dir.path);
      await tester.pumpAndSettle(const Duration(seconds: 2));

      // Toca [tapText] y espera a que aparezca [waitText]. En el binding
      // live los taps de tester.tap se pierden (multi-view en host), así
      // que se usa el gesto manual documentado: down → pump → up → pump.
      Future<void> tapUntilFound(String tapText, String waitText) async {
        for (int t = 0; t < 10; t++) {
          if (find.text(waitText).evaluate().isNotEmpty) return;
          final f = find.text(tapText);
          if (f.evaluate().isNotEmpty) {
            final center = tester.getCenter(f);
            final gesture = await tester.startGesture(center);
            await tester.pump(const Duration(milliseconds: 40));
            await gesture.up();
            await tester.pumpAndSettle();
          } else {
            await tester.pump(const Duration(milliseconds: 120));
          }
        }
      }

      // Onboarding si no se ha completado: Paso0 → Paso1 país → 7 slides
      // (Siguiente ×6) → Listo → Done.
      if (find.text('Comenzar').evaluate().isNotEmpty) {
        await tapUntilFound('Comenzar', 'Elegir Venezuela');
        await tapUntilFound('Elegir Venezuela', 'Siguiente');
        for (int i = 0; i < 6; i++) {
          final f = find.text('Siguiente');
          if (f.evaluate().isEmpty) break; // ya en la última slide
          final center = tester.getCenter(f);
          final gesture = await tester.startGesture(center);
          await tester.pump(const Duration(milliseconds: 40));
          await gesture.up();
          await tester.pumpAndSettle();
        }
        await tapUntilFound('Listo', 'Empezar a usar ValoraVE');
        await tapUntilFound('Empezar a usar ValoraVE', 'COTIZACIÓN PRINCIPAL');
      }
      // Tablero: sin red muestra estado honesto (con semilla real pendiente).
      expect(find.text('COTIZACIÓN PRINCIPAL'), findsOneWidget);
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
