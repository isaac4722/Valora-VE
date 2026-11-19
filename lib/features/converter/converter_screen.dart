/// ─── Conversor (§9.2 · MODULE=converter) ───────────────────────────────────
/// Monto dual from/to con swap y odómetros · fecha de tasas (Hoy/Ayer/Hace
/// 7d + histórica honesta: sin dato → sin dato, nunca fabrica) · ajustes
/// rápidos · comparación de fuentes · ruta del cálculo · recientes (10) ·
/// notas (5000) · tabla de referencia · compartir.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:provider/provider.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/history_api.dart';
import '../../data/store.dart';
import '../../services/sharing.dart';
import '../../widgets/ui.dart';

class ConverterScreen extends StatefulWidget {
  const ConverterScreen({super.key});

  @override
  State<ConverterScreen> createState() => _ConverterScreenState();
}

class _ConverterScreenState extends State<ConverterScreen> {
  final _amountCtrl = TextEditingController(text: '1');
  final _shareKey = GlobalKey(); // RepaintBoundary del cálculo → PNG
  double _amount = 1;
  bool _keypadVisible = true; // GUI simple: teclado plegable (patrón CalculaYa)
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
  /// Elegir fecha) van por el MISMO camino de carga histórica real.
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
  /// Sin dato → mapa vacío → mensaje honesto; nunca fabrica tasas.
  Future<void> _loadHistoric(DateTime date) async {
    final store = context.read<AppStore>();
    final day = SnapshotPoint.dayKey(date);
    final rates = <String, double>{};
    for (final id in ['ves-bcv', 'ves-parallel', 'eur-ves-oficial', 'cop-trm', 'brl-br', 'mxn-banxico']) {
      try {
        final point = await rateOn(id, day, localFallback: (sourceId, d) {
          final local = store.snapshots.where((p) => p.sourceId == sourceId && p.day == d).toList()
            ..sort((a, b) => a.day.compareTo(b.day));
          return local.isEmpty ? null : HistPoint(date: local.last.day, rate: local.last.rate);
        });
        if (point != null) rates[id] = point.rate;
      } catch (_) {/* honesto: sin dato */}
    }
    if (mounted) {
      setState(() {
        _historicRates = rates;
        _historicLoading = false;
      });
    }
  }

  /// Tecla del VeKeypad: dígitos y coma es-VE escriben; ⌫ borra; C limpia.
  void _onKeypadKey(String k) {
    setState(() {
      switch (k) {
        case '⌫':
          if (_amountCtrl.text.isNotEmpty) _amountCtrl.text = _amountCtrl.text.substring(0, _amountCtrl.text.length - 1);
        case 'C':
          _amountCtrl.text = '';
        default:
          // evita dobles comas y múltiple ceros a la izquierda
          if (k == ',' && _amountCtrl.text.contains(',')) return;
          _amountCtrl.text = '${_amountCtrl.text}$k';
      }
      _amount = parseLocaleNum(_amountCtrl.text) ?? 0;
    });
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

  /// Comparte el cálculo como PNG (tarjeta 1080px con monto, ruta y marca).
  Future<void> _sharePng() async {
    final bytes = await captureWidget(_shareKey);
    if (!mounted) return;
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('No pude generar la imagen'), behavior: SnackBarBehavior.floating));
      return;
    }
    await sharePng(bytes, 'valorave-conversion.png');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final ctx = _context(store);
    final from = CurrencyX.from(store.data.converter.from);
    final to = CurrencyX.from(store.data.converter.to);
    final plan = ctx.plan(from, to);
    final bool rounding = store.settings.numMode == 'redondeo';

    double result = 0;
    if (plan != null && _amount > 0) result = _amount * plan.rate;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const PageHeader('Divisas', hint: 'Puente USD · EUR visible · ruta honesta'),
          RepaintBoundary(
            key: _shareKey,
            child: Container(
              color: scheme.surfaceContainerLowest,
              child: Column(children: [
                _DualInput(
                  amountCtrl: _amountCtrl,
                  from: from,
                  to: to,
                  result: result,
                  plan: plan,
                  rounding: rounding,
                  onAmount: (v) => setState(() => _amount = v),
                  onSwap: () => store.setConverterPair(to.code, from.code),
                  onFrom: (c) => store.setConverterPair(c.code, to.code),
                  onTo: (c) => store.setConverterPair(from.code, c.code),
                ),
                _RutaCalculo(plan: plan),
                // Marca que sale en el PNG compartido (fila firma).
                Padding(
                  padding: const EdgeInsets.only(top: 10, bottom: 2),
                  child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Container(
                      width: 22,
                      height: 22,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: const Color(0xFF22354E),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Text('V',
                          style: TextStyle(
                              fontFamily: 'SpaceGrotesk',
                              fontSize: 13,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              height: 1)),
                    ),
                    const SizedBox(width: 6),
                    const Text('ValoraVE',
                        style: TextStyle(
                            fontFamily: 'SpaceGrotesk',
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFF22354E))),
                  ]),
                ),
              ]),
            ),
          ),
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Row(children: [
              FilledButton.tonalIcon(
                onPressed: plan == null || result <= 0 ? null : _sharePng,
                icon: const Icon(Icons.ios_share, size: 16),
                label: const Text('Compartir cálculo'),
              ),
              const SizedBox(width: 8),
              // Pago Móvil (G5): solo cuando el destino es VES y hay cuenta.
              if (to == Currency.ves)
                FilledButton.tonalIcon(
                  onPressed: result <= 0 ? null : () => showPagoMovilSheet(context, result),
                  icon: const Icon(Icons.account_balance, size: 16),
                  label: const Text('Pago Móvil'),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: Text('Imagen 1080 px con ruta y fuentes.',
                    style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
              ),
            ]),
          ),
          _KeypadCard(
            visible: _keypadVisible,
            rounding: rounding,
            amount: _amount,
            onToggle: () => setState(() => _keypadVisible = !_keypadVisible),
            onRounding: (v) => store.setSetting('numMode', v),
            onKey: _onKeypadKey,
            onAmount: (v) {
              setState(() {
                _amount = v <= 0 ? 0 : v;
                _amountCtrl.text = fmtPlain(_amount, 2);
              });
            },
          ),
          _FechaTasas(
            mode: _dateMode,
            customDate: _customDate,
            loading: _historicLoading,
            historic: _historicRates,
            onMode: (m) {
              setState(() {
                _dateMode = m;
                if (m == 'custom' && _customDate == null) {
                  _customDate = DateTime.now().subtract(const Duration(days: 7));
                }
              });
              _applyRateContext();
            },
            onDate: (d) {
              setState(() => _customDate = d);
              _applyRateContext();
            },
          ),
          _TablaFuentes(ctx: ctx, from: from, to: to),
          _TablaReferencia(ctx: ctx, amount: _amount, from: from),
          _Recientes(from: from, to: to, amount: _amount, result: result, plan: plan),
          _Notas(ctrl: _notesCtrl),
        ],
      ),
    );
  }
}

class _DualInput extends StatelessWidget {
  const _DualInput({
    required this.amountCtrl,
    required this.from,
    required this.to,
    required this.result,
    required this.plan,
    required this.rounding,
    required this.onAmount,
    required this.onSwap,
    required this.onFrom,
    required this.onTo,
  });

  final TextEditingController amountCtrl;
  final Currency from, to;
  final double result;
  final ({double rate, List<Currency> path, List<String> sourceIds})? plan;
  final bool rounding;
  final ValueChanged<double> onAmount;
  final VoidCallback onSwap;
  final ValueChanged<Currency> onFrom, onTo;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(children: [
          Row(children: [
            CurrencySelect(value: from, onChanged: onFrom),
            const Spacer(),
            Expanded(
              flex: 2,
              child: TextField(
                controller: amountCtrl,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                // Héroe del par: cifra grande tabular (firma de la app).
                style: VeText.displayNum(56, color: scheme.onSurface),
                textAlign: TextAlign.end,
                decoration: const InputDecoration(hintText: 'Monto'),
                onChanged: (t) => onAmount(parseLocaleNum(t) ?? 0),
              ),
            ),
          ]),
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(children: [
              const SizedBox(width: 44),
              TapScale(
                onTap: onSwap,
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
          Row(children: [
            CurrencySelect(value: to, onChanged: onTo),
            const Spacer(),
            Expanded(
              flex: 2,
              child: ReadWindow(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                semanticLabel: 'Resultado de la conversión',
                child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                  AnimatedNumber(
                    result,
                    // Héroe del par: cifra grande tabular (firma de la app).
                    style: VeText.displayNum(56, color: scheme.onSurface),
                    decimals: convDecimals(result, to, rounding: rounding),
                  ),
                  Text(fmtNum(result, decimals: convDecimals(result, to, rounding: rounding)),
                      style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
                ]),
              ),
            ),
          ]),
        ]),
      ),
    );
  }
}

class _KeypadCard extends StatelessWidget {
  const _KeypadCard({
    required this.visible,
    required this.rounding,
    required this.amount,
    required this.onToggle,
    required this.onRounding,
    required this.onKey,
    required this.onAmount,
  });

  final bool visible;
  final bool rounding;
  final double amount;
  final VoidCallback onToggle;
  final ValueChanged<String> onRounding;
  final ValueChanged<String> onKey;
  final ValueChanged<double> onAmount;

  static const _amounts = [1.0, 5.0, 10.0, 20.0, 50.0, 100.0];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(10, 10, 10, 12),
          child: Column(children: [
            // Fila de control: plegar teclado · decimales/redondeo.
            Row(children: [
              TapScale(
                onTap: onToggle,
                child: Semantics(
                  button: true,
                  label: visible ? 'Ocultar teclado' : 'Mostrar teclado',
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(mainAxisSize: MainAxisSize.min, children: [
                      Icon(Icons.keyboard_hide_outlined,
                          size: 15, color: scheme.onSurfaceVariant),
                      const SizedBox(width: 6),
                      Text(visible ? 'Ocultar teclado' : 'Teclado',
                          style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: scheme.onSurfaceVariant)),
                    ]),
                  ),
                ),
              ),
              const Spacer(),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'decimales', label: Text('Decimales')),
                  ButtonSegment(value: 'redondeo', label: Text('Redondear')),
                ],
                selected: {rounding ? 'redondeo' : 'decimales'},
                showSelectedIcon: false,
                onSelectionChanged: (s) => onRounding(s.first),
                style: ButtonStyle(
                  visualDensity: VisualDensity.compact,
                  textStyle: WidgetStatePropertyAll(
                      const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600)),
                ),
              ),
            ]),
            if (visible) ...[
              const SizedBox(height: 10),
              VeKeypad(onKey: onKey),
            ],
            const SizedBox(height: 10),
            // Fichas de monto absoluto (patrón CalculaYa).
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final v in _amounts)
                  ChipTag(fmtPlain(v, v == v.truncateToDouble() ? 0 : 2),
                      onTap: () => onAmount(v)),
              ],
            ),
            const SizedBox(height: 6),
 // Ajustes relativos del monto (no tecleables directamente: ±100 / ±10 %).
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final adj in quickAdjustments)
                  ChipTag(adj.label, onTap: () => onAmount(adj.apply(amount))),
              ],
            ),
          ]),
        ),
      ),
    );
  }
}

class _FechaTasas extends StatelessWidget {
  const _FechaTasas({
    required this.mode,
    required this.customDate,
    required this.loading,
    required this.historic,
    required this.onMode,
    required this.onDate,
  });

  final String mode;
  final DateTime? customDate;
  final bool loading;
  final Map<String, double>? historic;
  final ValueChanged<String> onMode;
  final ValueChanged<DateTime> onDate;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Fecha de las tasas'),
      Wrap(spacing: 6, children: [
        ChipTag('Hoy', selected: mode == 'today', onTap: () => onMode('today')),
        ChipTag('Ayer', selected: mode == 'yesterday', onTap: () => onMode('yesterday')),
        ChipTag('Hace 7 días', selected: mode == 'week', onTap: () => onMode('week')),
        ChipTag('Elegir fecha', selected: mode == 'custom', onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: customDate ?? now.subtract(const Duration(days: 7)),
            firstDate: DateTime(2023, 1, 3), // PICKER_MIN
            lastDate: now,
            locale: const Locale('es'),
          );
          if (picked != null) onMode('custom');
          if (picked != null) onDate(picked);
        }),
        if (customDate != null && mode == 'custom')
          Padding(
            padding: const EdgeInsets.only(left: 4, top: 4),
            child: Text(fmtDate(customDate!),
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: scheme.primary)),
          ),
      ]),
      // Los 3 presets + custom cargan histórico real: loading y mensaje
      // honesto si la fecha no tiene dato.
      if (mode != 'today') ...[
        const SizedBox(height: 8),
        if (loading)
          const Padding(padding: EdgeInsets.all(8), child: SizedBox(
              width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2)))
        else if (historic != null && historic!.isEmpty)
          Text('Sin datos para esa fecha (la serie empieza el 03-ene-2023 y '
                  'necesita conexión o snapshots guardados).',
              style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant))
      ],
    ]);
  }
}

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
              Stamp(labels, color: scheme.primary)
          ]),
        ),
      ),
    ]);
  }
}

class _TablaFuentes extends StatelessWidget {
  const _TablaFuentes({required this.ctx, required this.from, required this.to});
  final RateContext ctx;
  final Currency from, to;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    final p = ctx.plan(from, to);
    final sources = p == null ? const <String>[] : p.sourceIds;
    // Tasas personalizadas nombradas (patrón CalculaYa): fila propia con
    // brecha vs BCV; también comparan en el par USD→VES.
    final customs = store.customRates;
    final showCustoms = customs.isNotEmpty && from == Currency.usd && to == Currency.ves;
    if (sources.isEmpty && !showCustoms) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Comparación de fuentes'),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            for (final id in sources)
              if (RateSource.of(id) != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(children: [
                    SourceDot(RateSource.of(id)!.category),
                    const SizedBox(width: 8),
                    Expanded(child: Text(convSourceNames[id] ?? RateSource.of(id)!.label,
                        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
                    Text(ctx.rate(id) > 0 ? fmtRate(ctx.rate(id)) : '—',
                        style: VeText.displayNum(13.5, color: scheme.onSurface)),
                  ]),
                ),
            if (showCustoms)
              for (final cr in customs)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: TapScale(
                    // Seleccionable: aplica la tasa propia como fuente manual
                    // de VES (mecanismo existente del motor, sin cambios core).
                    onTap: () {
                      store.setManualRate('ves-manual', cr.bsPerUsd);
                      store.setRateSource(Currency.ves, 'ves-manual');
                    },
                    child: Row(children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: scheme.primary.withValues(alpha: 0.55)),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(cr.name,
                              style: const TextStyle(
                                  fontSize: 13, fontWeight: FontWeight.w600))),
                      GapChip(bsPerUsd: cr.bsPerUsd, bcv: store.bcvRate),
                      const SizedBox(width: 6),
                      Text(fmtRate(cr.bsPerUsd),
                          style: VeText.displayNum(13.5, color: scheme.onSurface)),
                    ]),
                  ),
                ),
          ]),
        ),
      ),
    ]);
  }
}

/// Tabla de referencia: el monto y sus múltiplos (planForTable del web).
class _TablaReferencia extends StatelessWidget {
  const _TablaReferencia({required this.ctx, required this.amount, required this.from});
  final RateContext ctx;
  final double amount;
  final Currency from;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amounts = quickAmounts[from] ?? const <double>[];
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Tabla de referencia'),
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

// ─── Compartir Pago Móvil (G5 · patrón CalculaYa con candado y aviso) ───────

/// Sheet con el monto convertido + datos de cobro de la cuenta elegida.
/// Aviso de sensibilidad visible; copiar y compartir en texto plano.
void showPagoMovilSheet(BuildContext context, double amountVes) {
  final store = context.read<AppStore>();
  if (store.accounts.isEmpty) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Agrega una cuenta en Ajustes → Cuentas y Pago Móvil'),
        behavior: SnackBarBehavior.floating));
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => _PagoMovilSheet(amountVes: amountVes),
  );
}

class _PagoMovilSheet extends StatefulWidget {
  const _PagoMovilSheet({required this.amountVes});
  final double amountVes;

  @override
  State<_PagoMovilSheet> createState() => _PagoMovilSheetState();
}

class _PagoMovilSheetState extends State<_PagoMovilSheet> {
  int _sel = 0;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final accounts = store.accounts;
    if (_sel >= accounts.length) _sel = 0;
    final acc = accounts.isEmpty ? null : accounts[_sel];

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.55,
        maxChildSize: 0.85,
        builder: (context, scroll) => SingleChildScrollView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Center(
              child: Container(
                  width: 36, height: 4,
                  decoration: BoxDecoration(
                      color: scheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999))),
            ),
            const SizedBox(height: 14),
            Text('Compartir Pago Móvil',
                style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 17,
                    fontWeight: FontWeight.w700)),
            const SizedBox(height: 10),
            ReadWindow(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              semanticLabel: 'Monto a cobrar',
              child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                AnimatedNumber(widget.amountVes,
                    style: VeText.displayNum(34, color: scheme.onSurface),
                    decimals: convDecimals(widget.amountVes, Currency.ves)),
                Text('Monto a cobrar',
                    style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
              ]),
            ),
            const SizedBox(height: 12),
            if (accounts.length > 1)
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  for (int i = 0; i < accounts.length; i++)
                    ChipTag('${accounts[i].bankName} (${accounts[i].bankCode})',
                        selected: i == _sel,
                        onTap: () => setState(() => _sel = i)),
                ],
              ),
            const SizedBox(height: 10),
            if (acc != null)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: scheme.outlineVariant),
                ),
                child: Text(acc.shareText(widget.amountVes),
                    style: const TextStyle(
                        fontSize: 13, height: 1.6)),
              ),
            const SizedBox(height: 8),
            Row(children: [
              Icon(Icons.info_outline, size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text('Compartes tus datos de cobro con quien reciba el mensaje.',
                    style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
              ),
            ]),
            const SizedBox(height: 14),
            if (acc != null)
              Row(children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(text: acc.shareText(widget.amountVes)));
                      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                          content: Text('Copiado'),
                          behavior: SnackBarBehavior.floating));
                    },
                    icon: const Icon(Icons.copy, size: 16),
                    label: const Text('Copiar'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: () async {
                      await SharePlus.instance.share(
                          ShareParams(text: '${acc.shareText(widget.amountVes)}\n\n— ValoraVE'));
                      if (context.mounted) Navigator.pop(context);
                    },
                    icon: const Icon(Icons.ios_share, size: 16),
                    label: const Text('Compartir'),
                  ),
                ),
              ]),
          ]),
        ),
      ),
    );
  }
}
