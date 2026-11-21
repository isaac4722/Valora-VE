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

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'package:share_plus/share_plus.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/history_api.dart';
import '../../data/rate_history.dart';
import '../../data/store.dart';
import '../../services/sharing.dart';
import '../../widgets/app_tips.dart';
import '../../widgets/app_tour.dart' show TourKeys;
import '../../widgets/rate_sheet.dart';
import '../../widgets/share_card.dart';
import '../../widgets/export_sheet.dart';
import '../../widgets/ui.dart';
import 'pago_movil_sheet.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorave/providers/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:valorave/core/ve_theme.dart';

part 'converter_reference.dart';
part 'converter_history.dart';

class ConverterScreen extends ConsumerStatefulWidget {
  const ConverterScreen({super.key});

  @override
  ConsumerState<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends ConsumerState<ConverterScreen> {
  /// BIDIRECCIONAL (v19, orden del dueño): los DOS campos se editan.
  final _fromCtrl = TextEditingController(text: '1');
  final _toCtrl = TextEditingController();
  double _fromTyped = 1;
  double _toTyped = 0;
  String _driver = 'from';
  String _lastSyncedPassive = '';

  String _dateMode = 'today'; // today | yesterday | week | custom
  DateTime? _customDate;
  Map<String, double>? _historicRates;
  bool _historicLoading = false;
  final _notesCtrl = TextEditingController();
  Timer? _notesSave;
  AppStore? _storeRef;

  /// v23 (GUI simple · comparativa CalculaYa): teclado propio desplegado
  /// por defecto bajo el dual input; plegable desde la fila de acciones.
  bool _keypad = true;

  /// Tecla del VeKeypad sobre el campo ACTIVO (driver v19: los dos lados
  /// se editan — el teclado escribe donde el usuario estaba escribiendo).
  void _padKey(String k) {
    final isFrom = _driver != 'to';
    final ctrl = isFrom ? _fromCtrl : _toCtrl;
    var t = ctrl.text;
    if (k == '⌫') {
      if (t.isNotEmpty) t = t.substring(0, t.length - 1);
    } else if (k == ',') {
      if (!t.contains(',')) t = t.isEmpty ? '0,' : '$t,';
    } else {
      t += k;
    }
    final v = parseLocaleNum(t) ?? 0;
    setState(() {
      _lastSyncedPassive = '';
      if (isFrom) {
        _fromTyped = v;
        _fromCtrl.text = t;
      } else {
        _toTyped = v;
        _toCtrl.text = t;
      }
    });
  }

  /// Monto directo (fichas 1/5/10/… y tabla de referencia): siempre al
  /// campo DE ORIGEN, como el camino existente de _TablaMontos.
  void _setFromAmount(double v, Currency from) {
    setState(() {
      _fromTyped = v <= 0 ? 0 : v;
      _driver = 'from';
      _lastSyncedPassive = '';
      _fromCtrl.text = v <= 0
          ? ''
          : fmtNum(_fromTyped, decimals: smartDecimals(_fromTyped, from));
    });
  }

  double _amountNowFor(RateContext ctx, Currency from, Currency to) {
    final rate = ctx.plan(from, to)?.rate ?? 0;
    if (_driver == 'to') return rate > 0 && _toTyped > 0 ? _toTyped / rate : 0;
    return _fromTyped;
  }

  @override
  void initState() {
    super.initState();
    final store = ref.read(appStoreProvider);
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
      'yesterday' => DateTime.now().subtract(const Duration(days: 1)),
      'week' => DateTime.now().subtract(const Duration(days: 7)),
      'custom' => _customDate,
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
    final store = ref.read(appStoreProvider);
    final offlineNet = ref.read(ratesPollerProvider).offlineNet;
    final base = store.contextOf(module: RateModule.converter);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final planIds = base.plan(from, to)?.sourceIds ?? const <String>[];
    final ids = <String>{
      'ves-bcv',
      'ves-parallel',
      'eur-ves-oficial',
      'cop-trm',
      'brl-br',
      'mxn-banxico',
      ...planIds,
      base.sel(from),
      base.sel(to),
    };
    final day = SnapshotPoint.dayKey(date);
    
    // MEJORA PERFORMANCE: Separa manuales y paraleliza el resto
    final manualRates = <String, double>{};
    final toFetch = <String>[];
    for (final id in ids) {
      if (id == 'ves-avg') continue;
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
    for (final p in fetched) {
      rates[p.sourceId] = p.rate;
    }

    if (fetched.isNotEmpty) {
      final merged = mergeSeries(fetched, store.snapshots);
      store.snapshots..clear()..addAll(merged);
      store.persistSnapshots();
    }
    final b = rates['ves-bcv'], p = rates['ves-parallel'];
    if (b != null && p != null) rates['ves-avg'] = (b + p) / 2;
    if (mounted) {
      setState(() { _historicRates = rates; _historicLoading = false; });
    }
  }

  RateContext _context(AppStore store) {
    final base = store.contextOf(module: RateModule.converter);
    if (_dateMode == 'today' || _historicRates == null) return base;
    return RateContext(rates: _historicRates!, selected: base.selected);
  }

  void _swapSides(AppStore store, Currency from, Currency to, ConversionPlan? plan, double result) {
    final rate = plan?.rate ?? 0;
    final nuevo = _driver == 'to' ? _toTyped : (rate > 0 && result > 0 ? result : _fromTyped);
    store.setConverterPair(to.code, from.code);
    setState(() {
      _fromTyped = nuevo > 0 ? nuevo : 0;
      _toTyped = 0;
      _driver = 'from';
      _lastSyncedPassive = '';
      _fromCtrl.text = fmtNum(_fromTyped, decimals: smartDecimals(_fromTyped, to));
    });
  }

  bool _hasOverride(AppStore store, Currency c) => store.data.settings.rateSourcesByModule.containsKey(moduleRateKey(RateModule.converter.code, c.code));

  void _pickSource(Currency c, String id) {
    final store = ref.read(appStoreProvider);
    final global = store.sourceFor(c);
    if (id == global) {
      store.setModuleRateSource(RateModule.converter, c, null);
    } else {
      store.setModuleRateSource(RateModule.converter, c, id);
    }
  }

  Future<Set<String>> _diasRemotos(List<String> ids) async {
    if (ref.read(ratesPollerProvider).offlineNet) return const <String>{};
    final probes = <String>{ for (final id in ids) ...(id == 'ves-avg' ? const ['ves-bcv', 'ves-parallel'] : [id]) };
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
    final store = ref.read(appStoreProvider);
    final ctx = store.contextOf(module: RateModule.converter);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final ids = <String>{ if (plan != null) ...plan.sourceIds, ctx.sel(from), if (from != to) ctx.sel(to) };
    final days = <String>{ for (final id in ids) for (final p in snapshotSeries(store.snapshots, id, 180)) p.day };
    if (!mounted) return;
    final label = ids.map((id) => convSourceNames[id] ?? RateSource.of(id)?.label ?? id).join(' + ');
    // v23.3 (pez 2-a P0-1): chrome del kit — el calendario histórico era
    // el último modal crudo de radio 20 de la app.
    final picked = await showVeHalfSheet<DateTime>(
      context: context,
      title: 'Elegir fecha histórica',
      builder: (_) => _CalendarioHistorico(days: days, futureDays: _diasRemotos(ids.toList()), initial: _dateMode == 'custom' ? _customDate : null, sourceLabel: label),
    );
    if (picked == null || !mounted) return;
    setState(() { _customDate = picked; _dateMode = 'custom'; });
    _applyRateContext();
  }

  Future<Uint8List?> _renderCard() async {
    final store = ref.read(appStoreProvider);
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
    final cat = src?.category.label ?? '';
    return renderConversionSharePng(
      context, from: from, to: to, inputAmount: amount, resultAmount: result,
      rateLine: '1 ${from.code} = ${fmtRate(plan.rate)} ${to.code}',
      sourceLabel: cat.isEmpty ? label : '$label · $cat',
      date: _dateMode == 'today' ? DateTime.now() : (_customDate ?? DateTime.now()),
    );
  }

  Future<void> _shareCard() async {
    final store = ref.read(appStoreProvider);
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final amount = _amountNowFor(ctx, from, to);
    if (plan == null || amount <= 0) return;
    final result = amount * plan.rate;
    final text = '${fmtMoney(amount, from)} ${from.code} = ${fmtMoney(result, to)} · 1 ${from.code} = ${fmtRate(plan.rate)} ${to.code} — ValoraVE';
    await showExportSheet(context, ExportSpec(
      title: 'Resultado ${from.code} → ${to.code}',
      subtitle: '${fmtMoney(amount, from)} ${from.code} = ${fmtMoney(result, to)} ${to.code}',
      formats: [
        ExportFormat(icon: Icons.subject_rounded, label: 'Texto', hint: 'Cifra y tasa listas para pegar en un chat', run: (share) async { await SharePlus.instance.share(ShareParams(text: text)); return null; }),
        ExportFormat(icon: Icons.image_outlined, label: 'Imagen PNG', hint: 'Tarjeta de ValoraVE con la conversión', run: (share) async {
          final png = await _renderCard(); if (png == null) return 'No pude generar la tarjeta';
          if (share) { await sharePng(png, 'conversion-valorave.png'); return null; }
          final path = await downloadBytes(png, fileName: 'conversion-valorave.png');
          return path == null ? 'No se pudo guardar la imagen.' : 'Guardado en: $path';
        }),
      ],
    ));
  }

  void _copyResult() {
    final store = ref.read(appStoreProvider);
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
    final cat = src?.category.label ?? '';
    copiarAlPortapapeles(context, '${fmtMoney(amount, from)} ${from.code} = ${fmtMoney(result, to)} ${to.code} · 1 ${from.code} = ${fmtRate(plan.rate)} ${to.code} ($label${cat.isEmpty ? '' : ' · $cat'}) · ValoraVE', 'Resultado copiado');
  }

  void _syncPassiveController(RateContext ctx, Currency from, Currency to, double result, double amount) {
    final passiveTo = _driver == 'from';
    // v23 (numMode · comparativa CalculaYa «Alternar redondeo»): en modo
    // redondeo el RESULTADO se muestra entero; la línea «≈» de abajo y la
    // ruta del cálculo conservan la cifra exacta (honestidad §1.2).
    final round = _storeRef?.data.settings.numMode == 'redondeo';
    final passiveTxt = passiveTo
        ? (result > 0
              ? fmtNum(result, decimals: round ? 0 : smartDecimals(result, to))
              : '')
        : (amount > 0 ? fmtNum(amount, decimals: smartDecimals(amount, from)) : '');
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

  /// v23.2 (patrón calculadora): las secciones secundarias viven en
  /// half-sheets — la pantalla queda a la vista sin subir/bajar.
  Future<void> _showSeccion(String titulo, WidgetBuilder builder) async {
    await showVeHalfSheet<void>(context: context, title: titulo, builder: builder);
  }

  @override
  Widget build(BuildContext context) {
    final fromCode = ref.watch(appStoreProvider.select((s) => s.data.converter.from));
    final toCode = ref.watch(appStoreProvider.select((s) => s.data.converter.to));
    final numMode = ref.watch(appStoreProvider.select((s) => s.settings.numMode));
    final from = CurrencyX.from(fromCode);
    final to = CurrencyX.from(toCode);

    final store = ref.watch(appStoreProvider);
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
    final frescura = src?.category == SourceCategory.manual ? 'tu tasa manual' : (when != null ? timeAgo(when) : 'sin fecha aún');
    final srcLabel = convSourceNames[primaryId] ?? src?.label ?? primaryId;
    final subTitulo = (plan != null && plan.rate > 0) ? '$srcLabel · 1 ${from.code} = ${fmtRate(plan.rate)} ${to.code}' : 'Sin tasa disponible para este par';
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: VeEntry(
        // v23.2 — patrón calculadora: el teclado es PISO FIJO abajo y la
        // cifra queda siempre a la vista; el bloque superior solo hace
        // scroll si un modo histórico lo estrena (en «Hoy» no hay scroll).
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const TipsTrigger(scope: 'conversor'),
                    VeTitle(sub: Text(subTitulo), child: const Text('Conversor')),
                    KeyedSubtree(
                      key: TourKeys.convFecha,
                      child: _FechaTasas(
                        mode: _dateMode, customDate: _customDate, loading: _historicLoading,
                        sinDatos: _historicRates != null && !_historicLoading && (plan == null || plan.rate <= 0),
                        onMode: (m) { setState(() => _dateMode = m); _applyRateContext(); },
                        onOpenCalendar: _openHistoricCalendar,
                      ),
                    ),
                    const SizedBox(height: 12),
                    KeyedSubtree(
                      key: TourKeys.convFuente,
                      child: RepaintBoundary(
                        child: _DualInput(
                          fromCtrl: _fromCtrl, toCtrl: _toCtrl, from: from, to: to, result: result, plan: plan, ctx: ctx,
                          activeSourceId: primaryId, frescura: frescura, hasOverride: _hasOverride(store, from),
                          onFromInput: (v) => setState(() { _fromTyped = v; _driver = 'from'; _lastSyncedPassive = ''; }),
                          onToInput: (v) => setState(() { _toTyped = v; _driver = 'to'; _lastSyncedPassive = ''; }),
                          onAdjust: (v) => setState(() {
                            _fromTyped = v <= 0 ? 0 : v; _driver = 'from'; _lastSyncedPassive = '';
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
                      // v23.2: acciones al mínimo — iconos con etiqueta para
                      // el lector (Semantics) y texto solo donde la palabra
                      // es la marca del flujo («Pago Móvil»).
                      child: Row(children: [
                        Semantics(
                          label: 'Compartir resultado',
                          child: VeBtn(
                            size: VeBtnSize.lg,
                            variant: VeBtnVariant.secondary,
                            enabled: plan != null && result > 0,
                            onPressed: _shareCard,
                            child: const Icon(LucideIcons.share2, size: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Semantics(
                          label: 'Copiar resultado',
                          child: VeBtn(
                            size: VeBtnSize.lg,
                            variant: VeBtnVariant.secondary,
                            enabled: plan != null && result > 0,
                            onPressed: _copyResult,
                            child: const Icon(LucideIcons.copy, size: 16),
                          ),
                        ),
                        const SizedBox(width: 8),
                        if (to == Currency.ves)
                          Expanded(
                            child: VeBtn(
                              size: VeBtnSize.lg,
                              variant: VeBtnVariant.secondary,
                              icon: LucideIcons.smartphone,
                              enabled: result > 0,
                              onPressed: () => showPagoMovilSheet(
                                context,
                                ref: ref,
                                montoBs: result,
                              ),
                              child: const Text('Pago Móvil'),
                            ),
                          )
                        else
                          const Spacer(),
                        Semantics(
                          label: _keypad ? 'Ocultar teclado' : 'Mostrar teclado',
                          child: VeBtn(
                            size: VeBtnSize.lg,
                            variant: VeBtnVariant.secondary,
                            onPressed: () => setState(() => _keypad = !_keypad),
                            child: Icon(_keypad ? LucideIcons.chevronDown : LucideIcons.calculator, size: 16),
                          ),
                        ),
                      ]),
                    ),
                    // v23.2: secciones secundarias como fichas — abren
                    // half-sheets y NO compiten por el alto de la pantalla.
                    // 4 slots iguales: SIEMPRE una sola línea.
                    Padding(
                      padding: const EdgeInsets.only(top: 8),
                      child: Row(children: [
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: VeChip(
                              dense: true,
                              onTap: () => _showSeccion('Referencia de fuentes', (c) => _ReferenciaFuentes(ctx: ctx, from: from, to: to, onPick: _pickSource)),
                              child: FittedBox(fit: BoxFit.scaleDown, child: const Text('Fuentes')),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: VeChip(
                              dense: true,
                              onTap: () => _showSeccion('Tabla de montos', (c) => _TablaMontos(
                                ctx: ctx, amount: amount, from: from,
                                onAmount: (v) { setState(() { _fromTyped = v <= 0 ? 0 : v; _driver = 'from'; _lastSyncedPassive = ''; _fromCtrl.text = fmtNum(_fromTyped, decimals: smartDecimals(_fromTyped, from)); }); Navigator.pop(c); },
                              )),
                              child: FittedBox(fit: BoxFit.scaleDown, child: const Text('Tabla')),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: VeChip(
                              dense: true,
                              onTap: () => _showSeccion('Recientes', (c) => _Recientes(from: from, to: to, amount: amount, result: result, plan: plan,
                                onRestore: (r) {
                                  final rf = CurrencyX.from(r.from);
                                  if (from != rf || to != CurrencyX.from(r.to)) store.setConverterPair(r.from, r.to);
                                  setState(() { _fromTyped = r.amount; _driver = 'from'; _lastSyncedPassive = ''; _fromCtrl.text = fmtNum(r.amount, decimals: smartDecimals(r.amount, rf)); });
                                  Navigator.pop(c);
                                },
                              )),
                              child: FittedBox(fit: BoxFit.scaleDown, child: const Text('Recientes')),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 2),
                            child: VeChip(
                              dense: true,
                              onTap: () => _showSeccion('Notas', (c) => _Notas(ctrl: _notesCtrl)),
                              child: FittedBox(fit: BoxFit.scaleDown, child: const Text('Notas')),
                            ),
                          ),
                        ),
                      ]),
                    ),
                  ],
                ),
              ),
            ),
            // v23 (GUI simple · comparativa CalculaYa): teclado propio +
            // fichas de montos + modo de vista del resultado como PISO
            // FIJO — el «modo calculadora» del dueño.
            AnimatedSize(
              duration: kLayoutDur,
              curve: kEaseVe,
              alignment: Alignment.bottomCenter,
              child: _keypad
                  ? Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                      child: RepaintBoundary(
                        child: VeCard(
                          padding: const EdgeInsets.fromLTRB(10, 10, 10, 10),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Fichas en UNA línea: 6 expandidas + «Limpiar»
                              // natural al final — cada slot sobra aire.
                              Row(children: [
                                for (final v in const [1, 5, 10, 20, 50, 100])
                                  Expanded(
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(horizontal: 2),
                                      child: VeChip(
                                        expands: true,
                                        dense: true,
                                        onTap: () => _setFromAmount(v.toDouble(), from),
                                        child: Text('$v'),
                                      ),
                                    ),
                                  ),
                                VeChip(
                                  dense: true,
                                  onTap: () => _setFromAmount(0, from),
                                  child: const Text('Limpiar'),
                                ),
                              ]),
                              const SizedBox(height: 8),
                              VeKeypad(onKey: _padKey),
                              const SizedBox(height: 8),
                              VeSegmented<String>(
                                value: numMode,
                                onChanged: store.setNumMode,
                                segments: const [
                                  VeSegment(value: 'decimales', label: 'Decimales'),
                                  VeSegment(value: 'redondeo', label: 'Redondear'),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : const SizedBox(width: double.infinity),
            ),
          ],
        ),
      ),
    );
  }
}

class _FechaTasas extends ConsumerWidget {
  const _FechaTasas({required this.mode, required this.customDate, required this.loading, required this.sinDatos, required this.onMode, required this.onOpenCalendar});
  final String mode; final DateTime? customDate; final bool loading; final bool sinDatos;
  final ValueChanged<String> onMode; final VoidCallback onOpenCalendar;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ink = Theme.of(context).extension<VeInk>()!;
    final String periodo = switch (mode) {
      'yesterday' => 'de ayer', 'week' => 'de hace 7 días',
      _ => customDate == null ? 'del día elegido' : 'del ${fmtDate(customDate!)}',
    };
    // v23.2: sin tarjeta envolvente — la fila de fechas respira directa en
    // la página (cada dp cuenta en el patrón calculadora).
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(spacing: 6, runSpacing: 6, children: [
        VeChip(active: mode == 'today', onTap: () => onMode('today'), child: const Text('Hoy')),
        VeChip(active: mode == 'yesterday', onTap: () => onMode('yesterday'), child: const Text('Ayer')),
        VeChip(active: mode == 'week', onTap: () => onMode('week'), child: const Text('Hace 7 días')),
        VeChip(active: mode == 'custom', icon: LucideIcons.calendarDays, onTap: onOpenCalendar, child: const Text('Fecha')),
      ]),
        if (mode != 'today') ...[
          const SizedBox(height: 8),
          if (loading)
            const Row(children: [SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2)), SizedBox(width: 8), Text('Buscando tasa…', style: TextStyle(fontSize: 12))])
          else
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(color: ink.warnBg, borderRadius: BorderRadius.circular(10), border: Border.all(color: ink.warn.withValues(alpha: 0.35))),
              child: Row(children: [
                Icon(Icons.history, size: 15, color: ink.warn), const SizedBox(width: 8),
                Expanded(child: Text(sinDatos ? 'Sin datos ese día — elige otro en el calendario' : 'Tasa $periodo', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600, color: ink.warn), maxLines: 2, overflow: TextOverflow.ellipsis)),
                VeBtn(variant: VeBtnVariant.ghost, size: VeBtnSize.sm, onPressed: () => onMode('today'), child: const Text('Hoy')),
              ]),
            ),
        ],
        ],
    );
  }
}

class _DualInput extends ConsumerWidget {
  const _DualInput({required this.fromCtrl, required this.toCtrl, required this.from, required this.to, required this.result, required this.plan, required this.ctx, required this.activeSourceId, required this.frescura, required this.hasOverride, required this.onFromInput, required this.onToInput, required this.onAdjust, required this.onSwap, required this.onFrom, required this.onTo, required this.onPickSource, required this.onClearOverride});
  final TextEditingController fromCtrl, toCtrl;
  final Currency from, to; final double result; final ConversionPlan? plan;
  final RateContext ctx; final String activeSourceId, frescura; final bool hasOverride;
  final ValueChanged<double> onFromInput, onToInput, onAdjust;
  final VoidCallback onSwap; final ValueChanged<Currency> onFrom, onTo;
  final void Function(Currency c, String id) onPickSource; final VoidCallback onClearOverride;

  Widget _fuenteLine(BuildContext ctx2, WidgetRef ref, ColorScheme scheme) {
    final src = RateSource.of(activeSourceId);
    final label = convSourceNames[activeSourceId] ?? src?.label ?? activeSourceId;
    return Row(children: [
      Expanded(child: InkWell(
        onTap: () => _openSourcesSheet(ctx2, ref), borderRadius: BorderRadius.circular(10),
        child: Padding(padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4), child: Row(children: [
          if (src != null) ...[SourceSeal(src.category), const SizedBox(width: 8)],
          Expanded(child: Text.rich(TextSpan(text: label, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: scheme.onSurface), children: [TextSpan(text: ' · $frescura', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w500, color: scheme.onSurfaceVariant))]), maxLines: 1, overflow: TextOverflow.ellipsis)),
          const SizedBox(width: 4), Icon(LucideIcons.chevronDown, size: 16, color: scheme.onSurfaceVariant),
        ])),
      )),
      if (hasOverride) VeBtn(variant: VeBtnVariant.ghost, size: VeBtnSize.sm, onPressed: onClearOverride, child: const Text('Seguir global')),
    ]);
  }
  Future<void> _openSourcesSheet(BuildContext context, WidgetRef ref) async {
    await showRateSheet(context, ref: ref, currency: from, ctx: ctx, currentId: activeSourceId, onPick: (id) => onPickSource(from, id));
  }
  double _fromValueOf(double result, ConversionPlan? plan) {
    final rate = plan?.rate ?? 0;
    return rate <= 0 ? 0 : (result > 0 ? result / rate : 0);
  }
  Widget _montoRow(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Text(from.symbol, style: VeText.displayNum(24, color: scheme.onSurfaceVariant, weight: FontWeight.w600)),
      const SizedBox(width: 8),
      Expanded(child: MoneyField(controller: fromCtrl, onChanged: onFromInput, maxDecimals: 6, style: VeText.displayNum(34, color: scheme.onSurface, weight: FontWeight.w600), decoration: const InputDecoration(hintText: 'Monto', border: InputBorder.none, isCollapsed: true, contentPadding: EdgeInsets.symmetric(vertical: 6)))),
      const SizedBox(width: 8), CurrencySelect(value: from, onChanged: onFrom),
    ]);
  }
  Widget _resultadoRow(ColorScheme scheme) {
    final ok = plan != null && result > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(child: MoneyField(controller: toCtrl, onChanged: onToInput, maxDecimals: 6, style: VeText.displayNum(40, color: ok ? scheme.onSurface : scheme.onSurfaceVariant), decoration: InputDecoration(hintText: 'Resultado', border: InputBorder.none, isCollapsed: true, contentPadding: const EdgeInsets.symmetric(vertical: 6), hintStyle: VeText.displayNum(40, color: scheme.onSurfaceVariant)))),
        const SizedBox(width: 8), CurrencySelect(value: to, onChanged: onTo),
      ]),
      Padding(padding: const EdgeInsets.only(left: 4, top: 2), child: Text(ok ? '≈ ${fmtMoney(result, to)}' : 'sin tasa para este par', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(fontSize: ok ? 12 : 10.5, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant))),
    ]);
  }
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return VeCard(
      padding: const EdgeInsets.all(12),
      child: Column(children: [
        _fuenteLine(context, ref, scheme), const Divider(height: 12), _montoRow(context),
        Padding(
          // v23.3 (pez 2-a P1-1): fila del swap a 44 — el botón insignia de
          // la pantalla tenía 32×32 de pista.
          padding: EdgeInsets.zero,
          child: SizedBox(
            height: 44,
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Positioned.fill(
                  child: Center(child: Divider(height: 1)),
                ),
                _SwapBtn(onTap: onSwap),
              ],
            ),
          ),
        ),
        _resultadoRow(scheme),
        Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Row(
            children: [
              for (final adj in quickAdjustments)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    // FittedBox: el sello ±10 %/±100 nunca rebosa en
                    // pantallas angostas (cifras blindadas §9.2).
                    child: VeChip(
                      expands: true,
                      onTap: () => onAdjust(adj.apply(_fromValueOf(result, plan))),
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(adj.label),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ]),
    );
  }
}

class _SwapBtn extends ConsumerStatefulWidget {
  const _SwapBtn({required this.onTap});
  final VoidCallback onTap;
  @override
  ConsumerState<_SwapBtn> createState() => _SwapBtnState();
}
class _SwapBtnState extends ConsumerState<_SwapBtn> {
  double _turns = 0;
  @override
  Widget build(BuildContext context) {
    final shad = context.ve;
    final scheme = shad.colorScheme;
    final bool dark = shad.brightness == Brightness.dark;
    return Semantics(
      button: true, label: 'Invertir par',
      child: TapScale(
        onTap: () { setState(() => _turns += 0.5); widget.onTap(); },
        child: AnimatedRotation(
          turns: _turns, duration: const Duration(milliseconds: 220), curve: kEaseVe,
          child: Container(
            // v23.3 (pez 2-a P1-1): visual 32, pista 44×44 — el dedo
            // tiene margen sin engordar el círculo.
            width: 44, height: 44,
            alignment: Alignment.center,
            child: Container(
              width: 32, height: 32,
              decoration: BoxDecoration(shape: BoxShape.circle, color: scheme.card, border: Border.all(width: 1, color: dark ? VeColors.lineStrongDark : VeColors.lineStrongLight)),
              child: Icon(Icons.swap_vert, size: 16, color: scheme.foreground),
            ),
          ),
        ),
      ),
    );
  }
}
