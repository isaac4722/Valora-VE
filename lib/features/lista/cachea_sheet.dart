/// ─── Hoja «Modo Cachea» (v27.3) ─────────────────────────────────────────────
/// Simulador de compra con inicial + cuotas quincenales sin intereses. Es un
/// cálculo de la Lista, no un método de pago: no se procesa ni se cobra nada.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/cachea.dart';
import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';

Future<void> showCacheaSheet(
  BuildContext context, {
  required WidgetRef ref,
  required double totalInCalc,
  required Currency calcCur,
  required double totalUsd,
  required RateContext ctx,
}) {
  return showVeSheet<void>(
    context: context,
    title: 'Modo Cachea',
    builder: (_) => _CacheaSheet(
      totalInCalc: totalInCalc,
      calcCur: calcCur,
      totalUsd: totalUsd,
      ctx: ctx,
    ),
  );
}

class _CacheaSheet extends ConsumerStatefulWidget {
  const _CacheaSheet({
    required this.totalInCalc,
    required this.calcCur,
    required this.totalUsd,
    required this.ctx,
  });

  final double totalInCalc;
  final Currency calcCur;
  final double totalUsd;
  final RateContext ctx;

  @override
  ConsumerState<_CacheaSheet> createState() => _CacheaSheetState();
}

class _CacheaSheetState extends ConsumerState<_CacheaSheet> {
  int _initialPct = 40;
  int _quotas = 3;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);
    final quote = cacheaQuote(
      total: widget.totalInCalc,
      initialPct: _initialPct,
      quotas: _quotas,
    );
    if (quote == null) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Text(
          'Agrega productos a la lista para simular una compra.',
          style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
        ),
      );
    }

    final double uCalc = widget.ctx.unitsPerUSD(widget.calcCur) ?? 0;
    final double uVes = widget.ctx.unitsPerUSD(Currency.ves) ?? 0;
    final double initialUsd = widget.totalUsd * _initialPct / 100;
    final double quotaUsd = (widget.totalUsd - initialUsd) / _quotas;
    final double initialCalc = initialUsd * uCalc;
    final double quotaCalc = quotaUsd * uCalc;
    final double totalBs = widget.totalUsd * uVes;
    final bool hasCalc = uCalc > 0;
    final bool hasBs = uVes > 0;

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Simula una compra con inicial y cuotas quincenales sin '
            'intereses. Solo cálculo: no se procesa ningún pago.',
            style: TextStyle(
              fontSize: 12,
              height: 1.4,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'TOTAL DE LA COMPRA',
            style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            hasCalc
                ? fmtMoney(widget.totalInCalc, widget.calcCur)
                : fmtUSD(widget.totalUsd),
            style: VeText.displayNum(
              30,
              color: scheme.onSurface,
              weight: FontWeight.w700,
            ),
          ),
          if (widget.calcCur != Currency.usd && widget.totalUsd > 0)
            Text(
              '≈ ${fmtUSD(widget.totalUsd)}'
              '${widget.calcCur != Currency.ves && hasBs ? ' · ${fmtMoney(totalBs, Currency.ves)}' : ''}',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          const SizedBox(height: 12),
          Text(
            'PAGO INICIAL',
            style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final p in kCacheaInitials)
                VeChip(
                  active: _initialPct == p,
                  onTap: () => setState(() => _initialPct = p),
                  child: Text('$p %'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'CUOTAS QUINCENALES',
            style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              for (final q in kCacheaQuotas)
                VeChip(
                  active: _quotas == q,
                  onTap: () => setState(() => _quotas = q),
                  child: Text('$q'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: scheme.surface,
              border: Border.all(color: scheme.outlineVariant),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Inicial',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasCalc
                                ? fmtMoney(initialCalc, widget.calcCur)
                                : fmtUSD(initialUsd),
                            style: VeText.displayNum(
                              22,
                              color: scheme.onSurface,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '$_quotas cuotas de',
                            style: TextStyle(
                              fontSize: 10.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            hasCalc
                                ? fmtMoney(quotaCalc, widget.calcCur)
                                : fmtUSD(quotaUsd),
                            style: VeText.displayNum(
                              22,
                              color: ink.pos,
                              weight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                if (hasBs && widget.calcCur != Currency.ves) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Inicial ≈ ${fmtMoney(initialUsd * uVes, Currency.ves)} · '
                    'cuota ≈ ${fmtMoney(quotaUsd * uVes, Currency.ves)}',
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
                const SizedBox(height: 10),
                Text(
                  'Total a pagar: ${hasCalc ? fmtMoney(widget.totalInCalc, widget.calcCur) : fmtUSD(widget.totalUsd)}'
                  ' · ${quote.payments} pagos · 0 % interés',
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(LucideIcons.info, size: 13, color: scheme.onSurfaceVariant),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Cashea es una marca de terceros. Simulación informativa; '
                  'no garantiza aprobación.',
                  style: TextStyle(
                    fontSize: 10,
                    height: 1.35,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
