/// ─── Insignia de banco (v27) ───────────────────────────────────────────────
/// Las cuentas de cobro se leen de un vistazo: cada banco lleva una insignia
/// ORIGINAL (monograma sobre su color de marca) pintada en Flutter. No son
/// logos oficiales ni activos de terceros: el nombre siempre acompaña a la
/// insignia y el dato que importa sigue siendo el número de cuenta.
library;

import 'package:flutter/material.dart';

import '../core/banks_ve.dart';

class BankBadge extends StatelessWidget {
  const BankBadge({super.key, required this.bank, this.size = 32});

  final String bank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = Color(kBankBadgeColors[bank] ?? 0xFF09090B);
    final initials = bankInitials(bank);
    return Semantics(
      label: bank,
      image: true,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(size * 0.26),
          border: Border.all(
            color: Colors.white.withValues(alpha: 0.18),
            width: size * 0.035,
          ),
        ),
        child: Text(
          initials,
          maxLines: 1,
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: size * (initials.length > 3 ? 0.22 : 0.29),
            fontWeight: FontWeight.w700,
            color: Colors.white,
            height: 1,
            letterSpacing: -0.3,
          ),
        ),
      ),
    );
  }
}
