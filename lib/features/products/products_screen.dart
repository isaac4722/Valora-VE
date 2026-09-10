/// ─── Productos · libro de precios (§9.4 · MODULE=finance como la PWA) ──────
/// 21 semillas CATALOG_VE (solo si vacío) · search sin acentos · chips de
/// categoría · filtro disponibilidad/meta · paginación 20 · cards con precio
/// vigente, variación y sparkline · CRUD completo + records · metas
/// (TARGET_EPS + metSince es-VE) · CSV ⇄ · escáner prefill.
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
import '../scanner/scanner_screen.dart';
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

  /// Escanea un código: si el producto ya existe abre su ficha; si no,
  /// abre el alta con el código prellenado. «A mano» pide el código en
  /// un diálogo (mismo camino que una lectura).
  Future<void> _scanCode() async {
    final store = context.read<AppStore>();
    var code = await ScannerScreen.scan(context);
    if (!mounted) return;
    if (code == '__manual__') {
      final ctrl = TextEditingController();
      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Código a mano'),
          content: TextField(
            controller: ctrl,
            autofocus: true,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(hintText: 'Código de barras'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buscar')),
          ],
        ),
      );
      if (ok != true) return;
      code = ctrl.text.trim();
    }
    if (code == null || code.isEmpty || !mounted) return;
    final scanned = code; // final local: promoción de tipo dentro de closures

    final found = store.products.where((p) => p.barcode == scanned).toList();
    if (found.isNotEmpty) {
      // Producto(es) registrados con ese código → al primero.
      setState(() {
        _query = scanned;
        _searchCtrl.text = scanned;
        _page = 0;
      });
      _showProductDialog(context, store, found.first);
      return;
    }
    // Sin registro: alta nueva con el código ya lleno.
    setState(() {
      _query = scanned;
      _searchCtrl.text = scanned;
      _page = 0;
    });
    _showProductDialog(context, store, null, initialBarcode: scanned);
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
        onPressed: () => _showProductDialog(context, store, null),
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
              onAction: () => _showProductDialog(context, store, null),
            ),
          ] else ...[
            const SizedBox(height: 8),
            for (final p in pageItems)
              _ProductCard(
                product: p,
                onTap: () => _showProductDialog(context, store, p),
                onAddCart: () => _addToCart(context, store, p),
              ),
            if (pages > 1)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                  IconButton(
                      onPressed: _page > 0 ? () => setState(() => _page--) : null,
                      icon: const Icon(Icons.chevron_left)),
                  Text('Página ${_page + 1} de $pages · ${list.length} productos',
                      style: const TextStyle(fontSize: 12)),
                  IconButton(
                      onPressed: _page < pages - 1 ? () => setState(() => _page++) : null,
                      icon: const Icon(Icons.chevron_right)),
                ]),
              ),
          ],
        ],
      ),
    );
  }

  void _addToCart(BuildContext context, AppStore store, Product p) {
    final last = p.latestRecord;
    if (last == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Regístrale precio primero'), behavior: SnackBarBehavior.floating));
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
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text('${p.name} agregado a la lista'), behavior: SnackBarBehavior.floating));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('El CSV no trae filas de datos '
                '(se espera encabezado + filas, ej.: Codigo,Nombre,Fecha)'),
            behavior: SnackBarBehavior.floating));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Falta la columna «Nombre» en el CSV'),
            behavior: SnackBarBehavior.floating));
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
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Sin filas válidas: la columna «Nombre» no trae datos'),
            behavior: SnackBarBehavior.floating));
      }
      return;
    }
    final added = store.importProducts(valid);
    final dedupe = valid.length - added;
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(added > 0
            ? (dedupe > 0 ? '$added importados · Ya están en libro: $dedupe' : '$added importados')
            : 'Ya están en libro: $dedupe'),
        behavior: SnackBarBehavior.floating));
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
                    '${product.barcode != null ? ' · ${product.barcode}' : ''}',
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
                Sparkline(records: product.records, up: variation > 0),
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

/// Sparkline de precios (64×21, canvas minimal).
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.records, required this.up});

  final List<PriceRecord> records;
  final bool up;

  @override
  Widget build(BuildContext context) {
    final c = up ? VeColors.of(context).neg : VeColors.of(context).pos;
    if (records.length < 2) return const SizedBox(width: 64, height: 21);
    return CustomPaint(
      size: const Size(64, 21),
      painter: _SparkPainter(
        values: records.map((r) => r.price).toList(),
        color: c,
      ),
    );
  }
}

class _SparkPainter extends CustomPainter {
  const _SparkPainter({required this.values, required this.color});
  final List<double> values;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    if (values.length < 2) return;
    final minV = values.reduce((a, b) => a < b ? a : b);
    final maxV = values.reduce((a, b) => a > b ? a : b);
    final range = (maxV - minV).clamp(0.0001, double.infinity);
    final path = Path();
    for (var i = 0; i < values.length; i++) {
      final x = i / (values.length - 1) * size.width;
      final y = size.height - ((values[i] - minV) / range) * size.height;
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SparkPainter old) => old.values != values;
}

/// Edita un registro existente: precio nuevo (>0 validado) + tienda opcional
/// → store.updateRecord.
Future<void> _editRecordDialog(
    BuildContext context, AppStore store, String productId, PriceRecord r) async {
  final priceCtrl =
      TextEditingController(text: fmtMoney(r.originalPrice, CurrencyX.from(r.currency)));
  final storeCtrl = TextEditingController(text: r.store ?? '');
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Editar registro'),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        TextField(
          controller: priceCtrl,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(
            hintText: 'Precio',
            labelText: 'Precio (${r.currency})',
          ),
        ),
        const SizedBox(height: 8),
        TextField(
          controller: storeCtrl,
          decoration: const InputDecoration(hintText: 'Tienda (opcional)'),
        ),
      ]),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
      ],
    ),
  );
  if (ok != true) return;
  final price = parseLocaleNum(priceCtrl.text);
  if (price == null || price <= 0) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Precio inválido: debe ser mayor que 0'),
          behavior: SnackBarBehavior.floating));
    }
    return;
  }
  final s = storeCtrl.text.trim();
  store.updateRecord(productId, r.id,
      newUSD: price, newOriginal: price, store: s.isEmpty ? null : s);
}

/// Elimina un registro con confirmación → store.deleteRecord.
Future<void> _confirmDeleteRecord(
    BuildContext context, AppStore store, String productId, PriceRecord r) async {
  final ok = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Eliminar registro'),
      content: Text(
          'Se quita el registro del ${fmtDate(r.date)} (${fmtUSD(r.price)}). El producto se conserva.'),
      actions: [
        TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: VeColors.of(context).neg),
          onPressed: () => Navigator.pop(ctx, true),
          child: const Text('Eliminar'),
        ),
      ],
    ),
  );
  if (ok == true) store.deleteRecord(productId, r.id);
}

/// Diálogo de producto: ficha + CRUD + records + meta + disponibilidad.
/// [initialBarcode] prellena el código (alta desde el escáner).
Future<void> _showProductDialog(BuildContext context, AppStore store, Product? existing,
    {String? initialBarcode}) async {
  final nameCtrl = TextEditingController(text: existing?.name ?? '');
  final barcodeCtrl = TextEditingController(text: existing?.barcode ?? initialBarcode ?? '');
  final priceCtrl = TextEditingController();
  final storeCtrl = TextEditingController();
  final targetCtrl = TextEditingController(text: existing?.targetPrice == null ? '' : '${existing!.targetPrice}');
  var category = existing?.category ?? ProductCategory.otros;
  var presentation = existing?.presentation ?? Presentation.unit;
  final isEdit = existing != null;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        child: DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.75,
          maxChildSize: 0.95,
          builder: (ctx, scroll) => ListView(
            controller: scroll,
            padding: const EdgeInsets.all(20),
            children: [
              Text(isEdit ? existing.name : 'Nuevo producto',
                  style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)),
              const SizedBox(height: 14),
              TextField(controller: nameCtrl, decoration: const InputDecoration(hintText: 'Nombre')),
              const SizedBox(height: 8),
              TextField(controller: barcodeCtrl, decoration: const InputDecoration(hintText: 'Código de barras (opcional)')),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final c in ProductCategory.values)
                  ChipTag(c.label, selected: category == c, onTap: () => setSheet(() => category = c)),
              ]),
              const SizedBox(height: 8),
              Wrap(spacing: 6, children: [
                for (final p in Presentation.values)
                  ChipTag(p.label, selected: presentation == p, onTap: () => setSheet(() => presentation = p)),
              ]),
              if (isEdit) ...[
                SectionTitle('Registrar precio'),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'Precio que pagaste'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: storeCtrl,
                      decoration: const InputDecoration(hintText: 'Tienda'),
                    ),
                  ),
                ]),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final raw = parseLocaleNum(priceCtrl.text);
                      if (raw == null || raw <= 0) return;
                      final sCtx = store.contextOf(module: RateModule.finance);
                      final usdRate = sCtx.unitsPerUSD(Currency.usd) ?? 1;
                      store.addRecord(existing.id, PriceRecord(
                        id: '',
                        price: raw, // USD directo (moneda de registro USD)
                        originalPrice: raw,
                        currency: 'USD',
                        quantity: 1,
                        store: storeCtrl.text.trim().isEmpty ? null : storeCtrl.text.trim(),
                        rate: usdRate,
                        sourceId: sCtx.sel(Currency.ves),
                        date: DateTime.now(),
                      ));
                      // Meta de precio: aviso si quedó POR DEBAJO (TARGET_EPS 0.005).
                      final target = existing.targetPrice;
                      if (target != null && target > 0 && raw < target * (1 - an.kTargetEps)) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('¡bajo tu meta!'), behavior: SnackBarBehavior.floating));
                      }
                      Navigator.pop(ctx);
                    },
                    child: const Text('Guardar precio'),
                  ),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: targetCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                      hintText: existing.targetPrice == null ? 'Meta de precio USD (opcional)' : 'Cambiar meta USD'),
                ),
                const SizedBox(height: 6),
                Row(children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        final t = parseLocaleNum(targetCtrl.text);
                        store.setTarget(existing.id, t);
                        Navigator.pop(ctx);
                      },
                      child: const Text('Fijar meta'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  OutlinedButton(
                    onPressed: () {
                      store.setUnavailable(existing.id, !existing.isUnavailable);
                      Navigator.pop(ctx);
                    },
                    child: Text(existing.isUnavailable ? 'Marcar disponible' : 'No disponible'),
                  ),
                ]),
                // Historial de precios VIVO: se re-dibuja al editar/eliminar
                // registros (escucha al store). Tap → editar · borrar → confirm.
                ListenableBuilder(
                  listenable: store,
                  builder: (ctx, _) {
                    final fresh =
                        store.products.where((p) => p.id == existing.id).firstOrNull ?? existing;
                    if (fresh.records.isEmpty) return const SizedBox.shrink();
                    return Column(children: [
                      SectionTitle('Historial de precios'),
                      for (final r in fresh.records.reversed.take(10))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 3),
                          child: Row(children: [
                            Expanded(
                              child: LedgerRow(
                                label: '${fmtDate(r.date)} · ${r.store ?? 'Sin tienda'}',
                                value: fmtUSD(r.price),
                                onTap: () => _editRecordDialog(ctx, store, fresh.id, r),
                              ),
                            ),
                            IconButton(
                              icon: Icon(Icons.delete_outline,
                                  size: 16, color: VeColors.of(ctx).neg),
                              tooltip: 'Eliminar registro',
                              onPressed: () => _confirmDeleteRecord(ctx, store, fresh.id, r),
                            ),
                          ]),
                        ),
                    ]);
                  },
                ),
                const SizedBox(height: 14),
                Row(children: [
                  Expanded(
                    child: FilledButton(
                      onPressed: () {
                        final name = nameCtrl.text.trim();
                        if (name.isEmpty) return;
                        final t = parseLocaleNum(targetCtrl.text);
                        store.updateProduct(existing.id, Product(
                          id: existing.id,
                          name: name,
                          barcode: barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                          category: category,
                          presentation: presentation,
                          size: existing.size,
                          sizeUnit: existing.sizeUnit,
                          createdAt: existing.createdAt,
                          records: existing.records,
                          targetPrice: t,
                        ));
                        Navigator.pop(ctx);
                      },
                      child: const Text('Guardar cambios'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton(
                    icon: Icon(Icons.delete_outline, color: VeColors.of(context).neg),
                    onPressed: () {
                      store.deleteProduct(existing.id);
                      Navigator.pop(ctx);
                    },
                  ),
                ]),
              ] else
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () {
                      final name = nameCtrl.text.trim();
                      if (name.isEmpty) return;
                      store.addProduct(
                        Product(
                          id: '',
                          name: name,
                          barcode: barcodeCtrl.text.trim().isEmpty ? null : barcodeCtrl.text.trim(),
                          category: category,
                          presentation: presentation,
                          size: 1,
                          createdAt: DateTime.now(),
                          records: const [],
                        ),
                        null,
                      );
                      Navigator.pop(ctx);
                    },
                    child: const Text('Crear producto'),
                  ),
                ),
            ],
          ),
        ),
      ),
    ),
  );
}
