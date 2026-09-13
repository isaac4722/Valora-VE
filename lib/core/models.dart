/// ─── ValoraVE · Modelo de datos (verdad = MVP-CRUD.md §1 + §12.1) ──────────
/// Modelos tolerantes: `fromJson` NUNCA lanza — datos corruptos o viejos se
/// reparaman con defaults sensatos. `toJson` produce JSON canónico compatible
/// con el backup del web (version: 12).
library;

import 'currencies.dart';

const int kDataVersion = 12;

/// Límite duro de listas importadas (mergeBackupData del web §4).
const int kMaxPerList = 10000;

/// Máximo de plantillas (§2.4).
const int kMaxTemplates = 20;

// ─── Utilidades de parsing tolerante ───────────────────────────────────────

double dOf(dynamic v, [double fallback = 0]) {
  if (v is num) return v.isFinite ? v.toDouble() : fallback;
  if (v is String) {
    final parsed = double.tryParse(v.replaceAll(',', '.'));
    if (parsed != null && parsed.isFinite) return parsed;
  }
  return fallback;
}

int iOf(dynamic v, [int fallback = 0]) => dOf(v, fallback.toDouble()).round();

bool bOf(dynamic v, [bool fallback = false]) =>
    v is bool ? v : (fallback && v != null ? v == true : v == true);

String sOf(dynamic v, [String fallback = '']) =>
    v is String ? v : (v == null ? fallback : '$v');

/// num opcional tolerante (null si no es número finito).
double? numOrNull(dynamic v) {
  if (v is num) return v.isFinite ? v.toDouble() : null;
  if (v is String) return double.tryParse(v.replaceAll(',', '.'));
  return null;
}

DateTime? dtOf(dynamic v) {
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v);
}

List<String> sListOf(dynamic v) =>
    v is List ? v.map((e) => sOf(e)).where((s) => s.isNotEmpty).toList() : const [];

// ─── 1.1 RateEntry / RateBoard ─────────────────────────────────────────────

class RateEntry {
  final double rate;
  final DateTime updatedAt;
  const RateEntry({required this.rate, required this.updatedAt});

  Map<String, dynamic> toJson() => {
        'rate': rate,
        'updatedAt': updatedAt.toIso8601String(),
      };

  static RateEntry? tryParse(Map<String, dynamic> j) {
    final r = dOf(j['rate']);
    if (r <= 0 || !r.isFinite) return null;
    return RateEntry(rate: r, updatedAt: dtOf(j['updatedAt']) ?? DateTime.now());
  }
}

class RateBoard {
  final Map<String, RateEntry> sources; // por sourceId (solo ids vivos)
  final List<String> providers; // respondieron
  final List<String> degraded; // fallaron (UI degradada)
  final DateTime? lastUpdate; // reloj de la consulta (cliente nativo)
  final DateTime? fetchedAt; // reloj al recibir (para «hace X min»)
  const RateBoard({
    required this.sources,
    this.providers = const [],
    this.degraded = const [],
    this.lastUpdate,
    this.fetchedAt,
  });

  const RateBoard.empty()
      : sources = const {},
        providers = const [],
        degraded = const [],
        lastUpdate = null,
        fetchedAt = null;

  bool get isEmpty => sources.isEmpty;

  RateBoard copyWith({
    Map<String, RateEntry>? sources,
    List<String>? providers,
    List<String>? degraded,
    DateTime? lastUpdate,
    DateTime? fetchedAt,
  }) =>
      RateBoard(
        sources: sources ?? this.sources,
        providers: providers ?? this.providers,
        degraded: degraded ?? this.degraded,
        lastUpdate: lastUpdate ?? this.lastUpdate,
        fetchedAt: fetchedAt ?? this.fetchedAt,
      );

  Map<String, dynamic> toJson() => {
        'sources': sources.map((k, v) => MapEntry(k, v.toJson())),
        'providers': providers,
        'degraded': degraded,
        'lastUpdate': lastUpdate?.toIso8601String(),
        'fetchedAt': fetchedAt?.toIso8601String(),
      };

  static RateBoard fromJson(Map<String, dynamic> j) {
    final raw = (j['sources'] as Map?) ?? const {};
    final sources = <String, RateEntry>{};
    raw.forEach((k, v) {
      if (v is Map) {
        final e = RateEntry.tryParse(Map<String, dynamic>.from(v));
        if (e != null && RateSource.of(k as String) != null) {
          sources[k] = e; // purga ids desconocidos (web §2.1)
        }
      }
    });
    return RateBoard(
      sources: sources,
      providers: sListOf(j['providers']),
      degraded: sListOf(j['degraded']),
      lastUpdate: dtOf(j['lastUpdate']),
      fetchedAt: dtOf(j['fetchedAt']),
    );
  }
}

// ─── 1.2 PriceRecord (9 campos) ────────────────────────────────────────────

class PriceRecord {
  final String id;
  final double price; // USD normalizado
  final double originalPrice; // tal cual
  final String currency; // CurrencyCode
  final int quantity;
  final String? store;
  final String? notes;
  final double rate; // tasa usada
  final String sourceId; // ej. 'ves-parallel'
  final DateTime date;

  const PriceRecord({
    required this.id,
    required this.price,
    required this.originalPrice,
    required this.currency,
    required this.quantity,
    this.store,
    this.notes,
    required this.rate,
    required this.sourceId,
    required this.date,
  });

  PriceRecord copyWith({
    double? price,
    double? originalPrice,
    String? currency,
    int? quantity,
    String? store,
    String? notes,
    double? rate,
    String? sourceId,
    DateTime? date,
  }) =>
      PriceRecord(
        id: id,
        price: price ?? this.price,
        originalPrice: originalPrice ?? this.originalPrice,
        currency: currency ?? this.currency,
        quantity: quantity ?? this.quantity,
        store: store ?? this.store,
        notes: notes ?? this.notes,
        rate: rate ?? this.rate,
        sourceId: sourceId ?? this.sourceId,
        date: date ?? this.date,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'price': price,
        'originalPrice': originalPrice,
        'currency': currency,
        'quantity': quantity,
        'store': store,
        'notes': notes,
        'rate': rate,
        'sourceId': sourceId,
        'date': date.toIso8601String(),
      };

  factory PriceRecord.fromJson(Map<String, dynamic> j) => PriceRecord(
        id: sOf(j['id']),
        price: dOf(j['price']),
        originalPrice: dOf(j['originalPrice']),
        currency: sOf(j['currency'], 'USD'),
        quantity: iOf(j['quantity'], 1),
        store: j['store'] as String?,
        notes: j['notes'] as String?,
        rate: dOf(j['rate']),
        sourceId: sOf(j['sourceId'], 'ves-bcv'),
        date: dtOf(j['date']) ?? DateTime.now(),
      );
}

// ─── 1.3 Product (13 campos) ───────────────────────────────────────────────

enum Presentation { unit, weight, volume, pack }

extension PresentationX on Presentation {
  String get label => switch (this) {
        Presentation.unit => 'Unidad',
        Presentation.weight => 'Peso',
        Presentation.volume => 'Volumen',
        Presentation.pack => 'Paquete',
      };
  String get code => enumCode(this);
  static Presentation from(String? s) => switch (s) {
        'weight' => Presentation.weight,
        'volume' => Presentation.volume,
        'pack' => Presentation.pack,
        _ => Presentation.unit,
      };
}

/// Categorías de producto (§1.10 PRODUCT_CATEGORIES, 7).
enum ProductCategory { alimentos, bebidas, limpieza, higiene, farmacia, tecnologia, otros }

extension ProductCategoryX on ProductCategory {
  String get label => switch (this) {
        ProductCategory.alimentos => 'Alimentos',
        ProductCategory.bebidas => 'Bebidas',
        ProductCategory.limpieza => 'Limpieza',
        ProductCategory.higiene => 'Higiene',
        ProductCategory.farmacia => 'Farmacia',
        ProductCategory.tecnologia => 'Tecnología',
        ProductCategory.otros => 'Otros',
      };
  String get code => enumCode(this);
  static ProductCategory from(String? s) {
    for (final c in ProductCategory.values) {
      if (enumCode(c) == s) return c;
    }
    return ProductCategory.otros;
  }
}

class Product {
  final String id;
  final String name;
  final String? barcode;
  final ProductCategory category;
  final Presentation presentation;
  final double size; // g / ml / pzas
  final String? sizeUnit; // mg|g|kg|ml|l
  final DateTime createdAt;
  final List<PriceRecord> records; // asc por fecha; último = vigente
  final DateTime? unavailableSince; // no disponible desde (null = disponible)
  final double? targetPrice; // meta (en targetCurrency)
  final String targetCurrency; // default 'USD'
  final DateTime? metSince; // ISO cuando quedó BAJO meta

  const Product({
    required this.id,
    required this.name,
    this.barcode,
    required this.category,
    required this.presentation,
    required this.size,
    this.sizeUnit,
    required this.createdAt,
    required this.records,
    this.unavailableSince,
    this.targetPrice,
    this.targetCurrency = 'USD',
    this.metSince,
  });

  PriceRecord? get latestRecord =>
      records.isEmpty ? null : records.reduce((a, b) => a.date.isAfter(b.date) ? a : b);

  bool get isUnavailable => unavailableSince != null;

  Product copyWith({
    String? name,
    String? barcode,
    ProductCategory? category,
    Presentation? presentation,
    double? size,
    String? sizeUnit,
    List<PriceRecord>? records,
    DateTime? unavailableSince,
    bool clearUnavailable = false,
    double? targetPrice,
    bool clearTarget = false,
    String? targetCurrency,
    DateTime? metSince,
    bool clearMetSince = false,
  }) =>
      Product(
        id: id,
        name: name ?? this.name,
        barcode: barcode ?? this.barcode,
        category: category ?? this.category,
        presentation: presentation ?? this.presentation,
        size: size ?? this.size,
        sizeUnit: sizeUnit ?? this.sizeUnit,
        createdAt: createdAt,
        records: records ?? this.records,
        unavailableSince:
            clearUnavailable ? null : (unavailableSince ?? this.unavailableSince),
        targetPrice: clearTarget ? null : (targetPrice ?? this.targetPrice),
        targetCurrency: targetCurrency ?? this.targetCurrency,
        metSince: clearMetSince ? null : (metSince ?? this.metSince),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'barcode': barcode,
        'category': category.code,
        'presentation': presentation.code,
        'size': size,
        'sizeUnit': sizeUnit,
        'createdAt': createdAt.toIso8601String(),
        'records': records.map((r) => r.toJson()).toList(),
        'unavailableSince': unavailableSince?.toIso8601String(),
        'targetPrice': targetPrice,
        'targetCurrency': targetCurrency,
        'metSince': metSince?.toIso8601String(),
      };

  factory Product.fromJson(Map<String, dynamic> j) => Product(
        id: sOf(j['id']),
        name: sOf(j['name']),
        barcode: j['barcode'] as String?,
        category: ProductCategoryX.from(sOf(j['category'], 'otros')),
        presentation: PresentationX.from(sOf(j['presentation'], 'unit')),
        size: dOf(j['size'], 1),
        sizeUnit: j['sizeUnit'] as String?,
        createdAt: dtOf(j['createdAt']) ?? DateTime.now(),
        records: () {
          final list = j['records'] is List
              ? (j['records'] as List)
                  .whereType<Map>()
                  .map((r) => PriceRecord.fromJson(Map<String, dynamic>.from(r)))
                  .toList()
              : <PriceRecord>[];
          list.sort((a, b) => a.date.compareTo(b.date));
          return list;
        }(),
        unavailableSince: dtOf(j['unavailableSince']),
        targetPrice: (j['targetPrice'] as num?)?.toDouble(),
        targetCurrency: sOf(j['targetCurrency'], 'USD'),
        metSince: dtOf(j['metSince']),
      );
}

// ─── 1.4 Transaction (8 campos, con amountUSD §12.1) ───────────────────────
// v17.8: el módulo Finanzas se retiró de la UI (orden del dueño — los
// gastos ahora viven en Análisis, alimentados por las compras de Lista).
// El modelo SE CONSERVA: respaldos viejos con movimientos siguen
// restaurando y haciendo round-trip SIN pérdida de datos (Regla honesta).

/// Categorías de finanzas (§1.10 FINANCE_CATEGORIES, 9).
/// v17.8: solo para parsear respaldos históricos — sin UI activa.
enum FinanceCategory {
  salario, otrosIngresos, // income
  alimentacion, transporte, servicios, entretenimiento, salud, educacion, otrosGastos,
}

extension FinanceCategoryX on FinanceCategory {
  bool get isIncome => this == FinanceCategory.salario || this == FinanceCategory.otrosIngresos;
  String get label => switch (this) {
        FinanceCategory.salario => 'Salario',
        FinanceCategory.otrosIngresos => 'Otros ingresos',
        FinanceCategory.alimentacion => 'Alimentación',
        FinanceCategory.transporte => 'Transporte',
        FinanceCategory.servicios => 'Servicios',
        FinanceCategory.entretenimiento => 'Entretenimiento',
        FinanceCategory.salud => 'Salud',
        FinanceCategory.educacion => 'Educación',
        FinanceCategory.otrosGastos => 'Otros gastos',
      };
  String get code => enumCode(this);
  static FinanceCategory from(String? s) {
    for (final c in FinanceCategory.values) {
      if (enumCode(c) == s) return c;
    }
    return FinanceCategory.otrosGastos;
  }
}

class Transaction {
  final String id;
  final String type; // 'income' | 'expense'
  final FinanceCategory category;
  final double amount;
  final String currency;
  final double amountUSD; // normalizado al momento (§12.1)
  final DateTime date;
  final String? description;

  const Transaction({
    required this.id,
    required this.type,
    required this.category,
    required this.amount,
    required this.currency,
    required this.amountUSD,
    required this.date,
    this.description,
  });

  bool get isIncome => type == 'income';

  Transaction copyWith({
    String? type,
    FinanceCategory? category,
    double? amount,
    String? currency,
    double? amountUSD,
    DateTime? date,
    String? description,
  }) =>
      Transaction(
        id: id,
        type: type ?? this.type,
        category: category ?? this.category,
        amount: amount ?? this.amount,
        currency: currency ?? this.currency,
        amountUSD: amountUSD ?? this.amountUSD,
        date: date ?? this.date,
        description: description ?? this.description,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'type': type,
        'category': category.code,
        'amount': amount,
        'currency': currency,
        'amountUSD': amountUSD,
        'date': date.toIso8601String(),
        'description': description,
      };

  factory Transaction.fromJson(Map<String, dynamic> j) => Transaction(
        id: sOf(j['id']),
        type: sOf(j['type'], 'expense') == 'income' ? 'income' : 'expense',
        category: FinanceCategoryX.from(sOf(j['category'], 'otrosGastos')),
        amount: dOf(j['amount']),
        currency: sOf(j['currency'], 'USD'),
        amountUSD: dOf(j['amountUSD']),
        date: dtOf(j['date']) ?? DateTime.now(),
        description: j['description'] as String?,
      );
}

// ─── 1.5 CartItem (9 campos, con checked/checkedBy §12.1) ──────────────────

class CartItem {
  final String id;
  final String? productId;
  final String name;
  final int quantity;
  final double price; // unitario tal cual
  final String currency;
  final String? barcode;
  final bool checked; // comprado (local o sala, v13.4)
  final String? checkedBy; // «Comprador 88»
  final String? store; // tienda del ítem (multitienda v17.2; null = única de la compra)
  final double? size; // tamaño de la presentación (p.ej. 600)
  final String? sizeUnit; // g | kg | ml | l | pzas

  const CartItem({
    required this.id,
    this.productId,
    required this.name,
    required this.quantity,
    required this.price,
    required this.currency,
    this.barcode,
    this.checked = false,
    this.checkedBy,
    this.store,
    this.size,
    this.sizeUnit,
  });

  CartItem copyWith({
    String? id,
    String? productId,
    String? name,
    int? quantity,
    double? price,
    String? currency,
    String? barcode,
    bool? checked,
    String? checkedBy,
    bool clearCheckedBy = false,
    bool clearProduct = false,
    String? store,
    bool clearStore = false,
    double? size,
    bool clearSize = false,
    String? sizeUnit,
    bool clearSizeUnit = false,
  }) =>
      CartItem(
        id: id ?? this.id,
        productId: clearProduct ? null : (productId ?? this.productId),
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        price: price ?? this.price,
        currency: currency ?? this.currency,
        barcode: barcode ?? this.barcode,
        checked: checked ?? this.checked,
        checkedBy: clearCheckedBy ? null : (checkedBy ?? this.checkedBy),
        store: clearStore ? null : (store ?? this.store),
        size: clearSize ? null : (size ?? this.size),
        sizeUnit: clearSizeUnit ? null : (sizeUnit ?? this.sizeUnit),
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'productId': productId,
        'name': name,
        'quantity': quantity,
        'price': price,
        'currency': currency,
        'barcode': barcode,
        'checked': checked,
        'checkedBy': checkedBy,
        'store': store,
        'size': size,
        'sizeUnit': sizeUnit,
      };

  factory CartItem.fromJson(Map<String, dynamic> j) => CartItem(
        id: sOf(j['id']),
        productId: j['productId'] as String?,
        name: sOf(j['name']),
        quantity: iOf(j['quantity'], 1).clamp(1, 999),
        price: dOf(j['price']),
        currency: sOf(j['currency'], 'USD'),
        barcode: j['barcode'] as String?,
        checked: j['checked'] == true,
        checkedBy: j['checkedBy'] as String?,
        store: j['store'] as String?,
        size: j['size'] == null ? null : dOf(j['size']),
        sizeUnit: j['sizeUnit'] as String?,
      );
}

// ─── 1.6 PurchaseItem / Purchase (campos reales, sin subtotal fantasma) ────

class PurchaseItem {
  final String name;
  final int quantity;
  final double priceUSD; // normalizado al comprar
  final double originalPrice; // unitario tal cual
  final String currency;
  final String? productId; // vínculo catálogo
  final String? store; // tienda de ESTE ítem (multitienda v17.2)
  final double? size; // tamaño capturado en la lista (peso/volumen)
  final String? sizeUnit; // g | kg | ml | l | pzas

  const PurchaseItem({
    required this.name,
    required this.quantity,
    required this.priceUSD,
    required this.originalPrice,
    required this.currency,
    this.productId,
    this.store,
    this.size,
    this.sizeUnit,
  });

  PurchaseItem copyWith({
    String? name,
    int? quantity,
    double? priceUSD,
    double? originalPrice,
    String? currency,
    String? productId,
    String? store,
    double? size,
    String? sizeUnit,
  }) =>
      PurchaseItem(
        name: name ?? this.name,
        quantity: quantity ?? this.quantity,
        priceUSD: priceUSD ?? this.priceUSD,
        originalPrice: originalPrice ?? this.originalPrice,
        currency: currency ?? this.currency,
        productId: productId ?? this.productId,
        store: store ?? this.store,
        size: size ?? this.size,
        sizeUnit: sizeUnit ?? this.sizeUnit,
      );

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'priceUSD': priceUSD,
        'originalPrice': originalPrice,
        'currency': currency,
        'productId': productId,
        'store': store,
        'size': size,
        'sizeUnit': sizeUnit,
      };

  factory PurchaseItem.fromJson(Map<String, dynamic> j) => PurchaseItem(
        name: sOf(j['name']),
        quantity: iOf(j['quantity'], 1).clamp(1, 999),
        priceUSD: dOf(j['priceUSD']),
        originalPrice: dOf(j['originalPrice']),
        currency: sOf(j['currency'], 'USD'),
        productId: j['productId'] as String?,
        store: j['store'] as String?,
        size: j['size'] == null ? null : dOf(j['size']),
        sizeUnit: j['sizeUnit'] as String?,
      );
}

class Purchase {
  final String id;
  final DateTime date;
  final String? store;
  final List<PurchaseItem> items;
  final double totalUSD;
  final double totalBS; // VES con tasa del momento
  final double rate; // VES/USD usada
  final String? rateSourceId;
  final bool igtf; // v14 histórico: solo display, motor nunca lo aplica
  final double? paidTotal; // si ajustó total
  final String? paidCurrency; // default 1ª moneda del carrito
  final String? ticketPhoto; // data URL comprimida ~200KB
  final String? notes;

  const Purchase({
    required this.id,
    required this.date,
    this.store,
    required this.items,
    required this.totalUSD,
    required this.totalBS,
    required this.rate,
    this.rateSourceId,
    this.igtf = false,
    this.paidTotal,
    this.paidCurrency,
    this.ticketPhoto,
    this.notes,
  });

  /// Total pagado efectivo (ajustado o total); IGTF solo display histórico.
  double get paidUSD => paidTotal ?? totalUSD;

  Purchase copyWith({
    String? id, // respaldado: addPurchase genera id para compras sin él
    DateTime? date,
    String? store,
    List<PurchaseItem>? items,
    double? totalUSD,
    double? totalBS,
    double? rate,
    String? rateSourceId,
    double? paidTotal,
    String? paidCurrency,
    String? ticketPhoto,
    bool clearTicket = false,
    String? notes,
  }) =>
      Purchase(
        id: id ?? this.id,
        date: date ?? this.date,
        store: store ?? this.store,
        items: items ?? this.items,
        totalUSD: totalUSD ?? this.totalUSD,
        totalBS: totalBS ?? this.totalBS,
        rate: rate ?? this.rate,
        rateSourceId: rateSourceId ?? this.rateSourceId,
        igtf: igtf,
        paidTotal: paidTotal ?? this.paidTotal,
        paidCurrency: paidCurrency ?? this.paidCurrency,
        ticketPhoto: clearTicket ? null : (ticketPhoto ?? this.ticketPhoto),
        notes: notes ?? this.notes,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'store': store,
        'items': items.map((e) => e.toJson()).toList(),
        'totalUSD': totalUSD,
        'totalBS': totalBS,
        'rate': rate,
        'rateSourceId': rateSourceId,
        'igtf': igtf,
        'paidTotal': paidTotal,
        'paidCurrency': paidCurrency,
        'ticketPhoto': ticketPhoto,
        'notes': notes,
      };

  factory Purchase.fromJson(Map<String, dynamic> j) => Purchase(
        id: sOf(j['id']),
        date: dtOf(j['date']) ?? DateTime.now(),
        store: j['store'] as String?,
        items: (j['items'] is List
            ? (j['items'] as List)
                .whereType<Map>()
                .map((e) => PurchaseItem.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const <PurchaseItem>[]),
        totalUSD: dOf(j['totalUSD']),
        totalBS: dOf(j['totalBS']),
        rate: dOf(j['rate']),
        rateSourceId: j['rateSourceId'] as String?,
        igtf: j['igtf'] == true,
        paidTotal: (j['paidTotal'] as num?)?.toDouble(),
        paidCurrency: j['paidCurrency'] as String?,
        ticketPhoto: j['ticketPhoto'] as String?,
        notes: j['notes'] as String?,
      );
}

// ─── 1.7 ShoppingTemplate / ShoppingTemplateItem / BasketItem ──────────────

class ShoppingTemplateItem {
  final String name;
  final int quantity;
  final double price; // congelado
  final String currency;
  final String? productId;
  final String? barcode;

  const ShoppingTemplateItem({
    required this.name,
    required this.quantity,
    required this.price,
    required this.currency,
    this.productId,
    this.barcode,
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'quantity': quantity,
        'price': price,
        'currency': currency,
        'productId': productId,
        'barcode': barcode,
      };

  factory ShoppingTemplateItem.fromJson(Map<String, dynamic> j) =>
      ShoppingTemplateItem(
        name: sOf(j['name']),
        quantity: iOf(j['quantity'], 1).clamp(1, 999),
        price: dOf(j['price']),
        currency: sOf(j['currency'], 'USD'),
        productId: j['productId'] as String?,
        barcode: j['barcode'] as String?,
      );
}

class ShoppingTemplate {
  final String id;
  final String name;
  final DateTime createdAt;
  final List<ShoppingTemplateItem> items;

  const ShoppingTemplate({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.items,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'createdAt': createdAt.toIso8601String(),
        'items': items.map((e) => e.toJson()).toList(),
      };

  factory ShoppingTemplate.fromJson(Map<String, dynamic> j) => ShoppingTemplate(
        id: sOf(j['id']),
        name: sOf(j['name']),
        createdAt: dtOf(j['createdAt']) ?? DateTime.now(),
        items: (j['items'] is List
            ? (j['items'] as List)
                .whereType<Map>()
                .map((e) => ShoppingTemplateItem.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const <ShoppingTemplateItem>[]),
      );
}

class BasketItem {
  final String productId;
  final int quantity;

  const BasketItem({required this.productId, required this.quantity});

  Map<String, dynamic> toJson() => {'productId': productId, 'quantity': quantity};

  factory BasketItem.fromJson(Map<String, dynamic> j) => BasketItem(
        productId: sOf(j['productId']),
        quantity: iOf(j['quantity'], 1),
      );
}

// ─── 1.8 Settings (14 campos, SIN theme — §12.1) ───────────────────────────

/// Módulos con fuente de tasa propia (v11).
enum RateModule { converter, calculator, finance }

extension RateModuleX on RateModule {
  String get code => enumCode(this);
  static RateModule from(String? s) => switch (s) {
        'converter' => RateModule.converter,
        'finance' => RateModule.finance,
        _ => RateModule.calculator,
      };
}

String moduleRateKey(String module, String currency) => '$module:$currency';

/// Sensibilidades de picos (v9): high 1% · medium 2% · low 3%.
const Map<String, double> spikeSensitivities = {
  'high': 1,
  'medium': 2,
  'low': 3,
};

class Settings {
  final String country; // VE · CO · BR · MX · US (default VE)
  final bool autoRefresh;
  final String tickerMode; // 'featured' | 'focus' | 'off' (solo Inicio)
  final bool onboarded; // bienvenida + tutorial
  final String calcCurrency; // v10 moneda totales Lista (default VES)
  final bool spikeAlerts;
  final double spikeThreshold; // default 2 (%)
  final List<String> spikeWatch; // v9 sourceIds
  final Map<String, String> rateSourcesByModule; // 'modulo:DIVISA' → fuente
  final double? targetBcv; // v12 rateTargetAlerts.bcv (null = off)
  final double? targetParallel; // v12 rateTargetAlerts.parallel
  final double? salaryAmount; // v12.2 sueldo mensual pactado (modo fijo)
  final String salaryCurrency;
  final String salaryMode; // v15 D1: 'fijo' | 'base' | 'rango' (máx 2 opciones)
  final double? salaryBase; // modo base: pago fijo
  final double? salaryVariable; // modo base: parte variable
  final double? salaryMin; // modo rango: mínimo
  final double? salaryMax; // modo rango: máximo
  final String tickerSize; // v13 'compact' | 'normal' | 'large'
  final int tickerSpeed; // v13 90 | 120 | 180 (segundos por vuelta)
  final List<String> currencyOrder; // v13 (vacío = canónico, se purga)
  final bool offlineMode; // v17.2: sin NINGUNA consulta a APIs (solo guardadas)
  final int pollMinutes; // v17.2: cada cuánto consulta la app las APIs (1..60)
  final bool biometricLock; // 17.7: pedir huella/rostro al abrir la app
  final String sseUrl; // 17.7: SSE en vivo opcional de un despliegue web ('' = off)

  const Settings({
    this.country = 'VE',
    this.autoRefresh = true,
    this.offlineMode = false,
    this.pollMinutes = 1,
    this.biometricLock = false,
    this.sseUrl = '',
    this.tickerMode = 'featured',
    this.onboarded = false,
    this.calcCurrency = 'VES',
    this.spikeAlerts = false,
    this.spikeThreshold = 2,
    this.spikeWatch = const ['ves-bcv', 'ves-parallel'],
    this.rateSourcesByModule = const {},
    this.targetBcv,
    this.targetParallel,
    this.salaryAmount,
    this.salaryCurrency = 'USD',
    this.salaryMode = 'fijo',
    this.salaryBase,
    this.salaryVariable,
    this.salaryMin,
    this.salaryMax,
    this.tickerSize = 'normal',
    this.tickerSpeed = 120,
    this.currencyOrder = const [],
  });

  const Settings.defaults() : this._defaultC();

  const Settings._defaultC()
      : country = 'VE',
        autoRefresh = true,
        offlineMode = false,
        pollMinutes = 1,
        biometricLock = false,
        sseUrl = '',
        tickerMode = 'featured',
        onboarded = false,
        calcCurrency = 'VES',
        spikeAlerts = false,
        spikeThreshold = 2,
        spikeWatch = const ['ves-bcv', 'ves-parallel'],
        rateSourcesByModule = const {},
        targetBcv = null,
        targetParallel = null,
        salaryAmount = null,
        salaryCurrency = 'USD',
        salaryMode = 'fijo',
        salaryBase = null,
        salaryVariable = null,
        salaryMin = null,
        salaryMax = null,
        tickerSize = 'normal',
        tickerSpeed = 120,
        currencyOrder = const [];

  Settings copyWith({
    String? country,
    bool? autoRefresh,
    bool? offlineMode,
    int? pollMinutes,
    String? tickerMode,
    bool? onboarded,
    String? calcCurrency,
    bool? spikeAlerts,
    double? spikeThreshold,
    List<String>? spikeWatch,
    Map<String, String>? rateSourcesByModule,
    double? targetBcv,
    bool clearTargetBcv = false,
    double? targetParallel,
    bool clearTargetParallel = false,
    double? salaryAmount,
    bool clearSalary = false,
    String? salaryCurrency,
    String? salaryMode,
    double? salaryBase,
    bool clearSalaryBase = false,
    double? salaryVariable,
    bool clearSalaryVariable = false,
    double? salaryMin,
    bool clearSalaryMin = false,
    double? salaryMax,
    bool clearSalaryMax = false,
    String? tickerSize,
    int? tickerSpeed,
    List<String>? currencyOrder,
    bool? biometricLock,
    String? sseUrl,
  }) =>
      Settings(
        country: country ?? this.country,
        autoRefresh: autoRefresh ?? this.autoRefresh,
        offlineMode: offlineMode ?? this.offlineMode,
        pollMinutes: pollMinutes ?? this.pollMinutes,
        tickerMode: tickerMode ?? this.tickerMode,
        onboarded: onboarded ?? this.onboarded,
        calcCurrency: calcCurrency ?? this.calcCurrency,
        spikeAlerts: spikeAlerts ?? this.spikeAlerts,
        spikeThreshold: spikeThreshold ?? this.spikeThreshold,
        spikeWatch: spikeWatch ?? this.spikeWatch,
        rateSourcesByModule: rateSourcesByModule ?? this.rateSourcesByModule,
        targetBcv: clearTargetBcv ? null : (targetBcv ?? this.targetBcv),
        targetParallel:
            clearTargetParallel ? null : (targetParallel ?? this.targetParallel),
        salaryAmount: clearSalary ? null : (salaryAmount ?? this.salaryAmount),
        salaryCurrency: salaryCurrency ?? this.salaryCurrency,
        salaryMode: salaryMode ?? this.salaryMode,
        salaryBase: clearSalaryBase ? null : (salaryBase ?? this.salaryBase),
        salaryVariable:
            clearSalaryVariable ? null : (salaryVariable ?? this.salaryVariable),
        salaryMin: clearSalaryMin ? null : (salaryMin ?? this.salaryMin),
        salaryMax: clearSalaryMax ? null : (salaryMax ?? this.salaryMax),
        tickerSize: tickerSize ?? this.tickerSize,
        tickerSpeed: tickerSpeed ?? this.tickerSpeed,
        currencyOrder: currencyOrder ?? this.currencyOrder,
        biometricLock: biometricLock ?? this.biometricLock,
        sseUrl: sseUrl ?? this.sseUrl,
      );

  Map<String, dynamic> toJson() => {
        'country': country,
        'autoRefresh': autoRefresh,
        'offlineMode': offlineMode,
        'pollMinutes': pollMinutes,
        'tickerMode': tickerMode,
        'onboarded': onboarded,
        'calcCurrency': calcCurrency,
        'spikeAlerts': spikeAlerts,
        'spikeThreshold': spikeThreshold,
        'spikeWatch': spikeWatch,
        'rateSourcesByModule': rateSourcesByModule,
        'rateTargetAlerts': {'bcv': targetBcv, 'parallel': targetParallel},
        'salary': _salaryToJson(
            salaryAmount, salaryCurrency, salaryMode, salaryBase,
            salaryVariable, salaryMin, salaryMax),
        'tickerSize': tickerSize,
        'tickerSpeed': tickerSpeed,
        'currencyOrder': currencyOrder,
        'biometricLock': biometricLock,
        'sseUrl': sseUrl,
      };

  /// Mapa de sueldo tolerante: el modo fijo usa amount; los modos variables
  /// (base+rango del web v12) arrastran sus campos. Null si no hay nada.
  static Map<String, dynamic>? _salaryToJson(
      double? amount, String currency, String mode,
      double? base, double? variable, double? min, double? max) {
    final hasAny = amount != null || base != null || variable != null || min != null || max != null;
    if (!hasAny) return null;
    return {
      'amount': amount,
      'currency': currency,
      'mode': mode,
      'base': base,
      'variable': variable,
      'min': min,
      'max': max,
    };
  }

  /// Sueldo mensual efectivo según el modo (fijo | base+variable | rango).
  /// Null honesto cuando el modo activo no tiene datos completos.
  double? effectiveSalary() {
    switch (salaryMode) {
      case 'base':
        final b = salaryBase ?? salaryAmount;
        final v = salaryVariable ?? 0;
        if (b == null || b <= 0) return null;
        return b + v;
      case 'rango':
        final lo = salaryMin, hi = salaryMax;
        if (lo == null || hi == null || lo <= 0 || hi < lo) return null;
        return (lo + hi) / 2;
      default:
        return (salaryAmount != null && salaryAmount! > 0) ? salaryAmount : null;
    }
  }

  /// Merge tolerante de settings incompletos (repara HMR del web §2).
  static Settings fromJson(Map<String, dynamic> j) {
    final targets = (j['rateTargetAlerts'] as Map?) ?? const {};
    final salary = (j['salary'] as Map?) ?? const {};
    return Settings(
      country: CountryX.from(sOf(j['country'], 'VE')).code,
      autoRefresh: j['autoRefresh'] != false,
      offlineMode: j['offlineMode'] == true,
      pollMinutes: (iOf(j['pollMinutes'], 1)).clamp(1, 60),
      biometricLock: j['biometricLock'] == true,
      sseUrl: sOf(j['sseUrl'], '').trim(),
      tickerMode: switch (sOf(j['tickerMode'], 'featured')) {
        'focus' => 'focus',
        'off' => 'off',
        _ => 'featured',
      },
      onboarded: j['onboarded'] == true,
      calcCurrency: sOf(j['calcCurrency'], 'VES').toUpperCase(),
      spikeAlerts: j['spikeAlerts'] == true,
      spikeThreshold: dOf(j['spikeThreshold'], 2).clamp(0.5, 5),
      spikeWatch: ((j['spikeWatch'] as List?) ?? const ['ves-bcv', 'ves-parallel'])
          .map((e) => sOf(e))
          .where((s) => RateSource.of(s) != null)
          .toList(),
      rateSourcesByModule: ((j['rateSourcesByModule'] as Map?) ?? const {})
          .map((k, v) => MapEntry(sOf(k), sOf(v))),
      targetBcv: numOrNull(targets['bcv'] ?? j['targetBcv']),
      targetParallel: numOrNull(targets['parallel'] ?? j['targetParallel']),
      salaryAmount: salary['amount'] != null ? dOf(salary['amount']) : null,
      salaryCurrency: sOf(salary['currency'], 'USD').toUpperCase(),
      salaryMode: switch (sOf(salary['mode'], 'fijo')) {
        'base' => 'base',
        'rango' => 'rango',
        _ => 'fijo',
      },
      salaryBase: salary['base'] != null ? dOf(salary['base']) : null,
      salaryVariable: salary['variable'] != null ? dOf(salary['variable']) : null,
      salaryMin: salary['min'] != null ? dOf(salary['min']) : null,
      salaryMax: salary['max'] != null ? dOf(salary['max']) : null,
      tickerSize: switch (sOf(j['tickerSize'], 'normal')) {
        'compact' => 'compact',
        'large' => 'large',
        _ => 'normal',
      },
      tickerSpeed: switch (iOf(j['tickerSpeed'], 120)) { 90 => 90, 180 => 180, _ => 120 },
      currencyOrder: sListOf(j['currencyOrder']),
    );
  }
}

// ─── 1.9 AppData (13 claves) ───────────────────────────────────────────────

class Budget {
  final double amount;
  final String currency;
  const Budget({this.amount = 0, this.currency = 'VES'});

  Map<String, dynamic> toJson() => {'amount': amount, 'currency': currency};

  static Budget fromJson(Map<String, dynamic> j) => Budget(
        amount: dOf(j['amount']),
        currency: sOf(j['currency'], 'VES'),
      );
}

class ConverterState {
  final String from;
  final String to;
  const ConverterState({this.from = 'USD', this.to = 'VES'});

  Map<String, dynamic> toJson() => {'from': from, 'to': to};

  static ConverterState fromJson(Map<String, dynamic> j) => ConverterState(
        from: sOf(j['from'], 'USD').toUpperCase(),
        to: sOf(j['to'], 'VES').toUpperCase(),
      );
}

/// Notificación del centro (ring 50, 9 kinds §7/§9.9).
enum NotifKind { spike, target, threshold, gap, daily, reminder, bcv, test, info }

extension NotifKindX on NotifKind {
  String get code => enumCode(this);
  static NotifKind from(String? s) {
    for (final k in NotifKind.values) {
      if (enumCode(k) == s) return k;
    }
    return NotifKind.info;
  }
}

class NotificationItem {
  final String id;
  final NotifKind kind;
  final String title;
  final String body;
  final DateTime at;
  final bool read;

  const NotificationItem({
    required this.id,
    required this.kind,
    required this.title,
    required this.body,
    required this.at,
    this.read = false,
  });

  NotificationItem copyWith({bool? read}) =>
      NotificationItem(id: id, kind: kind, title: title, body: body, at: at, read: read ?? this.read);

  Map<String, dynamic> toJson() => {
        'id': id,
        'kind': kind.code,
        'title': title,
        'body': body,
        'at': at.toIso8601String(),
        'read': read,
      };

  static NotificationItem fromJson(Map<String, dynamic> j) => NotificationItem(
        id: sOf(j['id']),
        kind: NotifKindX.from(sOf(j['kind'], 'info')),
        title: sOf(j['title']),
        body: sOf(j['body']),
        at: dtOf(j['at']) ?? DateTime.now(),
        read: j['read'] == true,
      );
}

/// Conversión reciente del conversor (quick-tools, máx 10).
class RecentConversion {
  final double amount;
  final String from;
  final String to;
  final DateTime at;

  const RecentConversion({
    required this.amount,
    required this.from,
    required this.to,
    required this.at,
  });

  Map<String, dynamic> toJson() => {
        'amount': amount,
        'from': from,
        'to': to,
        'at': at.toIso8601String(),
      };

  static RecentConversion fromJson(Map<String, dynamic> j) => RecentConversion(
        amount: dOf(j['amount']),
        from: sOf(j['from'], 'USD'),
        to: sOf(j['to'], 'VES'),
        at: dtOf(j['at']) ?? DateTime.now(),
      );
}

/// Snapshot diario de una fuente (rate-history, 180 días).
class SnapshotPoint {
  final String sourceId;
  final String day; // YYYY-MM-DD
  final double rate;

  const SnapshotPoint({required this.sourceId, required this.day, required this.rate});

  Map<String, dynamic> toJson() =>
      {'sourceId': sourceId, 'day': day, 'rate': rate};

  static SnapshotPoint fromJson(Map<String, dynamic> j) => SnapshotPoint(
        sourceId: sOf(j['sourceId']),
        day: sOf(j['day']),
        rate: dOf(j['rate']),
      );

  static String dayKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
}

/// Estado completo persistido (§1.9 AppData, 13 claves).
class AppData {
  final int version;
  final RateBoard board;
  final Map<String, String> rateSource; // CurrencyCode → sourceId
  final Map<String, double> manualRates; // sourceId → valor
  final ConverterState converter;
  final List<Product> products;
  final List<Transaction> transactions;
  final List<CartItem> cart;
  final List<Purchase> purchases;
  final Budget budget;
  final List<BasketItem> basket;
  final List<String> stores;
  final List<ShoppingTemplate> templates;
  final Settings settings;

  const AppData({
    this.version = kDataVersion,
    this.board = const RateBoard.empty(),
    this.rateSource = const {
      'USD': 'usd',
      'VES': 'ves-bcv',
      'COP': 'cop-trm',
      'EUR': 'eur-ves-oficial',
      'BRL': 'brl-br',
      'MXN': 'mxn-banxico',
    },
    this.manualRates = const {},
    this.converter = const ConverterState(),
    this.products = const [],
    this.transactions = const [],
    this.cart = const [],
    this.purchases = const [],
    this.budget = const Budget(),
    this.basket = const [],
    this.stores = const [],
    this.templates = const [],
    this.settings = const Settings(),
  });

  Map<String, dynamic> toJson() => {
        'version': version,
        'board': board.toJson(),
        'rateSource': rateSource,
        'manualRates': manualRates,
        'converter': converter.toJson(),
        'products': products.map((e) => e.toJson()).toList(),
        'transactions': transactions.map((e) => e.toJson()).toList(),
        'cart': cart.map((e) => e.toJson()).toList(),
        'purchases': purchases.map((e) => e.toJson()).toList(),
        'budget': budget.toJson(),
        'basket': basket.map((e) => e.toJson()).toList(),
        'stores': stores,
        'templates': templates.map((e) => e.toJson()).toList(),
        'settings': settings.toJson(),
      };

  static AppData fromJson(Map<String, dynamic> j) => AppData(
        version: iOf(j['version'], kDataVersion),
        board: j['board'] is Map
            ? RateBoard.fromJson(Map<String, dynamic>.from(j['board'] as Map))
            : const RateBoard.empty(),
        rateSource: ((j['rateSource'] as Map?) ?? const {})
            .map((k, v) => MapEntry(sOf(k).toUpperCase(), sOf(v))),
        manualRates: ((j['manualRates'] as Map?) ?? const {})
            .map((k, v) => MapEntry(sOf(k), dOf(v))),
        converter: j['converter'] is Map
            ? ConverterState.fromJson(Map<String, dynamic>.from(j['converter'] as Map))
            : const ConverterState(),
        products: (j['products'] is List
            ? (j['products'] as List)
                .whereType<Map>()
                .map((e) => Product.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const <Product>[]),
        transactions: (j['transactions'] is List
            ? (j['transactions'] as List)
                .whereType<Map>()
                .map((e) => Transaction.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const <Transaction>[]),
        cart: (j['cart'] is List
            ? (j['cart'] as List)
                .whereType<Map>()
                .map((e) => CartItem.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const <CartItem>[]),
        purchases: (j['purchases'] is List
            ? (j['purchases'] as List)
                .whereType<Map>()
                .map((e) => Purchase.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const <Purchase>[]),
        budget: j['budget'] is Map
            ? Budget.fromJson(Map<String, dynamic>.from(j['budget'] as Map))
            : const Budget(),
        basket: (j['basket'] is List
            ? (j['basket'] as List)
                .whereType<Map>()
                .map((e) => BasketItem.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const <BasketItem>[]),
        stores: sListOf(j['stores']),
        templates: (j['templates'] is List
            ? (j['templates'] as List)
                .whereType<Map>()
                .map((e) => ShoppingTemplate.fromJson(Map<String, dynamic>.from(e)))
                .toList()
            : const <ShoppingTemplate>[]),
        settings: j['settings'] is Map
            ? Settings.fromJson(Map<String, dynamic>.from(j['settings'] as Map))
            : const Settings(),
      );
}

// ─── 1.10 Semillas del catálogo VE (21 productos, CATALOG_VE del web) ──────

class CatalogSeed {
  final String name;
  final String? barcode;
  final ProductCategory category;
  final Presentation presentation;
  final double size;
  final String? sizeUnit;

  const CatalogSeed(this.name,
      {this.barcode, required this.category, required this.presentation, required this.size, this.sizeUnit});
}

const List<CatalogSeed> kCatalogVE = [
  CatalogSeed('Harina de maíz blanco', barcode: '7590211000012', category: ProductCategory.alimentos, presentation: Presentation.weight, size: 1000, sizeUnit: 'g'),
  CatalogSeed('Arroz blanco', barcode: '7590211000029', category: ProductCategory.alimentos, presentation: Presentation.weight, size: 1000, sizeUnit: 'g'),
  CatalogSeed('Pasta larga', barcode: '7590211000036', category: ProductCategory.alimentos, presentation: Presentation.weight, size: 1000, sizeUnit: 'g'),
  CatalogSeed('Aceite de maíz', barcode: '7590211000043', category: ProductCategory.alimentos, presentation: Presentation.volume, size: 1000, sizeUnit: 'ml'),
  CatalogSeed('Azúcar refinada', barcode: '7590211000050', category: ProductCategory.alimentos, presentation: Presentation.weight, size: 1000, sizeUnit: 'g'),
  CatalogSeed('Café molido', barcode: '7590211000067', category: ProductCategory.bebidas, presentation: Presentation.weight, size: 250, sizeUnit: 'g'),
  CatalogSeed('Leche en polvo', barcode: '7590211000074', category: ProductCategory.alimentos, presentation: Presentation.weight, size: 900, sizeUnit: 'g'),
  CatalogSeed('Margarina', barcode: '7590211000081', category: ProductCategory.alimentos, presentation: Presentation.weight, size: 500, sizeUnit: 'g'),
  CatalogSeed('Atún en lata', barcode: '7590211000098', category: ProductCategory.alimentos, presentation: Presentation.weight, size: 140, sizeUnit: 'g'),
  CatalogSeed('Refresco 2 litros', barcode: '7590211000104', category: ProductCategory.bebidas, presentation: Presentation.volume, size: 2000, sizeUnit: 'ml'),
  CatalogSeed('Agua mineral', barcode: '7590211000111', category: ProductCategory.bebidas, presentation: Presentation.volume, size: 1000, sizeUnit: 'ml'),
  CatalogSeed('Cerveza lata', barcode: '7590211000128', category: ProductCategory.bebidas, presentation: Presentation.unit, size: 355, sizeUnit: 'ml'),
  CatalogSeed('Detergente en polvo', barcode: '7590211000135', category: ProductCategory.limpieza, presentation: Presentation.weight, size: 900, sizeUnit: 'g'),
  CatalogSeed('Jabón de baño', barcode: '7590211000142', category: ProductCategory.higiene, presentation: Presentation.unit, size: 110, sizeUnit: 'g'),
  CatalogSeed('Papel higiénico 4 rollos', barcode: '7590211000159', category: ProductCategory.higiene, presentation: Presentation.pack, size: 4, sizeUnit: null),
  CatalogSeed('Pasta dental', barcode: '7590211000166', category: ProductCategory.higiene, presentation: Presentation.weight, size: 90, sizeUnit: 'g'),
  CatalogSeed('Shampoo', barcode: '7590211000173', category: ProductCategory.higiene, presentation: Presentation.volume, size: 400, sizeUnit: 'ml'),
  CatalogSeed('Analgésico 500 mg', barcode: '7590211000180', category: ProductCategory.farmacia, presentation: Presentation.pack, size: 10, sizeUnit: null),
  CatalogSeed('Antiacídico pastillas', barcode: '7590211000197', category: ProductCategory.farmacia, presentation: Presentation.pack, size: 20, sizeUnit: null),
  CatalogSeed('Cable USB-C', barcode: '7590211000203', category: ProductCategory.tecnologia, presentation: Presentation.unit, size: 1, sizeUnit: null),
  CatalogSeed('Audífonos básicos', barcode: '7590211000210', category: ProductCategory.tecnologia, presentation: Presentation.unit, size: 1, sizeUnit: null),
];
