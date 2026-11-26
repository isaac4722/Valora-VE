/// ─── Conversor · hoja del calendario histórico (parte de converter_screen)
/// v29 (H-28): Fuentes · Tabla · Recientes · Notas ya no viven en hojas del
/// Conversor — las fuentes se eligen en el selector de tasa (H-24) y la hoja
/// compartida de rate_sheet.dart; la tabla y los recientes eran repeticiones
/// de «Tasas» y «Historial»; las notas quedaron INLINE bajo el resultado.
/// Queda el calendario del segmento «Fecha» (H-22): la rejilla mensual con
/// los días que tienen snapshot REAL guardado para las fuentes del par.
/// Parte del archivo principal: comparte la privacidad de la biblioteca y
/// sus imports.
part of 'converter_screen.dart';

/// REQ 4 — Calendario histórico REAL: rejilla mensual con los días que
/// tienen snapshot guardado para las fuentes del par. Solo esos días son
/// tocables; hoy lleva borde; el día elegido va relleno.
class _CalendarioHistorico extends ConsumerStatefulWidget {
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
  ConsumerState<_CalendarioHistorico> createState() =>
      _CalendarioHistoricoState();
}

class _CalendarioHistoricoState extends ConsumerState<_CalendarioHistorico> {
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

    // v23.3: sin scroll interno NI SafeArea — el chrome de la hoja ya pone
    // ambos (un scrollable anidado robaría el gesto de arrastre de la hoja).
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // v23.3 (pez 2-a P0-1): el título vive en la cabecera del chrome
        // de la hoja (antes se repetía aquí en SpaceGrotesk 15 w800).
        FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
          'Fuentes: ${widget.sourceLabel}',
          maxLines: 1,
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        )),
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
                Text('Consultando días…', style: TextStyle(fontSize: 13.5)),
              ],
            ),
          )
        else if (_days.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: VeEmpty(
              icon: LucideIcons.calendar,
              title: 'Aún no hay fechas guardadas',
              sub: 'Se llena sola: un snapshot por día al refrescar tasas.',
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
                        11,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          RepaintBoundary(child: Column(children: _semanas(scheme))),
          const SizedBox(height: 10),
          Text(
            _remotosPendientes
                ? 'Llegando más días desde la API…'
                : 'Días sombreados: API + tus snapshots guardados.',
            style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
          ),
        ],
      ],
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
        ? (esHoy ? scheme.primary : scheme.onSurface)
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
              // v25 «HOJA»: «hoy» se marca con TINTA (número en primario,
              // w800) — sin anillo de borde alrededor del día.
              child: Text(
                '$day',
                style: TextStyle(
                  fontSize: 13.5,
                  fontWeight: elegido || esHoy
                      ? FontWeight.w800
                      : FontWeight.w600,
                  color: tinta,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
