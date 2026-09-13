/// Tests del motor de divisas (MVP Fase B · §3.2).
/// Aristas directas/inversas/EUR/puente USD/promedio derivado/brecha/rechazo.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/core/currencies.dart';

RateContext ctx({
  Map<String, double>? rates,
  Map<Currency, String>? selected,
}) =>
    RateContext(
      rates: rates ?? const {},
      selected: selected ?? const {},
    );

void main() {
  group('RateSource · 15 fuentes', () {
    test('catálogo exacto de fuentes', () {
      expect(RateSource.all.length, 15);
      expect(RateSource.byId['ves-bcv']!.category, SourceCategory.official);
      expect(RateSource.byId['ves-parallel']!.category, SourceCategory.parallel);
      expect(RateSource.byId['ves-avg']!.live, isFalse);
      expect(RateSource.byId['ves-manual']!.category, SourceCategory.manual);
      expect(RateSource.sourcesFor(Currency.ves).length, 4);
      expect(RateSource.sourcesFor(Currency.cop).length, 3);
      expect(RateSource.sourcesFor(Currency.eur).length, 4);
    });

    test('DEFAULT_RATE_SOURCE = v15 oficiales', () {
      expect(RateSource.defaultSource[Currency.usd], 'usd');
      expect(RateSource.defaultSource[Currency.ves], 'ves-bcv');
      expect(RateSource.defaultSource[Currency.cop], 'cop-trm');
      expect(RateSource.defaultSource[Currency.eur], 'eur-ves-oficial');
      expect(RateSource.defaultSource[Currency.brl], 'brl-br');
      expect(RateSource.defaultSource[Currency.mxn], 'mxn-banxico');
    });

    test('validSourceId rechaza ids muertos con fallback', () {
      expect(RateSource.validSourceId(Currency.ves, 'fuente-inventada'), 'ves-bcv');
      expect(RateSource.validSourceId(Currency.ves, 'ves-parallel'), 'ves-parallel');
      expect(RateSource.validSourceId(Currency.ves, null), 'ves-bcv');
    });

    test('RateSource.of rechaza ids desconocidos', () {
      expect(RateSource.of('no-existe'), isNull);
      expect(RateSource.of('ves-bcv'), isNotNull);
      expect(RateSource.of(null), isNull);
    });
  });

  group('Motor · puente USD', () {
    test('USD↔VES directo con fuente seleccionada', () {
      final c = ctx(
        rates: {'ves-bcv': 40, 'ves-parallel': 45},
        selected: {Currency.ves: 'ves-bcv'},
      );
      expect(c.unitsPerUSD(Currency.usd), 1);
      expect(c.unitsPerUSD(Currency.ves), 40);
      expect(c.convert(10, Currency.usd, Currency.ves), 400);
    });

    test('X↔Y sin arista directa pasa por USD', () {
      // COP 4000/USD · BRL 5/USD → 100 COP = 100/4000*5 BRL = 0.125 BRL
      final c = ctx(
        rates: {'cop-trm': 4000, 'brl-br': 5},
        selected: {Currency.cop: 'cop-trm', Currency.brl: 'brl-br'},
      );
      final plan = c.plan(Currency.cop, Currency.brl)!;
      expect(plan.path, [Currency.cop, Currency.usd, Currency.brl]);
      expect(c.convert(100, Currency.cop, Currency.brl), closeTo(0.125, 0.0001));
    });

    test('inversa de arista directa (VES→USD)', () {
      final c = ctx(rates: {'ves-bcv': 40}, selected: {Currency.ves: 'ves-bcv'});
      expect(c.convert(400, Currency.ves, Currency.usd), closeTo(10, 0.0001));
    });

    test('ves-avg SIEMPRE derivado local (nunca de red)', () {
      // Aunque «ves-avg» viniera de red, el motor lo recalcula.
      final c = ctx(
        rates: {'ves-bcv': 40, 'ves-parallel': 44, 'ves-avg': 999},
        selected: {Currency.ves: 'ves-avg'},
      );
      expect(c.avgVes(), closeTo(42, 0.0001));
      expect(c.unitsPerUSD(Currency.ves), closeTo(42, 0.0001));
    });

    test('ves-avg con una sola fuente viva usa la viva', () {
      final c = ctx(
        rates: {'ves-bcv': 40},
        selected: {Currency.ves: 'ves-avg'},
      );
      expect(c.avgVes(), 40);
    });
  });

  group('Motor · EUR visible (resolveEur)', () {
    test('EUR→VES usa su arista directa emparejada', () {
      final c = ctx(
        rates: {'eur-ves-oficial': 43.4, 'ves-bcv': 40},
        selected: {Currency.eur: 'eur-ves-oficial', Currency.ves: 'ves-bcv'},
      );
      final plan = c.plan(Currency.eur, Currency.ves)!;
      expect(plan.path, [Currency.eur, Currency.ves]);
      expect(plan.sourceIds, ['eur-ves-oficial']);
      expect(c.convert(1, Currency.eur, Currency.ves), closeTo(43.4, 0.001));
    });

    test('EUR→USD vía par emparejado (oficial↔BCV)', () {
      final c = ctx(
        rates: {'eur-ves-oficial': 43.4, 'ves-bcv': 40},
        selected: {Currency.eur: 'eur-ves-oficial', Currency.ves: 'ves-bcv'},
      );
      // eurPerUSD = 40 / 43.4
      expect(c.resolveEur()!.eurPerUSD, closeTo(40 / 43.4, 0.0001));
    });

    test('familia EUR emparejada: paralelo↔paralelo, cop↔TRM', () {
      final c = ctx(
        rates: {'eur-cop': 4500, 'cop-trm': 4000},
        selected: {Currency.eur: 'eur-cop', Currency.cop: 'cop-trm'},
      );
      expect(c.resolveEur()!.eurPerUSD, closeTo(4000 / 4500, 0.0001));
    });

    test('fallback de aristas EUR cuando la preferida no está viva', () {
      final c = ctx(
        rates: {'eur-brl': 5.4, 'brl-br': 5},
        selected: {Currency.eur: 'eur-ves-oficial', Currency.brl: 'brl-br'},
      );
      // eur-ves-oficial no está en rates → cae a eur-brl
      expect(c.resolveEur()!.edge.id, 'eur-brl');
      expect(c.resolveEur()!.eurPerUSD, closeTo(5 / 5.4, 0.0001));
    });

    test('COP→EUR con ruta EUR visible', () {
      final c = ctx(
        rates: {'cop-trm': 4000, 'eur-cop': 4500, 'cop-market': 4100},
        selected: {Currency.cop: 'cop-market', Currency.eur: 'eur-cop'},
      );
      final plan = c.plan(Currency.cop, Currency.eur);
      expect(plan, isNotNull);
      expect(plan!.rate, greaterThan(0));
    });

    test('ConversionPlan.direct: true solo en arista directa', () {
      // VES→USD con BCV: arista directa (inversa).
      final c1 = ctx(rates: {'ves-bcv': 40}, selected: {Currency.ves: 'ves-bcv'});
      expect(c1.plan(Currency.ves, Currency.usd)!.direct, isTrue);
      expect(c1.plan(Currency.usd, Currency.ves)!.direct, isTrue);
      // COP→BRL: vía dólar → NO directa.
      final c2 = ctx(
        rates: {'cop-trm': 4000, 'brl-br': 5},
        selected: {Currency.cop: 'cop-trm', Currency.brl: 'brl-br'},
      );
      expect(c2.plan(Currency.cop, Currency.brl)!.direct, isFalse);
    });

    test('ruta EUR de 4 tramos COMPLETA (EUR→BRL por VES+USD)', () {
      final c = ctx(
        rates: {'eur-ves-oficial': 43.4, 'ves-bcv': 40, 'brl-br': 5},
        selected: {Currency.eur: 'eur-ves-oficial', Currency.brl: 'brl-br'},
      );
      final plan = c.plan(Currency.eur, Currency.brl)!;
      // 1 EUR = 43.4 Bs → 43.4/40 USD → ×5 BRL = 5.425 BRL.
      expect(plan.rate, closeTo(5.425, 0.001));
      expect(plan.direct, isFalse);
      // La ruta se pinta COMPLETA: EUR → VES → USD → BRL (4 tramos).
      expect(
          plan.path, [Currency.eur, Currency.ves, Currency.usd, Currency.brl]);
      expect(plan.sourceIds, ['eur-ves-oficial', 'ves-bcv', 'brl-br']);
    });

    test('ruta EUR de 4 tramos inversa (BRL→EUR por USD+VES)', () {
      final c = ctx(
        rates: {'eur-ves-oficial': 43.4, 'ves-bcv': 40, 'brl-br': 5},
        selected: {Currency.eur: 'eur-ves-oficial', Currency.brl: 'brl-br'},
      );
      final plan = c.plan(Currency.brl, Currency.eur)!;
      expect(plan.rate, closeTo(1 / 5.425, 0.001));
      expect(
          plan.path, [Currency.brl, Currency.usd, Currency.ves, Currency.eur]);
      expect(plan.sourceIds, ['brl-br', 'ves-bcv', 'eur-ves-oficial']);
    });

    test('resolveEur expone pairId del puente (fuente USD emparejada)', () {
      final c = ctx(
        rates: {'eur-ves-oficial': 43.4, 'ves-bcv': 40},
        selected: {Currency.eur: 'eur-ves-oficial', Currency.ves: 'ves-bcv'},
      );
      final eur = c.resolveEur()!;
      expect(eur.pairId, 'ves-bcv');
      expect(eur.edge.id, 'eur-ves-oficial');
    });

    test('recursivo anti-ciclo no cuelga', () {
      final c = ctx(
        rates: {'ves-bcv': 40},
        selected: {Currency.ves: 'ves-bcv'},
      );
      // USD pide unitsPerUSD(ves) que pide unitsPerUSD(usd) → resuelve 40.
      expect(c.unitsPerUSD(Currency.ves), 40);
    });
  });

  group('Motor · rechazos', () {
    test('sin tasas → plan null y convert 0', () {
      final c = ctx();
      expect(c.plan(Currency.usd, Currency.ves), isNull);
      expect(c.convert(10, Currency.usd, Currency.ves), 0);
      expect(c.toUSD(10, Currency.ves), 0);
    });

    test('tasas muertas (≤0) se ignoran', () {
      final c = ctx(
        rates: {'ves-bcv': -5},
        selected: {Currency.ves: 'ves-bcv'},
      );
      expect(c.plan(Currency.usd, Currency.ves), isNull);
    });

    test('from==to → rate 1', () {
      final c = ctx(rates: {'ves-bcv': 40}, selected: {Currency.ves: 'ves-bcv'});
      final p = c.plan(Currency.ves, Currency.ves)!;
      expect(p.rate, 1);
    });

    test('toUSD con rate<=0 → 0 (nunca divide por cero)', () {
      final c = ctx(rates: {'ves-bcv': 0}, selected: {Currency.ves: 'ves-bcv'});
      expect(c.toUSD(100, Currency.ves), 0);
    });
  });

  group('Brecha y missing', () {
    test('gapPct: paralelo vs BCV', () {
      final c = ctx(rates: {'ves-bcv': 40, 'ves-parallel': 45},
          selected: {Currency.ves: 'ves-bcv'});
      expect(c.gapPct(), closeTo(12.5, 0.001));
    });

    test('gapPct null sin ambas fuentes', () {
      final c = ctx(rates: {'ves-bcv': 40}, selected: {Currency.ves: 'ves-bcv'});
      expect(c.gapPct(), isNull);
    });

    test('missingFocusCurrencies salta USD y las derivables', () {
      final c = ctx(
        rates: {'ves-bcv': 40, 'ves-parallel': 45, 'cop-trm': 4000},
        selected: {Currency.ves: 'ves-avg', Currency.cop: 'cop-trm'},
      );
      final missing = c.missingFocusCurrencies();
      expect(missing, isNot(contains(Currency.usd)));
      expect(missing, isNot(contains(Currency.ves)));
      expect(missing, contains(Currency.eur));
    });
  });

  group('focusOrder y países', () {
    test('focusOrder respeta preferencia y SIEMPRE devuelve 6', () {
      final order = CurrencyX.focusOrder(['EUR', 'VES', 'XX', 'ves']);
      expect(order.length, 6);
      expect(order.first, Currency.eur);
      expect(order[1], Currency.ves);
      expect(order.map((c) => c).toSet().length, 6);
    });

    test('setCountry-estilo: fuente EUR por país', () {
      expect(Country.VE.eurSource, 'eur-ves-oficial');
      expect(Country.CO.eurSource, 'eur-cop');
      expect(Country.BR.eurSource, 'eur-brl');
    });

    test('parsers de enums tolerantes (nunca lanzan)', () {
      expect(CurrencyX.from('VES'), Currency.ves);
      expect(CurrencyX.from('xxx'), Currency.usd);
      expect(CurrencyX.from(null), Currency.usd);
      expect(CountryX.from('CO'), Country.CO);
      expect(CountryX.from('zz'), Country.VE);
    });
  });
}
