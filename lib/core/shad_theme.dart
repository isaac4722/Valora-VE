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
    input: VeColors.lineStrongDark,
    ring: VeColors.primaryDark,
    selection: Color(0x4DF4F4F5),
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

/// Borde plano Linear/Vercel: un solo lado al 100 % de opacidad. Desde
/// TASK-34 (p3) lleva `padding: EdgeInsets.zero` EXPLÍCITO: el tema default
/// de shadcn reserva 2 px por lado para su anillo de foco (un borde
/// transparente), lo que infla TODOS los controles +4 px — el prototipo
/// mide 28/36/44 y aquí se cumple al píxel.
ShadBorder _flatBorder(
  Color color, {
  double radius = kShadControlRadius,
  double width = 1,
}) => ShadBorder.fromBorderSide(
  ShadBorderSide(color: color, width: width),
  padding: EdgeInsets.zero,
  radius: BorderRadius.circular(radius),
);

/// Decoración de botón SIN espacio reservado de foco (flush): la indicación
/// de foco es el cambio de color del borde — misma anchura, cero salto.
ShadDecoration _flushButtonDecoration() => ShadDecoration(
  border: _flatBorder(Colors.transparent, width: 0),
  focusedBorder: _flatBorder(Colors.transparent, width: 0),
  secondaryBorder: _flatBorder(Colors.transparent, width: 0),
  secondaryFocusedBorder: _flatBorder(Colors.transparent, width: 0),
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
        decoration: _flushButtonDecoration(),
      ),
      secondaryButtonTheme: ShadButtonTheme(
        height: 36,
        backgroundColor: colorScheme.secondary,
        hoverBackgroundColor: colorScheme.accent,
        foregroundColor: colorScheme.secondaryForeground,
        decoration: _flushButtonDecoration(),
      ),
      outlineButtonTheme: ShadButtonTheme(
        height: 36,
        backgroundColor: colorScheme.background,
        hoverBackgroundColor: colorScheme.accent,
        foregroundColor: colorScheme.foreground,
        decoration: _flushButtonDecoration(),
      ),
      ghostButtonTheme: ShadButtonTheme(
        height: 36,
        hoverBackgroundColor: colorScheme.accent,
        foregroundColor: colorScheme.foreground,
        decoration: _flushButtonDecoration(),
      ),
      destructiveButtonTheme: ShadButtonTheme(
        height: 36,
        backgroundColor: colorScheme.destructive,
        hoverBackgroundColor: _shift(
          colorScheme.destructive,
          isDark ? .12 : -.08,
        ),
        foregroundColor: colorScheme.destructiveForeground,
        decoration: _flushButtonDecoration(),
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
          focusedBorder: _flatBorder(colorScheme.ring, width: 1.4),
        ),
      ),
      // TASK-34 (p3): el checkbox del prototipo mide 18 px exactos — sin la
      // reserva de 2 px por lado del anillo default.
      checkboxTheme: ShadCheckboxTheme(
        decoration: ShadDecoration(
          border: _flatBorder(colorScheme.input),
          focusedBorder: _flatBorder(colorScheme.ring, width: 1.4),
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
