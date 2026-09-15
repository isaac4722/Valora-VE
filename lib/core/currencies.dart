/// ─── ValoraVE · Monedas, fuentes de tasa y motor de conversión ─────────────
/// Capa de DOMINIO. USD es el puente de todas las conversiones indirectas;
/// EUR resuelve con la mejor arista viva de su familia (oficial ↔ oficial,
/// paralelo ↔ paralelo). Puerto fiel de currencies.ts (web v15) con la
/// corrección §12.1 del spec: el promedio `ves-avg` SIEMPRE se deriva
/// (BCV+paralelo)/2, nunca llega de red.
library;

/// Divisas del foco de producto (v5): VES · USD · EUR · COP · BRL · MXN.
/// No existe ninguna otra moneda en la app.
enum Currency { usd, ves, cop, eur, brl, mxn }

/// Categoría de fuente de tasa — el SELLO dice QUÉ es la tasa (v19.0:
/// icono + palabra, no rayita de color): official 🏛 · mixed ⚖ ·
/// parallel 🛒 (mercado) · manual ✎.
enum SourceCategory { official, mixed, parallel, manual }

/// Etiqueta corta de categoría de fuente (web CATEGORY_LABEL). v19.0: la
/// categoría paralela se lee «Mercado» (la palabra del dueño) — los nombres
/// de fuente concretos siguen diciendo «Paralelo» donde aplica.
extension SourceCategoryX on SourceCategory {
  String get label => switch (this) {
    SourceCategory.official => 'Oficial',
    SourceCategory.mixed => 'Promedio',
    SourceCategory.parallel => 'Mercado',
    SourceCategory.manual => 'Manual',
  };
}

/// Código corto seguro (el `.name` del enum puede quedar tapado por
/// extensiones; `toString().split('.')` es inmune).
String enumCode(Object e) => e.toString().split('.').last;

extension CurrencyX on Currency {
  /// Código corto ('USD').
  String get code => enumCode(this).toUpperCase();
  String get symbol => switch (this) {
    Currency.usd => r'$',
    Currency.ves => 'Bs',
    Currency.eur => '€',
    Currency.brl => r'R$',
    _ => code,
  };
  String get label => switch (this) {
    Currency.usd => 'Dólar',
    Currency.ves => 'Bolívar',
    Currency.cop => 'Peso colombiano',
    Currency.eur => 'Euro',
    Currency.brl => 'Real',
    Currency.mxn => 'Peso mexicano',
  };

  /// Decimales por defecto al mostrar montos (COP 0, resto 2).
  int get decimals => this == Currency.cop ? 0 : 2;

  static final Map<String, Currency> _byCode = {
    for (final c in Currency.values) enumCode(c).toUpperCase(): c,
  };

  /// Parser tolerante: id desconocido/nulo → USD (nunca lanza).
  static Currency from(String? s) => _byCode[s?.toUpperCase()] ?? Currency.usd;

  /// Orden canónico del foco: VES · USD · EUR · COP · BRL · MXN.
  static List<Currency> get focus => [
    Currency.ves,
    Currency.usd,
    Currency.eur,
    Currency.cop,
    Currency.brl,
    Currency.mxn,
  ];

  /// Foco sin USD (para selects donde el dólar no compite).
  static List<Currency> get focusMain =>
      focus.where((c) => c != Currency.usd).toList();

  /// Orden respetando la preferencia del usuario (v13): las elegidas
  /// primero en su orden, las que falten al final en orden canónico.
  /// Devuelve SIEMPRE las 6 divisas y purga duplicados/extraños.
  static List<Currency> focusOrder(List<String>? userOrder) {
    if (userOrder == null || userOrder.isEmpty) return focus;
    final valid = userOrder
        .map((s) => _byCode[s.toUpperCase()])
        .whereType<Currency>()
        .toSet()
        .toList();
    final rest = focus.where((c) => !valid.contains(c)).toList();
    return [...valid, ...rest];
  }
}

/// Países con tablero propio (default VE).
enum Country { VE, CO, BR, MX, US }

extension CountryX on Country {
  String get code => enumCode(this);
  String get label => switch (this) {
    Country.VE => 'Venezuela',
    Country.CO => 'Colombia',
    Country.BR => 'Brasil',
    Country.MX => 'México',
    Country.US => 'Global / USD',
  };
  Currency get currency => switch (this) {
    Country.VE => Currency.ves,
    Country.CO => Currency.cop,
    Country.BR => Currency.brl,
    Country.MX => Currency.mxn,
    Country.US => Currency.usd,
  };

  /// Fuentes protagonistas del país (héroe + cinta «Mi país»).
  List<String> get featured => switch (this) {
    Country.VE => ['ves-bcv', 'ves-parallel', 'ves-avg'],
    Country.CO => ['cop-trm', 'cop-market'],
    Country.BR => ['brl-br'],
    Country.MX => ['mxn-banxico'],
    Country.US => ['ves-parallel', 'cop-trm', 'brl-br', 'mxn-banxico'],
  };

  /// Fuente EUR preferida del país (setCountry del web §2.1).
  String get eurSource => switch (this) {
    Country.VE => 'eur-ves-oficial',
    Country.CO => 'eur-cop',
    Country.BR => 'eur-brl',
    _ => 'eur-ves-oficial',
  };

  /// Extras regionales de la calculadora de sueldo (Inicio).
  List<Currency> get extras => switch (this) {
    Country.VE => const [Currency.cop, Currency.brl],
    Country.CO => const [Currency.usd],
    _ => const [],
  };

  static final Map<String, Country> _byCode = {
    for (final c in Country.values) enumCode(c): c,
  };

  /// Parser tolerante: id inválido/nulo → VE (nunca lanza).
  static Country from(String? s) => _byCode[s?.toUpperCase()] ?? Country.VE;
}

/// Fuente de tasa: 1 {base} = rate {quote}.
class RateSource {
  final String id;
  final Currency currency;
  final String label;
  final String detail;
  final Currency base, quote;

  /// live (de red) · derived (ves-avg) · manual (del usuario).
  final bool live;
  final SourceCategory category;

  const RateSource(
    this.id,
    this.currency,
    this.label,
    this.detail,
    this.base,
    this.quote, {
    this.live = true,
    this.category = SourceCategory.official,
  });

  /// Etiqueta natural de las aristas EUR («EUR Oficial a Bs»…).
  String get edgeName => currency == Currency.eur ? 'EUR $label' : label;

  static const all = <RateSource>[
    // VES
    RateSource(
      'ves-bcv',
      Currency.ves,
      'BCV',
      'Oficial · Banco Central de Venezuela',
      Currency.usd,
      Currency.ves,
    ),
    RateSource(
      'ves-parallel',
      Currency.ves,
      'Paralelo',
      'Mercado',
      Currency.usd,
      Currency.ves,
      category: SourceCategory.parallel,
    ),
    RateSource(
      'ves-avg',
      Currency.ves,
      'Promedio',
      'Entre BCV y paralelo',
      Currency.usd,
      Currency.ves,
      live: false,
      category: SourceCategory.mixed,
    ),
    RateSource(
      'ves-manual',
      Currency.ves,
      'Manual',
      'Tu propia tasa en VES por USD',
      Currency.usd,
      Currency.ves,
      live: false,
      category: SourceCategory.manual,
    ),
    // COP
    RateSource(
      'cop-trm',
      Currency.cop,
      'TRM',
      'Superfinanciera',
      Currency.usd,
      Currency.cop,
    ),
    RateSource(
      'cop-market',
      Currency.cop,
      'Mercado',
      'DolarAPI Colombia',
      Currency.usd,
      Currency.cop,
      category: SourceCategory.parallel,
    ),
    RateSource(
      'cop-manual',
      Currency.cop,
      'Manual',
      'Tu propia tasa en COP por USD',
      Currency.usd,
      Currency.cop,
      live: false,
      category: SourceCategory.manual,
    ),
    // BRL
    RateSource(
      'brl-br',
      Currency.brl,
      'Brasil',
      'Cotización oficial de Brasil',
      Currency.usd,
      Currency.brl,
    ),
    RateSource(
      'brl-manual',
      Currency.brl,
      'Manual',
      'Tu propia tasa en BRL por USD',
      Currency.usd,
      Currency.brl,
      live: false,
      category: SourceCategory.manual,
    ),
    // MXN
    RateSource(
      'mxn-banxico',
      Currency.mxn,
      'Banxico',
      'Banco de México',
      Currency.usd,
      Currency.mxn,
    ),
    RateSource(
      'mxn-manual',
      Currency.mxn,
      'Manual',
      'Tu propia tasa en MXN por USD',
      Currency.usd,
      Currency.mxn,
      live: false,
      category: SourceCategory.manual,
    ),
    // EUR: aristas emparejadas (familia misma fuente)
    RateSource(
      'eur-ves-oficial',
      Currency.eur,
      'Oficial a Bs',
      'EUR Oficial a Bs · BCV',
      Currency.eur,
      Currency.ves,
    ),
    RateSource(
      'eur-ves-paralelo',
      Currency.eur,
      'Paralelo a Bs',
      'EUR Paralelo a Bs · mercado',
      Currency.eur,
      Currency.ves,
      category: SourceCategory.parallel,
    ),
    RateSource(
      'eur-cop',
      Currency.eur,
      'a COP',
      'EUR a COP · DolarAPI Colombia',
      Currency.eur,
      Currency.cop,
    ),
    RateSource(
      'eur-brl',
      Currency.eur,
      'a BRL',
      'EUR a BRL · Brasil',
      Currency.eur,
      Currency.brl,
    ),
  ];

  static final Map<String, RateSource> byId = {for (final s in all) s.id: s};

  /// El store RECHAZA ids desconocidos (setRateBoard del web §2.1): una
  /// respuesta vieja con fuentes retiradas nunca entra al estado.
  static RateSource? of(String? id) =>
      id == null ? null : byId[id] ?? (id == 'usd' ? _usd : null);

  static const RateSource _usd = RateSource(
    'usd',
    Currency.usd,
    'Dólar',
    'Referencia',
    Currency.usd,
    Currency.usd,
  );

  static List<RateSource> sourcesFor(Currency c) =>
      all.where((s) => s.currency == c).toList();

  /// v15 oficiales por defecto (§1.10 DEFAULT_RATE_SOURCE).
  static const Map<Currency, String> defaultSource = {
    Currency.usd: 'usd',
    Currency.ves: 'ves-bcv',
    Currency.cop: 'cop-trm',
    Currency.eur: 'eur-ves-oficial',
    Currency.brl: 'brl-br',
    Currency.mxn: 'mxn-banxico',
  };

  /// ¿El id es válido para esta divisa (con fallback al default)?
  static String validSourceId(Currency c, String? id) {
    if (id == null) return defaultSource[c]!;
    final s = of(id);
    return (s != null && s.currency == c) ? s.id : defaultSource[c]!;
  }
}

/// Nombres cortos del grupo de fuentes en el Conversor (v15, sin repetir
/// palabras): «Dólar Oficial» (BCV) · «Dólar Paralelo» (mercado). v19.0: sin
/// la pseudo-fuente «usd» — 1 USD = 1 USD es obvio y no compite (orden del
/// dueño): el dólar es el puente de la app, no una fuente elegible.
const Map<String, String> convSourceNames = {
  'ves-bcv': 'Dólar Oficial',
  'ves-parallel': 'Dólar Paralelo',
  'ves-avg': 'Promedio',
  'ves-manual': 'Manual',
  'cop-trm': 'TRM',
  'cop-market': 'Mercado',
  'cop-manual': 'Manual',
  'brl-br': 'Real',
  'brl-manual': 'Manual',
  'mxn-banxico': 'Banxico',
  'mxn-manual': 'Manual',
  'eur-ves-oficial': 'EUR Oficial',
  'eur-ves-paralelo': 'EUR Paralelo',
  'eur-cop': 'EUR a COP',
  'eur-brl': 'EUR a BRL',
};

/// Plan de conversión (ConversionPlan del web v15): la tasa efectiva, la
/// ruta legible (`path` = divisas para las banderas), las fuentes usadas y
/// [direct] — true SOLO cuando el par tiene arista directa definida (la
/// «Tasa directa» del conversor); puente EUR y vía dólar son puentes.
class ConversionPlan {
  final double rate;
  final List<Currency> path;
  final List<String> sourceIds;
  final bool direct;

  const ConversionPlan({
    required this.rate,
    required this.path,
    required this.sourceIds,
    this.direct = false,
  });
}

/// Contexto de tasas resuelto (vivas + derivadas + manuales) y el motor de
/// conversión: arista directa · puente USD · EUR VISIBLE con resolveEur.
class RateContext {
  final Map<String, double> rates; // por id de fuente
  final Map<Currency, String> selected;

  const RateContext({required this.rates, required this.selected});

  double rate(String sourceId) => rates[sourceId] ?? 0;
  String sel(Currency c) => selected[c] ?? RateSource.defaultSource[c] ?? '';

  /// Tasa activa de la divisa (fuente seleccionada; live/derived/manual).
  double activeRate(Currency c) {
    if (c == Currency.usd) return 1;
    final id = sel(c);
    final def = RateSource.of(id);
    if (def?.category == SourceCategory.manual) return rate(id);
    if (id == 'ves-avg') return avgVes(); // SIEMPRE derivado, nunca de red
    return rate(id);
  }

  /// `ves-avg` derivado local: (BCV+paralelo)/2; si falta uno, el vivo.
  double avgVes() {
    final b = rate('ves-bcv'), p = rate('ves-parallel');
    if (b > 0 && p > 0) return (b + p) / 2;
    return b > 0 ? b : p;
  }

  /// Resuelve EUR → mejores aristas (familia emparejada EUR↔USD de la misma
  /// fuente: oficial↔BCV, paralelo↔paralelo, cop↔TRM, brl↔oficial).
  /// Devuelve además `pairId`: la fuente USD del puente (para pintar la ruta
  /// de 4 tramos completa: EUR → local → USD → destino).
  ({double eurPerUSD, RateSource edge, String pairId})? resolveEur() {
    const fallbackOrder = [
      'eur-ves-oficial',
      'eur-brl',
      'eur-cop',
      'eur-ves-paralelo',
    ];
    const pairSource = {
      'eur-ves-oficial': 'ves-bcv',
      'eur-ves-paralelo': 'ves-parallel',
      'eur-cop': 'cop-trm',
      'eur-brl': 'brl-br',
    };
    for (final id in [sel(Currency.eur), ...fallbackOrder]) {
      final def = RateSource.of(id);
      if (def == null || def.base != Currency.eur) continue;
      final r = rate(def.id);
      if (r <= 0) continue;
      final pairId = pairSource[def.id] ?? sel(def.quote);
      final pairDef = RateSource.of(pairId);
      if (pairDef == null ||
          pairDef.base != Currency.usd ||
          pairDef.quote != def.quote) {
        continue;
      }
      final q = rate(pairDef.id);
      if (q <= 0) continue;
      return (eurPerUSD: q / r, edge: def, pairId: pairDef.id);
    }
    return null;
  }

  /// Unidades de [c] por 1 USD (recursivo con guard anti-ciclo).
  double? unitsPerUSD(Currency c, [Set<Currency>? visited]) {
    if (c == Currency.usd) return 1;
    visited ??= {};
    if (visited.contains(c)) return null;
    visited.add(c);
    if (c == Currency.eur) return resolveEur()?.eurPerUSD;
    final def = RateSource.of(sel(c));
    if (def == null) return null;
    final r = rate(def.id);
    if (r <= 0) return null;
    if (def.category == SourceCategory.manual) return r;
    if (def.id == 'ves-avg') {
      final a = avgVes();
      return a > 0 ? a : null;
    }
    if (def.base == Currency.usd && def.quote == c) return r;
    final quoteU = unitsPerUSD(def.quote, visited);
    if (quoteU == null) return null;
    return quoteU / r;
  }

  /// Plan de conversión from → to con ruta legible:
  /// arista directa («Tasa directa», [ConversionPlan.direct]) · puente EUR
  /// VISIBLE con su ruta COMPLETA de 4 tramos (EUR → local → USD → destino)
  /// · vía dólar (puente invisible para no-EUR).
  ConversionPlan? plan(Currency from, Currency to) {
    // v19 (orden del dueño): un par IGUAL no es una conversión — 100 Bs son
    // 100 Bs; la app jamás ofrece «VES → VES». Se devuelve null y la UI
    // garantiza pares distintos (setConverterPair + selects con swap).
    if (from == to) return null;
    // 1) Arista directa definida por la fuente seleccionada de from/to.
    for (final c in [from, to]) {
      final def = RateSource.of(sel(c));
      if (def == null) continue;
      final r = rate(def.id);
      if (r <= 0) continue;
      if (def.base == from && def.quote == to) {
        return ConversionPlan(
          rate: r,
          path: [from, to],
          sourceIds: [def.id],
          direct: true,
        );
      }
      if (def.base == to && def.quote == from) {
        return ConversionPlan(
          rate: 1 / r,
          path: [from, to],
          sourceIds: [def.id],
          direct: true,
        );
      }
    }
    // 2) Puente EUR VISIBLE con ruta de 4 tramos: el cálculo real pasa
    //    EUR → local (arista EUR) → USD (fuente emparejada) → destino,
    //    y ahora se PINTA así (antes colapsaba a 2 banderas).
    if (from == Currency.eur && to != Currency.usd) {
      final eur = resolveEur();
      final tU = unitsPerUSD(to);
      if (eur != null && tU != null && tU > 0) {
        return ConversionPlan(
          rate: tU / eur.eurPerUSD,
          path: [from, eur.edge.quote, Currency.usd, to],
          sourceIds: [eur.edge.id, eur.pairId, sel(to)],
        );
      }
    }
    if (to == Currency.eur && from != Currency.usd) {
      final eur = resolveEur();
      final fU = unitsPerUSD(from);
      if (eur != null && fU != null && fU > 0) {
        return ConversionPlan(
          rate: eur.eurPerUSD / fU,
          path: [from, Currency.usd, eur.edge.quote, to],
          sourceIds: [sel(from), eur.pairId, eur.edge.id],
        );
      }
    }
    // 3) Vía dólar (puente invisible para no-EUR).
    final fU = unitsPerUSD(from), tU = unitsPerUSD(to);
    if (fU != null && fU > 0 && tU != null && tU > 0) {
      return ConversionPlan(
        rate: tU / fU,
        path: <Currency>[from, Currency.usd, to],
        sourceIds: [sel(from), sel(to)],
      );
    }
    return null;
  }

  /// Convierte amount en [from] → [to] con el plan activo (0 si no hay ruta).
  double convert(double amount, Currency from, Currency to) {
    if (amount <= 0 || from == to) return amount;
    final p = plan(from, to);
    return p == null ? 0 : amount * p.rate;
  }

  /// Normaliza cualquier monto a USD con la tasa activa (rate<=0 → 0).
  double toUSD(double amount, Currency currency) {
    if (currency == Currency.usd) return amount;
    final u = unitsPerUSD(currency);
    if (u == null || u <= 0) return 0;
    return amount / u;
  }

  /// Brecha paralelo vs oficial (VES) en % — sello del héroe y análisis.
  double? gapPct() {
    final b = rate('ves-bcv'), p = rate('ves-parallel');
    if (b <= 0 || p <= 0) return null;
    return (p / b - 1) * 100;
  }

  /// Divisas foco sin tasa viva ni manual (salta USD y las derivadas
  /// que se pueden derivar) — para el aviso honesto del tablero.
  List<Currency> missingFocusCurrencies() {
    final out = <Currency>[];
    for (final c in CurrencyX.focusMain) {
      final id = sel(c);
      if (id == 'ves-avg') continue; // derivable
      if (rate(id) <= 0) out.add(c);
    }
    return out;
  }
}

/// Montos rápidos por divisa (chips del conversor, §1.10 QUICK_AMOUNTS).
const Map<Currency, List<double>> quickAmounts = {
  Currency.usd: [1, 5, 10, 20, 50, 100],
  Currency.ves: [10, 50, 100, 500, 1000, 5000],
  Currency.cop: [5000, 10000, 20000, 50000, 100000, 200000],
  Currency.eur: [1, 5, 10, 20, 50, 100],
  Currency.brl: [5, 10, 20, 50, 100, 200],
  Currency.mxn: [20, 50, 100, 200, 500, 1000],
};

/// Ajustes rápidos del monto del conversor.
const List<({String label, double Function(double) apply})> quickAdjustments = [
  // v18.0 (orden del dueño): ±10 % primero, ±100 después — los porcentuales
  // son los ajustes de uso diario en el conversor.
  (label: '+10 %', apply: _pct10),
  (label: '−10 %', apply: _pct10down),
  (label: '+100', apply: _plus100),
  (label: '−100', apply: _minus100),
];

double _plus100(double v) => v + 100;
double _minus100(double v) => v - 100;
double _pct10(double v) => v * 1.10;
double _pct10down(double v) => v / 1.10;
