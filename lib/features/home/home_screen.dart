/// ─── Inicio (§9.1) ──────────────────────────────────────────────────────────
/// Hero fecha/hora/saludo · Héroe de tasa dp4 · Cotización principal
/// (tasas de la moneda del país + las fuentes seleccionadas por divisa,
/// rows → setRateSource) · Divisas del foco (→ conversor) · Resumen del
/// mes · Alertas de precios (metas) · Tus tiendas · Registros recientes ·
/// Herramientas. (Sección «Tu sueldo» retirada a pedido del dueño v17.2.)
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/analytics.dart' as an;
import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/rate_history.dart' show snapshotSeries;
import '../../data/store.dart';
import '../../state/app_state.dart';
import '../../widgets/app_router.dart' show kHeroRateKey;
import '../../widgets/app_tips.dart';
import '../../widgets/app_tour.dart' show TourKeys;
import '../../widgets/rate_sheet.dart';
import '../../widgets/ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final poller = context.watch<RatesPoller>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: RefreshIndicator(
        onRefresh: () => poller.refreshNow(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            const TipsTrigger(scope: 'home'),
            _Hero(poller: poller),
            // v19 · anti-salto: el héroe y la chispa de 7 días SON
            // condicionales (sin datos → shrink). AnimatedSize convierte su
            // aparición/desaparición en transición (300 ms) — el resto del
            // contenido nunca brinca al llegar la primera tasa o al cambiar
            // de fuente.
            AnimatedSize(
              duration: kLayoutDur,
              curve: kEaseVe,
              alignment: Alignment.topCenter,
              child: Column(children: [_RateHero(), _WeekSpark()]),
            ),
            // Anclas del tour completo (v17.8): cotización + divisas del foco.
            KeyedSubtree(
              key: TourKeys.cotizacion,
              child: _CotizacionPrincipal(),
            ),
            KeyedSubtree(key: TourKeys.divisasFoco, child: _DivisasFoco()),
            _ResumenMes(),
            _AlertasPrecios(),
            _TusTiendas(),
            _RegistrosRecientes(),
            _Herramientas(),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatefulWidget {
  const _Hero({required this.poller});
  final RatesPoller poller;

  @override
  State<_Hero> createState() => _HeroState();
}

class _HeroState extends State<_Hero> {
  Timer? _clock;
  DateTime _now = DateTime.now();

  @override
  void initState() {
    super.initState();
    // Hora viva del héroe: refresco cada 30 s (dispose correcto abajo).
    _clock = Timer.periodic(const Duration(seconds: 30), (_) {
      if (mounted) setState(() => _now = DateTime.now());
    });
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// % del paralelo (o BCV) vs el último snapshot de AYER — la píldora
  /// «vs ayer» del héroe v15. Null honesto si no hay datos comparables.
  (String, double)? _vsAyer(AppStore store) {
    for (final id in const ['ves-parallel', 'ves-bcv']) {
      final today = store.board.sources[id]?.rate;
      if (today == null || today <= 0) continue;
      final day = SnapshotPoint.dayKey(_now.subtract(const Duration(days: 1)));
      final yest =
          store.snapshots
              .where((p) => p.sourceId == id && p.day == day)
              .toList()
            ..sort((a, b) => a.day.compareTo(b.day));
      if (yest.isEmpty || yest.last.rate <= 0) continue;
      final pct = (today / yest.last.rate - 1) * 100;
      return (id == 'ves-parallel' ? 'Paralelo' : 'BCV', pct);
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    final now = _now;
    // Hora 24 h es-VE junto a la fecha (HH:mm, cero dependencias de locale).
    final hhmm =
        '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
    // «hace X» con el reloj real del cliente (fetchedAt del tablero);
    // se recalcula en cada rebuild (el poller notifica ~cada 60 s, cada
    // mutación del store y este timer de 30 s).
    final fetched = store.board.fetchedAt;
    final freshness = widget.poller.loading
        ? null
        : (fetched == null ? 'sin datos aún' : timeAgo(fetched, now));
    final vsAyer = _vsAyer(store);

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Row(
        children: [
          // v19 (orden del dueño): la fecha LARGA se retira — una sola línea
          // corta «lun 15 sep · 14:30» dice lo mismo sin ocupar el hero.
          Expanded(
            child: Text(
              '${kDias[now.weekday - 1].substring(0, 3)} ${now.day} ${kMeses[now.month - 1].substring(0, 3)} · $hhmm',
              style: TextStyle(
                fontSize: 14.5,
                fontWeight: FontWeight.w800,
                color: scheme.onSurface,
                height: 1.2,
              ),
            ),
          ),
          if (widget.poller.loading)
            const SizedBox(
              width: 16,
              height: 16,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          else ...[
            if (vsAyer != null) ...[
              Tooltip(
                message: '${vsAyer.$1} hoy vs ayer (snapshot local)',
                child: TrendBadge(vsAyer.$2),
              ),
              const SizedBox(width: 6),
            ],
            Text(
              freshness ?? '',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }
}

/// ─── Héroe de la tasa protagonista (patrón dp4, datos reales) ───────────────
/// Tarjeta «Dólar en Venezuela»: cifra héroe en ReadWindow (displayNum 38),
/// botón copiar, sellos de categoría/fuente y píldoras de brecha y vs-ayer.
/// Usa la fuente VES activa del tablero vivo (nunca demo).
class _RateHero extends StatelessWidget {
  const _RateHero();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    final VeInk sem = VeColors.of(context);

    // Fuente VES activa del tablero vivo; si no hay datos, nada (honesto).
    final activeId = store.sourceFor(Currency.ves);
    final s = RateSource.of(activeId);
    final e = store.board.sources[activeId];
    if (s == null || e == null) return const SizedBox.shrink();

    final Color catColor = switch (s.category) {
      SourceCategory.official => sem.pos,
      SourceCategory.mixed => sem.warn,
      SourceCategory.parallel => sem.neg,
      SourceCategory.manual => sem.manual,
    };

    // Brecha real vs BCV cuando la activa NO es la oficial (sello del héroe).
    final double? bcv = store.board.sources['ves-bcv']?.rate;
    final double? gapPct =
        (bcv != null && bcv > 0 && e.rate > 0 && activeId != 'ves-bcv')
        ? (e.rate / bcv - 1) * 100
        : null;

    // vs ayer: snapshot local del día anterior para la fuente activa.
    String? vsAyerLabel;
    final String dayKey = SnapshotPoint.dayKey(
      DateTime.now().subtract(const Duration(days: 1)),
    );
    final yest =
        store.snapshots
            .where((p) => p.sourceId == activeId && p.day == dayKey)
            .toList()
          ..sort((a, b) => a.day.compareTo(b.day));
    if (yest.isNotEmpty && yest.last.rate > 0) {
      final double pct = (e.rate / yest.last.rate - 1) * 100;
      vsAyerLabel = 'vs ayer ${fmtPct(pct, forceSign: true)}';
    }

    return Card(
      key: kHeroRateKey,
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    s.currency == Currency.usd ? 'Dólar en Venezuela' : s.label,
                    style: TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                      height: 1.1,
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(2.5),
                  decoration: BoxDecoration(
                    color: scheme.onSurfaceVariant.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: const Flag(Currency.ves, size: 13),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Expanded(
                  child: Settle(
                    child: ReadWindow(
                      semanticLabel:
                          '1 dólar igual a ${fmtRate(e.rate)} bolívares',
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          Flexible(
                            child: Text(
                              fmtRate(e.rate),
                              style: VeText.displayNum(
                                38,
                                color: scheme.onSurface,
                              ),
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          const SizedBox(width: 9),
                          const Flag(Currency.usd, size: 21),
                          const SizedBox(width: 6),
                          Text(
                            'USD',
                            style: VeText.displayNum(
                              20,
                              color: scheme.onSurfaceVariant,
                              weight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                InkWell(
                  onTap: () => copiarAlPortapapeles(
                    context,
                    fmtRate(e.rate).replaceAll('.', ','),
                    'Tasa copiada',
                  ),
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Icon(
                      Icons.copy_outlined,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Stamp(s.category.label, color: catColor),
                Stamp(s.detail, color: scheme.onSurfaceVariant),
                if (gapPct != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: sem.neg.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      'brecha ${fmtPct(gapPct)}',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'SpaceGrotesk',
                        color: sem.neg,
                      ),
                    ),
                  ),
                if (vsAyerLabel != null)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: sem.pos.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      vsAyerLabel,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        fontFamily: 'SpaceGrotesk',
                        color: sem.pos,
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sparkline de 7 días de la fuente VES activa (patrón dp6): honesta, solo
/// aparece con ≥ 2 snapshots guardados; muestra «Ayer» como referencia.
class _WeekSpark extends StatelessWidget {
  const _WeekSpark();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final activeId = store.sourceFor(Currency.ves);
    if (activeId.isEmpty) return const SizedBox.shrink();
    final pts = snapshotSeries(store.snapshots, activeId, 7);
    if (pts.length < 2) return const SizedBox.shrink();
    final values = pts.map((p) => p.rate).toList();
    final ayer = pts[pts.length - 2].rate;

    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 2),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Últimos 7 días',
                      style: VeText.labelCaps(
                        9.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (context, box) {
                        final w = (box.maxWidth - 84).clamp(120.0, 220.0);
                        return Sparkline(
                          values: values,
                          width: w.toDouble(),
                          height: 30,
                        );
                      },
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'Ayer',
                    style: VeText.labelCaps(
                      9.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    fmtRate(ayer),
                    style: VeText.displayNum(
                      15,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
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
class _CotizacionPrincipal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final poller = context.watch<RatesPoller>();
    final country = CountryX.from(store.settings.country);
    final ctx = store.contextOf();
    final manualId = '${country.currency.code.toLowerCase()}-manual';
    final hasAny = !store.board.isEmpty || ctx.rates.containsKey(manualId);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Cotización principal'),
        if (!hasAny)
          if (poller.offlineActive)
            // Desconexión ELEGIDA (modo offline): cloud_off + guía local.
            OfflineState(
              'Modo offline activo',
              hint:
                  'ValoraVE funciona 100% local. Pega tu tasa manual aquí '
                  'mismo, o desactiva el modo offline cuando quieras volver a '
                  'consultar las APIs.',
              actionLabel: 'Tasa manual',
              onAction: () => _editManual(context, store, manualId),
            )
          else if (poller.networkBlocked || poller.offlineNet)
            // Sin red (señal viva v17.8) o red bloqueada SIN datos guardados:
            // wifi_off + salidas reales — NUNCA spinner de 7 s que va a fallar.
            OfflineState(
              'Sin conexión · sin tasas guardadas todavía',
              hint:
                  'No pierdes nada: todo lo demás de la app funciona igual '
                  'con los datos de tu teléfono. Cuando vuelva la red, las '
                  'tasas se descargan solas; o pega una tasa manual ahora.',
              icon: Icons.wifi_off,
              actionLabel: poller.loading ? 'Consultando…' : 'Reintentar',
              onAction: poller.loading ? null : () => poller.retryNow(),
              secondaryLabel: 'Tasa manual',
              onSecondary: () => _editManual(context, store, manualId),
            )
          else
            // PRIMERA CARGA: spinner, cero iconografía de red.
            LoadingState(
              'Buscando tasas…',
              hint:
                  'Primera carga de tasas en curso. También puedes pegar '
                  'una tasa manual ahora mismo.',
              actionLabel: 'Tasa manual',
              onAction: () => _editManual(context, store, manualId),
            )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                children: [
                  // ── Grupo USD: todas las fuentes «1 USD = X» ──
                  const RateGroupHeader(
                    Currency.usd,
                    hint: '1 USD = X · toca una fila para activarla',
                  ),
                  ..._groupRows(context, store, ctx, [
                    Currency.ves,
                    Currency.cop,
                    Currency.brl,
                    Currency.mxn,
                  ], country.currency),
                  // ── Grupo EUR: aristas del euro (solo si alguna tiene valor) ──
                  if (_visibleSources(ctx, const [
                    Currency.eur,
                  ], country.currency).isNotEmpty) ...<Widget>[
                    const RateGroupHeader(Currency.eur, hint: '1 EUR = X'),
                    ..._groupRows(context, store, ctx, const [
                      Currency.eur,
                    ], country.currency),
                  ],
                ],
              ),
            ),
          ),
      ],
    );
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
          selected: ctx.sel(s.currency) == s.id,
          freshness: store.board.sources[s.id] == null
              ? null
              : timeAgo(store.board.sources[s.id]!.updatedAt),
          onTap: () {
            if (ctx.rate(s.id) <= 0) {
              // Manual sin valor: el editor ES la activación.
              _editManual(context, store, s.id);
              return;
            }
            store.setRateSource(s.currency, s.id);
          },
          onEdit: s.category == SourceCategory.manual
              ? () => _editManual(context, store, s.id)
              : null,
        ),
    ];
  }

  /// Editor manual inline: guarda y ACTIVA la fuente del país.
  Future<void> _editManual(
    BuildContext context,
    AppStore store,
    String sourceId,
  ) async {
    final s = RateSource.of(sourceId);
    if (s == null) return;
    final saved = await showManualRateEditor(context, sourceId: sourceId);
    if (saved && context.mounted) {
      store.setRateSource(s.currency, s.id);
    }
  }
}

/// «Divisas del foco» (patrón dp6): grid 2-col de MiniRateCard con bandera,
/// tasa activa y tinte por categoría. Tap → HOJA DE FUENTES de esa divisa
/// (nueva: radio de fuente con monto «1 {base} = X»; la manual lleva a
/// Ajustes). «Ir al conversor» queda en el encabezado de la sección.
class _DivisasFoco extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final ctx = store.contextOf();

    final list = CurrencyX.focus.toList(growable: false);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Divisas del foco',
          actionLabel: 'Ir al conversor',
          onAction: () => context.go('/conversor'),
        ),
        Padding(
          padding: const EdgeInsets.only(bottom: 4),
          child: Column(
            children: [
              for (int i = 0; i < list.length; i += 2)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: _MiniCard(
                          currency: list[i],
                          rate: ctx.activeRate(list[i]),
                        ),
                      ),
                      if (i + 1 < list.length) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: _MiniCard(
                            currency: list[i + 1],
                            rate: ctx.activeRate(list[i + 1]),
                          ),
                        ),
                      ] else
                        const Expanded(child: SizedBox.shrink()),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniCard extends StatelessWidget {
  const _MiniCard({required this.currency, required this.rate});

  final Currency currency;
  final double rate;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = RateSource.of(store.sourceFor(currency));
    final VeInk sem = VeColors.of(context);
    final Color catInk = switch (s?.category ?? SourceCategory.official) {
      SourceCategory.official => sem.pos,
      SourceCategory.mixed => sem.warn,
      SourceCategory.parallel => sem.neg,
      SourceCategory.manual => sem.manual,
    };
    return MiniRateCard(
      label: s == null
          ? currency.code
          : '${currency.code} · ${s.category.label}',
      value: rate > 0 ? fmtRate(rate) : '—',
      ink: rate > 0 ? catInk : null,
      leading: Flag(currency, size: 14),
      onTap: () => _openCurrencySources(context, currency),
    );
  }
}

/// Hoja de fuentes de una divisa (v19): el MISMO selector de TASA visual de
/// toda la app — filas [Bandera][Nombre][Precio + símbolo] con color de
/// categoría y Manual editable INLINE (antes era una lista plana sin
/// banderas que mandaba la manual a Ajustes).
Future<void> _openCurrencySources(BuildContext context, Currency c) async {
  final store = context.read<AppStore>();
  await showRateSheet(
    context,
    currency: c,
    ctx: store.contextOf(),
    currentId: store.sourceFor(c),
    title: 'Fuentes de ${c.code}',
    onPick: (id) => store.setRateSource(c, id),
  );
}

class _AlertasPrecios extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    final targets =
        store.products
            .where((p) => p.targetPrice != null && p.targetPrice! > 0)
            .toList()
          ..sort(
            (a, b) => (b.latestRecord?.date ?? b.createdAt).compareTo(
              a.latestRecord?.date ?? a.createdAt,
            ),
          );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Alertas de precios',
          actionLabel: 'Ver productos',
          onAction: () => context.go('/productos'),
        ),
        if (targets.isEmpty)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Row(
                children: [
                  Icon(
                    Icons.notifications_none,
                    size: 18,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Sin metas configuradas',
                      style: TextStyle(
                        fontSize: 12.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: () => context.go('/productos'),
                    child: const Text('Fijar una meta'),
                  ),
                ],
              ),
            ),
          )
        else
          Card(
            child: Column(
              children: [
                for (final p in targets.take(6))
                  InkWell(
                    onTap: () => context.go('/productos'),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 10,
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  p.name,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                Text(
                                  'Meta ${fmtUSD(p.targetPrice!)} · Último ${p.latestRecord != null ? fmtUSD(p.latestRecord!.price) : '—'}',
                                  style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          if (an.computeTargetInfo(p).met)
                            Stamp('¡bajo meta!', color: sem.pos)
                          else
                            Stamp('pendiente', color: scheme.onSurfaceVariant),
                        ],
                      ),
                    ),
                  ),
                if (targets.length > 6)
                  Padding(
                    padding: const EdgeInsets.only(
                      left: 14,
                      right: 14,
                      bottom: 10,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'y ${targets.length - 6} metas más en Productos.',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

class _ResumenMes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    // v17.8: el resumen se alimenta de las COMPRAS de Lista (automático,
    // sin registro manual). Finanzas como módulo se retiró por orden del
    // dueño; lo que gasta el usuario de verdad son sus compras guardadas.
    final monthPurchases = store.purchases
        .where((p) => p.date.year == now.year && p.date.month == now.month)
        .toList();
    final spent = monthPurchases.fold<double>(0, (a, p) => a + p.paidUSD);

    // Mes previo para el delta honesto.
    final prev = DateTime(now.year, now.month - 1, 1);
    final prevSpent = store.purchases
        .where((p) => p.date.year == prev.year && p.date.month == prev.month)
        .fold<double>(0, (a, p) => a + p.paidUSD);
    final deltaSub = prevSpent <= 0
        ? 'Mes previo: sin compras'
        : 'vs mes previo: ${fmtPct((spent / prevSpent - 1) * 100, forceSign: true)}';

    // Ledger por tienda (gastos del mes, top 5).
    final byStore = <String, double>{};
    for (final p in monthPurchases) {
      final k = (p.store ?? '').trim().isEmpty ? 'Sin tienda' : p.store!.trim();
      byStore[k] = (byStore[k] ?? 0) + p.paidUSD;
    }
    final sorted = byStore.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Resumen del mes',
          actionLabel: 'Ver en Análisis',
          onAction: () => context.go('/analisis'),
        ),
        if (monthPurchases.isEmpty)
          Card(
            child: EmptyState(
              'Sin compras este mes',
              icon: Icons.shopping_cart_outlined,
              hint:
                  'Finaliza una compra en Lista y este resumen se llena solo: '
                  'total del mes, tiendas y comparación con el mes anterior.',
            ),
          )
        else
          Card(
            child: Padding(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Gastado en ${kMeses[now.month - 1]}',
                    style: VeText.labelCaps(
                      9.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  AnimatedNumber(
                    spent,
                    style: VeText.displayNum(30, color: scheme.onSurface),
                    decimals: 2,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '$deltaSub · ${monthPurchases.length} ${monthPurchases.length == 1 ? 'compra' : 'compras'}',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: StatCard(
                          label: 'Compras',
                          value: '${monthPurchases.length}',
                          icon: Icons.receipt_long,
                          tone: StatTone.neutral,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: StatCard(
                          label: 'Tienda top',
                          value: sorted.first.key,
                          sub: sorted.length > 1
                              ? 'y ${sorted.length - 1} tiendas más'
                              : null,
                          icon: Icons.storefront_outlined,
                          tone: StatTone.pos,
                        ),
                      ),
                    ],
                  ),
                  if (sorted.isNotEmpty) ...[
                    const SizedBox(height: 12),
                    for (final e in sorted.take(5))
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: LedgerRow(
                          label: e.key,
                          value: fmtUSD(e.value),
                          leading: CircleAvatar(
                            radius: 12,
                            backgroundColor: scheme.primary.withValues(
                              alpha: 0.10,
                            ),
                            child: Text(
                              an.storeInitials(e.key),
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.w800,
                                color: scheme.primary,
                              ),
                            ),
                          ),
                          dots:
                              true, // cierre del resumen: conserva puntos contables
                        ),
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

class _TusTiendas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final stats = an.storeStats(store.purchases).take(4).toList();
    if (stats.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Tus tiendas',
          actionLabel: 'Ver historial',
          onAction: () => context.go('/historial'),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                for (final s in stats)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: InkWell(
                      onTap: () => showStoreSheet(context, s.store),
                      borderRadius: BorderRadius.circular(10),
                      child: LedgerRow(
                        label: s.store.isEmpty ? 'Sin tienda' : s.store,
                        value: fmtUSD(s.totalUSD),
                        leading: StoreAvatar(
                          s.store.isEmpty ? 'Sin Tienda' : s.store,
                          size: 28,
                        ),
                      ),
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

/// Detalle por tienda (StoreSheet del web §9.1): gasto total, frecuencia,
/// última compra y las compras de esa tienda con cross-link al Historial.
void showStoreSheet(BuildContext context, String storeName) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.9,
      builder: (ctx, scroll) {
        final store = ctx.watch<AppStore>();
        final scheme = Theme.of(ctx).colorScheme;
        final stats = an.storeStats(store.purchases);
        final stat = stats.where((s) => s.store == storeName).firstOrNull;
        final purchases = an.storeDetail(store.purchases, storeName);
        final label = storeName.isEmpty ? 'Sin tienda' : storeName;
        return ListView(
          controller: scroll,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
          children: [
            Row(
              children: [
                StoreAvatar(
                  storeName.isEmpty ? 'Sin Tienda' : storeName,
                  size: 40,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        label,
                        style: const TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      if (stat != null)
                        Text(
                          '${stat.count} compras · última ${stat.last == null ? '—' : fmtDate(stat.last!)}',
                          style: TextStyle(
                            fontSize: 12,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            if (stat == null)
              Padding(
                padding: const EdgeInsets.only(top: 30),
                child: Text(
                  'Sin compras registradas de esta tienda.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else ...[
              ReadWindow(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'GASTO ACUMULADO',
                      style: VeText.labelCaps(
                        9,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      fmtUSD(stat.totalUSD),
                      style: VeText.displayNum(26, color: scheme.onSurface),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              for (final p in purchases.take(12))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: LedgerRow(
                    label: '${fmtDate(p.date)} · ${p.items.length} artículos',
                    value: fmtUSD(p.totalUSD),
                    dots: true, // cierre de la cuenta por tienda: con puntos
                  ),
                ),
              if (purchases.length > 12)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    'y ${purchases.length - 12} compras más en el Historial.',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () {
                    Navigator.pop(ctx);
                    ctx.go('/historial');
                  },
                  child: const Text('Ver en el Historial'),
                ),
              ),
            ],
          ],
        );
      },
    ),
  );
}

class _RegistrosRecientes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final recents = <String>[];
    for (final p in store.purchases.take(3)) {
      recents.add('Compra · ${p.store ?? 'Sin tienda'} · ${fmtDate(p.date)}');
    }
    for (final t in store.transactions.take(3)) {
      recents.add(
        '${t.isIncome ? 'Ingreso' : 'Gasto'} · ${t.category.label} · ${fmtDate(t.date)}',
      );
    }
    if (recents.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle(
          'Registros recientes',
          actionLabel: 'Ver historial',
          onAction: () => context.go('/historial'),
        ),
        Card(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Column(
              children: [
                for (final r in recents)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Icon(
                          Icons.history,
                          size: 14,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            r,
                            style: const TextStyle(fontSize: 12.5),
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

class _Herramientas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SectionTitle('Herramientas'),
        Row(
          children: [
            Expanded(
              child: _Tool(
                icon: Icons.calculate_outlined,
                label: 'Conversor',
                onTap: () => context.go('/conversor'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Tool(
                icon: Icons.shopping_cart_outlined,
                label: 'Lista',
                onTap: () => context.go('/lista'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _Tool(
                icon: Icons.receipt_long_outlined,
                label: 'Historial',
                onTap: () => context.go('/historial'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _Tool extends StatelessWidget {
  const _Tool({required this.icon, required this.label, required this.onTap});
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return TapScale(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 14),
        decoration: BoxDecoration(
          color: scheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Column(
          children: [
            Icon(icon, size: 20, color: scheme.primary),
            const SizedBox(height: 6),
            Text(
              label,
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
            ),
          ],
        ),
      ),
    );
  }
}
