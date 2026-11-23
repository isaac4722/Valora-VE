/// ─── Bancos de Venezuela para Pago Móvil (v23 · comparativa CalculaYa) ──────
///
/// Nombres público-universales de los bancos con pago móvil del país, en el
/// idioma coloquial con que la gente los nombra. SIN logos ni códigos: son
/// marcas y activos de terceros (CalculaYa empaqueta 27 PNG; ValoraVE no
/// engorda el APK con assets ajenos) y el mensaje de cobro se entiende con
/// el nombre del banco + los datos que el usuario guarda.
///
/// Procedencia: los mismos 27 bancos que CalculaYa 1.1.0 lista para pago
/// móvil (verificados contra su APK — assets/banks), que es la lista real
/// de bancos con pago móvil en Venezuela.
library;

const List<String> kVkBanks = <String>[
  '100% Banco',
  'Banco Activo',
  'Banco Agrícola de Venezuela',
  'Banco del Caroní',
  'Banco del Tesoro',
  'Banco de Venezuela (BDV)',
  'Banco Digital de los Trabajadores',
  'Banco Exterior',
  'Banco Internacional de Desarrollo (BID)',
  'Banco Nacional de Crédito (BNC)',
  'Banco Plaza',
  'Banco Provincial (BBVA)',
  'Banco Venezolano de Crédito',
  'Bancamiga',
  'Bancaribe',
  'Bancrecer',
  'Banesco',
  'Banfanb',
  'Bangente',
  'Banplus',
  'BFC Banco Fondo Común',
  'DelSur Banco Universal',
  'Instituto Municipal de Crédito Popular (IMCP)',
  'Mercantil',
  'Mi Banco',
  'N58 Banco',
  'Sofitasa',
];

/// Color de marca de cada banco para su insignia original (v27). La clave
/// es el nombre EXACTO de [kVkBanks]. No son logos oficiales: la insignia
/// es un monograma pintado en Flutter sobre este color, para lectura rápida
/// sin empaquetar activos de terceros.
const Map<String, int> kBankBadgeColors = <String, int>{
  '100% Banco': 0xFFB3261E,
  'Banco Activo': 0xFF0B6FA4,
  'Banco Agrícola de Venezuela': 0xFF2E7D32,
  'Banco del Caroní': 0xFFD97706,
  'Banco del Tesoro': 0xFF1E4E8C,
  'Banco de Venezuela (BDV)': 0xFFC62828,
  'Banco Digital de los Trabajadores': 0xFF1565C0,
  'Banco Exterior': 0xFF0F4C81,
  'Banco Internacional de Desarrollo (BID)': 0xFF1A5DAB,
  'Banco Nacional de Crédito (BNC)': 0xFFB71C1C,
  'Banco Plaza': 0xFF2E7D32,
  'Banco Provincial (BBVA)': 0xFF0B4F8A,
  'Banco Venezolano de Crédito': 0xFF1B7E4B,
  'Bancamiga': 0xFFE07A1F,
  'Bancaribe': 0xFF0E5A8A,
  'Bancrecer': 0xFFB3261E,
  'Banesco': 0xFFC62828,
  'Banfanb': 0xFF2E7D32,
  'Bangente': 0xFF0B6FA4,
  'Banplus': 0xFF0F4C81,
  'BFC Banco Fondo Común': 0xFF1E4E8C,
  'DelSur Banco Universal': 0xFF2E7D32,
  'Instituto Municipal de Crédito Popular (IMCP)': 0xFF0B4F8A,
  'Mercantil': 0xFF0B4F8A,
  'Mi Banco': 0xFF1565C0,
  'N58 Banco': 0xFF1A5DAB,
  'Sofitasa': 0xFF2E7D32,
};

/// Insignias REALES por banco (v27.1 · REA del APK de CalculaYa 1.1.0):
/// los 27 PNG originales, normalizados a 128×128 sobre fondo blanco para
/// que la fila respire. La clave es el nombre EXACTO de [kVkBanks].
const Map<String, String> kBankBadgeAssets = <String, String>{
  '100% Banco': 'assets/banks/100-banco.png',
  'Banco Activo': 'assets/banks/banco-activo.png',
  'Banco Agrícola de Venezuela': 'assets/banks/banco-agricola.png',
  'Banco del Caroní': 'assets/banks/banco-del-caroni.png',
  'Banco del Tesoro': 'assets/banks/banco-del-tesoro.png',
  'Banco de Venezuela (BDV)': 'assets/banks/banco-de-venezuela.png',
  'Banco Digital de los Trabajadores':
      'assets/banks/banco-digital-trabajadores.png',
  'Banco Exterior': 'assets/banks/banco-exterior.png',
  'Banco Internacional de Desarrollo (BID)': 'assets/banks/bid.png',
  'Banco Nacional de Crédito (BNC)': 'assets/banks/bnc.png',
  'Banco Plaza': 'assets/banks/banco-plaza.png',
  'Banco Provincial (BBVA)': 'assets/banks/banco-provincial.png',
  'Banco Venezolano de Crédito': 'assets/banks/bvc.png',
  'Bancamiga': 'assets/banks/bancamiga.png',
  'Bancaribe': 'assets/banks/bancaribe.png',
  'Bancrecer': 'assets/banks/bancrecer.png',
  'Banesco': 'assets/banks/banesco.png',
  'Banfanb': 'assets/banks/banfanb.png',
  'Bangente': 'assets/banks/bangente.png',
  'Banplus': 'assets/banks/banplus.png',
  'BFC Banco Fondo Común': 'assets/banks/bfc.png',
  'DelSur Banco Universal': 'assets/banks/delsur.png',
  'Instituto Municipal de Crédito Popular (IMCP)': 'assets/banks/imcp.png',
  'Mercantil': 'assets/banks/mercantil.png',
  'Mi Banco': 'assets/banks/mi-banco.png',
  'N58 Banco': 'assets/banks/n58.png',
  'Sofitasa': 'assets/banks/sofitasa.png',
};

/// Iniciales cortas para el fallback sin asset (nunca debería pasar con el
/// catálogo completo, pero la UI no puede depender de un PNG).
String bankInitials(String bank) {
  final words = bank
      .replaceAll(RegExp(r'\([^)]*\)'), '')
      .split(RegExp(r'\s+'))
      .where((w) => w.isNotEmpty)
      .toList();
  if (words.isEmpty) return 'B';
  final stop = {'de', 'del', 'la', 'los', 'las', 'el'};
  final sig = words.where((w) => !stop.contains(w.toLowerCase())).toList();
  final src = sig.isEmpty ? words : sig;
  if (src.length == 1) {
    return src.first.length <= 3
        ? src.first.toUpperCase()
        : src.first.substring(0, 3).toUpperCase();
  }
  // Siglas explícitas al inicio (BFC, N58, 100 %) se respetan.
  if (RegExp(r'^[A-Z0-9%]{2,4}$').hasMatch(src.first)) return src.first;
  return src.take(3).map((w) => w[0].toUpperCase()).join();
}
