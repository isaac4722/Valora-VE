/// ─── Modo Cachea (v27.3) ────────────────────────────────────────────────────
/// Simulador de compra con inicial + cuotas quincenales sin intereses, como
/// el esquema que Cashea popularizó en Venezuela. Es UN CÁLCULO: no procesa
/// pagos, no guarda tarjetas ni cobra nada. Se usa en la Lista para que el
/// usuario vea cuánto paga hoy y cuánto en cada cuota antes de decidir.
library;

/// Porcentajes de iniciales habituales en el mercado venezolano.
const List<int> kCacheaInitials = <int>[20, 30, 40, 50];

/// Cuotas quincenales sin intereses (3 · 6 · 9 · 12).
const List<int> kCacheaQuotas = <int>[3, 6, 9, 12];

/// Cotización Cachea: total, inicial y cuota. Todas las cifras salen de
/// reglas simples y sin intereses; el total final es el mismo total.
class CacheaQuote {
  const CacheaQuote({
    required this.total,
    required this.initialPct,
    required this.quotas,
  });

  final double total;
  final int initialPct;
  final int quotas;

  double get initial => total * initialPct / 100;
  double get remaining => total - initial;
  double get quota => remaining / quotas;

  /// La inicial + las cuotas: mismo total, cero intereses.
  double get totalWithInterest => total;

  /// Número de pagos (inicial incluida).
  int get payments => quotas + 1;
}

/// Cotiza una compra. Null si los datos no sirven (total <= 0, inicial fuera
/// de 0..100 o cuotas < 1). Nunca lanza.
CacheaQuote? cacheaQuote({
  required double total,
  required int initialPct,
  required int quotas,
}) {
  if (!total.isFinite || total <= 0) return null;
  if (initialPct < 0 || initialPct > 100) return null;
  if (quotas < 1) return null;
  return CacheaQuote(total: total, initialPct: initialPct, quotas: quotas);
}
