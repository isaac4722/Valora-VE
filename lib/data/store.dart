/// ─── ValoraVE · Store central (§2 · todas las acciones) ────────────────────
/// Offline-first con Hive: 4 cajas de JSON (data · board · snapshots ·
/// notifs) + outbox de sala. Persistencia atómica por clave, migraciones por
/// DATA_VERSION y semilla offline con tasas públicas REALES (BCV 234,89 del
/// 12-sep-2025… tomadas del respaldo histórico del web v15 — prohibido
/// inventar cifras).
library;

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:hive_ce_flutter/hive_ce_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/analytics.dart' as an;
import '../core/currencies.dart';
import '../core/models.dart';

/// Nombre de cajas Hive.
const kBoxData = 'valorave.data';
const kBoxBoard = 'valorave.board';
const kBoxSnapshots = 'valorave.snapshots';
const kBoxNotifs = 'valorave.notifs';
const kBoxOutbox = 'valorave.outbox';

/// Clave del snapshot único de estado (spec web: preciove-store).
const _kDataKey = 'store';

/// PRODUCTO semilla para tests/primera carga (no cifras de mercado).
const kSeedBoardNote = 'Sin red: pega tu tasa manual en Ajustes.';

/// Store observable con todas las acciones del web §2.
class AppStore extends ChangeNotifier {
  AppData _data = const AppData();
  final List<NotificationItem> notifs = [];
  final List<SnapshotPoint> snapshots = [];
  final List<Map<String, dynamic>> outbox = [];

  bool _hydrated = false;
  bool get hydrated => _hydrated;

  /// Constructor por defecto: estado vacío hasta hydrate().
  AppStore() : this.withData(const AppData());

  /// Constructor ligero para WIDGET TESTS: estado inyectado, sin Hive ni
  /// plugins (los unit tests de Hive usan hydrate(testDir:) con test() plano).
  AppStore.withData(this._data) {
    _hydrated = true;
  }

  AppData get data => _data;
  RateBoard get board => _data.board;
  Settings get settings => _data.settings;
  List<Product> get products => _data.products;
  List<Transaction> get transactions => _data.transactions;
  List<CartItem> get cart => _data.cart;
  List<Purchase> get purchases => _data.purchases;
  List<String> get stores => _data.stores;
  List<ShoppingTemplate> get templates => _data.templates;
  List<BasketItem> get basket => _data.basket;

  int _id = 0;
  String newId() {
    _id++;
    final ms = DateTime.now().microsecondsSinceEpoch;
    return 'v$ms${_id.toString().padLeft(4, '0')}';
  }

  // ─── Motor activo ───────────────────────────────────────────────────────

  /// Contexto de tasas del módulo [module]: global + override por módulo.
  RateContext contextOf({RateModule? module}) {
    final selected = <Currency, String>{
      for (final e in _data.rateSource.entries)
        CurrencyX.from(e.key): RateSource.validSourceId(
          CurrencyX.from(e.key),
          e.value,
        ),
    };
    if (module != null) {
      // Overrides 'modulo:DIVISA' (validados contra sourcesFor).
      _data.settings.rateSourcesByModule.forEach((key, sourceId) {
        final parts = key.split(':');
        if (parts.length != 2) return;
        if (RateModuleX.from(parts[0]) == module) {
          final c = CurrencyX.from(parts[1]);
          final valid = RateSource.validSourceId(c, sourceId);
          if (RateSource.of(valid)?.category != SourceCategory.manual ||
              RateSource.validSourceId(c, sourceId) == sourceId) {
            selected[c] = valid;
          }
        }
      });
    }
    // Tasas vivas + derivadas + manuales.
    final rates = <String, double>{
      for (final e in _data.board.sources.entries) e.key: e.value.rate,
      ..._data.manualRates,
    };
    // ves-avg SIEMPRE derivado local (§3.1 kind derived).
    final avg = (rates['ves-bcv'] ?? 0) > 0 && (rates['ves-parallel'] ?? 0) > 0
        ? ((rates['ves-bcv']! + rates['ves-parallel']!) / 2)
        : 0.0;
    if (avg > 0) rates['ves-avg'] = avg;
    return RateContext(rates: rates, selected: selected);
  }

  /// Fuente seleccionada de una divisa (validada con fallback default).
  String sourceFor(Currency c, {RateModule? module}) =>
      contextOf(module: module).sel(c);

  // ─── 2.1 Tasas / país / conversor ───────────────────────────────────────

  /// setRateBoard: purga sources a ids conocidos; fetchedAt = ahora SIEMPRE.
  void setRateBoard(RateBoard b) {
    final clean = RateBoard(
      sources: {
        for (final e in b.sources.entries)
          if (RateSource.of(e.key) != null) e.key: e.value,
      },
      providers: b.providers,
      degraded: b.degraded,
      lastUpdate: b.lastUpdate ?? DateTime.now(),
      fetchedAt: DateTime.now(),
    );
    _data = AppData.fromJson(_data.toJson()..['board'] = clean.toJson());
    _persist();
  }

  /// setRateSource: fuente global por moneda (validada).
  void setRateSource(Currency currency, String sourceId) {
    final valid = RateSource.validSourceId(currency, sourceId);
    final rs = {..._data.rateSource, currency.code: valid};
    _data = AppData.fromJson(_data.toJson()..['rateSource'] = rs);
    _persist();
  }

  /// setModuleRateSource: valida vs sourcesFor; null/inválido borra → global.
  void setModuleRateSource(
    RateModule module,
    Currency currency,
    String? sourceId,
  ) {
    final map = {..._data.settings.rateSourcesByModule};
    final key = moduleRateKey(module.code, currency.code);
    if (sourceId == null) {
      map.remove(key);
    } else {
      final valid = RateSource.validSourceId(currency, sourceId);
      if (valid != sourceId) {
        map.remove(key); // inválido → global
      } else {
        map[key] = sourceId;
      }
    }
    _patchSettings(rateSourcesByModule: map);
  }

  /// setManualRate: >0 guarda, <=0 borra.
  void setManualRate(String sourceId, double value) {
    final map = {..._data.manualRates};
    if (value > 0) {
      map[sourceId] = value;
    } else {
      map.remove(sourceId);
    }
    _data = AppData.fromJson(_data.toJson()..['manualRates'] = map);
    _persist();
  }

  /// setConverterPair: par directo del conversor. v19 (orden del dueño): el
  /// par SIEMPRE tiene divisas distintas — nunca «VES → VES». Si llega un
  /// par igual (respaldo viejo o caller descuidado), el otro lado cae al
  /// complemento canónico (USD, o VES si la divisa ES USD).
  void setConverterPair(String from, String to) {
    var f = from.toUpperCase();
    var t = to.toUpperCase();
    if (f == t) {
      t = f == Currency.usd.code ? Currency.ves.code : Currency.usd.code;
    }
    _data = AppData.fromJson(
      _data.toJson()..['converter'] = ConverterState(from: f, to: t).toJson(),
    );
    _persist();
  }

  /// setCountry: no-op si inválido; set país + fuente EUR del país +
  /// converter USD→moneda del país (§2.1). Si la moneda del país ES USD
  /// (Global/US), el par cae a USD→VES para que el conversor siga útil.
  void setCountry(Country code) {
    _patchSettings(country: code.code);
    final String to = code.currency == Currency.usd
        ? Currency.ves.code
        : code.currency.code;
    _data = AppData.fromJson(
      _data.toJson()
        ..['rateSource'] = {..._data.rateSource, 'EUR': code.eurSource}
        ..['converter'] = ConverterState(
          from: Currency.usd.code,
          to: to,
        ).toJson(),
    );
    _persist();
  }

  void reopenTutorial() => _patchSettings(onboarded: false);
  void finishOnboarding() => _patchSettings(onboarded: true);

  void _patchSettings({
    String? country,
    bool? onboarded,
    Map<String, String>? rateSourcesByModule,
    bool? offlineMode,
    int? pollMinutes,
    bool? biometricLock,
    String? sseUrl,
  }) {
    final s = _data.settings;
    final patched = s.copyWith(
      country: country != null ? CountryX.from(country).code : null,
      onboarded: onboarded,
      rateSourcesByModule: rateSourcesByModule,
      offlineMode: offlineMode,
      pollMinutes: pollMinutes,
      biometricLock: biometricLock,
      sseUrl: sseUrl,
    );
    _data = AppData.fromJson(_data.toJson()..['settings'] = patched.toJson());
    _persist();
  }

  /// Modo offline total (v17.2): la app NO consulta ninguna API; todo lo que
  /// se ve sale del libro local (board/snapshots) + tasas manuales.
  void setOfflineMode(bool v) => _patchSettings(offlineMode: v);

  /// Cada cuánto consulta la app las APIs de tasas, en minutos (1..60).
  void setPollMinutes(int m) => _patchSettings(pollMinutes: m.clamp(1, 60));

  /// Bloqueo biométrico al abrir la app (17.7 — local_auth ya estaba).
  void setBiometricLock(bool v) => _patchSettings(biometricLock: v);

  /// URL del despliegue web con SSE en vivo (17.7): '' apaga el stream.
  void setSseUrl(String v) => _patchSettings(sseUrl: v.trim());

  /// setSetting genérico (§2.5) — camelCase de los campos v12/v13.
  void setSetting(String key, Object? value) {
    final s = _data.settings;
    Settings patched;
    switch (key) {
      case 'country':
        patched = s.copyWith(country: CountryX.from('$value').code);
      case 'autoRefresh':
        patched = s.copyWith(autoRefresh: value == true);
      case 'offlineMode':
        patched = s.copyWith(offlineMode: value == true);
      case 'pollMinutes':
        patched = s.copyWith(
          pollMinutes:
              (value is num ? value.toInt() : int.tryParse('$value') ?? 1)
                  .clamp(1, 60),
        );
      case 'biometricLock':
        patched = s.copyWith(biometricLock: value == true);
      case 'sseUrl':
        patched = s.copyWith(sseUrl: '$value'.trim());
      case 'tickerMode':
        patched = s.copyWith(tickerMode: '$value');
      case 'onboarded':
        patched = s.copyWith(onboarded: value == true);
      case 'calcCurrency':
        patched = s.copyWith(calcCurrency: '$value');
      case 'spikeAlerts':
        patched = s.copyWith(spikeAlerts: value == true);
      case 'spikeThreshold':
        patched = s.copyWith(spikeThreshold: (value as num).toDouble());
      case 'spikeWatch':
        patched = s.copyWith(spikeWatch: (value as List).cast<String>());
      case 'rateTargetAlerts.bcv':
        patched = s.copyWith(
          targetBcv: (value as num?)?.toDouble(),
          clearTargetBcv: value == null,
        );
      case 'rateTargetAlerts.parallel':
        patched = s.copyWith(
          targetParallel: (value as num?)?.toDouble(),
          clearTargetParallel: value == null,
        );
      case 'salary':
        final m = value as Map?;
        if (m == null) {
          patched = s.copyWith(
            clearSalary: true,
            clearSalaryBase: true,
            clearSalaryVariable: true,
            clearSalaryMin: true,
            clearSalaryMax: true,
          );
        } else if (m['mode'] is String &&
            (m['amount'] ?? m['base'] ?? m['min']) == null) {
          // Solo cambia de modo (chips Fijo/Base/Rango del Home).
          patched = s.copyWith(salaryMode: m['mode'] as String);
        } else {
          patched = s.copyWith(
            salaryAmount: (m['amount'] as num?)?.toDouble(),
            clearSalary: m['amount'] == null && s.salaryMode == 'fijo',
            salaryCurrency: m['currency'] != null ? '${m['currency']}' : null,
            salaryMode: m['mode'] is String ? m['mode'] as String : null,
            salaryBase: (m['base'] as num?)?.toDouble(),
            clearSalaryBase: m['base'] == null,
            salaryVariable: (m['variable'] as num?)?.toDouble(),
            clearSalaryVariable: m['variable'] == null,
            salaryMin: (m['min'] as num?)?.toDouble(),
            clearSalaryMin: m['min'] == null,
            salaryMax: (m['max'] as num?)?.toDouble(),
            clearSalaryMax: m['max'] == null,
          );
        }
      case 'tickerSize':
        patched = s.copyWith(tickerSize: '$value');
      case 'tickerSpeed':
        patched = s.copyWith(tickerSpeed: (value as num).toInt());
      case 'currencyOrder':
        patched = s.copyWith(currencyOrder: (value as List).cast<String>());
      default:
        return;
    }
    _data = AppData.fromJson(_data.toJson()..['settings'] = patched.toJson());
    _persist();
  }

  // ─── 2.2 Productos ──────────────────────────────────────────────────────

  Product addProduct(Product p, PriceRecord? firstRecord) {
    final product = Product(
      id: p.id.isEmpty ? newId() : p.id,
      name: p.name,
      barcode: p.barcode,
      category: p.category,
      presentation: p.presentation,
      size: p.size,
      sizeUnit: p.sizeUnit,
      createdAt: DateTime.now(),
      records: firstRecord != null
          ? [
              PriceRecord(
                id: firstRecord.id.isEmpty ? newId() : firstRecord.id,
                price: firstRecord.price,
                originalPrice: firstRecord.originalPrice,
                currency: firstRecord.currency,
                quantity: firstRecord.quantity,
                store: firstRecord.store,
                notes: firstRecord.notes,
                rate: firstRecord.rate,
                sourceId: firstRecord.sourceId,
                date: firstRecord.date,
              ),
            ]
          : [],
    );
    final list = [product, ..._data.products];
    _data = AppData.fromJson(
      _data.toJson()..['products'] = list.map((e) => e.toJson()).toList(),
    );
    final storeName = firstRecord?.store;
    if (storeName != null && storeName.trim().isNotEmpty) addStore(storeName);
    _persist();
    return product;
  }

  void updateProduct(String id, Product patch) {
    final list = _data.products
        .map(
          (p) => p.id == id
              ? p.copyWith(
                  name: patch.name,
                  barcode: patch.barcode,
                  category: patch.category,
                  presentation: patch.presentation,
                  size: patch.size,
                  sizeUnit: patch.sizeUnit,
                  targetPrice: patch.targetPrice,
                  clearTarget: patch.targetPrice == null,
                  targetCurrency: patch.targetCurrency,
                  metSince: patch.metSince,
                  clearMetSince: patch.metSince == null,
                  unavailableSince: patch.unavailableSince,
                  clearUnavailable: patch.unavailableSince == null,
                )
              : p,
        )
        .toList();
    _data = AppData.fromJson(
      _data.toJson()..['products'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  /// deleteProduct con cascada de canasta (§2.2).
  void deleteProduct(String id) {
    final list = _data.products.where((p) => p.id != id).toList();
    final basket = _data.basket.where((b) => b.productId != id).toList();
    _data = AppData.fromJson(
      _data.toJson()
        ..['products'] = list.map((e) => e.toJson()).toList()
        ..['basket'] = basket.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  /// addRecord con la tasa activa del módulo.
  void addRecord(String productId, PriceRecord record) {
    final list = _data.products.map((p) {
      if (p.id != productId) return p;
      final r = PriceRecord(
        id: record.id.isEmpty ? newId() : record.id,
        price: record.price,
        originalPrice: record.originalPrice,
        currency: record.currency,
        quantity: record.quantity,
        store: record.store,
        notes: record.notes,
        rate: record.rate,
        sourceId: record.sourceId,
        date: record.date,
      );
      if ((r.store ?? '').trim().isNotEmpty) addStore(r.store!);
      // Meta alcanzada: estampa metSince (v13.2) si quedó BAJO meta.
      var metSince = p.metSince;
      final target = p.targetPrice;
      if (target != null &&
          target > 0 &&
          r.price < target * (1 - an.kTargetEps)) {
        metSince ??= r.date;
      } else {
        metSince = null; // vuelve sobre ella → limpia
      }
      return p.copyWith(
        records: [...p.records, r],
        metSince: metSince,
        clearMetSince: metSince == null,
      );
    }).toList();
    _data = AppData.fromJson(
      _data.toJson()..['products'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  void updateRecord(
    String productId,
    String recordId, {
    double? newUSD,
    double? newOriginal,
    String? store,
    String? notes,
  }) {
    final list = _data.products.map((p) {
      if (p.id != productId) return p;
      final records = p.records.map((r) {
        if (r.id != recordId) return r;
        final newPrice = newUSD ?? r.price;
        return r.copyWith(
          price: newPrice,
          originalPrice: newOriginal ?? r.originalPrice,
          store: store,
          notes: notes,
        );
      }).toList()..sort((a, b) => a.date.compareTo(b.date));
      return p.copyWith(records: records);
    }).toList();
    _data = AppData.fromJson(
      _data.toJson()..['products'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  void deleteRecord(String productId, String recordId) {
    final list = _data.products.map((p) {
      if (p.id != productId) return p;
      return p.copyWith(
        records: p.records.where((r) => r.id != recordId).toList(),
      );
    }).toList();
    _data = AppData.fromJson(
      _data.toJson()..['products'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  /// setUnavailable: true estampa ahora, false limpia (§2.2).
  void setUnavailable(String productId, bool unavailable) {
    final list = _data.products.map((p) {
      if (p.id != productId) return p;
      return p.copyWith(
        unavailableSince: unavailable ? DateTime.now() : null,
        clearUnavailable: !unavailable,
      );
    }).toList();
    _data = AppData.fromJson(
      _data.toJson()..['products'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  /// setTarget: >0 guarda, <=0 quita; al fijar se limpia metSince.
  void setTarget(
    String productId,
    double? target, {
    String targetCurrency = 'USD',
  }) {
    final list = _data.products.map((p) {
      if (p.id != productId) return p;
      final valid = target != null && target > 0;
      return p.copyWith(
        targetPrice: valid ? target : null,
        clearTarget: !valid,
        targetCurrency: targetCurrency,
        metSince: null,
        clearMetSince: true,
      );
    }).toList();
    _data = AppData.fromJson(
      _data.toJson()..['products'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  /// Marca que el producto quedó bajo su meta en [at] (§9.4 metSince auto —
  /// lo fija AlertEngine.checkProductTargets al anunciar).
  void setMetSince(String productId, DateTime at) {
    final list = _data.products.map((p) {
      if (p.id != productId) return p;
      return p.copyWith(metSince: at);
    }).toList();
    _data = AppData.fromJson(
      _data.toJson()..['products'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  /// Rearma el aviso de meta (el precio volvió a subir por encima).
  void clearMetSince(String productId) {
    final list = _data.products.map((p) {
      if (p.id != productId) return p;
      return p.copyWith(clearMetSince: true);
    }).toList();
    _data = AppData.fromJson(
      _data.toJson()..['products'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  /// importProducts CSV: dedupe por barcode PRIMERO (si la fila lo trae);
  /// solo filas SIN barcode dedupean por nombre case-insensitive (§2.2).
  /// Crea {category:'otros', presentation:'unit', size:1, records:[]}.
  int importProducts(
    List<({String name, String? barcode, DateTime? date})> rows,
  ) {
    var added = 0;
    final list = [..._data.products];
    for (final row in rows) {
      final name = row.name.trim();
      if (name.isEmpty) continue;
      final bar = row.barcode?.trim() ?? '';
      // Barcode manda: con barcode la comparación es EXCLUSIVAMENTE por
      // barcode (dos productos distintos pueden compartir nombre); sin
      // barcode, nombre lower como única señal de duplicado.
      final dup = bar.isNotEmpty
          ? list.any((p) => (p.barcode ?? '') == bar)
          : list.any((p) => p.name.toLowerCase() == name.toLowerCase());
      if (dup) continue;
      list.insert(
        0,
        Product(
          id: newId(),
          name: name,
          barcode: bar.isEmpty ? null : bar,
          category: ProductCategory.otros,
          presentation: Presentation.unit,
          size: 1,
          createdAt: row.date ?? DateTime.now(),
          records: const [],
        ),
      );
      added++;
    }
    _data = AppData.fromJson(
      _data.toJson()..['products'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
    return added;
  }

  // ─── 2.3 Carrito / presupuesto / compras / finanzas / canasta ───────────

  /// addToCart: mismo name.lower+price+currency suma quantity, sino push.
  void addToCart(CartItem item) {
    final list = [..._data.cart];
    final idx = list.indexWhere(
      (c) =>
          c.name.toLowerCase() == item.name.toLowerCase() &&
          c.price == item.price &&
          c.currency == item.currency,
    );
    if (idx >= 0) {
      list[idx] = list[idx].copyWith(
        quantity: list[idx].quantity + item.quantity,
      );
    } else {
      list.add(item.id.isEmpty ? item.copyWith(id: newId()) : item);
    }
    _data = AppData.fromJson(
      _data.toJson()..['cart'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  void updateCartItem(
    String id,
    CartItem patch, {
    bool clearCheckedBy = false,
  }) {
    final list = _data.cart.map((c) {
      if (c.id != id) return c;
      return c.copyWith(
        productId: patch.productId,
        name: patch.name,
        quantity: patch.quantity,
        price: patch.price,
        currency: patch.currency,
        barcode: patch.barcode,
        checked: patch.checked,
        checkedBy: patch.checkedBy,
        clearProduct: patch.productId == null,
        clearCheckedBy: clearCheckedBy || patch.checkedBy == null,
        store: patch.store,
        clearStore: patch.store == null,
        size: patch.size,
        clearSize: patch.size == null,
        sizeUnit: patch.sizeUnit,
        clearSizeUnit: patch.sizeUnit == null,
      );
    }).toList();
    _data = AppData.fromJson(
      _data.toJson()..['cart'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  void removeFromCart(String id) {
    final list = _data.cart.where((c) => c.id != id).toList();
    _data = AppData.fromJson(
      _data.toJson()..['cart'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  void clearCart() {
    _data = AppData.fromJson(_data.toJson()..['cart'] = <dynamic>[]);
    _persist();
  }

  /// setBudget (v19): 0 limpia el MONTO pero conserva la MONEDA elegida —
  /// el bug del dueño («no deja seleccionar la moneda») nacía de que al no
  /// haber monto la divisa se reseteaba a VES y el selector parecía no
  /// responder. La moneda del presupuesto vive siempre en el modelo.
  void setBudget(double amount, String currency) {
    final b = Budget(
      amount: amount > 0 ? amount : 0,
      currency: CurrencyX.from(currency).code,
    );
    _data = AppData.fromJson(_data.toJson()..['budget'] = b.toJson());
    _persist();
  }

  void addPurchase(Purchase p) {
    // Toda compra nueva DEBE tener id único: sin él, deletePurchase y los
    // backups merge (dedupe por id) corrompían el historial. Si el caller
    // no lo trae, se genera aquí (newId) vía copyWith(id: …).
    final purchase = p.id.isEmpty ? p.copyWith(id: newId()) : p;
    final list = [purchase, ..._data.purchases]; // unshift
    _data = AppData.fromJson(
      _data.toJson()..['purchases'] = list.map((e) => e.toJson()).toList(),
    );
    if ((p.store ?? '').trim().isNotEmpty) addStore(p.store!);
    _persist();
  }

  void updatePurchase(String id, Purchase patch) {
    final list = _data.purchases.map((p) {
      if (p.id != id) return p;
      return p.copyWith(
        date: patch.date,
        store: patch.store,
        items: patch.items,
        totalUSD: patch.totalUSD,
        totalBS: patch.totalBS,
        rate: patch.rate,
        rateSourceId: patch.rateSourceId,
        paidTotal: patch.paidTotal,
        paidCurrency: patch.paidCurrency,
        ticketPhoto: patch.ticketPhoto,
        clearTicket: patch.ticketPhoto == null,
        notes: patch.notes,
      );
    }).toList();
    _data = AppData.fromJson(
      _data.toJson()..['purchases'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  void deletePurchase(String id) {
    final list = _data.purchases.where((p) => p.id != id).toList();
    _data = AppData.fromJson(
      _data.toJson()..['purchases'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  /// findSimilarProduct (v17.2): detecta un producto YA registrado que
  /// coincida por (a) mismo código de barras, o (b) mismo nombre en la
  /// MISMA tienda. Criterios de identidad SOLO nombre/código/tienda —
  /// nunca peso ni precio. Null = sin parecido razonable.
  Product? findSimilarProduct({
    required String name,
    String? barcode,
    String? store,
  }) {
    final b = (barcode ?? '').trim();
    final n = name.trim().toLowerCase();
    final s = (store ?? '').trim().toLowerCase();
    for (final p in _data.products) {
      final sameBarcode = b.isNotEmpty && (p.barcode ?? '').trim() == b;
      final sameStoreName =
          n.isNotEmpty &&
          p.name.trim().toLowerCase() == n &&
          s.isNotEmpty &&
          p.records.any((r) => (r.store ?? '').trim().toLowerCase() == s);
      if (sameBarcode || sameStoreName) return p;
    }
    return null;
  }

  /// recordPurchaseItemOnProduct (v17.2): añade el precio del ítem comprado
  /// como nuevo PriceRecord del producto (USD normalizado, patrón del
  /// editor de Productos) y devuelve el producto actualizado. La UI llama
  /// esto tras el «ya existe → vincular» o tras crear el producto nuevo.
  void recordPurchaseItemOnProduct(
    String productId,
    PurchaseItem item, {
    String? store,
  }) {
    final p = _data.products.where((e) => e.id == productId).firstOrNull;
    if (p == null) return;
    final sCtx = contextOf(module: RateModule.finance);
    final usdRate = sCtx.unitsPerUSD(Currency.usd) ?? 1;
    addRecord(
      productId,
      PriceRecord(
        id: '',
        price: item.priceUSD,
        originalPrice: item.originalPrice,
        currency: 'USD',
        quantity: item.quantity,
        store: (store ?? item.store)?.trim().isEmpty == false
            ? (store ?? item.store)!.trim()
            : null,
        rate: usdRate,
        sourceId: sCtx.sel(Currency.ves),
        date: DateTime.now(),
      ),
    );
  }

  // v17.8: addTransaction/updateTransaction/deleteTransaction se retiraron
  // con el módulo Finanzas (ya no hay UI que registre movimientos manuales).
  // El getter [transactions] y el modelo Transaction SE CONSERVAN: los
  // respaldos viejos siguen restaurando/round-trip sin perder datos.

  /// addToBasket: suma cantidad si ya está.
  void addToBasket(String productId, int qty) {
    final list = [..._data.basket];
    final idx = list.indexWhere((b) => b.productId == productId);
    if (idx >= 0) {
      list[idx] = BasketItem(
        productId: productId,
        quantity: list[idx].quantity + qty,
      );
    } else {
      list.add(BasketItem(productId: productId, quantity: qty));
    }
    _data = AppData.fromJson(
      _data.toJson()..['basket'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  /// updateBasketItem: <=0 elimina.
  void updateBasketItem(String productId, int qty) {
    var list = [..._data.basket];
    if (qty <= 0) {
      list = list.where((b) => b.productId != productId).toList();
    } else {
      final idx = list.indexWhere((b) => b.productId == productId);
      if (idx >= 0) {
        list[idx] = BasketItem(productId: productId, quantity: qty);
      } else {
        list.add(BasketItem(productId: productId, quantity: qty));
      }
    }
    _data = AppData.fromJson(
      _data.toJson()..['basket'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  void removeFromBasket(String productId) {
    final list = _data.basket.where((b) => b.productId != productId).toList();
    _data = AppData.fromJson(
      _data.toJson()..['basket'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  // ─── 2.4 Plantillas (máx 20) ────────────────────────────────────────────

  /// saveTemplate: null si carrito vacío; congela carrito; unshift + slice(0,20).
  String? saveTemplate(String name) {
    final cleanName = name.trim();
    if (cleanName.isEmpty || _data.cart.isEmpty) return null;
    final t = ShoppingTemplate(
      id: newId(),
      name: cleanName,
      createdAt: DateTime.now(),
      items: _data.cart
          .map(
            (c) => ShoppingTemplateItem(
              name: c.name,
              quantity: c.quantity,
              price: c.price,
              currency: c.currency,
              productId: c.productId,
              barcode: c.barcode,
            ),
          )
          .toList(),
    );
    final list = [t, ..._data.templates].take(kMaxTemplates).toList();
    _data = AppData.fromJson(
      _data.toJson()..['templates'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
    return t.id;
  }

  void deleteTemplate(String id) {
    final list = _data.templates.where((t) => t.id != id).toList();
    _data = AppData.fromJson(
      _data.toJson()..['templates'] = list.map((e) => e.toJson()).toList(),
    );
    _persist();
  }

  /// applyTemplate → totalQty (0 si no existe/vacía; merge con regla addToCart).
  int applyTemplate(String id) {
    final t = _data.templates.where((t) => t.id == id).firstOrNull;
    if (t == null || t.items.isEmpty) return 0;
    var total = 0;
    for (final item in t.items) {
      addToCart(
        CartItem(
          id: newId(),
          productId: item.productId,
          name: item.name,
          quantity: item.quantity,
          price: item.price,
          currency: item.currency,
          barcode: item.barcode,
        ),
      );
      total += item.quantity;
    }
    return total;
  }

  // ─── 2.5 Tiendas / backup / reset ───────────────────────────────────────

  /// addStore: trim, no duplicados case-insensitive.
  void addStore(String name) {
    final clean = name.trim();
    if (clean.isEmpty) return;
    if (_data.stores.any((s) => s.toLowerCase() == clean.toLowerCase())) return;
    final list = [clean, ..._data.stores];
    _data = AppData.fromJson(_data.toJson()..['stores'] = list);
    _persist();
  }

  // ─── Centro de notificaciones (ring 50, 9 kinds) ─────────────────────────

  void pushNotification({
    required NotifKind kind,
    required String title,
    required String body,
  }) {
    // dedupe título 10 min (web §7).
    final now = DateTime.now();
    final dup = notifs.any(
      (n) => n.title == title && now.difference(n.at).inMinutes < 10,
    );
    if (dup) return;
    notifs.insert(
      0,
      NotificationItem(
        id: newId(),
        kind: kind,
        title: title,
        body: body,
        at: now,
      ),
    );
    if (notifs.length > 50) notifs.removeRange(50, notifs.length);
    _persistNotifs();
    notifyListeners();
  }

  void markRead(String id) {
    for (var i = 0; i < notifs.length; i++) {
      if (notifs[i].id == id) notifs[i] = notifs[i].copyWith(read: true);
    }
    _persistNotifs();
    notifyListeners();
  }

  void markAllRead() {
    for (var i = 0; i < notifs.length; i++) {
      if (!notifs[i].read) notifs[i] = notifs[i].copyWith(read: true);
    }
    _persistNotifs();
    notifyListeners();
  }

  void clearNotifications() {
    notifs.clear();
    _persistNotifs();
    notifyListeners();
  }

  // ─── quick-tools: recientes y notas del conversor ────────────────────────

  /// pushRecentConversion (10, dedupe misma from/to/amount <60s).
  void pushRecentConversion(double amount, Currency from, Currency to) {
    final sp = prefs;
    if (sp == null) return;
    final now = DateTime.now();
    final list = (sp.getStringList('valorave.recents') ?? [])
        .map(
          (e) => RecentConversion.fromJson(
            Map<String, dynamic>.from(jsonDecode(e)),
          ),
        )
        .toList();
    final dup = list.any(
      (r) =>
          r.from == from.code &&
          r.to == to.code &&
          r.amount == amount &&
          now.difference(r.at).inSeconds < 60,
    );
    if (dup) return;
    list.insert(
      0,
      RecentConversion(amount: amount, from: from.code, to: to.code, at: now),
    );
    sp.setStringList(
      'valorave.recents',
      list.take(10).map((e) => jsonEncode(e.toJson())).toList(),
    );
    notifyListeners();
  }

  List<RecentConversion> readRecentConversions() {
    final sp = prefs;
    if (sp == null) return const [];
    return (sp.getStringList('valorave.recents') ?? const [])
        .map(
          (e) => RecentConversion.fromJson(
            Map<String, dynamic>.from(jsonDecode(e)),
          ),
        )
        .toList();
  }

  void clearRecentConversions() {
    prefs?.remove('valorave.recents');
    notifyListeners();
  }

  String readConversionNotes() => prefs?.getString('valorave.conv-notes') ?? '';
  void writeConversionNotes(String text) {
    prefs?.setString(
      'valorave.conv-notes',
      text.length > 5000 ? text.substring(0, 5000) : text,
    );
  }

  /// replaceAll: sustituye el estado completo (import replace/merge de
  /// respaldos) — usado por settings tras importBackup.
  void replaceAll(AppData next) {
    _data = next;
    _persist();
  }

  // ─── resetAll (§2.5): limpia TODO salvo el tablero vivo ──────────────────

  /// Comportamiento documentado: se conserva ÚNICAMENTE el tablero vivo
  /// (board). Todo lo demás vuelve a defaults de fábrica:
  /// · settings → Settings por defecto (país VE, onboarding de nuevo).
  /// · rateSource → defaults oficiales del modelo (AppData.rateSource).
  /// · rateHistory (snapshots) → BORRADA (no se conserva).
  /// · centro de notificaciones → vaciado.
  /// El outbox de sala y las quick-tools de prefs NO se tocan (colas de
  /// sincronización/operación, no datos del usuario).
  void resetAll() {
    final liveBoard = _data.board;
    _data = AppData(board: liveBoard);
    snapshots.clear();
    persistSnapshots();
    notifs.clear();
    _persist();
    _persistNotifs();
  }

  // ─── Hidratación / persistencia ─────────────────────────────────────────

  SharedPreferences? prefs;
  Box<String>? _boxData;
  Box<String>? _boxSnapshots;
  Box<String>? _boxNotifs;
  Box<String>? _boxOutbox;

  /// [testDir] habilita hidratación en tests (Hive.init plano, sin plugins).
  Future<void> hydrate({String? testDir}) async {
    if (testDir != null) {
      Hive.init(testDir);
    } else {
      await Hive.initFlutter();
    }
    _boxData = await Hive.openBox<String>(kBoxData);
    _boxSnapshots = await Hive.openBox<String>(kBoxSnapshots);
    _boxNotifs = await Hive.openBox<String>(kBoxNotifs);
    _boxOutbox = await Hive.openBox<String>(kBoxOutbox);
    prefs = await SharedPreferences.getInstance();

    final raw = _boxData!.get(_kDataKey);
    if (raw != null && raw.isNotEmpty) {
      try {
        _data = migrate(
          AppData.fromJson(Map<String, dynamic>.from(jsonDecode(raw))),
        );
      } catch (_) {
        _data = const AppData(); // nunca lanza: datos corruptos → fresh
      }
    } else {
      _data = const AppData();
    }
    // Notificaciones.
    notifs
      ..clear()
      ..addAll(
        (_boxNotifs!.get('ring') ?? '[]').toString().isNotEmpty
            ? ((jsonDecode(_boxNotifs!.get('ring') ?? '[]') as List?) ??
                      const [])
                  .whereType<Map>()
                  .map(
                    (e) =>
                        NotificationItem.fromJson(Map<String, dynamic>.from(e)),
                  )
                  .toList()
            : <NotificationItem>[],
      );
    // Snapshots.
    final snapRaw = _boxSnapshots!.get('points');
    if (snapRaw != null) {
      try {
        snapshots
          ..clear()
          ..addAll(
            ((jsonDecode(snapRaw) as List?) ?? const []).whereType<Map>().map(
              (e) => SnapshotPoint.fromJson(Map<String, dynamic>.from(e)),
            ),
          );
      } catch (_) {}
    }
    // Outbox.
    final outRaw = _boxOutbox!.get('queue');
    if (outRaw != null) {
      try {
        outbox
          ..clear()
          ..addAll(
            ((jsonDecode(outRaw) as List?) ?? const []).whereType<Map>().map(
              (e) => Map<String, dynamic>.from(e),
            ),
          );
      } catch (_) {}
    }
    _hydrated = true;
    notifyListeners();
  }

  /// Cadena de migraciones DATA_VERSION (v12 vigente; el web migró v1→v12 —
  /// el store nativo nace en v12 pero repara settings incompletos).
  AppData migrate(AppData d) => d;

  void _persist() {
    final raw = jsonEncode(_data.toJson());
    _boxData?.put(_kDataKey, raw);
    // Durabilidad (v19.5): put() queda en el búfer de Hive; el flush fuerza
    // la escritura a disco antes del próximo ciclo de eventos. Fire-and-forget
    // con captura: si el disco falla, el dato sigue en memoria y el próximo
    // _persist reintenta — un corte de luz ya no borra la última compra.
    final box = _boxData;
    if (box != null) unawaited(box.flush().catchError((_) {}));
    notifyListeners();
  }

  void _persistNotifs() {
    _boxNotifs?.put('ring', jsonEncode(notifs.map((e) => e.toJson()).toList()));
  }

  /// Fuerza la escritura en disco del anillo de notificaciones. En 2º plano
  /// (workmanager) el Hive.put queda en cola: si el worker termina sin
  /// esperar, el aviso se pierde del centro aunque la notificación del
  /// sistema sí saliera (fix TASK-32). Idempotente y sin efecto en app viva.
  Future<void> flushNotifications() async {
    try {
      await _boxNotifs?.flush();
    } catch (_) {
      // Sin caja abierta (host de pruebas, isolate en cierre): no bloquea.
    }
  }

  void persistSnapshots() {
    _boxSnapshots?.put(
      'points',
      jsonEncode(snapshots.map((e) => e.toJson()).toList()),
    );
  }

  void persistOutbox() {
    _boxOutbox?.put('queue', jsonEncode(outbox));
  }

  // ─── Aplicación de eventos remotos de sala (guard baseline+suppress) ────

  /// Aplica item_add/item_update/item_remove/list_clear/list_replace remotos
  /// SIN re-emitirlos (el transporte llama esto tras el guard).
  void applyRemoteRoomEvent(String type, Map<String, dynamic> payload) {
    switch (type) {
      case 'item_add':
        final item = payload['item'];
        if (item is Map) {
          final m = Map<String, dynamic>.from(item);
          final existing = _data.cart.indexWhere((c) => c.id == m['id']);
          final parsed = CartItem.fromJson(m);
          if (existing >= 0) {
            final list = [..._data.cart]..[existing] = parsed;
            _data = AppData.fromJson(
              _data.toJson()..['cart'] = list.map((e) => e.toJson()).toList(),
            );
          } else {
            addToCart(parsed);
            return; // addToCart ya notifica
          }
        }
      case 'item_update':
        final id = payload['id'];
        final patch = payload['patch'];
        if (id is String && patch is Map) {
          final list = _data.cart.map((c) {
            if (c.id != id) return c;
            var next = c;
            final p = Map<String, dynamic>.from(patch);
            if (p['name'] is String) next = next.copyWith(name: p['name']);
            if (p['quantity'] is num) {
              next = next.copyWith(
                quantity: (p['quantity'] as num).toInt().clamp(1, 999),
              );
            }
            if (p['price'] is num) {
              next = next.copyWith(price: (p['price'] as num).toDouble());
            }
            if (p['currency'] is String) {
              next = next.copyWith(currency: p['currency']);
            }
            if (p['checked'] is bool) {
              next = next.copyWith(checked: p['checked']);
            }
            if (p.containsKey('checkedBy')) {
              final cb = p['checkedBy'];
              next = (cb is String && cb.isNotEmpty)
                  ? next.copyWith(checkedBy: cb)
                  : next.copyWith(checkedBy: null, clearCheckedBy: true);
            }
            return next;
          }).toList();
          _data = AppData.fromJson(
            _data.toJson()..['cart'] = list.map((e) => e.toJson()).toList(),
          );
        }
      case 'item_remove':
        if (payload['id'] is String) removeFromCart(payload['id'] as String);
      case 'list_clear':
        clearCart();
      case 'list_replace':
        final items = payload['items'];
        if (items is List) {
          final list = items
              .whereType<Map>()
              .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
              .toList();
          _data = AppData.fromJson(
            _data.toJson()..['cart'] = list.map((e) => e.toJson()).toList(),
          );
        }
    }
    _persist();
  }
}
