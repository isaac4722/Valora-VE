/// ─── Conversor · histórico y notas (parte de converter_screen.dart) ────────
/// Recientes + notas persistentes + hoja del calendario histórico (REQ 4).
/// Parte del archivo principal: comparte la privacidad de la biblioteca y
/// sus imports.
part of 'converter_screen.dart';


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
  final ConversionPlan? plan;

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
    this.futureDays,
  });

  /// Días disponibles YYYY-MM-DD al abrir (snapshots locales — REQ 8: nunca
  /// días vacíos). v17.6 FIX: el calendario ya NO depende solo del dispositivo:
  /// [futureDays] trae los días de la serie REMOTA (180 días por fuente,
  /// seriesForSource) y se fusionan en vivo — así un teléfono recién instalado
  /// ve un calendario real, no «no aparece nada».
  final Set<String> days;
  final DateTime? initial;
  final String sourceLabel;

  /// Días remotos en camino (null = no consultar). Se fusionan con [days]
  /// al completar; errores se ignoran (los locales cubren).
  final Future<Set<String>>? futureDays;

  @override
  State<_CalendarioHistorico> createState() => _CalendarioHistoricoState();
}

class _CalendarioHistoricoState extends State<_CalendarioHistorico> {
  late DateTime _month;
  late Set<String> _days;
  bool _remotosPendientes = false;

  @override
  void initState() {
    super.initState();
    _days = {...widget.days};
    _remotosPendientes = widget.futureDays != null;
    final anchor = widget.initial ?? _ultimoDia() ?? DateTime.now();
    _month = DateTime(anchor.year, anchor.month, 1);
    // FIX (v17.6): fusiona los días de la API cuando llegan. Si el equipo
    // apenas se instaló, el calendario pasa de 1-2 días locales a la serie
    // completa sin cerrar ni reabrir la hoja.
    widget.futureDays?.then((extra) {
      if (!mounted) return;
      setState(() {
        _days.addAll(extra);
        _remotosPendientes = false;
      });
    }).catchError((_) {
      if (!mounted) return;
      setState(() => _remotosPendientes = false);
    });
  }

  DateTime? _ultimoDia() {
    if (_days.isEmpty) return null;
    final last = _days.reduce((a, b) => a.compareTo(b) >= 0 ? a : b);
    final d = DateTime.parse(last);
    return DateTime(d.year, d.month, 1);
  }

  DateTime? get _minMonth {
    if (_days.isEmpty) return null;
    final first = _days.reduce((a, b) => a.compareTo(b) <= 0 ? a : b);
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
          if (_days.isEmpty && _remotosPendientes)
            // FIX (v17.6): mientras la API responde NUNCA se muestra un
            // calendario vacío — estado de carga explícito.
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 28),
              child: Column(children: [
                SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4)),
                SizedBox(height: 12),
                Text('Consultando los días disponibles…',
                    style: TextStyle(fontSize: 12.5)),
              ]),
            )
          else if (_days.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: EmptyState(
                'Aún no hay fechas guardadas',
                icon: Icons.calendar_month,
                hint: 'Sin conexión y sin snapshots locales todavía. La app '
                    'guarda un snapshot por día cada vez que se refrescan '
                    'las tasas; con internet este calendario llena sus 180 '
                    'días al instante.',
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
              _remotosPendientes
                  ? 'Llegando más días desde la API…'
                  : 'Los días sombreados vienen de la API y de tus '
                      'snapshots guardados.',
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
    final disponible = _days.contains(key);
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
