/// ─── VeTheme · la piel «Instrumento SaaS» sobre Material 3 nativo ──────────
/// QUÉ: la app viste Material 3 PURO (MaterialApp.router + AppTheme) y esta
/// fachada expone los tokens del diseño con la MISMA forma que consumía el
/// kit cuando vivía sobre shadcn/ui: `context.ve.colorScheme.primary`,
/// `context.ve.brightness` — cero cambios en las 102 llamadas de pantallas.
/// POR QUÉ: orden del dueño (v24) de construir la GUI sobre el Material 3
/// nativo de Flutter, más simple y mejor mantenido que la capa shadcn.
/// CONTRATO: los valores son EXACTAMENTE los de `VeColors` (theme.dart),
/// 1:1 con los roles CSS del prototipo Linear/Vercel — ni un tono nuevo.
/// `VeInk` (semántica de dinero) sigue viajando con el tema Material como
/// ThemeExtension, como siempre.
library;

import 'package:flutter/material.dart';

import 'theme.dart';

/// Radio firma (Linear/Vercel): tarjetas y popovers 10, controles 8.
/// Antes kVeRadius/kVeControlRadius — mismos números, dueño nuevo.
const double kVeRadius = 10;
const double kVeControlRadius = 8;

/// Esquema de la fachada: los mismos roles que el ShadColorScheme de la
/// era shadcn, con los tokens EXACTOS de VeColors por brillo.
class VeScheme {
  const VeScheme({
    required this.background,
    required this.foreground,
    required this.card,
    required this.cardForeground,
    required this.popover,
    required this.popoverForeground,
    required this.primary,
    required this.primaryForeground,
    required this.secondary,
    required this.secondaryForeground,
    required this.muted,
    required this.mutedForeground,
    required this.accent,
    required this.accentForeground,
    required this.destructive,
    required this.destructiveForeground,
    required this.border,
    required this.input,
    required this.ring,
    required this.selection,
  });

  final Color background;
  final Color foreground;
  final Color card;
  final Color cardForeground;
  final Color popover;
  final Color popoverForeground;
  final Color primary;
  final Color primaryForeground;
  final Color secondary;
  final Color secondaryForeground;
  final Color muted;
  final Color mutedForeground;
  final Color accent;
  final Color accentForeground;
  final Color destructive;
  final Color destructiveForeground;
  final Color border;
  final Color input;
  final Color ring;
  final Color selection;

  /// Alias Material de los roles que las pantallas ya usaban.
  Color get onSurface => foreground;
  Color get onSurfaceVariant => mutedForeground;
  Color get outlineVariant => border;
  Color get surfaceContainerLowest => card;

  static const VeScheme light = VeScheme(
    background: VeColors.bgLight,
    foreground: VeColors.fgLight,
    card: VeColors.cardLight,
    cardForeground: VeColors.fgLight,
    popover: VeColors.cardLight,
    popoverForeground: VeColors.fgLight,
    primary: VeColors.primaryLight,
    primaryForeground: VeColors.bgLight,
    secondary: VeColors.mutedLight,
    secondaryForeground: VeColors.fgLight,
    muted: VeColors.mutedLight,
    mutedForeground: VeColors.mutedFgLight,
    accent: VeColors.accentLight,
    accentForeground: VeColors.fgLight,
    destructive: VeColors.destructiveLight,
    destructiveForeground: Colors.white,
    border: VeColors.borderLight,
    input: VeColors.lineStrongLight,
    ring: VeColors.primaryLight,
    selection: Color(0x3309090B),
  );

  static const VeScheme dark = VeScheme(
    background: VeColors.bgDark,
    foreground: VeColors.fgDark,
    card: VeColors.cardDark,
    cardForeground: VeColors.fgDark,
    popover: VeColors.cardDark,
    popoverForeground: VeColors.fgDark,
    primary: VeColors.primaryDark,
    primaryForeground: VeColors.onPrimaryDark,
    secondary: VeColors.mutedDark,
    secondaryForeground: VeColors.fgDark,
    muted: VeColors.mutedDark,
    mutedForeground: VeColors.mutedFgDark,
    accent: VeColors.accentDark,
    accentForeground: VeColors.fgDark,
    destructive: VeColors.destructiveDark,
    destructiveForeground: VeColors.onPrimaryDark,
    border: VeColors.borderDark,
    input: VeColors.lineStrongDark,
    ring: VeColors.primaryDark,
    selection: Color(0x4DF4F4F5),
  );
}

/// Fachada del tema: `.colorScheme` (VeScheme) + `.brightness`, la misma
/// superficie que consumía `context.ve` — el rename es mecánico.
class VeThemeData {
  const VeThemeData({required this.colorScheme, required this.brightness});

  final VeScheme colorScheme;
  final Brightness brightness;

  static VeThemeData of(BuildContext context) {
    final b = Theme.of(context).brightness;
    return VeThemeData(
      colorScheme: b == Brightness.dark ? VeScheme.dark : VeScheme.light,
      brightness: b,
    );
  }
}

/// Acceso corto: `context.ve.colorScheme.primary` / `context.ve.brightness`.
extension VeThemeX on BuildContext {
  VeThemeData get ve => VeThemeData.of(this);
}
