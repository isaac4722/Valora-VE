/// ─── Conversor · referencia del par (parte de converter_screen.dart) ───────
/// Ruta del cálculo + todas las fuentes del par + tabla de montos + matriz
/// 6×6 (dp6). Parte del archivo principal: comparte la privacidad de la
/// biblioteca y sus imports.
part of \'converter_screen.dart\';

/// Encabezado de sección en el lenguaje del prototipo (TASK-34 · p6):
/// eyebrow caps 10.5 px con la acción de texto a la derecha. Reemplaza a
/// [SectionTitle] en el conversor conservando el texto en MAYÚSCULAS que
/// los tests y el tour esperan ver.
class _SectionEyebrow extends StatelessWidget {
  const _SectionEyebrow(this.title, {this.actionLabel, this.onAction});

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return VeEyebrow(
      right: (actionLabel == null || onAction == null)
          ? null
          : VeBtn(
              variant: VeBtnVariant.ghost,
              size: VeBtnSize.sm,
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
      child: Text(title.toUpperCase()),
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

  List<RateSource> _buildSources() {
    // PERF: deduplica sin contains() O(n²) y sin doble RateSource.of()
    final seen = <String>{};
    final out = <RateSource>[];
    for (final s in [...RateSource.sourcesFor(from), ...RateSource.sourcesFor(to)]) {
      if (seen.add(s.id)) out.add(s);
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final sources = _buildSources();
    // v19.0 (orden del dueño): USD no aporta fuentes
    if (sources.isEmpty) return const SizedBox.shrink();

    // PERF: un solo select para todas las frescuras, no un watch por fila
    final freshnessMap = context.select<AppStore, Map<String, String?>>((s) {
      return {for (final src in sources) src.id: s.board.sources[src.id] == null ? null : timeAgo(s.board.sources[src.id]!.updatedAt)};
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionEyebrow(\'Referencia de fuentes\'),
        RepaintBoundary(
          child: VeGroup(
            children: [
              for (final s in sources)
                _fila(s, freshnessMap[s.id]),
            ],
          ),
        ),
      ],
    );
  }

  Widget _fila(RateSource s, String? freshness) {
    final r = ctx.rate(s.id);
    return RateTile(
      key: ValueKey(s.id),
      sourceId: s.id,
      rate: r,
      selected: ctx.sel(s.currency) == s.id,
      freshness: freshness,
      onTap: () => onPick(s.currency, s.id),
    );
  }
}

/// Montos de referencia: el monto y sus múltiplos (planForTable del web).
/// Cuando el par es USD→VES y existen ambas tasas reales, sube a la tabla
/// de equivalencias del prototipo: 4 columnas (USD · BCV · Paralelo · Dif)
/// con la diferencia en tinta warn; tocar una fila pega ese monto arriba.
class _TablaMontos extends StatelessWidget {
  const _TablaMontos({
    required this.ctx,
    required this.amount,
    required this.from,
    this.onAmount,
  });
  final RateContext ctx;
  final double amount;
  final Currency from;

  /// Toca un monto de la tabla → se convierte en el monto del conversor.
  final ValueChanged<double>? onAmount;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final amounts = quickAmounts[from] ?? const <double>[];
    if (amounts.isEmpty) return const SizedBox.shrink();

    final bcv = ctx.rate(\'ves-bcv\');
    final par = ctx.rate(\'ves-parallel\');
    final dual = from == Currency.usd && bcv > 0 && par > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const _SectionEyebrow(\'Montos de referencia\'),
        if (dual)
          RepaintBoundary(
            child: VeGroup(
              children: [
                Container(
                  padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                  color: scheme.onSurfaceVariant.withValues(alpha: 0.06),
                  child: Row(
                    children: [
                      for (final (i, h) in const [\'USD\', \'BCV\', \'Paralelo\', \'Dif.\'].indexed)
                        Expanded(
                          child: Text(
                            h,
                            textAlign: i == 0 ? TextAlign.left : TextAlign.right,
                            style: TextStyle(
                              fontSize: 10.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.84,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                for (final a in amounts)
                  _DualRow(
                    key: ValueKey(a),
                    amount: a,
                    bcv: bcv,
                    par: par,
                    ink: ink,
                    onTap: onAmount,
                  ),
              ],
            ),
          )
        else
          RepaintBoundary(
            child: VeGroup(
              children: [
                for (final a in amounts)
                  VeRow(
                    key: ValueKey(a),
                    onTap: onAmount == null ? null : () => onAmount!(a),
                    label: VeNum(
                      fmtMoney(a, from),
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                    ),
                    right: Text(fmtCurrency(ctx.convert(a, from, Currency.ves), Currency.ves)),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

// PERF: widget extraído para no crear closures dentro del loop
class _DualRow extends StatelessWidget {
  const _DualRow({
    super.key,
    required this.amount,
    required this.bcv,
    required this.par,
    required this.ink,
    required this.onTap,
  });
  final double amount, bcv, par;
  final VeInk ink;
  final ValueChanged<double>? onTap;

  @override
  Widget build(BuildContext context) {
    final diff = amount * (par - bcv);
    return InkWell(
      onTap: onTap == null ? null : () => onTap!(amount),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
        child: Row(
          children: [
            Expanded(child: VeNum(\'\$${fmtNum(amount, decimals: 0)}\', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
            Expanded(child: Align(alignment: Alignment.centerRight, child: VeNum(fmtNum(amount * bcv, decimals: 0), style: const TextStyle(fontSize: 12.5)))),
            Expanded(child: Align(alignment: Alignment.centerRight, child: VeNum(fmtNum(amount * par, decimals: 0), style: const TextStyle(fontSize: 12.5)))),
            Expanded(child: Align(alignment: Alignment.centerRight, child: VeNum(\'${diff >= 0 ? \'+\' : \'−\'}${fmtNum(diff.abs(), decimals: 0)}\', style: TextStyle(fontSize: 12.5, color: ink.warn)))),
          ],
        ),
      ),
    );
  }
}
