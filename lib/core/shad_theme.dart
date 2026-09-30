/// ─── ShadTheme «Instrumento SaaS» · GUI Linear/Vercel (TASK-33) ─────────────
/// QUÉ: fundaciones del rediseño ordenado por el dueño — la capa shadcn/ui
/// (paquete `shadcn_ui`) que viste la app con el lenguaje «modern minimal
/// SaaS» de Linear/Vercel: superficies planas, bordes 100 %, tipografía
/// Inter/Space Grotesk, cero adornos.
/// POR QUÉ: orden expresa del dueño (TASK-33) de reconstruir la GUI sobre el
/// plugin de shadcn manteniendo SOLO los colores del diseño vigente. Los
/// tokens de color son EXACTAMENTE los de `VeColors` (theme.dart): papel-tinta
/// claro canónico y grafito oscuro — ni un tono nuevo, ni una opacidad nueva.
/// CONTRATO: `AppTheme` (Material) sigue vivo para las pantallas no migradas
/// vía `materialThemeBuilder` — cero regresión visual durante la transición.
/// La semántica de dinero (VeInk) y las transiciones de página firma viajan
/// con el tema Material como siempre.
library;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'theme.dart';

/// Radio firma del rediseño (Linear/Vercel): tarjetas y popovers 10,
/// controles 8. Un solo número, cero radios mágicos.
const double kShadRadius = 10;
const double kShadControlRadius = 8;

/// Esquema de color shadcn con los tokens EXACTOS de ValoraVE.
///
/// Mapeo 1:1 de los roles de `docs/DESIGN-SYSTEM.md` a los roles CSS de
/// shadcn/ui. El color de datos (oficial/paralelo, sube/baja) sigue viviendo
/// en `VeInk` — el esquema shadcn solo viste superficies y acciones.
abstract final class VeShadColors {
  VeShadColors._();

  /// Claro (canónico) — papel-tinta.
  static ShadColorScheme light() => const ShadColorScheme(
    background: VeColors.bgLight,
    foreground: VeColors.fgLight,
    card: VeColors.cardLight,
    cardForeground: VeColors.fgLight,
    popover: VeColors.cardLight,
    popoverForeground: VeColors.fgLight,
    primary: VeColors.primaryLight,
    primaryForeground: Colors.white,
    secondary: VeColors.mutedLight,
    secondaryForeground: VeColors.fgLight,
    muted: VeColors.mutedLight,
    mutedForeground: VeColors.mutedFgLight,
    accent: VeColors.accentLight,
    accentForeground: VeColors.fgLight,
    destructive: VeColors.destructiveLight,
    destructiveForeground: Colors.white,
    border: VeColors.borderLight,
    input: VeColors.borderLight,
    ring: VeColors.primaryLight,
    selection: Color(0x3322354E),
  );

  /// Grafito (oscuro) — frío, sin negro puro.
  static ShadColorScheme dark() => const ShadColorScheme(
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
    input: VeColors.borderDark,
    ring: VeColors.primaryDark,
    selection: Color(0x4D8FA7C4),
  );
}

/// Tipografía shadcn de la app: Inter de cuerpo + estilos firma del repo
/// («displayNum» con cifras tabulares de Space Grotesk, «labelCaps» para
/// rótulos técnicos) como estilos custom — la escala h1–muted de shadcn se
/// queda de fábrica para no inventar una escala paralela.
ShadTextTheme _textTheme(Color fg, Color mutedFg) => ShadTextTheme(
  family: 'Inter',
  custom: {
    'displayNum': VeText.displayNum(28, color: fg),
    'displayNumHero': VeText.displayNum(44, color: fg),
    'labelCaps': VeText.labelCaps(10, color: mutedFg),
  },
);

/// Borde plano Linear/Vercel: un solo lado al 100 % de opacidad.
ShadBorder _flatBorder(Color color, {double radius = kShadControlRadius}) =>
    ShadBorder.fromBorderSide(
      ShadBorderSide(color: color, width: 1),
      radius: BorderRadius.circular(radius),
    );

/// Tema shadcn completo «Linear/Vercel» para cada brillo.
///
/// Decisiones de gusto (orden del dueño TASK-33): bordes secundarios
/// DESACTIVADOS (superficie plana), sombras fuera de los controles, botones
/// compactos (36 regular · 30 sm · 42 lg), tooltips de tinta invertida y
/// separadores al borde 100 %.
abstract final class ShadThemeVe {
  ShadThemeVe._();

  static ShadThemeData light() =>
      _build(colorScheme: VeShadColors.light(), brightness: Brightness.light);

  static ShadThemeData dark() =>
      _build(colorScheme: VeShadColors.dark(), brightness: Brightness.dark);

  static ShadThemeData _build({
    required ShadColorScheme colorScheme,
    required Brightness brightness,
  }) {
    final isDark = brightness == Brightness.dark;
    return ShadThemeData(
      brightness: brightness,
      colorScheme: colorScheme,
      radius: BorderRadius.circular(kShadRadius),
      // Linear/Vercel: UN borde, plano, al 100 % — sin el doble borde
      // sombra/borde que shadcn trae por defecto.
      disableSecondaryBorder: true,
      textTheme: _textTheme(
        colorScheme.foreground,
        colorScheme.mutedForeground,
      ),
      separatorTheme: ShadSeparatorTheme(
        color: colorScheme.border,
        thickness: 1,
        radius: BorderRadius.circular(kShadControlRadius),
      ),
      primaryButtonTheme: ShadButtonTheme(
        height: 36,
        backgroundColor: colorScheme.primary,
        hoverBackgroundColor: _shift(colorScheme.primary, isDark ? .12 : -.08),
        foregroundColor: colorScheme.primaryForeground,
        pressedBackgroundColor: _shift(
          colorScheme.primary,
          isDark ? .20 : -.14,
        ),
      ),
      secondaryButtonTheme: ShadButtonTheme(
        height: 36,
        backgroundColor: colorScheme.secondary,
        hoverBackgroundColor: colorScheme.accent,
        foregroundColor: colorScheme.secondaryForeground,
      ),
      outlineButtonTheme: ShadButtonTheme(
        height: 36,
        backgroundColor: colorScheme.background,
        hoverBackgroundColor: colorScheme.accent,
        foregroundColor: colorScheme.foreground,
      ),
      ghostButtonTheme: ShadButtonTheme(
        height: 36,
        hoverBackgroundColor: colorScheme.accent,
        foregroundColor: colorScheme.foreground,
      ),
      destructiveButtonTheme: ShadButtonTheme(
        height: 36,
        backgroundColor: colorScheme.destructive,
        hoverBackgroundColor: _shift(
          colorScheme.destructive,
          isDark ? .12 : -.08,
        ),
        foregroundColor: colorScheme.destructiveForeground,
      ),
      tooltipTheme: ShadTooltipTheme(
        decoration: ShadDecoration(
          color: isDark ? VeColors.accentDark : VeColors.primaryLight,
          border: _flatBorder(Colors.transparent),
          labelStyle: TextStyle(
            fontFamily: 'Inter',
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: isDark ? VeColors.fgDark : Colors.white,
          ),
        ),
      ),
      popoverTheme: ShadPopoverTheme(
        decoration: ShadDecoration(
          color: colorScheme.popover,
          border: _flatBorder(colorScheme.border, radius: kShadRadius),
        ),
      ),
      cardTheme: ShadCardTheme(
        radius: BorderRadius.circular(kShadRadius),
        backgroundColor: colorScheme.card,
        border: _flatBorder(colorScheme.border, radius: kShadRadius),
      ),
      inputTheme: ShadInputTheme(
        decoration: ShadDecoration(
          color: colorScheme.background,
          border: _flatBorder(colorScheme.input),
          focusedBorder: _flatBorder(colorScheme.ring),
        ),
      ),
      sheetTheme: ShadSheetTheme(
        radius: BorderRadius.circular(kShadRadius),
        backgroundColor: colorScheme.card,
      ),
      primaryDialogTheme: ShadDialogTheme(
        radius: BorderRadius.circular(kShadRadius),
        backgroundColor: colorScheme.card,
      ),
      primaryAlertTheme: ShadAlertTheme(
        decoration: ShadDecoration(
          color: colorScheme.card,
          border: _flatBorder(colorScheme.border, radius: kShadRadius),
        ),
        iconColor: colorScheme.primary,
      ),
      destructiveAlertTheme: ShadAlertTheme(
        decoration: ShadDecoration(
          color: colorScheme.card,
          border: _flatBorder(colorScheme.destructive, radius: kShadRadius),
        ),
        iconColor: colorScheme.destructive,
      ),
    );
  }

  /// Oscurece (t<0) o aclara (t>0) un color — solo para estados hover/pressed
  /// de controles; los tokens de superficie NUNCA pasan por aquí.
  static Color _shift(Color c, double t) {
    if (t == 0) return c;
    return t > 0
        ? Color.lerp(c, Colors.white, t)!
        : Color.lerp(c, Colors.black, -t)!;
  }
}

/// Puente de compatibilidad: el tema Material que ShadApp inyecta para las
/// pantallas aún no migradas. Es EXACTAMENTE el `AppTheme` vigente (semántica
/// VeInk, transiciones de página firma, temas de componentes Material) —
/// con el ColorScheme de Material You cuando el usuario lo activó.
///
/// Uso: `materialThemeBuilder: (context, mTheme) => veMaterialBridge(...)`.
ThemeData veMaterialBridge(Brightness brightness, ColorScheme? dynamicScheme) {
  return brightness == Brightness.dark
      ? AppTheme.dark(dynamicScheme)
      : AppTheme.light(dynamicScheme);
}
