/// ─── ValoraVE · Formato es-VE (§3.3) ───────────────────────────────────────
/// «1.234,56» — punto de miles, coma decimal. COP 0 decimales, EUR tasas a 4.
/// Parsers tolerantes que aceptan «1.234,56», «1234.56», «$915,38», «Bs. 40».
library;

import 'package:intl/intl.dart';

import 'currencies.dart';
import 'models.dart';

const List<String> kMeses = [
  'enero',
  'febrero',
  'marzo',
  'abril',
  'mayo',
  'junio',
  'julio',
  'agosto',
  'septiembre',
  'octubre',
  'noviembre',
  'diciembre',
];

const List<String> kDias = [
  'lunes',
  'martes',
  'miércoles',
  'jueves',
  'viernes',
  'sábado',
  'domingo',
];

/// Número es-VE: 1.234,56 (negativos con − inicial).
String fmtNum(double v, {int decimals = 2}) {
  if (v.isNaN || v.isInfinite) return '—';
  final abs = v.abs();
  final nf = NumberFormat.decimalPatternDigits(
    locale: 'es_VE',
    decimalDigits: decimals.clamp(0, 6),
  );
  final s = nf.format(abs);
  return v < 0 ? '−$s' : s;
}

/// Decimales inteligentes (<1 → 4, <100 → 2, sino moneda; COP 0).
int smartDecimals(double v, Currency c) {
  if (c == Currency.cop) return 0;
  final abs = v.abs();
  if (abs > 0 && abs < 1) return 4;
  return c.decimals;
}

/// Monto de divisa con símbolo: «$ 915,38» · «Bs 10.000,00» · «COP 4.200.000».
String fmtCurrency(double v, Currency c, {bool withCode = false}) {
  final dec = smartDecimals(v, c);
  final n = fmtNum(v, decimals: dec);
  final sym = withCode ? c.code : c.symbol;
  return '$sym $n';
}

/// Alias del web: fmtMoney formatea tal cual sin símbolo.
String fmtMoney(double v, Currency c) =>
    fmtNum(v, decimals: smartDecimals(v, c));

/// USD explícito.
String fmtUSD(double v) => fmtCurrency(v, Currency.usd);

/// Bs explícito.
String fmtBS(double v) => fmtCurrency(v, Currency.ves);

/// Tasa: ≥100 → 2 dec · ≥1 → 4 dec · <1 → 6 dec.
String fmtRate(double v) {
  if (v.isNaN || v.isInfinite) return '—';
  final a = v.abs();
  final dec = a >= 100 ? 2 : (a >= 1 ? 4 : 6);
  return fmtNum(v, decimals: dec);
}

/// Tasa EUR: siempre 4 decimales (§3.3 fmtEurRate).
String fmtEurRate(double v) => fmtNum(v, decimals: 4);

/// Porcentaje con signo: «+2,1 %».
String fmtPct(double v, {int decimals = 1, bool forceSign = false}) {
  final s = fmtNum(v.abs(), decimals: decimals);
  final sign = v > 0 ? '+' : (v < 0 ? '−' : (forceSign ? '+' : ''));
  return '$sign$s %';
}

/// «02-feb-2026» (estilo del web es-VE).
String fmtDate(DateTime d) {
  const meses = [
    'ene',
    'feb',
    'mar',
    'abr',
    'may',
    'jun',
    'jul',
    'ago',
    'sep',
    'oct',
    'nov',
    'dic',
  ];
  return '${d.day.toString().padLeft(2, '0')}-${meses[d.month - 1]}-${d.year}';
}

/// «02-feb-2026 14:30».
String fmtDateTime(DateTime d) =>
    '${fmtDate(d)} ${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

/// Fecha larga: «sábado, 6 de septiembre de 2026».
String fmtDateLong(DateTime d) =>
    '${kDias[d.weekday - 1]}, ${d.day} de ${kMeses[d.month - 1]} de ${d.year}';

/// Mes corto: «sep».
String fmtMesCorto(int month) => kMeses[month - 1].substring(0, 3);

/// Saludo por hora.
String saludo(DateTime d) {
  if (d.hour < 12) return 'Buenos días';
  if (d.hour < 19) return 'Buenas tardes';
  return 'Buenas noches';
}

/// Días completos desde [then].
int daysSince(DateTime then, [DateTime? now]) {
  now ??= DateTime.now();
  return DateTime(
    now.year,
    now.month,
    now.day,
  ).difference(DateTime(then.year, then.month, then.day)).inDays;
}

/// «hace instantes / hace X min / hace X h / hace X d» (por fetchedAt).
String timeAgo(DateTime then, [DateTime? now]) {
  now ??= DateTime.now();
  final diff = now.difference(then);
  if (diff.inMinutes < 1) return 'hace instantes';
  if (diff.inMinutes < 60) return 'hace ${diff.inMinutes} min';
  if (diff.inHours < 24) return 'hace ${diff.inHours} h';
  if (diff.inDays < 30) return 'hace ${diff.inDays} d';
  return fmtDate(then);
}

/// Texto de arista: «1 USD = 915,38 VES».
String sourceEdgeText(RateSource s, double rate) =>
    '1 ${s.base.code} = ${s.currency == Currency.eur ? fmtEurRate(rate) : fmtRate(rate)} ${s.quote.code}';

/// Etiqueta de presentación + tamaño: «1 kg» · «2 L» · «Paquete 4 pzas».
String presentationLabel(Product p) {
  switch (p.presentation) {
    case Presentation.unit:
      return 'Unidad';
    case Presentation.weight:
      final g = p.size;
      if (g >= 1000) {
        return '${fmtNum(g / 1000, decimals: g % 1000 == 0 ? 0 : 2)} kg';
      }
      return '${fmtNum(g, decimals: 0)} g';
    case Presentation.volume:
      final ml = p.size;
      if (ml >= 1000) {
        return '${fmtNum(ml / 1000, decimals: ml % 1000 == 0 ? 0 : 2)} L';
      }
      return '${fmtNum(ml, decimals: 0)} ml';
    case Presentation.pack:
      return 'Paquete · ${fmtNum(p.size, decimals: 0)} pzas';
  }
}

/// Unidad base del producto ('kg', 'L', 'pza'…).
String baseUnitLabel(Product p) => switch (p.presentation) {
  Presentation.unit => 'pza',
  Presentation.weight => 'kg',
  Presentation.volume => 'L',
  Presentation.pack => 'pza',
};

/// Precio por unidad base (USD): g→kg, ml→L, pzas→pza.
double? pricePerBase(PriceRecord r, Product p) {
  if (p.size <= 0) return null;
  switch (p.presentation) {
    case Presentation.weight:
      return r.price * 1000 / p.size;
    case Presentation.volume:
      return r.price * 1000 / p.size;
    case Presentation.unit:
    case Presentation.pack:
      return r.price / p.size;
  }
}

// ─── Parsers tolerantes (§3.3 parseLocaleNum / parseDecimal) ───────────────

/// Acepta «1.234,56», «1234.56», «1 234», «$915,38», «Bs. 40», «-5%».
/// Devuelve null si no hay cifra interpretable.
double? parseLocaleNum(String? raw) {
  if (raw == null) return null;
  var s = raw.trim();
  if (s.isEmpty) return null;
  s = s.replaceAll(RegExp(r'[\s\u00A0]'), '');
  s = s.replaceAll(RegExp(r'[^0-9.,\u2212\-+]'), ''); // deja $ fuera
  s = s.replaceAll(
    RegExp(r'^[.,]+'),
    '',
  ); // «Bs. 40» → «40» (punto suelto inicial)
  if (s.isEmpty) return null;
  // Detección de separador decimal: la ÚLTIMA coma o punto gana.
  final lastComma = s.lastIndexOf(',');
  final lastDot = s.lastIndexOf('.');
  String normalized;
  if (lastComma > lastDot) {
    // coma decimal: quita puntos de miles y cambia coma por punto.
    normalized = s.replaceAll('.', '').replaceAll(',', '.');
  } else if (lastDot > lastComma) {
    final decimals = s.length - lastDot - 1;
    // v19.6 (bug del dueño): misma regla que MoneyField._canon — sin coma
    // en el texto, un punto con 3+ dígitos detrás es MILES («4.0000» tras
    // el 5.º tecleo = 40000, no 4), salvo cero inicial («0.0001» es una
    // tasa chiquita, no 1).
    final intPart = s.substring(0, lastDot).replaceAll(RegExp(r'[^0-9]'), '');
    final intIsZero = RegExp(r'^0*$').hasMatch(intPart);
    final isThousandSep =
        lastDot > 0 && decimals >= 3 && !s.contains(',') && !intIsZero;
    // «1.234» es ambiguo: si hay coma ANTES del punto, el punto es decimal.
    if (lastComma >= 0) {
      normalized = s.replaceAll('.', '').replaceAll(',', '.');
    } else if (isThousandSep) {
      normalized = s.replaceAll('.', '');
    } else {
      normalized = s; // punto decimal
    }
  } else {
    normalized = s;
  }
  normalized = normalized.replaceAll('−', '-');
  return double.tryParse(normalized);
}

/// Parser de fecha ISO local (YYYY-MM-DD) o ISO completo; null si inválida.
DateTime? parseDateField(dynamic v) {
  if (v is DateTime) return v;
  if (v is! String || v.isEmpty) return null;
  return DateTime.tryParse(v);
}

// ─── CSV (§3.3): delim «,»/«;», comillas «""», BOM opcional ────────────────

/// Serializa filas a CSV (escapa con «""» y saltos dentro de comillas).
String toCSV(List<List<String>> rows, {String delimiter = ','}) {
  String esc(String cell) {
    final s = cell;
    if (s.contains(delimiter) || s.contains('"') || s.contains('\n')) {
      return '"${s.replaceAll('"', '""')}"';
    }
    return s;
  }

  return rows.map((r) => r.map(esc).join(delimiter)).join('\n');
}

/// Parsea CSV tolerante: detecta delimitador, soporta «""» y \n embebido.
List<List<String>> parseCSV(String text) {
  var input = text;
  if (input.startsWith('\ufeff')) input = input.substring(1);
  // Delimitador: el que más aparezca fuera de comillas (aprox: total).
  final semis = ';'.allMatches(input).length;
  final commas = ','.allMatches(input).length;
  final delimiter = semis > commas ? ';' : ',';

  final rows = <List<String>>[];
  final row = <String>[];
  final cell = StringBuffer();
  var inQuotes = false;
  var i = 0;
  String? peek(int ahead) => i + ahead < input.length ? input[i + ahead] : null;
  while (i < input.length) {
    final ch = input[i];
    if (inQuotes) {
      if (ch == '"') {
        if (peek(1) == '"') {
          cell.write('"');
          i += 2;
          continue;
        }
        inQuotes = false;
        i++;
        continue;
      }
      cell.write(ch);
      i++;
      continue;
    }
    if (ch == '"') {
      inQuotes = true;
      i++;
    } else if (ch == delimiter) {
      row.add(cell.toString());
      cell.clear();
      i++;
    } else if (ch == '\n' || ch == '\r') {
      row.add(cell.toString());
      cell.clear();
      rows.add(List<String>.from(row)); // copia (row se reutiliza)
      row.clear();
      if (ch == '\r' && peek(1) == '\n') i++;
      i++;
    } else {
      cell.write(ch);
      i++;
    }
  }
  if (cell.isNotEmpty || row.isNotEmpty) {
    row.add(cell.toString());
    rows.add(row);
  }
  return rows
      .map((r) => r.map((c) => c.trim()).toList())
      .where((r) => r.any((c) => c.isNotEmpty))
      .toList();
}

/// Normaliza texto para búsqueda sin acentos (fold).
String fold(String s) {
  final lower = s.toLowerCase();
  const withDiacritics = 'áéíóúüñÁÉÍÓÚÜÑ';
  const without = 'aeiouunaeiouun';
  final sb = StringBuffer();
  for (final ch in lower.runes) {
    final c = String.fromCharCode(ch);
    final idx = withDiacritics.indexOf(c);
    sb.write(idx >= 0 ? without[idx] : c);
  }
  return sb.toString();
}

// ─── Fechas ISO locales ────────────────────────────────────────────────────

/// ISO local sin zona (YYYY-MM-DD) — la clave de los snapshots.
String isoDay(DateTime d) => SnapshotPoint.dayKey(d);

/// Rótulo «DD/MM/YYYY» para campos de fecha.
String fmtFechaCampo(DateTime? d) => d == null
    ? ''
    : '${d.day.toString().padLeft(2, '0')}/${d.month.toString().padLeft(2, '0')}/${d.year}';
