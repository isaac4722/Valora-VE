/// ─── Lista / «Calculadora de compras» (§9.3 · MODULE=calculator) ───────────
/// Hero total (odómetro) · tasas de cálculo (moneda + FUENTE del módulo) ·
/// agregar producto · editor de ítems con detalle (tienda, código, peso) ·
/// escáner ROI (solo recuadro central) · vuelto MULTI-DIVISA · dividir con
/// propina · checkout en MODAL con multitienda, «ya existe» y foto de ticket.
///
/// Decisiones de iconos (v17.2): Icons.qr_code_scanner = ESCANEAR (legible y
/// ya canónico en la app), Icons.receipt_long = HISTORIAL (cabecera de Lista),
/// la sala conserva Icons.groups_outlined.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

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
  final _storeCtrl =
      TextEditingController(); // tienda sugerida (anti-duplicado)
  final _totalsKey = GlobalKey(); // RepaintBoundary de Totales → PNG
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
    final item = await showItemEditorSheet(
      context,
      store: store,
      presetName: presetName,
      presetBarcode: code,
    );
    if (item == null || !mounted) return;
    if (item.name.trim().isEmpty || item.price <= 0) {
      showToast(
        context,
        'Nombre y precio válido (> 0) requeridos',
        kind: ToastKind.warn,
      );
      return;
    }
    store.addToCart(item);
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

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final ctx = store.contextOf(module: RateModule.calculator);
    final calcCur = CurrencyX.from(store.settings.calcCurrency);
    final totals = cartTotals(store.cart, ctx);
    final double totalInCalc = calcCur == Currency.usd
        ? totals.usd
        : (ctx.unitsPerUSD(calcCur) ?? 0) > 0
        ? totals.usd * (ctx.unitsPerUSD(calcCur) ?? 0.0)
        : 0.0;
    // Sugerencia pasiva anti-duplicado de tienda (nunca bloquea).
    final typed = _storeName.trim();
    final String? rawSuggest = typed.length >= 3
        ? an.findSimilarStore(typed, store.stores)
        : null;
    final String? suggestion = (rawSuggest != null && rawSuggest != typed)
        ? rawSuggest
        : null;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PageHeader(
            'Lista de compras',
            hint: 'Presupuesto, vuelto y dividir la cuenta',
            action: IconButton(
              tooltip: 'Historial',
              icon: const Icon(Icons.receipt_long, size: 20),
              onPressed: () => context.push('/historial'),
            ),
          ),
          const TipsTrigger(scope: 'lista'),
          // v18.0 · Sala Viva: si estás en sala, la lista lo sabe — el strip
          // vive arriba de TODO y lleva a la pantalla de la sala.
          const _EnSalaStrip(),
          // Hero total (v19, orden del dueño): el número grande en la moneda
          // principal de cálculo y, como extra al lado, su equivalente en USD.
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
                    // Divisa de cálculo SIEMPRE visible junto a la cifra (v17.5).
                    CurrencyTag(calcCur.code),
                    const Spacer(),
                    // Contador de ítems VISIBLE (fix): antes un LiveBadge
                    // con live:false — que colapsa a SizedBox.shrink() y
                    // jamás se pintaba (elemento muerto en el héroe).
                    Stamp('${store.cart.length} ítems'),
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
                        style: VeText.displayNum(64, color: scheme.onSurface),
                        decimals: smartDecimals(totalInCalc, calcCur),
                      ),
                    ),
                    // Extra USD al lado (si la moneda de cálculo NO es USD).
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
          // Tasas de cálculo: moneda + FUENTE dependiente (requisito A).
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Moneda de cálculos',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                CurrencySelect(
                  value: calcCur,
                  onChanged: (c) => store.setSetting('calcCurrency', c.code),
                ),
                _FuenteChip(store: store, currency: calcCur),
              ],
            ),
          ),
          // Agregar producto. Ancla del tour (v17.8): el card de captura.
          SectionTitle('Agregar producto'),
          KeyedSubtree(
            key: TourKeys.listaAgregar,
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Expanded(
                          flex: 3,
                          child: TextField(
                            controller: _nameCtrl,
                            decoration: const InputDecoration(
                              hintText: 'Producto',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: _qtyCtrl,
                            keyboardType: TextInputType.number,
                            textAlign: TextAlign.center,
                            decoration: const InputDecoration(
                              hintText: 'Cant.',
                            ),
                          ),
                        ),
                        IconButton.filledTonal(
                          onPressed: () => _scanItem(store),
                          tooltip: 'Escanear código de barras',
                          icon: const Icon(Icons.qr_code_scanner, size: 20),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _priceCtrl,
                            keyboardType: const TextInputType.numberWithOptions(
                              decimal: true,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Precio unitario',
                            ),
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
                    TextField(
                      controller: _storeCtrl,
                      onChanged: (v) => setState(() => _storeName = v),
                      decoration: const InputDecoration(
                        hintText: 'Tienda (opcional)',
                      ),
                    ),
                    if (suggestion != null)
                      // Sugerencia PASIVA anti-duplicado: nunca bloquea el alta.
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: TapScale(
                          onTap: () {
                            _storeCtrl.text = suggestion;
                            setState(() => _storeName = suggestion);
                          },
                          child: Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outline,
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
                    const SizedBox(height: 10),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton.icon(
                        onPressed: () => _addItem(store),
                        icon: const Icon(Icons.add, size: 16),
                        label: const Text('Agregar a la lista'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          // Lista de compras.
          if (store.cart.isNotEmpty) ...[
            SectionTitle(
              'Lista de compras',
              actionLabel: 'Vaciar',
              onAction: () => store.clearCart(),
            ),
            Card(
              child: Column(
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
            ),
          ],
          // Presupuesto.
          _Presupuesto(totalUsd: totals.usd, ctx: ctx),
          // Compra en grupo.
          SectionTitle('Compra en grupo'),
          Card(
            child: KeyedSubtree(
              key: TourKeys.listaSala,
              child: ListenableBuilder(
                listenable: context.read<RoomController>(),
                builder: (context, _) {
                  final room = context.read<RoomController>();
                  final inRoom = room.connected;
                  return ListTile(
                    leading: Icon(
                      inRoom ? Icons.groups_2_outlined : Icons.groups_outlined,
                      color: scheme.primary,
                    ),
                    title: const Text(
                      'Sala en vivo',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                    subtitle: Text(
                      inRoom
                          ? 'En sala ${room.code} · ${room.visibleMembers.length} '
                                'miembros · toca para ver la sala'
                          : 'Comparte tu lista por código de 6 letras, QR, WiFi directo o servidor',
                      style: const TextStyle(fontSize: 12),
                    ),
                    trailing: inRoom
                        ? const LiveBadge(live: true, label: 'En sala')
                        : const Icon(Icons.chevron_right),
                    onTap: () => inRoom
                        ? context.push('/sala-viva')
                        : showRoomSheet(context),
                  );
                },
              ),
            ),
          ),
          // Totales por moneda + compartir (texto y PNG).
          if (store.cart.isNotEmpty) ...[
            SectionTitle('Totales'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  children: [
                    // Preview en pantalla (v18.0): el PNG del generador compone el
                    // MISMO TotalsDoc off-stage — el share ya no depende de que
                    // esta tarjeta siga montada tras el scroll.
                    RepaintBoundary(
                      key: _totalsKey,
                      child: TotalsDoc(totals: totals),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.tonalIcon(
                            onPressed: _shareTotalsPng,
                            icon: const Icon(Icons.image_outlined, size: 15),
                            label: const Text(
                              'Compartir PNG',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                shareTotalsText(context, store, totals),
                            icon: const Icon(Icons.share, size: 15),
                            label: const Text(
                              'Compartir',
                              style: TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
          // Plantillas.
          _Plantillas(),
          // v19 (orden del dueño): Vuelto y Dividir la cuenta viven AHORA en
          // el modal de «Finalizar compra» (apartado AL PAGAR) — la pantalla
          // de lista queda para armar la compra; lo demás es post-compra.
          if (store.cart.isNotEmpty) ...[
            const SizedBox(height: 6),
            const _CheckoutLauncher(),
          ],
        ],
      ),
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

  /// Editar ítem → editor con detalle (tienda, código, peso) en sheet firma.
  Future<void> _editCartItem(AppStore store, CartItem item) async {
    final edited = await showItemEditorSheet(
      context,
      store: store,
      initial: item,
    );
    if (edited == null || !mounted) return;
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
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (current != null) ...[
              SourceSeal(current.category),
              const SizedBox(width: 6),
            ],
            Text(
              'Fuente: ${current?.label ?? currentId}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800),
            ),
            const SizedBox(width: 2),
            Icon(Icons.expand_more, size: 15, color: scheme.onSurfaceVariant),
          ],
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
    final scheme = Theme.of(context).colorScheme;
    final c = CurrencyX.from(item.currency);
    // Detalle multitienda + peso capturado (v17.2), si existe.
    final extras = <String>[
      if ((item.store ?? '').trim().isNotEmpty) item.store!.trim(),
      if ((item.size ?? 0) > 0)
        '${fmtNum(item.size!, decimals: item.size! % 1 == 0 ? 0 : 2)} ${item.sizeUnit ?? ''}'
            .trim(),
    ];
    return GestureDetector(
      onLongPress: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(
          children: [
            Checkbox(
              value: item.checked,
              onChanged: (v) => onChecked(v ?? false, 'Yo'),
            ),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    item.name,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                      decoration: item.checked
                          ? TextDecoration.lineThrough
                          : null,
                      color: item.checked
                          ? scheme.onSurfaceVariant
                          : scheme.onSurface,
                    ),
                  ),
                  Text(
                    '${fmtCurrency(item.price, c)} × ${item.quantity}'
                    '${item.checkedBy != null && item.checkedBy!.isNotEmpty ? ' · ${item.checkedBy}' : ''}',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  if (extras.isNotEmpty)
                    Text(
                      extras.join(' · '),
                      style: TextStyle(
                        fontSize: 10.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
            InkWell(
              onTap: () => onQty(item.quantity - 1),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.remove, size: 16),
              ),
            ),
            Text(
              '${item.quantity}',
              style: VeText.displayNum(13.5, color: scheme.onSurface),
            ),
            InkWell(
              onTap: () => onQty(item.quantity + 1),
              child: const Padding(
                padding: EdgeInsets.all(6),
                child: Icon(Icons.add, size: 16),
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.edit_outlined,
                size: 15,
                color: scheme.onSurfaceVariant,
              ),
              tooltip: 'Editar',
              onPressed: onEdit,
            ),
            IconButton(
              icon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
              onPressed: onRemove,
            ),
          ],
        ),
      ),
    );
  }
}

class _Presupuesto extends StatefulWidget {
  const _Presupuesto({required this.totalUsd, required this.ctx});
  final double totalUsd;
  final RateContext ctx;

  @override
  State<_Presupuesto> createState() => _PresupuestoState();
}

class _PresupuestoState extends State<_Presupuesto> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final budget = store.data.budget;
    final bCur = CurrencyX.from(budget.currency);
    final u = widget.ctx.unitsPerUSD(bCur) ?? 0;
    final budgetUsd = u > 0 ? budget.amount / u : 0.0;
    final pct = budgetUsd > 0 ? (widget.totalUsd / budgetUsd * 100) : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Presupuesto'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      // v19: MoneyField con miles en vivo; la MONEDA se elige y
                      // queda fija aunque aún no haya monto (bug del dueño).
                      child: MoneyField(
                        controller: _ctrl,
                        decoration: InputDecoration(
                          hintText: budget.amount > 0
                              ? fmtMoney(budget.amount, bCur)
                              // «Presupuesto del mes» (v19.10): el hint largo
                              // «Tu presupuesto en VES» se truncaba contra el
                              // selector de moneda; la divisa ya está al lado.
                              : 'Presupuesto del mes',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    CurrencySelect(
                      value: bCur,
                      onChanged: (c) {
                        // Cambia la divisa conservando el monto vigente (o el
                        // tecleado si hay): setBudget ya NUNCA resetea la moneda.
                        final v = parseLocaleNum(_ctrl.text) ?? budget.amount;
                        store.setBudget(v, c.code);
                        if (context.mounted) {
                          setState(() {});
                        }
                      },
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      onPressed: () {
                        final v = parseLocaleNum(_ctrl.text) ?? 0;
                        store.setBudget(v, bCur.code);
                        _ctrl.clear();
                      },
                      child: const Text('Fijar'),
                    ),
                  ],
                ),
                if (budget.amount > 0) ...[
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(999),
                    child: LinearProgressIndicator(
                      value: (pct / 100).clamp(0, 1),
                      backgroundColor: scheme.surfaceContainerHigh,
                      color: pct > 100
                          ? VeColors.of(context).neg
                          : scheme.primary,
                      minHeight: 8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    pct > 100
                        ? 'Excede tu presupuesto: ${fmtPct(pct - 100)} encima'
                        : 'Consumido: ${fmtPct(pct)}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pct > 100
                          ? VeColors.of(context).neg
                          : scheme.onSurfaceVariant,
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
}

class _Plantillas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Plantillas',
          actionLabel: 'Guardar carrito',
          onAction: () async {
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
        ),
        if (store.templates.isEmpty)
          Text(
            'Congela tu lista repetida (máx 20) y aplícala con un toque.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          )
        else
          Card(
            child: Column(
              children: [
                for (final t in store.templates)
                  ListTile(
                    dense: true,
                    leading: Icon(
                      Icons.bookmark_border,
                      size: 18,
                      color: scheme.primary,
                    ),
                    title: Text(
                      t.name,
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    subtitle: Text(
                      '${t.items.length} ítems · ${fmtDate(t.createdAt)}',
                      style: const TextStyle(fontSize: 11),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        TextButton(
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
                        IconButton(
                          icon: const Icon(Icons.close, size: 15),
                          onPressed: () => store.deleteTemplate(t.id),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// ─── Vuelto MULTI-DIVISA (requisito K) ──────────────────────────────────────
/// Varias filas «moneda + monto»: lo entregado se suma convertido a la
/// moneda del cálculo (vía ctx.plan: arista directa, puente EUR o vía USD).
/// El vuelto sale en la moneda del cálculo y, si se pide, desglosado por
/// divisa. Sin tasa para una divisa → mensaje honesto (no inventa números).
class _CheckoutLauncher extends StatelessWidget {
  const _CheckoutLauncher();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final ctx = store.contextOf(module: RateModule.calculator);
    final calcCur = CurrencyX.from(store.settings.calcCurrency);
    final totals = cartTotals(store.cart, ctx);
    final u = ctx.unitsPerUSD(calcCur) ?? 0;
    final totalInCalc = calcCur == Currency.usd
        ? totals.usd
        : (u > 0 ? totals.usd * u : 0.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Cerrar compra'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                LedgerRow(
                  label: 'Ítems',
                  value: '${store.cart.length} · ${totals.units} u.',
                ),
                LedgerRow(
                  label: 'Total',
                  value: '${calcCur.code} ${fmtMoney(totalInCalc, calcCur)}',
                  boldValue: true,
                ),
                LedgerRow(label: 'Total USD', value: fmtUSD(totals.usd)),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () => showCheckoutSheet(context),
                    icon: const Icon(Icons.point_of_sale, size: 16),
                    label: const Text('Finalizar compra'),
                  ),
                ),
                if (u <= 0 && calcCur != Currency.usd)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      'Sin tasa viva para ${calcCur.code}: el total en esa moneda no se puede calcular.',
                      style: TextStyle(
                        fontSize: 11,
                        color: VeColors.of(context).warn,
                      ),
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

/// ─── Strip «En sala» (v18.0) ───────────────────────────────────────────────
/// Arriba de TODO en la Lista cuando hay sala activa: LiveBadge + nombre de
/// la sala + miembros → abre la Sala Viva (pantalla propia de la sala).
class _EnSalaStrip extends StatelessWidget {
  const _EnSalaStrip();

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomController>();
    if (!room.connected) return const SizedBox.shrink();
    final scheme = Theme.of(context).colorScheme;
    final title = room.roomName.isNotEmpty
        ? room.roomName
        : 'Sala ${room.code}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/sala-viva'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Row(
            children: [
              const LiveBadge(live: true, label: 'En sala'),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '$title · ${room.visibleMembers.length} en la sala',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(Icons.groups_2_outlined, size: 18, color: scheme.primary),
            ],
          ),
        ),
      ),
    );
  }
}
