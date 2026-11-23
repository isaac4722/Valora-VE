/// ─── Tests de la fachada VeTheme (v24 · Material 3 nativo) ─────────────────
/// Guardián del contrato de la piel:
/// 1. Los tokens de VeScheme son EXACTAMENTE los de VeColors (la orden del
///    dueño: «ni un tono nuevo») en ambos brillos.
/// 2. Radii firma Linear/Vercel: tarjetas 10 · controles 8.
/// 3. `context.ve` resuelve por el brillo del ThemeData real.
/// 4. AppTheme (Material puro) conserva VeInk — la semántica de dinero.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/core/ve_theme.dart';

void main() {
  group('VeScheme · colores del diseño vigente, sin uno nuevo', () {
    test('claro mapea 1:1 los tokens VeColors', () {
      final s = VeScheme.light;
      expect(s.background, VeColors.bgLight);
      expect(s.foreground, VeColors.fgLight);
      expect(s.card, VeColors.cardLight);
      expect(s.cardForeground, VeColors.fgLight);
      expect(s.popover, VeColors.cardLight);
      expect(s.popoverForeground, VeColors.fgLight);
      expect(s.primary, VeColors.primaryLight);
      // Primario invertido del prototipo (bg fg / texto bg).
      expect(s.primaryForeground, VeColors.bgLight);
      expect(s.secondary, VeColors.mutedLight);
      expect(s.muted, VeColors.mutedLight);
      expect(s.mutedForeground, VeColors.mutedFgLight);
      expect(s.accent, VeColors.accentLight);
      expect(s.border, VeColors.borderLight);
      expect(s.input, VeColors.lineStrongLight);
      expect(s.ring, VeColors.primaryLight);
      expect(s.destructive, VeColors.destructiveLight);
      expect(s.selection, const Color(0x3309090B));
    });

    test('oscuro mapea 1:1 los tokens VeColors', () {
      final s = VeScheme.dark;
      expect(s.background, VeColors.bgDark);
      expect(s.foreground, VeColors.fgDark);
      expect(s.card, VeColors.cardDark);
      expect(s.primary, VeColors.primaryDark);
      expect(s.primaryForeground, VeColors.onPrimaryDark);
      expect(s.mutedForeground, VeColors.mutedFgDark);
      expect(s.accent, VeColors.accentDark);
      expect(s.border, VeColors.borderDark);
      expect(s.input, VeColors.lineStrongDark);
      expect(s.destructive, VeColors.destructiveDark);
      expect(s.selection, const Color(0x4DF4F4F5));
    });

    test('alias Material apuntan a los tokens correctos', () {
      const s = VeScheme.light;
      expect(s.onSurface, s.foreground);
      expect(s.onSurfaceVariant, s.mutedForeground);
      expect(s.outlineVariant, s.border);
      expect(s.surfaceContainerLowest, s.card);
    });
  });

  group('Radii firma Linear/Vercel', () {
    test('tarjetas 10 · controles 8', () {
      expect(kVeRadius, 10);
      expect(kVeControlRadius, 8);
    });
  });

  group('context.ve · resuelve por brillo', () {
    testWidgets('claro y oscuro en el mismo árbol', (tester) async {
      late Brightness vistoClaro;
      late Brightness vistoOscuro;
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          home: Builder(
            builder: (context) {
              vistoClaro = context.ve.brightness;
              return MaterialApp(
                theme: AppTheme.dark(),
                home: Builder(
                  builder: (context) {
                    vistoOscuro = context.ve.brightness;
                    return const SizedBox.shrink();
                  },
                ),
              );
            },
          ),
        ),
      );
      expect(vistoClaro, Brightness.light);
      expect(vistoOscuro, Brightness.dark);
    });
  });

  group('AppTheme · VeInk viaja con el tema Material', () {
    test('claro y oscuro registran la semántica de dinero', () {
      expect(AppTheme.light().extension<VeInk>(), isNotNull);
      expect(AppTheme.dark().extension<VeInk>(), isNotNull);
      expect(AppTheme.light().extension<VeInk>()!.pos, VeColors.posLight);
      expect(AppTheme.dark().extension<VeInk>()!.pos, VeColors.posDark);
      expect(AppTheme.dark().extension<VeInk>()!.usdt, VeColors.usdtDark);
    });
  });
}
