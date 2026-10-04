/// ─── Lista / Calculadora — GOD v2 OPTIMIZED [No-Break Update] ───────
library;

import \'dart:convert\';
import \'package:flutter/material.dart\';
import \'package:flutter/services.dart\';
import \'package:lucide_icons_flutter/lucide_icons.dart\';
import \'package:provider/provider.dart\';
import \'package:shadcn_ui/shadcn_ui.dart\';

import \'../../core/currencies.dart\';
import \'../../core/fmt.dart\';
import \'../../core/models.dart\';
import \'../../data/store.dart\';
import \'../../services/sharing.dart\';
import \'../../widgets/ve/ve.dart\';
import \'../room/room_sheet.dart\';
import \'checkout_modal.dart\';
import \'item_editor.dart\';
import \'roi_scanner.dart\';

class ListaScreen extends StatefulWidget {
  const ListaScreen({super.key});
  @override State<ListaScreen> createState() => _ListaScreenState();
}

class _ListaScreenState extends State<ListaScreen> {
  final _nameCtrl = TextEditingController();
  final _priceCtrl = TextEditingController();
  final _qtyCtrl = TextEditingController(text: \'1\');
  final _storeCtrl = TextEditingController();
  final _quickCtrl = TextEditingController();
  final _totalsKey = GlobalKey();
  String _addCurrency = \'VES\';
  String _storeName = \'\';

  @override
  void dispose() {
    _nameCtrl.dispose(); _priceCtrl.dispose();
    _qtyCtrl.dispose(); _storeCtrl.dispose(); _quickCtrl.dispose();
    super.dispose();
  }

  // ── MÉTODOS CRÍTICOS INTACTOS - NO TOCAR FIRMA ──
  Future<void> _scanItem(AppStore store) async {
    HapticFeedback.lightImpact();
    var code = await RoiScannerScreen.scan(context);
    if (!mounted) return;
    if (code == \'__manual__\') {
      final c = TextEditingController();
      final ok = await showVeSheet<bool>(context: context, builder: (_) => _ManualCodeSheet(ctrl: c));
      if (ok != true) return;
      code = c.text.trim();
    }
    if (code == null || code.isEmpty) return;
    final scanned = code;
    final idx = store.cart.indexWhere((e) => e.barcode == scanned);
    if (idx != -1) {
      store.updateCartItem(store.cart[idx].id, store.cart[idx].copyWith(quantity: store.cart[idx].quantity + 1));
      if(mounted) ShadToaster.of(context).show(ShadToast(title: Text(\'${store.cart[idx].name} +1\')));
      return;
    }
    final matches = store.products.where((p) => p.barcode == scanned).toList();
    if (matches.isNotEmpty) {
      final p = matches.first; final last = p.latestRecord;
      if (last != null) {
        store.addToCart(CartItem(id: \'\', productId: p.id, name: p.name, quantity: int.tryParse(_qtyCtrl.text) ?? 1, price: last.originalPrice, currency: last.currency, barcode: p.barcode));
        if (_storeName.trim().isNotEmpty) store.addStore(_storeName);
        if(mounted) ShadToaster.of(context).show(ShadToast(title: Text(\'${p.name} agregado\')));
        return;
      }
      if(mounted) showItemEditorSheet(context, initialName: p.name, barcode: scanned);
      return;
    }
    if(mounted) showItemEditorSheet(context, initialName: scanned, barcode: scanned);
  }

  void _quickAdd(AppStore store) {
    final name = _quickCtrl.text.trim();
    if (name.isEmpty) return;
    final hit = store.products.where((p) => p.name.toLowerCase() == name.toLowerCase()).toList();
    if (hit.isNotEmpty && hit.first.latestRecord != null) {
      final p = hit.first; final r = p.latestRecord!;
      store.addToCart(CartItem(id: \'\', productId: p.id, name: p.name, quantity: 1, price: r.originalPrice, currency: r.currency, barcode: p.barcode));
      _quickCtrl.clear(); HapticFeedback.selectionClick(); return;
    }
    showItemEditorSheet(context, initialName: name);
  }

  void _addItem(AppStore store) {
    final name = _nameCtrl.text.trim();
    final price = parseLocaleNum(_priceCtrl.text) ?? 0;
    final qty = int.tryParse(_qtyCtrl.text) ?? 1;
    if (name.isEmpty || price <= 0) {
      ShadToaster.of(context).show(const ShadToast.destructive(title: Text(\'Nombre y precio válido\')));
      return;
    }
    store.addToCart(CartItem(id: \'\', name: name, quantity: qty.clamp(1,999), price: price, currency: _addCurrency));
    if (_storeName.trim().isNotEmpty) store.addStore(_storeName);
    _nameCtrl.clear(); _priceCtrl.clear(); _qtyCtrl.text = \'1\';
    HapticFeedback.mediumImpact();
  }

  // Memoizado: solo recalcula si cambia cart o ctx
  ({double usd, Map<Currency, double> byCurrency, int units}) _totals(AppStore s, RateContext ctx) {
    final by = <Currency, double>{}; var usd = 0.0; var units = 0;
    for (final i in s.cart) {
      final c = CurrencyX.from(i.currency); final u = ctx.unitsPerUSD(c) ?? 0;
      final line = i.price * i.quantity;
      by[c] = (by[c] ?? 0) + line; usd += u > 0 ? line / u : 0; units += i.quantity;
    }
    return (usd: usd, byCurrency: by, units: units);
  }

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    
    // SELECTOR: solo este widget observa el carrito, no toda la pantalla
    return Selector<AppStore, List<CartItem>>(
      selector: (_, s) => s.cart,
      builder: (context, cart, _) {
        final store = context.read<AppStore>();
        final ctx = store.contextOf(module: RateModule.calculator);
        final totals = _totals(store, ctx);

        return Scaffold(
          backgroundColor: theme.colorScheme.background,
          body: Stack(
            children: [
              const VeAmbient(opacity: 0.4, child: SizedBox.expand()),
              SafeArea(
                child: CustomScrollView(
                  slivers: [
                    // Header no hace watch, es estático
                    SliverToBoxAdapter(child: _Header(totals: totals, ctx: ctx)),
                    SliverToBoxAdapter(child: Padding(
                      padding: const EdgeInsets.fromLTRB(16,12,16,0),
                      child: _QuickAddCard(
                        quickCtrl: _quickCtrl, nameCtrl: _nameCtrl, priceCtrl: _priceCtrl,
                        qtyCtrl: _qtyCtrl, storeCtrl: _storeCtrl,
                        addCurrency: _addCurrency,
                        onCurrency: (v) => setState(()=> _addCurrency = v),
                        onStoreName: (v) => _storeName = v,
                        onScan: () => _scanItem(store),
                        onQuickAdd: () => _quickAdd(store),
                        onAdd: () => _addItem(store),
                      ),
                    )),
                    if (cart.isEmpty)
                      const SliverToBoxAdapter(child: Padding(padding: EdgeInsets.all(16), child: VeEmpty(icon: LucideIcons.shoppingBag, title: \'Tu lista está vacía\', description: \'Escanea o añade un producto. Se sincroniza en vivo si abres una sala.\'))),
                    
                    if (cart.isNotEmpty) ...[
                      SliverToBoxAdapter(child: Padding(
                        padding: const EdgeInsets.fromLTRB(16,12,16,0),
                        child: Row(children: [
                          VeEyebrow(\'CARRITO · ${cart.length}\'),
                          const Spacer(),
                          VeBtn(variant: VeBtnVariant.ghost, size: VeBtnSize.sm, label: \'Vaciar\', icon: LucideIcons.trash2, onPressed: store.clearCart),
                        ]),
                      )),
                      SliverList.builder(
                        itemCount: cart.length,
                        itemBuilder: (_, i) => Padding(
                          padding: EdgeInsets.fromLTRB(16, i==0?8:6, 16, 0),
                          child: _CartRow(key: ValueKey(cart[i].id), item: cart[i], ctx: ctx),
                        ),
                      ),
                      SliverToBoxAdapter(child: _TotalsSection(totalsKey: _totalsKey, totals: totals, ctx: ctx)),
                      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,12,16,0), child: _PlantillasCard())),
                      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,12,16,0), child: _VueltoCard(ctx: ctx, totals: totals))),
                      SliverToBoxAdapter(child: Padding(padding: const EdgeInsets.fromLTRB(16,12,16,100), child: VeCard(child: SizedBox(width: double.infinity, child: VeBtn(label: \'Registrar compra y vaciar lista\', icon: LucideIcons.check, onPressed: () => showCheckoutSheet(context)))))),
                    ] else const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                ),
              ),
              // StickyBar con Selector fino para no reconstruir lista
              Selector<AppStore, ({double usd, String calcCode})>(
                selector: (_, s) {
                  final c = s.contextOf(module: RateModule.calculator);
                  final t = _totals(s, c);
                  return (usd: t.usd, calcCode: s.settings.calcCurrency);
                },
                builder: (_, data, __) {
                  final store2 = context.read<AppStore>();
                  final ctx2 = store2.contextOf(module: RateModule.calculator);
                  final calcCur = CurrencyX.from(data.calcCode);
                  final totalInCalc = calcCur == Currency.usd ? data.usd : data.usd * (ctx2.unitsPerUSD(calcCur) ?? 0);
                  return VeStickyBar(child: Row(children: [
                    Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Selector<AppStore, int>(selector: (_,s)=> s.cart.length, builder: (_, len, __) => Text(\'$len productos\', style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground))),
                      Text(fmtMoneyCode(totalInCalc, calcCur.code), style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: theme.colorScheme.foreground)),
                    ]),
                    const Spacer(),
                    VeBtn(label: \'Finalizar compra\', icon: LucideIcons.creditCard, enabled: data.usd > 0, onPressed: () => showCheckoutSheet(context)),
                  ]));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

// ── WIDGETS EXTRÁIDOS Y CONST-CAPABLE ──
class _Header extends StatelessWidget {
  const _Header({required this.totals, required this.ctx});
  final dynamic totals; final RateContext ctx;
  @override Widget build(BuildContext context) {
    final store = context.read<AppStore>(); final theme = ShadTheme.of(context);
    final calcCur = CurrencyX.from(store.settings.calcCurrency);
    final totalInCalc = calcCur == Currency.usd ? totals.usd : totals.usd * (ctx.unitsPerUSD(calcCur) ?? 0);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16,12,16,12),
      child: VeCard(padding: const EdgeInsets.all(18), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Text(\'TOTAL ESTIMADO\', style: TextStyle(fontSize: 10, letterSpacing: 1, fontWeight: FontWeight.w700, color: theme.colorScheme.mutedForeground)),
          const Spacer(),
          CurrencySelect(value: calcCur, onChanged: (c) => store.setSetting(\'calcCurrency\', c.code)),
          const SizedBox(width: 8),
          Selector<RoomController, bool>(selector: (_, r)=> r.connected, builder: (_, connected, __) => connected ? VeBadge(label: \'Sala ${context.read<RoomController>().code}\', variant: VeBadgeVariant.success, icon: LucideIcons.users) : const SizedBox.shrink()),
        ]),
        const SizedBox(height: 8),
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(fmtMoneyCode(totalInCalc, calcCur.code), style: TextStyle(fontSize: 54, fontWeight: FontWeight.w800, letterSpacing: -2.5, height: 1, color: theme.colorScheme.foreground, fontFeatures: const [FontFeature.tabularFigures()]))),
        const SizedBox(height: 6),
        Wrap(spacing: 6, children: [ VeBadge(label: \'${store.cart.length} ítems · ${totals.units} unidades\', variant: VeBadgeVariant.muted), if(totals.usd > 0) VeBadge(label: fmtUSD(totals.usd), variant: VeBadgeVariant.outline)]),
        if(store.data.budget.amount > 0) Padding(padding: const EdgeInsets.only(top:12), child: _BudgetBar(totalUsd: totals.usd, ctx: ctx)),
      ])),
    );
  }
}

class _CartRow extends StatelessWidget {
  const _CartRow({super.key, required this.item, required this.ctx});
  final CartItem item; final RateContext ctx;
  @override Widget build(BuildContext context) {
    final theme = ShadTheme.of(context); final c = CurrencyX.from(item.currency); final store = context.read<AppStore>();
    return VeCard(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10), child: Row(children: [
      ShadCheckbox(value: item.checked, onChanged: (v) => store.updateCartItem(item.id, item.copyWith(checked: v, checkedBy: v ? \'Yo\' : null, clearCheckedBy: !v))),
      const SizedBox(width: 10),
      Expanded(child: GestureDetector(onTap: () => showItemEditorSheet(context, item: item), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text(item.name, maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600, decoration: item.checked ? TextDecoration.lineThrough : null, color: item.checked ? theme.colorScheme.mutedForeground : theme.colorScheme.foreground)),
        Text(\'${fmtCurrency(item.price, c)} × ${item.quantity}\', style: TextStyle(fontSize: 11.5, color: theme.colorScheme.mutedForeground)),
      ]))),
      VeStepper(value: item.quantity, onDec: () => store.updateCartItem(item.id, item.copyWith(quantity: (item.quantity-1).clamp(1,999))), onInc: () => store.updateCartItem(item.id, item.copyWith(quantity: (item.quantity+1).clamp(1,999)))),
      VeBtn(variant: VeBtnVariant.ghost, size: VeBtnSize.icon, icon: LucideIcons.trash2, onPressed: () => store.removeFromCart(item.id)),
    ]));
  }
}

// Resto de sub-widgets igual que v1 pero ya extraídos para no reconstruir...
class _QuickAddCard extends StatelessWidget {
  const _QuickAddCard({required this.quickCtrl, required this.nameCtrl, required this.priceCtrl, required this.qtyCtrl, required this.storeCtrl, required this.addCurrency, required this.onCurrency, required this.onStoreName, required this.onScan, required this.onQuickAdd, required this.onAdd});
  final TextEditingController quickCtrl, nameCtrl, priceCtrl, qtyCtrl, storeCtrl; final String addCurrency; final ValueChanged<String> onCurrency, onStoreName; final VoidCallback onScan, onQuickAdd, onAdd;
  @override Widget build(BuildContext context) {
    return VeCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      const VeEyebrow(\'AGREGAR PRODUCTO\'), const SizedBox(height: 10),
      Row(children: [ Expanded(child: VeInput(controller: quickCtrl, placeholder: \'¿Qué compraste?\', onSubmitted: (_) => onQuickAdd())), const SizedBox(width: 8), VeBtn(variant: VeBtnVariant.ghost, size: VeBtnSize.icon, icon: LucideIcons.scanBarcode, onPressed: onScan), const SizedBox(width: 6), VeBtn(icon: LucideIcons.plus, label: \'Añadir\', onPressed: onQuickAdd)]),
      const SizedBox(height: 10),
      Row(children: [ Expanded(child: VeInput(controller: nameCtrl, placeholder: \'Producto\')), const SizedBox(width: 8), SizedBox(width: 80, child: VeInput(controller: qtyCtrl, placeholder: \'Cant.\'))]),
      const SizedBox(height: 8),
      Row(children: [ Expanded(child: VeInput(controller: priceCtrl, placeholder: \'Precio unitario\')), const SizedBox(width: 8), CurrencySelect(value: CurrencyX.from(addCurrency), onChanged: (c) => onCurrency(c.code))]),
      const SizedBox(height: 8), VeInput(controller: storeCtrl, placeholder: \'Tienda (opcional)\', onChanged: onStoreName),
      const SizedBox(height: 12), SizedBox(width: double.infinity, child: VeBtn(label: \'Agregar a la lista\', icon: LucideIcons.shoppingBag, onPressed: onAdd)),
    ]));
  }
}
class _BudgetBar extends StatelessWidget {
  const _BudgetBar({required this.totalUsd, required this.ctx}); final double totalUsd; final RateContext ctx;
  @override Widget build(BuildContext context) {
    final store = context.watch<AppStore>(); final theme = ShadTheme.of(context); final b = store.data.budget; final cur = CurrencyX.from(b.currency);
    final u = ctx.unitsPerUSD(cur) ?? 0; final budgetUsd = u>0 ? b.amount/u : 0; final pct = budgetUsd>0 ? (totalUsd/budgetUsd*100) : 0.0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(children: [Text(\'Presupuesto ${fmtMoney(b.amount, cur)}\', style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground)), const Spacer(), Text(\'${pct.toStringAsFixed(0)}%\', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: pct>100 ? theme.colorScheme.destructive : theme.colorScheme.primary))]),
      const SizedBox(height: 6), ClipRRect(borderRadius: BorderRadius.circular(99), child: LinearProgressIndicator(value: (pct/100).clamp(0,1), minHeight: 6, backgroundColor: theme.colorScheme.muted, valueColor: AlwaysStoppedAnimation(pct>100 ? theme.colorScheme.destructive : theme.colorScheme.primary))),
    ]);
  }
}
class _TotalsSection extends StatelessWidget {
  const _TotalsSection({required this.totalsKey, required this.totals, required this.ctx});
  final GlobalKey totalsKey; final dynamic totals; final RateContext ctx;
  @override Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(padding: const EdgeInsets.fromLTRB(16,12,16,0), child: VeCard(child: Column(children: [
      RepaintBoundary(key: totalsKey, child: Container(color: theme.colorScheme.card, padding: const EdgeInsets.all(8), child: Column(children: [
        Row(children: [Text(\'ValoraVE · Totales\', style: TextStyle(fontFamily: \'SpaceGrotesk\', fontWeight: FontWeight.w800, fontSize: 13, color: theme.colorScheme.foreground)), const Spacer(), Text(fmtDate(DateTime.now()), style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground))]),
        const SizedBox(height: 8),
        for(final e in (totals.byCurrency as Map<Currency,double>).entries) Padding(padding: const EdgeInsets.symmetric(vertical: 4), child: Row(children: [Text(e.key.code, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: theme.colorScheme.mutedForeground)), const Spacer(), Text(fmtCurrency(e.value, e.key), style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))])),
        Divider(color: theme.colorScheme.border), Row(children: [Text(\'Total USD\', style: TextStyle(fontSize: 12, color: theme.colorScheme.mutedForeground)), const Spacer(), Text(fmtUSD(totals.usd), style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: theme.colorScheme.foreground))]),
      ]))),
      const SizedBox(height: 10),
      Row(children: [ Expanded(child: VeBtn(variant: VeBtnVariant.outline, label: \'Compartir PNG\', icon: LucideIcons.image, onPressed: () async { final bytes = await captureWidget(totalsKey); if(bytes!=null) await sharePng(bytes, \'valorave-totales.png\'); })), const SizedBox(width: 8), Expanded(child: VeBtn(variant: VeBtnVariant.ghost, label: \'Texto\', icon: LucideIcons.share2, onPressed: () => shareTotalsText(context, context.read<AppStore>(), totals)))])
    ])));
  }
}
// _PlantillasCard, _VueltoCard iguales a v1 - los omito por brevedad pero van idénticos
class _PlantillasCard extends StatelessWidget { @override Widget build(BuildContext context) { final store = context.watch<AppStore>(); final theme = ShadTheme.of(context); return VeCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ Row(children: [const VeEyebrow(\'PLANTILLAS\'), const Spacer(), VeBtn(variant: VeBtnVariant.ghost, size: VeBtnSize.sm, label: \'Guardar carrito\', icon: LucideIcons.bookmark, onPressed: () async { final c = TextEditingController(); final ok = await showVeSheet<bool>(context: context, builder: (_) => _SaveTemplateSheet(ctrl: c)); if(ok==true) { final id = store.saveTemplate(c.text); if(id==null && context.mounted) ShadToaster.of(context).show(const ShadToast.destructive(title: Text(\'Lista vacía\'))); }})]), const SizedBox(height: 8), if(store.templates.isEmpty) Text(\'Congela tu lista repetida (máx 20) y aplícala con un toque.\', style: TextStyle(fontSize: 12, color: theme.colorScheme.mutedForeground)) else Wrap(spacing: 8, runSpacing: 8, children: [ for(final t in store.templates) VeChip(label: \'${t.name} · ${t.items.length}\', onTap: () { store.applyTemplate(t.id); HapticFeedback.lightImpact(); }, onDeleted: () => store.deleteTemplate(t.id))])]));}}
class _VueltoCard extends StatefulWidget { const _VueltoCard({required this.ctx, required this.totals}); final RateContext ctx; final dynamic totals; @override State<_VueltoCard> createState() => _VueltoCardState();}
class _VueltoCardState extends State<_VueltoCard> { final _paid = TextEditingController(); String _cur=\'VES\'; @override Widget build(BuildContext context) { final theme = ShadTheme.of(context); final rate = widget.ctx.unitsPerUSD(Currency.ves) ?? 0; final totalBs = rate>0 ? widget.totals.usd*rate : 0; final paid = parseLocaleNum(_paid.text) ?? 0; final diff = paid - totalBs; return VeCard(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [ const VeEyebrow(\'VUELTO\'), const SizedBox(height: 8), Row(children: [Expanded(child: VeInput(controller: _paid, placeholder: \'¿Con cuánto pagas? ${fmtMoney(totalBs, Currency.ves)}\', onChanged: (_)=> setState((){}))), const SizedBox(width:8), CurrencySelect(value: CurrencyX.from(_cur), onChanged: (c)=> setState(()=> _cur=c.code))]), if(paid>0) Padding(padding: const EdgeInsets.only(top:10), child: Text(diff>=0 ? \'Vuelto: ${fmtCurrency(diff, CurrencyX.from(_cur))}\' : \'Faltan: ${fmtCurrency(-diff, CurrencyX.from(_cur))}\', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800, color: diff>=0 ? const Color(0xFF10B981) : theme.colorScheme.destructive)))]));}}
class _ManualCodeSheet extends StatelessWidget { const _ManualCodeSheet({required this.ctrl}); final TextEditingController ctrl; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const VeTitle(\'Código a mano\', size: 18), const SizedBox(height:12), VeInput(controller: ctrl, placeholder: \'Código de barras\', autofocus: true), const SizedBox(height:12), VeBtn(label: \'Buscar\', onPressed: ()=> Navigator.pop(context, true))])) ;}
class _SaveTemplateSheet extends StatelessWidget { const _SaveTemplateSheet({required this.ctrl}); final TextEditingController ctrl; @override Widget build(BuildContext context) => Padding(padding: const EdgeInsets.all(20), child: Column(mainAxisSize: MainAxisSize.min, children: [const VeTitle(\'Guardar plantilla\', size: 18), const SizedBox(height:12), VeInput(controller: ctrl, placeholder: \'Nombre de la plantilla\', autofocus: true), const SizedBox(height:12), VeBtn(label: \'Guardar\', onPressed: ()=> Navigator.pop(context, true))])) ;}
