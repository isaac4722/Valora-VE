/// ─── Conversor (§9.2 · MODULE=converter) ───────────────────────────────────
/// Monto dual from/to con swap y odómetros · fecha de tasas (Hoy/Ayer/Hace
/// 7d + histórica honesta: sin dato → sin dato, nunca fabrica) · ajustes
/// rápidos · comparación de fuentes · ruta del cálculo · recientes (10) ·
/// notas (5000) · tabla de referencia · compartir.
library;

import 'package:flutter/material.dart';
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
  String _dateMode = 'today'; // today | yesterday | week | custom
  DateTime? _customDate;
  Map<String, double>? _historicRates; // tasas históricas (sourceId → rate)
  bool _historicLoading = false;
  final _notesCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    final store = context.read<AppStore>();
    _notesCtrl.text = store.readConversionNotes();
    _notesCtrl.addListener(() {
      store.writeConversionNotes(_notesCtrl.text);
    });
  }

  @override
  void dispose() {
    _amountCtrl.dispose();
    _notesCtrl.dispose();
    super.dispose();
  }

  void _applyRateContext() {
    setState(() {
      _historicRates = null;
      if (_dateMode == 'custom' && _customDate != null) {
        _historicLoading = true;
        _loadCustom();
      }
    });
  }

  Future<void> _loadCustom() async {
    final store = context.read<AppStore>();
    final date = SnapshotPoint.dayKey(_customDate!);
    final rates = <String, double>{};
    for (final id in ['ves-bcv', 'ves-parallel', 'eur-ves-oficial', 'cop-trm', 'brl-br', 'mxn-banxico']) {
      try {
        final point = await rateOn(id, date, localFallback: (sourceId, day) {
          final local = store.snapshots.where((p) => p.sourceId == sourceId && p.day == day).toList()
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

  /// Contexto efectivo: vivo o histórico (fecha seleccionada).
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

    double result = 0;
    if (plan != null && _amount > 0) result = _amount * plan.rate;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const PageHeader('Conversor', hint: 'Puente USD · EUR visible · ruta honesta'),
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
                  onAmount: (v) => setState(() => _amount = v),
                  onSwap: () => store.setConverterPair(to.code, from.code),
                  onFrom: (c) => store.setConverterPair(c.code, to.code),
                  onTo: (c) => store.setConverterPair(from.code, c.code),
                ),
                _RutaCalculo(plan: plan),
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
              Expanded(
                child: Text('Imagen 1080 px con ruta y fuentes.',
                    style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
              ),
            ]),
          ),
          _QuickAdjustments(
            amount: _amount,
            onAdjust: (v) {
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
          _Recientes(from: from, to: to, result: result, plan: plan),
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
    required this.onAmount,
    required this.onSwap,
    required this.onFrom,
    required this.onTo,
  });

  final TextEditingController amountCtrl;
  final Currency from, to;
  final double result;
  final ({double rate, List<Currency> path, List<String> sourceIds})? plan;
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
                style: VeText.displayNum(22, color: scheme.onSurface),
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
                    style: VeText.displayNum(22, color: scheme.onSurface),
                    decimals: smartDecimals(result, to),
                  ),
                  Text(fmtCurrency(result, to),
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

class _QuickAdjustments extends StatelessWidget {
  const _QuickAdjustments({required this.amount, required this.onAdjust});

  final double amount;
  final ValueChanged<double> onAdjust;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(children: [
        for (final adj in quickAdjustments)
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChipTag(adj.label, onTap: () => onAdjust(adj.apply(amount))),
          ),
      ]),
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
      if (mode == 'custom') ...[
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
    final p = ctx.plan(from, to);
    final sources = p == null ? const <String>[] : p.sourceIds;
    if (sources.isEmpty) return const SizedBox.shrink();

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
  const _Recientes({required this.from, required this.to, required this.result, required this.plan});
  final Currency from, to;
  final double result;
  final ({double rate, List<Currency> path, List<String> sourceIds})? plan;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final recents = store.readRecentConversions();

    // Registra la conversión actual (dedupe <60s dentro del store).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (result > 0 && plan != null) {
        store.pushRecentConversion(store.data.converter.from.isEmpty ? 1 : 1, from, to);
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
