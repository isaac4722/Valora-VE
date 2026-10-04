/// ─── Productos · Ficha de producto (§9.4 · TASK-34 Ve) ──────────────────────
/// Ficha en SHEET Ve (showVeSheet wide: móvil bottom / escritorio modal
/// centrado) con TODO el detalle de siempre:
///  · Cabecera: categoría eyebrow + nombre editable + badges de estado +
///    tienda del último registro.
///  · Cifra vigente protagonista: precio 34 px + VeBadge de estado +
///    VeSparkline h48 + «hace X» + variación % vs registro anterior (tinta
///    pos/neg) + precio por unidad (kg/L/pza) cuando el tamaño lo permite.
///  · Grid de 3 stats (Mejor · Promedio · Meta) con divisores.
///  · «Precio por tienda» (VeGroup): comparador de precio más bajo con
///    badge «Mejor» en la más barata (último precio por tienda).
///  · «Registrar precio»: monto + moneda + tienda (autocompletado) →
///    addRecord con fecha de hoy; banner honesto «¡Bajo tu meta!» si el
///    precio quedó por debajo (TARGET_EPS).
///  · Gráfica «Inflación/deflación del producto» (VeTimelineChart: área USD
///    + precio por kg/L punteado en escala propia), % acumulado del
///    período, chip interactivo. Estado vacío honesto («sin datos»).
///  · Historial de registros: editar (updateRecord) y borrar (deleteRecord
///    con confirmación).
///  · Ajustes: código de barras (+ escáner), categoría/presentación/tamaño,
///    meta de precio fijar/quitar, tienda del último registro, marcar no
///    disponible. Eliminar vive en el pie (trash danger) con confirmación.
///  · Pie: [Eliminar producto] + [Agregar a la lista] (precio vigente del
///    libro; sin precio avisa honesto).
/// Alta de producto (req. 2): NewProductSheet — nombre + escaneo de código +
/// PRIMER PRECIO (precio+moneda+tamaño opcional) → addProduct con
/// firstRecord en un solo paso.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:intl/intl.dart' show DateFormat;

import '../../core/analytics.dart' as an;
import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../services/alerts.dart';
import '../../services/notifications.dart';
import '../scanner/scanner_screen.dart';
import '../lista/item_editor.dart' show StoreAutocompleteField;
import '../../widgets/ui.dart';

/// Estado visual de un producto (mapa del prototipo Products.tsx):
/// META OK→pos · Sube→neg · Baja→pos · Estable→neutral · Sin dato→neutral ·
/// No disponible→neg. La sparkline hereda el tono (sube=neg · baja/meta=pos ·
/// estable/sin dato=muted).
class VeProductStatus {
  const VeProductStatus({
    required this.label,
    required this.tone,
    required this.spark,
  });

  final String label;
  final VeTone tone;
  final VeChartTone spark;
}

/// Resuelve el estado de un producto con su historial real (sin inventar):
/// meta cumplida > subida > bajada > estable; sin serie → «Sin dato»;
/// marcado no disponible → «No disponible».
VeProductStatus productStatus(Product p) {
  final target = an.computeTargetInfo(p);
  if (p.isUnavailable) {
    return const VeProductStatus(
      label: 'No disponible',
      tone: VeTone.neg,
      spark: VeChartTone.muted,
    );
  }
  if (target.met) {
    return const VeProductStatus(
      label: 'Meta OK',
      tone: VeTone.pos,
      spark: VeChartTone.pos,
    );
  }
  if (p.records.length >= 2) {
    final v = an.totalVariation(p.records);
    if (v > 0.5) {
      return const VeProductStatus(
        label: 'Sube',
        tone: VeTone.neg,
        spark: VeChartTone.neg,
      );
    }
    if (v < -0.5) {
      return const VeProductStatus(
        label: 'Baja',
        tone: VeTone.pos,
        spark: VeChartTone.pos,
      );
    }
    return const VeProductStatus(
      label: 'Estable',
      tone: VeTone.neutral,
      spark: VeChartTone.muted,
    );
  }
  return const VeProductStatus(
    label: 'Sin dato',
    tone: VeTone.neutral,
    spark: VeChartTone.muted,
  );
}

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
    // FIX 9P·Performance: el texto se lee ANTES de disponer (después de
    // dispose, leer .text revienta). Cada apertura del diálogo dejaba un
    // controller vivo.
    final typed = ctrl.text.trim();
    ctrl.dispose();
    if (ok != true) return null;
    code = typed;
  }
  if (code == null || code.isEmpty) return null;
  return code;
}

/// Abre la FICHA completa de un producto existente (req. 1) — v20: hoja
/// a MEDIA PANTALLA arrastrable (orden del dueño: nace a la mitad, sube
/// si el usuario quiere más detalle; pie con [Eliminar] + [Agregar]).
Future<void> showProductSheet(BuildContext context, Product product) async {
  final key = GlobalKey<ProductSheetState>();
  await showVeHalfSheet(
    context: context,
    title: 'Ficha del producto',
    wide: true,
    builder: (_) => ProductSheet(key: key, productId: product.id),
    footer: Row(
      children: [
        VeBtn(
          variant: VeBtnVariant.danger,
          icon: LucideIcons.trash2,
          onPressed: () => key.currentState?.askDelete(),
          child: const Text('Eliminar'),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: VeBtn(
            variant: VeBtnVariant.primary,
            icon: LucideIcons.plus,
            onPressed: () => key.currentState?.addToCartAndClose(),
            child: const Text('Agregar a la lista'),
          ),
        ),
      ],
    ),
  );
}

/// Abre el ALTA de producto nuevo (req. 2): nombre + código (con escáner) +
/// primer precio en un paso → addProduct con firstRecord. v20: media
/// pantalla arrastrable (el alta es corto; no cubre la app de golpe).
Future<void> showNewProductSheet(
  BuildContext context, {
  String? initialBarcode,
}) async {
  final key = GlobalKey<_NewProductSheetState>();
  await showVeHalfSheet(
    context: context,
    title: 'Nuevo producto',
    builder: (_) => NewProductSheet(key: key, initialBarcode: initialBarcode),
    footer: VeBtn(
      variant: VeBtnVariant.primary,
      size: VeBtnSize.lg,
      expands: true,
      icon: LucideIcons.check,
      onPressed: () => key.currentState?.create(),
      child: const Text('Crear producto'),
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
  State<ProductSheet> createState() => ProductSheetState();
}

class ProductSheetState extends State<ProductSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _barcodeCtrl;
  late final TextEditingController _sizeCtrl;
  late final TextEditingController _lastStoreCtrl;
  late final TextEditingController _priceCtrl;
  late final TextEditingController _targetCtrl;

  late ProductCategory _cat;
  late Presentation _pres;
  Currency _newCurrency = Currency.usd;
  String? _newStore;

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

  Product? _currentProduct() => context
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
    final storeName = (_newStore ?? '').trim();
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
    setState(() {
      _priceError = null;
      _newStore = null;
    });
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

  /// Pie: «Eliminar» (trash) — confirmación y cascada de canasta en store.
  /// El watcher de la ficha la cierra al no encontrar el producto.
  Future<void> askDelete() async {
    final store = context.read<AppStore>();
    final p = _currentProduct();
    if (p == null) return;
    await _confirmDelete(store, p);
  }

  /// Pie: «Agregar a la lista» con el precio vigente del libro (patrón del
  /// escáner). Sin precio → aviso honesto, no se agrega en $0.
  void addToCartAndClose() {
    final store = context.read<AppStore>();
    final p = _currentProduct();
    if (p == null) return;
    final last = p.latestRecord;
    if (last == null) {
      showToast(context, 'Regístrale precio primero', kind: ToastKind.warn);
      return;
    }
    store.addToCart(
      CartItem(
        id: '',
        productId: p.id,
        name: p.name,
        quantity: 1,
        price: last.originalPrice,
        currency: last.currency,
        barcode: p.barcode,
      ),
    );
    showToast(context, '${p.name} agregado a la lista', kind: ToastKind.ok);
    Navigator.of(context).pop();
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
    // FIX 9P·Performance: los textos se leen ANTES de disponer los
    // controllers — cada edición de registro dejaba dos vivos.
    final price = parseLocaleNum(priceCtrl.text);
    final storeName = storeCtrl.text.trim();
    priceCtrl.dispose();
    storeCtrl.dispose();
    if (ok != true || !context.mounted) return;
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
      store: storeName,
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
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        _header(context, store, p),
        _vigente(context, p),
        if (_justMet) ...[
          const SizedBox(height: 8),
          _metBanner(context, p),
        ],
        _stats(context, p),
        _addPrice(context, store, p),
        _tiendas(context, p),
        _chart(context, p),
        _history(context, store, p),
        _actions(context, store, p),
      ],
    );
  }

  // ── Cabecera: categoría + nombre editable + badges + última tienda ──────

  Widget _header(BuildContext context, AppStore store, Product p) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final target = an.computeTargetInfo(p);
    final last = p.latestRecord;
    final hasStore = last != null && _storeOf(last) != 'Sin tienda';

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Categoría (eyebrow del prototipo).
        Text(
          p.category.label.toUpperCase(),
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.84,
            color: scheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        TextField(
          controller: _nameCtrl,
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: scheme.foreground,
            height: 1.15,
          ),
          decoration: const InputDecoration(
            hintText: 'Nombre del producto',
            border: InputBorder.none,
            isDense: true,
            contentPadding: EdgeInsets.zero,
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            if (p.isUnavailable)
              const VeBadge(tone: VeTone.neg, child: Text('NO DISPONIBLE'))
            else if (target.met)
              const VeBadge(tone: VeTone.pos, child: Text('BAJO META'))
            else if (p.targetPrice != null)
              VeBadge(tone: VeTone.warn, child: Text('META FIJADA'))
            else
              const VeBadge(tone: VeTone.neutral, child: Text('SIN META')),
            if ((p.barcode ?? '').trim().isNotEmpty)
              Text(
                p.barcode!,
                style: TextStyle(
                  fontFamily: 'JetBrainsMono',
                  fontSize: 10.5,
                  letterSpacing: 0.6,
                  color: scheme.mutedForeground,
                ),
              ),
            Text(
              presentationLabel(p),
              style: TextStyle(fontSize: 11.5, color: scheme.mutedForeground),
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
              style: VeText.labelCaps(9, color: scheme.mutedForeground),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                last == null ? '— sin registros' : _storeOf(last),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.foreground,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),
          ],
        ),
        // Botón de guardado solo cuando hay cambios (ListenableBuilder para
        // no redibujar la gráfica en cada tecla).
        AnimatedBuilder(
          animation: Listenable.merge([_nameCtrl, _barcodeCtrl, _sizeCtrl]),
          builder: (context, _) => _isDirty(p)
              ? Padding(
                  padding: const EdgeInsets.only(top: 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: VeBtn(
                          size: VeBtnSize.sm,
                          onPressed: () => _saveDetails(store, p),
                          child: const Text('Guardar cambios'),
                        ),
                      ),
                      const SizedBox(width: 8),
                      VeBtn(
                        variant: VeBtnVariant.ghost,
                        size: VeBtnSize.sm,
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
              color: ink.neg,
            ),
          ),
        ],
      ],
    );
  }

  // ── Cifra vigente: precio 34 px + badge + sparkline h48 ─────────────────

  Widget _vigente(BuildContext context, Product p) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final last = p.latestRecord;
    final st = productStatus(p);
    final series = p.records.map((r) => r.price).toList();

    final priceBlock = last == null
        ? Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '—',
                style: VeText.displayNum(
                  34,
                  color: scheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Sin datos: regístrale el primer precio abajo.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: scheme.mutedForeground,
                ),
              ),
            ],
          )
        : Builder(builder: (context) {
            final recs = [...p.records]
              ..sort((a, b) => a.date.compareTo(b.date));
            final prev = recs.length >= 2 ? recs[recs.length - 2] : null;
            final varPct = prev == null
                ? null
                : an.priceVariation(prev.price, last.price);
            final perUnit = _perUnitOf(last, p);
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        'PRECIO VIGENTE',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: VeText.labelCaps(
                          9.5,
                          color: scheme.mutedForeground,
                        ),
                      ),
                    ),
                    const SizedBox(width: 6),
                    // El libro de precios es USD-normalizado: divisa
                    // explícita (v17.5).
                    const CurrencyTag('USD'),
                    if (varPct != null) ...[
                      const SizedBox(width: 5),
                      TrendBadge(varPct),
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
                    style: VeText.displayNum(34, color: scheme.foreground),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${timeAgo(last.date)} · ${_storeOf(last)}'
                  '${last.currency != 'USD' ? ' · pagó ${fmtMoney(last.originalPrice, CurrencyX.from(last.currency))}' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: scheme.foreground.withValues(alpha: 0.75),
                  ),
                ),
                if (perUnit != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    '≈ ${fmtUSD(perUnit)} / ${baseUnitLabel(p)}',
                    style: VeText.displayNum(12.5, color: ink.pos),
                  ),
                ],
              ],
            );
          });

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: priceBlock),
              const SizedBox(width: 8),
              VeBadge(tone: st.tone, child: Text(st.label)),
            ],
          ),
          if (series.length >= 2) ...[
            const SizedBox(height: 8),
            SizedBox(
              height: 48,
              child: VeSparkline(
                data: series,
                tone: st.spark,
                height: 48,
              ),
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
          Icon(LucideIcons.circleCheck, size: 15, color: sem.pos),
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

  // ── Grid de 3 stats (Mejor · Promedio · Meta) ───────────────────────────

  Widget _stats(BuildContext context, Product p) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final recs = p.records;
    final best = recs.isEmpty
        ? null
        : recs.map((r) => r.price).reduce((a, b) => a < b ? a : b);
    final avg = recs.isEmpty
        ? null
        : recs.fold<double>(0, (a, r) => a + r.price) / recs.length;

    Widget cell(String label, String value, {bool first = false}) {
      return Expanded(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: first
              ? null
              : BoxDecoration(
                  border: Border(
                    left: BorderSide(color: scheme.border),
                  ),
                ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label.toUpperCase(),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 10.5,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.84,
                  color: scheme.mutedForeground,
                ),
              ),
              const SizedBox(height: 4),
              VeNum(
                value,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: scheme.foreground,
                ),
              ),
            ],
          ),
        ),
      );
    }

    return Padding(
      padding: const EdgeInsets.only(top: 14),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.border),
        ),
        child: Row(
          children: [
            cell('Mejor', best == null ? '—' : fmtUSD(best), first: true),
            cell('Promedio', avg == null ? '—' : fmtUSD(avg)),
            cell(
              'Meta',
              p.targetPrice == null ? '—' : fmtUSD(p.targetPrice!),
            ),
          ],
        ),
      ),
    );
  }

  // ── Registrar precio (acción protagonista, enfoque web v15) ────────────

  Widget _addPrice(BuildContext context, AppStore store, Product p) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VeEyebrow(child: const Text('REGISTRAR PRECIO')),
        VeCard(
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
              // Tienda (autocompletado con las del libro — texto libre).
              StoreAutocompleteField(
                stores: store.stores,
                initialValue: _newStore,
                onChanged: (v) => setState(() => _newStore = v),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(
                    LucideIcons.calendar,
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
              VeBtn(
                variant: VeBtnVariant.primary,
                expands: true,
                icon: LucideIcons.plus,
                onPressed: () => _submitPrice(store, p),
                child: const Text('Registrar precio'),
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
      ],
    );
  }

  // ── Tiendas: comparador de precio más bajo (v17.5 · hueco real del
  // ── consultor: «comparador de tiendas»). Último precio por tienda.

  Widget _tiendas(BuildContext context, Product p) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
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
        VeEyebrow(child: const Text('PRECIO POR TIENDA')),
        VeGroup(
          children: [
            for (final (i, e) in rows.indexed)
              VeRow(
                label: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Flexible(
                      child: Text(
                        e.key,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    if (i == 0) ...[
                      const SizedBox(width: 6),
                      const VeBadge(tone: VeTone.pos, child: Text('Mejor')),
                    ],
                  ],
                ),
                sub: Text('${count[e.key]} reg. · ${timeAgo(e.value.date)}'),
                right: VeNum(
                  fmtUSD(e.value.price),
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: i == 0 ? null : scheme.foreground,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }

  // ── Gráfica: inflación/deflación del producto ──────────────────────────

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
        VeEyebrow(child: const Text('INFLACIÓN/DEFLACIÓN DEL PRODUCTO')),
        VeCard(
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
                          LucideIcons.chartColumn,
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
                // v20.4: VeTimelineChart (CustomPainter propio) en lugar de
                // syncfusion — mismo contenido: área USD + punteado por
                // unidad en su propia escala, leyenda y chip al tocar.
                VeTimelineChart(
                  height: 186,
                  margin: EdgeInsets.zero,
                  legend: true,
                  xLabel: (t) => DateFormat('dd/MM').format(t),
                  yLabel: (v) => fmtNum(v, decimals: 0),
                  semantic: 'Inflación o deflación del producto',
                  series: [
                    VeTimelineSeries(
                      name: 'Precio (USD)',
                      points: [
                        for (final pt in points)
                          VeTimelinePoint(pt.date, pt.price),
                      ],
                      color: scheme.primary,
                      area: true,
                      format: (v) => fmtUSD(v),
                    ),
                    if (hasUnit)
                      VeTimelineSeries(
                        name: 'Por ${baseUnitLabel(p)}',
                        points: [
                          for (final pt in points)
                            VeTimelinePoint(pt.date, pt.perUnit),
                        ],
                        color: sem.manual,
                        dashed: true,
                        dashPattern: const <double>[5, 3],
                        width: 1.6,
                        format: (v) => fmtUSD(v),
                      ),
                  ],
                ),
            ],
          ),
        ),
      ],
    );
  }

  // ── Historial de registros (editar/borrar) ──────────────────────────────

  Widget _history(BuildContext context, AppStore store, Product p) {
    final scheme = Theme.of(context).colorScheme;
    final recs = [...p.records]..sort((a, b) => a.date.compareTo(b.date));
    final shown = recs.reversed.take(30).toList();

    return Column(
      children: [
        VeEyebrow(child: const Text('HISTORIAL DE REGISTROS')),
        if (recs.isEmpty)
          const VeEmpty(
            title: 'Sin registros todavía',
            sub: 'Todo arranca con el primer precio.',
          )
        else
          VeGroup(
            children: [
              for (final r in shown)
                Row(
                  children: [
                    Expanded(
                      child: VeRow(
                        label: Text(_recordLabel(r)),
                        right: Text(fmtUSD(r.price)),
                        onTap: () => _editRecord(context, store, p, r),
                      ),
                    ),
                    VeIconBtn(
                      icon: LucideIcons.trash2,
                      danger: true,
                      onTap: () =>
                          _confirmDeleteRecord(context, store, p, r),
                      label: 'Eliminar registro',
                    ),
                  ],
                ),
            ],
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

  // ── Ajustes: código, categoría/presentación/tamaño, meta, tienda ───────

  Widget _actions(BuildContext context, AppStore store, Product p) {
    final scheme = Theme.of(context).colorScheme;
    final sizeHint = switch (_pres) {
      Presentation.weight => 'Tamaño total en g (ej. 1000)',
      Presentation.volume => 'Tamaño total en ml (ej. 2000)',
      Presentation.pack => 'Unidades del paquete (ej. 4)',
      Presentation.unit => 'Contenido (opcional, ej. 355 ml)',
    };

    // Ajustes en su Card con grupos separados por divisores — jerarquía
    // clara y nada pegado (v19). Eliminar vive en el pie del sheet.
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VeEyebrow(child: const Text('AJUSTES DEL PRODUCTO')),
        VeCard(
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
                    child: VeInput(
                      controller: _barcodeCtrl,
                      keyboardType: TextInputType.number,
                      placeholder: 'Código (opcional)',
                      semantic: 'Código de barras',
                    ),
                  ),
                  const SizedBox(width: 8),
                  VeIconBtn(
                    icon: LucideIcons.scanBarcode,
                    onTap: _scanIntoBarcode,
                    label: 'Escanear código de barras',
                  ),
                ],
              ),
              const Divider(height: 22),
              Text(
                'PRESENTACIÓN',
                style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final pr in Presentation.values)
                    VeChip(
                      active: _pres == pr,
                      onTap: () => setState(() => _pres = pr),
                      child: Text(pr.label),
                    ),
                ],
              ),
              const SizedBox(height: 10),
              VeInput(
                controller: _sizeCtrl,
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                placeholder: sizeHint,
                semantic: 'Tamaño',
              ),
              const SizedBox(height: 10),
              Text(
                'CATEGORÍA',
                style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final c in ProductCategory.values)
                    VeChip(
                      active: _cat == c,
                      onTap: () => setState(() => _cat = c),
                      child: Text(c.label),
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
                    child: VeBtn(
                      size: VeBtnSize.sm,
                      onPressed: () => _fixTarget(store, p),
                      child: const Text('Fijar meta'),
                    ),
                  ),
                  if (p.targetPrice != null) ...[
                    const SizedBox(width: 8),
                    Expanded(
                      child: VeBtn(
                        variant: VeBtnVariant.ghost,
                        size: VeBtnSize.sm,
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
                    child: VeInput(
                      controller: _lastStoreCtrl,
                      placeholder: p.latestRecord == null
                          ? '— sin registros'
                          : 'Ej. Bicentenario',
                      semantic: 'Tienda del último registro',
                    ),
                  ),
                  const SizedBox(width: 8),
                  VeBtn(
                    size: VeBtnSize.sm,
                    enabled: p.latestRecord != null,
                    onPressed: () => _saveLastStore(store, p),
                    child: const Text('Guardar'),
                  ),
                ],
              ),
              const Divider(height: 22),
              VeBtn(
                expands: true,
                icon: p.isUnavailable
                    ? LucideIcons.circleCheck
                    : LucideIcons.ban,
                onPressed: () => store.setUnavailable(p.id, !p.isUnavailable),
                child: Text(
                  p.isUnavailable
                      ? 'Marcar disponible'
                      : 'Marcar no disponible',
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// Punto de la gráfica: fecha + precio USD (+ precio por unidad base si
/// aplica; null → el pintor lo salta).
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
  void create() {
    final store = context.read<AppStore>();
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
    final scheme = Theme.of(context).colorScheme;
    final sizeHint = switch (_pres) {
      Presentation.weight => 'Tamaño total en g (opcional)',
      Presentation.volume => 'Tamaño total en ml (opcional)',
      Presentation.pack => 'Unidades del paquete (opcional)',
      Presentation.unit => 'Contenido (opcional)',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        VeField(
          label: 'Nombre',
          child: VeInput(
            controller: _nameCtrl,
            autofocus: widget.initialBarcode == null,
            placeholder: 'ej. Pasta larga 500 g',
            semantic: 'Nombre del producto',
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'CÓDIGO DE BARRAS',
          style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: VeInput(
                controller: _barcodeCtrl,
                keyboardType: TextInputType.number,
                placeholder: 'Código (opcional)',
                semantic: 'Código de barras',
              ),
            ),
            const SizedBox(width: 8),
            VeIconBtn(
              icon: LucideIcons.scanBarcode,
              onTap: _scanIntoBarcode,
              label: 'Escanear código de barras',
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
        const SizedBox(height: 14),
        Text(
          'CATEGORÍA',
          style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final c in ProductCategory.values)
              VeChip(
                active: _cat == c,
                onTap: () => setState(() => _cat = c),
                child: Text(c.label),
              ),
          ],
        ),
        const SizedBox(height: 12),
        Text(
          'PRESENTACIÓN',
          style: VeText.labelCaps(9, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final pr in Presentation.values)
              VeChip(
                active: _pres == pr,
                onTap: () => setState(() => _pres = pr),
                child: Text(pr.label),
              ),
          ],
        ),
        const SizedBox(height: 10),
        VeInput(
          controller: _sizeCtrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          placeholder: sizeHint,
          semantic: 'Tamaño',
        ),
        const SizedBox(height: 14),
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
        VeInput(
          controller: _storeCtrl,
          placeholder: 'Tienda (opcional)',
          semantic: 'Tienda',
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
      ],
    );
  }
}
