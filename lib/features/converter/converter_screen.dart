/// ─── Conversor (§9.2 · MODULE=converter) [Linear Edition] ─────────
library;

import \'dart:async\';
import \'dart:typed_data\';
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

// parts vinculados
part \'converter_reference.dart\';
part \'converter_history.dart\';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});
  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  // ── Estado dual ──
  final _fromCtrl = TextEditingController(text: \'1\');
  final _toCtrl = TextEditingController();
  final _shareKey = GlobalKey();
  final _notesCtrl = TextEditingController();
  
  String _driver = \'from\'; // \'from\' | \'to\'
  bool _syncing = false;
  double get _fromTyped => parseLocaleNum(_fromCtrl.text) ?? 0;
  double get _toTyped => parseLocaleNum(_toCtrl.text) ?? 0;

  // ── Fecha / Histórico ──
  String _dateMode = \'today\';
  DateTime? _customDate;
  Map<String, double>? _historicRates;
  bool _historicLoading = false;

  Timer? _notesSave;
  AppStore? _storeRef;

  @override
  void initState() {
    super.initState();
    _storeRef = context.read<AppStore>();
    _notesCtrl.text = _storeRef!.readConversionNotes();
    _notesCtrl.addListener(_onNotesChanged);
    _fromCtrl.addListener(() => _onFieldChanged(\'from\'));
    _toCtrl.addListener(() => _onFieldChanged(\'to\'));
    // init sync
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncFields());
  }

  void _onNotesChanged() {
    _notesSave?.cancel();
    _notesSave = Timer(const Duration(milliseconds: 600), () {
      _storeRef?.writeConversionNotes(_notesCtrl.text);
    });
  }

  void _onFieldChanged(String driver) {
    if (_syncing) return;
    _driver = driver;
    _syncFields();
  }

  void _syncFields() {
    final store = context.read<AppStore>();
    final ctx = _effectiveContext(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    if (plan == null || plan.rate == 0) return;

    setState(() {}); // refresca result
    _syncing = true;
    try {
      if (_driver == \'from\') {
        final v = _fromTyped;
        final res = v * plan.rate;
        _toCtrl.text = v == 0 ? \'\' : fmtNum(res, decimals: smartDecimals(res, to));
      } else {
        final v = _toTyped;
        final res = v / plan.rate;
        _fromCtrl.text = v == 0 ? \'\' : fmtNum(res, decimals: smartDecimals(res, from));
      }
    } finally {
      _syncing = false;
    }
  }

  void _swapSides(AppStore store) {
    HapticFeedback.lightImpact();
    final from = store.data.converter.from;
    final to = store.data.converter.to;
    // REGLA DE ORO: nunca par idéntico -> swap
    store.setConverterPair(to, from);
    // conserva el valor activo
    final keeper = _driver == \'from\' ? _fromCtrl.text : _toCtrl.text;
    _syncing = true;
    if (_driver == \'from\') {
      _toCtrl.text = keeper;
      _driver = \'to\';
    } else {
      _fromCtrl.text = keeper;
      _driver = \'from\';
    }
    _syncing = false;
    _syncFields();
  }

  RateContext _effectiveContext(AppStore store) {
    final base = store.contextOf(module: RateModule.converter);
    if (_dateMode == \'today\' || _historicRates == null) return base;
    return RateContext(rates: _historicRates!, selected: base.selected);
  }

  void _applyRateContext() {
    final DateTime? target = switch (_dateMode) {
      \'yesterday\' => DateTime.now().subtract(const Duration(days: 1)),
      \'week\' => DateTime.now().subtract(const Duration(days: 7)),
      \'custom\' => _customDate,
      _ => null,
    };
    setState(() {
      _historicRates = null;
      if (target != null) {
        _historicLoading = true;
        _loadHistoric(target);
      } else {
        _syncFields();
      }
    });
  }

  Future<void> _loadHistoric(DateTime date) async {
    final store = context.read<AppStore>();
    final day = SnapshotPoint.dayKey(date);
    final rates = <String, double>{};
    for (final id in [\'ves-bcv\',\'ves-parallel\',\'eur-ves-oficial\',\'cop-trm\',\'brl-br\',\'mxn-banxico\']) {
      try {
        final p = await rateOn(id, day, localFallback: (sid, d) {
          final local = store.snapshots.where((x) => x.sourceId == sid && x.day == d).toList()
            ..sort((a,b) => a.day.compareTo(b.day));
          return local.isEmpty ? null : HistPoint(date: local.last.day, rate: local.last.rate);
        });
        if (p != null) rates[id] = p.rate;
      } catch (_) {}
    }
    if (!mounted) return;
    setState(() { _historicRates = rates; _historicLoading = false; });
    _syncFields();
  }

  Future<void> _sharePng() async {
    final bytes = await captureWidget(_shareKey);
    if (!mounted) return;
    if (bytes == null) {
      ShadToaster.of(context).show(ShadToast.destructive(title: const Text(\'No pude generar la imagen\')));
      return;
    }
    await sharePng(bytes, \'valorave-conversion.png\');
  }

  @override
  void dispose() {
    final pending = _notesSave?.isActive ?? false;
    _notesSave?.cancel();
    if (pending) _storeRef?.writeConversionNotes(_notesCtrl.text);
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final theme = ShadTheme.of(context);
    final ctx = _effectiveContext(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final offline = context.watch<RatesPoller>().offlineNet;

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Stack(
        children: [
          const VeAmbient(opacity: 0.45, child: SizedBox.expand()),
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
              children: [
                // Header Linear
                Row(children: [
                  const VeEyebrow(\'CONVERSOR · MODULE:CONVERTER\'),
                  const Spacer(),
                  if (offline) VeBadge(label: \'Offline · local\', variant: VeBadgeVariant.warning, icon: LucideIcons.wifiOff),
                  const SizedBox(width: 8),
                  VeBtn(variant: VeBtnVariant.ghost, size: VeBtnSize.sm, icon: LucideIcons.info, onPressed: () => showVeSheet(context: context, builder: (_) => const ConverterReferenceSheet())),
                ]),
                const SizedBox(height: 8),
                VeTitle(\'Conversor\', size: 28),
                Text(\'Puente USD·EUR visible · ruta honesta · histórico real\', style: TextStyle(fontSize: 13, color: theme.colorScheme.mutedForeground)),
                const SizedBox(height: 16),

                // ── HERO DUAL CARD ──
                RepaintBoundary(
                  key: _shareKey,
                  child: VeCard(
                    padding: EdgeInsets.zero,
                    child: Column(children: [
                      _MoneyRow(
                        label: \'Envías\',
                        currency: from,
                        controller: _fromCtrl,
                        active: _driver == \'from\',
                        onSelect: (c) {
                          if (c.code == to.code) { _swapSides(store); } 
                          else { store.setConverterPair(c.code, to.code); _syncFields(); }
                        },
                        onSourceOverride: (sid) => store.setModuleRateSource(RateModule.converter, from.code, sid == \'global\' ? null : sid),
                        selectedSource: ctx.selectedFor(from.code),
                      ),
                      // Divider + Swap
                      Stack(alignment: Alignment.center, children: [
                        Divider(height: 1, color: theme.colorScheme.border),
                        TapScale(
                          onTap: () => _swapSides(store),
                          child: Container(
                            padding: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.background,
                              border: Border.all(color: theme.colorScheme.border),
                              shape: BoxShape.circle,
                              boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10)],
                            ),
                            child: Icon(LucideIcons.arrowUpDown, size: 16, color: theme.colorScheme.primary),
                          ),
                        ),
                      ]),
                      _MoneyRow(
                        label: \'Recibes\',
                        currency: to,
                        controller: _toCtrl,
                        active: _driver == \'to\',
                        onSelect: (c) {
                          if (c.code == from.code) { _swapSides(store); }
                          else { store.setConverterPair(from.code, c.code); _syncFields(); }
                        },
                        onSourceOverride: (sid) => store.setModuleRateSource(RateModule.converter, to.code, sid == \'global\' ? null : sid),
                        selectedSource: ctx.selectedFor(to.code),
                      ),
                      // Footer rate
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.muted.withOpacity(0.4),
                          borderRadius: const BorderRadius.vertical(bottom: Radius.circular(14)),
                          border: Border(top: BorderSide(color: theme.colorScheme.border)),
                        ),
                        child: Row(children: [
                          Icon(LucideIcons.gitBranch, size: 12, color: theme.colorScheme.mutedForeground),
                          const SizedBox(width: 6),
                          Expanded(
                            child: plan == null
                              ? Text(\'Sin tasa para este par\', style: TextStyle(fontSize: 11.5, color: theme.colorScheme.mutedForeground))
                              : FittedBox(
                                  fit: BoxFit.scaleDown, alignment: Alignment.centerLeft,
                                  child: Text(\'1 ${from.code} = ${fmtNum(plan.rate, decimals: 4)} ${to.code} · ${plan.sourceIds.map((e) => convSourceNames[e] ?? e).join(" → ")}\',
                                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w500, color: theme.colorScheme.mutedForeground)),
                                ),
                          ),
                          VeBadge(label: fmtDate(DateTime.now()), variant: VeBadgeVariant.muted),
                        ]),
                      ),
                      // Marca para PNG
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                          Container(width: 18, height: 18, decoration: BoxDecoration(color: const Color(0xFF111827), borderRadius: BorderRadius.circular(5)), alignment: Alignment.center, child: const Text(\'V\', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 10))),
                          const SizedBox(width: 6),
                          Text(\'ValoraVE · valorave.app\', style: TextStyle(fontSize: 10, color: theme.colorScheme.mutedForeground, fontWeight: FontWeight.w600)),
                        ]),
                      )
                    ]),
                  ),
                ),

                const SizedBox(height: 10),
                // Quick Adjustments
                VeGroup(
                  title: \'Ajustes rápidos\',
                  trailing: Text(\'${fmtNum(_fromTyped)} ${from.code}\', style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground)),
                  child: Wrap(spacing: 8, runSpacing: 8, children: [
                    for (final adj in quickAdjustments)
                      VeChip(label: adj.label, selected: false, onTap: () {
                        HapticFeedback.selectionClick();
                        final next = adj.apply(_driver == \'from\' ? _fromTyped : _toTyped);
                        _syncing = true;
                        if (_driver == \'from\') _fromCtrl.text = fmtPlain(next, 2);
                        else _toCtrl.text = fmtPlain(next, 2);
                        _syncing = false;
                        _syncFields();
                      }),
                  ]),
                ),

                // Fecha Tasas
                _FechaTasasCard(
                  mode: _dateMode, customDate: _customDate, loading: _historicLoading, historic: _historicRates,
                  onMode: (m) { setState(() { _dateMode = m; if(m==\'custom\' && _customDate==null) _customDate = DateTime.now().subtract(const Duration(days:7)); }); _applyRateContext(); },
                  onDate: (d) { setState(() => _customDate = d); _applyRateContext(); },
                ),

                _TablaFuentes(ctx: ctx, from: from, to: to),
                _TablaReferencia(ctx: ctx, amount: _fromTyped, from: from),
                _RecientesBlock(from: from, to: to, currentAmount: _fromTyped, onPick: (r) {
                  store.setConverterPair(r.from, r.to);
                  _syncing = true;
                  _fromCtrl.text = fmtPlain(r.amount, 2);
                  _driver = \'from\';
                  _syncing = false;
                  _syncFields();
                }),
                _NotasBlock(ctrl: _notesCtrl),
              ],
            ),
          ),
          // Sticky Bar Linear
          VeStickyBar(
            child: Row(children: [
              Expanded(child: Text(\'Imagen 1080px con ruta y fuentes\', style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground))),
              VeBtn(variant: VeBtnVariant.ghost, label: \'Copiar\', icon: LucideIcons.copy, onPressed: plan==null? null : () {
                final txt = \'${fmtNum(_fromTyped)} ${from.code} = ${fmtNum(_toTyped)} ${to.code} (${plan.sourceIds.join(", ")})\';
                Clipboard.setData(ClipboardData(text: txt));
              }),
              const SizedBox(width: 8),
              VeBtn(label: \'Compartir\', icon: LucideIcons.share2, onPressed: plan==null? null : _sharePng),
            ]),
          ),
        ],
      ),
    );
  }
}

/// ── Fila de dinero con selector + input blindado ──
class _MoneyRow extends StatelessWidget {
  const _MoneyRow({required this.label, required this.currency, required this.controller, required this.active, required this.onSelect, required this.onSourceOverride, required this.selectedSource});
  final String label;
  final Currency currency;
  final TextEditingController controller;
  final bool active;
  final ValueChanged<Currency> onSelect;
  final ValueChanged<String> onSourceOverride;
  final String? selectedSource;

  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.all(14),
      child: Row(children: [
        // Selector divisa
        VeBtn(
          variant: VeBtnVariant.outline, size: VeBtnSize.sm,
          label: currency.code,
          icon: LucideIcons.chevronDown,
          onPressed: () => showVeSheet(context: context, builder: (_) => _CurrencyPicker(current: currency, onPick: onSelect)),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(label.toUpperCase(), style: TextStyle(fontSize: 10, letterSpacing: 0.8, fontWeight: FontWeight.w700, color: theme.colorScheme.mutedForeground)),
            const SizedBox(height: 2),
            // BLINDAJE: FittedBox scaleDown
            FittedBox(
              fit: BoxFit.scaleDown, alignment: Alignment.centerRight,
              child: SizedBox(
                width: 220,
                child: TextField(
                  controller: controller,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textAlign: TextAlign.right,
                  style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, letterSpacing: -1.2, color: active ? theme.colorScheme.foreground : theme.colorScheme.mutedForeground, fontFeatures: const [FontFeature.tabularFigures()]),
                  decoration: InputDecoration(border: InputBorder.none, hintText: \'0,00\', isDense: true, contentPadding: EdgeInsets.zero, hintStyle: TextStyle(color: theme.colorScheme.mutedForeground.withOpacity(0.4))),
                  inputFormatters: [VeMoneyFormatter()], // es-VE puntos miles, coma decimal
                ),
              ),
            ),
            Text(fmtCurrency(parseLocaleNum(controller.text) ?? 0, currency), style: TextStyle(fontSize: 11, color: theme.colorScheme.mutedForeground)),
          ]),
        ),
      ]),
    );
  }
}

class _FechaTasasCard extends StatelessWidget {
  const _FechaTasasCard({required this.mode, required this.customDate, required this.loading, required this.historic, required this.onMode, required this.onDate});
  final String mode; final DateTime? customDate; final bool loading; final Map<String,double>? historic;
  final ValueChanged<String> onMode; final ValueChanged<DateTime> onDate;
  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return VeCard(
      margin: const EdgeInsets.only(top: 12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const VeEyebrow(\'FECHA DE TASAS\'),
        const SizedBox(height: 10),
        SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(children: [
          VeChip(label: \'Hoy\', selected: mode==\'today\', onTap: ()=> onMode(\'today\')),
          const SizedBox(width: 6),
          VeChip(label: \'Ayer\', selected: mode==\'yesterday\', onTap: ()=> onMode(\'yesterday\')),
          const SizedBox(width: 6),
          VeChip(label: \'Hace 7d\', selected: mode==\'week\', onTap: ()=> onMode(\'week\')),
          const SizedBox(width: 6),
          VeChip(label: customDate==null? \'Elegir fecha\' : fmtDate(customDate!), selected: mode==\'custom\', icon: LucideIcons.calendarDays, onTap: () async {
            final now = DateTime.now();
            final picked = await showDatePicker(context: context, initialDate: customDate ?? now.subtract(const Duration(days:7)), firstDate: DateTime(2023,1,3), lastDate: now, locale: const Locale(\'es\'));
            if(picked!=null){ onMode(\'custom\'); onDate(picked); }
          }),
        ])),
        if(mode!=\'today\') ...[
          const SizedBox(height: 10),
          if(loading) const SizedBox(width:16,height:16,child: CircularProgressIndicator(strokeWidth: 2))
          else if(historic!=null && historic!.isEmpty) Text(\'Sin datos para esa fecha. Serie desde 03-ene-2023.\', style: TextStyle(fontSize: 12, color: theme.colorScheme.destructive))
          else if(historic!=null) VeBadge(label: \'${historic!.length} fuentes históricas\', variant: VeBadgeVariant.muted),
        ]
      ]),
    );
  }
}
