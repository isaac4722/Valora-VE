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
import '../../widgets/app_tour.dart' show TourKeys;
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
        '${fmtMoney(_amount, from)} ${from.code} = ${fmtMoney(result, to)} · '
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
            amountCtrl: _amountCtrl,
            amount: _amount,
            from: from,
            to: to,
            result: result,
            plan: plan,
            ctx: ctx,
            activeSourceId: primaryId,
            frescura: frescura,
            hasOverride: _hasOverride(store, from),
            onAmount: (v) => setState(() => _amount = v),
            onAdjust: (v) {
              setState(() {
                _amount = v <= 0 ? 0 : v;
                // v19.0: el campo también habla es-VE («1.234,56»), igual que
                // el resto de la app — nada de formato en-US en la UI.
                _amountCtrl.text = fmtNum(_amount,
                    decimals: smartDecimals(_amount, from));
              });
            },
            onSwap: () => store.setConverterPair(to.code, from.code),
            onFrom: (c) => store.setConverterPair(c.code, to.code),
            onTo: (c) => store.setConverterPair(from.code, c.code),
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

/// Entrada/salida dual del par, layout XE/Wise (v18.0, orden del dueño):
/// · Fuente + frescura ARRIBA como una línea tocable (hoja de fuentes).
/// · Monto a la izquierda (30 px, secundario) · selector de divisa a la
///   derecha; el swap centrado y grande entre ambas filas.
/// · Resultado HÉROE (52 px, FittedBox scaleDown) con «≈ fmtMoney» debajo.
/// · Ajustes rápidos: fila de 4 chips al mismo ancho (±10 % · ±100).
/// La tarjeta nunca crece de más: cifras en ReadWindow con maxLines 1 (REQ 1).
class _DualInput extends StatefulWidget {
  const _DualInput({
    required this.amountCtrl,
    required this.amount,
    required this.from,
    required this.to,
    required this.result,
    required this.plan,
    required this.ctx,
    required this.activeSourceId,
    required this.frescura,
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

  /// Contexto de tasas vivo (para pintar la tasa de cada fuente en la hoja).
  final RateContext ctx;
  final String activeSourceId;
  final String frescura;
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

  /// Línea de fuente + frescura (estilo XE): tocable → hoja con TODAS las
  /// fuentes de la divisa, su categoría y su tasa. El override del módulo
  /// (si existe) se anuncia y se limpia a un toque. v19.0: con USD la línea
  /// NO se toca — el dólar es la referencia de la app (1 = 1), no una fuente
  /// elegible (orden del dueño).
  Widget _fuenteLine(ColorScheme scheme) {
    final src = RateSource.of(widget.activeSourceId);
    final label =
        convSourceNames[widget.activeSourceId] ?? src?.label ?? widget.activeSourceId;
    final isUsd = widget.from == Currency.usd;
    final content = Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
      child: Row(children: [
        if (!isUsd && src != null) ...[SourceSeal(src.category), const SizedBox(width: 8)],
        Expanded(
          child: Text.rich(
            TextSpan(
              text: isUsd ? 'USD · referencia de la app' : label,
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface),
              children: [
                TextSpan(
                    text: isUsd
                        ? ' · 1 = 1, sin fuente'
                        : ' · ${widget.frescura}',
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
        if (!isUsd)
          Icon(Icons.expand_more, size: 18, color: scheme.onSurfaceVariant),
      ]),
    );
    if (isUsd) return content; // sin InkWell: nada que elegir
    return Row(children: [
      Expanded(
        child: InkWell(
          onTap: _openSourcesSheet,
          borderRadius: BorderRadius.circular(10),
          child: content,
        ),
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
    ]);
  }

  /// Hoja de fuentes de la divisa de origen (v18.0): categoría + tasa de cada
  /// una; tocar una la activa (o limpia el override si es la global).
  /// v19.0: USD no abre hoja — no hay nada que elegir (1 = 1).
  Future<void> _openSourcesSheet() async {
    if (widget.from == Currency.usd) return;
    final scheme = Theme.of(context).colorScheme;
    final ids = <String>[
      for (final s in RateSource.sourcesFor(widget.from)) s.id,
    ];
    final picked = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          padding: const EdgeInsets.symmetric(vertical: 8),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
              child: Text('Fuente de tasa · ${widget.from.code}',
                  style: VeText.labelCaps(10.5, color: scheme.primary)),
            ),
            for (final id in ids)
              (() {
                final src = RateSource.of(id);
                final label = convSourceNames[id] ?? src?.label ?? id;
                final rate = widget.ctx.rate(id);
                final active = id == widget.activeSourceId;
                return ListTile(
                  dense: true,
                  leading: src == null ? null : SourceSeal(src.category),
                  title: Text(label,
                      style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: active ? scheme.primary : scheme.onSurface)),
                  subtitle: rate > 0
                      ? Text('1 ${widget.from.code} = ${fmtRate(rate)} ${widget.to.code}',
                          style: TextStyle(
                              fontSize: 11.5, color: scheme.onSurfaceVariant))
                      : null,
                  trailing: active
                      ? Icon(Icons.check_rounded, size: 18, color: scheme.primary)
                      : null,
                  onTap: () => Navigator.of(context).pop(id),
                );
              })(),
          ],
        ),
      ),
    );
    if (picked != null) widget.onPickSource(widget.from, picked);
  }

  /// Fila de entrada: monto (30 px, secundario) a la IZQUIERDA y selector de
  /// divisa a la derecha — el orden de lectura de XE/Wise.
  Widget _montoRow(ColorScheme scheme) {
    return Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
      Expanded(
        child: ReadWindow(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
          semanticLabel: 'Monto a convertir. Toca para editar.',
          child: _editing
              ? TextField(
                  controller: widget.amountCtrl,
                  focusNode: _focus,
                  autofocus: true,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  maxLines: 1,
                  textAlign: TextAlign.left,
                  // Entrada SECUNDARIA (v18.0): 30 px — el héroe es el
                  // resultado, no el monto.
                  style: VeText.displayNum(30, color: scheme.onSurface),
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
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          fmtNum(widget.amount,
                              decimals: smartDecimals(widget.amount, widget.from)),
                          maxLines: 1,
                          style: VeText.displayNum(30, color: scheme.onSurface),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text('toca para escribir',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurfaceVariant)),
                    ],
                  ),
                ),
        ),
      ),
      const SizedBox(width: 8),
      CurrencySelect(value: widget.from, onChanged: widget.onFrom),
    ]);
  }

  /// Fila de salida: resultado HÉROE (52 px) a la izquierda, selector de
  /// divisa a la derecha y «≈ fmtMoney» debajo — la cifra con símbolo local
  /// que confirma el número grande SIN repetir la divisa (fin del «Bs Bs»).
  Widget _resultadoRow(ColorScheme scheme) {
    final ok = widget.plan != null && widget.result > 0;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        Expanded(
          child: ReadWindow(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
            semanticLabel: 'Resultado de la conversión',
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: ok
                  ? AnimatedNumber(
                      widget.result,
                      style: VeText.displayNum(52, color: scheme.onSurface),
                      decimals: smartDecimals(widget.result, widget.to),
                    )
                  : Text('—',
                      maxLines: 1,
                      style: VeText.displayNum(
                          52, color: scheme.onSurfaceVariant)),
            ),
          ),
        ),
        const SizedBox(width: 8),
        CurrencySelect(value: widget.to, onChanged: widget.onTo),
      ]),
      if (ok)
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 2),
          child: Text(
            '≈ ${fmtMoney(widget.result, widget.to)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                fontFeatures: const [FontFeature.tabularFigures()],
                color: scheme.onSurfaceVariant),
          ),
        )
      else
        Padding(
          padding: const EdgeInsets.only(left: 4, top: 2),
          child: Text('sin tasa para este par',
              style: TextStyle(
                  fontSize: 10.5, color: scheme.onSurfaceVariant)),
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
          _fuenteLine(scheme),
          const Divider(height: 18),
          _montoRow(scheme),
          // Swap centrado y GRANDE (v18.0): el gesto firma del conversor.
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: Row(children: [
              const Expanded(child: SizedBox()),
              TapScale(
                onTap: widget.onSwap,
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
                            widget.onAdjust(adj.apply(widget.amount)),
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
