/// ─── Checkout modal (v17.2 · requisitos F, G, H) ────────────────────────────
/// «Finalizar compra» ya NO guarda en línea: abre este sheet modal que
/// configura y revisa TODO antes de guardar:
/// · Desglose AGRUPADO POR TIENDA del carrito (multitienda u tienda única).
/// · Toggle «Varias tiendas»: OFF = un solo campo de tienda para la compra
///   (autocompletado, editable y borrable); ON = cada ítem lleva su tienda.
///   Al guardar: OFF → Purchase.store = la tienda, ítems sin tienda;
///   ON → Purchase.store = null y cada PurchaseItem.store = su tienda.
/// · «Productos ya existe»: para cada ítem con barcode o nombre se consulta
///   findSimilarProduct; si hay match se avisa con «Vincular» (usa el
///   producto del libro y registra el precio tras guardar) o «Crear nuevo»
///   (addProduct con PriceRecord USD-normalizado, patrón de products_screen).
/// · Pagado (ajustado) con moneda, nota, FOTO DEL TICKET (picker JPEG 1024
///   .72 + re-aseguro con photo_compress) y botón final «Guardar compra».
/// Tras guardar: SnackBar con acción «Ver historial» → /historial, y una
/// pasada fire-and-forget de compresión de tickets viejos (requisito J).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../services/photo_compress.dart';
import '../../widgets/ui.dart';
import 'item_editor.dart';

/// Abre el modal de checkout. Devuelve true si la compra se guardó.
Future<void> showCheckoutSheet(BuildContext context) async {
  final saved = await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const CheckoutModal(),
  );
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: const Text('Compra guardada en el historial'),
      behavior: SnackBarBehavior.floating,
      action: SnackBarAction(
        label: 'Ver historial',
        onPressed: () => context.push('/historial'),
      ),
    ));
  }
}

/// Totales del carrito (USD + por moneda + unidades) — motor compartido
/// entre la pantalla Lista y este modal (antes vivía en lista_screen.dart).
({double usd, Map<Currency, double> byCurrency, int units}) cartTotals(
    List<CartItem> cart, RateContext ctx) {
  final by = <Currency, double>{};
  var usd = 0.0;
  var units = 0;
  for (final item in cart) {
    final c = CurrencyX.from(item.currency);
    final u = ctx.unitsPerUSD(c) ?? 0;
    final line = item.price * item.quantity;
    by[c] = (by[c] ?? 0) + line;
    usd += u > 0 ? line / u : 0;
    units += item.quantity;
  }
  return (usd: usd, byCurrency: by, units: units);
}

/// Construye la Purchase del carrito. [multiStore] define dónde vive la
/// tienda (requisito F). Los ítems llevan size/sizeUnit capturados en la
/// lista para que el historial muestre el peso (requisito I).
Purchase buildPurchase({
  required List<CartItem> cart,
  required RateContext ctx,
  required ({double usd, Map<Currency, double> byCurrency, int units}) totals,
  String? storeName,
  bool multiStore = false,
  double? paidTotal,
  String? paidCurrency,
  String? ticketDataUrl,
  String? notes,
}) {
  final rate = ctx.unitsPerUSD(Currency.ves) ?? 0;
  final items = cart.map((c) {
    final cur = CurrencyX.from(c.currency);
    final u = ctx.unitsPerUSD(cur) ?? 0;
    return PurchaseItem(
      name: c.name,
      quantity: c.quantity,
      priceUSD: u > 0 ? c.price / u : 0,
      originalPrice: c.price,
      currency: c.currency,
      productId: c.productId,
      store: multiStore ? c.store : null,
      size: c.size,
      sizeUnit: c.sizeUnit,
    );
  }).toList();
  return Purchase(
    id: '',
    date: DateTime.now(),
    store: multiStore ? null : storeName,
    items: items,
    totalUSD: totals.usd,
    totalBS: rate > 0 ? totals.usd * rate : 0,
    rate: rate,
    rateSourceId: ctx.sel(Currency.ves),
    igtf: false, // v14+: retirado del motor, solo display histórico
    paidTotal: paidTotal,
    paidCurrency: paidCurrency ?? (cart.isNotEmpty ? cart.first.currency : 'VES'),
    ticketPhoto: ticketDataUrl,
    notes: notes,
  );
}

/// Data URL JPEG base64 (compatibilidad con respaldos web: data:image/jpeg).
String photoToDataUrl(List<int> bytes) =>
    'data:image/jpeg;base64,${base64Encode(bytes)}';

class CheckoutModal extends StatefulWidget {
  const CheckoutModal({super.key});

  @override
  State<CheckoutModal> createState() => _CheckoutModalState();
}

class _CheckoutModalState extends State<CheckoutModal> {
  // Snapshot UNA vez (read, no watch): mutar el store al guardar no debe
  // reconstruir el modal con la lista ya vacía.
  late final AppStore _store;
  late final List<CartItem> _cart;
  late final RateContext _ctx;

  bool _multiStore = false;
  String? _singleStore;
  final _paidCtrl = TextEditingController();
  late Currency _paidCurrency;
  final _notesCtrl = TextEditingController();
  String? _ticketDataUrl;
  bool _picking = false;

  /// H: decisiones «ya existe» — itemId → true = vincular al match;
  /// ausente/false = crear nuevo producto al guardar.
  final Map<String, bool> _link = {};

  /// H: match del libro por ítem (recalculado si cambia la tienda en juego).
  final Map<String, Product?> _matches = {};

  @override
  void initState() {
    super.initState();
    _store = context.read<AppStore>();
    _cart = List<CartItem>.from(_store.cart);
    _ctx = _store.contextOf(module: RateModule.calculator);
    // Default multitienda ON si algún ítem ya trae tienda asignada.
    _multiStore = _cart.any((c) => (c.store ?? '').trim().isNotEmpty);
    _paidCurrency = CurrencyX.from(
        _cart.isNotEmpty ? _cart.first.currency : _store.settings.calcCurrency);
    for (final c in _cart) {
      _matches[c.id] = _store.findSimilarProduct(
          name: c.name, barcode: c.barcode, store: c.store);
    }
  }

  @override
  void dispose() {
    _paidCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  ({double usd, Map<Currency, double> byCurrency, int units}) get _totals =>
      cartTotals(_cart, _ctx);

  Currency get _calcCur => CurrencyX.from(_store.settings.calcCurrency);

  double get _totalInCalc {
    final t = _totals;
    if (_calcCur == Currency.usd) return t.usd;
    final u = _ctx.unitsPerUSD(_calcCur) ?? 0;
    return u > 0 ? t.usd * u : 0;
  }

  void _recomputeMatch(CartItem it) {
    _matches[it.id] = _store.findSimilarProduct(
        name: it.name, barcode: it.barcode, store: it.store);
  }

  void _setItemStore(CartItem it, String? value) {
    final patched =
        it.copyWith(store: value, clearStore: value == null || value.trim().isEmpty);
    _store.updateCartItem(it.id, patched);
    final idx = _cart.indexWhere((c) => c.id == it.id);
    if (idx >= 0) _cart[idx] = patched;
    _recomputeMatch(patched);
    setState(() {});
  }

  /// H: vincular el ítem al producto ya registrado del libro.
  void _linkTo(CartItem it, Product p) {
    final patched = it.copyWith(productId: p.id);
    _store.updateCartItem(it.id, patched);
    final idx = _cart.indexWhere((c) => c.id == it.id);
    if (idx >= 0) _cart[idx] = patched;
    _link[it.id] = true;
    setState(() {});
  }

  /// Agrupa el carrito por tienda efectiva para el desglose del modal.
  Map<String, List<CartItem>> _groupedByStore() {
    final map = <String, List<CartItem>>{};
    for (final it in _cart) {
      final s = _multiStore
          ? ((it.store ?? '').trim().isEmpty ? 'Sin asignar' : it.store!.trim())
          : ((_singleStore ?? '').trim().isEmpty ? 'Sin tienda' : _singleStore!.trim());
      (map[s] ??= []).add(it);
    }
    return map;
  }

  Future<void> _pickTicket() async {
    if (_picking) return;
    setState(() => _picking = true);
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
          source: ImageSource.camera,
          maxWidth: 1024,
          maxHeight: 1024,
          imageQuality: 72);
      if (photo == null) return;
      var bytes = await photo.readAsBytes();
      if (bytes.length > 12 * 1024 * 1024) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
              content: Text('La foto pesa más de 12 MB'),
              behavior: SnackBarBehavior.floating));
        }
        return;
      }
      // Re-asegura JPEG ≤1024 px (photo_compress): si no reduce, se conserva
      // el original del picker (nunca se agranda ni degrada a ciegas).
      final compressed = await compressJpeg(
          Uint8List.fromList(bytes), quality: 72, maxDim: 1024);
      if (compressed != null) bytes = compressed;
      if (!mounted) return;
      setState(() => _ticketDataUrl = photoToDataUrl(bytes));
    } finally {
      if (mounted) setState(() => _picking = false);
    }
  }

  /// Guarda la compra: Purchase + productos (vincular/crear) + compresión
  /// de tickets viejos (fire-and-forget). Devuelve true para cerrar el modal.
  Future<bool> _save() async {
    if (_cart.isEmpty) return true;
    final single =
        (_singleStore ?? '').trim().isEmpty ? null : _singleStore!.trim();
    final notes =
        (_notesCtrl.text).trim().isEmpty ? null : _notesCtrl.text.trim();
    final paid = parseLocaleNum(_paidCtrl.text);
    final t = _totals;

    // 1) La compra (F: tienda única vs por ítem).
    final purchase = buildPurchase(
      cart: _cart,
      ctx: _ctx,
      totals: t,
      storeName: single,
      multiStore: _multiStore,
      paidTotal: paid,
      paidCurrency: _paidCurrency.code,
      ticketDataUrl: _ticketDataUrl,
      notes: notes,
    );
    _store.addPurchase(purchase);

    // 2) Productos del libro (H): vincular → registrar precio; resto → crear.
    // _cart y purchase.items van 1:1 en el mismo orden (buildPurchase mapea).
    final vesRate = _ctx.unitsPerUSD(Currency.usd) ?? 1;
    final created = <String, String>{}; // 'nombre|tienda' → productId
    for (var i = 0; i < _cart.length; i++) {
      final it = _cart[i];
      final purchaseItem = purchase.items[i];
      final itemStore = _multiStore
          ? ((it.store ?? '').trim().isEmpty ? null : it.store!.trim())
          : single;
      final pid = it.productId;
      if (pid != null && pid.isNotEmpty) {
        // Vinculado (de origen o por «Vincular»): el precio entra al libro.
        _store.recordPurchaseItemOnProduct(pid, purchaseItem, store: itemStore);
        continue;
      }
      // Producto nuevo: reutiliza el creado en esta misma compra si ya pasó.
      final key = '${it.name.toLowerCase().trim()}|${itemStore ?? ''}';
      if (created.containsKey(key)) continue;
      // Presentación/tamaño normalizados a unidad base del catálogo.
      Presentation pres = Presentation.unit;
      double sizeBase = 1;
      String? unitBase;
      final su = it.sizeUnit;
      final s = it.size ?? 0;
      if (s > 0 && (su == 'g' || su == 'kg')) {
        pres = Presentation.weight;
        sizeBase = su == 'kg' ? s * 1000 : s;
        unitBase = 'g';
      } else if (s > 0 && (su == 'ml' || su == 'l')) {
        pres = Presentation.volume;
        sizeBase = su == 'l' ? s * 1000 : s;
        unitBase = 'ml';
      }
      final createdProduct = _store.addProduct(
        Product(
          id: '',
          name: it.name,
          barcode: it.barcode,
          category: ProductCategory.otros,
          presentation: pres,
          size: sizeBase,
          sizeUnit: unitBase,
          createdAt: DateTime.now(),
          records: const [],
        ),
        // Patrón USD-normalizado de products_screen: price USD + rate/sel.
        PriceRecord(
          id: '',
          price: purchaseItem.priceUSD,
          originalPrice: purchaseItem.originalPrice,
          currency: 'USD',
          quantity: purchaseItem.quantity,
          store: itemStore,
          rate: vesRate,
          sourceId: _ctx.sel(Currency.ves),
          date: DateTime.now(),
        ),
      );
      created[key] = createdProduct.id;
    }

    // 3) Compresión de tickets viejos (J) — fire-and-forget, sin bloquear.
    unawaited(compressOldTicketPhotos(_store));
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final t = _totals;
    final groups = _groupedByStore();
    final matchesList =
        _cart.where((c) => (_matches[c.id] != null)).toList();

    return SafeArea(
      top: false,
      child: Padding(
        // Deja sitio al teclado sin tapar el botón final.
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.92),
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 18),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
              // Cabecera.
              Row(children: [
                Expanded(
                  child: Text('Finalizar compra',
                      style: TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface)),
                ),
                IconButton(
                  tooltip: 'Cerrar',
                  icon: const Icon(Icons.close, size: 18),
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ]),
              Text(
                  '${_cart.length} ítems · ${t.units} unidades · ${t.byCurrency.length} monedas',
                  style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
              ReadWindow(
                semanticLabel: 'Total a guardar',
                child: Row(children: [
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                          '${_calcCur.code} ${fmtMoney(_totalInCalc, _calcCur)}',
                          style: VeText.displayNum(34, color: scheme.onSurface)),
                    ),
                  ),
                  Text('Total USD: ${fmtUSD(t.usd)}',
                      style: TextStyle(
                          fontSize: 11.5, color: scheme.onSurfaceVariant)),
                ]),
              ),
              // Desglose por tienda (requisito F/G: resumen final agrupado).
              for (final entry in groups.entries) ...[
                const SizedBox(height: 12),
                Row(children: [
                  Icon(Icons.storefront_outlined, size: 13, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text(entry.key,
                      style: const TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w800)),
                ]),
                const SizedBox(height: 4),
                for (final it in entry.value)
                  LedgerRow(
                    label: '${it.quantity} × ${it.name}',
                    value: fmtUSD(_itemUsd(it)),
                  ),
                const RuleDouble(),
                const SizedBox(height: 4),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text('Subtotal: ${fmtUSD(_groupUsd(entry.value))}',
                      style: VeText.displayNum(13, color: scheme.onSurface)),
                ),
                // Multitienda ON: campo de tienda por ítem.
                if (_multiStore)
                  for (final it in entry.value)
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: StoreAutocompleteField(
                        stores: _store.stores,
                        initialValue: it.store,
                        hint: 'Tienda de ${it.name}',
                        onChanged: (v) => _setItemStore(it, v),
                      ),
                    ),
              ],
              const SizedBox(height: 12),
              // Toggle multitienda (requisito F).
              Row(children: [
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text('Varias tiendas', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
                    Text(
                      _multiStore
                          ? 'Cada ítem se asigna a su tienda.'
                          : 'Una sola tienda para toda la compra.',
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                  ]),
                ),
                Switch(value: _multiStore, onChanged: (v) => setState(() => _multiStore = v)),
              ]),
              if (!_multiStore) ...[
                StoreAutocompleteField(
                  stores: _store.stores,
                  initialValue: _singleStore,
                  hint: 'Tienda de la compra (opcional)',
                  onChanged: (v) => setState(() {
                    _singleStore = v;
                    // El match «ya existe» depende de la tienda en juego.
                    for (final c in _cart) {
                      _recomputeMatch(c);
                    }
                  }),
                ),
              ],
              // H: avisos «ya existe» con Vincular / Crear nuevo.
              if (matchesList.isNotEmpty) ...[
                const SizedBox(height: 14),
                Text('YA EN TU LIBRO', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 6),
                for (final it in matchesList)
                  _MatchRow(
                    item: it,
                    match: _matches[it.id]!,
                    linked: _link[it.id] == true,
                    onLink: () => _linkTo(it, _matches[it.id]!),
                    onCreate: () => setState(() => _link[it.id] = false),
                  ),
              ],
              const SizedBox(height: 14),
              // Pagado (ajustado) + moneda (se mantiene del checkout previo).
              Text('PAGADO (AJUSTADO)', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: TextField(
                    controller: _paidCtrl,
                    keyboardType: const TextInputType.numberWithOptions(decimal: true),
                    decoration: InputDecoration(
                        hintText: 'Total: ${fmtUSD(t.usd)} · ${_calcCur.code} ${fmtMoney(_totalInCalc, _calcCur)}'),
                  ),
                ),
                const SizedBox(width: 8),
                CurrencySelect(
                  value: _paidCurrency,
                  onChanged: (c) => setState(() => _paidCurrency = c),
                ),
              ]),
              const SizedBox(height: 8),
              TextField(
                controller: _notesCtrl,
                decoration: const InputDecoration(hintText: 'Nota o descripción (opcional)'),
              ),
              const SizedBox(height: 8),
              // Foto del ticket (JPEG 1024 .72 + compress).
              Row(children: [
                OutlinedButton.icon(
                  onPressed: _picking ? null : _pickTicket,
                  icon: _picking
                      ? const SizedBox(width: 14, height: 14,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.camera_alt_outlined, size: 15),
                  label: Text(_ticketDataUrl == null ? 'Foto del ticket' : 'Foto lista',
                      style: const TextStyle(fontSize: 12.5)),
                ),
                if (_ticketDataUrl != null) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.photo, size: 14, color: scheme.primary),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('Ticket adjunto (~200 KB)',
                        style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _ticketDataUrl = null),
                    child: const Text('Quitar', style: TextStyle(fontSize: 12)),
                  ),
                ],
              ]),
              const SizedBox(height: 14),
              // Acción final única.
              SizedBox(
                width: double.infinity,
                child: PrimaryButton(
                  'Guardar compra',
                  icon: Icons.save_outlined,
                  onPressed: _cart.isEmpty
                      ? null
                      : () async {
                          final ok = await _save();
                          if (context.mounted && ok) {
                            Navigator.of(context).pop(true);
                          }
                        },
                ),
              ),
            ]),
          ),
        ),
      ),
    );
  }

  double _itemUsd(CartItem it) {
    final c = CurrencyX.from(it.currency);
    final u = _ctx.unitsPerUSD(c) ?? 0;
    return u > 0 ? it.price * it.quantity / u : 0;
  }

  double _groupUsd(List<CartItem> items) =>
      items.fold(0.0, (acc, it) => acc + _itemUsd(it));
}

/// Aviso ««Arroz» ya existe en `tienda`» con Vincular / Crear nuevo (H).
class _MatchRow extends StatelessWidget {
  const _MatchRow({
    required this.item,
    required this.match,
    required this.linked,
    required this.onLink,
    required this.onCreate,
  });

  final CartItem item;
  final Product match;
  final bool linked;
  final VoidCallback onLink;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final VeInk sem = VeColors.of(context);
    final where = match.latestRecord?.store ?? 'tu catálogo';
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: sem.warn.withValues(alpha: 0.07),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sem.warn.withValues(alpha: 0.35)),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('«${item.name}» ya existe en $where',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: scheme.onSurface)),
          const SizedBox(height: 6),
          Row(children: [
            ChipTag('Vincular', selected: linked, onTap: linked ? null : onLink),
            const SizedBox(width: 6),
            ChipTag('Crear nuevo', selected: !linked, onTap: !linked ? null : onCreate),
            const Spacer(),
            if (linked)
              Icon(Icons.check_circle_outline, size: 15, color: scheme.primary),
          ]),
        ]),
      ),
    );
  }
}
