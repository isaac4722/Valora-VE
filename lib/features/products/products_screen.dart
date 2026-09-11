/// ─── Productos · libro de precios (§9.4 · MODULE=finance como la PWA) ──────
/// 21 semillas CATALOG_VE (solo si vacío) · search sin acentos · chips de
/// categoría · filtro disponibilidad/meta · paginación 20 · cards con precio
/// vigente, variación y sparkline · ficha FULL-HEIGHT en product_sheet.dart
/// (detalle + gráfica + historial + ajustes) · alta nueva con escáner y
/// primer precio en un paso · CSV ⇄ · iconos: importar Icons.upload_file ·
/// exportar/compartir Icons.ios_share · escaneo Icons.qr_code_scanner.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';

import '../../core/analytics.dart' as an;
import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import 'product_sheet.dart';
import '../../widgets/ui.dart';
import '../../services/sharing.dart';

const int kPageSize = 20;

/// Fecha tolerante del CSV: ISO ('2026-02-02'), '02/02/2026' o el formato
/// propio de export '02-feb-2026'. Null honesto si no parsea.
DateTime? parseCsvDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;
  final m = RegExp(r'^(\d{1,2})[-/](\d{1,2}|[a-záéíúüñ]{3,})[-/](\d{2,4})$', caseSensitive: false)
      .firstMatch(s);
  if (m == null) return null;
  final day = int.tryParse(m.group(1)!);
  var month = int.tryParse(m.group(2)!);
  if (month == null) {
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    final t = m.group(2)!.toLowerCase();
    final idx = meses.indexWhere((mm) => t.startsWith(mm));
    if (idx < 0) return null;
    month = idx + 1;
  }
  var year = int.tryParse(m.group(3)!);
  if (year == null) return null;
  if (year < 100) year += 2000;
  if (day == null || day < 1 || day > 31 || month < 1 || month > 12) return null;
  return DateTime(year, month, day);
}

class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key});

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _query = '';
  final _searchCtrl = TextEditingController();
  ProductCategory? _cat;
  bool _onlyUnavailable = false;
  bool _onlyTarget = false;
  int _page = 0;

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Escanea un código (mecanismo existente + fallback manual): si el
  /// producto ya existe abre su FICHA (product_sheet); si no, abre el ALTA
  /// con el código prellenado y primer precio en un paso.
  Future<void> _scanCode() async {
    final store = context.read<AppStore>();
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;

    final found = store.products.where((p) => p.barcode == code).toList();
    if (found.isNotEmpty) {
      // Producto(s) registrados con ese código → a la ficha del primero.
      setState(() {
        _query = code;
        _searchCtrl.text = code;
        _page = 0;
      });
      showProductSheet(context, found.first);
      return;
    }
    // Sin registro: alta nueva con el código ya lleno.
    setState(() {
      _query = code;
      _searchCtrl.text = code;
      _page = 0;
    });
    showNewProductSheet(context, initialBarcode: code);
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final store = context.read<AppStore>();
      if (store.products.isEmpty && store.data.stores.isEmpty) {
        // Semilla canasta: 21 productos si el libro está vacío (§13 Fase A).
        _seedCatalog(store);
      }
    });
  }

  /// Semilla canasta: 21 productos del catálogo (solo si el libro está vacío).
  /// Preserva categoría/presentación/tamaño del CATALOG_VE (§13 Fase A).
  void _seedCatalog(AppStore store) {
    for (final seed in kCatalogVE) {
      store.addProduct(
        Product(
          id: '',
          name: seed.name,
          barcode: seed.barcode,
          category: seed.category,
          presentation: seed.presentation,
          size: seed.size,
          sizeUnit: seed.sizeUnit,
          createdAt: DateTime.now(),
          records: const [],
        ),
        null,
      );
    }
  }

  List<Product> _filtered(AppStore store) {
    final q = fold(_query.trim().toLowerCase());
    var list = store.products;
    if (q.isNotEmpty) {
      list = list.where((p) => fold(p.name.toLowerCase()).contains(q) || (p.barcode ?? '').contains(_query)).toList();
    }
    if (_cat != null) list = list.where((p) => p.category == _cat).toList();
    if (_onlyUnavailable) list = list.where((p) => p.isUnavailable).toList();
    if (_onlyTarget) list = list.where((p) => p.targetPrice != null).toList();
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final list = _filtered(store);
    final pages = (list.length / kPageSize).ceil().clamp(1, 9999);
    final pageItems = list.skip(_page * kPageSize).take(kPageSize).toList();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showNewProductSheet(context),
        icon: const Icon(Icons.add, size: 18),
        label: const Text('Producto'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
        children: [
          PageHeader('Productos', hint: 'Tu libro de precios: qué pagas, dónde y cuándo',
            action: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.upload_file, size: 19),
                tooltip: 'Importar CSV',
                onPressed: () => _importCsv(context, store),
              ),
              IconButton(
                icon: const Icon(Icons.ios_share, size: 19),
                tooltip: 'Exportar CSV',
                onPressed: () => _exportCsv(context, store),
              ),
            ])),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _searchCtrl,
                onChanged: (v) {
                  setState(() {
                    _query = v;
                    _page = 0;
                  });
                },
                decoration: const InputDecoration(
                  hintText: 'Buscar por nombre o código de barras',
                  prefixIcon: Icon(Icons.search, size: 18),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filledTonal(
              onPressed: _scanCode,
              tooltip: 'Escanear código de barras',
              icon: const Icon(Icons.qr_code_scanner, size: 20),
            ),
          ]),
          const SizedBox(height: 10),
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChipTag('Todas', selected: _cat == null, onTap: () => setState(() { _cat = null; _page = 0; })),
            for (final c in ProductCategory.values)
              ChipTag(c.label, selected: _cat == c, onTap: () => setState(() { _cat = c; _page = 0; })),
            const SizedBox(width: 4),
            ChipTag('No disponibles', selected: _onlyUnavailable, onTap: () => setState(() { _onlyUnavailable = !_onlyUnavailable; _page = 0; })),
            ChipTag('Con meta', selected: _onlyTarget, onTap: () => setState(() { _onlyTarget = !_onlyTarget; _page = 0; })),
          ]),
          if (list.isEmpty) ...[
            const SizedBox(height: 14),
            EmptyState(
              'Nada por aquí',
              icon: Icons.inventory_2_outlined,
              hint: _query.isEmpty
                  ? 'Agrega productos con el botón de abajo o importa un CSV con «Nombre» y «Código».'
                  : 'Sin resultados para «$_query». Prueba con otra palabra o revisa los filtros.',
              actionLabel: 'Agregar producto',
              onAction: () => showNewProductSheet(context),
            ),
          ] else ...[
            const SizedBox(height: 8),
            for (final p in pageItems)
              _ProductCard(
                product: p,
                onTap: () => showProductSheet(context, p),
                onAddCart: () => _addToCart(context, store, p),
              ),
            if (pages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('${list.length} productos',
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant)),
              ),
            Paginator(
              page: _page + 1,
              totalPages: pages,
              onPage: (p) => setState(() => _page = p - 1),
            ),
          ],
        ],
      ),
    );
  }

  void _addToCart(BuildContext context, AppStore store, Product p) {
    final last = p.latestRecord;
    if (last == null) {
      showToast(context, 'Regístrale precio primero', kind: ToastKind.warn);
      return;
    }
    store.addToCart(CartItem(
      id: '',
      productId: p.id,
      name: p.name,
      quantity: 1,
      price: last.originalPrice,
      currency: last.currency,
      barcode: p.barcode,
    ));
    showToast(context, '${p.name} agregado a la lista', kind: ToastKind.ok);
  }

  /// Importa productos desde CSV (columnas «Codigo,Nombre,Fecha»; delimitador
  /// y comillas los maneja parseCSV). Dedupe por código o nombre dentro de
  /// store.importProducts → SnackBar honesta con importados vs duplicados.
  Future<void> _importCsv(BuildContext context, AppStore store) async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['csv', 'txt']);
    if (picked.isEmpty) return;
    final raw = await picked.single.readAsBytes().then((b) => utf8.decode(b, allowMalformed: true));
    final rows = parseCSV(raw);
    if (rows.length < 2) {
      if (context.mounted) {
        showToast(context, 'El CSV no trae filas de datos '
            '(se espera encabezado + filas, ej.: Codigo,Nombre,Fecha)', kind: ToastKind.warn);
      }
      return;
    }
    final header = rows.first.map((c) => c.trim().toLowerCase()).toList();
    int findCol(List<String> keys) {
      for (final k in keys) {
        final i = header.indexWhere((h) => h.contains(k));
        if (i >= 0) return i;
      }
      return -1;
    }
    final iName = findCol(['nombre', 'producto', 'name']);
    if (iName < 0) {
      if (context.mounted) {
        showToast(context, 'Falta la columna «Nombre» en el CSV', kind: ToastKind.warn);
      }
      return;
    }
    final iCode = findCol(['codigo']);
    final iDate = findCol(['fecha', 'date']);
    final valid = <({String name, String? barcode, DateTime? date})>[];
    for (final row in rows.skip(1)) {
      String cell(int i) => (i >= 0 && i < row.length) ? row[i].trim() : '';
      final name = cell(iName);
      if (name.isEmpty) continue;
      final code = cell(iCode);
      valid.add((
        name: name,
        barcode: code.isEmpty ? null : code,
        date: parseCsvDate(cell(iDate)),
      ));
    }
    if (valid.isEmpty) {
      if (context.mounted) {
        showToast(context, 'Sin filas válidas: la columna «Nombre» no trae datos',
            kind: ToastKind.warn);
      }
      return;
    }
    final added = store.importProducts(valid);
    final dedupe = valid.length - added;
    if (!context.mounted) return;
    showToast(context,
        added > 0
            ? (dedupe > 0 ? '$added importados · Ya están en libro: $dedupe' : '$added importados')
            : 'Ya están en libro: $dedupe',
        kind: added > 0 ? ToastKind.ok : ToastKind.info);
  }

  void _exportCsv(BuildContext context, AppStore store) {
    final rows = <List<String>>[
      ['Producto', 'Codigo', 'Categoria', 'PrecioUSD', 'PrecioOriginal', 'Moneda', 'Tienda', 'Tasa', 'Fuente', 'Fecha'],
    ];
    for (final p in store.products) {
      for (final r in p.records) {
        rows.add([p.name, p.barcode ?? '', p.category.label,
          r.price.toStringAsFixed(4), r.originalPrice.toStringAsFixed(2),
          r.currency, r.store ?? '', r.rate.toStringAsFixed(4), r.sourceId, fmtDate(r.date)]);
      }
    }
    final text = toCSV(rows);
    exportTextFile(context, 'productos-valorave.csv', text);
  }
}

/// Exporta texto a file_picker/share (CSV/JSON).
void exportTextFile(BuildContext context, String name, String text) {
  showShareFile(context, name, text);
}

class _ProductCard extends StatelessWidget {
  const _ProductCard({required this.product, required this.onTap, required this.onAddCart});

  final Product product;
  final VoidCallback onTap;
  final VoidCallback onAddCart;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final last = product.latestRecord;
    final variation = an.totalVariation(product.records);
    final target = an.computeTargetInfo(product);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              CategoryIcon(cat: product.category, size: 32),
              const SizedBox(width: 10),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(product.name, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
                  Text(
                    '${presentationLabel(product)}'
                    '${(product.barcode ?? '').trim().isNotEmpty ? ' · ${product.barcode}' : ''}',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
                  ),
                ]),
              ),
              if (product.isUnavailable)
                Stamp('no disponible', color: VeColors.of(context).neg)
              else if (target.met)
                Stamp('¡bajo meta!', color: VeColors.of(context).pos),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              if (last != null)
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(fmtUSD(last.price), style: VeText.displayNum(17, color: scheme.onSurface)),
                  Text(
                    '${last.store ?? 'Sin tienda'} · ${fmtDate(last.date)}'
                    '${last.currency != 'USD' ? ' · pagó ${fmtMoney(last.originalPrice, CurrencyX.from(last.currency))}' : ''}',
                    style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
                  ),
                ])
              else
                Text('Sin precio aún', style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
              const Spacer(),
              if (product.records.length >= 2) ...[
                // Sparkline compartida del sistema (dp6): misma semántica
                // visual (sube = neg, baja = pos) sin duplicado local.
                Sparkline(
                  values: product.records.map((r) => r.price).toList(),
                  width: 64,
                  height: 21,
                ),
                const SizedBox(width: 10),
                TrendBadge(variation, dense: true),
              ],
              if (product.targetPrice != null) ...[
                const SizedBox(width: 10),
                Tooltip(
                  message: 'Meta: ${fmtUSD(product.targetPrice!)}',
                  child: Icon(Icons.adjust, size: 15, color: scheme.primary),
                ),
              ],
            ]),
          ]),
        ),
      ),
    );
  }
}


