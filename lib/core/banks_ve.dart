/// ─── Catálogo de bancos de Venezuela (código SUDEBAN para Pago Móvil) ─────
/// Dato público (tablas oficiales de código de banco usadas en Pago Móvil).
/// Sin logos de terceros: texto + código (decisión Q1 del design doc
/// docs/designs/2026-11-20-gui-simple.md — no engordar el APK).
library;

class VeBank {
  final String code; // 4 dígitos SUDEBAN
  final String name;
  const VeBank(this.code, this.name);
}

const List<VeBank> kVeBanks = [
  VeBank('0102', 'Banco de Venezuela'),
  VeBank('0104', 'Banco Venezolano de Crédito'),
  VeBank('0105', 'Mercantil'),
  VeBank('0106', 'Provincial (BBVA)'),
  VeBank('0107', 'Banco Caroní'),
  VeBank('0108', 'Banco Exterior'),
  VeBank('0109', 'BOD (Occidental de Descuento)'),
  VeBank('0111', 'BNC (Nacional de Crédito)'),
  VeBank('0114', 'Banco Caribe'),
  VeBank('0134', 'Banesco'),
  VeBank('0137', 'Sofitasa'),
  VeBank('0138', 'Banco Plaza'),
  VeBank('0151', 'BFC Banco Fondo Común'),
  VeBank('0156', '100% Banco'),
  VeBank('0157', 'Banco del Tesoro'),
  VeBank('0158', 'Bancrecer'),
  VeBank('0160', 'Banco Activo'),
  VeBank('0163', 'Banco Agrícola'),
  VeBank('0166', 'BANAP (Nacional de Ahorro y Préstamo)'),
  VeBank('0168', 'Banplus'),
  VeBank('0171', 'Banco Internacional de Desarrollo'),
  VeBank('0172', 'Bancamiga'),
  VeBank('0173', 'Bancaribe'),
  VeBank('0174', 'Banfanb'),
  VeBank('0601', 'IMCP (Instituto Municipal de Crédito Popular)'),
];

/// Nombre corto del banco por código (null si no está en el catálogo).
String? veBankName(String code) {
  for (final b in kVeBanks) {
    if (b.code == code) return b.name;
  }
  return null;
}
