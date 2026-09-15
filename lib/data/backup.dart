/// ─── Respaldo · export/import + fusión por id (§4 backup-merge.ts) ──────────
/// mergeBackupData: unión por id (empate=local); products fusionan records +
/// meta (target/unavailable) gana el lado con el último record más reciente;
/// stores unión case-insensitive; NO toca cart/budget/board/rateSource/
/// manualRates/converter/settings. MAX_PER_LIST=10000.
library;

import 'dart:convert';

import '../core/currencies.dart';
import '../core/models.dart';

class MergeCounts {
  final int products;
  final int records;
  final int transactions;
  final int purchases;
  final int templates;
  final int stores;

  const MergeCounts({
    this.products = 0,
    this.records = 0,
    this.transactions = 0,
    this.purchases = 0,
    this.templates = 0,
    this.stores = 0,
  });

  Map<String, int> toMap() => {
    'products': products,
    'records': records,
    'transactions': transactions,
    'purchases': purchases,
    'templates': templates,
    'stores': stores,
  };
}

class BackupMergeResult {
  final AppData data;
  final MergeCounts counts;
  const BackupMergeResult(this.data, this.counts);
}

/// Export: {version:12, data:{13 claves}, savedAt} (web §2.5).
String exportBackupJson(AppData data) =>
    const JsonEncoder.withIndent('  ').convert({
      'version': kDataVersion,
      'data': data.toJson(),
      'savedAt': DateTime.now().toIso8601String(),
    });

/// Fusión pura (testeable sin IO): local + incoming → fusionado + conteos.
BackupMergeResult mergeBackupData(AppData local, AppData incoming) {
  // ── Products: unión por id (empate=local), records unidos, meta gana el
  // lado con último record más reciente.
  final products = <String, Product>{};
  for (final p in local.products) {
    products[p.id] = p;
  }
  int addedProducts = 0, addedRecords = 0;
  for (final incomingP in incoming.products) {
    if (incomingP.id.isEmpty) continue;
    final localP = products[incomingP.id];
    if (localP == null) {
      if (products.length < kMaxPerList) {
        products[incomingP.id] = incomingP;
        addedProducts++;
        addedRecords += incomingP.records.length;
      }
      continue;
    }
    // Fusión de records: por id, sino por fecha+precio (dedupe).
    final byId = {for (final r in localP.records) r.id: r};
    final mergedRecords = [...localP.records];
    for (final r in incomingP.records) {
      if (byId.containsKey(r.id)) continue;
      final dup = mergedRecords.any(
        (x) =>
            SnapshotPoint.dayKey(x.date) == SnapshotPoint.dayKey(r.date) &&
            x.price == r.price &&
            x.originalPrice == r.originalPrice,
      );
      if (dup) continue;
      mergedRecords.add(r);
      addedRecords++;
    }
    mergedRecords.sort((a, b) => a.date.compareTo(b.date));
    // Meta (target/unavailable) gana el lado con último record más reciente.
    final localLast = localP.latestRecord?.date ?? DateTime(0);
    final incomingLast = incomingP.latestRecord?.date ?? DateTime(0);
    Product merged = Product(
      id: localP.id,
      name: incomingP.name.isNotEmpty ? incomingP.name : localP.name,
      barcode: incomingP.barcode ?? localP.barcode,
      category: incomingLast.isAfter(localLast)
          ? incomingP.category
          : localP.category,
      presentation: incomingLast.isAfter(localLast)
          ? incomingP.presentation
          : localP.presentation,
      size: incomingLast.isAfter(localLast) ? incomingP.size : localP.size,
      sizeUnit: incomingLast.isAfter(localLast)
          ? incomingP.sizeUnit
          : localP.sizeUnit,
      createdAt: localP.createdAt,
      records: mergedRecords,
      unavailableSince: incomingLast.isAfter(localLast)
          ? incomingP.unavailableSince
          : localP.unavailableSince,
      targetPrice: incomingLast.isAfter(localLast)
          ? incomingP.targetPrice
          : localP.targetPrice,
      targetCurrency: incomingLast.isAfter(localLast)
          ? incomingP.targetCurrency
          : localP.targetCurrency,
      metSince: incomingLast.isAfter(localLast)
          ? incomingP.metSince
          : localP.metSince,
    );
    products[merged.id] = merged;
  }

  // ── Transactions: unión por id.
  final transactions = <String, Transaction>{};
  for (final t in local.transactions) {
    transactions[t.id] = t;
  }
  int addedTransactions = 0;
  for (final t in incoming.transactions) {
    if (!transactions.containsKey(t.id) && t.id.isNotEmpty) {
      if (transactions.length < kMaxPerList) {
        transactions[t.id] = t;
        addedTransactions++;
      }
    }
  }

  // ── Purchases: unión por id.
  final purchases = <String, Purchase>{};
  for (final p in local.purchases) {
    purchases[p.id] = p;
  }
  int addedPurchases = 0;
  for (final p in incoming.purchases) {
    if (!purchases.containsKey(p.id) && p.id.isNotEmpty) {
      if (purchases.length < kMaxPerList) {
        purchases[p.id] = p;
        addedPurchases++;
      }
    }
  }

  // ── Templates: unión por id.
  final templates = <String, ShoppingTemplate>{};
  for (final t in local.templates) {
    templates[t.id] = t;
  }
  int addedTemplates = 0;
  for (final t in incoming.templates) {
    if (!templates.containsKey(t.id) && t.id.isNotEmpty) {
      if (templates.length < kMaxTemplates) {
        templates[t.id] = t;
        addedTemplates++;
      }
    }
  }

  // ── Stores: unión case-insensitive.
  final seen = <String>{};
  final stores = <String>[];
  for (final s in [...local.stores, ...incoming.stores]) {
    final key = s.toLowerCase();
    if (seen.add(key)) stores.add(s);
  }
  final addedStores = (stores.length - local.stores.length).clamp(
    0,
    stores.length,
  );

  final merged = AppData(
    version: kDataVersion,
    // merge NO toca board/rateSource/manualRates/converter/settings.
    board: local.board,
    rateSource: local.rateSource,
    manualRates: local.manualRates,
    converter: local.converter,
    settings: local.settings,
    products: products.values.toList(),
    transactions: transactions.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date)),
    purchases: purchases.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date)),
    templates: templates.values.toList(),
    stores: stores,
    // cart/budget: locales (merge no los toca).
    cart: local.cart,
    budget: local.budget,
    basket: local.basket,
  );

  return BackupMergeResult(
    merged,
    MergeCounts(
      products: addedProducts,
      records: addedRecords,
      transactions: addedTransactions,
      purchases: addedPurchases,
      templates: addedTemplates,
      stores: addedStores,
    ),
  );
}

/// Import con 2 modos:
/// · replace: conserva el `board` vivo y sanea rateSource/settings.
/// · merge: fusiona por id y no toca cart/budget/board/settings.
typedef BackupResult = ({bool ok, String? error, Map<String, int>? counts});

BackupResult importBackup(AppData local, String raw, {required bool merge}) {
  dynamic decoded;
  try {
    decoded = const JsonDecoder().convert(raw);
  } catch (_) {
    return (ok: false, error: 'JSON inválido', counts: null);
  }
  if (decoded is! Map) {
    return (ok: false, error: 'Estructura no válida', counts: null);
  }
  final map = Map<String, dynamic>.from(decoded);
  final dataRaw = map['data'];
  if (dataRaw is! Map) {
    return (ok: false, error: 'Estructura no válida', counts: null);
  }
  final incoming = AppData.fromJson(Map<String, dynamic>.from(dataRaw));
  // Guard duro del web: si no trae products[] no es un backup.
  if ((dataRaw['products'] as List?) == null) {
    return (ok: false, error: 'Estructura no válida', counts: null);
  }

  if (merge) {
    final r = mergeBackupData(local, incoming);
    return (ok: true, error: null, counts: r.counts.toMap());
  }

  // replace: conserva board vivo + sanea rateSource (solo ids vivos).
  final rateSource = <String, String>{
    for (final e in incoming.rateSource.entries)
      if (RateSource.of(e.value) != null) e.key: e.value,
  };
  final replaced = AppData(
    version: kDataVersion,
    board: local.board, // tablero vivo NUNCA del backup
    rateSource: rateSource,
    manualRates: incoming.manualRates,
    converter: incoming.converter,
    products: incoming.products,
    transactions: incoming.transactions,
    cart: incoming.cart,
    purchases: incoming.purchases,
    budget: incoming.budget,
    basket: incoming.basket,
    stores: incoming.stores,
    templates: incoming.templates,
    settings: incoming.settings,
  );
  assert(replaced.version == kDataVersion);
  return (
    ok: true,
    error: null,
    counts: {
      'products': incoming.products.length,
      'records': incoming.products.fold<int>(
        0,
        (acc, p) => acc + p.records.length,
      ),
      'transactions': incoming.transactions.length,
      'purchases': incoming.purchases.length,
      'templates': incoming.templates.length,
      'stores': incoming.stores.length,
    },
  );
}
