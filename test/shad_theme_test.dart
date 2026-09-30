/// ─── Tests de las fundaciones shadcn (TASK-33) ──────────────────────────────
/// Cobertura del contrato de la pieza 1:
/// 1. Los tokens de color shadcn son EXACTAMENTE los de VeColors (la orden
///    del dueño fue «solo del actual se mantendrán los colores» — este test
///    es el guardián de esa regla en ambos temas).
/// 2. Los temas ShadThemeVe construyen con el gusto Linear/Vercel pactado
///    (radio 10, sin borde secundario, Inter + estilos firma).
/// 3. El puente Material (veMaterialBridge) conserva VeInk y el look vigente
///    para las pantallas no migradas.
/// 4. La app arranca bajo ShadApp con ambos temas sin romper.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/core/shad_theme.dart';
import 'package:valorave/core/theme.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

void main() {
  group('VeShadColors · colores del diseño vigente, sin uno nuevo', () {
    test('tema claro mapea 1:1 los tokens VeColors', () {
      final s = VeShadColors.light();
      expect(s.background, VeColors.bgLight);
      expect(s.foreground, VeColors.fgLight);
      expect(s.card, VeColors.cardLight);
      expect(s.cardForeground, VeColors.fgLight);
      expect(s.popover, VeColors.cardLight);
      expect(s.popoverForeground, VeColors.fgLight);
      expect(s.primary, VeColors.primaryLight);
      expect(s.primaryForeground, Colors.white);
      expect(s.secondary, VeColors.mutedLight);
      expect(s.secondaryForeground, VeColors.fgLight);
      expect(s.muted, VeColors.mutedLight);
      expect(s.mutedForeground, VeColors.mutedFgLight);
      expect(s.accent, VeColors.accentLight);
      expect(s.accentForeground, VeColors.fgLight);
      expect(s.destructive, VeColors.destructiveLight);
      expect(s.destructiveForeground, Colors.white);
      expect(s.border, VeColors.borderLight);
      expect(s.input, VeColors.borderLight);
      expect(s.ring, VeColors.primaryLight);
    });

    test('tema grafito mapea 1:1 los tokens VeColors', () {
      final s = VeShadColors.dark();
      expect(s.background, VeColors.bgDark);
      expect(s.foreground, VeColors.fgDark);
      expect(s.card, VeColors.cardDark);
      expect(s.cardForeground, VeColors.fgDark);
      expect(s.popover, VeColors.cardDark);
      expect(s.popoverForeground, VeColors.fgDark);
      expect(s.primary, VeColors.primaryDark);
      expect(s.primaryForeground, VeColors.onPrimaryDark);
      expect(s.secondary, VeColors.mutedDark);
      expect(s.secondaryForeground, VeColors.fgDark);
      expect(s.muted, VeColors.mutedDark);
      expect(s.mutedForeground, VeColors.mutedFgDark);
      expect(s.accent, VeColors.accentDark);
      expect(s.accentForeground, VeColors.fgDark);
      expect(s.destructive, VeColors.destructiveDark);
      expect(s.destructiveForeground, VeColors.onPrimaryDark);
      expect(s.border, VeColors.borderDark);
      expect(s.input, VeColors.borderDark);
      expect(s.ring, VeColors.primaryDark);
    });
  });

  group('ShadThemeVe · gusto Linear/Vercel pactado', () {
    test('claro: brillo, radio firma, sin borde secundario, Inter', () {
      final t = ShadThemeVe.light();
      expect(t.brightness, Brightness.light);
      expect(t.radius, BorderRadius.circular(kShadRadius));
      expect(t.disableSecondaryBorder, isTrue);
      expect(t.textTheme.family, 'Inter');
    });

    test('oscuro: ídem grafito', () {
      final t = ShadThemeVe.dark();
      expect(t.brightness, Brightness.dark);
      expect(t.radius, BorderRadius.circular(kShadRadius));
      expect(t.disableSecondaryBorder, isTrue);
    });

    test('estilos firma viajan como custom: displayNum y labelCaps', () {
      for (final t in [ShadThemeVe.light(), ShadThemeVe.dark()]) {
        final display = t.textTheme.custom['displayNum'];
        expect(display, isNotNull);
        expect(display!.fontFamily, 'SpaceGrotesk');
        expect(
          display.fontFeatures,
          contains(const FontFeature.tabularFigures()),
        );
        expect(display.fontSize, 28);
        final hero = t.textTheme.custom['displayNumHero'];
        expect(hero!.fontSize, 44);
        final caps = t.textTheme.custom['labelCaps'];
        expect(caps, isNotNull);
      }
    });

    testWidgets('ShadApp arranca y expone el esquema ValoraVE', (tester) async {
      late ShadThemeData capturado;
      await tester.pumpWidget(
        ShadApp(
          theme: ShadThemeVe.light(),
          darkTheme: ShadThemeVe.dark(),
          themeMode: ThemeMode.dark,
          home: Builder(
            builder: (context) {
              capturado = ShadTheme.of(context);
              return const Scaffold(body: SizedBox.shrink());
            },
          ),
        ),
      );
      await tester.pump();
      expect(capturado.colorScheme.background, VeColors.bgDark);
      expect(capturado.colorScheme.primary, VeColors.primaryDark);
    });
  });

  group('veMaterialBridge · compatibilidad con lo no migrado', () {
    test('inyecta el AppTheme vigente con la semántica VeInk', () {
      for (final brightness in [Brightness.light, Brightness.dark]) {
        final m = veMaterialBridge(brightness, null);
        final ink = m.extension<VeInk>();
        expect(ink, isNotNull, reason: 'VeInk debe viajar en el tema Material');
        expect(
          m.scaffoldBackgroundColor,
          brightness == Brightness.dark
              ? VeColors.bgDark
              : VeColors.bgLight,
        );
        expect(
          m.textTheme.bodyMedium?.fontFamily,
          'Inter',
          reason: 'El cuerpo Material sigue tipografiándose con Inter',
        );
      }
    });

    test('Material You solo tiñe el par primario (contrato dp6)', () {
      final dinamico = ColorScheme.fromSeed(
        seedColor: const Color(0xFF00FF00),
        brightness: Brightness.light,
      );
      final m = veMaterialBridge(Brightness.light, dinamico);
      expect(m.colorScheme.primary, dinamico.primary);
      // Superficies y semántica de dinero siguen siendo de marca.
      expect(m.scaffoldBackgroundColor, VeColors.bgLight);
      expect(m.extension<VeInk>()!.pos, VeColors.posLight);
    });
  });
}
