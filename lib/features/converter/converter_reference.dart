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
          _SectionEyebrow('Ruta del cálculo'),
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
        _SectionEyebrow('Ruta del cálculo'),
        VeCard(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _kindLabel(p).toUpperCase(),
                style: VeText.labelCaps(10.5, color: scheme.primary),
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
                        VeBadge(
                          child: Text(
                            (convSourceNames[id] ??
                                    RateSource.of(id)?.label ??
                                    id)
                                .toUpperCase(),
                          ),
                        ),
                  ],
                ),
              ],
            ],
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
    final scheme = Theme.of(context).colorScheme;
    final activa = ctx.sel(s.currency) == s.id;
    final r = ctx.rate(s.id);
    return VeRow(
      onTap: () => onPick(s.currency, s.id),
      label: Text(
        '${s.currency.code} ${s.label}',
        style: activa
            ? TextStyle(fontWeight: FontWeight.w700, color: scheme.onSurface)
            : TextStyle(color: scheme.onSurface),
      ),
      sub: Text(s.detail),
      right: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          VeNum(
            r > 0 ? fmtRate(r) : '—',
            style: TextStyle(
              fontSize: 13.5,
              fontWeight: activa ? FontWeight.w700 : FontWeight.w500,
              color: scheme.onSurface,
            ),
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
            Icon(LucideIcons.check, size: 15, color: scheme.primary)
          else
            const SizedBox(width: 15),
        ],
      ),
      showChevron: false,
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
        _SectionEyebrow(
          'Tabla de referencia 6×6',
          actionLabel: _open ? 'Ocultar' : 'Mostrar',
          onAction: () => setState(() => _open = !_open),
        ),
        VeCard(
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
                                    // labelCaps aplica el piso de
                                    // legibilidad de 9.5 px (antes 8.5
                                    // crudos, bajo el mínimo del sistema).
                                    Text(
                                      c.code,
                                      style: VeText.labelCaps(
                                        9.5,
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
                                                color: scheme.onSurfaceVariant,
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
                                                      style: VeText.displayNum(
                                                        10,
                                                        weight: FontWeight.w600,
                                                        color: scheme.onSurface,
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
                  'Toca «Mostrar» para cruzar las 6 divisas del foco con la '
                  'tasa vigente de cada una.',
                  style: TextStyle(
                    fontSize: 11.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
        ),
      ],
    );
  }
}
