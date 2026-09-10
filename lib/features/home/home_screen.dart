/// ─── Inicio (§9.1) ──────────────────────────────────────────────────────────
/// Hero fecha/saludo · Cotización principal (rows → setRateSource) ·
/// calculadora de sueldo fija + tiles + extras regionales + derivadas LOTTT ·
/// Resumen del mes · Tus tiendas · Registros recientes · Herramientas.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/analytics.dart' as an;
import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../state/app_state.dart';
import '../../widgets/ui.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final poller = context.watch<RatesPoller>();
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: RefreshIndicator(
        onRefresh: () => poller.refreshNow(),
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
          children: [
            _Hero(now: now, poller: poller),
            _CotizacionPrincipal(),
            _SueldoSection(),
            _ResumenMes(),
            _TusTiendas(),
            _RegistrosRecientes(),
            _Herramientas(),
          ],
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({required this.now, required this.poller});
  final DateTime now;
  final RatesPoller poller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 14),
      child: Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(saludo(now), style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            Text(fmtDateLong(now),
                style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800, color: scheme.onSurface, height: 1.2)),
          ]),
        ),
        if (poller.loading)
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        else
          Text('hace instantes', style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
      ]),
    );
  }
}

class _CotizacionPrincipal extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final poller = context.watch<RatesPoller>();
    final scheme = Theme.of(context).colorScheme;
    final country = CountryX.from(store.settings.country);
    final featured = country.featured;

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Cotización principal', index: 1),
      if (store.board.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(children: [
              Icon(Icons.wifi_off, size: 30, color: scheme.onSurfaceVariant),
              const SizedBox(height: 10),
              Text(poller.networkBlocked ? 'Sin conexión y sin tasas guardadas' : 'Tablero vacío',
                  style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14.5)),
              const SizedBox(height: 6),
              Text(
                'La app funciona igual: usa el editor de tasas manuales en Ajustes → Monedas y tasas, o reintenta cuando haya red.',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12.5, height: 1.45, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 12),
              FilledButton.tonal(
                onPressed: () => poller.refreshNow(),
                child: const Text('Reintentar'),
              ),
            ]),
          ),
        )
      else
        Card(
          child: Column(children: [
            for (final id in featured)
              _RateRow(sourceId: id, selected: store.sourceFor(CurrencyX.from(RateSource.of(id)?.currency.code ?? 'VES')) == id),
          ]),
        ),
    ]);
  }
}

class _RateRow extends StatelessWidget {
  const _RateRow({required this.sourceId, required this.selected});

  final String sourceId;
  final bool selected;

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final s = RateSource.of(sourceId);
    final e = store.board.sources[sourceId];
    if (s == null || e == null) return const SizedBox.shrink();
    final VeInk sem = VeColors.of(context);
    final ink = switch (s.category) {
      SourceCategory.official => sem.pos,
      SourceCategory.mixed => sem.warn,
      SourceCategory.parallel => sem.neg,
      SourceCategory.manual => sem.manual,
    };

    return InkWell(
      onTap: () => store.setRateSource(s.currency, s.id),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
        child: Row(children: [
          SourceDot(s.category),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(s.label, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              Text(s.detail, style: TextStyle(fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Semantics(
              label: '1 dólar igual a ${fmtRate(e.rate)} bolívares',
              child: Text(s.currency == Currency.eur ? fmtEurRate(e.rate) : fmtRate(e.rate),
                  style: VeText.displayNum(19, color: Theme.of(context).colorScheme.onSurface)),
            ),
            Text(timeAgo(e.updatedAt), style: TextStyle(fontSize: 10.5, color: Theme.of(context).colorScheme.onSurfaceVariant)),
          ]),
          const SizedBox(width: 8),
          Text('Bs', style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: ink)),
        ]),
      ),
    );
  }
}

class _SueldoSection extends StatefulWidget {
  @override
  State<_SueldoSection> createState() => _SueldoSectionState();
}

class _SueldoSectionState extends State<_SueldoSection> {
  final _amountCtrl = TextEditingController();

  @override
  void dispose() {
    _amountCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final ctx = store.contextOf();
    final salary = store.settings.salaryAmount;
    final salaryCur = CurrencyX.from(store.settings.salaryCurrency);

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Tu sueldo', index: 2,
          actionLabel: salary == null ? null : 'Quitar sueldo',
          onAction: salary == null ? null : () => store.setSetting('salary', null)),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: TextField(
                  controller: _amountCtrl,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    hintText: salary == null ? 'Monto mensual pactado' : 'Cambiar monto',
                  ),
                ),
              ),
              const SizedBox(width: 8),
              CurrencySelect(
                value: salaryCur,
                onChanged: (c) {
                  if (salary != null) {
                    store.setSetting('salary', {'amount': salary, 'currency': c.code});
                  }
                },
              ),
            ]),
            const SizedBox(height: 10),
            Row(children: [
              FilledButton(
                onPressed: () {
                  final v = parseLocaleNum(_amountCtrl.text);
                  if (v == null || v <= 0) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Ingresa un monto válido'), behavior: SnackBarBehavior.floating));
                    return;
                  }
                  store.setSetting('salary', {'amount': v, 'currency': salaryCur.code});
                  _amountCtrl.clear();
                },
                child: Text(salary == null ? 'Guardar sueldo' : 'Actualizar'),
              ),
            ]),
            if (salary != null && salary > 0) ...[
              const SizedBox(height: 14),
              ReadWindow(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('Sueldo pactado', style: VeText.labelCaps(9, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  Text(fmtCurrency(salary, salaryCur), style: VeText.displayNum(24, color: scheme.onSurface)),
                ]),
              ),
              const SizedBox(height: 10),
              // Tiles: contrato (moneda pactada), USD, EUR + extras del país.
              _SalaryTiles(ctx: ctx, salary: salary, salaryCur: salaryCur),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _SalaryTiles extends StatelessWidget {
  const _SalaryTiles({required this.ctx, required this.salary, required this.salaryCur});

  final RateContext ctx;
  final double salary;
  final Currency salaryCur;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final country = CountryX.from(context.read<AppStore>().settings.country);

    double? inCur(Currency c) {
      if (ctx.unitsPerUSD(salaryCur) == null) return null;
      final p = ctx.plan(salaryCur, c);
      return p == null ? null : salary * p.rate;
    }

    final tiles = <(String, String)>[];
    final usd = inCur(Currency.usd);
    final eur = inCur(Currency.eur);
    final ves = inCur(Currency.ves);
    if (ves != null) tiles.add(('Bs al mes', fmtMoney(ves, Currency.ves)));
    if (usd != null) tiles.add(('USD al mes', fmtMoney(usd, Currency.usd)));
    if (eur != null) tiles.add(('EUR al mes', fmtMoney(eur, Currency.eur)));
    for (final c in country.extras) {
      final v = inCur(c);
      if (v != null) tiles.add(('${c.code} al mes', fmtMoney(v, c)));
    }

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          for (final (label, value) in tiles)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: scheme.outlineVariant),
              ),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(label, style: VeText.labelCaps(9, color: scheme.onSurfaceVariant)),
                const SizedBox(height: 3),
                Text(value, style: VeText.displayNum(14.5, color: scheme.onSurface)),
              ]),
            ),
        ],
      ),
      if (ves != null) ...[
        const SizedBox(height: 8),
        Text('Derivadas LOTTT: ${fmtMoney(ves / 30, Currency.ves)} / día · '
                '${fmtMoney(ves / 30 / 8, Currency.ves)} / hora aprox.',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
      ],
    ]);
  }
}

class _ResumenMes extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final now = DateTime.now();
    final monthTx = store.transactions
        .where((t) => t.date.year == now.year && t.date.month == now.month)
        .toList();
    final income = monthTx.where((t) => t.isIncome).fold<double>(0, (a, t) => a + t.amountUSD);
    final expense = monthTx.where((t) => !t.isIncome).fold<double>(0, (a, t) => a + t.amountUSD);
    final balance = income - expense;

    // Ledger por categoría (gastos del mes).
    final byCat = <FinanceCategory, double>{};
    for (final t in monthTx.where((t) => !t.isIncome)) {
      byCat[t.category] = (byCat[t.category] ?? 0) + t.amountUSD;
    }
    final sorted = byCat.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Resumen del mes', index: 3,
          actionLabel: 'Ver finanzas', onAction: () => context.go('/finanzas')),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Balance de ${kMeses[now.month - 1]}',
                style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            Text(fmtUSD(balance),
                style: VeText.displayNum(30, color: balance < 0 ? VeColors.of(context).neg : scheme.onSurface)),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: StatCard(label: 'Ingresos', value: fmtUSD(income), icon: Icons.south_west, tone: StatTone.pos)),
              const SizedBox(width: 8),
              Expanded(child: StatCard(label: 'Gastos', value: fmtUSD(expense), icon: Icons.north_east, tone: StatTone.neg)),
            ]),
            if (sorted.isNotEmpty) ...[
              const SizedBox(height: 12),
              for (final e in sorted.take(5))
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: LedgerRow(
                    label: e.key.label,
                    value: fmtUSD(e.value),
                    leading: CategoryIcon(finCat: e.key, size: 24),
                  ),
                ),
            ],
          ]),
        ),
      ),
    ]);
  }
}

class _TusTiendas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final stats = an.storeStats(store.purchases).take(4).toList();
    if (stats.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Tus tiendas', index: 4,
          actionLabel: 'Ver historial', onAction: () => context.go('/historial')),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(children: [
            for (final s in stats)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: LedgerRow(
                  label: s.store.isEmpty ? 'Sin tienda' : s.store,
                  value: fmtUSD(s.totalUSD),
                  leading: StoreAvatar(s.store.isEmpty ? 'Sin Tienda' : s.store, size: 28),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }
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
      recents.add('${t.isIncome ? 'Ingreso' : 'Gasto'} · ${t.category.label} · ${fmtDate(t.date)}');
    }
    if (recents.isEmpty) return const SizedBox.shrink();

    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Registros recientes', index: 5,
          actionLabel: 'Ver historial', onAction: () => context.go('/historial')),
      Card(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          child: Column(children: [
            for (final r in recents)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 6),
                child: Row(children: [
                  Icon(Icons.history, size: 14, color: Theme.of(context).colorScheme.onSurfaceVariant),
                  const SizedBox(width: 8),
                  Expanded(child: Text(r, style: const TextStyle(fontSize: 12.5))),
                ]),
              ),
          ]),
        ),
      ),
    ]);
  }
}

class _Herramientas extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Herramientas', index: 6),
      Row(children: [
        Expanded(child: _Tool(icon: Icons.calculate_outlined, label: 'Conversor', onTap: () => context.go('/conversor'))),
        const SizedBox(width: 8),
        Expanded(child: _Tool(icon: Icons.shopping_cart_outlined, label: 'Lista', onTap: () => context.go('/lista'))),
        const SizedBox(width: 8),
        Expanded(child: _Tool(icon: Icons.receipt_long_outlined, label: 'Historial', onTap: () => context.go('/historial'))),
      ]),
    ]);
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
        child: Column(children: [
          Icon(icon, size: 20, color: scheme.primary),
          const SizedBox(height: 6),
          Text(label, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
        ]),
      ),
    );
  }
}
