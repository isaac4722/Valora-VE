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
import '../../data/store.dart';
import '../../services/quick_actions.dart' show scanRequest;
import '../../services/sharing.dart';
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
  final _storeCtrl = TextEditingController(); // tienda sugerida (anti-duplicado)
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
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Buscar')),
          ],
        ),
      );
      if (ok != true || !mounted) return;
      final manual = ctrl.text.trim();
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
        store.addToCart(CartItem(
          id: '',
          productId: p.id,
          name: p.name,
          quantity: int.tryParse(_qtyCtrl.text) ?? 1,
          price: last.originalPrice,
          currency: last.currency,
          barcode: p.barcode,
        ));
        if (_storeName.trim().isNotEmpty) store.addStore(_storeName);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('${p.name} · ${fmtMoneyCode(last.originalPrice, last.currency)} agregado'),
            behavior: SnackBarBehavior.floating));
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
          c.id, c.copyWith(quantity: (c.quantity + 1).clamp(1, 999)));
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${c.name} ya está en tu lista — sumé 1'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    // 3) Código sin registrar → diálogo honesto (requisito E).
    if (!mounted) return;
    final action = await showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Código no registrado'),
        content: Text(
            'Código $scanned no registrado: no coincide con ningún producto de tu libro ni con un ítem de la lista.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(dctx, 'rescan'),
              child: const Text('Repetir escaneo')),
          FilledButton(
              onPressed: () => Navigator.pop(dctx, 'manual'),
              child: const Text('Agregar manualmente')),
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
  Future<void> _openEditorForCode(AppStore store, String code,
      {String? presetName}) async {
    final item = await showItemEditorSheet(
      context,
      store: store,
      presetName: presetName,
      presetBarcode: code,
    );
    if (item == null || !mounted) return;
    if (item.name.trim().isEmpty || item.price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nombre y precio válido (> 0) requeridos'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    store.addToCart(item);
  }

  void _addItem(AppStore store) {
    final name = _nameCtrl.text.trim();
    final price = parseLocaleNum(_priceCtrl.text) ?? 0;
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    if (name.isEmpty || price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Escribe nombre y precio válido'), behavior: SnackBarBehavior.floating));
      return;
    }
    store.addToCart(CartItem(
      id: '',
      name: name,
      quantity: qty.clamp(1, 999),
      price: price,
      currency: _addCurrency,
      store: _storeName.trim().isEmpty ? null : _storeName.trim(),
    ));
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
    final String? rawSuggest =
        typed.length >= 3 ? an.findSimilarStore(typed, store.stores) : null;
    final String? suggestion =
        (rawSuggest != null && rawSuggest != typed) ? rawSuggest : null;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PageHeader('Lista de compras', hint: 'Presupuesto, vuelto y dividir — sin IGTF',
            action: IconButton(
              tooltip: 'Historial',
              icon: const Icon(Icons.receipt_long, size: 20),
              onPressed: () => context.push('/historial'),
            )),
          // Hero total.
          ReadWindow(
            semanticLabel: 'Total de la compra',
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Text('TOTAL DE LA COMPRA', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
                const Spacer(),
                LiveBadge(live: false, label: '${store.cart.length} ítems'),
              ]),
              const SizedBox(height: 4),
              AnimatedNumber(
                totalInCalc,
                // Héroe: cifra a 64 px tabular (firma de la app).
                style: VeText.displayNum(64, color: scheme.onSurface),
                decimals: smartDecimals(totalInCalc, calcCur),
              ),
            ]),
          ),
          // Tasas de cálculo: moneda + FUENTE dependiente (requisito A).
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text('Moneda de cálculos',
                    style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
                CurrencySelect(
                  value: calcCur,
                  onChanged: (c) => store.setSetting('calcCurrency', c.code),
                ),
                _FuenteChip(store: store, currency: calcCur),
              ],
            ),
          ),
          // Agregar producto.
          SectionTitle('Agregar producto'),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(children: [
                Row(children: [
                  Expanded(
                    flex: 3,
                    child: TextField(
                      controller: _nameCtrl,
                      decoration: const InputDecoration(hintText: 'Producto'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _qtyCtrl,
                      keyboardType: TextInputType.number,
                      textAlign: TextAlign.center,
                      decoration: const InputDecoration(hintText: 'Cant.'),
                    ),
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _scanItem(store),
                    tooltip: 'Escanear código de barras',
                    icon: const Icon(Icons.qr_code_scanner, size: 20),
                  ),
                ]),
                const SizedBox(height: 8),
                Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _priceCtrl,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(hintText: 'Precio unitario'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CurrencySelect(
                    value: CurrencyX.from(_addCurrency),
                    onChanged: (c) => setState(() => _addCurrency = c.code),
                  ),
                ]),
                const SizedBox(height: 8),
                TextField(
                  controller: _storeCtrl,
                  onChanged: (v) => setState(() => _storeName = v),
                  decoration: const InputDecoration(hintText: 'Tienda (opcional)'),
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
                      child: Row(children: [
                        Icon(Icons.lightbulb_outline,
                            size: 13, color: scheme.primary),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text('¿Quizá quisiste «$suggestion»?',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: scheme.primary)),
                        ),
                      ]),
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
              ]),
            ),
          ),
          // Lista de compras.
          if (store.cart.isNotEmpty) ...[
            SectionTitle('Lista de compras',
                actionLabel: 'Vaciar', onAction: () => store.clearCart()),
            Card(
              child: Column(children: [
                for (final item in store.cart)
                  _CartRow(
                    item: item,
                    ctx: ctx,
                    onChecked: (v, by) => store.updateCartItem(
                        item.id, item.copyWith(checked: v, checkedBy: v ? (by ?? '') : null, clearCheckedBy: !v)),
                    onQty: (q) => store.updateCartItem(item.id, item.copyWith(quantity: q.clamp(1, 999))),
                    onRemove: () => store.removeFromCart(item.id),
                    onEdit: () => _editCartItem(store, item),
                  ),
              ]),
            ),
          ],
          // Presupuesto.
          _Presupuesto(totalUsd: totals.usd, ctx: ctx),
          // Compra en grupo.
          SectionTitle('Compra en grupo'),
          Card(
            child: ListTile(
              leading: Icon(Icons.groups_outlined, color: scheme.primary),
              title: const Text('Sala en vivo', style: TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
              subtitle: const Text('Comparte tu lista por código de 6 letras, QR, WiFi directo o servidor', style: TextStyle(fontSize: 12)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => showRoomSheet(context),
            ),
          ),
          // Totales por moneda + compartir (texto y PNG).
          if (store.cart.isNotEmpty) ...[
            SectionTitle('Totales'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  // Área capturada a PNG (fondo de tarjeta para el share).
                  RepaintBoundary(
                    key: _totalsKey,
                    child: Container(
                      color: scheme.surface,
                      padding: const EdgeInsets.all(8),
                      child: Column(children: [
                        Row(children: [
                          const Expanded(
                            child: Text('ValoraVE · Totales',
                                style: TextStyle(
                                    fontFamily: 'SpaceGrotesk',
                                    fontSize: 13,
                                    fontWeight: FontWeight.w800)),
                          ),
                          Text(fmtDate(DateTime.now()),
                              style: TextStyle(
                                  fontSize: 11,
                                  color: scheme.onSurfaceVariant)),
                        ]),
                        const SizedBox(height: 6),
                        for (final e in totals.byCurrency.entries)
                          _TotalsRow(text: fmtCurrency(e.value, e.key), code: e.key),
                        const RuleDouble(),
                        const SizedBox(height: 6),
                        Text('Total USD: ${fmtUSD(totals.usd)}',
                            style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w700,
                                color: scheme.onSurface)),
                      ]),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _shareTotalsPng,
                        icon: const Icon(Icons.image_outlined, size: 15),
                        label: const Text('Compartir PNG', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => shareTotalsText(context, store, totals),
                        icon: const Icon(Icons.share, size: 15),
                        label: const Text('Compartir', style: TextStyle(fontSize: 12.5)),
                      ),
                    ),
                  ]),
                ]),
              ),
            ),
          ],
          // Plantillas.
          _Plantillas(),
          // Vuelto multi-divisa + dividir con propina + checkout modal.
          if (store.cart.isNotEmpty) ...[
            _Vuelto(ctx: ctx, totals: totals, calcCur: calcCur, totalInCalc: totalInCalc),
            _DividirCuenta(totalUsd: totals.usd, totalInCalc: totalInCalc, calcCur: calcCur),
            const _CheckoutLauncher(),
          ],
        ],
      ),
    );
  }

  /// Comparte los Totales como PNG (captura de la tarjeta, mismo camino
  /// que el PNG del Conversor).
  Future<void> _shareTotalsPng() async {
    final bytes = await captureWidget(_totalsKey);
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No pude generar la imagen'), behavior: SnackBarBehavior.floating));
      return;
    }
    await sharePng(bytes, 'valorave-totales.png');
  }

  /// Editar ítem → editor con detalle (tienda, código, peso) en sheet firma.
  Future<void> _editCartItem(AppStore store, CartItem item) async {
    final edited = await showItemEditorSheet(context, store: store, initial: item);
    if (edited == null || !mounted) return;
    if (edited.name.trim().isEmpty || edited.price <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Nombre y precio válido (> 0) requeridos'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    store.updateCartItem(item.id, edited);
  }
}

/// Selector de FUENTE de tasa dependiente de la moneda de cálculo (requisito
/// A): opciones = RateSource.sourcesFor(moneda); valor = fuente del módulo
/// Lista (RateModule.calculator — el override por módulo §9.3; sin override
/// cae a la global, cuyo default es la oficial). Cambia con
/// setModuleRateSource para no alterar Conversor ni Finanzas.
class _FuenteChip extends StatelessWidget {
  const _FuenteChip({required this.store, required this.currency});

  final AppStore store;
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final currentId = store.sourceFor(currency, module: RateModule.calculator);
    final current = RateSource.of(currentId);
    final sources = RateSource.sourcesFor(currency);
    return PopupMenuButton<String>(
      initialValue: currentId,
      onSelected: (id) =>
          store.setModuleRateSource(RateModule.calculator, currency, id),
      tooltip: 'Fuente de la tasa del módulo Lista',
      itemBuilder: (_) => [
        for (final s in sources)
          PopupMenuItem(
            value: s.id,
            child: Row(children: [
              SourceDot(s.category),
              const SizedBox(width: 8),
              Text(s.label, style: const TextStyle(fontSize: 13)),
              const SizedBox(width: 6),
              Expanded(
                child: Text(s.detail,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                        fontSize: 10.5, color: scheme.onSurfaceVariant)),
              ),
            ]),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: scheme.surfaceContainerHighest.withValues(alpha: 0.45),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          if (current != null) ...[
            SourceDot(current.category),
            const SizedBox(width: 6),
          ],
          Text('Fuente: ${current?.label ?? currentId}',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800)),
          const SizedBox(width: 2),
          Icon(Icons.expand_more, size: 15, color: scheme.onSurfaceVariant),
        ]),
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
      child: Row(children: [
        Flag(code, size: 15),
        const SizedBox(width: 8),
        Expanded(child: Text(text, style: const TextStyle(fontSize: 12.5))),
      ]),
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
        '${fmtNum(item.size!, decimals: item.size! % 1 == 0 ? 0 : 2)} ${item.sizeUnit ?? ''}'.trim(),
    ];
    return GestureDetector(
      onLongPress: onEdit,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        child: Row(children: [
          Checkbox(
            value: item.checked,
            onChanged: (v) => onChecked(v ?? false, 'Yo'),
          ),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(
                item.name,
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                  decoration: item.checked ? TextDecoration.lineThrough : null,
                  color: item.checked ? scheme.onSurfaceVariant : scheme.onSurface,
                ),
              ),
              Text(
                '${fmtCurrency(item.price, c)} × ${item.quantity}'
                '${item.checkedBy != null && item.checkedBy!.isNotEmpty ? ' · ${item.checkedBy}' : ''}',
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
              ),
              if (extras.isNotEmpty)
                Text(extras.join(' · '),
                    style: TextStyle(
                        fontSize: 10.5, color: scheme.onSurfaceVariant)),
            ]),
          ),
          InkWell(
            onTap: () => onQty(item.quantity - 1),
            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove, size: 16)),
          ),
          Text('${item.quantity}', style: VeText.displayNum(13.5, color: scheme.onSurface)),
          InkWell(
            onTap: () => onQty(item.quantity + 1),
            child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add, size: 16)),
          ),
          IconButton(
            icon: Icon(Icons.edit_outlined, size: 15, color: scheme.onSurfaceVariant),
            tooltip: 'Editar',
            onPressed: onEdit,
          ),
          IconButton(
            icon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
            onPressed: onRemove,
          ),
        ]),
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

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Presupuesto'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _ctrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: budget.amount > 0 ? fmtMoney(budget.amount, bCur) : 'Tu presupuesto',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CurrencySelect(value: bCur, onChanged: (c) {
                final v = parseLocaleNum(_ctrl.text);
                store.setBudget(v ?? budget.amount, c.code);
              }),
              const SizedBox(width: 8),
              FilledButton(
                onPressed: () {
                  final v = parseLocaleNum(_ctrl.text) ?? 0;
                  store.setBudget(v, bCur.code);
                  _ctrl.clear();
                },
                child: const Text('Fijar'),
              ),
            ]),
            if (budget.amount > 0) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(999),
                child: LinearProgressIndicator(
                  value: (pct / 100).clamp(0, 1),
                  backgroundColor: scheme.surfaceContainerHigh,
                  color: pct > 100 ? VeColors.of(context).neg : scheme.primary,
                  minHeight: 8,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                pct > 100
                    ? 'Excede tu presupuesto: ${fmtPct(pct - 100)} encima'
                    : 'Consumido: ${fmtPct(pct)}',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                    color: pct > 100 ? VeColors.of(context).neg : scheme.onSurfaceVariant),
              ),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _Plantillas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Plantillas',
          actionLabel: 'Guardar carrito', onAction: () async {
        final nameCtrl = TextEditingController();
        final ok = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text('Guardar plantilla'),
            content: TextField(controller: nameCtrl, autofocus: true,
                decoration: const InputDecoration(hintText: 'Nombre de la plantilla')),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
              FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Guardar')),
            ],
          ),
        );
        if (ok == true) {
          final id = store.saveTemplate(nameCtrl.text);
          if (id == null && context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                content: Text('La lista está vacía: no hay nada que guardar'),
                behavior: SnackBarBehavior.floating));
          }
        }
      }),
      if (store.templates.isEmpty)
        Text('Congela tu lista repetida (máx 20) y aplícala con un toque.',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))
      else
        Card(
          child: Column(children: [
            for (final t in store.templates)
              ListTile(
                dense: true,
                leading: Icon(Icons.bookmark_border, size: 18, color: scheme.primary),
                title: Text(t.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
                subtitle: Text('${t.items.length} ítems · ${fmtDate(t.createdAt)}', style: const TextStyle(fontSize: 11)),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  TextButton(onPressed: () {
                    final qty = store.applyTemplate(t.id);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                        content: Text(qty > 0 ? 'Plantilla aplicada: $qty unidades' : 'Plantilla vacía'),
                        behavior: SnackBarBehavior.floating));
                  }, child: const Text('Aplicar')),
                  IconButton(
                      icon: const Icon(Icons.close, size: 15),
                      onPressed: () => store.deleteTemplate(t.id)),
                ]),
              ),
          ]),
        ),
    ]);
  }
}

/// ─── Vuelto MULTI-DIVISA (requisito K) ──────────────────────────────────────
/// Varias filas «moneda + monto»: lo entregado se suma convertido a la
/// moneda del cálculo (vía ctx.plan: arista directa, puente EUR o vía USD).
/// El vuelto sale en la moneda del cálculo y, si se pide, desglosado por
/// divisa. Sin tasa para una divisa → mensaje honesto (no inventa números).
class _Vuelto extends StatefulWidget {
  const _Vuelto({
    required this.ctx,
    required this.totals,
    required this.calcCur,
    required this.totalInCalc,
  });

  final RateContext ctx;
  final ({double usd, Map<Currency, double> byCurrency, int units}) totals;
  final Currency calcCur;
  final double totalInCalc;

  @override
  State<_Vuelto> createState() => _VueltoState();
}

class _VueltoState extends State<_Vuelto> {
  final List<TextEditingController> _ctrls = [TextEditingController()];
  final List<Currency> _currencies = [Currency.ves];
  bool _breakdown = false;

  @override
  void dispose() {
    for (final c in _ctrls) {
      c.dispose();
    }
    super.dispose();
  }

  void _addRow() {
    setState(() {
      _ctrls.add(TextEditingController());
      _currencies.add(Currency.usd);
    });
  }

  void _removeRow(int i) {
    setState(() {
      _ctrls.removeAt(i).dispose();
      _currencies.removeAt(i);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    final calcCur = widget.calcCur;

    var delivered = 0.0;
    final missing = <Currency>{};
    final rows = <({Currency cur, double amount, double converted, bool missing})>[];
    for (var i = 0; i < _ctrls.length; i++) {
      final amount = parseLocaleNum(_ctrls[i].text) ?? 0;
      if (amount <= 0) continue;
      final cur = _currencies[i];
      final p = widget.ctx.plan(cur, calcCur);
      if (p == null) {
        missing.add(cur);
        rows.add((cur: cur, amount: amount, converted: 0, missing: true));
        continue;
      }
      final converted = amount * p.rate;
      delivered += converted;
      rows.add((cur: cur, amount: amount, converted: converted, missing: false));
    }
    final bool hasInput = rows.isNotEmpty;
    final double change = delivered - widget.totalInCalc;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Calculadora de vuelto'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(
                'Total a cubrir: ${fmtCurrency(widget.totalInCalc, calcCur)}'
                '${calcCur != Currency.usd ? ' (${fmtUSD(widget.totals.usd)})' : ''}',
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            // Filas «moneda + monto» (varios pagos en distintas divisas).
            for (var i = 0; i < _ctrls.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(children: [
                  Expanded(
                    child: TextField(
                      controller: _ctrls[i],
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      onChanged: (_) => setState(() {}),
                      decoration: InputDecoration(
                          hintText: i == 0 ? '¿Con cuánto pagas?' : 'Otro pago'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CurrencySelect(
                    value: _currencies[i],
                    onChanged: (c) => setState(() => _currencies[i] = c),
                  ),
                  if (_ctrls.length > 1)
                    IconButton(
                      tooltip: 'Quitar pago',
                      icon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
                      onPressed: () => _removeRow(i),
                    ),
                ]),
              ),
            TextButton.icon(
              onPressed: _addRow,
              icon: const Icon(Icons.add, size: 14),
              label: const Text('Pagar en otra divisa', style: TextStyle(fontSize: 12)),
            ),
            // Resultado: vuelto o falta, en la moneda del cálculo.
            if (hasInput) ...[
              const SizedBox(height: 6),
              if (missing.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(
                    'Sin tasa viva para ${missing.map((m) => m.code).join(', ')}: '
                    'no puedo convertir ese pago — revisa su fuente en Ajustes.',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: sem.warn),
                  ),
                ),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  change >= 0
                      ? 'Vuelto: ${fmtCurrency(change, calcCur)}'
                      : 'Faltan: ${fmtCurrency(-change, calcCur)}',
                  style: VeText.displayNum(22,
                      color: change >= 0 ? sem.pos : sem.neg),
                ),
              ),
              Text('Entregado: ${fmtCurrency(delivered, calcCur)}',
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
              TextButton(
                onPressed: () => setState(() => _breakdown = !_breakdown),
                style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap),
                child: Text(_breakdown ? 'Ocultar desglose' : 'Desglosar por divisa',
                    style: const TextStyle(fontSize: 12)),
              ),
              if (_breakdown)
                for (final r in rows)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 2),
                    child: LedgerRow(
                      leading: Flag(r.cur, size: 14),
                      label: '${fmtMoney(r.amount, r.cur)} ${r.cur.code}',
                      value: r.missing
                          ? 'Sin tasa'
                          : '${fmtMoney(r.converted, calcCur)} ${calcCur.code}',
                      valueColor: r.missing ? sem.warn : null,
                    ),
                  ),
            ],
          ]),
        ),
      ),
    ]);
  }
}

/// ─── Dividir la cuenta (requisito L) ────────────────────────────────────────
/// Personas (+/−) · propina % (chips 0/5/10/15/20) · opción «propina ya
/// incluida en el total» (simple: sobre el total con impuesto ya dentro) ·
/// resultado por persona en la moneda del cálculo · copiar texto.
class _DividirCuenta extends StatefulWidget {
  const _DividirCuenta({
    required this.totalUsd,
    required this.totalInCalc,
    required this.calcCur,
  });

  final double totalUsd;
  final double totalInCalc;
  final Currency calcCur;

  @override
  State<_DividirCuenta> createState() => _DividirCuentaState();
}

class _DividirCuentaState extends State<_DividirCuenta> {
  int _people = 2;
  int _tipPct = 0;
  bool _tipIncluded = false;

  static const _tipOptions = [0, 5, 10, 15, 20];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    final people = _people.clamp(1, 50);
    final factor = _tipIncluded ? 1.0 : 1 + _tipPct / 100;
    final perPerson = widget.totalInCalc * factor / people;
    final perPersonUsd = widget.totalUsd * factor / people;
    final tipAmount = widget.totalInCalc * _tipPct / 100;

    final copyText = 'Reparto ValoraVE · ${fmtDate(DateTime.now())}\n'
        'Total: ${fmtCurrency(widget.totalInCalc, widget.calcCur)}'
        ' (${fmtUSD(widget.totalUsd)})\n'
        'Propina: $_tipPct % — ${_tipIncluded ? 'ya incluida en el total' : 'se añade al total'}\n'
        '$people personas → ${fmtCurrency(perPerson, widget.calcCur)} c/u';

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Dividir la cuenta'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            // Personas.
            Row(children: [
              Text('PERSONAS', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 10),
              InkWell(
                onTap: () => setState(() => _people = (_people - 1).clamp(1, 50)),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.remove_circle_outline, size: 20)),
              ),
              Text('$people', style: VeText.displayNum(16, color: scheme.onSurface)),
              InkWell(
                onTap: () => setState(() => _people = (_people + 1).clamp(1, 50)),
                borderRadius: BorderRadius.circular(8),
                child: const Padding(
                    padding: EdgeInsets.all(6),
                    child: Icon(Icons.add_circle_outline, size: 20)),
              ),
              const Spacer(),
              TextButton.icon(
                onPressed: () => copiarAlPortapapeles(context, copyText, 'Reparto copiado'),
                icon: const Icon(Icons.copy, size: 14),
                label: const Text('Copiar', style: TextStyle(fontSize: 12)),
              ),
            ]),
            const SizedBox(height: 6),
            // Propina %.
            Wrap(spacing: 6, children: [
              for (final t in _tipOptions)
                ChipTag('$t %', selected: _tipPct == t,
                    onTap: () => setState(() => _tipPct = t)),
            ]),
            const SizedBox(height: 6),
            // Opción simple: propina sobre el total con impuesto (ya dentro).
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('Propina ya incluida en el total',
                      style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600)),
                  Text('Apágalo si la propina se añade encima del total',
                      style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
                ]),
              ),
              Switch(value: _tipIncluded, onChanged: (v) => setState(() => _tipIncluded = v)),
            ]),
            const SizedBox(height: 8),
            // Resultado por persona en la moneda del cálculo.
            ReadWindow(
              semanticLabel: 'Cuota por persona',
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text('Cada quien: ${fmtCurrency(perPerson, widget.calcCur)}',
                      style: VeText.displayNum(19, color: scheme.onSurface)),
                ),
                if (widget.calcCur != Currency.usd)
                  Text('≈ ${fmtUSD(perPersonUsd)} c/u',
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                if (_tipPct > 0)
                  Text(
                    _tipIncluded
                        ? 'Propina $_tipPct % (${fmtCurrency(tipAmount, widget.calcCur)}) dentro del total'
                        : 'Propina $_tipPct % añadida: ${fmtCurrency(tipAmount, widget.calcCur)}',
                    style: TextStyle(
                        fontSize: 11,
                        color: _tipIncluded ? scheme.onSurfaceVariant : sem.pos),
                  ),
              ]),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// ─── Cerrar compra (requisito G) ────────────────────────────────────────────
/// Ya NO guarda en línea ni muestra la interfaz inline: un resumen corto y
/// el botón «Finalizar compra» que abre el MODAL de checkout
/// (checkout_modal.dart) con tiendas, ajuste de pagado, nota y foto.
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

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Cerrar compra'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            LedgerRow(label: 'Ítems', value: '${store.cart.length} · ${totals.units} u.'),
            LedgerRow(
                label: 'Total',
                value: '${calcCur.code} ${fmtMoney(totalInCalc, calcCur)}',
                boldValue: true),
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
                child: Text('Sin tasa viva para ${calcCur.code}: el total en esa moneda no se puede calcular.',
                    style: TextStyle(fontSize: 11, color: VeColors.of(context).warn)),
              ),
          ]),
        ),
      ),
    ]);
  }
}
