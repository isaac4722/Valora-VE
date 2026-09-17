/// ─── Productos · Ficha de producto (§9.4 · enfoque web v15) ────────────────
/// Bottom-sheet FULL-HEIGHT (0.94 · isScrollControlled + useSafeArea): cubre
/// el header de la app con integración limpia. Contenido de la ficha:
///  · Cabecera firma: nombre editable + Stamps de estado (¡bajo meta! verde /
///    meta fijada / sin meta / no disponible) + tienda del último registro.
///  · Cifra vigente protagonista: ReadWindow con displayNum grande + «hace X»
///    + variación % vs registro anterior (tinta pos/neg) + precio por unidad
///    (kg/L/pza) cuando el tamaño lo permite. FittedBox scaleDown.
///  · «Actualizar precio» como acción protagonista: campo + moneda + tienda
///    (opcional), se registra con fecha de hoy → addRecord; banner honesto
///    «¡Bajo tu meta!» si el precio quedó por debajo (TARGET_EPS).
///  · Gráfica «Inflación/deflación del producto»: SfCartesianChart (área USD
///    + precio por kg/L punteado en eje secundario), % acumulado del período,
///    enableTooltip + trackball. Estado vacío honesto («sin datos»).
///  · Historial de registros (LedgerRow): fecha · tienda · precio, editar
///    (updateRecord) y borrar (deleteRecord con confirmación).
///  · Ajustes: código de barras (+ escáner con el mecanismo existente), meta
///    de precio fijar/quitar, tienda del último registro, marcar no
///    disponible y eliminar producto (confirm; cascada de canasta en store).
/// Alta de producto (req. 2): NewProductSheet — nombre + escaneo de código +
/// PRIMER PRECIO (precio+moneda+tamaño opcional) → addProduct con
/// firstRecord en un solo paso. Iconografía: escanear Icons.qr_code_scanner.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart' show DateFormat;
import 'package:provider/provider.dart';
import 'package:syncfusion_flutter_charts/charts.dart';

import '../../core/analytics.dart' as an;
import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../services/alerts.dart';
import '../../services/notifications.dart';
import '../scanner/scanner_screen.dart';
import '../../widgets/ui.dart';

/// Escaneo de código de barras con el mecanismo existente
/// (ScannerScreen.scan) + fallback «__manual__» en diálogo. Devuelve el
/// código final o null si no se obtuvo nada.
Future<String?> scanBarcode(BuildContext context) async {
  var code = await ScannerScreen.scan(context);
  if (!context.mounted) return null;
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
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Buscar'),
          ),
        ],
      ),
    );
    if (ok != true) return null;
    code = ctrl.text.trim();
  }
  if (code == null || code.isEmpty) return null;
  return code;
}

/// Abre la FICHA completa de un producto existente (req. 1). Full-height:
/// isScrollControlled + useSafeArea + 0.94 del alto disponible — el header
/// de la app queda cubierto. LayoutBuilder para respetar también el teclado.
Future<void> showProductSheet(BuildContext context, Product product) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: LayoutBuilder(
        builder: (ctx, cons) => SizedBox(
          height: cons.maxHeight * 0.94,
          child: ProductSheet(productId: product.id),
        ),
      ),
    ),
  );
}

/// Abre el ALTA de producto nuevo (req. 2): nombre + código (con escáner) +
/// primer precio en un paso → addProduct con firstRecord.
Future<void> showNewProductSheet(
  BuildContext context, {
  String? initialBarcode,
}) async {
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    clipBehavior: Clip.antiAlias,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
    ),
    builder: (ctx) => Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
      child: LayoutBuilder(
        builder: (ctx, cons) => SizedBox(
          height: cons.maxHeight * 0.94,
          child: NewProductSheet(initialBarcode: initialBarcode),
        ),
      ),
    ),
  );
}

/// Etiqueta honesta de la tienda de un registro ('' → Sin tienda).
String _storeOf(PriceRecord r) {
  final s = r.store?.trim() ?? '';
  return s.isEmpty ? 'Sin tienda' : s;
}

/// Normaliza el precio que pagó [raw] en [cur] a USD (campo `price` del
/// record) con el contexto del módulo finance. Devuelve también la tasa
/// VES/USD activa para el campo `rate` (contrato de recordPriceBS:
/// price(USD) × rate = Bs). Sin tasa para la divisa → null (la UI avisa).
({double usd, double rate})? normalizePriceUSD(
  AppStore store,
  double raw,
  Currency cur,
) {
  final ctx = store.contextOf(module: RateModule.finance);
  final rate = ctx.unitsPerUSD(Currency.ves) ?? 1;
  if (cur == Currency.usd) return (usd: raw, rate: rate);
  final u = ctx.unitsPerUSD(cur);
  if (u == null || u <= 0) return null;
  return (usd: raw / u, rate: rate);
}

// ═══════════════════════════ Ficha de producto ═════════════════════════════

class ProductSheet extends StatefulWidget {
  const ProductSheet({super.key, required this.productId});

  final String productId;

  @override
  State<ProductSheet> createState() => _ProductSheetState();
}

class _ProductSheetState extends State<ProductSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _sizeCtrl;
  late final TextEditingController _lastStoreCtrl;
  late final TextEditingController _newStoreCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _targetCtrl;

  late ProductCategory _cat;
  late Presentation _pres;
  Currency _newCurrency = Currency.usd;

  String? _priceError;
  String? _detailsError;
  bool _justMet = false;
  Timer? _metTimer;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    final p = _initialProduct();
    _nameCtrl = TextEditingController(text: p?.name ?? '');
    _barcodeCtrl = TextEditingController(text: p?.barcode ?? '');
    _sizeCtrl = TextEditingController(
      text: p == null || p.size <= 0 ? '' : _sizeText(p.size),
    );
    _lastStoreCtrl = TextEditingController(
      text: p?.latestRecord?.store?.trim() ?? '',
    );
    _newStoreCtrl = TextEditingController();
    _priceCtrl = TextEditingController();
    _targetCtrl = TextEditingController(
      // fmtNum es-VE (fix): el toString crudo interpolaba «3.0»/«2.5» con
      // PUNTO decimal — formato que la propia app considera inválido al
      // teclear (MoneyField normaliza a coma).
      text: p?.targetPrice == null ? '' : fmtNum(p!.targetPrice!),
    );
    _cat = p?.category ?? ProductCategory.otros;
    _pres = p?.presentation ?? Presentation.unit;
  }

  Product? _initialProduct() => context
      .read<AppStore>()
      .products
      .where((x) => x.id == widget.productId)
      .firstOrNull;

  @override
  void dispose() {
    _metTimer?.cancel();
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _sizeCtrl.dispose();
    _lastStoreCtrl.dispose();
    _newStoreCtrl.dispose();
    _priceCtrl.dispose();
    _targetCtrl.dispose();
    super.dispose();
  }

  String _sizeText(double v) =>
      v % 1 == 0 ? v.toInt().toString() : fmtNum(v, decimals: 2);

  /// ¿Cambió algo editable (nombre/código/categoría/presentación/tamaño)?
  bool _isDirty(Product p) {
    if (_nameCtrl.text.trim() != p.name) return true;
    if (_barcodeCtrl.text.trim() != (p.barcode ?? '')) return true;
    if (_cat != p.category || _pres != p.presentation) return true;
    final size = parseLocaleNum(_sizeCtrl.text);
    if (size != null && size != p.size) return true;
    return false;
  }

  void _resetLocal(Product p) {
    setState(() {
      _nameCtrl.text = p.name;
      _barcodeCtrl.text = p.barcode ?? '';
      _sizeCtrl.text = p.size <= 0 ? '' : _sizeText(p.size);
      _cat = p.category;
      _pres = p.presentation;
      _detailsError = null;
    });
  }

  /// Guarda nombre/código/categoría/presentación/tamaño → updateProduct.
  /// Preserva unavailableSince/targetPrice/metSince (patch explícito).
  void _saveDetails(AppStore store, Product p) {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _detailsError = 'El nombre no puede quedar vacío');
      return;
    }
    final size = parseLocaleNum(_sizeCtrl.text) ?? p.size;
    // Barcode vacío → '' (permite LIMPIAR el código; el modelo no borra con
    // null porque copyWith lo conserva). Todos los consumidores tratan ''
    // como ausente (dedupe, escaneo, display).
    store.updateProduct(
      p.id,
      Product(
        id: p.id,
        name: name,
        barcode: _barcodeCtrl.text.trim(),
        category: _cat,
        presentation: _pres,
        size: size,
        sizeUnit: switch (_pres) {
          Presentation.weight => 'g',
          Presentation.volume => 'ml',
          _ => null,
        },
        createdAt: p.createdAt,
        records: p.records,
        unavailableSince: p.unavailableSince,
        targetPrice: p.targetPrice,
        targetCurrency: p.targetCurrency,
        metSince: p.metSince,
      ),
    );
    setState(() => _detailsError = null);
  }

  /// Registra el precio que se pagó HOY → addRecord (+ aviso «bajo meta»).
  void _submitPrice(AppStore store, Product p) {
    final raw = parseLocaleNum(_priceCtrl.text);
    if (raw == null || raw <= 0) {
      setState(() => _priceError = 'Ingresa un precio mayor que 0');
      return;
    }
    final norm = normalizePriceUSD(store, raw, _newCurrency);
    if (norm == null) {
      setState(
        () => _priceError =
            'Sin tasa activa para ${_newCurrency.label} — regístralo en USD',
      );
      return;
    }
    final storeName = _newStoreCtrl.text.trim();
    final prev = p.latestRecord; // ANTES de insertar (base de la alerta).
    store.addRecord(
      p.id,
      PriceRecord(
        id: '',
        price: norm.usd, // USD normalizado
        originalPrice: raw, // tal cual se pagó
        currency: _newCurrency.code,
        quantity: 1,
        store: storeName.isEmpty ? null : storeName,
        rate: norm.rate,
        sourceId: store.contextOf(module: RateModule.finance).sel(Currency.ves),
        date: DateTime.now(),
      ),
    );
    _priceCtrl.clear();
    _newStoreCtrl.clear();
    setState(() => _priceError = null);
    // Alerta de subida de precio (v17.5) + metas de producto (17.7 · el
    // mismo camino del 2º plano): engine + sistema + centro + metSince.
    try {
      context.read<AlertEngine>().checkProductRise(
        notifs: context.read<NotificationsService>(),
        persist: (kind, title, body) =>
            store.pushNotification(kind: kind, title: title, body: body),
        productId: p.id,
        productName: p.name,
        oldPrice: prev?.price ?? 0,
        newPrice: norm.usd,
        storeName: storeName.isEmpty ? null : storeName,
      );
      // Metas de precio (17.7 · price_targets): anuncia «bajo tu meta» por
      // el canal del sistema + centro y fija metSince — mismo camino que el
      // 2º plano de workmanager.
      context.read<AlertEngine>().checkProductTargets(
        store: store,
        notifs: context.read<NotificationsService>(),
        persist: (kind, title, body) =>
            store.pushNotification(kind: kind, title: title, body: body),
      );
    } catch (_) {
      // Sin Provider (previews/tests): la alerta es no-op, el registro sigue.
    }
    // Aviso «¡bajo tu meta!» (patrón §9.4 TARGET_EPS) — banner temporal.
    final t = p.targetPrice;
    if (t != null && t > 0 && norm.usd < t * (1 - an.kTargetEps)) {
      _metTimer?.cancel();
      setState(() => _justMet = true);
      _metTimer = Timer(const Duration(seconds: 4), () {
        if (mounted) setState(() => _justMet = false);
      });
    }
  }

  void _fixTarget(AppStore store, Product p) {
    final t = parseLocaleNum(_targetCtrl.text);
    if (t == null || t <= 0) {
      setState(
        () => _detailsError = 'Meta inválida: ingresa un monto mayor que 0',
      );
      return;
    }
    store.setTarget(p.id, t);
    setState(() => _detailsError = null);
  }

  void _clearTarget(AppStore store, Product p) {
    store.setTarget(p.id, null);
    _targetCtrl.clear();
  }

  /// Guarda la tienda del último registro → updateRecord.
  void _saveLastStore(AppStore store, Product p) {
    final last = p.latestRecord;
    if (last == null) return;
    store.updateRecord(
      p.id,
      last.id,
      newUSD: last.price,
      newOriginal: last.originalPrice,
      store: _lastStoreCtrl.text.trim(),
    );
  }

  Future<void> _scanIntoBarcode() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    setState(() => _barcodeCtrl.text = code);
  }

  Future<void> _confirmDelete(AppStore store, Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar producto'),
        content: Text(
          'Se elimina «${p.name}» con sus ${p.records.length} registro(s) '
          'y se quita de la lista de compras.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: VeColors.of(context).neg,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    store.deleteProduct(p.id); // el watcher cierra la ficha al no encontrarlo
  }

  Future<void> _editRecord(
    BuildContext context,
    AppStore store,
    Product p,
    PriceRecord r,
  ) async {
    final priceCtrl = TextEditingController(
      text: fmtMoney(r.originalPrice, CurrencyX.from(r.currency)),
    );
    final storeCtrl = TextEditingController(
      text: _storeOf(r) == 'Sin tienda' ? '' : r.store,
    );
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar registro'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            MoneyField(
              controller: priceCtrl,
              autofocus: true,
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
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    final price = parseLocaleNum(priceCtrl.text);
    if (price == null || price <= 0) {
      showToast(
        context,
        'Precio inválido: debe ser mayor que 0',
        kind: ToastKind.warn,
      );
      return;
    }
    store.updateRecord(
      p.id,
      r.id,
      newUSD: price,
      newOriginal: price,
      store: storeCtrl.text.trim(),
    );
  }

  Future<void> _confirmDeleteRecord(
    BuildContext context,
    AppStore store,
    Product p,
    PriceRecord r,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Eliminar registro'),
        content: Text(
          'Se quita el registro del ${fmtDate(r.date)} (${fmtUSD(r.price)}). '
          'El producto se conserva.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: VeColors.of(context).neg,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (ok == true) store.deleteRecord(p.id, r.id);
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final p = store.products.where((x) => x.id == widget.productId).firstOrNull;

    // Producto eliminado (desde la propia ficha) → cierra una sola vez.
    if (p == null) {
      if (!_closed) {
        _closed = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.of(context).pop();
        });
      }
      return const SizedBox.shrink();
    }

    return Column(
      children: [
        // Agarradera firma del sheet.
        Center(
          child: Container(
            width: 34,
            height: 3.5,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              _header(context, store, p),
              const SizedBox(height: 14),
              _vigente(context, p),
              if (_justMet) ...[
                const SizedBox(height: 8),
                _metBanner(context, p),
              ],
              _addPrice(context, store, p),
              _chart(context, p),
              _tiendas(context, p),
              _history(context, store, p),
              _actions(context, store, p),
            ],
          ),
        ),
      ],
    );
  }

  // ── Cabecera: nombre editable + stamps + última tienda ───────────────────

  Widget _header(BuildContext context, AppStore store, Product p) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    final last = p.latestRecord;
    final target = an.computeTargetInfo(p);
    final hasStore = last != null && _storeOf(last) != 'Sin tienda';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            CategoryIcon(cat: p.category, size: 38),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: _nameCtrl,
                style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                  height: 1.15,
                ),
                decoration: const InputDecoration(
                  hintText: 'Nombre del producto',
                  border: InputBorder.none,
                  isDense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 20),
              tooltip: 'Cerrar ficha',
              onPressed: () => Navigator.of(context).pop(),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (p.isUnavailable)
              Stamp('no disponible', color: sem.neg, icon: Icons.block)
            else if (target.met)
              Stamp('¡bajo meta!', color: sem.pos, icon: Icons.check)
            else if (p.targetPrice != null)
              Stamp('meta fijada', color: sem.warn)
            else
              Stamp('sin meta', color: scheme.onSurfaceVariant),
            if ((p.barcode ?? '').trim().isNotEmpty)
              Text(
                p.barcode!,
                style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
              ),
            Text(
              presentationLabel(p),
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            StoreAvatar(
              last == null || !hasStore ? '—' : _storeOf(last),
              size: 22,
            ),
            const SizedBox(width: 7),
            Text(
              'ÚLTIMA TIENDA',
              style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                last == null ? '— sin registros' : _storeOf(last),
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Botón de guardado solo cuando hay cambios (ListenableBuilder para no
        // redibujar la gráfica en cada tecla).
        AnimatedBuilder(
          animation: Listenable.merge([_nameCtrl, _barcodeCtrl, _sizeCtrl]),
          builder: (context, _) => _isDirty(p)
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: FilledButton.tonal(
                          onPressed: () => _saveDetails(store, p),
                          child: const Text('Guardar cambios'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      OutlinedButton(
                        onPressed: () => _resetLocal(p),
                        child: const Text('Descartar'),
                      ),
                    ],
                  ),
                )
              : const SizedBox.shrink(),
        ),
        if (_detailsError != null) ...[
          const SizedBox(height: 6),
          Text(
            _detailsError!,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: sem.neg,
            ),
          ),
        ],
      ],
    );
  }

  // ── Cifra vigente (ReadWindow, displayNum, variación vs anterior) ────────

  Widget _vigente(BuildContext context, Product p) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    final last = p.latestRecord;

    if (last == null) {
      return ReadWindow(
        semanticLabel: 'Sin precio vigente todavía',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'PRECIO VIGENTE',
              style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              '—',
              style: VeText.displayNum(34, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Text(
              'Sin datos: regístra el primer precio abajo.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ),
      );
    }

    final recs = [...p.records]..sort((a, b) => a.date.compareTo(b.date));
    final prev = recs.length >= 2 ? recs[recs.length - 2] : null;
    final varPct = prev == null
        ? null
        : an.priceVariation(prev.price, last.price);
    final perUnit = _perUnitOf(last, p);

    return ReadWindow(
      semanticLabel: 'Precio vigente ${fmtUSD(last.price)}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Flexible + Wrap-friendly: a textScale >=1.2 la fila superaba
          // los ~300 px del ReadWindow y desbordaba (fix overflow).
          Row(
            children: [
              Flexible(
                child: Text(
                  'PRECIO VIGENTE',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
                ),
              ),
              const SizedBox(width: 6),
              // El libro de precios es USD-normalizado: divisa explícita (v17.5).
              const CurrencyTag('USD'),
              if (varPct != null) ...[
                const SizedBox(width: 5),
                TrendBadge(varPct),
                const SizedBox(width: 5),
                Text(
                  'VS ANTERIOR',
                  style: VeText.labelCaps(8.5, color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
          const SizedBox(height: 6),
          // Números largos: FittedBox scaleDown (§8).
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              fmtUSD(last.price),
              style: VeText.displayNum(34, color: scheme.onSurface),
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Icon(Icons.history, size: 12, color: scheme.onSurfaceVariant),
              const SizedBox(width: 4),
              Flexible(
                child: Text(
                  '${timeAgo(last.date)} · ${_storeOf(last)}'
                  '${last.currency != 'USD' ? ' · pagó ${fmtMoney(last.originalPrice, CurrencyX.from(last.currency))}' : ''}',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface.withValues(alpha: 0.75),
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          if (perUnit != null) ...[
            const SizedBox(height: 4),
            Text(
              '≈ ${fmtUSD(perUnit)} / ${baseUnitLabel(p)}',
              style: VeText.displayNum(12.5, color: sem.pos),
            ),
          ],
        ],
      ),
    );
  }

  /// Precio por unidad base solo cuando es honesto (kg/L/pza con tamaño > 0).
  double? _perUnitOf(PriceRecord r, Product p) {
    if (p.size <= 0 || p.presentation == Presentation.unit) return null;
    return pricePerBase(r, p);
  }

  Widget _metBanner(BuildContext context, Product p) {
    final sem = VeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
      decoration: BoxDecoration(
        color: sem.pos.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: sem.pos.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.celebration_outlined, size: 15, color: sem.pos),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              '¡Bajo tu meta! El precio quedó por debajo de ${fmtUSD(p.targetPrice!)}',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: sem.pos,
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Actualizar precio (acción protagonista, enfoque web v15) ─────────────

  Widget _addPrice(BuildContext context, AppStore store, Product p) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    // v19: la sección vive en su Card como todas las demás (antes iba
    // suelta y pegada a la cifra vigente) y el monto usa MoneyField con
    // formato de miles en vivo.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Actualizar precio', icon: Icons.price_change_outlined),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: MoneyField(
                        controller: _priceCtrl,
                        decoration: const InputDecoration(
                          hintText: 'Precio que pagaste',
                          prefixIcon: Icon(Icons.payments_outlined, size: 18),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CurrencySelect(
                      value: _newCurrency,
                      onChanged: (c) => setState(() => _newCurrency = c),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: _newStoreCtrl,
                  decoration: const InputDecoration(
                    hintText: 'Tienda (opcional)',
                    prefixIcon: Icon(Icons.storefront_outlined, size: 18),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Icon(
                      Icons.today_outlined,
                      size: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 5),
                    Expanded(
                      child: Text(
                        'SE REGISTRA CON FECHA DE HOY · ${fmtDate(DateTime.now()).toUpperCase()}',
                        style: VeText.labelCaps(
                          8.5,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                if (_priceError != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    _priceError!,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: sem.neg,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => _submitPrice(store, p),
                    icon: const Icon(Icons.add_circle_outline, size: 17),
                    label: const Text('Actualizar precio'),
                  ),
                ),
                if (p.targetPrice != null) ...[
                  const SizedBox(height: 6),
                  Text(
                    'Tu meta para este producto: ${fmtUSD(p.targetPrice!)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Gráfica: inflación/deflación del producto ────────────────────────────

  Widget _chart(BuildContext context, Product p) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    final recs = [...p.records]..sort((a, b) => a.date.compareTo(b.date));
    final total = recs.length >= 2 ? an.totalVariation(recs) : null;
    final showUnit = p.size > 0 && p.presentation != Presentation.unit;
    final hasUnit = showUnit && recs.any((r) => pricePerBase(r, p) != null);
    final points = recs
        .map(
          (r) => _ChartPoint(
            r.date,
            r.price,
            showUnit ? pricePerBase(r, p) : null,
          ),
        )
        .toList();

    return Column(
      children: [
        SectionTitle(
          'Inflación/deflación del producto',
          icon: Icons.show_chart,
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
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
                          FittedBox(
                            fit: BoxFit.scaleDown,
                            alignment: Alignment.centerLeft,
                            child: Text(
                              total == null ? '—' : fmtPct(total),
                              style: VeText.displayNum(
                                21,
                                color: scheme.onSurface,
                              ),
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            total == null
                                ? 'Acumulado del período (sin datos)'
                                : 'Acumulado del período · del ${fmtDate(recs.first.date)} al ${fmtDate(recs.last.date)}',
                            style: TextStyle(
                              fontSize: 11,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (total != null) TrendBadge(total),
                  ],
                ),
                if (hasUnit) ...[
                  const SizedBox(height: 4),
                  Text(
                    'Punteada: precio por ${baseUnitLabel(p)} (eje derecho)',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 6),
                if (recs.length < 2)
                  SizedBox(
                    height: 120,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.query_stats,
                            size: 20,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(height: 6),
                          Text(
                            recs.isEmpty
                                ? 'Sin registros: no hay curva que mostrar.'
                                : 'Con un solo registro no hay curva — añade otro precio.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                  )
                else
                  SizedBox(
                    height: 200,
                    child: SfCartesianChart(
                      legend: const Legend(
                        isVisible: true,
                        position: LegendPosition.bottom,
                        textStyle: TextStyle(fontSize: 10),
                      ),
                      primaryXAxis: DateTimeAxis(
                        dateFormat: DateFormat('dd/MM'),
                        majorGridLines: const MajorGridLines(width: 0),
                        labelStyle: const TextStyle(fontSize: 9.5),
                      ),
                      primaryYAxis: NumericAxis(
                        majorGridLines: const MajorGridLines(width: 0.5),
                        labelStyle: const TextStyle(fontSize: 9.5),
                      ),
                      axes: hasUnit
                          ? [
                              NumericAxis(
                                name: 'unit',
                                opposedPosition: true,
                                majorGridLines: const MajorGridLines(width: 0),
                                labelStyle: const TextStyle(fontSize: 9.5),
                              ),
                            ]
                          : const <ChartAxis>[],
                      tooltipBehavior: TooltipBehavior(enable: true),
                      trackballBehavior: TrackballBehavior(
                        enable: true,
                        activationMode: ActivationMode.singleTap,
                      ),
                      series: [
                        AreaSeries<_ChartPoint, DateTime>(
                          dataSource: points,
                          xValueMapper: (pt, _) => pt.date,
                          yValueMapper: (pt, _) => pt.price,
                          name: 'Precio (USD)',
                          color: scheme.primary.withValues(alpha: 0.22),
                          borderColor: scheme.primary,
                          borderWidth: 2,
                        ),
                        if (hasUnit)
                          LineSeries<_ChartPoint, DateTime>(
                            dataSource: points,
                            xValueMapper: (pt, _) => pt.date,
                            yValueMapper: (pt, _) => pt.perUnit,
                            yAxisName: 'unit',
                            name: 'Por ${baseUnitLabel(p)}',
                            color: sem.manual,
                            width: 1.6,
                            dashArray: const <double>[5, 3],
                          ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Tiendas: comparador de precio más bajo (v17.5 · hueco real del
  // ── consultor: «comparador de tiendas»). Último precio por tienda.

  Widget _tiendas(BuildContext context, Product p) {
    final sem = VeColors.of(context);
    final byStore = <String, PriceRecord>{};
    final count = <String, int>{};
    for (final r in p.records) {
      final s = (r.store == null || r.store!.trim().isEmpty)
          ? 'Sin tienda'
          : r.store!.trim();
      count[s] = (count[s] ?? 0) + 1;
      final cur = byStore[s];
      if (cur == null || r.date.isAfter(cur.date)) byStore[s] = r;
    }
    if (byStore.length < 2) {
      return const SizedBox.shrink(); // sin comparación no hay sección
    }

    final rows = byStore.entries.toList()
      ..sort((a, b) => a.value.price.compareTo(b.value.price));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Tiendas', icon: Icons.storefront_outlined),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            child: Column(
              children: [
                for (final (i, e) in rows.indexed)
                  LedgerRow(
                    leading: StoreAvatar(e.key),
                    label:
                        '${e.key} · ${timeAgo(e.value.date)}'
                        ' · ${count[e.key]} reg.${i == 0 ? ' · MÁS BARATO' : ''}',
                    dots: true,
                    value: fmtUSD(e.value.price),
                    valueColor: i == 0 ? sem.pos : null,
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  // ── Historial de registros (LedgerRow + editar/borrar) ───────────────────

  Widget _history(BuildContext context, AppStore store, Product p) {
    final scheme = Theme.of(context).colorScheme;
    final recs = [...p.records]..sort((a, b) => a.date.compareTo(b.date));
    final shown = recs.reversed.take(30).toList();

    return Column(
      children: [
        SectionTitle(
          'Historial de registros',
          icon: Icons.receipt_long_outlined,
        ),
        if (recs.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.receipt_long_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sin registros todavía: todo arranca con el primer precio.',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: Column(
                children: [
                  for (final r in shown)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 3),
                      child: Row(
                        children: [
                          Expanded(
                            child: LedgerRow(
                              label: _recordLabel(r),
                              value: fmtUSD(r.price),
                              onTap: () => _editRecord(context, store, p, r),
                            ),
                          ),
                          IconButton(
                            icon: Icon(
                              Icons.delete_outline,
                              size: 16,
                              color: VeColors.of(context).neg,
                            ),
                            tooltip: 'Eliminar registro',
                            onPressed: () =>
                                _confirmDeleteRecord(context, store, p, r),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ),
        if (recs.length > 30)
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Text(
              '+${recs.length - 30} registros anteriores',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
      ],
    );
  }

  String _recordLabel(PriceRecord r) =>
      '${fmtDate(r.date)} · ${_storeOf(r)}'
      '${r.currency != 'USD' ? ' · pagó ${fmtMoney(r.originalPrice, CurrencyX.from(r.currency))}' : ''}';

  // ── Ajustes: código, categoría/presentación/tamaño, meta, tienda, peligro ─

  Widget _actions(BuildContext context, AppStore store, Product p) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    final sizeHint = switch (_pres) {
      Presentation.weight => 'Tamaño total en g (ej. 1000)',
      Presentation.volume => 'Tamaño total en ml (ej. 2000)',
      Presentation.pack => 'Unidades del paquete (ej. 4)',
      Presentation.unit => 'Contenido (opcional, ej. 355 ml)',
    };

    // v19: Ajustes en SU Card (antes suelto) con grupos separados por
    // divisores — jerarquía clara y nada pegado.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Ajustes del producto', icon: Icons.tune),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'CÓDIGO DE BARRAS',
                  style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _barcodeCtrl,
                        keyboardType: TextInputType.number,
                        decoration: const InputDecoration(
                          hintText: 'Código (opcional)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      onPressed: _scanIntoBarcode,
                      tooltip: 'Escanear código de barras',
                      icon: const Icon(Icons.qr_code_scanner, size: 20),
                    ),
                  ],
                ),
                const Divider(height: 22),
                Text(
                  'PRESENTACIÓN',
                  style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final pr in Presentation.values)
                      ChipTag(
                        pr.label,
                        selected: _pres == pr,
                        onTap: () => setState(() => _pres = pr),
                      ),
                  ],
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sizeCtrl,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(hintText: sizeHint),
                ),
                const SizedBox(height: 10),
                Text(
                  'CATEGORÍA',
                  style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final c in ProductCategory.values)
                      ChipTag(
                        c.label,
                        selected: _cat == c,
                        onTap: () => setState(() => _cat = c),
                      ),
                  ],
                ),
                const Divider(height: 22),
                Text(
                  'META DE PRECIO (USD)',
                  style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                MoneyField(
                  controller: _targetCtrl,
                  maxDecimals: 4,
                  decoration: InputDecoration(
                    hintText: p.targetPrice == null
                        ? 'Ej. 2,50'
                        : 'Cambiar meta USD',
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => _fixTarget(store, p),
                        child: const Text('Fijar meta'),
                      ),
                    ),
                    if (p.targetPrice != null) ...[
                      const SizedBox(width: 8),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => _clearTarget(store, p),
                          child: const Text('Quitar meta'),
                        ),
                      ),
                    ],
                  ],
                ),
                const Divider(height: 22),
                Text(
                  'TIENDA DEL ÚLTIMO REGISTRO',
                  style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _lastStoreCtrl,
                        decoration: InputDecoration(
                          hintText: p.latestRecord == null
                              ? '— sin registros'
                              : 'Ej. Bicentenario',
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: p.latestRecord == null
                          ? null
                          : () => _saveLastStore(store, p),
                      child: const Text('Guardar'),
                    ),
                  ],
                ),
                const Divider(height: 22),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: () =>
                        store.setUnavailable(p.id, !p.isUnavailable),
                    icon: Icon(
                      p.isUnavailable
                          ? Icons.check_circle_outline
                          : Icons.block,
                      size: 16,
                    ),
                    label: Text(
                      p.isUnavailable
                          ? 'Marcar disponible'
                          : 'Marcar no disponible',
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: sem.neg,
                      side: BorderSide(color: sem.neg.withValues(alpha: 0.4)),
                    ),
                    onPressed: () => _confirmDelete(store, p),
                    icon: const Icon(Icons.delete_outline, size: 16),
                    label: const Text('Eliminar producto'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Punto de la gráfica: fecha + precio USD (+ precio por unidad base si
/// aplica; null → syncfusion lo salta).
class _ChartPoint {
  const _ChartPoint(this.date, this.price, this.perUnit);

  final DateTime date;
  final double price;
  final double? perUnit;
}

// ═══════════════════════════ Alta de producto ══════════════════════════════

class NewProductSheet extends StatefulWidget {
  const NewProductSheet({super.key, this.initialBarcode});

  final String? initialBarcode;

  @override
  State<NewProductSheet> createState() => _NewProductSheetState();
}

class _NewProductSheetState extends State<NewProductSheet> {
  final _nameCtrl = TextEditingController();
  late final TextEditingController _barcodeCtrl = TextEditingController(
    text: widget.initialBarcode ?? '',
  );
  final _sizeCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _storeCtrl = TextEditingController();

  ProductCategory _cat = ProductCategory.otros;
  Presentation _pres = Presentation.unit;
  Currency _currency = Currency.usd;
  String? _error;
  String? _barcodeWarn;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _barcodeCtrl.dispose();
    _sizeCtrl.dispose();
    _priceCtrl.dispose();
    _storeCtrl.dispose();
    super.dispose();
  }

  Future<void> _scanIntoBarcode() async {
    final code = await scanBarcode(context);
    if (code == null || !mounted) return;
    final store = context.read<AppStore>();
    final dupe = store.products.where((p) => p.barcode == code).firstOrNull;
    setState(() {
      _barcodeCtrl.text = code;
      _barcodeWarn = dupe == null
          ? null
          : 'Ese código ya está en el libro como «${dupe.name}»';
    });
  }

  /// Crea el producto (y su primer precio si se ingresó) en un paso.
  void _create(AppStore store) {
    final name = _nameCtrl.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'El nombre es obligatorio');
      return;
    }
    PriceRecord? first;
    final rawText = _priceCtrl.text.trim();
    if (rawText.isNotEmpty) {
      final raw = parseLocaleNum(rawText);
      if (raw == null || raw <= 0) {
        setState(() => _error = 'Precio inválido: debe ser mayor que 0');
        return;
      }
      final norm = normalizePriceUSD(store, raw, _currency);
      if (norm == null) {
        setState(
          () => _error = 'Sin tasa activa para ${_currency.label} — usa USD',
        );
        return;
      }
      final storeName = _storeCtrl.text.trim();
      first = PriceRecord(
        id: '',
        price: norm.usd,
        originalPrice: raw,
        currency: _currency.code,
        quantity: 1,
        store: storeName.isEmpty ? null : storeName,
        rate: norm.rate,
        sourceId: store.contextOf(module: RateModule.finance).sel(Currency.ves),
        date: DateTime.now(),
      );
    }
    final size =
        parseLocaleNum(_sizeCtrl.text) ??
        switch (_pres) {
          Presentation.unit => 1.0,
          Presentation.pack => 1.0,
          _ => 0.0,
        };
    store.addProduct(
      Product(
        id: '',
        name: name,
        barcode: _barcodeCtrl.text.trim().isEmpty
            ? null
            : _barcodeCtrl.text.trim(),
        category: _cat,
        presentation: _pres,
        size: size,
        sizeUnit: switch (_pres) {
          Presentation.weight => 'g',
          Presentation.volume => 'ml',
          _ => null,
        },
        createdAt: DateTime.now(),
        records: const [],
      ),
      first,
    );
    if (!mounted) return;
    showToast(
      context,
      first == null ? 'Producto creado' : 'Producto creado con primer precio',
      kind: ToastKind.ok,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final sizeHint = switch (_pres) {
      Presentation.weight => 'Tamaño total en g (opcional)',
      Presentation.volume => 'Tamaño total en ml (opcional)',
      Presentation.pack => 'Unidades del paquete (opcional)',
      Presentation.unit => 'Contenido (opcional)',
    };

    return Column(
      children: [
        Center(
          child: Container(
            width: 34,
            height: 3.5,
            margin: const EdgeInsets.only(top: 10),
            decoration: BoxDecoration(
              color: scheme.outlineVariant,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 28),
            children: [
              PageHeader(
                'Nuevo producto',
                hint: 'Alta en un paso: nombre + primer precio',
                action: IconButton(
                  icon: const Icon(Icons.close, size: 20),
                  tooltip: 'Cerrar',
                  onPressed: () => Navigator.of(context).pop(),
                ),
              ),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        controller: _nameCtrl,
                        autofocus: widget.initialBarcode == null,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'Nombre del producto',
                          prefixIcon: Icon(
                            Icons.inventory_2_outlined,
                            size: 18,
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'CÓDIGO DE BARRAS',
                        style: VeText.labelCaps(
                          9,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(height: 6),
                      Row(
                        children: [
                          Expanded(
                            child: TextField(
                              controller: _barcodeCtrl,
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                hintText: 'Código (opcional)',
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          IconButton.filledTonal(
                            onPressed: _scanIntoBarcode,
                            tooltip: 'Escanear código de barras',
                            icon: const Icon(Icons.qr_code_scanner, size: 20),
                          ),
                        ],
                      ),
                      if (_barcodeWarn != null) ...[
                        const SizedBox(height: 5),
                        Text(
                          _barcodeWarn!,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: VeColors.of(context).warn,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Text(
                'CATEGORÍA',
                style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final c in ProductCategory.values)
                    ChipTag(
                      c.label,
                      selected: _cat == c,
                      onTap: () => setState(() => _cat = c),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'PRESENTACIÓN',
                style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (final pr in Presentation.values)
                    ChipTag(
                      pr.label,
                      selected: _pres == pr,
                      onTap: () => setState(() => _pres = pr),
                    ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _sizeCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                decoration: InputDecoration(hintText: sizeHint),
              ),
              const SizedBox(height: 12),
              Text(
                'PRIMER PRECIO (OPCIONAL · FECHA DE HOY)',
                style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: MoneyField(
                      controller: _priceCtrl,
                      decoration: const InputDecoration(
                        hintText: 'Precio que pagaste',
                        prefixIcon: Icon(Icons.payments_outlined, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CurrencySelect(
                    value: _currency,
                    onChanged: (c) => setState(() => _currency = c),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              TextField(
                controller: _storeCtrl,
                decoration: const InputDecoration(
                  hintText: 'Tienda (opcional)',
                  prefixIcon: Icon(Icons.storefront_outlined, size: 18),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sin precio igual se crea: lo añades después desde su ficha.',
                style: TextStyle(
                  fontSize: 11.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              if (_error != null) ...[
                const SizedBox(height: 6),
                Text(
                  _error!,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: VeColors.of(context).neg,
                  ),
                ),
              ],
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _create(store),
                  icon: const Icon(Icons.check, size: 17),
                  label: const Text('Crear producto'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}
