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

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/history_api.dart';
import '../../data/rate_history.dart';
import '../../data/store.dart';
import '../../services/sharing.dart';
import '../../widgets/share_card.dart';
import '../../widgets/ui.dart';

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
      builder: (_) => _CalendarioHistorico(
        days: days,
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
  Future<void> _shareCard() async {
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
    final png = await renderConversionSharePng(
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
    if (!mounted) return;
    if (png == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No pude generar la tarjeta'),
          behavior: SnackBarBehavior.floating));
      return;
    }
    await sharePng(png, 'conversion-valorave.png');
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
          _FechaTasas(
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
          _Recientes(from: from, to: to, amount: _amount, result: result, plan: plan),
          _Notas(ctrl: _notesCtrl),
        ],
      ),
    );
  }
}

/// Fila de fecha de las tasas (entre el encabezado y el conversor): tasa
/// activa con su frescura (timeAgo de updatedAt/fetchedAt) + presets +
/// botón de calendario histórico + banner «tasa del <fecha>».
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
  final ({double rate, List<Currency> path, List<String> sourceIds})? plan;
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
  final ({double rate, List<Currency> path, List<String> sourceIds})? plan;
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
              // Héroe del par: cifra grande tabular (firma de la app).
              style: VeText.displayNum(56, color: scheme.onSurface),
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
                      style: VeText.displayNum(56, color: scheme.onSurface),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text('${widget.from.code} · toca para escribir',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5, color: scheme.onSurfaceVariant)),
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
                  // Héroe del par: cifra grande tabular (firma de la app).
                  style: VeText.displayNum(56, color: scheme.onSurface),
                  decimals: smartDecimals(widget.result, widget.to),
                )
              : Text('—',
                  maxLines: 1,
                  style:
                      VeText.displayNum(56, color: scheme.onSurfaceVariant)),
        ),
        const SizedBox(height: 2),
        Text(
          ok ? fmtCurrency(widget.result, widget.to) : 'sin tasa para este par',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
        ),
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
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const SizedBox(width: 44),
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
              const Spacer(),
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

/// Ruta del cálculo legible (arista directa · puente EUR · vía dólar).
class _RutaCalculo extends StatelessWidget {
  const _RutaCalculo({required this.plan});
  final ({double rate, List<Currency> path, List<String> sourceIds})? plan;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (plan == null) {
      return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        SectionTitle('Ruta del cálculo'),
        Text('Sin tasa disponible para este par. Revisa tus fuentes en '
                'Ajustes → Monedas y tasas, o pega una tasa manual.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
      ]);
    }
    final p = plan!;
    final labels = p.sourceIds
        .map((id) => convSourceNames[id] ?? RateSource.of(id)?.label ?? id)
        .where((s) => s.isNotEmpty)
        .join(' + ');
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Ruta del cálculo'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Row(children: [
            for (int i = 0; i < p.path.length; i++) ...[
              if (i > 0) ...[
                Icon(Icons.arrow_forward, size: 13, color: scheme.onSurfaceVariant),
                const SizedBox(width: 6),
              ],
              Flag(p.path[i], size: 16),
              const SizedBox(width: 4),
              Text(p.path[i].code, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800)),
              const SizedBox(width: 4),
            ],
            const Spacer(),
            if (labels.isNotEmpty)
              Flexible(child: Stamp(labels, color: scheme.primary))
          ]),
        ),
      ),
    ]);
  }
}

/// REQ 5 — Referencia de fuentes del par: TODAS las fuentes disponibles de
/// la divisa de origen y de destino (VES: BCV · Paralelo · Promedio · Manual;
/// COP: TRM · Mercado · Manual; EUR: sus aristas; USD: referencia). Cada fila
/// muestra punto de categoría, nombre, detalle, tasa y marca la activa;
/// tocar una fila la usa como fuente (mismo camino del selector de chips).
class _ReferenciaFuentes extends StatelessWidget {
  const _ReferenciaFuentes({
    required this.ctx,
    required this.from,
    required this.to,
    required this.onPick,
  });

  final RateContext ctx;
  final Currency from, to;
  final void Function(Currency c, String id) onPick;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Dedupe por id conservando el orden: primero la divisa de origen.
    final ids = <String>[];
    for (final s in [...RateSource.sourcesFor(from), ...RateSource.sourcesFor(to)]) {
      if (!ids.contains(s.id)) ids.add(s.id);
    }
    // USD no compite en el tablero: entra como referencia (1 USD = USD).
    if ((from == Currency.usd || to == Currency.usd) && !ids.contains('usd')) {
      if (from == Currency.usd) {
        ids.insert(0, 'usd');
      } else {
        ids.add('usd');
      }
    }
    if (ids.isEmpty) ids.add(RateSource.validSourceId(from, null));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Referencia de fuentes'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            for (final id in ids)
              if (RateSource.of(id) != null)
                _fila(context, scheme, RateSource.of(id)!),
          ]),
        ),
      ),
    ]);
  }

  Widget _fila(BuildContext context, ColorScheme scheme, RateSource s) {
    final activa = ctx.sel(s.currency) == s.id;
    // USD es el puente: tasa de referencia 1 (RateContext.activeRate(usd)).
    final r = s.id == 'usd' ? 1.0 : ctx.rate(s.id);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(children: [
        SourceDot(s.category),
        const SizedBox(width: 9),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('${s.currency.code} ${s.label}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 13,
                    fontWeight:
                        activa ? FontWeight.w800 : FontWeight.w600,
                    color: scheme.onSurface)),
            Text(s.detail,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 10.5, color: scheme.onSurfaceVariant)),
          ]),
        ),
        const SizedBox(width: 8),
        Text(r > 0 ? fmtRate(r) : '—',
            style: VeText.displayNum(13.5, color: scheme.onSurface)),
        Text(' ${s.quote.code}',
            style: TextStyle(
                fontSize: 10.5,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant)),
        const SizedBox(width: 8),
        if (activa)
          Icon(Icons.check_circle, size: 15, color: scheme.primary)
        else
          const SizedBox(width: 15),
      ]),
    );
    return InkWell(
      onTap: () => onPick(s.currency, s.id),
      borderRadius: BorderRadius.circular(8),
      child: row,
    );
  }
}

/// Montos de referencia: el monto y sus múltiplos a Bs (planForTable del web).
class _TablaMontos extends StatelessWidget {
  const _TablaMontos({required this.ctx, required this.amount, required this.from});
  final RateContext ctx;
  final double amount;
  final Currency from;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amounts = quickAmounts[from] ?? const <double>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Montos de referencia'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            for (final a in amounts)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Text(fmtMoney(a, from),
                      style: VeText.displayNum(13.5, color: scheme.onSurface)),
                  const Spacer(),
                  Text(fmtCurrency(ctx.convert(a, from, Currency.ves), Currency.ves),
                      style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant)),
                ]),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _Recientes extends StatelessWidget {
  const _Recientes({
    required this.from,
    required this.to,
    required this.amount,
    required this.result,
    required this.plan,
  });
  final Currency from, to;
  final double amount;
  final double result;
  final ({double rate, List<Currency> path, List<String> sourceIds})? plan;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final recents = store.readRecentConversions();

    // Registra la conversión actual con el MONTO REAL del campo
    // (dedupe <60s dentro del store).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (result > 0 && plan != null && amount > 0) {
        store.pushRecentConversion(amount, from, to);
      }
    });

    if (recents.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Recientes',
          actionLabel: 'Vaciar', onAction: () => store.clearRecentConversions()),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            for (final r in recents.take(10))
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(children: [
                  Flag(CurrencyX.from(r.from), size: 15),
                  const SizedBox(width: 4),
                  Text(fmtNum(r.amount, decimals: 2), style: VeText.displayNum(12.5, color: Theme.of(context).colorScheme.onSurface)),
                  Icon(Icons.arrow_forward, size: 12, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  Flag(CurrencyX.from(r.to), size: 15),
                  const SizedBox(width: 6),
                  Text('${r.from} → ${r.to}',
                      style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                  const Spacer(),
                  Text(fmtDate(r.at), style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
                ]),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _Notas extends StatelessWidget {
  const _Notas({required this.ctrl});
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Notas',
          actionLabel: 'Limpiar',
          onAction: () {
            ctrl.clear();
            store.writeConversionNotes('');
          }),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: ctrl,
            maxLines: 4,
            maxLength: 5000,
            decoration: const InputDecoration(
              hintText: 'Apunta aquí: dónde vi la tasa, qué comparé…',
              border: InputBorder.none,
            ),
          ),
        ),
      ),
    ]);
  }
}

/// REQ 4 — Calendario histórico REAL: rejilla mensual con los días que
/// tienen snapshot guardado para las fuentes del par. Solo esos días son
/// tocables; hoy lleva borde; el día elegido va relleno. Tema light/dark
/// con tokens del sistema (nada de Material por defecto sin tratar).
class _CalendarioHistorico extends StatefulWidget {
  const _CalendarioHistorico({
    required this.days,
    required this.sourceLabel,
    this.initial,
  });

  /// Días disponibles YYYY-MM-DD (solo con datos — REQ 8: nunca días vacíos).
  final Set<String> days;
  final DateTime? initial;
  final String sourceLabel;

  @override
  State<_CalendarioHistorico> createState() => _CalendarioHistoricoState();
}

class _CalendarioHistoricoState extends State<_CalendarioHistorico> {
  late DateTime _month;

  @override
  void initState() {
    super.initState();
    final anchor = widget.initial ?? _ultimoDia() ?? DateTime.now();
    _month = DateTime(anchor.year, anchor.month, 1);
  }

  DateTime? _ultimoDia() {
    if (widget.days.isEmpty) return null;
    final last = widget.days.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    final d = DateTime.parse(last);
    return DateTime(d.year, d.month, 1);
  }

  DateTime? get _minMonth {
    if (widget.days.isEmpty) return null;
    final first = widget.days.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    final d = DateTime.parse(first);
    return DateTime(d.year, d.month, 1);
  }

  DateTime get _maxMonth {
    final n = DateTime.now();
    return DateTime(n.year, n.month, 1);
  }

  void _mover(int meses) {
    setState(() {
      _month = DateTime(_month.year, _month.month + meses, 1);
    });
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final min = _minMonth;
    final puedePrev = min != null && _month.isAfter(min);
    final puedeNext = _month.isBefore(_maxMonth);
    final mes = kMeses[_month.month - 1];

    return SafeArea(
      top: false,
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 18, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Elegir fecha histórica',
              style: TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 15,
                  fontWeight: FontWeight.w800,
                  color: scheme.onSurface)),
          const SizedBox(height: 2),
          Text('Fuentes: ${widget.sourceLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
          const SizedBox(height: 12),
          if (widget.days.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: EmptyState(
                'Aún no hay fechas guardadas',
                icon: Icons.calendar_month,
                hint: 'La app guarda un snapshot por día cada vez que se '
                    'refrescan las tasas. Vuelve mañana y el calendario '
                    'tendrá su primer día.',
              ),
            )
          else ...[
            Row(children: [
              IconButton(
                onPressed: puedePrev ? () => _mover(-1) : null,
                icon: const Icon(Icons.chevron_left, size: 20),
                tooltip: 'Mes anterior',
              ),
              Expanded(
                child: Center(
                  child: Text(
                    '${mes[0].toUpperCase()}${mes.substring(1)} ${_month.year}',
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface),
                  ),
                ),
              ),
              IconButton(
                onPressed: puedeNext ? () => _mover(1) : null,
                icon: const Icon(Icons.chevron_right, size: 20),
                tooltip: 'Mes siguiente',
              ),
            ]),
            const SizedBox(height: 4),
            Row(children: [
              for (final d in const ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
                Expanded(
                  child: Center(
                    child: Text(d,
                        style: VeText.labelCaps(9.5,
                            color: scheme.onSurfaceVariant)),
                  ),
                ),
            ]),
            const SizedBox(height: 4),
            ..._semanas(scheme),
            const SizedBox(height: 10),
            Text(
              'Solo son tocables los días con snapshot guardado en este '
              'dispositivo.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ]),
      ),
    );
  }

  /// Rejilla de 7 columnas (lunes primero) con semanas completas.
  List<Widget> _semanas(ColorScheme scheme) {
    final lead = DateTime(_month.year, _month.month, 1).weekday - 1;
    final total = DateTime(_month.year, _month.month + 1, 0).day;
    final celdas = <int?>[
      for (var i = 0; i < lead; i++) null,
      for (var d = 1; d <= total; d++) d,
    ];
    while (celdas.length % 7 != 0) {
      celdas.add(null);
    }
    final semanas = (celdas.length / 7).ceil();
    return [
      for (var w = 0; w < semanas; w++)
        Row(children: [
          for (var i = 0; i < 7; i++) Expanded(child: _celda(celdas[w * 7 + i], scheme)),
        ]),
    ];
  }

  Widget _celda(int? day, ColorScheme scheme) {
    if (day == null) return const SizedBox(height: 42);
    final date = DateTime(_month.year, _month.month, day);
    final key = SnapshotPoint.dayKey(date);
    final disponible = widget.days.contains(key);
    final esHoy = key == SnapshotPoint.dayKey(DateTime.now());
    final elegido = widget.initial != null && SnapshotPoint.dayKey(widget.initial!) == key;
    final fondo = elegido
        ? scheme.primary
        : disponible
            ? scheme.primary.withValues(alpha: 0.08)
            : Colors.transparent;
    final tinta = elegido
        ? scheme.onPrimary
        : disponible
            ? scheme.onSurface
            : scheme.onSurfaceVariant.withValues(alpha: 0.4);
    return SizedBox(
      height: 42,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: fondo,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
            // REQ 4/8: solo días con datos son seleccionables.
            onTap: disponible ? () => Navigator.of(context).pop(date) : null,
            child: Center(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: esHoy && !elegido
                      ? Border.all(color: scheme.primary.withValues(alpha: 0.55))
                      : null,
                ),
                child: Text('$day',
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight:
                            elegido || esHoy ? FontWeight.w800 : FontWeight.w600,
                        color: tinta)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
