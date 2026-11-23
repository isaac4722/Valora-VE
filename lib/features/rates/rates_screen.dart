/// ─── Tasas (v27) ───────────────────────────────────────────────────────────
/// La cotización completa vive en su propia pantalla: el Inicio solo enseña
/// la tasa protagonista y una salida clara hacia aquí. Mantiene las fuentes
/// del país, las tasas propias con nombre y la edición manual inline.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/rate_history.dart' show snapshotSeries;
import '../../data/store.dart';
import '../../widgets/rate_sheet.dart';
import '../../widgets/ui.dart';
import '../../providers/providers.dart';

class RatesScreen extends ConsumerWidget {
  const RatesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: const [
            _RatesHeader(),
            RatesBoard(),
            SizedBox(height: 18),
            WeekSpark(),
            SizedBox(height: 8),
            _ProvidersLine(),
          ],
        ),
      ),
    );
  }
}

class _RatesHeader extends ConsumerWidget {
  const _RatesHeader();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              VeIconBtn(
                icon: LucideIcons.arrowLeft,
                label: 'Volver',
                onTap: () => context.canPop() ? context.pop() : context.go('/'),
              ),
              const Spacer(),
              VeIconBtn(
                icon: LucideIcons.settings2,
                label: 'Configurar tasas',
                onTap: () => context.push('/ajustes/tasas'),
              ),
            ],
          ),
          Text(
            'Tasas',
            style: VeText.displayNum(
              26,
              color: scheme.onSurface,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Lo que vale tu dinero hoy, según la fuente que elijas.',
            style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _ProvidersLine extends ConsumerWidget {
  const _ProvidersLine();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    final providers = store.board.providers;
    final degraded = store.board.degraded;
    if (providers.isEmpty && degraded.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Text(
        [
          if (providers.isNotEmpty) 'Responden: ${providers.join(' · ')}',
          if (degraded.isNotEmpty) 'Sin respuesta: ${degraded.join(' · ')}',
        ].join('  ·  '),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
      ),
    );
  }
}

class _SectionHeader extends ConsumerWidget {
  const _SectionHeader(this.title, {this.hint});

  final String title;
  final String? hint;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return VeEyebrow(hint: hint, child: Text(title.toUpperCase()));
  }
}

class WeekSpark extends ConsumerWidget {
  const WeekSpark({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    final activeId = store.sourceFor(Currency.ves);
    if (activeId.isEmpty) return const SizedBox.shrink();
    final pts = snapshotSeries(store.snapshots, activeId, 7);
    if (pts.length < 2) return const SizedBox.shrink();
    final values = pts.map((p) => p.rate).toList();
    final ayer = pts[pts.length - 2].rate;
    // Inicial del día de cada snapshot («L», «M», «X»…).
    final labels = [
      for (final p in pts)
        kDias[DateTime.parse(p.day).weekday - 1].substring(0, 1).toUpperCase(),
    ];

    // v25 «HOJA»: directo al papel — sin tarjeta contenedora.
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 12, 0, 2),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Últimos 7 días',
                  style: VeText.labelCaps(10.5, color: scheme.onSurfaceVariant),
                ),
              ),
              Text(
                'Ayer ',
                style: VeText.labelCaps(10.5, color: scheme.onSurfaceVariant),
              ),
              VeNum(
                fmtRate(ayer),
                style: VeText.displayNum(
                  14,
                  color: scheme.onSurface,
                  weight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          VeBars(
            labels: labels,
            data: values,
            // v24.1: tono pos (verde marca) — las barras en tinta fg
            // (negro) leían como vigas muertas; el color solo significa
            // (§5) y aquí la serie es un dato positivo del tablero.
            tone: VeChartTone.pos,
            height: 96,
            formatValue: fmtRate,
            semantic: 'Tasa de los últimos 7 días, una barra por día',
          ),
        ],
      ),
    );
  }
}

/// ─── Lista de Cotización (v19.0, orden del dueño) ────────────────────────────
/// Agrupada por divisa base: sección USD (BCV · Paralelo · Promedio ·
/// Manual · TRM · Mercado · Brasil · Banxico) y sección EUR (aristas del
/// euro). Cada fila es un RateTile: [Bandera] [Nombre] [Precio + símbolo]
/// con el color de categoría establecido. La fila Manual del país siempre
/// está visible: el lápiz (o el toque, si no hay valor) abre el editor
/// INLINE — la tasa manual se fija desde aquí, sin ir a Ajustes.
class RatesBoard extends ConsumerWidget {
  const RatesBoard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final poller = ref.watch(ratesPollerProvider);
    final scheme = Theme.of(context).colorScheme;
    final country = CountryX.from(store.settings.country);
    final ctx = store.contextOf();
    final manualId = '${country.currency.code.toLowerCase()}-manual';
    final hasAny = !store.board.isEmpty || ctx.rates.containsKey(manualId);
    final customRates = store.data.customRates;
    final hasAnyCustom = hasAny || customRates.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          'Cotización principal',
          hint: 'Tasas de hoy y qué tasa usan tus cálculos',
        ),
        if (!hasAnyCustom)
          if (poller.offlineActive)
            // Desconexión ELEGIDA (modo offline): cloud_off + guía local.
            OfflineState(
              'Modo offline activo',
              hint:
                  'Todo corre en tu teléfono. Pega una tasa o desactiva el modo offline.',
              actionLabel: 'Tasa manual',
              onAction: () => editManualRate(context, ref, store, manualId),
            )
          else if (poller.networkBlocked || poller.offlineNet)
            // Sin red (señal viva v17.8) o red bloqueada SIN datos guardados:
            // wifi_off + salidas reales — NUNCA spinner de 7 s que va a fallar.
            OfflineState(
              'Sin conexión · sin tasas guardadas todavía',
              // v23.3 (pez 2-a P1-2): UNA línea — el claim v23.2 de «offline
              // a una línea» no había llegado a este estado (3 líneas a
              // 390 px). La salida corta conserva el mensaje y las dos
              // salidas reales siguen a un toque.
              hint:
                  'Todo lo demás funciona igual: pega una tasa o espera la red.',
              icon: Icons.wifi_off,
              actionLabel: poller.loading ? 'Consultando…' : 'Reintentar',
              onAction: poller.loading ? null : () => poller.retryNow(),
              secondaryLabel: 'Tasa manual',
              onSecondary: () => editManualRate(context, ref, store, manualId),
            )
          else
            // PRIMERA CARGA: spinner, cero iconografía de red.
            LoadingState(
              'Buscando tasas…',
              hint: 'Primera carga… o pega una tasa manual ya.',
              actionLabel: 'Tasa manual',
              onAction: () => editManualRate(context, ref, store, manualId),
            )
        else
          // v25 «HOJA»: SIN tarjeta contenedora — eyebrow + filas planas con
          // hairlines (filas en tinta, seleccionada sin caja).
          Column(
            children: [
              // ── Grupo USD: todas las fuentes «1 USD = X» ──
              // v20: hint corto — el largo «· toca para activar» se
              // truncaba con feo (VLM gate); tocar es descubrible.
              const RateGroupHeader(Currency.usd, hint: '1 USD = X'),
              ..._withHairlines(
                _groupRows(context, ref, store, ctx, [
                  Currency.ves,
                  Currency.cop,
                  Currency.brl,
                  Currency.mxn,
                ], country.currency),
              ),
              // ── Tus tasas (v23 · comparativa CalculaYa): tasas propias
              // con nombre y brecha vs BCV; tocar = aplicar (mecanismo
              // manual existente, cero cambios en el core).
              if (customRates.isNotEmpty) ...<Widget>[
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 2),
                  child: Text(
                    'TUS TASAS',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 9.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.76,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final (i, r) in customRates.indexed) ...[
                  if (i > 0)
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: scheme.outlineVariant.withValues(alpha: 0.65),
                    ),
                  _CustomRateRow(
                    rate: r,
                    bcv: ctx.rate('ves-bcv'),
                    selected:
                        ctx.sel(Currency.ves) == 'ves-manual' &&
                        (store.data.manualRates['ves-manual'] == r.bsPerUsd),
                    onTap: () => store.applyCustomRate(r),
                  ),
                ],
              ],
              // ── Grupo EUR: aristas del euro (solo si alguna tiene valor) ──
              if (_visibleSources(ctx, const [
                Currency.eur,
              ], country.currency).isNotEmpty) ...<Widget>[
                const RateGroupHeader(Currency.eur, hint: '1 EUR = X'),
                ..._withHairlines(
                  _groupRows(context, ref, store, ctx, const [
                    Currency.eur,
                  ], country.currency),
                ),
              ],
            ],
          ),
      ],
    );
  }

  /// v25 «HOJA»: hairline 1 px entre filas de la lista de cotización.
  List<Widget> _withHairlines(List<Widget> rows) {
    final out = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      if (i > 0) out.add(const Divider(height: 1, thickness: 1));
      out.add(rows[i]);
    }
    return out;
  }

  /// Fuentes visibles de [currencies]: con valor (>0) + SIEMPRE la Manual
  /// de la divisa del país (acceso rápido del dueño).
  List<RateSource> _visibleSources(
    RateContext ctx,
    List<Currency> currencies,
    Currency countryCurrency,
  ) {
    final out = <RateSource>[];
    for (final c in currencies) {
      for (final s in RateSource.sourcesFor(c)) {
        final isCountryManual =
            s.category == SourceCategory.manual && c == countryCurrency;
        if (ctx.rate(s.id) <= 0 && !isCountryManual) continue;
        out.add(s);
      }
    }
    return out;
  }

  List<Widget> _groupRows(
    BuildContext context,
    WidgetRef ref,
    AppStore store,
    RateContext ctx,
    List<Currency> currencies,
    Currency countryCurrency,
  ) {
    return <Widget>[
      for (final s in _visibleSources(ctx, currencies, countryCurrency))
        RateTile(
          sourceId: s.id,
          rate: ctx.rate(s.id),
          precision: store.settings.precision,
          selected: ctx.sel(s.currency) == s.id,
          freshness: store.board.sources[s.id] == null
              ? null
              : timeAgo(store.board.sources[s.id]!.updatedAt),
          onTap: () {
            if (ctx.rate(s.id) <= 0) {
              // Manual sin valor: el editor ES la activación.
              editManualRate(context, ref, store, s.id);
              return;
            }
            store.setRateSource(s.currency, s.id);
          },
          onEdit: s.category == SourceCategory.manual
              ? () => editManualRate(context, ref, store, s.id)
              : null,
        ),
    ];
  }
}

/// Editor manual inline: guarda y ACTIVA la fuente del país (v27).
Future<void> editManualRate(
  BuildContext context,
  WidgetRef ref,
  AppStore store,
  String sourceId,
) async {
  final s = RateSource.of(sourceId);
  if (s == null) return;
  final saved = await showManualRateEditor(
    context,
    ref: ref,
    sourceId: sourceId,
  );
  if (saved && context.mounted) {
    store.setRateSource(s.currency, s.id);
  }
}

/// Fila de tasa propia (v23): sello manual (violeta) + nombre + GapChip de
/// brecha vs BCV + valor tabular a la derecha; seleccionada invierte la
/// tinta como las filas de fuente. Mismo ritmo vertical que RateTile.
class _CustomRateRow extends ConsumerWidget {
  const _CustomRateRow({
    required this.rate,
    required this.bcv,
    required this.selected,
    required this.onTap,
  });

  final CustomRate rate;
  final double bcv;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final gap = bcv > 0 ? (rate.bsPerUsd / bcv - 1) * 100 : null;
    return InkWell(
      onTap: onTap,
      child: Container(
        // v25 «HOJA»: fila seleccionada SIN CAJA — tinta plena + check 14.
        margin: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
        child: Row(
          children: [
            const SourceSeal(SourceCategory.manual),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          rate.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: selected
                                ? scheme.onSurface
                                : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      if (selected) ...[
                        const SizedBox(width: 6),
                        Icon(Icons.check_rounded, size: 14, color: ink.manual),
                      ],
                    ],
                  ),
                  if (gap != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 3),
                      child: GapChip(gapPct: gap),
                    ),
                ],
              ),
            ),
            Text(
              '${fmtRate(rate.bsPerUsd)} Bs',
              style: VeText.displayNum(
                15,
                color: selected ? scheme.onSurface : scheme.onSurfaceVariant,
                weight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// «Divisas del foco» (patrón dp6): grid 2-col de MiniRateCard con bandera,
/// tasa activa y tinte por categoría. Tap → HOJA DE FUENTES de esa divisa
/// (nueva: radio de fuente con monto «1 {base} = X»; la manual lleva a
/// Ajustes). «Ir al conversor» queda en el encabezado de la sección.
