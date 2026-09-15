/// Tests del AppStore (§2 · todas las acciones) con Hive en directorio temp.
library;

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/currencies.dart';
import 'package:valorave/core/models.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:valorave/data/rate_history.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';

void main() {
  late Directory tmp;
  late AppStore store;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    SharedPreferences.setMockInitialValues({});
    tmp = await Directory.systemTemp.createTemp('valorave_test');
    store = AppStore();
    await store.hydrate(testDir: tmp.path);
  });

  tearDown(() async {
    await Hive.close(); // aísla cajas entre tests
    await tmp.delete(recursive: true);
  });

  group('Fuentes de tasa y motor', () {
    test('setRateBoard purga ids desconocidos y estampa fetchedAt', () {
      store.setRateBoard(RateBoard(
        sources: {
          'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026)),
          'fuente-muerta': RateEntry(rate: 1, updatedAt: DateTime(2026)),
        },
      ));
      expect(store.board.sources.containsKey('ves-bcv'), isTrue);
      expect(store.board.sources.containsKey('fuente-muerta'), isFalse);
      expect(store.board.fetchedAt, isNotNull);
    });

    test('setRateSource valida y hace fallback', () {
      store.setRateSource(Currency.ves, 'inventado');
      expect(store.sourceFor(Currency.ves), 'ves-bcv');
      store.setRateSource(Currency.ves, 'ves-parallel');
      expect(store.sourceFor(Currency.ves), 'ves-parallel');
    });

    test('setManualRate: >0 guarda, <=0 borra', () {
      store.setManualRate('ves-manual', 50);
      expect(store.contextOf().rate('ves-manual'), 50);
      store.setManualRate('ves-manual', -1);
      expect(store.contextOf().rate('ves-manual'), 0);
    });

    test('setModuleRateSource: inválido borra → global', () {
      store.setModuleRateSource(RateModule.converter, Currency.ves, 'ves-parallel');
      expect(store.settings.rateSourcesByModule['converter:VES'], 'ves-parallel');
      store.setModuleRateSource(RateModule.converter, Currency.ves, 'inventado');
      expect(store.settings.rateSourcesByModule.containsKey('converter:VES'), isFalse);
    });

    test('setCountry ajusta fuente EUR y converter USD→moneda del país', () {
      store.setCountry(Country.CO);
      expect(store.settings.country, 'CO');
      expect(store.data.rateSource['EUR'], 'eur-cop');
      expect(store.data.converter.from, 'USD');
      expect(store.data.converter.to, 'COP');
      // País con moneda USD (Global/US): el par cae a USD→VES (§2.1).
      store.setCountry(Country.US);
      expect(store.data.converter.to, 'VES');
    });
  });

  group('Productos (§2.2)', () {
    test('addProduct con firstRecord + addStore', () {
      final p = store.addProduct(
        Product(
          id: '', name: 'Café', category: ProductCategory.alimentos,
          presentation: Presentation.weight, size: 250,
          createdAt: DateTime(2026), records: const [],
        ),
        PriceRecord(id: '', price: 5.0, originalPrice: 200, currency: 'VES',
            quantity: 1, store: 'Bodega', rate: 40, sourceId: 'ves-bcv',
            date: DateTime(2026)),
      );
      expect(p.id, isNotEmpty);
      expect(p.records.length, 1);
      expect(store.stores, contains('Bodega'));
    });

    test('deleteProduct con cascada de canasta', () {
      final p = store.addProduct(
        Product(id: '', name: 'X', category: ProductCategory.otros,
            presentation: Presentation.unit, size: 1, createdAt: DateTime(2026), records: const []),
        null,
      );
      store.addToBasket(p.id, 2);
      store.deleteProduct(p.id);
      expect(store.products.any((x) => x.id == p.id), isFalse);
      expect(store.basket.any((b) => b.productId == p.id), isFalse);
    });

    test('addRecord estampa metSince al quedar bajo meta y limpia al subir', () {
      final p = store.addProduct(
        Product(id: '', name: 'Y', category: ProductCategory.otros,
            presentation: Presentation.unit, size: 1, createdAt: DateTime(2026), records: const []),
        null,
      );
      store.updateProduct(p.id, Product(
        id: p.id, name: 'Y', category: ProductCategory.otros,
        presentation: Presentation.unit, size: 1, createdAt: p.createdAt,
        records: p.records, targetPrice: 10,
      ));
      store.addRecord(p.id, PriceRecord(id: '', price: 9.0, originalPrice: 9, currency: 'USD',
          quantity: 1, rate: 1, sourceId: 'usd', date: DateTime(2026)));
      expect(store.products.first.metSince, isNotNull);
      store.addRecord(p.id, PriceRecord(id: '', price: 11.0, originalPrice: 11, currency: 'USD',
          quantity: 1, rate: 1, sourceId: 'usd', date: DateTime(2026, 2)));
      expect(store.products.first.metSince, isNull);
    });

    test('setUnavailable estampa y limpia', () {
      final p = store.addProduct(
        Product(id: '', name: 'Z', category: ProductCategory.otros,
            presentation: Presentation.unit, size: 1, createdAt: DateTime(2026), records: const []),
        null,
      );
      store.setUnavailable(p.id, true);
      expect(store.products.first.isUnavailable, isTrue);
      store.setUnavailable(p.id, false);
      expect(store.products.first.isUnavailable, isFalse);
    });

    test('importProducts dedupe por barcode y nombre', () {
      final n = store.importProducts([
        (name: 'Harina de maíz blanco', barcode: '7590211000012', date: null),
        (name: 'HARINA DE MAÍZ BLANCO', barcode: null, date: null),
        (name: 'Producto nuevo', barcode: null, date: null),
      ]);
      expect(n, 2); // dedupe por barcode+nombre: «Harina…» y «Producto nuevo»
    });

    test('importProducts: barcode manda, nombre sin barcode no bloquea otro', () {
      // Dos productos con MISMO nombre pero distinto barcode: con barcode el
      // dedupe es EXCLUSIVAMENTE por barcode → ambos entran.
      final n = store.importProducts([
        (name: 'Café', barcode: '111', date: null),
        (name: 'Café', barcode: '222', date: null),
        (name: 'Café', barcode: null, date: null), // sin barcode → dedupe por nombre
      ]);
      expect(n, 2);
    });

    test('addPurchase genera id único si viene sin él', () {
      store.addPurchase(Purchase(
        id: '',
        date: DateTime(2026),
        items: const [],
        totalUSD: 5,
        totalBS: 200,
        rate: 40,
      ));
      expect(store.purchases.first.id, isNotEmpty);
    });
  });

  group('Carrito, presupuesto y plantillas (§2.3/2.4)', () {
    test('addToCart: dedupe suma quantity', () {
      store.addToCart(const CartItem(id: '', name: 'Pan', quantity: 1, price: 10, currency: 'VES'));
      store.addToCart(const CartItem(id: '', name: 'pan', quantity: 2, price: 10, currency: 'VES'));
      expect(store.cart.length, 1);
      expect(store.cart.first.quantity, 3);
    });

    test('saveTemplate: null con carrito vacío; máx 20', () {
      expect(store.saveTemplate('Vacía'), isNull);
      for (int i = 0; i < 25; i++) {
        store.addToCart(CartItem(id: '', name: 'Item $i', quantity: 1, price: i.toDouble(), currency: 'USD'));
        store.saveTemplate('Plantilla $i');
      }
      expect(store.templates.length, kMaxTemplates);
    });

    test('applyTemplate merge con regla addToCart', () {
      store.addToCart(const CartItem(id: '', name: 'Pan', quantity: 1, price: 10, currency: 'VES'));
      final id = store.saveTemplate('Base');
      store.clearCart();
      expect(store.applyTemplate(id!), 1);
      store.applyTemplate(id);
      expect(store.cart.first.quantity, 2);
    });

    test('setBudget 0 limpia el monto pero CONSERVA la moneda (v19)', () {
      store.setBudget(100, 'VES');
      expect(store.data.budget.amount, 100);
      store.setBudget(0, 'VES');
      expect(store.data.budget.amount, 0);
      // Bug del dueño: cambiar la moneda sin monto la reseteaba a VES.
      store.setBudget(0, 'EUR');
      expect(store.data.budget.currency, 'EUR');
      expect(store.data.budget.amount, 0);
      store.setBudget(250, 'EUR');
      expect(store.data.budget.currency, 'EUR');
      expect(store.data.budget.amount, 250);
    });

    test('setConverterPair JAMÁS acepta divisas iguales (v19)', () {
      store.setConverterPair('USD', 'VES');
      expect(store.data.converter.from, 'USD');
      expect(store.data.converter.to, 'VES');
      // Par igual entrante → el otro lado se despeja (USD complemento).
      store.setConverterPair('VES', 'VES');
      expect(store.data.converter.from, 'VES');
      expect(store.data.converter.to, 'USD');
      expect(store.data.converter.from != store.data.converter.to, isTrue);
      // USD→USD → cae a VES.
      store.setConverterPair('USD', 'USD');
      expect(store.data.converter.to, 'VES');
      // Casos normales intactos.
      store.setConverterPair('EUR', 'COP');
      expect(store.data.converter.from, 'EUR');
      expect(store.data.converter.to, 'COP');
    });

    test('updateBasketItem <=0 elimina', () {
      final p = store.addProduct(
        Product(id: '', name: 'W', category: ProductCategory.otros,
            presentation: Presentation.unit, size: 1, createdAt: DateTime(2026), records: const []),
        null,
      );
      store.addToBasket(p.id, 1);
      store.updateBasketItem(p.id, 0);
      expect(store.basket, isEmpty);
    });
  });

  group('Persistencia y resetAll (§2.5)', () {
    test('round-trip Hive: los datos sobreviven una nueva hidratación', () async {
      store.addToCart(const CartItem(id: '', name: 'Persistente', quantity: 1, price: 1, currency: 'USD'));
      final store2 = AppStore();
      await store2.hydrate(testDir: tmp.path);
      expect(store2.cart.any((c) => c.name == 'Persistente'), isTrue);
    });

    test('resetAll conserva SOLO el tablero vivo (§2.5 v15)', () {
      store.setRateBoard(RateBoard(sources: {
        'ves-bcv': RateEntry(rate: 40, updatedAt: DateTime(2026)),
      }));
      store.addToCart(const CartItem(id: '', name: 'X', quantity: 1, price: 1, currency: 'USD'));
      store.setCountry(Country.CO); // muda settings + rateSource + converter
      store.resetAll();
      expect(store.cart, isEmpty);
      expect(store.board.sources['ves-bcv'], isNotNull);
      // Settings y rateSource vuelven a defaults de fábrica (país VE, EUR
      // oficial a Bs), el conversor al par canónico USD→VES.
      expect(store.settings.country, 'VE');
      expect(store.settings.onboarded, isFalse);
      expect(store.data.rateSource['EUR'], 'eur-ves-oficial');
      expect(store.data.converter.from, 'USD');
      expect(store.data.converter.to, 'VES');
      // El ring de notificaciones también se vacía.
      store.pushNotification(kind: NotifKind.info, title: 'T', body: 'b');
      store.resetAll();
      expect(store.notifs, isEmpty);
    });
  });

  group('Snapshots · snapshotSeries (§4)', () {
    test('recorta a los últimos [days] días', () {
      final now = DateTime.now();
      final store2 = <SnapshotPoint>[
        SnapshotPoint(sourceId: 'ves-bcv', day: SnapshotPoint.dayKey(now.subtract(const Duration(days: 200))), rate: 1),
        SnapshotPoint(sourceId: 'ves-bcv', day: SnapshotPoint.dayKey(now.subtract(const Duration(days: 40))), rate: 2),
        SnapshotPoint(sourceId: 'ves-bcv', day: SnapshotPoint.dayKey(now.subtract(const Duration(days: 5))), rate: 3),
        SnapshotPoint(sourceId: 'ves-bcv', day: SnapshotPoint.dayKey(now), rate: 4),
      ];
      final s30 = snapshotSeries(store2, 'ves-bcv', 30);
      expect(s30.length, 2); // 5 días y hoy; 40 y 200 fuera
      expect(s30.last.rate, 4);
      expect(snapshotSeries(store2, 'ves-bcv', 365).length, 4);
    });
  });

  group('Centro de notificaciones y quick-tools', () {
    test('pushNotification: dedupe título 10 min y ring 50', () {
      for (int i = 0; i < 60; i++) {
        store.pushNotification(kind: NotifKind.info, title: 'Aviso $i', body: 'b');
      }
      expect(store.notifs.length, 50);
      final before = store.notifs.length;
      store.pushNotification(kind: NotifKind.info, title: 'Aviso 59', body: 'dup');
      expect(store.notifs.length, before); // dedupe
    });

    test('pushRecentConversion: dedupe <60s y máx 10', () {
      for (int i = 0; i < 15; i++) {
        store.pushRecentConversion(i.toDouble(), Currency.usd, Currency.ves);
      }
      expect(store.readRecentConversions().length, 10);
      final before = store.readRecentConversions().length;
      store.pushRecentConversion(14, Currency.usd, Currency.ves); // dup inmediato
      expect(store.readRecentConversions().length, before);
    });
  });

  group('Sala · eventos remotos (guard de supresión)', () {
    test('applyRemoteRoomEvent aplica item_add/update/remove/clear/replace', () {
      store.applyRemoteRoomEvent('item_add', {
        'item': {'id': 'i1', 'name': 'Remoto', 'quantity': 2, 'price': 10, 'currency': 'VES'},
      });
      expect(store.cart.first.name, 'Remoto');
      store.applyRemoteRoomEvent('item_update', {
        'id': 'i1',
        'patch': {'quantity': 5, 'checked': true, 'checkedBy': 'Ana'},
      });
      expect(store.cart.first.quantity, 5);
      expect(store.cart.first.checkedBy, 'Ana');
      store.applyRemoteRoomEvent('item_remove', {'id': 'i1'});
      expect(store.cart, isEmpty);
      store.applyRemoteRoomEvent('list_replace', {
        'items': [
          {'id': 'i2', 'name': 'Nuevo', 'quantity': 1, 'price': 1, 'currency': 'USD'},
        ],
      });
      expect(store.cart.first.id, 'i2');
      store.applyRemoteRoomEvent('list_clear', {});
      expect(store.cart, isEmpty);
    });
  });

  group('Metas de precio · checkProductTargets (17.7 · price_targets)', () {
    test('anuncia el cruce fresco una vez, fija metSince y rearma al subir', () async {
      final prefs = await SharedPreferences.getInstance();
      final engine = AlertEngine(prefs);
      final notifs = NotificationsService();
      final anunciados = <String>[];

      void eval() => engine.checkProductTargets(
            store: store,
            notifs: notifs,
            persist: (kind, title, body) => anunciados.add(title),
          );

      // Producto SIN meta, precio alto.
      final p = store.addProduct(
        Product(id: '', name: 'Aceite', category: ProductCategory.alimentos,
            presentation: Presentation.unit, size: 1, createdAt: DateTime(2026), records: const []),
        null,
      );
      store.addRecord(p.id, PriceRecord(id: '', price: 5, originalPrice: 5,
          currency: 'USD', quantity: 1, rate: 1, sourceId: 'usd', date: DateTime(2026)));

      // Meta fijada SOBRE el precio ya existente (2º plano): anuncia + fija metSince.
      store.setTarget(p.id, 6);
      eval();
      expect(anunciados, hasLength(1));
      expect(anunciados.first, contains('Aceite'));
      expect(store.products.firstWhere((x) => x.id == p.id).metSince, isNotNull);

      // Segunda pasada el mismo día: claim por día → silencio.
      anunciados.clear();
      eval();
      expect(anunciados, isEmpty);

      // Precio sube sobre la meta → rearma (metSince a null).
      store.addRecord(p.id, PriceRecord(id: '', price: 6, originalPrice: 6,
          currency: 'USD', quantity: 1, rate: 1, sourceId: 'usd', date: DateTime.now()));
      eval();
      expect(store.products.firstWhere((x) => x.id == p.id).metSince, isNull);
      expect(anunciados, isEmpty);
    });

    test('sin meta o sin registros: silencio absoluto', () async {
      final prefs = await SharedPreferences.getInstance();
      final engine = AlertEngine(prefs);
      final p = store.addProduct(
        Product(id: '', name: 'Sal', category: ProductCategory.otros,
            presentation: Presentation.unit, size: 1, createdAt: DateTime(2026), records: const []),
        null,
      );
      var llamadas = 0;
      void contar(_, _, _) => llamadas++;
      engine.checkProductTargets(
          store: store, notifs: NotificationsService(), persist: contar);
      expect(llamadas, 0); // sin meta → nada
      store.setTarget(p.id, 1); // meta pero SIN registros
      engine.checkProductTargets(
          store: store, notifs: NotificationsService(), persist: contar);
      expect(llamadas, 0);
    });
  });
}
