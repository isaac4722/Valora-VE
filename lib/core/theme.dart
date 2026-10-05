/// Tema de ValoraVE — tokens EXACTOS del prototipo web de referencia
/// (TASK-34, orden del dueño): zinc neutro de precisión estilo Linear/Vercel,
/// tinta casi negra como primario (botón invertido fg→bg), bordes 100 % y
/// CERO sombras: plana como un instrumento. El color de datos solo
/// significa (oficial/paralelo, sube/baja/meta) y cada tono trae su fondo
/// tenue para badges legibles en ambos brillos.
/// CONTRATO (§8): aquí vive la ÚNICA definición de kEaseVe — ui.dart la
/// re-exporta para no romper a quien la importe desde ahí.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Curva firma del sistema (EASE [0.16, 1, 0.3, 1]).
const Cubic kEaseVe = Cubic(0.16, 1.0, 0.3, 1.0);

/// Paleta por rol, light (zinc del prototipo) y dark (grafito zinc).
///
/// Los valores son EXACTOS a los CSS custom properties del prototipo de
/// referencia (`:root` y `.dark`): ni un tono inventado, ni una opacidad
/// nueva. El «primario» es la propia tinta (Linear/Vercel): el botón
/// principal es fg con texto bg — cero acentos de marca.
class VeColors {
  const VeColors._();

  // ── Claro (zinc · `:root` del prototipo) ──
  static const Color bgLight = Color(0xFFFAFAFA); // --bg
  static const Color cardLight = Color(0xFFFFFFFF); // --surface
  static const Color fgLight = Color(0xFF09090B); // --fg
  static const Color mutedLight = Color(0xFFF4F4F5); // --subtle
  static const Color mutedFgLight = Color(0xFF71717A); // --muted
  static const Color primaryLight = fgLight; // botón invertido fg→bg
  static const Color accentLight = Color(0xFFF0F0F1); // --hover
  static const Color borderLight = Color(0xFFE8E8EA); // --line
  static const Color destructiveLight = Color(0xFFD33A2C); // --neg

  // ── Oscuro (grafito zinc · `.dark` del prototipo) ──
  static const Color bgDark = Color(0xFF08080A); // --bg
  static const Color cardDark = Color(0xFF0E0E11); // --surface
  static const Color fgDark = Color(0xFFF4F4F5); // --fg
  static const Color mutedDark = Color(0xFF17171B); // --subtle
  static const Color mutedFgDark = Color(0xFF8B8B95); // --muted
  static const Color primaryDark = fgDark; // botón invertido fg→bg
  static const Color onPrimaryDark = Color(0xFF08080A); // --bg
  static const Color accentDark = Color(0xFF1D1D22); // --hover
  static const Color borderDark = Color(0xFF222227); // --line
  static const Color destructiveDark = Color(0xFFF0705F); // --neg

  // ── Bordes fuertes y texto terciario (inputs, chips, kbd) ──
  /// `--line-strong` claro: el borde de controles vivos (inputs, botones
  /// secundarios) — un punto más decidido que [borderLight].
  static const Color lineStrongLight = Color(0xFFD4D4D8);

  /// `--line-strong` oscuro.
  static const Color lineStrongDark = Color(0xFF34343B);

  /// `--faint` claro: texto terciario (placeholders, hints, kbd).
  static const Color faintLight = Color(0xFFA1A1AA);

  /// `--faint` oscuro.
  static const Color faintDark = Color(0xFF5C5C66);

  // ── Semánticas de dinero y tasas (light / dark · prototipo) ──
  static const Color posLight = Color(0xFF0E7A57); // --pos
  static const Color posDark = Color(0xFF3ECF9A);
  static const Color negLight = Color(0xFFD33A2C); // --neg
  static const Color negDark = Color(0xFFF0705F);
  static const Color warnLight = Color(0xFFB45309); // --warn
  static const Color warnDark = Color(0xFFF0A560);
  static const Color manualLight = Color(0xFF5B4BC4); // --info
  static const Color manualDark = Color(0xFF9D90F2);
  // Monedas hermanas (fuera del prototipo VE): tonos propios que armonizan
  // con el zinc, sin tocar la semántica oficial/paralelo.
  static const Color copLight = Color(0xFF5D6B13);
  static const Color copDark = Color(0xFFB5C65E);
  static const Color brlLight = Color(0xFF12873C);
  static const Color brlDark = Color(0xFF5FCD84);
  static const Color mxnLight = Color(0xFFB03D90);
  static const Color mxnDark = Color(0xFFE391CB);

  // ── Fondos tenues de los tonos (badges del prototipo) ──
  /// `--pos-bg` claro: badge verde sobre fondo mentolado.
  static const Color posBgLight = Color(0xFFE6F4EE);

  /// `--pos-bg` oscuro.
  static const Color posBgDark = Color(0xFF0F2A21);

  /// `--neg-bg` claro.
  static const Color negBgLight = Color(0xFFFCEBE9);

  /// `--neg-bg` oscuro.
  static const Color negBgDark = Color(0xFF2D1411);

  /// `--warn-bg` claro.
  static const Color warnBgLight = Color(0xFFFDF1E1);

  /// `--warn-bg` oscuro.
  static const Color warnBgDark = Color(0xFF2B1E0F);

  /// `--info-bg` claro.
  static const Color infoBgLight = Color(0xFFEEEBFB);

  /// `--info-bg` oscuro.
  static const Color infoBgDark = Color(0xFF1C1840);

  /// Devuelve el set de semánticas del TEMA ACTIVO (v17.6 R1-1).
  ///
  /// Las semánticas viven ahora en [VeInk] como `ThemeExtension` registrado
  /// en `AppTheme.light()/dark()` — viajan DENTRO de ThemeData (lerp suave
  /// entre temas, visibles para tests dorados y Material You). El fallback
  /// por brillo queda como red de seguridad (pantallas sin tema registrado,
  /// tests). API pública intacta: ninguna llamada del repo cambia.
  static VeInk of(BuildContext context) {
    final ext = Theme.of(context).extension<VeInk>();
    if (ext != null) return ext;
    return Theme.of(context).brightness == Brightness.dark
        ? const VeInk.dark()
        : const VeInk.light();
  }
}

/// Semánticas de datos para el tema activo.
///
/// v17.6 (RECHECK R1-1): [VeInk] ES ahora un `ThemeExtension<VeInk>` —
/// el registro vive en `AppTheme._build` (`extensions:`), así el set viaja
/// con el ThemeData (requirement «ThemeExtension creado y aplicado en
/// MaterialApp»). Evolución, no reescritura: los 7 campos y los constructores
/// light/dark son EXACTAMENTE los mismos tokens de siempre.
class VeInk extends ThemeExtension<VeInk> {
  const VeInk({
    required this.pos,
    required this.neg,
    required this.warn,
    required this.manual,
    required this.cop,
    required this.brl,
    required this.mxn,
    this.posBg = const Color(0x1A0E7A57),
    this.negBg = const Color(0x1AD33A2C),
    this.warnBg = const Color(0x1AB45309),
    this.infoBg = const Color(0x1A5B4BC4),
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
        posBg: VeColors.posBgLight,
        negBg: VeColors.negBgLight,
        warnBg: VeColors.warnBgLight,
        infoBg: VeColors.infoBgLight,
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
        posBg: VeColors.posBgDark,
        negBg: VeColors.negBgDark,
        warnBg: VeColors.warnBgDark,
        infoBg: VeColors.infoBgDark,
      );

  final Color pos; // verde — oficiales, positivo
  final Color neg; // rojo — paralelos, negativo, destructivo
  final Color warn; // ámbar — promedios, avisos
  final Color manual; // violeta — manuales / EUR
  final Color cop; // oliva
  final Color brl; // verde Brasil
  final Color mxn; // magenta

  /// Fondos tenues de badge (`--pos-bg` & co. del prototipo): superficie
  /// donde el tono correspondiente es texto — contraste AA sin esfuerzo.
  final Color posBg;
  final Color negBg;
  final Color warnBg;
  final Color infoBg;

  @override
  VeInk copyWith({
    Color? pos,
    Color? neg,
    Color? warn,
    Color? manual,
    Color? cop,
    Color? brl,
    Color? mxn,
    Color? posBg,
    Color? negBg,
    Color? warnBg,
    Color? infoBg,
  }) => VeInk(
    pos: pos ?? this.pos,
    neg: neg ?? this.neg,
    warn: warn ?? this.warn,
    manual: manual ?? this.manual,
    cop: cop ?? this.cop,
    brl: brl ?? this.brl,
    mxn: mxn ?? this.mxn,
    posBg: posBg ?? this.posBg,
    negBg: negBg ?? this.negBg,
    warnBg: warnBg ?? this.warnBg,
    infoBg: infoBg ?? this.infoBg,
  );

  @override
  VeInk lerp(VeInk? other, double t) {
    if (other == null) return this;
    return VeInk(
      pos: Color.lerp(pos, other.pos, t)!,
      neg: Color.lerp(neg, other.neg, t)!,
      warn: Color.lerp(warn, other.warn, t)!,
      manual: Color.lerp(manual, other.manual, t)!,
      cop: Color.lerp(cop, other.cop, t)!,
      brl: Color.lerp(brl, other.brl, t)!,
      mxn: Color.lerp(mxn, other.mxn, t)!,
      posBg: Color.lerp(posBg, other.posBg, t)!,
      negBg: Color.lerp(negBg, other.negBg, t)!,
      warnBg: Color.lerp(warnBg, other.warnBg, t)!,
      infoBg: Color.lerp(infoBg, other.infoBg, t)!,
    );
  }
}

/// Temas Material de la app, construidos sobre los tokens del diseño.
///
/// Material You (dp6 · mejora 2): [dynamicScheme] llega de DynamicColorBuilder
/// (Android 12+) ya armonizado. CONTRATO: SOLO pinta primario/onPrimary —
/// superficies, bordes, texto y la semántica de dinero (error/pos/neg/warn)
/// son tokens de marca y NUNCA se tocan: la cifra de una compra no cambia de
/// color porque el usuario eligió otro wallpaper.
abstract final class AppTheme {
  static ThemeData light([ColorScheme? dynamicScheme]) => _build(
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
    dynamicScheme: dynamicScheme,
  );

  static ThemeData dark([ColorScheme? dynamicScheme]) => _build(
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
    dynamicScheme: dynamicScheme,
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
    ColorScheme? dynamicScheme,
  }) {
    // Material You: solo el par primario es dinámico; lo demás queda de marca.
    final Color effPrimary = dynamicScheme?.primary ?? primary;
    final Color effOnPrimary = dynamicScheme?.onPrimary ?? onPrimary;
    final ColorScheme scheme = ColorScheme(
      brightness: isDark ? Brightness.dark : Brightness.light,
      primary: effPrimary,
      onPrimary: effOnPrimary,
      secondary: mutedFg,
      onSecondary: card,
      tertiary: effPrimary,
      onTertiary: effOnPrimary,
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
      inversePrimary: effPrimary,
      onInverseSurface: bg,
      inverseSurface: fg,
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      // RECHECK R1-1 (v17.6): las semánticas de dinero viajan EN el tema —
      // una sola verdad: Theme.of(context).extension<VeInk>(). En esta
      // versión de Flutter extensions es Iterable: la clave la pone el
      // framework con runtimeType.
      extensions: <ThemeExtension<dynamic>>[
        isDark ? const VeInk.dark() : const VeInk.light(),
      ],
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
        systemOverlayStyle: isDark
            ? SystemUiOverlayStyle.light
            : SystemUiOverlayStyle.dark,
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
          borderRadius: BorderRadius.circular(10),
          side: BorderSide(color: border),
        ),
      ),
      // §8 transición de página firma (slide 18/10 px + fade).
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: <TargetPlatform, PageTransitionsBuilder>{
          TargetPlatform.android: VePageTransitionsBuilder(),
          TargetPlatform.iOS: VePageTransitionsBuilder(),
          TargetPlatform.macOS: VePageTransitionsBuilder(),
          TargetPlatform.linux: VePageTransitionsBuilder(),
          TargetPlatform.windows: VePageTransitionsBuilder(),
          TargetPlatform.fuchsia: VePageTransitionsBuilder(),
        },
      ),
      dividerTheme: DividerThemeData(color: border, thickness: 1, space: 1),
      // Superficies del navegador (§craft-floor): la selección de texto y
      // las barras de scroll también son parte del sistema — no quedan con
      // los defaults del navegador azul.
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: effPrimary,
        selectionColor: mutedFg.withValues(alpha: 0.28),
        selectionHandleColor: effPrimary,
      ),
      scrollbarTheme: ScrollbarThemeData(
        thickness: WidgetStateProperty.all(4),
        minThumbLength: 40,
        radius: Radius.circular(999),
        thumbColor: WidgetStateProperty.resolveWith((Set<WidgetState> s) {
          if (s.contains(WidgetState.dragged)) {
            return isDark ? VeColors.lineStrongDark : VeColors.lineStrongLight;
          }
          if (s.contains(WidgetState.hovered)) {
            return mutedFg.withValues(alpha: 0.55);
          }
          return mutedFg.withValues(alpha: 0.32);
        }),
        trackVisibility: WidgetStateProperty.all(false),
        crossAxisMargin: 2,
        mainAxisMargin: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: muted.withValues(alpha: 0.55),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 12,
          vertical: 12,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide(color: effPrimary, width: 1.4),
        ),
        hintStyle: TextStyle(
          color: mutedFg.withValues(alpha: 0.75),
          fontSize: 13.5,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: effPrimary,
          foregroundColor: effOnPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          textStyle: const TextStyle(
            fontFamily: 'Inter',
            fontSize: 13.5,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: effPrimary,
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: card,
        surfaceTintColor: Colors.transparent,
        // §8: diálogos elevan 8 con sombra firma al 12 %.
        elevation: 8,
        shadowColor: const Color(0x1F0C1016),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
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
              states.contains(WidgetState.selected) ? effOnPrimary : card,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? effPrimary : border,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (Set<WidgetState> states) =>
              states.contains(WidgetState.selected) ? effPrimary : border,
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: card,
        side: BorderSide(color: border),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    final CurvedAnimation curved = CurvedAnimation(
      parent: animation,
      curve: kEaseVe,
      reverseCurve: kEaseVe.flipped,
    );
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
  }) => TextStyle(
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
  }) => TextStyle(
    fontFamily: 'Inter',
    fontSize: size < 9.5 ? 9.5 : size,
    fontWeight: weight,
    color: color,
    letterSpacing: 0.12 * (size < 9.5 ? 9.5 : size),
  );
}
