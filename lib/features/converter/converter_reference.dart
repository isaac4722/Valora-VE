/// ─── Conversor · referencia del par (parte de converter_screen.dart) ───────
/// Ruta del cálculo + todas las fuentes del par + tabla de montos + matriz
/// 6×6 (dp6). Parte del archivo principal: comparte la privacidad de la
/// biblioteca y sus imports.
part of 'converter_screen.dart';

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

/// Ruta del cálculo — ELIMINADA (v20 · orden del dueño): «no creo que sea
/// informativamente útil o necesaria… vamos a reducir y mejorar la
/// estructura». La fuente activa sigue visible en la línea superior del
/// card del par y en Referencia de fuentes.

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
        _SectionEyebrow('Referencia de fuentes'),
        // Filas divididas del prototipo (Group+Row): tocar una fila la usa
        // como fuente (mismo camino del selector de chips).
        VeGroup(
          children: [
            for (final id in ids)
              if (RateSource.of(id) != null) _fila(context, RateSource.of(id)!),
          ],
        ),
      ],
    );
  }

  Widget _fila(BuildContext context, RateSource s) {
    final r = ctx.rate(s.id);
    final store = context.watch<AppStore>();
    // v20 (orden del dueño): la referencia de fuentes usa el MISMO tile
    // visual de tasas de toda la app — fondo del color de categoría,
    // sello con icono, precio en tinta y check en la activa. Antes eran
    // filas planas sin color ni identificación.
    return RateTile(
      sourceId: s.id,
      rate: r,
      selected: ctx.sel(s.currency) == s.id,
      freshness: store.board.sources[s.id] == null
          ? null
          : timeAgo(store.board.sources[s.id]!.updatedAt),
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

    // Tabla de equivalencias (USD · BCV · Paralelo · Dif) SOLO con datos
    // reales de ambas fuentes; el resto de pares mantiene la versión de
    // siempre (monto → Bs con la fuente activa).
    final bcv = ctx.rate('ves-bcv');
    final par = ctx.rate('ves-parallel');
    final dual = from == Currency.usd && bcv > 0 && par > 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionEyebrow('Montos de referencia'),
        if (dual)
          VeGroup(
            children: [
              // Encabezado de columnas del prototipo (fondo subtle + caps).
              Container(
                padding: const EdgeInsets.fromLTRB(14, 7, 14, 7),
                color: scheme.onSurfaceVariant.withValues(alpha: 0.06),
                child: Row(
                  children: [
                    for (final (i, h) in const [
                      'USD',
                      'BCV',
                      'Paralelo',
                      'Dif.',
                    ].indexed)
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
                InkWell(
                  onTap: onAmount == null ? null : () => onAmount!(a),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 9,
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: VeNum(
                            '\$${fmtNum(a, decimals: 0)}',
                            style: const TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: VeNum(
                              fmtNum(a * bcv, decimals: 0),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: VeNum(
                              fmtNum(a * par, decimals: 0),
                              style: const TextStyle(fontSize: 12.5),
                            ),
                          ),
                        ),
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerRight,
                            child: VeNum(
                              '${a * (par - bcv) >= 0 ? '+' : '−'}'
                              '${fmtNum((a * (par - bcv)).abs(), decimals: 0)}',
                              style: TextStyle(fontSize: 12.5, color: ink.warn),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          )
        else
          VeGroup(
            children: [
              for (final a in amounts)
                VeRow(
                  onTap: onAmount == null ? null : () => onAmount!(a),
                  label: VeNum(
                    fmtMoney(a, from),
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  right: Text(
                    fmtCurrency(
                      ctx.convert(a, from, Currency.ves),
                      Currency.ves,
                    ),
                  ),
                ),
            ],
          ),
      ],
    );
  }
}

/// Matriz 6×6 — ELIMINADA (v20 · orden del dueño): «la tabla de referencia
/// por 6 no creo que sea necesaria y es un poco más confusa de lo que en
/// realidad puede ser útil». El par activo se convierte en el card
/// principal; los demás pares viven en Recientes y en la hoja de monedas.
