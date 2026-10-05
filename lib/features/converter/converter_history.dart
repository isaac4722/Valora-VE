/// ─── Conversor · histórico y notas (parte de converter_screen.dart) ────────
/// Recientes + notas persistentes + hoja del calendario histórico (REQ 4).
/// Parte del archivo principal: comparte la privacidad de la biblioteca y
/// sus imports.
part of 'converter_screen.dart';

class _Recientes extends StatefulWidget {
  const _Recientes({
    required this.from,
    required this.to,
    required this.amount,
    required this.result,
    required this.plan,
    this.onRestore,
  });
  final Currency from, to;
  final double amount;
  final double result;
  final ConversionPlan? plan;

  /// Toca una conversión guardada → restaura par y monto (prototipo).
  final void Function(RecentConversion r)? onRestore;

  @override
  State<_Recientes> createState() => _RecientesState();
}

class _RecientesState extends State<_Recientes> {
  String? _lastPushedKey;

  @override
  void didUpdateWidget(covariant _Recientes oldWidget) {
    super.didUpdateWidget(oldWidget);
    _tryPush();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _tryPush();
  }

  void _tryPush() {
    if (widget.result <= 0 || widget.plan == null || widget.amount <= 0) return;
    // PERF: evita push duplicado en cada rebuild/frame
    final key = '${widget.amount}_${widget.from.code}_${widget.to.code}';
    if (_lastPushedKey == key) return;
    _lastPushedKey = key;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<AppStore>().pushRecentConversion(
            widget.amount,
            widget.from,
            widget.to,
          );
    });
  }

  @override
  Widget build(BuildContext context) {
    // PERF: Selector -> solo rebuild si cambia la lista de recientes
    final recents = context.select<AppStore, List<RecentConversion>>(
      (s) => s.readRecentConversions(),
    );

    if (recents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionEyebrow(
          'Recientes',
          actionLabel: 'Vaciar',
          onAction: context.read<AppStore>().clearRecentConversions,
        ),
        VeGroup(
          children: [
            for (final r in recents.take(10))
              VeRow(
                key: ValueKey('${r.from}_${r.to}_${r.at.millisecondsSinceEpoch}'),
                onTap: widget.onRestore == null ? null : () => widget.onRestore!(r),
                label: Row(
                  children: [
                    Flag(CurrencyX.from(r.from), size: 15),
                    const SizedBox(width: 6),
                    Flexible(
                      child: VeNum(
                        fmtNum(r.amount, decimals: 2),
                        style: const TextStyle(fontSize: 12.5),
                      ),
                    ),
                    const SizedBox(width: 4),
                    Icon(
                      LucideIcons.arrowRight,
                      size: 12,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 4),
                    Flag(CurrencyX.from(r.to), size: 15),
                  ],
                ),
                right: Text('${r.from} → ${r.to} · ${fmtDate(r.at)}'),
                showChevron: true,
              ),
          ],
        ),
      ],
    );
  }
}

class _Notas extends StatelessWidget {
  const _Notas({required this.ctrl});
  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionEyebrow(
          'Notas',
          actionLabel: 'Limpiar',
          onAction: () {
            ctrl.clear();
            context.read<AppStore>().writeConversionNotes('');
          },
        ),
        RepaintBoundary(
          child: VeCard(
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
      ],
    );
  }
}

/// REQ 4 — Calendario histórico REAL: rejilla mensual con los días que
/// tienen snapshot guardado para las fuentes del par. Solo esos días son
/// tocables; hoy lleva borde; el día elegido va relleno.
class _CalendarioHistorico extends StatefulWidget {
  const _CalendarioHistorico({
    required this.days,
    required this.sourceLabel,
    this.initial,
    this.futureDays,
  });

  final Set<String> days;
  final DateTime? initial;
  final String sourceLabel;
  final Future<Set<String>>? futureDays;

  @override
  State<_CalendarioHistorico> createState() => _CalendarioHistoricoState();
}

class _CalendarioHistoricoState extends State<_CalendarioHistorico> {
  late DateTime _month;
  late Set<String> _days;
  bool _remotosPendientes = false;
  // PERF: cache para no hacer DateTime.parse() 30+ veces por build
  final Map<String, DateTime> _parsedCache = {};

  DateTime _parseCached(String day) =>
      _parsedCache.putIfAbsent(day, () => DateTime.parse(day));

  @override
  void initState() {
    super.initState();
    _days = {...widget.days};
    _remotosPendientes = widget.futureDays != null;
    final anchor = widget.initial ?? _ultimoDia() ?? DateTime.now();
    _month = DateTime(anchor.year, anchor.month, 1);
    _loadRemotos();
  }

  @override
  void didUpdateWidget(covariant _CalendarioHistorico oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.days != widget.days) {
      _days = {...widget.days};
      _parsedCache.clear();
    }
  }

  Future<void> _loadRemotos() async {
    if (widget.futureDays == null) return;
    try {
      final extra = await widget.futureDays!;
      if (!mounted) return;
      setState(() {
        _days.addAll(extra);
        _remotosPendientes = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() => _remotosPendientes = false);
    }
  }

  DateTime? _ultimoDia() {
    if (_days.isEmpty) return null;
    final last = _days.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    final d = _parseCached(last);
    return DateTime(d.year, d.month, 1);
  }

  DateTime? get _minMonth {
    if (_days.isEmpty) return null;
    final first = _days.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
    final d = _parseCached(first);
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
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Elegir fecha histórica',
              style: TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 15,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              'Fuentes: ${widget.sourceLabel}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (_days.isEmpty && _remotosPendientes)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 28),
                child: Column(
                  children: [
                    SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.4),
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Consultando los días disponibles…',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ],
                ),
              )
            else if (_days.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: VeEmpty(
                  icon: LucideIcons.calendar,
                  title: 'Aún no hay fechas guardadas',
                  sub:
                      'Sin conexión y sin snapshots locales todavía. La app '
                      'guarda un snapshot por día cada vez que se refrescan '
                      'las tasas; con internet este calendario llena sus 180 '
                      'días al instante.',
                ),
              )
            else ...[
              Row(
                children: [
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
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: puedeNext ? () => _mover(1) : null,
                    icon: const Icon(Icons.chevron_right, size: 20),
                    tooltip: 'Mes siguiente',
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  for (final d in const ['L', 'M', 'X', 'J', 'V', 'S', 'D'])
                    Expanded(
                      child: Center(
                        child: Text(
                          d,
                          style: VeText.labelCaps(
                            9.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(height: 4),
              RepaintBoundary(
                child: Column(children: _semanas(scheme)),
              ),
              const SizedBox(height: 10),
              Text(
                _remotosPendientes
                    ? 'Llegando más días desde la API…'
                    : 'Los días sombreados vienen de la API y de tus '
                          'snapshots guardados.',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }

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
        Row(
          children: [
            for (var i = 0; i < 7; i++)
              Expanded(child: _celda(celdas[w * 7 + i], scheme)),
          ],
        ),
    ];
  }

  Widget _celda(int? day, ColorScheme scheme) {
    if (day == null) return const SizedBox(height: 42);
    final date = DateTime(_month.year, _month.month, day);
    final key = SnapshotPoint.dayKey(date);
    final disponible = _days.contains(key);
    final esHoy = key == SnapshotPoint.dayKey(DateTime.now());
    final elegido =
        widget.initial != null && SnapshotPoint.dayKey(widget.initial!) == key;
    final fondo = elegido
        ? scheme.primary
        : disponible
            ? scheme.primary.withValues(alpha: 0.08)
            : Colors.transparent;
    final tinta = elegido
        ? scheme.onPrimary
        : disponible
            ? scheme.onSurface
            : scheme.onSurfaceVariant.withValues(alpha: 0.55);
    return SizedBox(
      height: 42,
      child: Padding(
        padding: const EdgeInsets.all(2),
        child: Material(
          color: fondo,
          borderRadius: BorderRadius.circular(10),
          child: InkWell(
            borderRadius: BorderRadius.circular(10),
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
                child: Text(
                  '$day',
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: elegido || esHoy ? FontWeight.w800 : FontWeight.w600,
                    color: tinta,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
