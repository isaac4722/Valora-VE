/// ─── Insignia de banco (v27.1 · REA del APK de CalculaYa 1.1.0) ───────────
/// Las cuentas de cobro se leen de un vistazo: cada banco lleva su insignia
/// REAL de `assets/banks/` (27 PNG del APK de CalculaYa, normalizados a
/// 128×128). Debajo vive un monograma original sobre el color de marca:
/// si el PNG tarda en decodificar o falta, la fila nunca queda con un hueco.
library;

import 'package:flutter/material.dart';

import '../core/banks_ve.dart';

class BankBadge extends StatelessWidget {
  const BankBadge({super.key, required this.bank, this.size = 32});

  final String bank;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = kBankBadgeAssets[bank];
    final color = Color(kBankBadgeColors[bank] ?? 0xFF09090B);
    final initials = bankInitials(bank);
    return Semantics(
      label: bank,
      image: true,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(size * 0.24),
        child: SizedBox(
          width: size,
          height: size,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: color,
                child: Center(
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
              ),
              if (asset != null)
                Image.asset(
                  asset,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => const SizedBox.shrink(),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
