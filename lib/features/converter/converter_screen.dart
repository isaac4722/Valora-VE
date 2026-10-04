/// ─── Conversor (§9.2 · MODULE=converter) ───────────────────────────────────
/// Monto dual from/to con swap y odómetros · cifras blindadas con
/// FittedBox(scaleDown) dentro de ReadWindow (números largos no rompen la
/// tarjeta) · selector de fuente por módulo (default SIEMPRE oficial) ·
/// fila de fecha de la tasa activa + calendario histórico de snapshots
/// reales (sin dato → sin dato, nunca fabrica) · ajustes rápidos pegados
/// al campo de entrada · referencia de fuentes del par (tap = usar) ·
/// montos de referencia · recientes (10) · notas (5000) · compartir con
/// tarjeta de marca 1080 px (memoria, sin archivo).
library;

import \'dart:async\';
import \'dart:typed_data\';

import \'package:flutter/material.dart\';
import \'package:provider/provider.dart\';
import \'package:shadcn_ui/shadcn_ui.dart\' show LucideIcons, ShadTheme;
import \'package:share_plus/share_plus.dart\';

import \'../../core/currencies.dart\';
import \'../../core/fmt.dart\';
import \'../../core/models.dart\';
import \'../../core/theme.dart\';
import \'../../data/history_api.dart\';
import \'../../data/rate_history.dart\';
import \'../../data/store.dart\';
import \'../../state/app_state.dart\' show RatesPoller;
import \'../../services/sharing.dart\';
import \'../../widgets/app_tips.dart\';
import \'../../widgets/app_tour.dart\' show TourKeys;
import \'../../widgets/rate_sheet.dart\';
import \'../../widgets/share_card.dart\';
import \'../../widgets/export_sheet.dart\';
import \'../../widgets/ui.dart\';

part \'converter_reference.dart\';
part \'converter_history.dart\';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  /// BIDIRECCIONAL (v19, orden del dueño): los DOS campos se editan.
  final _fromCtrl = TextEditingController(text: \'1\');
  final _toCtrl = TextEditingController();
  double _fromTyped = 1;
  double _toTyped = 0;
  String _driver = \'from\';
  String _lastSyncedPassive = \'\';

  String _dateMode = \'today\'; // today | yesterday | week | custom
  DateTime? _customDate;
  Map<String, double>? _historicRates;
  bool _historicLoading = false;
  final _notesCtrl = TextEditingController();
  Timer? _notesSave;
  AppStore? _storeRef;

  double _amountNowFor(RateContext ctx, Currency from, Currency to) {
    final rate = ctx.plan(from, to)?.rate ?? 0;
    if (_driver == \'to\') return rate > 0 && _toTyped > 0 ? _toTyped / rate : 0;
    return _fromTyped;
  }

  double get _amountNow {
    final store = context.read<AppStore>();
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    return _amountNowFor(ctx, from, to);
  }

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _storeRef = store;
    _notesCtrl.text = store.readConversionNotes();
    _notesCtrl.addListener(_onNotesChanged);
  }

  void _onNotesChanged() {
    _notesSave?.cancel();
    _notesSave = Timer(const Duration(milliseconds: 600), () {
      _storeRef?.writeConversionNotes(_notesCtrl.text);
    });
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
      }
    });
  }

  Future<void> _loadHistoric(DateTime date) async {
    final store = context.read<AppStore>();
    final offlineNet = context.read<RatesPoller>().offlineNet;
    final base = store.contextOf(module: RateModule.converter);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final planIds = base.plan(from, to)?.sourceIds ?? const <String>[];
    final ids = <String>{
      \'ves-bcv\',
      \'ves-parallel\',
      \'eur-ves-oficial\',
      \'cop-trm\',
      \'brl-br\',
      \'mxn-banxico\',
      ...planIds,
      base.sel(from),
      base.sel(to),
    };
    final day = SnapshotPoint.dayKey(date);
    
    // MEJORA PERFORMANCE: Separa manuales y paraleliza el resto
    final manualRates = <String, double>{};
    final toFetch = <String>[];
    for (final id in ids) {
      if (id == \'ves-avg\') continue;
      final def = RateSource.of(id);
      if (def?.category == SourceCategory.manual) {
        final v = base.rate(id);
        if (v > 0) manualRates[id] = v;
      } else {
        toFetch.add(id);
      }
    }

    final fetchedPoints = await Future.wait(toFetch.map((id) async {
      try {
        final point = await rateOn(
          id, day, preferLocal: offlineNet,
          localFallback: (sourceId, d) {
            final local = store.snapshots.where((p) => p.sourceId == sourceId && p.day == d).toList()
              ..sort((a, b) => a.day.compareTo(b.day));
            return local.isEmpty ? null : HistPoint(date: local.last.day, rate: local.last.rate);
          },
        );
        if (point != null) {
          final pointDay = point.date.length == 10 ? point.date : day;
          return SnapshotPoint(sourceId: id, day: pointDay, rate: point.rate);
        }
      } catch (_) {}
      return null;
    }));

    final fetched = fetchedPoints.whereType<SnapshotPoint>().toList();
    final rates = <String, double>{...manualRates};
    for (final p in fetched) rates[p.sourceId] = p.rate;

    if (fetched.isNotEmpty) {
      final merged = mergeSeries(fetched, store.snapshots);
      store.snapshots..clear()..addAll(merged);
      store.persistSnapshots();
    }
    final b = rates[\'ves-bcv\'], p = rates[\'ves-parallel\'];
    if (b != null && p != null) rates[\'ves-avg\'] = (b + p) / 2;
    if (mounted) setState(() { _historicRates = rates; _historicLoading = false; });
  }

  RateContext _context(AppStore store) {
    final base = store.contextOf(module: RateModule.converter);
    if (_dateMode == \'today\' || _historicRates == null) return base;
    return RateContext(rates: _historicRates!, selected: base.selected);
  }

  void _swapSides(AppStore store, Currency from, Currency to, ConversionPlan? plan, double result) {
    final rate = plan?.rate ?? 0;
    final nuevo = _driver == \'to\' ? _toTyped : (rate > 0 && result > 0 ? result : _fromTyped);
    store.setConverterPair(to.code, from.code);
    setState(() {
      _fromTyped = nuevo > 0 ? nuevo : 0;
      _toTyped = 0;
      _driver = \'from\';
      _lastSyncedPassive = \'\';
      _fromCtrl.text = fmtNum(_fromTyped, decimals: smartDecimals(_fromTyped, to));
    });
  }

  bool _hasOverride(AppStore store, Currency c) => store.data.settings.rateSourcesByModule.containsKey(moduleRateKey(RateModule.converter.code, c.code));

  void _pickSource(Currency c, String id) {
    final store = context.read<AppStore>();
    final global = store.sourceFor(c);
    if (id == global) {
      store.setModuleRateSource(RateModule.converter, c, null);
    } else {
      store.setModuleRateSource(RateModule.converter, c, id);
    }
  }

  Future<Set<String>> _diasRemotos(List<String> ids) async {
    if (context.read<RatesPoller>().offlineNet) return const <String>{};
    final probes = <String>{ for (final id in ids) ...(id == \'ves-avg\' ? const [\'ves-bcv\', \'ves-parallel\'] : [id]) };
    final results = await Future.wait(probes.where((id) {
      final def = RateSource.of(id);
      return def != null && def.category != SourceCategory.manual;
    }).map((id) async {
      try {
        final res = await seriesForSource(id, 180);
        return res.points.map((p) => p.date).toSet();
      } catch (_) { return <String>{}; }
    }));
    return results.expand((e) => e).toSet();
  }

  Future<void> _openHistoricCalendar() async {
    final store = context.read<AppStore>();
    final ctx = store.contextOf(module: RateModule.converter);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final ids = <String>{ if (plan != null) ...plan.sourceIds, ctx.sel(from), if (from != to) ctx.sel(to) };
    final days = <String>{ for (final id in ids) for (final p in snapshotSeries(store.snapshots, id, 180)) p.day };
    if (!mounted) return;
    final label = ids.map((id) => convSourceNames[id] ?? RateSource.of(id)?.label ?? id).join(\' + \');
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (_) => _CalendarioHistorico(days: days, futureDays: _diasRemotos(ids.toList()), initial: _dateMode == \'custom\' ? _customDate : null, sourceLabel: label),
    );
    if (picked == null || !mounted) return;
    setState(() { _customDate = picked; _dateMode = \'custom\'; });
    _applyRateContext();
  }

  Future<Uint8List?> _renderCard() async {
    final store = context.read<AppStore>();
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final amount = _amountNowFor(ctx, from, to);
    if (plan == null || amount <= 0) return null;
    final result = amount * plan.rate;
    final primaryId = plan.sourceIds.isNotEmpty ? plan.sourceIds.first : ctx.sel(from);
    final src = RateSource.of(primaryId);
    final label = convSourceNames[primaryId] ?? src?.label ?? primaryId;
    final cat = src?.category.label ?? \'\';
    return renderConversionSharePng(
      context, from: from, to: to, inputAmount: amount, resultAmount: result,
      rateLine: \'1 ${from.code} = ${fmtRate(plan.rate)} ${to.code}\',
      sourceLabel: cat.isEmpty ? label : \'$label · $cat\',
      date: _dateMode == \'today\' ? DateTime.now() : (_customDate ?? DateTime.now()),
    );
  }

  Future<void> _shareCard() async {
    final store = context.read<AppStore>();
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final amount = _amountNowFor(ctx, from, to);
    if (plan == null || amount <= 0) return;
    final result = amount * plan.rate;
    final text = \'${fmtMoney(amount, from)} ${from.code} = ${fmtMoney(result, to)} · 1 ${from.code} = ${fmtRate(plan.rate)} ${to.code} — ValoraVE\';
    await showExportSheet(context, ExportSpec(
      title: \'Resultado ${from.code} → ${to.code}\',
      subtitle: \'${fmtMoney(amount, from)} ${from.code} = ${fmtMoney(result, to)} ${to.code}\',
      formats: [
        ExportFormat(icon: Icons.subject_rounded, label: \'Texto\', hint: \'Cifra y tasa listas para pegar en un chat\', run: (share) async { await SharePlus.instance.share(ShareParams(text: text)); return null; }),
        ExportFormat(icon: Icons.image_outlined, label: \'Imagen PNG\', hint: \'Tarjeta de ValoraVE con la conversión\', run: (share) async {
          final png = await _renderCard(); if (png == null) return \'No pude generar la tarjeta\';
          if (share) { await sharePng(png, \'conversion-valorave.png\'); return null; }
          final path = await downloadBytes(png, fileName: \'conversion-valorave.png\');
          return path == null ? \'No se pudo guardar la imagen.\' : \'Guardado en: $path\';
        }),
      ],
    ));
  }

  void _copyResult() {
    final store = context.read<AppStore>();
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final amount = _amountNowFor(ctx, from, to);
    if (plan == null || amount <= 0) return;
    final result = amount * plan.rate;
    final primaryId = plan.sourceIds.isNotEmpty ? plan.sourceIds.first : ctx.sel(from);
    final src = RateSource.of(primaryId);
    final label = convSourceNames[primaryId] ?? src?.label ?? primaryId;
    final cat = src?.category.label ?? \'\';
    copiarAlPortapapeles(context, \'${fmtMoney(amount, from)} ${from.code} = ${fmtMoney(result, to)} ${to.code} · 1 ${from.code} = ${fmtRate(plan.rate)} ${to.code} ($label${cat.isEmpty ? \'\' : \' · $cat\'}) · ValoraVE\', \'Resultado copiado\');
  }

  void _syncPassiveController(RateContext ctx, Currency from, Currency to, double result, double amount) {
    final passiveTo = _driver == \'from\';
    final passiveTxt = passiveTo
        ? (result > 0 ? fmtNum(result, decimals: smartDecimals(result, to)) : \'\')
        : (amount > 0 ? fmtNum(amount, decimals: smartDecimals(amount, from)) : \'\');
    if (passiveTxt == _lastSyncedPassive) return;
    final ctrl = passiveTo ? _toCtrl : _fromCtrl;
    if (ctrl.text == passiveTxt) { _lastSyncedPassive = passiveTxt; return; }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (ctrl.text != passiveTxt) {
        ctrl.value = TextEditingValue(text: passiveTxt, selection: TextSelection.collapsed(offset: passiveTxt.length));
        _lastSyncedPassive = passiveTxt;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final fromCode = context.select<AppStore, String>((s) => s.data.converter.from);
    final toCode = context.select<AppStore, String>((s) => s.data.converter.to);
    final from = CurrencyX.from(fromCode);
    final to = CurrencyX.from(toCode);
    
    final store = context.watch<AppStore>();
    final ctx = _context(store);
    final plan = ctx.plan(from, to);
    final amount = _amountNowFor(ctx, from, to);
    double result = 0;
    if (plan != null && amount > 0) result = amount * plan.rate;

    _syncPassiveController(ctx, from, to, result, amount);

    final primaryId = (plan != null && plan.sourceIds.isNotEmpty) ? plan.sourceIds.first : ctx.sel(from);
    final src = RateSource.of(primaryId);
    final entry = store.board.sources[primaryId];
    final when = entry?.updatedAt ?? store.board.fetchedAt;
    final frescura = src?.category == SourceCategory.manual ? \'tu tasa manual\' : (when != null ? timeAgo(when) : \'sin fecha aún\');
    final srcLabel = convSourceNames[primaryId] ?? src?.label ?? primaryId;
    final subTitulo = (plan != null && plan.rate > 0) ? \'$srcLabel · 1 ${from.code} = ${fmtRate(plan.rate)} ${to.code}\' : \'Sin tasa disponible para este par\';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: VeEntry(
        child: ListView(
          cacheExtent: 800,
          addAutomaticKeepAlives: false,
          addRepaintBoundaries: true,
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            const TipsTrigger(scope: \'conversor\'),
            VeTitle(sub: Text(subTitulo), child: const Text(\'Conversor\')),
            KeyedSubtree(
              key: TourKeys.convFecha,
              child: _FechaTasas(
                mode: _dateMode, customDate: _customDate, loading: _historicLoading,
                sinDatos: _historicRates != null && !_historicLoading && (plan == null || plan.rate <= 0),
                onMode: (m) { setState(() => _dateMode = m); _applyRateContext(); },
                onOpenCalendar: _openHistoricCalendar,
              ),
            ),
            const SizedBox(height: 14),
            KeyedSubtree(
              key: TourKeys.convFuente,
              child: RepaintBoundary(
                child: _DualInput(
                  fromCtrl: _fromCtrl, toCtrl: _toCtrl, from: from, to: to, result: result, plan: plan, ctx: ctx,
                  activeSourceId: primaryId, frescura: frescura, hasOverride: _hasOverride(store, from),
                  onFromInput: (v) => setState(() { _fromTyped = v; _driver = \'from\'; _lastSyncedPassive = \'\'; }),
                  onToInput: (v) => setState(() { _toTyped = v; _driver = \'to\'; _lastSyncedPassive = \'\'; }),
                  onAdjust: (v) => setState(() {
                    _fromTyped = v <= 0 ? 0 : v; _driver = \'from\'; _lastSyncedPassive = \'\';
                    _fromCtrl.text = fmtNum(_fromTyped, decimals: smartDecimals(_fromTyped, from));
                  }),
                  onSwap: () => _swapSides(store, from, to, plan, result),
                  onFrom: (c) => c == to ? _swapSides(store, from, to, plan, result) : store.setConverterPair(c.code, to.code),
                  onTo: (c) => c == from ? _swapSides(store, from, to, plan, result) : store.setConverterPair(from.code, c.code),
                  onPickSource: _pickSource,
                  onClearOverride: () => store.setModuleRateSource(RateModule.converter, from, null),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Wrap(spacing: 8, runSpacing: 6, children: [
                VeBtn(variant: VeBtnVariant.secondary, icon: LucideIcons.share2, enabled: plan != null && result > 0, onPressed: _shareCard, child: const Text(\'Compartir\')),
                VeBtn(variant: VeBtnVariant.secondary, icon: LucideIcons.copy, enabled: plan != null && result > 0, onPressed: _copyResult, child: const Text(\'Copiar\')),
              ]),
            ),
            _ReferenciaFuentes(ctx: ctx, from: from, to: to, onPick: _pickSource),
            _TablaMontos(
              ctx: ctx, amount: amount, from: from,
              onAmount: (v) => setState(() { _fromTyped = v <= 0 ? 0 : v; _driver = \'from\'; _lastSyncedPassive = \'\'; _fromCtrl.text = fmtNum(_fromTyped, decimals: smartDecimals(_fromTyped, from)); }),
            ),
            _Recientes(from: from, to: to, amount: amount, result: result, plan: plan,
              onRestore: (r) {
                final rf = CurrencyX.from(r.from);
                if (from != rf || to != CurrencyX.from(r.to)) store.setConverterPair(r.from, r.to);
                setState(() { _fromTyped = r.amount; _driver = \'from\'; _lastSyncedPassive = \'\'; _fromCtrl.text = fmtNum(r.amount, decimals: smartDecimals(r.amount, rf)); });
              },
            ),
            _Notas(ctrl: _notesCtrl),
          ],
        ),
      ),
    );
  }
}

class _FechaTasas extends StatelessWidget {
  const _FechaTasas({required this.mode, required this.customDate, required this.loading, required this.sinDatos, required this.onMode, required this.onOpenCalendar});
  final String mode; final DateTime? customDate; final bool loading; final bool sinDatos;
  final ValueChanged<String> onMode; final VoidCallback onOpenCalendar;
  @override
  Widget build(BuildContext context) {
    final ink = Theme.of(context).extension<VeInk>()!;
    final String periodo = switch (mode) {
      \'yesterday\' => \'de ayer\', \'week\' => \'de hace 7 días\',
      _ => customDate == null ? \'del día elegido\' : \'del ${fmtDate(customDate!)}\',
    };
    return VeCard(
      padding: const EdgeInsets.all(12),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Wrap(spacing: 6, runSpacing: 6, children: [
          VeChip(active: mode == \'today\', onTap: () => onMode(\'today\'), child: const Text(\'Hoy\')),
          VeChip(active: mode == \'yesterday\', onTap: () => onMode(\'yesterday\'), child: const Text(\'Ayer\')),
          VeChip(active: mode == \'week\', onTap: () => onMode(\'week\'), child: const Text(\'Hace 7 días\')),
          VeChip(active: mode == \'custom\', onTap: onOpenCalendar, child: const Text(\'Elegir fecha\')),
        ]),
        if (mode != \'today\') ...[
          const SizedBox(height: 10),
          if (loading)
            const Row(children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text(\'Buscando la tasa del día…\', style: TextStyle(fontSize: 12))])
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: ink.warnBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: ink.warn.withValues(alpha: 0.35))),
              child: Row(children: [
                Icon(Icons.history, size: 15, color: ink.warn), const SizedBox(width: 8),
                Expanded(child: Text(sinDatos ? \'Sin datos para esa fecha. Elige un día del calendario.\' : \'Mostrando la tasa $periodo\', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ink.warn), maxLines: 2, overflow: TextOverflow.ellipsis)),
                VeBtn(variant: VeBtnVariant.ghost, size: VeBtnSize.sm, onPressed: () => onMode(\'today\'), child: const Text(\'Volver a hoy\')),
              ]),
            ),
        ],
      ]),
    );
  }
}

class _DualInput extends StatelessWidget {
  const _DualInput({required this.fromCtrl, required this.toCtrl, required this.from, required this.to, required this.result, required this.plan, required this.ctx, required this.activeSourceId, required this.frescura, required this.hasOverride, required this.onFromInput, required this.onToInput, required this.onAdjust, required this.onSwap, required this.onFrom, required this.onTo, required this.onPickSource, required this.onClearOverride});
  final TextEditingController fromCtrl, toCtrl;
  final Currency from, to; final double result; final ConversionPlan? plan;
  final RateContext ctx; final String activeSourceId, frescura; final bool hasOverride;
  final ValueChanged<double> onFromInput, onToInput, onAdjust;
  final VoidCallback onSwap; final ValueChanged<Currency> onFrom, onTo;
  final void Function(Currency c, String id) onPickSource; final VoidCallback onClearOverride;

  Widget _fuenteLine(BuildContext ctx2, ColorScheme scheme) {
    final src = RateSource.of(activeSourceId);
    final label = convSourceNames[activeSourceId] ?? src?.label ?? activeSourceId;
    return Row(children: [
      Expanded(child: InkWell(
        onTap: () => _openSourcesSheet(ctx2), borderRadius: BorderRadius.circular(10),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Row(children: [
          if (src != null) ...[SourceSeal(src.category), const SizedBox(width: 8)],
          Expanded(child: Text.rich(TextSpan(text: label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface), children: [TextSpan(text: \' · $frescura\', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant))]), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4), Icon(LucideIcons.chevronDown, size: 16, color: scheme.onSurfaceVariant),
        ])),
      )),
      if (hasOverride) VeBtn(variant: VeBtnVariant.ghost, size: VeBtnSize.sm, onPressed: onClearOverride, child: const Text(\'Seguir global\')),
    ]);
  }
  Future<void> _openSourcesSheet(BuildContext context) async {
    await showRateSheet(context, currency: from, ctx: ctx, currentId: activeSourceId, onPick: (id) => onPickSource(from, id));
  }
  double _fromValueOf(double result, ConversionPlan? plan) {
    final rate = plan?.rate ?? 0;
    return rate <= 0 ? 0 : (result > 0 ? result / rate : 0);
  }
  Widget _montoRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(from.symbol, style: VeText.displayNum(28, color: scheme.onSurfaceVariant, weight: FontWeight.w600)),
      const SizedBox(width: 8),
      Expanded(child: MoneyField(controller: fromCtrl, onChanged: onFromInput, maxDecimals: 6, style: VeText.displayNum(38, color: scheme.onSurface, weight: FontWeight.w600), decoration: const InputDecoration(hintText: \'Monto\', border: InputBorder.none, isCollapsed: true, contentPadding: EdgeInsets.symmetric(vertical: 8)))),
      const SizedBox(width: 8), CurrencySelect(value: from, onChanged: onFrom),
    ]);
  }
  Widget _resultadoRow(ColorScheme scheme) {
    final ok = plan != null && result > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: MoneyField(controller: toCtrl, onChanged: onToInput, maxDecimals: 6, style: VeText.displayNum(46, color: ok ? scheme.onSurface : scheme.onSurfaceVariant), decoration: InputDecoration(hintText: \'Resultado\', border: InputBorder.none, isCollapsed: true, contentPadding: const EdgeInsets.symmetric(vertical: 8), hintStyle: VeText.displayNum(46, color: scheme.onSurfaceVariant)))),
        const SizedBox(width: 8), CurrencySelect(value: to, onChanged: onTo),
      ]),
      Padding(padding: const EdgeInsets.only(left: 4, top: 2), child: Text(ok ? \'≈ ${fmtMoney(result, to)}\' : \'sin tasa para este par\', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: ok ? 12 : 10.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant))),
    ]);
  }
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return VeCard(
      padding: const EdgeInsets.all(14),
      child: Column(children: [
        _fuenteLine(context, scheme), const Divider(height: 18), _montoRow(context),
        Padding(padding: const EdgeInsets.symmetric(vertical: 2), child: SizedBox(height: 36, child: Stack(alignment: Alignment.center, children: [const Positioned.fill(child: Center(child: Divider(height: 1))), _SwapBtn(onTap: onSwap)]))),
        _resultadoRow(scheme),
        Padding(padding: const EdgeInsets.only(top: 10), child: Row(children: [for (final adj in quickAdjustments) Expanded(child: Padding(padding: const EdgeInsets.symmetric(horizontal: 2), child: VeChip(expands: true, onTap: () => onAdjust(adj.apply(_fromValueOf(result, plan))), child: Text(adj.label))))])),
      ]),
    );
  }
}

class _SwapBtn extends StatefulWidget {
  const _SwapBtn({required this.onTap});
  final VoidCallback onTap;
  @override
  State<_SwapBtn> createState() => _SwapBtnState();
}
class _SwapBtnState extends State<_SwapBtn> {
  double _turns = 0;
  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context);
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;
    return Semantics(
      button: true, label: \'Invertir par\',
      child: TapScale(
        onTap: () { setState(() => _turns += 0.5); widget.onTap(); },
        child: AnimatedRotation(
          turns: _turns, duration: const Duration(milliseconds: 220), curve: kEaseVe,
          child: Container(
            width: 32, height: 32,
            decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.card, border: Border.all(width: 1, color: dark ? VeColors.lineStrongDark : VeColors.lineStrongLight)),
            child: Icon(Icons.swap_vert, size: 16, color: scheme.foreground),
          ),
        ),
      ),
    );
  }
}
