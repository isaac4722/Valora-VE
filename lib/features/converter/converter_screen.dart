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
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/history_api.dart';
import '../../data/rate_history.dart';
import '../../data/store.dart';
import '../../state/app_state.dart' show RatesPoller;
import '../../services/sharing.dart';
import '../../widgets/app_tips.dart';
import '../../widgets/app_tour.dart' show TourKeys;
import '../../widgets/rate_sheet.dart';
import '../../widgets/share_card.dart';
import '../../widgets/share_menu.dart';
import '../../widgets/ui.dart';

part 'converter_reference.dart';
part 'converter_history.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  /// BIDIRECCIONAL (v19, orden del dueño): los DOS campos se editan.
  /// [_driver] recuerda el último lado tecleado; el pasivo se sincroniza
  /// en cada build (también cuando la tasa cambia sola). [_fromTyped] y
  /// [_toTyped] guardan lo escrito en cada lado — el monto efectivo SIEMPRE
  /// se deriva del conductor con la tasa viva (nada se redondea a lo bruto).
  final _fromCtrl = TextEditingController(text: '1');
  final _toCtrl = TextEditingController();
  double _fromTyped = 1;
  double _toTyped = 0;
  String _driver = 'from';

  /// Monto efectivo en la divisa FROM (fuente de verdad de la conversión).
  double get _amountNow {
    final store = context.read<AppStore>();
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final rate = ctx.plan(from, to)?.rate ?? 0;
    if (_driver == 'to') return rate > 0 && _toTyped > 0 ? _toTyped / rate : 0;
    return _fromTyped;
  }
  String _dateMode = 'today'; // today | yesterday | week | custom
  DateTime? _customDate;
  Map<String, double>? _historicRates; // tasas históricas (sourceId → rate)
  bool _historicLoading = false;
  final _notesCtrl = TextEditingController();
  Timer? _notesSave; // debounce 600 ms de las notas
  AppStore? _storeRef; // para el flush en dispose (sin context)

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _storeRef = store;
    _notesCtrl.text = store.readConversionNotes();
    _notesCtrl.addListener(_onNotesChanged);
  }

  /// Debounce de notas: reprograma el guardado a 600 ms de la última tecla.
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
    // Flush del debounce: si quedó texto sin guardar, se persiste al salir.
    if (pending) _storeRef?.writeConversionNotes(_notesCtrl.text);
    _fromCtrl.dispose();
    _toCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  /// Fecha objetivo del modo elegido: los 3 presets (Ayer · Hace 7 días ·
  /// calendario) van por el MISMO camino de carga histórica real.
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

  /// Carga histórica real (serie remota + respaldo de snapshots locales).
  /// Cubre las fuentes canónicas + las que exige el plan ACTIVO del par
  /// (puente/arista EUR incluida). Las manuales se conservan (constante del
  /// usuario, no dato fechado) y `ves-avg` se deriva igual que el store.
  /// Sin dato → mapa sin la tasa → mensaje honesto; nunca fabrica tasas.
  Future<void> _loadHistoric(DateTime date) async {
    final store = context.read<AppStore>();
    // v19: sin red NO se sondea la API (9 s de espera fingida): el libro
    // local responde primero (preferLocal) y la tasa manual sigue contando
    // como personalizada, no como «sin conexión».
    final offlineNet = context.read<RatesPoller>().offlineNet;
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
    final rates = <String, double>{};
    // v19 (orden del dueño): TODO lo consultado queda guardado localmente —
    // los puntos históricos que llegan de la API se fusionan al libro de
    // snapshots (día gana remoto) y se persisten en el teléfono.
    final fetched = <SnapshotPoint>[];
    for (final id in ids) {
      final def = RateSource.of(id);
      if (def?.category == SourceCategory.manual) {
        // La tasa manual no tiene historia: es la constante del usuario.
        final v = base.rate(id);
        if (v > 0) rates[id] = v;
        continue;
      }
      if (id == 'ves-avg') continue; // se deriva abajo (§3.1)
      try {
        final point = await rateOn(id, day, preferLocal: offlineNet, localFallback: (sourceId, d) {
          final local = store.snapshots.where((p) => p.sourceId == sourceId && p.day == d).toList()
            ..sort((a, b) => a.day.compareTo(b.day));
          return local.isEmpty ? null : HistPoint(date: local.last.day, rate: local.last.rate);
        });
        if (point != null) {
          rates[id] = point.rate;
          final pointDay = point.date.length == 10 ? point.date : day;
          fetched.add(SnapshotPoint(
              sourceId: id, day: pointDay, rate: point.rate));
        }
      } catch (_) {/* honesto: sin dato */}
    }
    if (fetched.isNotEmpty) {
      // Fusión ANTES de mutar la lista (remoto gana por día; local se
      // conserva) — y luego reemplazo atómico.
      final merged = mergeSeries(fetched, store.snapshots);
      store.snapshots
        ..clear()
        ..addAll(merged);
      store.persistSnapshots();
    }
    final b = rates['ves-bcv'], p = rates['ves-parallel'];
    if (b != null && p != null) rates['ves-avg'] = (b + p) / 2;
    if (mounted) {
      setState(() {
        _historicRates = rates;
        _historicLoading = false;
      });
    }
  }

  /// Contexto efectivo: vivo (hoy) o histórico (fecha seleccionada).
  RateContext _context(AppStore store) {
    final base = store.contextOf(module: RateModule.converter);
    if (_dateMode == 'today' || _historicRates == null) return base;
    return RateContext(
      rates: _historicRates!,
      selected: base.selected,
    );
  }

  /// Intercambia los lados del par (botón swap o al elegir la divisa del
  /// otro lado). El NÚMERO se conserva: si el conductor era el resultado,
  /// ese valor pasa a ser el monto del nuevo par (comportamiento XE).
  void _swapSides(
      AppStore store, Currency from, Currency to, ConversionPlan? plan, double result) {
    final rate = plan?.rate ?? 0;
    final nuevo = _driver == 'to'
        ? _toTyped
        : (rate > 0 && result > 0 ? result : _fromTyped);
    store.setConverterPair(to.code, from.code);
    setState(() {
      _fromTyped = nuevo > 0 ? nuevo : 0;
      _toTyped = 0;
      _driver = 'from';
      // La nueva divisa FROM es la antigua `to`.
      _fromCtrl.text =
          fmtNum(_fromTyped, decimals: smartDecimals(_fromTyped, to));
    });
  }

  /// ¿Hay override de fuente propio del conversor para esta divisa?
  bool _hasOverride(AppStore store, Currency c) =>
      store.data.settings.rateSourcesByModule
          .containsKey(moduleRateKey(RateModule.converter.code, c.code));

  /// Selector de fuente (chips y tabla de referencia). Si el id coincide con
  /// la fuente global se limpia el override (el conversor vuelve a seguir la
  /// global); si no, se fija override SOLO para este módulo — el default del
  /// sistema es la oficial y aquí nunca se fuerza el paralelo.
  void _pickSource(Currency c, String id) {
    final store = context.read<AppStore>();
    final global = store.sourceFor(c);
    if (id == global) {
      store.setModuleRateSource(RateModule.converter, c, null);
    } else {
      store.setModuleRateSource(RateModule.converter, c, id);
    }
  }

  /// FIX date-picker (v17.6): los días del calendario ya no salen SOLO de los
  /// snapshots locales (un teléfono nuevo veía 1-2 días = «no aparece nada»).
  /// La hoja abre al instante con lo local y fusiona la serie REMOTA de las
  /// fuentes del par (180 días por fuente, seriesForSource). Offline (v19) →
  /// ni se intenta: los locales cubren SIN espera ni spinner falso.
  Future<Set<String>> _diasRemotos(List<String> ids) async {
    if (context.read<RatesPoller>().offlineNet) return const <String>{};
    final probes = <String>{
      for (final id in ids)
        ...(id == 'ves-avg' ? const ['ves-bcv', 'ves-parallel'] : [id]),
    };
    final out = <String>{};
    for (final id in probes) {
      final def = RateSource.of(id);
      if (def == null || def.category == SourceCategory.manual) continue;
      try {
        final res = await seriesForSource(id, 180);
        out.addAll(res.points.map((p) => p.date));
      } catch (_) {/* sin red: cubren los locales */}
    }
    return out;
  }

  /// Calendario histórico (REQ 4): días con snapshot guardado de las fuentes
  /// del par (primarias del plan + seleccionadas). Solo esos días son
  /// seleccionables; al elegir se carga la tasa de ese día.
  Future<void> _openHistoricCalendar() async {
    final store = context.read<AppStore>();
    final ctx = store.contextOf(module: RateModule.converter);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final ids = <String>{
      if (plan != null) ...plan.sourceIds,
      ctx.sel(from),
      if (from != to) ctx.sel(to),
    };
    final days = <String>{
      for (final id in ids)
        for (final p in snapshotSeries(store.snapshots, id, 180)) p.day,
    };
    if (!mounted) return;
    final label = ids
        .map((id) => convSourceNames[id] ?? RateSource.of(id)?.label ?? id)
        .join(' + ');
    final picked = await showModalBottomSheet<DateTime>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      // Hoja blindada (v17.6): esquinas propias y fondo opaco del tema —
      // nunca una hoja transparente/rectangular que parezca «no aparece».
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _CalendarioHistorico(
        days: days,
        futureDays: _diasRemotos(ids.toList()),
        initial: _dateMode == 'custom' ? _customDate : null,
        sourceLabel: label,
      ),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _customDate = picked;
      _dateMode = 'custom';
    });
    _applyRateContext();
  }

  /// Comparte la conversión con la TARJETA DE MARCA (1080×1080) compuesta
  /// offstage — solo memoria, sin archivo intermedio (regla del dueño).
  /// Bytes de la tarjeta de marca (sin compartir aún).
  Future<Uint8List?> _renderCard() async {
    final store = context.read<AppStore>();
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final amount = _amountNow;
    if (plan == null || amount <= 0) return null;
    final result = amount * plan.rate;
    final primaryId =
        plan.sourceIds.isNotEmpty ? plan.sourceIds.first : ctx.sel(from);
    final src = RateSource.of(primaryId);
    final label = convSourceNames[primaryId] ?? src?.label ?? primaryId;
    final cat = src?.category.label ?? '';
    return renderConversionSharePng(
      context,
      from: from,
      to: to,
      inputAmount: amount,
      resultAmount: result,
      rateLine: '1 ${from.code} = ${fmtRate(plan.rate)} ${to.code}',
      sourceLabel: cat.isEmpty ? label : '$label · $cat',
      // Fecha de la tasa mostrada (hoy o la histórica elegida).
      date: _dateMode == 'today' ? DateTime.now() : (_customDate ?? DateTime.now()),
    );
  }

  /// Compartir SIEMPRE vía menú propio (v17.2): texto · imagen · guardar.
  /// Nunca el share nativo directo con un PNG.
  Future<void> _shareCard() async {
    final store = context.read<AppStore>();
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final amount = _amountNow;
    if (plan == null || amount <= 0) return;
    final result = amount * plan.rate;
    final text =
        '${fmtMoney(amount, from)} ${from.code} = ${fmtMoney(result, to)} · '
        '1 ${from.code} = ${fmtRate(plan.rate)} ${to.code} — ValoraVE';
    await showShareMenu(context, title: 'Resultado ${from.code} → ${to.code}', actions: [
      ShareMenuAction(
        icon: Icons.subject_rounded,
        label: 'Texto',
        hint: 'Cifra y tasa listas para pegar en un chat',
        onRun: () async {
          await SharePlus.instance.share(ShareParams(text: text));
          return null;
        },
      ),
      ShareMenuAction(
        icon: Icons.image_outlined,
        label: 'Compartir imagen',
        hint: 'Tarjeta de ValoraVE con la conversión',
        onRun: () async {
          final png = await _renderCard();
          if (png == null) return 'No pude generar la tarjeta';
          await sharePng(png, 'conversion-valorave.png');
          return null;
        },
      ),
      ShareMenuAction(
        icon: Icons.download_rounded,
        label: 'Descargar imagen',
        hint: 'Guarda la tarjeta sin abrir el share',
        onRun: () async {
          final png = await _renderCard();
          if (png == null) return 'No pude generar la tarjeta';
          return runDownloadBytes(png, 'conversion-valorave.png');
        },
      ),
    ]);
  }

  /// Texto del resultado al portapapeles (acompaña a la tarjeta).
  void _copyResult() {
    final store = context.read<AppStore>();
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final amount = _amountNow;
    if (plan == null || amount <= 0) return;
    final result = amount * plan.rate;
    final primaryId =
        plan.sourceIds.isNotEmpty ? plan.sourceIds.first : ctx.sel(from);
    final src = RateSource.of(primaryId);
    final label = convSourceNames[primaryId] ?? src?.label ?? primaryId;
    final cat = src?.category.label ?? '';
    copiarAlPortapapeles(
      context,
      '${fmtMoney(amount, from)} ${from.code} = '
          '${fmtMoney(result, to)} ${to.code} · '
          '1 ${from.code} = ${fmtRate(plan.rate)} ${to.code} '
          '($label${cat.isEmpty ? '' : ' · $cat'}) · ValoraVE',
      'Resultado copiado',
    );
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final amount = _amountNow;

    double result = 0;
    if (plan != null && amount > 0) result = amount * plan.rate;

    // Campo PASIVO sincronizado con el estado vivo (la tasa puede cambiar
    // sola): el conductor conserva exactamente lo que el usuario tecleó.
    final passiveTo = _driver == 'from';
    final passiveTxt = passiveTo
        ? (result > 0 ? fmtNum(result, decimals: smartDecimals(result, to)) : '')
        : (amount > 0 ? fmtNum(amount, decimals: smartDecimals(amount, from)) : '');
    if ((passiveTo ? _toCtrl : _fromCtrl).text != passiveTxt) {
      (passiveTo ? _toCtrl : _fromCtrl).text = passiveTxt;
    }

    // Fuente activa del par + su frescura (v18.0: vive en la línea superior
    // del conversor, estilo XE/Wise).
    final primaryId =
        (plan != null && plan.sourceIds.isNotEmpty) ? plan.sourceIds.first : ctx.sel(from);
    final src = RateSource.of(primaryId);
    final entry = store.board.sources[primaryId];
    final when = entry?.updatedAt ?? store.board.fetchedAt;
    final frescura = src?.category == SourceCategory.manual
        ? 'tu tasa manual'
        : (when != null ? timeAgo(when) : 'sin fecha aún');

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const TipsTrigger(scope: 'conversor'),
          const PageHeader('Conversor', hint: 'Puente USD · EUR visible · ruta honesta'),
          // Fecha de la tasa activa + selector histórico (calendario real).
          KeyedSubtree(
            key: TourKeys.convFecha,
            child: _FechaTasas(
            mode: _dateMode,
            customDate: _customDate,
            loading: _historicLoading,
            sinDatos: _historicRates != null &&
                !_historicLoading &&
                (plan == null || plan.rate <= 0),
            onMode: (m) {
              setState(() => _dateMode = m);
              _applyRateContext();
            },
            onOpenCalendar: _openHistoricCalendar,
          ),
          ),
          const SizedBox(height: 14),
          // Ancla del tour (v17.8): el card del par con su fuente de tasa.
          KeyedSubtree(
            key: TourKeys.convFuente,
            child: _DualInput(
            fromCtrl: _fromCtrl,
            toCtrl: _toCtrl,
            from: from,
            to: to,
            result: result,
            plan: plan,
            ctx: ctx,
            activeSourceId: primaryId,
            frescura: frescura,
            hasOverride: _hasOverride(store, from),
            onFromInput: (v) => setState(() {
              _fromTyped = v;
              _driver = 'from';
            }),
            onToInput: (v) => setState(() {
              _toTyped = v;
              _driver = 'to';
            }),
            onAdjust: (v) {
              // Los ajustes rápidos mueven el lado FROM (es el «monto»).
              setState(() {
                _fromTyped = v <= 0 ? 0 : v;
                _driver = 'from';
                _fromCtrl.text = fmtNum(_fromTyped,
                    decimals: smartDecimals(_fromTyped, from));
              });
            },
            // Swap XE: elegir la divisa del otro lado INTERCAMBIA lados; el
            // número escrito se queda (el resultado pasa a ser el monto).
            onSwap: () => _swapSides(store, from, to, plan, result),
            onFrom: (c) => c == to
                ? _swapSides(store, from, to, plan, result)
                : store.setConverterPair(c.code, to.code),
            onTo: (c) => c == from
                ? _swapSides(store, from, to, plan, result)
                : store.setConverterPair(from.code, c.code),
            onPickSource: _pickSource,
            onClearOverride: () =>
                store.setModuleRateSource(RateModule.converter, from, null),
          ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              FilledButton.tonalIcon(
                onPressed: plan == null || result <= 0 ? null : _shareCard,
                icon: const Icon(Icons.ios_share, size: 16),
                label: const Text('Compartir'),
              ),
              const SizedBox(width: 8),
              OutlinedButton.icon(
                onPressed: plan == null || result <= 0 ? null : _copyResult,
                icon: const Icon(Icons.copy_all, size: 16),
                label: const Text('Copiar'),
              ),
            ]),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 6),
            child: Text('Tarjeta de marca 1080 px · se comparte desde memoria.',
                style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
          ),
          _RutaCalculo(plan: plan),
          // REQ 5: fuentes disponibles por divisa implicada en el par.
          _ReferenciaFuentes(ctx: ctx, from: from, to: to, onPick: _pickSource),
          _TablaMontos(ctx: ctx, amount: amount, from: from),
          // dp6 · mejora 9: matriz completa de pares a un vistazo (plegada).
          _Matriz6(ctx: ctx),
          _Recientes(from: from, to: to, amount: amount, result: result, plan: plan),
          _Notas(ctrl: _notesCtrl),
        ],
      ),
    );
  }
}

/// Fila de fecha de las tasas (entre el encabezado y el conversor): presets
/// de fecha + calendario histórico + banner «tasa del `fecha`».
/// v18.0: la FUENTE y su frescura viven en la línea superior del conversor
/// (estilo XE/Wise) — esta tarjeta ya no las duplica.
class _FechaTasas extends StatelessWidget {
  const _FechaTasas({
    required this.mode,
    required this.customDate,
    required this.loading,
    required this.sinDatos,
    required this.onMode,
    required this.onOpenCalendar,
  });

  final String mode;
  final DateTime? customDate;
  final bool loading;
  final bool sinDatos;
  final ValueChanged<String> onMode;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final sem = VeColors.of(context);
    final String periodo = switch (mode) {
      'yesterday' => 'de ayer',
      'week' => 'de hace 7 días',
      _ => customDate == null ? 'del día elegido' : 'del ${fmtDate(customDate!)}',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Fila 1: presets de fecha (todos cargan histórico real) + calendario.
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChipTag('Hoy', selected: mode == 'today', onTap: () => onMode('today')),
            ChipTag('Ayer', selected: mode == 'yesterday', onTap: () => onMode('yesterday')),
            ChipTag('Hace 7 días', selected: mode == 'week', onTap: () => onMode('week')),
            ChipTag('Elegir fecha', selected: mode == 'custom', onTap: onOpenCalendar),
          ]),
          // Banner histórico honesto (REQ 4/8).
          if (mode != 'today') ...[
            const SizedBox(height: 10),
            if (loading)
              const Row(children: [
                SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                SizedBox(width: 8),
                Text('Buscando la tasa del día…',
                    style: TextStyle(fontSize: 12)),
              ])
            else
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                  color: sem.warn.withValues(alpha: 0.09),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: sem.warn.withValues(alpha: 0.35)),
                ),
                child: Row(children: [
                  Icon(Icons.history, size: 15, color: sem.warn),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      sinDatos
                          ? 'Sin datos para esa fecha. Elige un día del calendario.'
                          : 'Mostrando la tasa $periodo',
                      style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                          color: sem.warn),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  TextButton(
                    onPressed: () => onMode('today'),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text('Volver a hoy', style: TextStyle(fontSize: 12)),
                  ),
                ]),
              ),
          ],
        ]),
      ),
    );
  }
}

/// Entrada/salida dual del par, layout XE/Wise — BIDIRECCIONAL (v19, orden
/// del dueño): los DOS campos se editan con formato de miles en vivo
/// (MoneyField); escribir ABAJO calcula hacia arriba (monto = valor / tasa).
/// · Fuente + frescura ARRIBA como una línea tocable (hoja de fuentes).
/// · Monto arriba (30 px, secundario) · resultado HÉROE abajo (46 px).
/// · Selector de divisa a la derecha de cada campo; elegir la divisa del
///   OTRO lado intercambia los lados (jamás «VES → VES»).
/// · Ajustes rápidos: fila de 4 chips al mismo ancho (±10 % · ±100).
class _DualInput extends StatelessWidget {
  const _DualInput({
    required this.fromCtrl,
    required this.toCtrl,
    required this.from,
    required this.to,
    required this.result,
    required this.plan,
    required this.ctx,
    required this.activeSourceId,
    required this.frescura,
    required this.hasOverride,
    required this.onFromInput,
    required this.onToInput,
    required this.onAdjust,
    required this.onSwap,
    required this.onFrom,
    required this.onTo,
    required this.onPickSource,
    required this.onClearOverride,
  });

  final TextEditingController fromCtrl;
  final TextEditingController toCtrl;
  final Currency from, to;
  final double result;
  final ConversionPlan? plan;

  /// Contexto de tasas vivo (para pintar la tasa de cada fuente en la hoja).
  final RateContext ctx;
  final String activeSourceId;
  final String frescura;
  final bool hasOverride;
  final ValueChanged<double> onFromInput;
  final ValueChanged<double> onToInput;
  final ValueChanged<double> onAdjust;
  final VoidCallback onSwap;
  final ValueChanged<Currency> onFrom, onTo;
  final void Function(Currency c, String id) onPickSource;
  final VoidCallback onClearOverride;

  /// Línea de fuente + frescura (estilo XE): tocable → hoja con TODAS las
  /// fuentes de la divisa, su categoría y su tasa. El override del módulo
  /// (si existe) se anuncia y se limpia a un toque.
  Widget _fuenteLine(BuildContext ctx, ColorScheme scheme) {
    final src = RateSource.of(activeSourceId);
    final label =
        convSourceNames[activeSourceId] ?? src?.label ?? activeSourceId;
    return Row(children: [
      Expanded(
        child: InkWell(
          onTap: () => _openSourcesSheet(ctx),
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
            child: Row(children: [
              if (src != null) ...[SourceDot(src.category), const SizedBox(width: 8)],
              Expanded(
                child: Text.rich(
                  TextSpan(
                    text: label,
                    style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: scheme.onSurface),
                    children: [
                      TextSpan(
                          text: ' · $frescura',
                          style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: 4),
              Icon(Icons.expand_more, size: 18, color: scheme.onSurfaceVariant),
            ]),
          ),
        ),
      ),
      if (hasOverride)
        TextButton(
          onPressed: onClearOverride,
          style: TextButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            minimumSize: Size.zero,
            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
          child: const Text('Seguir global', style: TextStyle(fontSize: 11)),
        ),
    ]);
  }

  /// Hoja de fuentes de la divisa de origen (v19): el selector de TASA
  /// visual de toda la app — filas [Bandera][Nombre][Precio + símbolo] con
  /// color de categoría; la Manual abre el editor inline. Tocar una la
  /// activa (o limpia el override si es la global).
  Future<void> _openSourcesSheet(BuildContext context) async {
    await showRateSheet(
      context,
      currency: from,
      ctx: ctx,
      currentId: activeSourceId,
      onPick: (id) => onPickSource(from, id),
    );
  }

  /// Valor FROM efectivo para los ajustes rápidos (±10 % · ±100): si el
  /// conductor es el campo de abajo, se usa el monto derivado hacia arriba.
  double _fromValueOf(double result, ConversionPlan? plan) {
    final rate = plan?.rate ?? 0;
    if (rate <= 0) return 0;
    return result > 0 ? result / rate : 0;
  }

  /// Fila de entrada: monto (30 px, secundario) a la IZQUIERDA y selector de
  /// divisa a la derecha — el orden de lectura de XE/Wise. Siempre editable,
  /// con formato de miles en vivo (MoneyField).
  Widget _montoRow(ColorScheme scheme) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: MoneyField(
          controller: fromCtrl,
          onChanged: onFromInput,
          maxDecimals: 6,
          style: VeText.displayNum(30, color: scheme.onSurface),
          decoration: const InputDecoration(
            hintText: 'Monto',
            border: InputBorder.none,
            isCollapsed: true,
            contentPadding: EdgeInsets.symmetric(vertical: 8),
          ),
        ),
      ),
      const SizedBox(width: 8),
      CurrencySelect(value: from, onChanged: onFrom),
    ]);
  }

  /// Fila de salida: resultado HÉROE (46 px), EDITABLE (v19 bidireccional):
  /// escribir aquí calcula el monto hacia arriba. Debajo, la cifra con
  /// símbolo local que confirma el número grande SIN repetir la divisa.
  Widget _resultadoRow(ColorScheme scheme) {
    final ok = plan != null && result > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: MoneyField(
            controller: toCtrl,
            onChanged: onToInput,
            maxDecimals: 6,
            style: VeText.displayNum(
                46, color: ok ? scheme.onSurface : scheme.onSurfaceVariant),
            decoration: InputDecoration(
              hintText: 'Resultado',
              border: InputBorder.none,
              isCollapsed: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              hintStyle: VeText.displayNum(
                  46, color: scheme.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(width: 8),
        CurrencySelect(value: to, onChanged: onTo),
      ]),
      Padding(
        padding: const EdgeInsets.only(left: 4, top: 2),
        child: Text(
          ok
              ? '≈ ${fmtMoney(result, to)}'
              : 'sin tasa para este par',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontSize: ok ? 12 : 10.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant),
        ),
      ),
    ]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          _fuenteLine(context, scheme),
          const Divider(height: 18),
          _montoRow(scheme),
          // Swap centrado y GRANDE (v18.0): el gesto firma del conversor.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              const Expanded(child: SizedBox()),
              TapScale(
                onTap: onSwap,
                child: Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.08),
                    border: Border.all(
                        color: scheme.primary.withValues(alpha: 0.25)),
                  ),
                  child: Icon(Icons.swap_vert,
                      size: 26, color: scheme.primary),
                ),
              ),
              const Expanded(child: SizedBox()),
            ]),
          ),
          _resultadoRow(scheme),
          // REQ 6 · v18.0: ajustes rápidos al mismo ancho — 4 chips Expanded
          // (±10 % · ±100) siempre alineados, sin Wrap que los reordene.
          Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Row(
              children: [
                for (final adj in quickAdjustments)
                  Expanded(
                    child: Center(
                      child: ChipTag(
                        adj.label,
                        onTap: () =>
                            onAdjust(adj.apply(_fromValueOf(result, plan))),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
