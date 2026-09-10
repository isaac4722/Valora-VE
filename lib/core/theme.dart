/// Tema «El Instrumento» de ValoraVE — tokens exactos del sistema de diseño
/// v15 (DESIGN.md). Superficie neutra de precisión: azul tinta señala lo
/// tocable, el color de datos solo significa (oficial/paralelo, sube/baja).
/// CONTRATO (§8): aquí vive la ÚNICA definición de kEaseVe — ui.dart la
/// re-exporta para no romper a quien la importe desde ahí.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Curva firma del sistema (EASE [0.16, 1, 0.3, 1]).
const Cubic kEaseVe = Cubic(0.16, 1.0, 0.3, 1.0);

/// Paleta por rol, light (canónico) y dark (grafito frío).
class VeColors {
  const VeColors._();

  // ── Claro (canónico) ──
  static const Color bgLight = Color(0xFFF7F8F9);
  static const Color cardLight = Color(0xFFFFFFFF);
  static const Color fgLight = Color(0xFF1A1D21);
  static const Color mutedLight = Color(0xFFF1F2F4);
  static const Color mutedFgLight = Color(0xFF5F6672);
  static const Color primaryLight = Color(0xFF22354E);
  static const Color accentLight = Color(0xFFEEF1F4);
  static const Color borderLight = Color(0xFFD3D9DF);
  static const Color destructiveLight = Color(0xFFCF4437);

  // ── Grafito (oscuro) ──
  static const Color bgDark = Color(0xFF121417);
  static const Color cardDark = Color(0xFF1A1D21);
  static const Color fgDark = Color(0xFFECEEF1);
  static const Color mutedDark = Color(0xFF202429);
  static const Color mutedFgDark = Color(0xFF9AA1AB);
  static const Color primaryDark = Color(0xFF8FA7C4);
  static const Color onPrimaryDark = Color(0xFF0E1622);
  static const Color accentDark = Color(0xFF242A32);
  static const Color borderDark = Color(0xFF3A4048);
  static const Color destructiveDark = Color(0xFFF07A6C);

  // ── Semánticas de dinero y tasas (light / dark) ──
  static const Color posLight = Color(0xFF10755A);
  static const Color posDark = Color(0xFF3ECF9E);
  static const Color negLight = Color(0xFFCF4437);
  static const Color negDark = Color(0xFFF07A6C);
  static const Color warnLight = Color(0xFFB05E0E);
  static const Color warnDark = Color(0xFFEDA25C);
  static const Color manualLight = Color(0xFF6E5BB8);
  static const Color manualDark = Color(0xFFB3A0EC);
  static const Color copLight = Color(0xFF5D6B13);
  static const Color copDark = Color(0xFFB5C65E);
  static const Color brlLight = Color(0xFF12873C);
  static const Color brlDark = Color(0xFF5FCD84);
  static const Color mxnLight = Color(0xFFB03D90);
  static const Color mxnDark = Color(0xFFE391CB);

  /// Devuelve el set de semánticas según el brillo del tema actual.
  static VeInk of(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? const VeInk.dark()
          : const VeInk.light();
}

/// Semánticas de datos para el tema activo.
class VeInk {
  const VeInk({
    required this.pos,
    required this.neg,
    required this.warn,
    required this.manual,
    required this.cop,
    required this.brl,
    required this.mxn,
  });

  const VeInk.light()
      : this(
          pos: VeColors.posLight,
          neg: VeColors.negLight,
          warn: VeColors.warnLight,
          manual: VeColors.manualLight,
          cop: VeColors.copLight,
          brl: VeColors.brlLight,
          mxn: VeColors.mxnLight,
        );

  const VeInk.dark()
      : this(
          pos: VeColors.posDark,
          neg: VeColors.negDark,
          warn: VeColors.warnDark,
          manual: VeColors.manualDark,
          cop: VeColors.copDark,
          brl: VeColors.brlDark,
          mxn: VeColors.mxnDark,
        );

  final Color pos; // verde — oficiales, positivo
  final Color neg; // rojo — paralelos, negativo, destructivo
  final Color warn; // ámbar — promedios, avisos
  final Color manual; // violeta — manuales / EUR
  final Color cop; // oliva
  final Color brl; // verde Brasil
  final Color mxn; // magenta
}

/// Temas Material de la app, construidos sobre los tokens del diseño.
abstract final class AppTheme {
  static ThemeData light() => _build(
        bg: VeColors.bgLight,
        card: VeColors.cardLight,
        fg: VeColors.fgLight,
        muted: VeColors.mutedLight,
        mutedFg: VeColors.mutedFgLight,
        primary: VeColors.primaryLight,
        onPrimary: Colors.white,
        accent: VeColors.accentLight,
        border: VeColors.borderLight,
        destructive: VeColors.destructiveLight,
        isDark: false,
      );

  static ThemeData dark() => _build(
        bg: VeColors.bgDark,
        card: VeColors.cardDark,
        fg: VeColors.fgDark,
        muted: VeColors.mutedDark,
        mutedFg: VeColors.mutedFgDark,
        primary: VeColors.primaryDark,
        onPrimary: VeColors.onPrimaryDark,
        accent: VeColors.accentDark,
        border: VeColors.borderDark,
        destructive: VeColors.destructiveDark,
        isDark: true,
      );

  static ThemeData _build({
    required Color bg,
    required Color card,
    required Color fg,
    required Color muted,
    required Color mutedFg,
    required Color primary,
    required Color onPrimary,
    required Color accent,
    required Color border,
    required Color destructive,
    required bool isDark,
  }) {
    final ColorScheme scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: primary,
      onPrimary: onPrimary,
      secondary: mutedFg,
      onSecondary: card,
      tertiary: primary,
      onTertiary: onPrimary,
      error: destructive,
      onError: Colors.white,
      surface: card,
      onSurface: fg,
      surfaceContainerLowest: bg,
      surfaceContainerLow: card,
      surfaceContainer: isDark ? VeColors.mutedDark : muted,
      surfaceContainerHigh: accent,
      surfaceContainerHighest: muted,
      onSurfaceVariant: mutedFg,
      outline: mutedFg,
      outlineVariant: border,
      shadow: const Color(0xFF0C1016),
      scrim: Colors.black,
      inversePrimary: primary,
      onInverseSurface: bg,
      inverseSurface: fg,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      fontFamily: 'Inter',
      splashFactory: InkSparkle.splashFactory,
      appBarTheme: AppBarTheme(
        elevation: 0,
        scrolledUnderElevation: 0,
        backgroundColor: bg,
        foregroundColor: fg,
        // §8: display en SpaceGrotesk (los números siguen tabulares).
        titleTextStyle: TextStyle(
          fontFamily: 'SpaceGrotesk',
          fontSize: 17,
          fontWeight: FontWeight.w700,
          color: fg,
          letterSpacing: -0.2,
        ),
        systemOverlayStyle: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      ),
      // §8 sombra firma sutil: card eleva 1 con sombra azul-noche al 8 %.
      cardTheme: CardThemeData(
        elevation: 1,
        shadowColor: const Color(0x140C1016),
        color: card,
        surfaceTintColor: Colors.transparent,
        margin: EdgeInsets.zero,
        clipBehavior: Clip.antiAlias,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: BorderSide(color: border),
        ),
      ),
      // §8 transición de página firma (slide 18/10 px + fade).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <PageTransitionsBuilder, TargetPlatform>{
          TargetPlatform.android: VePageTransitionsBuilder(),
          TargetPlatform.iOS: VePageTransitionsBuilder(),
          TargetPlatform.macOS: VePageTransitionsBuilder(),
          TargetPlatform.linux: VePageTransitionsBuilder(),
          TargetPlatform.windows: VePageTransitionsBuilder(),
          TargetPlatform.fuchsia: VePageTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: muted.withValues(alpha: 0.55),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: BorderSide(color: primary, width: 1.4),
        ),
        hintStyle: TextStyle(color: mutedFg.withValues(alpha: 0.75), fontSize: 13.5),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: fg,
          side: BorderSide(color: border),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primary,
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark ? VeColors.accentDark : VeColors.primaryLight,
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13,
          color: isDark ? VeColors.fgDark : Colors.white,
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        // §8: diálogos elevan 8 con sombra firma al 12 %.
        elevation: 8,
        shadowColor: const Color(0x1F0C1016),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        titleTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 16,
          fontWeight: FontWeight.w700,
          color: fg,
        ),
        contentTextStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 13.5,
          height: 1.45,
          color: mutedFg,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? onPrimary : card,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? primary : border,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? primary : border,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(999)),
        labelStyle: TextStyle(
          fontFamily: 'Inter',
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: mutedFg,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        showDragHandle: true,
        elevation: 8,
        shadowColor: Color(0x1F0C1016),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
        ),
      ),
    );
  }
}

/// Transición de página firma (§8): slide sutil (dx 18 px · dy 10 px) +
/// fade, con la curva kEaseVe sobre la duración estándar de ruta (300 ms).
/// Con `disableAnimations` del sistema → SOLO fade (accesibilidad).
class VePageTransitionsBuilder extends PageTransitionsBuilder {
  const VePageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    final CurvedAnimation curved =
        CurvedAnimation(parent: animation, curve: kEaseVe, reverseCurve: kEaseVe.flipped);
    if (MediaQuery.disableAnimationsOf(context)) {
      return FadeTransition(opacity: curved, child: child);
    }
    final Size size = MediaQuery.sizeOf(context);
    final Offset begin = Offset(
      size.width > 0 ? 18 / size.width : 0.02,
      size.height > 0 ? 10 / size.height : 0.012,
    );
    return SlideTransition(
      position: Tween<Offset>(begin: begin, end: Offset.zero).animate(curved),
      child: FadeTransition(opacity: curved, child: child),
    );
  }
}

/// Estilos tipográficos firma del sistema.
abstract final class VeText {
  /// `display-num` — Space Grotesk con cifras tabulares (no bailan).
  static TextStyle displayNum(
    double size, {
    required Color color,
    FontWeight weight = FontWeight.w700,
    double? letterSpacing,
  }) =>
      TextStyle(
        fontFamily: 'SpaceGrotesk',
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing ?? -0.02 * size,
        fontFeatures: const <FontFeature>[FontFeature.tabularFigures()],
        height: 1.05,
      );

  /// `label-caps` — rótulos técnicos en mayúsculas con tracking amplio.
  ///
  /// Piso de legibilidad: en móvil ningún rótulo baja de 9.5 px aunque el
  /// diseño pida menos (evita el «texto demasiado pequeño» en pantallas densas).
  static TextStyle labelCaps(
    double size, {
    required Color color,
    FontWeight weight = FontWeight.w600,
  }) =>
      TextStyle(
        fontFamily: 'Inter',
        fontSize: size < 9.5 ? 9.5 : size,
        fontWeight: weight,
        color: color,
        letterSpacing: 0.12 * (size < 9.5 ? 9.5 : size),
      );
}
