/// ─── Lista / «Calculadora de compras» (§9.3 · TASK-34 lenguaje Ve) ──────────
/// Hero total (odómetro) · tasas de cálculo (moneda + FUENTE del módulo) ·
/// barra de presupuesto tappable (total/techo + progreso + «En carrito») ·
/// alta rápida por nombre (libro de precios o editor) · captura manual con
/// detalle (precio, cantidad, tienda, escáner ROI) · filas con checkbox +
/// stepper + total tabular · «Agregar sin escribir» (frecuentes del libro) ·
/// checkout en SHEET Ve con multitienda, «ya existe» y foto de ticket ·
/// vuelto MULTI-DIVISA · dividir con propina.
///
/// TASK-34 (p7): presentación del prototipo web «modern minimal SaaS» con el
/// kit Ve (VeTitle/VeChip/VeCard/VeGroup/VeStepper/VeBadge/VeStickyBar/
/// VeEmpty) sobre TODA la lógica previa: RoomController (sala viva), escáner
/// ROI, plantillas, totales compartibles y flujo de checkout intactos.
///
/// Decisiones de iconos (v17.2): escanear = Lucide scanBarcode, historial =
/// Lucide receiptText, sala = Lucide users.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/analytics.dart' as an;
import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../core/version.dart';
import '../../data/store.dart';
import '../../room/room_controller.dart';
import '../../services/quick_actions.dart' show scanRequest;
import '../../services/sharing.dart';
import '../../widgets/app_tips.dart';
import '../../widgets/app_tour.dart' show TourKeys;
import '../../widgets/rate_sheet.dart';
import '../../widgets/ui.dart';
import 'checkout_modal.dart';
import 'item_editor.dart';
import 'roi_scanner.dart';
import '../room/room_sheet.dart';

class ListaScreen extends StatefulWidget {
  const ListaScreen({super.key});

  @override
  State<ListaScreen> createState() => _ListaScreenState();
}

class _ListaScreenState extends State<ListaScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: '1');
  final _quickCtrl = TextEditingController();
  final _storeCtrl =
      TextEditingController(); // tienda sugerida (anti-duplicado)
  final _totalsKey = GlobalKey(); // RepaintBoundary de Totales → PNG
  final _plantillasKey = GlobalKey(); // ancla de scroll del chip «Plantillas»
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
        _scanItem(context.read<AppStore>());
      }
    });
    scanRequest.addListener(_onScanRequest);
  }

  void _onScanRequest() {
    if (!mounted || !scanRequest.value) return;
    scanRequest.value = false;
    _scanItem(context.read<AppStore>());
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
        content: Text(
          'Código $scanned no registrado: no coincide con ningún producto de tu libro ni con un ítem de la lista.',
        ),
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
        'Nombre y precio válido (> 0) requeridos',
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
        'Escribe nombre y precio válido',
        kind: ToastKind.warn,
      );
      return;
    }
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
    final room = context.read<RoomController>();
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
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final room = context.watch<RoomController>();
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
      body: Stack(
        children: [
          ListView(
            // Padding inferior extra para no tapar el contenido con la
            // VeStickyBar (checkout/dividir).
            padding: EdgeInsets.fromLTRB(
              16,
              8,
              16,
              hasCart ? 112 : 24,
            ),
            children: [
              VeTitle(
                sub: Text('Presupuesto, vuelto y dividir la cuenta'),
                child: Text('Lista de compras'),
              ),
              const TipsTrigger(scope: 'lista'),
              // Fila de acciones de cabecera (prototipo): chips «Sala en
              // vivo» + «Plantillas» (ancla del tour en la sala) e historial.
              // En 320 px no caben dentro del VeTitle: fila propia.
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  children: [
                    KeyedSubtree(
                      key: TourKeys.listaSala,
                      child: VeChip(
                        active: room.connected,
                        onTap: () => _openRoom(context),
                        child: const Text('Sala en vivo'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    VeChip(
                      onTap: () => Scrollable.ensureVisible(
                        _plantillasKey.currentContext!,
                        duration: const Duration(milliseconds: 350),
                        curve: kEaseVe,
                      ),
                      child: const Text('Plantillas'),
                    ),
                    const Spacer(),
                    VeIconBtn(
                      icon: LucideIcons.receiptText,
                      onTap: () => context.push('/historial'),
                      label: 'Historial',
                    ),
                  ],
                ),
              ),
              // v18.0 · Sala Viva: si estás en sala, la lista lo sabe — la
              // cabecera de sala vive arriba de TODO y lleva a la sala.
              _RoomHeader(room: room),
              // Hero total (v19, orden del dueño): el número grande en la
              // moneda principal de cálculo y, como extra al lado, su
              // equivalente en USD.
              ReadWindow(
                semanticLabel:
                    'Total de la compra: ${fmtMoney(totalInCalc, calcCur)} ${calcCur.code}',
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Text(
                          'TOTAL DE LA COMPRA',
                          style: VeText.labelCaps(
                            9.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 6),
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
                    const SizedBox(height: 4),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Expanded(
                          child: AnimatedNumber(
                            totalInCalc,
                            // Héroe: cifra a 64 px tabular (firma de la app).
                            style: VeText.displayNum(
                              64,
                              color: scheme.onSurface,
                            ),
                            decimals: smartDecimals(totalInCalc, calcCur),
                          ),
                        ),
                        // Extra USD al lado (si la moneda de cálculo NO es
                        // USD).
                        if (calcCur != Currency.usd && totals.usd > 0)
                          Padding(
                            padding: const EdgeInsets.only(left: 10, bottom: 8),
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
              // v20 (orden del dueño): UN panel de control con presupuesto
              // + moneda de cálculo — antes eran un Wrap suelto de pills
              // («no se vea mal las monedas de cálculo») y una barra
              // aislada que nadie entendía cómo usar.
              Padding(
                padding: const EdgeInsets.only(top: 14),
                child: _PanelPresupuesto(
                  store: store,
                  ctx: ctx,
                  totalUsd: totals.usd,
                  calcCur: calcCur,
                  onCalcCurrency: (c) =>
                      store.setSetting('calcCurrency', c.code),
                ),
              ),
              // ── Zona de captura (ancla del tour v17.8) ─────────────────
              KeyedSubtree(
                key: TourKeys.listaAgregar,
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
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 3,
                                child: VeInput(
                                  key: const Key('lista-nombre'),
                                  controller: _nameCtrl,
                                  placeholder: 'Producto',
                                  semantic: 'Nombre del producto',
                                ),
                              ),
                              const SizedBox(width: 8),
                              SizedBox(
                                width: 68,
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
                              VeIconBtn(
                                icon: LucideIcons.scanBarcode,
                                onTap: () => _scanItem(store),
                                label: 'Escanear código de barras',
                              ),
                            ],
                          ),
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              Expanded(
                                child: VeInput(
                                  key: const Key('lista-precio'),
                                  controller: _priceCtrl,
                                  keyboardType:
                                      const TextInputType.numberWithOptions(
                                        decimal: true,
                                      ),
                                  placeholder: 'Precio unitario',
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
                          const SizedBox(height: 10),
                          VeInput(
                            key: const Key('lista-tienda'),
                            controller: _storeCtrl,
                            onChanged: (v) => setState(() => _storeName = v),
                            placeholder: 'Tienda (opcional)',
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
                                          fontSize: 12,
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
              // ── Lista de compras ────────────────────────────────────────
              if (!hasCart)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: VeEmpty(
                    icon: LucideIcons.shoppingCart,
                    title: 'Lista vacía',
                    sub: 'Agrega productos o usa una plantilla.',
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
                VeEyebrow(
                  right: VeBtn(
                    variant: VeBtnVariant.ghost,
                    size: VeBtnSize.sm,
                    onPressed: () => store.clearCart(),
                    child: const Text('Vaciar'),
                  ),
                  child: const Text('EN LA LISTA'),
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
                            'Sin tasa viva para ${calcCur.code}: el total en esa moneda no se puede calcular.',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: VeColors.of(context).warn,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
              // «Agregar sin escribir» (prototipo): frecuentes del libro +
              // picker completo.
              VeEyebrow(child: const Text('AGREGAR SIN ESCRIBIR')),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final p in _quickProducts(store))
                    VeChip(
                      onTap: () => _addFromBook(store, p),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Opacity(
                            opacity: 0.6,
                            child: Text(
                              '+',
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ),
                          const SizedBox(width: 4),
                          Text(p.name),
                        ],
                      ),
                    ),
                  VeChip(
                    dashed: true,
                    onTap: () => _openProductPicker(store),
                    child: const Padding(
                      padding: EdgeInsets.symmetric(horizontal: 12),
                      child: Text('Elegir de mis productos'),
                    ),
                  ),
                ],
              ),
              // Totales por moneda + compartir (texto y PNG).
              if (hasCart) ...[
                VeEyebrow(child: const Text('TOTALES')),
                VeCard(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    children: [
                      // Preview en pantalla (v18.0): el PNG del generador
                      // compone el MISMO TotalsDoc off-stage — el share ya no
                      // depende de que esta tarjeta siga montada tras el
                      // scroll.
                      RepaintBoundary(
                        key: _totalsKey,
                        child: TotalsDoc(totals: totals),
                      ),
                      const SizedBox(height: 10),
                      // Wrap (no Row+Expanded): en teléfonos angostos los
                      // dos botones FLUYEN a dos líneas en vez de desbordar.
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          VeBtn(
                            variant: VeBtnVariant.secondary,
                            size: VeBtnSize.sm,
                            icon: LucideIcons.image,
                            onPressed: _shareTotalsPng,
                            child: const Text('Compartir PNG'),
                          ),
                          VeBtn(
                            variant: VeBtnVariant.secondary,
                            size: VeBtnSize.sm,
                            icon: LucideIcons.share2,
                            onPressed: () =>
                                shareTotalsText(context, store, totals),
                            child: const Text('Compartir'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
              // Plantillas.
              _Plantillas(anchorKey: _plantillasKey),
            ],
          ),
          // v19 (orden del dueño): Vuelto y Dividir la cuenta viven en el
          // modal de «Finalizar compra» — la barra inferior lanza el reparto
          // y el checkout.
          if (hasCart)
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: VeStickyBar(
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
              ),
            ),
        ],
      ),
    );
  }

  /// Frecuentes del libro (hasta 6): con precio vigente y sin copia en la
  /// lista (por producto o por nombre).
  List<Product> _quickProducts(AppStore store) {
    return [
      for (final p in store.products)
        if (p.latestRecord != null &&
            !store.cart.any(
              (c) =>
                  c.productId == p.id ||
                  fold(c.name.toLowerCase()) == fold(p.name.toLowerCase()),
            ))
        p,
    ].take(6).toList();
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

  /// Totales actuales del carrito (recalculados para el render off-stage:
  /// el PNG se genera desde el estado vivo, no desde el último build).
  ({double usd, Map<Currency, double> byCurrency, int units}) _totalsOf() {
    final store = context.read<AppStore>();
    final ctx = store.contextOf(module: RateModule.calculator);
    return cartTotals(store.cart, ctx);
  }

  /// Comparte los Totales como PNG (v18.0): compone el documento
  /// OFF-STAGE — causa raíz del «No pude generar la imagen» era capturar el
  /// boundary VISIBLE de una tarjeta que el scroll ya recicló. Fallback al
  /// boundary visible si el off-stage no estuviera disponible.
  Future<void> _shareTotalsPng() async {
    final totals = _totalsOf();
    final off = await renderOffstagePng(
      context,
      TotalsDoc(totals: totals),
      width: 360,
    );
    final bytes = off ?? await captureWidget(_totalsKey);
    if (!mounted) return;
    if (bytes == null) {
      showToast(context, 'No pude generar la imagen', kind: ToastKind.error);
      return;
    }
    await sharePng(bytes, 'valorave-totales.png');
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
        'Nombre y precio válido (> 0) requeridos',
        kind: ToastKind.warn,
      );
      return;
    }
    store.updateCartItem(item.id, edited);
  }
}

/// Selector de FUENTE de tasa dependiente de la moneda de cálculo (requisito
/// A): v19 — la hoja visual de toda la app (RateTile con bandera, precio y
/// categoría; la Manual con editor inline). Valor = fuente del módulo Lista
/// (RateModule.calculator — el override por módulo §9.3; sin override cae a
/// la global, cuyo default es la oficial). Cambia con setModuleRateSource
/// para no alterar el Conversor ni las fichas de producto.
class _FuenteChip extends StatelessWidget {
  const _FuenteChip({required this.store, required this.currency});

  final AppStore store;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentId = store.sourceFor(currency, module: RateModule.calculator);
    final current = RateSource.of(currentId);
    return TapScale(
      onTap: () async {
        await showRateSheet(
          context,
          currency: currency,
          ctx: store.contextOf(module: RateModule.calculator),
          currentId: currentId,
          title: 'Tasa del módulo Lista · ${currency.label}',
          onPick: (id) =>
              store.setModuleRateSource(RateModule.calculator, currency, id),
        );
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        // v20: pill COMPACTA al nivel del CurrencySelect — sello de
        // categoría + nombre corto (edgeName) + chevron. El «Fuente: X»
        // largo desbordaba la fila del panel (fix dueño).
        decoration: BoxDecoration(
          color: scheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(color: scheme.outlineVariant),
        ),
        // scaleDown: si el espacio aprieta (Ahem · textScale alto), la
        // pill se REDUCE proporcionalmente en vez de desbordar — igual
        // que los botones de la barra pegadiza.
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (current != null) ...[
                SourceSeal(current.category),
                const SizedBox(width: 6),
              ],
              Text(
                current?.edgeName ?? currentId,
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(width: 2),
              Icon(Icons.expand_more, size: 15, color: scheme.onSurfaceVariant),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─── Documento de Totales (v18.0: público y reutilizable) ──────────────────
/// El MISMO widget sirve de preview en la tarjeta de Totales Y de fuente del
/// PNG off-stage: lo que se ve es lo que se comparte.
class TotalsDoc extends StatelessWidget {
  const TotalsDoc({super.key, required this.totals});

  final ({double usd, Map<Currency, double> byCurrency, int units}) totals;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      color: scheme.surface,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          Row(
            children: [
              const Expanded(
                child: Text(
                  'ValoraVE · Totales',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              Text(
                fmtDate(DateTime.now()),
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          for (final e in totals.byCurrency.entries)
            _TotalsRow(text: fmtCurrency(e.value, e.key), code: e.key),
          const RuleDouble(),
          const SizedBox(height: 6),
          Text(
            'Total USD: ${fmtUSD(totals.usd)}',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: scheme.onSurface,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'ValoraVE $kAppVersionVisible · es-VE',
            style: TextStyle(fontSize: 9, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TotalsRow extends StatelessWidget {
  const _TotalsRow({required this.text, required this.code});
  final String text;
  final Currency code;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Flag(code, size: 15),
          const SizedBox(width: 8),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
        ],
      ),
    );
  }
}

/// ─── Fila de ítem del carrito (prototipo List.tsx) ──────────────────────────
/// Checkbox de comprado + nombre (tachado y tenue al comprar) + subtítulo
/// (tienda · precio c/u · peso · quién lo marcó) + stepper −/+ + total
/// tabular a la derecha. Fondo subtle/50 en comprados; tocar el cuerpo abre
/// la hoja de edición; «Quitar» vive en esa hoja.
class _CartRow extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
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
        color: item.checked
            ? scheme.muted.withValues(alpha: 0.5)
            : null,
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
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
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
                        decorationColor: scheme.mutedForeground
                            .withValues(alpha: 0.85),
                        color: item.checked
                            ? scheme.mutedForeground.withValues(alpha: 0.75)
                            : scheme.foreground,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      sub,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11.5,
                        color: muted,
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

/// ─── Panel de presupuesto + cálculo (v20 · orden del dueño) ──────────────────
/// UNA tarjeta que explica sola cómo funciona el presupuesto:
/// · Fila 1: eyebrow «Presupuesto del mes» + total de la lista sobre el
///   tope («de Bs 5.000» · «sin tope»).
/// · Barra de progreso h6 (tinta normal · warn > 80 % · neg excedido).
/// · Fila 2: «Restan/Excedido X» + «En carrito Y».
/// · Divisor y fila de CÁLCULO: en qué moneda se suma la lista y con qué
///   fuente de tasa — dos pills compactas (bandera+código · sello+nombre),
///   no el Wrap suelto de textos que había antes.
/// Tocar el cuerpo abre el editor del presupuesto; las pills abren sus
/// propias hojas (moneda / fuente).
class _PanelPresupuesto extends StatelessWidget {
  const _PanelPresupuesto({
    required this.store,
    required this.ctx,
    required this.totalUsd,
    required this.calcCur,
    required this.onCalcCurrency,
  });

  final AppStore store;
  final RateContext ctx;
  final double totalUsd;
  final Currency calcCur;
  final ValueChanged<Currency> onCalcCurrency;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final budget = store.data.budget;
    final bCur = CurrencyX.from(budget.currency);
    final u = ctx.unitsPerUSD(bCur) ?? 0;
    final budgetUsd = u > 0 ? budget.amount / u : 0.0;
    final pct = budgetUsd > 0 ? (totalUsd / budgetUsd * 100) : 0.0;
    final over = budgetUsd > 0 && totalUsd > budgetUsd;
    final fill = over ? ink.neg : (pct > 80 ? ink.warn : scheme.foreground);

    // Total de la compra en la divisa del presupuesto (si hay tasa).
    final String totalText = u > 0
        ? fmtMoney(totalUsd * u, bCur)
        : '—';
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
          Row(
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  'PRESUPUESTO DEL MES',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.84,
                    color: scheme.mutedForeground,
                  ),
                ),
              ),
              VeNum(
                totalText,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.foreground,
                ),
              ),
              Text(
                budget.amount > 0
                    ? ' de ${fmtMoney(budget.amount, bCur)}'
                    : ' · sin tope',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: scheme.mutedForeground,
                ),
              ),
            ],
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
          Row(
            children: [
              Expanded(
                child: budget.amount > 0
                    ? Text.rich(
                        TextSpan(
                          text: over ? 'Excedido ' : 'Restan ',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            color: scheme.mutedForeground,
                          ),
                          children: [
                            TextSpan(
                              text: u > 0
                                  ? fmtMoney(diffB.abs(), bCur)
                                  : '—',
                              style: TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                                color: over ? ink.neg : scheme.foreground,
                              ),
                            ),
                          ],
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      )
                    : Text(
                        'Fija tu tope del mes — toca esta tarjeta',
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12.5,
                          color: scheme.mutedForeground,
                        ),
                      ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  cartText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w500,
                    color: ink.pos,
                  ),
                ),
              ),
            ],
          ),
          // ── Divisor + fila de cálculo (v20): moneda y fuente, compactas.
          Padding(
            padding: const EdgeInsets.only(top: 4),
            child: Divider(height: 24, color: scheme.border),
          ),
          Row(
            children: [
              Icon(
                LucideIcons.calculator,
                size: 14,
                color: scheme.mutedForeground,
              ),
              const SizedBox(width: 7),
              // Expanded + ellipsis: la etiqueta cede antes que romper la
              // fila (Ahem/textScale extremos no desbordan).
              Expanded(
                child: Text(
                  'Cálculos en',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.foreground,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Flexible(
                child: CurrencySelect(value: calcCur, onChanged: onCalcCurrency),
              ),
              const SizedBox(width: 8),
              Flexible(child: _FuenteChip(store: store, currency: calcCur)),
            ],
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
class _BudgetSheet extends StatefulWidget {
  const _BudgetSheet({required this.store});

  final AppStore store;

  @override
  State<_BudgetSheet> createState() => _BudgetSheetState();
}

class _BudgetSheetState extends State<_BudgetSheet> {
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
    final v = parseLocaleNum(_ctrl.text) ??
        widget.store.data.budget.amount;
    widget.store.setBudget(v, c.code);
    setState(() => _cur = c);
  }

  void _save() {
    final v = parseLocaleNum(_ctrl.text);
    if (v == null || v <= 0) {
      showToast(
        context,
        'Ingresa un monto mayor que 0',
        kind: ToastKind.warn,
      );
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
    final scheme = ShadTheme.of(context).colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        // v20 (orden del dueño): cómo se USA — una línea de qué hace y
        // leyenda de los tres estados de la barra.
        Text(
          'Es tu tope de gasto del mes. La barra de la Lista se llena con '
          'el total del carrito:',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12.5,
            height: 1.45,
            color: scheme.mutedForeground,
          ),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Container(
              width: 22,
              height: 4,
              decoration: BoxDecoration(
                color: scheme.foreground,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'Dentro del presupuesto',
              style: TextStyle(fontSize: 11.5),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 22,
              height: 4,
              decoration: BoxDecoration(
                color: ink.warn,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'Cerca del tope (más del 80 %)',
              style: TextStyle(fontSize: 11.5),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Container(
              width: 22,
              height: 4,
              decoration: BoxDecoration(
                color: ink.neg,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(width: 7),
            const Text(
              'Te pasaste del tope',
              style: TextStyle(fontSize: 11.5),
            ),
          ],
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

/// ─── Cabecera de sala activa (v18.0 · prototipo: sala en vivo) ──────────────
/// Badge «En vivo» + código en mono + avatares superpuestos de los miembros
/// (con punto de presencia) → abre la Sala Viva.
class _RoomHeader extends StatelessWidget {
  const _RoomHeader({required this.room});

  final RoomController room;

  @override
  Widget build(BuildContext context) {
    if (!room.connected) return const SizedBox.shrink();
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final title = room.roomName.isNotEmpty
        ? room.roomName
        : 'Sala ${room.code}';
    final members = room.visibleMembers.take(4).toList();

    return Padding(
      padding: const EdgeInsets.only(top: 4, bottom: 10),
      child: VeCard(
        onTap: () => context.push('/sala-viva'),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: scheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      VeBadge(tone: VeTone.pos, dot: true, child: Text('En vivo')),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          'Código ${room.code}',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: 'JetBrainsMono',
                            fontVariations: [FontVariation('wght', 500)],
                            fontSize: 12,
                            letterSpacing: 1.8,
                            color: scheme.mutedForeground,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            // Avatares superpuestos (32 px, iniciales, borde de fondo).
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                for (var i = 0; i < members.length; i++)
                  Padding(
                    padding: EdgeInsets.only(left: i == 0 ? 0 : -10),
                    child: _avatar(
                      context,
                      members[i].id == room.myId
                          ? 'TÚ'
                          : members[i].name.trim().toUpperCase(),
                      online: members[i].online,
                      ink: ink,
                    ),
                  ),
              ],
            ),
            const SizedBox(width: 10),
            Icon(
              LucideIcons.chevronRight,
              size: 16,
              color: scheme.mutedForeground,
            ),
          ],
        ),
      ),
    );
  }

  Widget _avatar(BuildContext context, String initials,
      {required bool online, required VeInk ink}) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        color: scheme.muted,
        shape: BoxShape.circle,
        border: Border.all(color: scheme.card, width: 2),
      ),
      alignment: Alignment.center,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Text(
            initials.length > 2 ? initials.substring(0, 2) : initials,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: scheme.foreground,
            ),
          ),
          Positioned(
            right: -4,
            bottom: -4,
            child: Container(
              width: 9,
              height: 9,
              decoration: BoxDecoration(
                color: online ? ink.pos : ink.warn,
                shape: BoxShape.circle,
                border: Border.all(color: scheme.card, width: 2),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ─── Picker «Elegir de mis productos» (prototipo PickSheet) ─────────────────
class _ProductPicker extends StatefulWidget {
  const _ProductPicker({required this.store});

  final AppStore store;

  @override
  State<_ProductPicker> createState() => _ProductPickerState();
}

class _ProductPickerState extends State<_ProductPicker> {
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
                        color: ShadTheme.of(context).colorScheme.mutedForeground,
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

class _Plantillas extends StatelessWidget {
  const _Plantillas({required this.anchorKey});

  /// Ancla de scroll del chip «Plantillas» de la cabecera.
  final GlobalKey anchorKey;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return KeyedSubtree(
      key: anchorKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VeEyebrow(
            right: VeBtn(
              variant: VeBtnVariant.ghost,
              size: VeBtnSize.sm,
              onPressed: () async {
                final nameCtrl = TextEditingController();
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Guardar plantilla'),
                    content: TextField(
                      controller: nameCtrl,
                      autofocus: true,
                      decoration: const InputDecoration(
                        hintText: 'Nombre de la plantilla',
                      ),
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
                // Fix leak: dispose del controller tras leer su texto.
                final name = nameCtrl.text;
                nameCtrl.dispose();
                if (ok == true) {
                  final id = store.saveTemplate(name);
                  if (id == null && context.mounted) {
                    showToast(
                      context,
                      'La lista está vacía: no hay nada que guardar',
                      kind: ToastKind.warn,
                    );
                  }
                }
              },
              child: const Text('Guardar carrito'),
            ),
            child: const Text('PLANTILLAS'),
          ),
          if (store.templates.isEmpty)
            const VeEmpty(
              title: 'Sin plantillas',
              sub: 'Congela tu lista repetida (máx 20) y aplícala con un toque.',
            )
          else
            VeGroup(
              children: [
                for (final t in store.templates)
                  VeRow(
                    label: Text(t.name),
                    sub: Text(
                      '${t.items.length} '
                      '${t.items.length == 1 ? 'ítem' : 'ítems'} · '
                      '${fmtDate(t.createdAt)}',
                    ),
                    right: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        VeBtn(
                          size: VeBtnSize.sm,
                          onPressed: () {
                            final qty = store.applyTemplate(t.id);
                            showToast(
                              context,
                              qty > 0
                                  ? 'Plantilla aplicada: $qty unidades'
                                  : 'Plantilla vacía',
                              kind: qty > 0 ? ToastKind.ok : ToastKind.info,
                            );
                          },
                          child: const Text('Aplicar'),
                        ),
                        const SizedBox(width: 6),
                        VeIconBtn(
                          icon: LucideIcons.x,
                          onTap: () => store.deleteTemplate(t.id),
                          label: 'Eliminar plantilla',
                        ),
                      ],
                    ),
                  ),
              ],
            ),
        ],
      ),
    );
  }
}
