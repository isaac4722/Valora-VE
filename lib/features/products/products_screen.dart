/// ─── Productos · libro de precios (§9.4 · TASK-34 lenguaje Ve) ──────────────
/// 21 semillas CATALOG_VE (solo si vacío) · search sin acentos · chips de
/// categoría (activo = tinta) · filtro disponibilidad/meta · paginación 20 ·
/// filas de 2 líneas (nombre + «N tiendas · última hace X») con precio
/// tabular, VeSparkline (tono por tendencia) y VeBadge de estado · ficha
/// completa en product_sheet.dart (showVeSheet wide) · alta nueva con
/// escáner y primer precio en un paso · CSV ⇄ · barra inferior «Agregar
/// producto».
///
/// TASK-34 (p8): presentación del prototipo web (Products.tsx) sobre TODA la
/// lógica previa — semillas, filtros, paginación, exportación y ficha
/// intactas.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../data/store.dart';
import 'product_sheet.dart';
import '../../widgets/app_tips.dart';
import '../../widgets/app_tour.dart' show TourKeys;
import '../../widgets/ui.dart';
import '../../widgets/export_sheet.dart';

const int kPageSize = 20;

/// Fecha tolerante del CSV: ISO ('2026-02-02'), '02/02/2026' o el formato
/// propio de export '02-feb-2026'. Null honesto si no parsea.
DateTime? parseCsvDate(String raw) {
  final s = raw.trim();
  if (s.isEmpty) return null;
  final iso = DateTime.tryParse(s);
  if (iso != null) return iso;
  final m = RegExp(
    r'^(\d{1,2})[-/](\d{1,2}|[a-záéíúüñ]{3,})[-/](\d{2,4})$',
    caseSensitive: false,
  ).firstMatch(s);
  if (m == null) return null;
  final day = int.tryParse(m.group(1)!);
  var month = int.tryParse(m.group(2)!);
  if (month == null) {
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final t = m.group(2)!.toLowerCase();
    final idx = meses.indexWhere((mm) => t.startsWith(mm));
    if (idx < 0) return null;
    month = idx + 1;
  }
  var year = int.tryParse(m.group(3)!);
  if (year == null) return null;
  if (year < 100) year += 2000;
  if (day == null || day < 1 || day > 31 || month < 1 || month > 12) {
    return null;
  }
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
      list = list
          .where(
            (p) =>
                fold(p.name.toLowerCase()).contains(q) ||
                (p.barcode ?? '').contains(_query),
          )
          .toList();
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
    // Clamp de página: al borrar productos desde la ficha la lista se
    // encoge y _page podía quedar fuera de rango («Página 3 de 2» con
    // página vacía). Se corrige en build antes de paginar.
    if (_page >= pages) {
      _page = pages - 1;
    }
    final pageItems = list.skip(_page * kPageSize).take(kPageSize).toList();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: Stack(
        children: [
          ListView(
            // Padding inferior extra para no tapar el contenido con la
            // VeStickyBar («Agregar producto»).
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 104),
            children: [
              VeTitle(
                sub: Text('${store.products.length} en tu libro'),
                right: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    VeIconBtn(
                      icon: LucideIcons.upload,
                      onTap: () => _importCsv(context, store),
                      label: 'Importar CSV',
                    ),
                    const SizedBox(width: 8),
                    VeBtn(
                      size: VeBtnSize.sm,
                      icon: LucideIcons.download,
                      onPressed: () => _exportCsv(context, store),
                      child: const Text('CSV'),
                    ),
                  ],
                ),
                child: Text('Productos'),
              ),
              const TipsTrigger(scope: 'productos'),
              // Buscador + escáner (ancla del tour v17.8).
              KeyedSubtree(
                key: TourKeys.prodBusqueda,
                child: Row(
                  children: [
                    Expanded(
                      child: VeInput(
                        controller: _searchCtrl,
                        placeholder: 'Buscar producto…',
                        onChanged: (v) {
                          setState(() {
                            _query = v;
                            _page = 0;
                          });
                        },
                        semantic: 'Buscar producto',
                      ),
                    ),
                    const SizedBox(width: 8),
                    VeIconBtn(
                      icon: LucideIcons.scanBarcode,
                      onTap: _scanCode,
                      label: 'Escanear código de barras',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // Chips de categoría (activo = tinta invertida).
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  VeChip(
                    active: _cat == null,
                    onTap: () => setState(() {
                      _cat = null;
                      _page = 0;
                    }),
                    child: const Text('Todas'),
                  ),
                  for (final c in ProductCategory.values)
                    VeChip(
                      active: _cat == c,
                      onTap: () => setState(() {
                        _cat = c;
                        _page = 0;
                      }),
                      child: Text(c.label),
                    ),
                  VeChip(
                    active: _onlyUnavailable,
                    onTap: () => setState(() {
                      _onlyUnavailable = !_onlyUnavailable;
                      _page = 0;
                    }),
                    child: const Text('No disponibles'),
                  ),
                  VeChip(
                    active: _onlyTarget,
                    onTap: () => setState(() {
                      _onlyTarget = !_onlyTarget;
                      _page = 0;
                    }),
                    child: const Text('Con meta'),
                  ),
                ],
              ),
              if (list.isEmpty) ...[
                const SizedBox(height: 14),
                VeEmpty(
                  icon: LucideIcons.scanBarcode,
                  title: 'Sin productos',
                  sub: _query.isEmpty
                      ? 'Agrega uno nuevo o importa un CSV con «Nombre» y «Código».'
                      : 'Sin resultados para «$_query». Prueba con otra palabra o revisa los filtros.',
                  action: VeBtn(
                    size: VeBtnSize.sm,
                    icon: LucideIcons.plus,
                    onPressed: () => showNewProductSheet(context),
                    child: const Text('Agregar producto'),
                  ),
                ),
              ] else ...[
                const SizedBox(height: 12),
                VeGroup(
                  children: [
                    for (final p in pageItems)
                      _ProductRow(
                        product: p,
                        onTap: () => showProductSheet(context, p),
                      ),
                  ],
                ),
                if (pages > 1)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      '${list.length} ${list.length == 1 ? 'producto' : 'productos'}',
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                Paginator(
                  page: _page + 1,
                  totalPages: pages,
                  onPage: (p) => setState(() => _page = p - 1),
                ),
                const SizedBox(height: 6),
                Text(
                  'Toca un producto para ver su ficha: precio por tienda, disponibilidad y meta de precio objetivo.',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
          // Barra inferior del prototipo: alta de producto siempre a mano.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VeStickyBar(
              children: [
                VeBtn(
                  variant: VeBtnVariant.primary,
                  size: VeBtnSize.lg,
                  expands: true,
                  icon: LucideIcons.plus,
                  onPressed: () => showNewProductSheet(context),
                  child: const Text('Agregar producto'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Importa productos desde CSV (columnas «Codigo,Nombre,Fecha»; delimitador
  /// y comillas los maneja parseCSV). Dedupe por código o nombre dentro de
  /// store.importProducts → SnackBar honesta con importados vs duplicados.
  Future<void> _importCsv(BuildContext context, AppStore store) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['csv', 'txt'],
    );
    if (picked.isEmpty) return;
    final raw = await picked.single.readAsBytes().then(
      (b) => utf8.decode(b, allowMalformed: true),
    );
    final rows = parseCSV(raw);
    if (rows.length < 2) {
      if (context.mounted) {
        showToast(
          context,
          'El CSV no trae filas de datos '
          '(se espera encabezado + filas, ej.: Codigo,Nombre,Fecha)',
          kind: ToastKind.warn,
        );
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
        showToast(
          context,
          'Falta la columna «Nombre» en el CSV',
          kind: ToastKind.warn,
        );
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
        showToast(
          context,
          'Sin filas válidas: la columna «Nombre» no trae datos',
          kind: ToastKind.warn,
        );
      }
      return;
    }
    final added = store.importProducts(valid);
    final dedupe = valid.length - added;
    if (!context.mounted) return;
    showToast(
      context,
      added > 0
          ? (dedupe > 0
                ? '$added importados · Ya están en libro: $dedupe'
                : '$added importados')
          : 'Ya están en libro: $dedupe',
      kind: added > 0 ? ToastKind.ok : ToastKind.info,
    );
  }

  Future<void> _exportCsv(BuildContext context, AppStore store) async {
    final rows = <List<String>>[
      [
        'Producto',
        'Codigo',
        'Categoria',
        'PrecioUSD',
        'PrecioOriginal',
        'Moneda',
        'Tienda',
        'Tasa',
        'Fuente',
        'Fecha',
      ],
    ];
    for (final p in store.products) {
      for (final r in p.records) {
        rows.add([
          p.name,
          p.barcode ?? '',
          p.category.label,
          r.price.toStringAsFixed(4),
          r.originalPrice.toStringAsFixed(2),
          r.currency,
          r.store ?? '',
          r.rate.toStringAsFixed(4),
          r.sourceId,
          fmtDate(r.date),
        ]);
      }
    }
    await showExportSheet(
      context,
      ExportSpec(
        title: 'Productos',
        subtitle: 'El catálogo completo con sus precios',
        formats: [
          csvFormat(
            hint: 'Una fila por registro de precio',
            fileName: 'productos-valorave.csv',
            rows: () => rows,
          ),
        ],
      ),
    );
  }
}

/// ─── Fila de producto (prototipo Products.tsx) ───────────────────────────────
/// Dos líneas: nombre 14 w500 + «N tiendas · última hace X» · precio 16
/// semibold tabular a la derecha · sparkline (tono por tendencia) + VeBadge
/// de estado (Meta OK pos · Sube neg · Baja pos · Estable/Sin dato neutral).
class _ProductRow extends StatelessWidget {
  const _ProductRow({required this.product, required this.onTap});

  final Product product;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final st = productStatus(product);
    final last = product.latestRecord;
    final stores = product.records
        .map((r) => (r.store ?? '').trim())
        .where((s) => s.isNotEmpty)
        .toSet();
    final hasSeries = product.records.length >= 2;
    final sub = last == null
        ? 'Sin precios registrados'
        : '${stores.isEmpty ? 1 : stores.length} '
              '${stores.length <= 1 ? 'tienda' : 'tiendas'} · última ${timeAgo(last.date)}';

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        product.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: scheme.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        sub,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: scheme.mutedForeground,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  last == null ? '—' : fmtUSD(last.price),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    letterSpacing: -0.2,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: last == null
                        ? scheme.mutedForeground
                        : scheme.foreground,
                  ),
                ),
              ],
            ),
            // v21 (GUI superior): sin registros NO hay fila inferior —
            // «Sin precios registrados» + «—» ya lo dicen; el badge «Sin
            // dato» repetía la misma información por triplicado.
            if (last != null) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  if (hasSeries)
                    SizedBox(
                      width: 200,
                      child: VeSparkline(
                        data: product.records.map((r) => r.price).toList(),
                        tone: st.spark,
                        height: 32,
                      ),
                    ),
                  const Spacer(),
                  VeBadge(tone: st.tone, child: Text(st.label)),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}
