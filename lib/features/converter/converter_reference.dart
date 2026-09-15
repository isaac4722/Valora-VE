/// ─── Conversor · referencia del par (parte de converter_screen.dart) ───────
/// Ruta del cálculo + todas las fuentes del par + tabla de montos + matriz
/// 6×6 (dp6). Parte del archivo principal: comparte la privacidad de la
/// biblioteca y sus imports.
part of 'converter_screen.dart';

/// Ruta del cálculo legible (arista directa · puente EUR · vía dólar).
/// La ruta del puente EUR se pinta COMPLETA (4 tramos: EUR → local → USD →
/// destino) con las fuentes usadas en cada tramo — nunca colapsada.
class _RutaCalculo extends StatelessWidget {
  const _RutaCalculo({required this.plan});
  final ConversionPlan? plan;

  /// Etiqueta del tipo de ruta (§1.11 del web): «Tasa directa» solo con
  /// arista directa; el puente EUR se declara a la vista.
  String _kindLabel(ConversionPlan p) {
    if (p.direct) return 'Tasa directa';
    if (p.path.contains(Currency.eur) &&
        (p.path.first == Currency.eur || p.path.last == Currency.eur)) {
      return 'Puente EUR visible';
    }
    return 'Vía dólar';
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    if (plan == null) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Ruta del cálculo'),
          Text(
            'Sin tasa disponible para este par. Revisa tus fuentes en '
            'Ajustes → Monedas y tasas, o pega una tasa manual.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
      );
    }
    final p = plan!;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Ruta del cálculo'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _kindLabel(p).toUpperCase(),
                  style: VeText.labelCaps(9.5, color: scheme.primary),
                ),
                const SizedBox(height: 7),
                Wrap(
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    for (int i = 0; i < p.path.length; i++) ...[
                      if (i > 0) ...[
                        Icon(
                          Icons.arrow_forward,
                          size: 13,
                          color: scheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 6),
                      ],
                      Flag(p.path[i], size: 16),
                      const SizedBox(width: 4),
                      Text(
                        p.path[i].code,
                        style: const TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      const SizedBox(width: 4),
                    ],
                  ],
                ),
                if (p.sourceIds.isNotEmpty) ...[
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final id in p.sourceIds)
                        if (id.isNotEmpty)
                          Stamp(
                            convSourceNames[id] ??
                                RateSource.of(id)?.label ??
                                id,
                            color: scheme.primary,
                          ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
      ],
    );
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
    for (final s in [
      ...RateSource.sourcesFor(from),
      ...RateSource.sourcesFor(to),
    ]) {
      if (!ids.contains(s.id)) ids.add(s.id);
    }
    // v19.0 (orden del dueño): USD no aporta fuentes — 1 USD = 1 USD es
    // obvio en el mismo contexto. Con USD en el par se listan las fuentes de
    // la OTRA divisa; si no hay nada, la sección desaparece.
    if (ids.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Referencia de fuentes'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final id in ids)
                  if (RateSource.of(id) != null)
                    _fila(context, scheme, RateSource.of(id)!),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _fila(BuildContext context, ColorScheme scheme, RateSource s) {
    final activa = ctx.sel(s.currency) == s.id;
    final r = ctx.rate(s.id);
    final row = Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SourceSeal(s.category),
          const SizedBox(width: 9),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.currency.code} ${s.label}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: activa ? FontWeight.w800 : FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                Text(
                  s.detail,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            r > 0 ? fmtRate(r) : '—',
            style: VeText.displayNum(13.5, color: scheme.onSurface),
          ),
          Text(
            ' ${s.quote.code}',
            style: TextStyle(
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(width: 8),
          if (activa)
            Icon(Icons.check_circle, size: 15, color: scheme.primary)
          else
            const SizedBox(width: 15),
        ],
      ),
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
  const _TablaMontos({
    required this.ctx,
    required this.amount,
    required this.from,
  });
  final RateContext ctx;
  final double amount;
  final Currency from;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final amounts = quickAmounts[from] ?? const <double>[];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Montos de referencia'),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final a in amounts)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        Text(
                          fmtMoney(a, from),
                          style: VeText.displayNum(
                            13.5,
                            color: scheme.onSurface,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          fmtCurrency(
                            ctx.convert(a, from, Currency.ves),
                            Currency.ves,
                          ),
                          style: TextStyle(
                            fontSize: 12.5,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Matriz 6×6 plegable (dp6 · mejora 9): las 6 divisas del foco cruzadas con
/// la tasa vigente de cada una (1 A = X B vía el plan activo). Celdas sin
/// ruta honestas («—»), scroll horizontal y plegada por defecto para no
/// robar altura al conversor.
class _Matriz6 extends StatefulWidget {
  const _Matriz6({required this.ctx});
  final RateContext ctx;

  @override
  State<_Matriz6> createState() => _Matriz6State();
}

class _Matriz6State extends State<_Matriz6> {
  bool _open = false;
  final ScrollController _scroll = ScrollController();

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final focus = CurrencyX.focus;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: SectionTitle('Tabla de referencia 6×6')),
            Switch(
              value: _open,
              onChanged: (v) => setState(() => _open = v),
              materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
          ],
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: _open
                ? Scrollbar(
                    controller: _scroll,
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      controller: _scroll,
                      scrollDirection: Axis.horizontal,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              const SizedBox(width: 42),
                              for (final c in focus)
                                SizedBox(
                                  width: 58,
                                  child: Column(
                                    children: [
                                      Flag(c, size: 13),
                                      const SizedBox(height: 2),
                                      Text(
                                        c.code,
                                        style: TextStyle(
                                          fontSize: 8.5,
                                          fontWeight: FontWeight.w700,
                                          letterSpacing: 0.6,
                                          color: scheme.onSurfaceVariant,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          for (final r in focus)
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 2),
                              child: Row(
                                children: [
                                  SizedBox(
                                    width: 42,
                                    child: Center(child: Flag(r, size: 15)),
                                  ),
                                  for (final c in focus)
                                    SizedBox(
                                      width: 58,
                                      child: Center(
                                        child: r == c
                                            ? Text(
                                                '·',
                                                style: TextStyle(
                                                  fontSize: 12,
                                                  color:
                                                      scheme.onSurfaceVariant,
                                                ),
                                              )
                                            : () {
                                                final rate = widget.ctx.convert(
                                                  1,
                                                  r,
                                                  c,
                                                );
                                                return rate > 0
                                                    ? Text(
                                                        fmtRate(rate),
                                                        style:
                                                            VeText.displayNum(
                                                              10,
                                                              weight: FontWeight
                                                                  .w600,
                                                              color: scheme
                                                                  .onSurface,
                                                            ),
                                                      )
                                                    : Text(
                                                        '—',
                                                        style: TextStyle(
                                                          fontSize: 10,
                                                          color: scheme
                                                              .onSurfaceVariant,
                                                        ),
                                                      );
                                              }(),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  )
                : Text(
                    'Enciende la tabla para cruzar las 6 divisas del foco con la tasa vigente de cada una.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
