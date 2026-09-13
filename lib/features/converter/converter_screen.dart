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
import '../../services/sharing.dart';
import '../../widgets/coach_mark.dart';
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
  final _amountCtrl = TextEditingController(text: '1');
  double _amount = 1;
  String _dateMode = 'today'; // today | yesterday | week | custom
  DateTime? _customDate;
  Map<String, double>? _historicRates; // tasas históricas (sourceId → rate)
  bool _historicLoading = false;
  final _notesCtrl = TextEditingController();
  Timer? _notesSave; // debounce 600 ms de las notas
  AppStore? _storeRef; // para el flush en dispose (sin context)

  /// Ancla del coach-mark de fecha histórica (Ola 1 · tips-dismissed).
  static final GlobalKey _tipFecha = GlobalKey(debugLabel: 'tip-converter-fecha');

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _storeRef = store;
    _notesCtrl.text = store.readConversionNotes();
    _notesCtrl.addListener(_onNotesChanged);
    // Coach-mark (Ola 1): fecha histórica — tras el walkthrough del módulo.
    scheduleFeatureTip(context, '/conversor', 'converter.fecha',
        anchor: _tipFecha,
        title: 'Ponle fecha al cálculo',
        body: '«Elegir fecha» abre el calendario con los días guardados (los '
            'remotos de 180 días se suman en vivo) y la tasa de ESE día entra '
            'al cálculo, con su ruta y su fuente a la vista.');
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
    _amountCtrl.dispose();
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
        final point = await rateOn(id, day, localFallback: (sourceId, d) {
          final local = store.snapshots.where((p) => p.sourceId == sourceId && p.day == d).toList()
            ..sort((a, b) => a.day.compareTo(b.day));
          return local.isEmpty ? null : HistPoint(date: local.last.day, rate: local.last.rate);
        });
        if (point != null) rates[id] = point.rate;
      } catch (_) {/* honesto: sin dato */}
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
  /// fuentes del par (180 días por fuente, seriesForSource). Offline → los
  /// locales cubren y el error se ignora en silencio.
  Future<Set<String>> _diasRemotos(List<String> ids) async {
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
    if (plan == null || _amount <= 0) return null;
    final result = _amount * plan.rate;
    final primaryId =
        plan.sourceIds.isNotEmpty ? plan.sourceIds.first : ctx.sel(from);
    final src = RateSource.of(primaryId);
    final label = convSourceNames[primaryId] ?? src?.label ?? primaryId;
    final cat = src?.category.label ?? '';
    return renderConversionSharePng(
      context,
      from: from,
      to: to,
      inputAmount: _amount,
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
    if (plan == null || _amount <= 0) return;
    final result = _amount * plan.rate;
    final text =
        '${fmtPlain(_amount, 2)} ${from.code} = ${fmtMoney(result, to)} · '
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
    if (plan == null || _amount <= 0) return;
    final result = _amount * plan.rate;
    final primaryId =
        plan.sourceIds.isNotEmpty ? plan.sourceIds.first : ctx.sel(from);
    final src = RateSource.of(primaryId);
    final label = convSourceNames[primaryId] ?? src?.label ?? primaryId;
    final cat = src?.category.label ?? '';
    copiarAlPortapapeles(
      context,
      '${fmtMoney(_amount, from)} ${from.code} = '
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

    double result = 0;
    if (plan != null && _amount > 0) result = _amount * plan.rate;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const PageHeader('Conversor', hint: 'Puente USD · EUR visible · ruta honesta'),
          // Fecha de la tasa activa + selector histórico (calendario real).
          KeyedSubtree(
            key: _tipFecha,
            child: _FechaTasas(
            store: store,
            ctx: ctx,
            from: from,
            plan: plan,
            mode: _dateMode,
            customDate: _customDate,
            loading: _historicLoading,
            historic: _historicRates,
            onMode: (m) {
              setState(() => _dateMode = m);
              _applyRateContext();
            },
            onOpenCalendar: _openHistoricCalendar,
          ),
          ),
          const SizedBox(height: 14),
          _DualInput(
            amountCtrl: _amountCtrl,
            amount: _amount,
            from: from,
            to: to,
            result: result,
            plan: plan,
            activeSourceId: ctx.sel(from),
            hasOverride: _hasOverride(store, from),
            onAmount: (v) => setState(() => _amount = v),
            onAdjust: (v) {
              setState(() {
                _amount = v <= 0 ? 0 : v;
                _amountCtrl.text = fmtPlain(_amount, 2);
              });
            },
            onSwap: () => store.setConverterPair(to.code, from.code),
            onFrom: (c) => store.setConverterPair(c.code, to.code),
            onTo: (c) => store.setConverterPair(from.code, c.code),
            onPickSource: _pickSource,
            onClearOverride: () =>
                store.setModuleRateSource(RateModule.converter, from, null),
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
          _TablaMontos(ctx: ctx, amount: _amount, from: from),
          // dp6 · mejora 9: matriz completa de pares a un vistazo (plegada).
          _Matriz6(ctx: ctx),
          _Recientes(from: from, to: to, amount: _amount, result: result, plan: plan),
          _Notas(ctrl: _notesCtrl),
        ],
      ),
    );
  }
}

/// Fila de fecha de las tasas (entre el encabezado y el conversor): tasa
/// activa con su frescura (timeAgo de updatedAt/fetchedAt) + presets +
/// botón de calendario histórico + banner «tasa del `fecha`».
class _FechaTasas extends StatelessWidget {
  const _FechaTasas({
    required this.store,
    required this.ctx,
    required this.from,
    required this.plan,
    required this.mode,
    required this.customDate,
    required this.loading,
    required this.historic,
    required this.onMode,
    required this.onOpenCalendar,
  });

  final AppStore store;
  final RateContext ctx;
  final Currency from;
  final ConversionPlan? plan;
  final String mode;
  final DateTime? customDate;
  final bool loading;
  final Map<String, double>? historic;
  final ValueChanged<String> onMode;
  final VoidCallback onOpenCalendar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    final primaryId =
        (plan != null && plan!.sourceIds.isNotEmpty) ? plan!.sourceIds.first : ctx.sel(from);
    final src = RateSource.of(primaryId);
    final label = convSourceNames[primaryId] ?? src?.label ?? primaryId;
    final entry = store.board.sources[primaryId];
    final when = entry?.updatedAt ?? store.board.fetchedAt;
    final frescura = src?.category == SourceCategory.manual
        ? 'tu tasa manual'
        : (when != null ? timeAgo(when) : 'sin fecha aún');
    final sinDatos = historic != null &&
        !loading &&
        (plan == null || plan!.rate <= 0);
    final String periodo = switch (mode) {
      'yesterday' => 'de ayer',
      'week' => 'de hace 7 días',
      _ => customDate == null ? 'del día elegido' : 'del ${fmtDate(customDate!)}',
    };

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          // Fila 1: fecha de la tasa activa + calendario histórico.
          Row(children: [
            if (src != null) ...[SourceDot(src.category), const SizedBox(width: 8)],
            Expanded(
              child: Text.rich(
                TextSpan(
                  text: 'Tasas de $label ',
                  style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                      color: scheme.onSurface),
                  children: [
                    TextSpan(
                        text: '· $frescura',
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
            const SizedBox(width: 8),
            ChipTag('Elegir fecha', selected: mode == 'custom', onTap: onOpenCalendar),
          ]),
          const SizedBox(height: 10),
          // Fila 2: presets (todos cargan histórico real).
          Wrap(spacing: 6, runSpacing: 6, children: [
            ChipTag('Hoy', selected: mode == 'today', onTap: () => onMode('today')),
            ChipTag('Ayer', selected: mode == 'yesterday', onTap: () => onMode('yesterday')),
            ChipTag('Hace 7 días', selected: mode == 'week', onTap: () => onMode('week')),
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

/// Entrada/salida dual del par. La tarjeta NO crece de más: ambas cifras
/// viven en ReadWindow con FittedBox(scaleDown) y maxLines 1 (REQ 1), el
/// selector de fuente va junto al par (REQ 2) y los ajustes rápidos quedan
/// pegados al campo de entrada (REQ 6).
class _DualInput extends StatefulWidget {
  const _DualInput({
    required this.amountCtrl,
    required this.amount,
    required this.from,
    required this.to,
    required this.result,
    required this.plan,
    required this.activeSourceId,
    required this.hasOverride,
    required this.onAmount,
    required this.onAdjust,
    required this.onSwap,
    required this.onFrom,
    required this.onTo,
    required this.onPickSource,
    required this.onClearOverride,
  });

  final TextEditingController amountCtrl;
  final double amount;
  final Currency from, to;
  final double result;
  final ConversionPlan? plan;
  final String activeSourceId;
  final bool hasOverride;
  final ValueChanged<double> onAmount;
  final ValueChanged<double> onAdjust;
  final VoidCallback onSwap;
  final ValueChanged<Currency> onFrom, onTo;
  final void Function(Currency c, String id) onPickSource;
  final VoidCallback onClearOverride;

  @override
  State<_DualInput> createState() => _DualInputState();
}

class _DualInputState extends State<_DualInput> {
  bool _editing = false;
  late final FocusNode _focus = FocusNode()
    ..addListener(() {
      if (!_focus.hasFocus && mounted && _editing) {
        setState(() => _editing = false);
      }
    });

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// Campo de monto: lectura con cifra escalable (FittedBox) y edición al
  /// tocar — misma ventana ReadWindow, altura controlada.
  Widget _campoMonto(ColorScheme scheme) {
    return ReadWindow(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      semanticLabel: 'Monto a convertir. Toca para editar.',
      child: _editing
          ? TextField(
              controller: widget.amountCtrl,
              focusNode: _focus,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              maxLines: 1,
              textAlign: TextAlign.end,
              // Entrada SECUNDARIA (v17.6): la cifra héroe del par es la
              // salida; el monto editable baja a 40 y se apoya en mutedFg
              // para no competir por el ojo.
              style: VeText.displayNum(40, color: scheme.onSurface),
              decoration: const InputDecoration(
                hintText: 'Monto',
                border: InputBorder.none,
              ),
              onChanged: (t) => widget.onAmount(parseLocaleNum(t) ?? 0),
              onSubmitted: (_) => _focus.unfocus(),
            )
          : GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => setState(() => _editing = true),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerRight,
                    child: Text(
                      fmtNum(widget.amount,
                          decimals: smartDecimals(widget.amount, widget.from)),
                      maxLines: 1,
                      // Entrada secundaria: 40 vs héroe 56 de la salida.
                      style: VeText.displayNum(40, color: scheme.onSurface),
                    ),
                  ),
                  const SizedBox(height: 2),
                  // Divisa SIEMPRE visible junto a la cifra (v17.5).
                  Row(mainAxisSize: MainAxisSize.min, children: [
                    CurrencyTag(widget.from.code),
                    const SizedBox(width: 6),
                    Flexible(
                      child: Text('toca para escribir',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurfaceVariant)),
                    ),
                  ]),
                ],
              ),
            ),
    );
  }

  /// Salida: cifra escalable (nunca desborda, REQ 1) y honesta: sin plan → «—».
  Widget _salida(ColorScheme scheme) {
    final ok = widget.plan != null && widget.result > 0;
    return ReadWindow(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      semanticLabel: 'Resultado de la conversión',
      child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerRight,
          child: ok
              ? AnimatedNumber(
                  widget.result,
                  // HÉROE del par (v17.6): la salida manda — 56 tabular,
                  // entrada a 40. Única cifra displayLarge de la pantalla.
                  style: VeText.displayNum(56, color: scheme.onSurface),
                  decimals: smartDecimals(widget.result, widget.to),
                )
              : Text('—',
                  maxLines: 1,
                  style:
                      VeText.displayNum(56, color: scheme.onSurfaceVariant)),
        ),
        const SizedBox(height: 2),
        // Divisa SIEMPRE visible junto a la cifra (v17.5).
        Row(mainAxisSize: MainAxisSize.min, children: [
          if (ok) ...[CurrencyTag(widget.to.code), const SizedBox(width: 6)],
          Flexible(
            child: Text(
              // FIX «Bs Bs» (v17.6): el TAG ya dice la divisa; el subtítulo
              // lleva SOLO el número (fmtMoney sin símbolo). Antes:
              // [Bs] Bs 832,49 — duplicado.
              ok ? fmtMoney(widget.result, widget.to) : 'sin tasa para este par',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
            ),
          ),
        ]),
      ]),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          // REQ 2: selector de fuente de tasa junto al par (default oficial).
          Row(children: [
            Expanded(
              child: Text('FUENTE DE TASA · ${widget.from.code}',
                  style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
            ),
            if (widget.hasOverride)
              TextButton(
                onPressed: widget.onClearOverride,
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(horizontal: 6),
                  minimumSize: Size.zero,
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                child: const Text('Seguir global', style: TextStyle(fontSize: 11)),
              ),
          ]),
          const SizedBox(height: 6),
          SourcePills(
            // USD no compite en el tablero: su única referencia entra igual
            // ('usd') para que el selector nunca quede vacío.
            sources: [
              for (final s in RateSource.sourcesFor(widget.from)) s.id,
              if (RateSource.sourcesFor(widget.from).isEmpty)
                RateSource.validSourceId(widget.from, null),
            ],
            value: widget.activeSourceId,
            onChanged: (id) => widget.onPickSource(widget.from, id),
          ),
          const SizedBox(height: 12),
          // Fila de entrada.
          Row(children: [
            CurrencySelect(value: widget.from, onChanged: widget.onFrom),
            const Spacer(),
            Expanded(flex: 2, child: _campoMonto(scheme)),
          ]),
          // REQ 6: ajustes rápidos inmediatamente bajo el campo de entrada.
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(
              alignment: WrapAlignment.end,
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final adj in quickAdjustments)
                  ChipTag(adj.label, onTap: () => widget.onAdjust(adj.apply(widget.amount))),
              ],
            ),
          ),
          // FIX swap (v17.6): centrado REAL entre las dos filas. Antes:
          // SizedBox(44) + Spacer → botón pegado a la izquierda.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const Expanded(child: SizedBox()),
              TapScale(
                onTap: widget.onSwap,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: scheme.primary.withValues(alpha: 0.08),
                  ),
                  child: Icon(Icons.swap_vert, size: 18, color: scheme.primary),
                ),
              ),
              const Expanded(child: SizedBox()),
            ]),
          ),
          // Fila de salida.
          Row(children: [
            CurrencySelect(value: widget.to, onChanged: widget.onTo),
            const Spacer(),
            Expanded(flex: 2, child: _salida(scheme)),
          ]),
        ]),
      ),
    );
  }
}

