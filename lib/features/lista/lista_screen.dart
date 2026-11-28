/// ─── Lista / «Calculadora de compras» (§9.3 · TASK-34 lenguaje Ve) ──────────
/// Hero total (odómetro) en TARJETA de superficie (v29 H-31) · presupuesto
/// de UNA línea de estado (H-32) · sección propia «CÁLCULOS DE LA LISTA»
/// con selector de tasa GRANDE (H-33) · captura por espacios lógicos
/// QUÉ·CUÁNTO·DÓNDE (H-34) · sala en vivo como entrada propia bajo el
/// título (H-37) · barra pegadiza en bottomNavigationBar (v30 V-1: jamás
/// tapa los campos) · alta rápida por nombre (libro de precios o editor) ·
/// captura manual con detalle (precio, cantidad, tienda, escáner ROI) ·
/// filas con checkbox + stepper + total tabular · checkout en SHEET Ve con
/// multitienda, «ya existe» y foto de ticket · vuelto MULTI-DIVISA ·
/// dividir con propina.
///
/// v29 (H-35/H-36): plantillas y toggle «Más» ELIMINADOS — nada se esconde:
/// las frecuentes las cubre el alta rápida + el picker del estado vacío y
/// los totales son la constancia del checkout.
///
/// Decisiones de iconos (v17.2): escanear = Lucide scanBarcode, historial =
/// Lucide receiptText, sala = Lucide users.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../core/analytics.dart' as an;
import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../room/room_controller.dart';
import '../../services/quick_actions.dart' show scanRequest;
import '../../widgets/app_tips.dart';
import '../../widgets/app_tour.dart' show TourKeys;
import '../../widgets/rate_sheet.dart';
import '../../widgets/ui.dart';
import 'cachea_sheet.dart';
import 'checkout_modal.dart';
import 'item_editor.dart';
import 'roi_scanner.dart';
import '../room/room_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorave/providers/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:valorave/core/ve_theme.dart';

class ListaScreen extends ConsumerStatefulWidget {
  const ListaScreen({super.key});

  @override
  ConsumerState<ListaScreen> createState() => _ListaScreenState();
}

class _ListaScreenState extends ConsumerState<ListaScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _quickCtrl = TextEditingController();
  final _storeCtrl =
      TextEditingController(); // tienda sugerida (anti-duplicado)
  String _addCurrency = 'VES';
  String _storeName = '';

  @override
  void initState() {
    super.initState();
    // Shortcut «Escanear» del launcher: si hay petición pendiente, abre el
    // escáner en el primer frame (quick_actions → scanRequest).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (scanRequest.value) {
        scanRequest.value = false;
        _scanItem(ref.read(appStoreProvider));
      }
    });
    scanRequest.addListener(_onScanRequest);
  }

  void _onScanRequest() {
    if (!mounted || !scanRequest.value) return;
    scanRequest.value = false;
    _scanItem(ref.read(appStoreProvider));
  }

  @override
  void dispose() {
    scanRequest.removeListener(_onScanRequest);
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    _quickCtrl.dispose();
    _storeCtrl.dispose();
    super.dispose();
  }

  /// Escanea con el escáner ROI (solo recuadro central) y resuelve el código:
  /// · Producto del libro con precio → directo al carrito.
  /// · Ítem ya en la lista → suma 1 (aviso honesto, sin duplicar).
  /// · Nada registrado → diálogo honesto con «Repetir escaneo» y
  ///   «Agregar manualmente» (requisito E).
  Future<void> _scanItem(AppStore store) async {
    final code = await RoiScannerScreen.scan(context);
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
      // El texto se lee ANTES de disponer el controller (fix leak: cada
      // apertura del diálogo dejaba un controller vivo para siempre).
      final manual = ctrl.text.trim();
      ctrl.dispose();
      if (ok != true || !mounted) return;
      if (manual.isEmpty) return;
      await _resolveScannedCode(store, manual);
      return;
    }
    if (code == null || code.isEmpty) return;
    await _resolveScannedCode(store, code);
  }

  /// Resolución de un código escaneado/escrito a mano (requisitos E y D).
  Future<void> _resolveScannedCode(AppStore store, String scanned) async {
    // 1) ¿Producto registrado en el libro?
    final matches = store.products.where((p) => p.barcode == scanned).toList();
    if (matches.isNotEmpty) {
      final p = matches.first;
      final last = p.latestRecord;
      if (last != null) {
        // Precio vigente del libro → directo al carrito.
        store.addToCart(
          CartItem(
            id: '',
            productId: p.id,
            name: p.name,
            quantity: int.tryParse(_qtyCtrl.text) ?? 1,
            price: last.originalPrice,
            currency: last.currency,
            barcode: p.barcode,
          ),
        );
        if (_storeName.trim().isNotEmpty) store.addStore(_storeName);
        showToast(
          context,
          '${p.name} · ${fmtMoneyCode(last.originalPrice, last.currency)} agregado',
          kind: ToastKind.ok,
        );
        return;
      }
      // Registrado pero sin precios → editor prellenado (nombre + código).
      await _openEditorForCode(store, scanned, presetName: p.name);
      return;
    }
    // 2) ¿Ya está en la lista? → suma 1 (no duplica renglón).
    final inCart = store.cart.where((c) => c.barcode == scanned).toList();
    if (inCart.isNotEmpty) {
      final c = inCart.first;
      store.updateCartItem(
        c.id,
        c.copyWith(quantity: (c.quantity + 1).clamp(1, 999)),
      );
      showToast(context, '${c.name} ya está en tu lista — sumé 1');
      return;
    }
    // 3) Código sin registrar → diálogo honesto (requisito E).
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Código no registrado'),
        content: Text('El código $scanned no está en tu libro ni en la lista.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dctx, 'rescan'),
            child: const Text('Repetir escaneo'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dctx, 'manual'),
            child: const Text('Agregar manualmente'),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (action == 'rescan') {
      await _scanItem(store);
      return;
    }
    if (action == 'manual') {
      await _openEditorForCode(store, scanned);
    }
  }

  /// Abre el editor de ítems prellenado con el código escaneado.
  Future<void> _openEditorForCode(
    AppStore store,
    String code, {
    String? presetName,
  }) async {
    final res = await showItemEditorSheet(
      context,
      store: store,
      presetName: presetName,
      presetBarcode: code,
    );
    await _resolveEditorResult(store, res);
  }

  /// Resultado del editor: valida y agrega (el editor nunca entrega un ítem
  /// incompleto, pero la validación del caller se conserva por contrato).
  Future<void> _resolveEditorResult(
    AppStore store,
    ItemEditorResult? res,
  ) async {
    final item = res?.item;
    if (res == null || item == null || res.remove) return;
    if (!mounted) return;
    if (item.name.trim().isEmpty || item.price <= 0) {
      showToast(
        context,
        'Nombre y precio válidos (> 0) requeridos',
        kind: ToastKind.warn,
      );
      return;
    }
    store.addToCart(item);
    if (_storeName.trim().isNotEmpty) store.addStore(_storeName);
  }

  /// Alta rápida por nombre (prototipo List.tsx): busca en el libro de
  /// precios → con precio vigente entra directo al carrito; sin precio (o
  /// desconocido) abre el editor prellenado con el nombre.
  Future<void> _quickAdd(AppStore store) async {
    final name = _quickCtrl.text.trim();
    if (name.isEmpty) {
      showToast(
        context,
        'Escribe el nombre de un producto',
        kind: ToastKind.warn,
      );
      return;
    }
    final q = fold(name.toLowerCase());
    final match = store.products
        .where((p) => fold(p.name.toLowerCase()) == q)
        .firstOrNull;
    if (match != null) {
      final last = match.latestRecord;
      if (last != null) {
        _addFromBook(store, match);
        _quickCtrl.clear();
        return;
      }
      // Registrado sin precio → editor prellenado (nombre + código).
      await _openEditorForCode(
        store,
        match.barcode ?? '',
        presetName: match.name,
      );
      _quickCtrl.clear();
      return;
    }
    // Desconocido → editor con el nombre ya escrito.
    await _openEditorForCode(store, '', presetName: name);
    if (!mounted) return;
    _quickCtrl.clear();
  }

  /// Agrega un producto del libro con su precio vigente (patrón del
  /// escáner y de la ficha de producto).
  void _addFromBook(AppStore store, Product p) {
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
  }

  void _addItem(AppStore store) {
    final name = _nameCtrl.text.trim();
    final price = parseLocaleNum(_priceCtrl.text) ?? 0;
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    if (name.isEmpty || price <= 0) {
      showToast(
        context,
        'Escribe nombre y precio válidos',
        kind: ToastKind.warn,
      );
      return;
    }
    // v21.2: toque de luz al comprometer el ítem — feedback físico del
    // «ya quedó», complementa el toast (no-op en web).
    HapticFeedback.lightImpact();
    store.addToCart(
      CartItem(
        id: '',
        name: name,
        quantity: qty.clamp(1, 999),
        price: price,
        currency: _addCurrency,
        store: _storeName.trim().isEmpty ? null : _storeName.trim(),
      ),
    );
    if (_storeName.trim().isNotEmpty) store.addStore(_storeName);
    _nameCtrl.clear();
    _priceCtrl.clear();
    _qtyCtrl.text = '1';
  }

  /// Sala: conectado → pantalla de la sala; sin sala → crear/unirse.
  void _openRoom(BuildContext context) {
    final room = ref.read(roomControllerProvider);
    if (room.connected) {
      context.push('/sala-viva');
    } else {
      showRoomSheet(context);
    }
  }

  /// «Dividir la cuenta» (barra inferior): mismo panel del checkout, en su
  /// propio sheet (v19: el reparto es cosa de AL PAGAR).
  Future<void> _openDividirSheet(
    RateContext ctx,
    Currency calcCur,
    double totalInCalc,
    double totalUsd,
  ) {
    return showVeSheet(
      context: context,
      title: 'Dividir la cuenta',
      builder: (_) => DividirCuentaPanel(
        totalUsd: totalUsd,
        totalInCalc: totalInCalc,
        calcCur: calcCur,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(appStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    final room = ref.watch(roomControllerProvider);
    final ctx = store.contextOf(module: RateModule.calculator);
    final calcCur = CurrencyX.from(store.settings.calcCurrency);
    final totals = cartTotals(store.cart, ctx);
    final double totalInCalc = calcCur == Currency.usd
        ? totals.usd
        : (ctx.unitsPerUSD(calcCur) ?? 0) > 0
        ? totals.usd * (ctx.unitsPerUSD(calcCur) ?? 0.0)
        : 0.0;
    final uCalc = ctx.unitsPerUSD(calcCur) ?? 0;
    // Sugerencia pasiva anti-duplicado de tienda (nunca bloquea).
    final typed = _storeName.trim();
    final String? rawSuggest = typed.length >= 3
        ? an.findSimilarStore(typed, store.stores)
        : null;
    final String? suggestion = (rawSuggest != null && rawSuggest != typed)
        ? rawSuggest
        : null;
    final bool hasCart = store.cart.isNotEmpty;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      // v30 (V-1): la barra pegadiza vive en bottomNavigationBar — el cuerpo
      // se acota a su medida y NADA queda tapado (antes flotaba en un
      // Positioned sobre el ListView y cortaba la fila Cant./Precio/moneda).
      bottomNavigationBar: hasCart
          ? VeStickyBar(
              children: [
                // FittedBox scaleDown: con montos largos o pantallas
                // angostas la etiqueta se REDUCE antes que desbordar.
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: VeBtn(
                    variant: VeBtnVariant.secondary,
                    size: VeBtnSize.lg,
                    icon: LucideIcons.splitSquareHorizontal,
                    onPressed: () => _openDividirSheet(
                      ctx,
                      calcCur,
                      totalInCalc,
                      totals.usd,
                    ),
                    child: const Text('Dividir cuenta'),
                  ),
                ),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  child: VeBtn(
                    variant: VeBtnVariant.primary,
                    size: VeBtnSize.lg,
                    icon: LucideIcons.wallet,
                    onPressed: () => showCheckoutSheet(context),
                    child: Text(
                      'Cerrar compra · ${fmtMoney(totalInCalc, calcCur)}',
                    ),
                  ),
                ),
              ],
            )
          : null,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          // v32 (orden del dueño): el TÍTULO VA SOLO — sin iconos a la
          // derecha. v34: REJERARQUIZACIÓN de la pantalla (orden del
          // dueño) — primero lo que se hace todos los días (ver el total y
          // capturar productos), después la lista viva, y AL FINAL la
          // configuración y las puertas de navegación.
          VeTitle(
            sub: Text('Presupuesto y vuelto'),
            child: Text('Lista de compras'),
          ),
          const TipsTrigger(scope: 'lista'),
          // ── 1 · El héroe: el total de la compra (v29 H-31).
          ReadWindow(
            semanticLabel:
                'Total de la compra: ${fmtMoney(totalInCalc, calcCur)} ${calcCur.code}',
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(14),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        'TOTAL DE LA COMPRA',
                        style: VeText.labelCaps(
                          11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                      // v23.3 (gate visual): 8 de respiro — a 6 el badge
                      // «Bs» se pegaba al rótulo a 390.
                      const SizedBox(width: 8),
                      // Divisa de cálculo SIEMPRE visible junto a la cifra
                      // (v17.5).
                      CurrencyTag(calcCur.code),
                      const Spacer(),
                      // Contador de ítems VISIBLE (fix): antes un LiveBadge
                      // con live:false — que colapsa a SizedBox.shrink() y
                      // jamás se pintaba (elemento muerto en el héroe).
                      Stamp(
                        '${store.cart.length} '
                        '${store.cart.length == 1 ? 'ítem' : 'ítems'}',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Expanded(
                        // H-31: escala gradual — la cifra display 30 cede
                        // tamaño antes que romper la línea.
                        child: FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: AnimatedNumber(
                            totalInCalc,
                            // Héroe: cifra 30 tabular (v23.2: escala única
                            // con el Conversor).
                            style: VeText.displayNum(
                              30,
                              color: scheme.onSurface,
                            ),
                            decimals: smartDecimals(totalInCalc, calcCur),
                          ),
                        ),
                      ),
                      // Extra USD al lado (si la moneda de cálculo NO es
                      // USD).
                      if (calcCur != Currency.usd && totals.usd > 0)
                        Padding(
                          padding: const EdgeInsets.only(left: 10, bottom: 4),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              const Flag(Currency.usd, size: 14),
                              const SizedBox(height: 2),
                              Text(
                                '≈ ${fmtUSD(totals.usd)}',
                                textAlign: TextAlign.end,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w700,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                  color: scheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          // ── 2 · Zona de captura (ancla del tour v17.8) · v34: SUBE justo
          // debajo del total — es lo que se hace TODOS los días; la
          // configuración vive abajo.
          KeyedSubtree(
            key: TourKeys.listaAgregar,
            child: Padding(
              padding: const EdgeInsets.only(top: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VeEyebrow(child: const Text('AGREGAR PRODUCTO')),
                  // Alta rápida por nombre (prototipo): libro de precios o
                  // editor prellenado.
                  Row(
                    children: [
                      Expanded(
                        child: VeInput(
                          controller: _quickCtrl,
                          placeholder: 'Agregar producto…',
                          onSubmitted: (_) => _quickAdd(store),
                          semantic: 'Agregar producto',
                        ),
                      ),
                      const SizedBox(width: 8),
                      VeBtn(
                        variant: VeBtnVariant.primary,
                        size: VeBtnSize.sm,
                        icon: LucideIcons.plus,
                        onPressed: () => _quickAdd(store),
                        semantic: 'Agregar',
                        child: const SizedBox(width: 13),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // Captura manual con detalle: nombre · cantidad ·
                  // escáner · precio + moneda · tienda (sugerencia).
                  VeCard(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      children: [
                        // v29 (H-34): captura por espacios lógicos — QUÉ
                        // (Producto · escáner) · CUÁNTO (Cant. · Precio ·
                        // moneda) · DÓNDE (Tienda en fila propia) · acción
                        // a todo lo ancho.
                        // ── QUÉ ──
                        Row(
                          children: [
                            Expanded(
                              child: VeInput(
                                key: const Key('lista-nombre'),
                                controller: _nameCtrl,
                                placeholder: 'Producto',
                                semantic: 'Nombre del producto',
                              ),
                            ),
                            const SizedBox(width: 8),
                            // v32 (orden del dueño): el ESCANER se ve — 40
                            // visual / 18 de glifo, centrado contra el input.
                            VeIconBtn(
                              icon: LucideIcons.scanBarcode,
                              size: 40,
                              iconSize: 18,
                              onTap: () => _scanItem(store),
                              label: 'Escanear código de barras',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // ── CUÁNTO ──
                        Row(
                          children: [
                            SizedBox(
                              width: 64,
                              child: VeInput(
                                key: const Key('lista-cant'),
                                controller: _qtyCtrl,
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                placeholder: 'Cant.',
                                semantic: 'Cantidad',
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: VeInput(
                                key: const Key('lista-precio'),
                                controller: _priceCtrl,
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                      decimal: true,
                                    ),
                                placeholder: 'Precio',
                                semantic: 'Precio unitario',
                              ),
                            ),
                            const SizedBox(width: 8),
                            CurrencySelect(
                              value: CurrencyX.from(_addCurrency),
                              onChanged: (c) =>
                                  setState(() => _addCurrency = c.code),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        // ── DÓNDE ──
                        VeInput(
                          key: const Key('lista-tienda'),
                          controller: _storeCtrl,
                          onChanged: (v) => setState(() => _storeName = v),
                          placeholder: 'Tienda',
                          semantic: 'Tienda',
                        ),
                        if (suggestion != null)
                          // Sugerencia PASIVA anti-duplicado: nunca bloquea
                          // el alta.
                          Padding(
                            padding: const EdgeInsets.only(top: 6),
                            child: TapScale(
                              onTap: () {
                                _storeCtrl.text = suggestion;
                                setState(() => _storeName = suggestion);
                              },
                              child: Row(
                                children: [
                                  Icon(
                                    LucideIcons.lightbulb,
                                    size: 13,
                                    color: scheme.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Flexible(
                                    child: Text(
                                      '¿Quizá quisiste «$suggestion»?',
                                      style: TextStyle(
                                        fontSize: 13.5,
                                        fontWeight: FontWeight.w600,
                                        color: scheme.primary,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        const SizedBox(height: 12),
                        VeBtn(
                          variant: VeBtnVariant.primary,
                          expands: true,
                          icon: LucideIcons.plus,
                          onPressed: () => _addItem(store),
                          child: const Text('Agregar a la lista'),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          // ── 3 · Lista de compras (lo capturado, a la vista).
          if (!hasCart)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: VeEmpty(
                icon: LucideIcons.shoppingCart,
                title: 'Lista vacía',
                sub:
                    'Escribe el producto, escanea su código o elige de '
                    'tu libro de precios.',
                action: VeBtn(
                  size: VeBtnSize.sm,
                  variant: VeBtnVariant.secondary,
                  icon: LucideIcons.listPlus,
                  onPressed: () => _openProductPicker(store),
                  child: const Text('Elegir de mis productos'),
                ),
              ),
            )
          else ...[
            Padding(
              padding: const EdgeInsets.only(top: 14),
              child: VeEyebrow(
                right: VeBtn(
                  variant: VeBtnVariant.ghost,
                  size: VeBtnSize.sm,
                  onPressed: () => store.clearCart(),
                  child: const Text('Vaciar'),
                ),
                child: const Text('EN LA LISTA'),
              ),
            ),
            VeGroup(
              children: [
                for (final item in store.cart)
                  _CartRow(
                    item: item,
                    ctx: ctx,
                    onChecked: (v, by) => store.updateCartItem(
                      item.id,
                      item.copyWith(
                        checked: v,
                        checkedBy: v ? (by ?? '') : null,
                        clearCheckedBy: !v,
                      ),
                    ),
                    onQty: (q) => store.updateCartItem(
                      item.id,
                      item.copyWith(quantity: q.clamp(1, 999)),
                    ),
                    onRemove: () => store.removeFromCart(item.id),
                    onEdit: () => _editCartItem(store, item),
                  ),
              ],
            ),
            // Aviso honesto de tasa faltante para la divisa de cálculo.
            if (uCalc <= 0 && calcCur != Currency.usd)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.triangleAlert,
                      size: 13,
                      color: VeColors.of(context).warn,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Sin tasa viva para ${calcCur.code} — el total en esa moneda no se calcula.',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: VeColors.of(context).warn,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
          ],
          // ── 4 · Cálculos de la lista (v29 H-33): en qué moneda se suma y
          // con qué tasa. v34: vive tras la lista — es configuración.
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _CalculosLista(
              store: store,
              calcCur: calcCur,
              onCalcCurrency: (c) => store.setSetting('calcCurrency', c.code),
            ),
          ),
          // ── 5 · Presupuesto de UNA línea de estado (v29 H-32).
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _PanelPresupuesto(
              store: store,
              ctx: ctx,
              totalUsd: totals.usd,
            ),
          ),
          // ── 6 · Modo Cachea (v27.3 · v32): fila delineada a todo lo
          // ancho, gemela de Sala/Historial.
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: _FilaEntrada(
              icon: LucideIcons.wallet,
              title: 'Modo Cachea',
              sub: totalInCalc > 0
                  ? 'Simula inicial + cuotas quincenales, sin intereses.'
                  : 'Agrega productos y simula inicial + cuotas.',
              semantic: 'Modo Cachea',
              enabled: totalInCalc > 0,
              onTap: () => showCacheaSheet(
                context,
                ref: ref,
                totalInCalc: totalInCalc,
                calcCur: calcCur,
                totalUsd: totals.usd,
                ctx: ctx,
              ),
            ),
          ),
          // ── 7 · Puertas de navegación (v34): Sala en vivo e Historial
          // agrupadas al final en UN solo bloque con hairline — la Lista
          // es de capturar; salir a otro lado va abajo.
          Padding(
            padding: const EdgeInsets.only(top: 14),
            child: VeGroup(
              children: [
                // v29 (H-37): entrada propia de la Sala en vivo — con sala
                // activa muestra nombre, «En vivo», código y personas.
                // Ancla del tour conservada.
                KeyedSubtree(
                  key: TourKeys.listaSala,
                  child: _SalaEntry(
                    room: room,
                    onTap: () => _openRoom(context),
                  ),
                ),
                _FilaEntrada(
                  icon: LucideIcons.receiptText,
                  title: 'Historial de compras',
                  sub: 'Tus compras cerradas, con su tasa y su tienda.',
                  semantic: 'Historial de compras',
                  onTap: () => context.push('/historial'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Picker de productos del libro (prototipo PickSheet): busca, agrega con
  /// el precio vigente o avisa si aún no tiene.
  Future<void> _openProductPicker(AppStore store) {
    return showVeSheet(
      context: context,
      title: 'Mis productos',
      builder: (_) => _ProductPicker(store: store),
    );
  }

  /// Editar ítem → editor con detalle (tienda, código, peso) en sheet Ve.
  Future<void> _editCartItem(AppStore store, CartItem item) async {
    final res = await showItemEditorSheet(
      context,
      store: store,
      initial: item,
      removable: true,
    );
    if (res == null || !mounted) return;
    if (res.remove) {
      store.removeFromCart(item.id);
      return;
    }
    final edited = res.item;
    if (edited == null) return;
    if (edited.name.trim().isEmpty || edited.price <= 0) {
      showToast(
        context,
        'Nombre y precio válidos (> 0) requeridos',
        kind: ToastKind.warn,
      );
      return;
    }
    store.updateCartItem(item.id, edited);
  }
}

/// ─── Cálculos de la lista (v29 · H-33) ──────────────────────────────────────
/// Sección propia FUERA del presupuesto: en qué MONEDA se suma la lista y
/// con qué TASA — cosa general de toda la pantalla. El selector de tasa es
/// el control GRANDE del Conversor (H-24): delineado a todo lo ancho con
/// sello + nombre en tinta plena («BCV · Oficial», el «Oficial» siempre en
/// oficiales) + «1 USD = X VES · hace 16 h» + chevron; al tocar abre la
/// hoja de fuentes del módulo Lista (RateModule.calculator — el override
/// por módulo §9.3; sin override cae a la global). Con cálculo en USD no
/// hay tasa que elegir: el dólar es la base de toda la app.
class _CalculosLista extends StatelessWidget {
  const _CalculosLista({
    required this.store,
    required this.calcCur,
    required this.onCalcCurrency,
  });

  final AppStore store;
  final Currency calcCur;
  final ValueChanged<Currency> onCalcCurrency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VeEyebrow(child: const Text('CÁLCULOS DE LA LISTA')),
        // Moneda en que se suma TODO lo capturado.
        Row(
          children: [
            Expanded(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  'La lista se suma en',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CurrencySelect(value: calcCur, onChanged: onCalcCurrency),
          ],
        ),
        const SizedBox(height: 10),
        if (RateSource.sourcesFor(calcCur).isNotEmpty)
          _SelectorTasa(store: store, currency: calcCur)
        else
          // USD: la base del cálculo — no hay tasa que elegir.
          Row(
            children: [
              Icon(LucideIcons.info, size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'El cálculo en USD es directo — el dólar es la base de la app.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// v29 (H-33): selector de tasa GRANDE — el mismo lenguaje del Conversor
/// (H-24): control delineado a todo lo ancho, sello + nombre + tasa viva +
/// frescura + chevron. Abre la hoja de fuentes (todas las opciones con su
/// cifra, la activa marcada).
class _SelectorTasa extends ConsumerWidget {
  const _SelectorTasa({required this.store, required this.currency});

  final AppStore store;
  final Currency currency;

  /// Nombre ÚNICO en una sola forma, con «Oficial» siempre en oficiales
  /// (v28 home / v29 H-33: mismo lenguaje en toda la app).
  String _nombreFuente(RateSource? src) {
    if (src == null) return currency.code;
    return src.label.contains(src.category.label)
        ? src.label
        : '${src.label} · ${src.category.label}';
  }

  Future<void> _openSourcesSheet(BuildContext context, WidgetRef ref) async {
    final currentId = store.sourceFor(currency, module: RateModule.calculator);
    await showRateSheet(
      context,
      ref: ref,
      currency: currency,
      ctx: store.contextOf(module: RateModule.calculator),
      currentId: currentId,
      title: 'Tasa del módulo Lista · ${currency.label}',
      onPick: (id) =>
          store.setModuleRateSource(RateModule.calculator, currency, id),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final currentId = store.sourceFor(currency, module: RateModule.calculator);
    final current = RateSource.of(currentId);
    final ctx = store.contextOf(module: RateModule.calculator);
    final rate = ctx.unitsPerUSD(currency) ?? 0;
    final entry = store.board.sources[currentId];
    final when = entry?.updatedAt ?? store.board.fetchedAt;
    final frescura = current?.category == SourceCategory.manual
        ? 'tu tasa manual'
        : (when != null ? timeAgo(when) : 'sin fecha aún');

    return Semantics(
      button: true,
      label: 'Tasa de cálculo de la lista',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openSourcesSheet(context, ref),
          borderRadius: BorderRadius.circular(12),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.ve.colorScheme.border),
            ),
            child: Row(
              children: [
                if (current != null) ...[
                  SourceSeal(current.category),
                  const SizedBox(width: 8),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _nombreFuente(current),
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          rate > 0
                              ? '1 USD = ${fmtRatePrecise(rate, store.settings.precision)} ${currency.code} · $frescura'
                              : 'Sin tasa disponible para ${currency.code}',
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.5,
                            fontWeight: FontWeight.w500,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  LucideIcons.chevronDown,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─── Fila de ítem del carrito (prototipo List.tsx) ──────────────────────────
/// Checkbox de comprado + nombre (tachado y tenue al comprar) + subtítulo
/// (tienda · precio c/u · peso · quién lo marcó) + stepper −/+ + total
/// tabular a la derecha. Fondo subtle/50 en comprados; tocar el cuerpo abre
/// la hoja de edición; «Quitar» vive en esa hoja.
class _CartRow extends ConsumerWidget {
  const _CartRow({
    required this.item,
    required this.ctx,
    required this.onChecked,
    required this.onQty,
    required this.onRemove,
    required this.onEdit,
  });

  final CartItem item;
  final RateContext ctx;
  final void Function(bool, String?) onChecked;
  final ValueChanged<int> onQty;
  final VoidCallback onRemove;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shad = context.ve;
    final scheme = shad.colorScheme;
    final c = CurrencyX.from(item.currency);
    // Detalle multitienda + peso capturado (v17.2), si existe.
    final extras = <String>[
      if ((item.store ?? '').trim().isNotEmpty) item.store!.trim(),
      if ((item.size ?? 0) > 0)
        '${fmtNum(item.size!, decimals: item.size! % 1 == 0 ? 0 : 2)} ${item.sizeUnit ?? ''}'
            .trim(),
    ];
    final sub = [
      '${fmtCurrency(item.price, c)} c/u',
      ...extras,
      if (item.checkedBy != null && item.checkedBy!.isNotEmpty)
        'marcó ${item.checkedBy}',
    ].join(' · ');
    final muted = item.checked
        ? scheme.mutedForeground.withValues(alpha: 0.6)
        : scheme.mutedForeground;

    return GestureDetector(
      onLongPress: onEdit,
      child: Container(
        color: item.checked ? scheme.muted.withValues(alpha: 0.5) : null,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        child: Row(
          children: [
            VeCheckbox(
              value: item.checked,
              onChanged: () => onChecked(!item.checked, 'Yo'),
              label: 'Marcar ${item.name}',
            ),
            const SizedBox(width: 12),
            // Cuerpo: tocar abre la hoja de edición.
            Expanded(
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onEdit,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        item.name,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          // v20 (orden del dueño): tachado MEJORADO — línea
                          // más gruesa y bien trazada sobre texto atenuado;
                          // el nombre se lee igual (no desaparece).
                          decoration: item.checked
                              ? TextDecoration.lineThrough
                              : null,
                          decorationThickness: item.checked ? 1.8 : null,
                          decorationColor: scheme.mutedForeground.withValues(
                            alpha: 0.85,
                          ),
                          color: item.checked
                              ? scheme.mutedForeground.withValues(alpha: 0.75)
                              : scheme.foreground,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        sub,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: muted,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 10),
            VeStepper(
              value: item.quantity,
              min: 1,
              max: 999,
              onChanged: onQty,
              semantic: 'Cantidad de ${item.name}',
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 68,
              child: Text(
                fmtMoney(item.price * item.quantity, c),
                textAlign: TextAlign.end,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  fontFeatures: const [FontFeature.tabularFigures()],
                  // v20: el TOTAL no se tacha — el monto sigue legible
                  // (dato útil aunque el ítem ya esté comprado); solo se
                  // atenúa. Antes el doble tachado ensuciaba la fila.
                  color: item.checked ? muted : scheme.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Presupuesto de UNA línea de estado (v29 · H-32) ───────────────────────
/// La tarjeta que fija el tope del mes:
/// · Eyebrow «PRESUPUESTO DEL MES».
/// · Barra de progreso h6 (tinta normal · warn > 80 % · neg excedido).
/// · UNA línea de estado («Restan X» / «Excedido X» / «Tu tope de gasto —
///   toca para fijarlo», con FittedBox anti-rotura) + el tope o «sin tope»
///   a la derecha.
/// · El pulso del carrito («En carrito…») en su propia línea.
/// Tocar el cuerpo abre la hoja que fija el tope. La hoja explica SOLO lo
/// necesario en dos líneas (qué hace + qué significan ámbar/rojo).
class _PanelPresupuesto extends ConsumerWidget {
  const _PanelPresupuesto({
    required this.store,
    required this.ctx,
    required this.totalUsd,
  });

  final AppStore store;
  final RateContext ctx;
  final double totalUsd;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shad = context.ve;
    final scheme = shad.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final budget = store.data.budget;
    final bCur = CurrencyX.from(budget.currency);
    final u = ctx.unitsPerUSD(bCur) ?? 0;
    final budgetUsd = u > 0 ? budget.amount / u : 0.0;
    final pct = budgetUsd > 0 ? (totalUsd / budgetUsd * 100) : 0.0;
    final over = budgetUsd > 0 && totalUsd > budgetUsd;
    final fill = over ? ink.neg : (pct > 80 ? ink.warn : scheme.foreground);
    final hasTope = budget.amount > 0;

    // «En carrito»: ítems marcados + su monto convertido.
    var cartUsd = 0.0;
    var cartCount = 0;
    for (final it in store.cart.where((c) => c.checked)) {
      cartCount++;
      final iu = ctx.unitsPerUSD(CurrencyX.from(it.currency)) ?? 0;
      if (iu > 0) cartUsd += it.price * it.quantity / iu;
    }
    final cartText = u > 0
        ? 'En carrito: $cartCount ${cartCount == 1 ? 'ítem' : 'ítems'}'
              ' · ${fmtMoney(cartUsd * u, bCur)}'
        : 'En carrito: $cartCount ${cartCount == 1 ? 'ítem' : 'ítems'}';

    final diffB = u > 0 ? (budgetUsd - totalUsd) * u : 0.0;

    return VeCard(
      onTap: () => _openBudgetSheet(context),
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'PRESUPUESTO DEL MES',
            style: VeText.labelCaps(11, color: scheme.mutedForeground),
          ),
          const SizedBox(height: 10),
          // Barra h6 redondeada: pista subtle; tinta / warn / neg.
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: SizedBox(
              height: 6,
              child: Stack(
                children: [
                  Container(color: scheme.muted),
                  FractionallySizedBox(
                    widthFactor: (pct / 100).clamp(0.0, 1.0),
                    child: Container(color: fill),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          // H-32: UNA línea de estado + el tope (o «sin tope») a la derecha.
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text.rich(
                    TextSpan(
                      text: hasTope ? (over ? 'Excedido ' : 'Restan ') : null,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        color: scheme.mutedForeground,
                      ),
                      children: hasTope
                          ? [
                              TextSpan(
                                text: u > 0 ? fmtMoney(diffB.abs(), bCur) : '—',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w600,
                                  color: over ? ink.neg : scheme.foreground,
                                ),
                              ),
                            ]
                          : [
                              TextSpan(
                                text: 'Tu tope de gasto — toca para fijarlo',
                                style: TextStyle(
                                  fontFamily: 'Inter',
                                  fontSize: 13.5,
                                  color: scheme.mutedForeground,
                                ),
                              ),
                            ],
                    ),
                    maxLines: 1,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  hasTope
                      ? 'tope ${fmtMoney(budget.amount, bCur)}'
                      : 'sin tope',
                  maxLines: 1,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: hasTope ? scheme.foreground : scheme.mutedForeground,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          // H-32: el pulso del carrito, en su propia línea.
          FittedBox(
            fit: BoxFit.scaleDown,
            alignment: Alignment.centerLeft,
            child: Text(
              cartText,
              maxLines: 1,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                fontWeight: FontWeight.w500,
                color: ink.pos,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _openBudgetSheet(BuildContext context) {
    return showVeSheet(
      context: context,
      title: 'Presupuesto',
      builder: (_) => _BudgetSheet(store: store),
    );
  }
}

/// Editor del presupuesto (v19: MoneyField con miles en vivo; la MONEDA se
/// elige y queda fija aunque aún no haya monto — bug del dueño). Cambiar la
/// divisa conserva el monto vigente (o el tecleado si hay): setBudget ya
/// NUNCA resetea la moneda.
class _BudgetSheet extends ConsumerStatefulWidget {
  const _BudgetSheet({required this.store});

  final AppStore store;

  @override
  ConsumerState<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends ConsumerState<_BudgetSheet> {
  final _ctrl = TextEditingController();
  late Currency _cur;

  @override
  void initState() {
    super.initState();
    _cur = CurrencyX.from(widget.store.data.budget.currency);
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _pickCurrency(Currency c) {
    // Cambia la divisa conservando el monto vigente (o el tecleado si hay).
    final v = parseLocaleNum(_ctrl.text) ?? widget.store.data.budget.amount;
    widget.store.setBudget(v, c.code);
    setState(() => _cur = c);
  }

  void _save() {
    final v = parseLocaleNum(_ctrl.text);
    if (v == null || v <= 0) {
      showToast(context, 'Ingresa un monto mayor que 0', kind: ToastKind.warn);
      return;
    }
    widget.store.setBudget(v, _cur.code);
    Navigator.of(context).pop();
  }

  /// v20: quitar el tope (monto 0) conservando la moneda elegida —
  /// setBudget(0) ya NO resetea la divisa (v19).
  void _clear() {
    widget.store.setBudget(0, _cur.code);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final budget = widget.store.data.budget;
    final scheme = context.ve.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // v29 (H-32): la hoja explica SOLO lo necesario en DOS líneas —
        // qué hace el tope y qué significan ámbar/rojo.
        Text(
          'Es tu tope de gasto del mes: la barra de la Lista se llena con '
          'el total del carrito.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            height: 1.45,
            color: scheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Ámbar avisa que pasaste el 80 % del tope; rojo, que ya te '
          'excediste.',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            height: 1.45,
            color: scheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 14),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: VeField(
                label: 'Tope del mes',
                hint: 'La barra de la lista se calcula con este valor.',
                child: MoneyField(
                  controller: _ctrl,
                  decoration: InputDecoration(
                    hintText: budget.amount > 0
                        ? fmtMoney(budget.amount, _cur)
                        : 'Presupuesto del mes',
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            CurrencySelect(value: _cur, onChanged: _pickCurrency),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final x in const [30, 60, 100, 200])
              VeChip(
                onTap: () => setState(() => _ctrl.text = '$x'),
                child: Text('$x ${_cur.code}'),
              ),
          ],
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            if (budget.amount > 0) ...[
              VeBtn(
                variant: VeBtnVariant.ghost,
                onPressed: _clear,
                child: const Text('Quitar tope'),
              ),
              const SizedBox(width: 8),
            ],
            Expanded(
              child: VeBtn(
                variant: VeBtnVariant.primary,
                expands: true,
                icon: LucideIcons.check,
                onPressed: _save,
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ─── Entrada de Sala en vivo (v29 · H-37) ───────────────────────────────────
/// Entrada propia y clara bajo el título: fila delineada (icono · «Sala en
/// vivo» · «Comparte la lista en tiempo real» · chevron). Con sala activa
/// muestra nombre, «En vivo», código y personas. Tocar abre la sala viva
/// (o el lobby si aún no hay sala). Ancla del tour conservada arriba.
/// v32 · Fila de ENTRADA delineada a todo lo ancho — el lenguaje común de
/// las puertas de la Lista (Historial · Modo Cachea; Sala usa su propia
/// variante con estado en vivo, mismo lenguaje). Icono · título ·
/// descripción · chevron, todo separado y centrado verticalmente.
class _FilaEntrada extends StatelessWidget {
  const _FilaEntrada({
    required this.icon,
    required this.title,
    required this.sub,
    required this.semantic,
    required this.onTap,
    this.enabled = true,
  });

  final IconData icon;
  final String title;
  final String sub;
  final String semantic;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: semantic,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: enabled ? onTap : null,
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: context.ve.colorScheme.border),
              ),
              child: Row(
                children: [
                  Icon(icon, size: 17, color: scheme.onSurface),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          sub,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 13.5,
                            height: 1.3,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    LucideIcons.chevronRight,
                    size: 15,
                    color: scheme.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SalaEntry extends StatelessWidget {
  const _SalaEntry({required this.room, required this.onTap});

  final RoomController room;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final live = room.connected;
    final title = live
        ? (room.roomName.isNotEmpty
              ? room.roomName
              : (room.code.isNotEmpty ? 'Sala ${room.code}' : 'Sala en vivo'))
        : 'Sala en vivo';
    final people = room.visibleMembers.length;

    return Semantics(
      button: true,
      label: 'Sala en vivo',
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: context.ve.colorScheme.border),
            ),
            child: Row(
              children: [
                Icon(LucideIcons.users, size: 17, color: scheme.onSurface),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          title,
                          maxLines: 1,
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                      ),
                      const SizedBox(height: 2),
                      if (live)
                        Row(
                          children: [
                            VeBadge(
                              tone: VeTone.pos,
                              dot: true,
                              child: const Text('En vivo'),
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: FittedBox(
                                fit: BoxFit.scaleDown,
                                alignment: Alignment.centerLeft,
                                child: Text(
                                  'Código ${room.code} · $people '
                                  '${people == 1 ? 'persona' : 'personas'}',
                                  maxLines: 1,
                                  style: TextStyle(
                                    fontFamily: 'Inter',
                                    fontSize: 13.5,
                                    fontWeight: FontWeight.w500,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          alignment: Alignment.centerLeft,
                          child: Text(
                            'Comparte la lista en tiempo real',
                            maxLines: 1,
                            style: TextStyle(
                              fontFamily: 'Inter',
                              fontSize: 13.5,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Icon(
                  LucideIcons.chevronRight,
                  size: 16,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// ─── Picker «Elegir de mis productos» (prototipo PickSheet) ─────────────────
class _ProductPicker extends ConsumerStatefulWidget {
  const _ProductPicker({required this.store});

  final AppStore store;

  @override
  ConsumerState<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends ConsumerState<_ProductPicker> {
  final _qCtrl = TextEditingController();

  @override
  void dispose() {
    _qCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final q = fold(_qCtrl.text.trim().toLowerCase());
    final list = widget.store.products
        .where((p) => q.isEmpty || fold(p.name.toLowerCase()).contains(q))
        .toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        VeInput(
          controller: _qCtrl,
          onChanged: (_) => setState(() {}),
          placeholder: 'Filtrar…',
          semantic: 'Buscar producto',
        ),
        const SizedBox(height: 12),
        if (list.isEmpty)
          const VeEmpty(
            icon: LucideIcons.searchX,
            title: 'Sin coincidencias',
            sub: 'Prueba otra palabra.',
          )
        else
          VeGroup(
            children: [
              for (final p in list)
                VeRow(
                  label: Text(p.name),
                  sub: Text(p.category.label),
                  right: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      VeNum(
                        p.latestRecord == null
                            ? '—'
                            : fmtUSD(p.latestRecord!.price),
                      ),
                      const SizedBox(width: 8),
                      Icon(
                        LucideIcons.plus,
                        size: 14,
                        color: context.ve.colorScheme.mutedForeground,
                      ),
                    ],
                  ),
                  onTap: () {
                    final last = p.latestRecord;
                    if (last == null) {
                      showToast(
                        context,
                        'Regístrale precio primero',
                        kind: ToastKind.warn,
                      );
                      return;
                    }
                    widget.store.addToCart(
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
                    showToast(
                      context,
                      '${p.name} agregado',
                      kind: ToastKind.ok,
                    );
                    Navigator.of(context).pop();
                  },
                ),
            ],
          ),
      ],
    );
  }
}
