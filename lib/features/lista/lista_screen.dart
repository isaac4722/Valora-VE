/// ─── Lista / «Calculadora de compras» (§9.3 · MODULE=calculator) ───────────
/// Hero total (odómetro) · tasas de cálculo (moneda + fuente del módulo) ·
/// agregar producto · rows editables con checked/checkedBy · sala en vivo ·
/// totales sin IGTF · presupuesto % · plantillas (20) · vuelto · dividir ·
/// checkout «Pagado (ajustado)» con foto de ticket · enlace/compartir.
library;

import 'dart:convert';


import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';

import '../../core/analytics.dart' as an;
import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../services/sharing.dart';
import '../scanner/scanner_screen.dart';
import '../../widgets/ui.dart';
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
  String _addCurrency = 'VES';
  String _storeName = '';

  @override
  void dispose() {
    _nameCtrl.dispose();
    _priceCtrl.dispose();
    _qtyCtrl.dispose();
    super.dispose();
  }

  /// Escanea un código y lo convierte en ítem: producto registrado con
  /// precio → entra directo al carrito; con registro sin precio o nuevo,
  /// prellena el formulario para completar a mano (§9.3 escáner).
  Future<void> _scanItem(AppStore store) async {
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

    final matches = store.products.where((p) => p.barcode == code).toList();
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
      // Registrado pero sin precios → prellena el nombre.
      setState(() => _nameCtrl.text = p.name);
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('${p.name} no tiene precio registrado — complétalo'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    // Código nuevo: prellena el campo con el código para completar a mano.
    setState(() => _nameCtrl.text = code);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Código sin registrar — escribe nombre y precio'),
        behavior: SnackBarBehavior.floating));
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
      // priceUSD no existe en CartItem — se normaliza al vuelo al totalizar.
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
    final totals = cartTotalsUsd(store, ctx);
    final double totalInCalc = calcCur == Currency.usd
        ? totals.usd
        : (ctx.unitsPerUSD(calcCur) ?? 0) > 0
            ? totals.usd * (ctx.unitsPerUSD(calcCur) ?? 0.0)
            : 0.0;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PageHeader('Lista de compras', hint: 'Presupuesto, vuelto y dividir — sin IGTF'),
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
                style: VeText.displayNum(44, color: scheme.onSurface),
                decimals: smartDecimals(totalInCalc, calcCur),
              ),
            ]),
          ),
          // Tasas de cálculo.
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(children: [
              Text('Moneda de cálculos', style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              const SizedBox(width: 8),
              CurrencySelect(
                value: calcCur,
                onChanged: (c) => store.setSetting('calcCurrency', c.code),
              ),
            ]),
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
                  onChanged: (v) => _storeName = v,
                  decoration: const InputDecoration(hintText: 'Tienda (opcional)'),
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
          // Totales por moneda + compartir.
          if (store.cart.isNotEmpty) ...[
            SectionTitle('Totales'),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(children: [
                  for (final e in totals.byCurrency.entries)
                    _TotalsRow(text: fmtCurrency(e.value, e.key), code: e.key),
                  const RuleDouble(),
                  const SizedBox(height: 8),
                  Row(children: [
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
          // Vuelto + dividir (solo con items).
          if (store.cart.isNotEmpty) ...[
            _Vuelto(ctx: ctx, totals: totals),
            _DividirCuenta(totalUsd: totals.usd, ctx: ctx),
            // Checkout.
            _Checkout(ctx: ctx, totals: totals),
          ],
        ],
      ),
    );
  }

  static ({double usd, Map<Currency, double> byCurrency, int units}) cartTotalsUsd(
      AppStore store, RateContext ctx) {
    final by = <Currency, double>{};
    var usd = 0.0;
    var units = 0;
    for (final item in store.cart) {
      final c = CurrencyX.from(item.currency);
      final u = ctx.unitsPerUSD(c) ?? 0;
      final line = item.price * item.quantity;
      by[c] = (by[c] ?? 0) + line;
      usd += u > 0 ? line / u : 0;
      units += item.quantity;
    }
    return (usd: usd, byCurrency: by, units: units);
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
  });

  final CartItem item;
  final RateContext ctx;
  final void Function(bool, String?) onChecked;
  final ValueChanged<int> onQty;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final c = CurrencyX.from(item.currency);
    return Padding(
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
          icon: Icon(Icons.close, size: 16, color: scheme.onSurfaceVariant),
          onPressed: onRemove,
        ),
      ]),
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

class _Vuelto extends StatefulWidget {
  const _Vuelto({required this.ctx, required this.totals});
  final RateContext ctx;
  final ({double usd, Map<Currency, double> byCurrency, int units}) totals;

  @override
  State<_Vuelto> createState() => _VueltoState();
}

class _VueltoState extends State<_Vuelto> {
  final _paidCtrl = TextEditingController();
  String _paidCurrency = 'VES';

  @override
  void dispose() {
    _paidCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rate = widget.ctx.unitsPerUSD(Currency.ves) ?? 0.0;
    final totalBs = rate > 0 ? widget.totals.usd * rate : 0.0;
    final paid = parseLocaleNum(_paidCtrl.text) ?? 0;
    final paidCur = CurrencyX.from(_paidCurrency);
    final paidU = widget.ctx.unitsPerUSD(paidCur) ?? 0;
    final paidUsd = paidU > 0 ? paid / paidU : 0.0;
    final r = an.computeChange(totalBS: totalBs, paidUSD: paidCur == Currency.usd ? paid : 0, paidBS: paidCur == Currency.ves ? paid : 0, rate: rate);
    final double missing = r.missing > 0 ? r.missing : (paidUsd < totalBs && paid > 0 ? (totalBs - paidUsd) * rate : 0.0);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Calculadora de vuelto'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _paidCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(hintText: '¿Con cuánto pagas? (total: ${fmtMoney(totalBs, Currency.ves)})'),
                ),
              ),
              const SizedBox(width: 8),
              CurrencySelect(value: paidCur, onChanged: (c) => setState(() => _paidCurrency = c.code)),
            ]),
            if (paid > 0) ...[
              const SizedBox(height: 10),
              Text(
                missing > 0
                    ? 'Faltan ${fmtCurrency(missing * (paidCur == Currency.ves ? 1 : rate), paidCur)}'
                    : 'Vuelto: ${fmtCurrency(paidCur == Currency.ves ? r.change : r.change / (rate > 0 ? rate : 1), paidCur)}',
                style: VeText.displayNum(20, color: missing > 0 ? VeColors.of(context).neg : VeColors.of(context).pos),
              ),
              Text('Cuenta: ${fmtCurrency(totalBs, Currency.ves)} · Pagado: ${fmtCurrency(paid, paidCur)}',
                  style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
            ],
          ]),
        ),
      ),
    ]);
  }
}

double computeChangeTotalBs(double totalBs, double paidUSD, double paidBS, double rate) =>
    paidUSD + paidBS - totalBs;

class _DividirCuenta extends StatefulWidget {
  const _DividirCuenta({required this.totalUsd, required this.ctx});
  final double totalUsd;
  final RateContext ctx;

  @override
  State<_DividirCuenta> createState() => _DividirCuentaState();
}

class _DividirCuentaState extends State<_DividirCuenta> {
  int _people = 2;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rate = widget.ctx.unitsPerUSD(Currency.ves) ?? 0;
    final perPerson = _people > 0 ? widget.totalUsd / _people : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Dividir la cuenta'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            InkWell(
                onTap: () => setState(() => _people = (_people - 1).clamp(1, 50)),
                child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.remove_circle_outline))),
            Text('$_people personas', style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
            InkWell(
                onTap: () => setState(() => _people = (_people + 1).clamp(1, 50)),
                child: const Padding(padding: EdgeInsets.all(6), child: Icon(Icons.add_circle_outline))),
            const Spacer(),
            TextButton(
              onPressed: () => copiarAlPortapapeles(context,
                  'Reparto: $_people personas · ${fmtUSD(perPerson)} c/u · Total ${fmtUSD(widget.totalUsd)}'
                  '${rate > 0 ? ' · ${fmtMoney(perPerson * rate, Currency.ves)} c/u' : ''}',
                  'Reparto copiado'),
              child: const Text('Copiar reparto'),
            ),
          ]),
        ),
      ),
      if (_people > 0)
        Padding(
          padding: const EdgeInsets.only(top: 4),
          child: Text('Cada quien: ${fmtUSD(perPerson)}'
                  '${rate > 0 ? ' · ${fmtMoney(perPerson * rate, Currency.ves)}' : ''}',
              style: VeText.displayNum(15, color: scheme.onSurface)),
        ),
    ]);
  }
}

class _Checkout extends StatefulWidget {
  const _Checkout({required this.ctx, required this.totals});
  final RateContext ctx;
  final ({double usd, Map<Currency, double> byCurrency, int units}) totals;

  @override
  State<_Checkout> createState() => _CheckoutState();
}

class _CheckoutState extends State<_Checkout> {
  final _paidCtrl = TextEditingController();
  final _storeCtrl = TextEditingController();
  final _notesCtrl = TextEditingController();
  String? _ticketDataUrl;

  @override
  void dispose() {
    _paidCtrl.dispose();
    _storeCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickTicket() async {
    final picker = ImagePicker();
    final photo = await picker.pickImage(
        source: ImageSource.camera, maxWidth: 1024, maxHeight: 1024, imageQuality: 72);
    if (photo == null) return;
    final bytes = await photo.readAsBytes();
    if (bytes.length > 12 * 1024 * 1024) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('La foto pesa más de 12 MB'), behavior: SnackBarBehavior.floating));
      }
      return;
    }
    setState(() => _ticketDataUrl = photoToDataUrl(bytes));
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final rate = widget.ctx.unitsPerUSD(Currency.ves) ?? 0;
    final paid = parseLocaleNum(_paidCtrl.text);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Cerrar compra'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Pagado (ajustado)', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            TextField(
              controller: _paidCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: InputDecoration(
                hintText: 'Total: ${fmtUSD(widget.totals.usd)}'
                    '${rate > 0 ? ' · ${fmtMoney(widget.totals.usd * rate, Currency.ves)}' : ''}',
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _storeCtrl,
                  decoration: const InputDecoration(hintText: 'Tienda'),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: _pickTicket,
                icon: const Icon(Icons.camera_alt_outlined, size: 15),
                label: Text(_ticketDataUrl == null ? 'Ticket' : 'Foto lista', style: const TextStyle(fontSize: 12.5)),
              ),
            ]),
            const SizedBox(height: 8),
            TextField(
              controller: _notesCtrl,
              decoration: const InputDecoration(hintText: 'Notas (opcional)'),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.check, size: 16),
                label: const Text('Registrar compra y vaciar lista'),
                onPressed: () {
                  if (store.cart.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                        content: Text('La lista está vacía'), behavior: SnackBarBehavior.floating));
                    return;
                  }
                  final purchase = buildPurchase(
                    store: store,
                    ctx: widget.ctx,
                    totals: widget.totals,
                    storeName: _storeCtrl.text.trim().isEmpty ? null : _storeCtrl.text.trim(),
                    paidTotal: paid,
                    ticketDataUrl: _ticketDataUrl,
                    notes: _notesCtrl.text.trim().isEmpty ? null : _notesCtrl.text.trim(),
                  );
                  store.addPurchase(purchase);
                  store.clearCart();
                  _paidCtrl.clear();
                  _storeCtrl.clear();
                  _notesCtrl.clear();
                  setState(() => _ticketDataUrl = null);
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Compra registrada: ${fmtUSD(purchase.totalUSD)}'),
                      behavior: SnackBarBehavior.floating));
                },
              ),
            ),
            if (_ticketDataUrl != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Row(children: [
                  Icon(Icons.photo, size: 14, color: scheme.primary),
                  const SizedBox(width: 6),
                  Text('Ticket adjunto (~200 KB comprimido)', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
                  const Spacer(),
                  TextButton(onPressed: () => setState(() => _ticketDataUrl = null), child: const Text('Quitar')),
                ]),
              ),
          ]),
        ),
      ),
    ]);
  }
}

/// Data URL JPEG base64 (compatibilidad con respaldos web: data:image/jpeg).
String photoToDataUrl(List<int> bytes) =>
    'data:image/jpeg;base64,${base64Encode(bytes)}';

Purchase buildPurchase({
  required AppStore store,
  required RateContext ctx,
  required ({double usd, Map<Currency, double> byCurrency, int units}) totals,
  String? storeName,
  double? paidTotal,
  String? ticketDataUrl,
  String? notes,
}) {
  final rate = ctx.unitsPerUSD(Currency.ves) ?? 0;
  final items = store.cart
      .map((c) {
        final cur = CurrencyX.from(c.currency);
        final u = ctx.unitsPerUSD(cur) ?? 0;
        return PurchaseItem(
          name: c.name,
          quantity: c.quantity,
          priceUSD: u > 0 ? c.price / u : 0,
          originalPrice: c.price,
          currency: c.currency,
          productId: c.productId,
        );
      })
      .toList();
  return Purchase(
    id: '',
    date: DateTime.now(),
    store: storeName,
    items: items,
    totalUSD: totals.usd,
    totalBS: rate > 0 ? totals.usd * rate : 0,
    rate: rate,
    rateSourceId: ctx.sel(Currency.ves),
    igtf: false, // v14+: retirado del motor, solo display histórico
    paidTotal: paidTotal,
    paidCurrency: store.cart.isNotEmpty ? store.cart.first.currency : 'VES',
    ticketPhoto: ticketDataUrl,
    notes: notes,
  );
}

