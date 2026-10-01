/// ─── Onboarding (§9.9 · v19.0 · orden del dueño: slides) ─────────────────────
/// Bienvenida en PageView de 4 slides con avanzar/retroceder (botones y
/// gesto de swipe): marca → lo que hace → datos tuyos → país con banderas.
/// El botón final «Comenzar en {país}» fija el país, cierra el onboarding y
/// deja pasar al tutorial completo (que arranca solo al montar el shell).
///
/// La última vez (v18.0) esto era UN scroll — el dueño pidió volver a
/// slides. El tutorial sigue siendo UNO (app_tour.dart); la bienvenida NO
/// se repite sola (replay en Ajustes → «Volver a ver la bienvenida»).
///
/// Sin logotipo gráfico: la marca es tipografía pura «ValoraVE».
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/currencies.dart';
import '../../core/shad_theme.dart' show kShadRadius;
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../widgets/ui.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _page = PageController();
  int _index = 0;
  Country _country = Country.VE;

  @override
  void dispose() {
    _page.dispose();
    super.dispose();
  }

  void _go(int i) {
    final target = i.clamp(0, 3);
    _page.animateToPage(
      target,
      duration: const Duration(milliseconds: 320),
      curve: kEaseVe,
    );
  }

  Future<void> _finish(AppStore store) async {
    store.setCountry(_country);
    store.finishOnboarding();
    if (mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: PageView(
                controller: _page,
                physics: const PageScrollPhysics(),
                onPageChanged: (i) => setState(() => _index = i),
                children: <Widget>[
                  const _SlideMarca(),
                  const _SlideQueHace(),
                  const _SlideDatos(),
                  _SlidePais(
                    country: _country,
                    onPickCountry: (c) => setState(() => _country = c),
                  ),
                ],
              ),
            ),
            // Barra de control: atrás · puntos · siguiente/comenzar.
            // TASK-34 p11: botones Ve (ghost atrás · primario adelante) —
            // misma píldora de tinta invertida del prototipo. FittedBox en
            // los puntos y Flexible en los botones (fix overflow <356 dp).
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
              child: Row(
                children: <Widget>[
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 96),
                      child: VeBtn(
                        variant: VeBtnVariant.ghost,
                        enabled: _index > 0,
                        onPressed: () => _go(_index - 1),
                        child: const Text('Atrás'),
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        child: _Dots(count: 4, index: _index, onTap: _go),
                      ),
                    ),
                  ),
                  Flexible(
                    child: ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 150),
                      child: VeBtn(
                        variant: VeBtnVariant.primary,
                        onPressed: _index < 3
                            ? () => _go(_index + 1)
                            : () => _finish(store),
                        child: Text(
                          _index < 3 ? 'Siguiente' : 'Comenzar',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// ─── Slide 1 · Marca ─────────────────────────────────────────────────────────
class _SlideMarca extends StatelessWidget {
  const _SlideMarca();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Scroll + centrado (patrón de los slides 2-4): en landscape o con
    // textScale >=1.5 el contenido superaba el viewport fijo del PageView
    // y desbordaba — el primer slide que ve un usuario nuevo (fix).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              // Marca del prototipo (TASK-34 p11): rombo de tinta con el
              // círculo del fondo — el mismo gesto del SVG del web, pintado.
              const Center(child: _VeLogo(size: 44)),
              const SizedBox(height: 20),
              Center(
                child: RichText(
                  text: TextSpan(
                    style: VeText.displayNum(
                      44,
                      color: scheme.onSurface,
                      weight: FontWeight.w700,
                    ),
                    children: <InlineSpan>[
                      const TextSpan(text: 'Valora'),
                      TextSpan(
                        text: 'VE',
                        style: TextStyle(color: scheme.primary),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Center(
                child: Text(
                  'Precios y divisas de Venezuela',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Center(
                child: Text(
                  'El instrumento para registrar, comparar y calcular.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    height: 1.45,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(height: 34),
              // Las seis divisas del foco, con banderas reales (assets/flags).
              Center(
                child: Wrap(
                  spacing: 14,
                  runSpacing: 14,
                  alignment: WrapAlignment.center,
                  children: <Widget>[
                    for (final c in CurrencyX.focus) _FlagPill(currency: c),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Banderita grande con el código debajo (slide 1).
class _FlagPill extends StatelessWidget {
  const _FlagPill({required this.currency});
  final Currency currency;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Flag(currency, size: 34),
        const SizedBox(height: 6),
        Text(
          currency.code,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

/// Marca del prototipo web: rombo (cuadrado rotado 45° con esquinas
/// redondeadas) en tinta fg con el círculo del fondo al centro — el mismo
/// gesto del `<svg>` del Onboarding, pintado en Flutter.
class _VeLogo extends StatelessWidget {
  const _VeLogo({this.size = 40});

  final double size;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context).colorScheme;
    return CustomPaint(
      size: Size.square(size),
      painter: _VeLogoPainter(fg: shad.foreground, bg: shad.background),
    );
  }
}

class _VeLogoPainter extends CustomPainter {
  _VeLogoPainter({required this.fg, required this.bg});

  final Color fg;
  final Color bg;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    // Rect del rombo: mismo viewBox 48×48 del SVG (rect 7..41, rx 9) rotado
    // alrededor del centro (24, 24) — escalado al tamaño pedido.
    final scale = s / 48;
    canvas.save();
    canvas.translate(s / 2, s / 2);
    canvas.rotate(0.7853981633974483); // 45°
    final rrect = RRect.fromRectAndRadius(
      Rect.fromCenter(
        center: Offset.zero,
        width: 34 * scale,
        height: 34 * scale,
      ),
      Radius.circular(9 * scale),
    );
    canvas.drawRRect(rrect, Paint()..color = fg);
    canvas.restore();
    canvas.drawCircle(Offset(s / 2, s / 2), 6 * scale, Paint()..color = bg);
  }

  @override
  bool shouldRepaint(_VeLogoPainter oldDelegate) =>
      oldDelegate.fg != fg || oldDelegate.bg != bg;
}

/// ─── Slide 2 · Lo que hace ───────────────────────────────────────────────────
class _SlideQueHace extends StatelessWidget {
  const _SlideQueHace();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    // Centrado vertical (v19.10): mismo patrón del slide 1 — el
    // contenido respira centrado y con textScale alto sigue habiendo
    // scroll sin desbordes (antes quedaba colgado arriba, ~45 % vacío).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 12, 26, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Lo que hace',
                style: VeText.displayNum(
                  24,
                  color: scheme.onSurface,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tres cosas, bien hechas.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              _WelcomeBullet(
                icon: Icons.swap_horiz,
                color: scheme.primary,
                title: 'Tasas con contexto',
                body:
                    'Oficial, promedio y paralelo, siempre con la fuente a la vista.',
              ),
              const SizedBox(height: 12),
              _WelcomeBullet(
                icon: Icons.receipt_long_outlined,
                color: sem.pos,
                title: 'Tu libro de precios',
                body:
                    'Compras como asientos contables, con ticket y totales al cambio.',
              ),
              const SizedBox(height: 12),
              _WelcomeBullet(
                icon: Icons.calculate_outlined,
                color: sem.warn,
                title: 'Cálculos que sirven',
                body:
                    'Sueldo en divisas, vuelto, presupuesto y análisis del mes.',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─── Slide 3 · Datos tuyos ───────────────────────────────────────────────────
class _SlideDatos extends StatelessWidget {
  const _SlideDatos();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Centrado vertical (v19.10): mismo patrón del slide 1 — el
    // contenido respira centrado y con textScale alto sigue habiendo
    // scroll sin desbordes (antes quedaba colgado arriba, ~45 % vacío).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 12, 26, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                'Tus datos, tuyos',
                style: VeText.displayNum(
                  24,
                  color: scheme.onSurface,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Sin cuentas, sin nube, sin claves.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 18),
              Builder(
                builder: (cardCtx) {
                  final shad = ShadTheme.of(cardCtx).colorScheme;
                  return Container(
                    padding: const EdgeInsets.all(16),
                    clipBehavior: Clip.antiAlias,
                    decoration: BoxDecoration(
                      color: shad.card,
                      borderRadius: BorderRadius.circular(kShadRadius),
                      border: Border.all(color: shad.border),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              Icons.cloud_done_outlined,
                              size: 20,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Tasas en vivo, datos tuyos',
                                style: TextStyle(
                                  fontSize: 14.5,
                                  fontWeight: FontWeight.w700,
                                  color: scheme.onSurface,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Las cotizaciones llegan de APIs públicas (BCV, paralelo, TRM, '
                          'Banxico, Banco Central de Brasil) y se guardan en tu teléfono '
                          'para consultarlas sin conexión. Tus registros, listas y compras '
                          'viven solo aquí: sin cuentas ni claves. Sin red la app sigue '
                          'igual y acepta tasas manuales.',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.45,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                        const Divider(height: 22),
                        // Leyenda de categorías (dp6): el color dice qué es la tasa.
                        const CategoryLegend(),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ─── Slide 4 · País (banderas reales) + Comenzar ─────────────────────────────
class _SlidePais extends StatelessWidget {
  const _SlidePais({required this.country, required this.onPickCountry});

  final Country country;
  final ValueChanged<Country> onPickCountry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    // Centrado vertical (v19.10): mismo patrón del slide 1 — el
    // contenido respira centrado y con textScale alto sigue habiendo
    // scroll sin desbordes (antes quedaba colgado arriba, ~45 % vacío).
    return LayoutBuilder(
      builder: (context, constraints) => SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(26, 12, 26, 8),
        child: ConstrainedBox(
          constraints: BoxConstraints(minHeight: constraints.maxHeight - 20),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              Text(
                '¿Desde dónde miras las tasas?',
                style: VeText.displayNum(
                  24,
                  color: scheme.onSurface,
                  weight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Define el tablero protagonista.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 6),
              Text(
                'Lo puedes cambiar en Ajustes cuando quieras. Al tocar «Comenzar» '
                'verás el tutorial completo de la app.',
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                alignment: WrapAlignment.center,
                children: <Widget>[
                  for (final c in Country.values)
                    _CountryChip(
                      country: c,
                      selected: country == c,
                      onTap: () => onPickCountry(c),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Puntos de posición tocables (4 slides).
class _Dots extends StatelessWidget {
  const _Dots({required this.count, required this.index, required this.onTap});

  final int count;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (var i = 0; i < count; i++)
          GestureDetector(
            onTap: () => onTap(i),
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 22,
              height: 22,
              alignment: Alignment.center,
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                curve: kEaseVe,
                width: i == index ? 18 : 7,
                height: 7,
                decoration: BoxDecoration(
                  color: i == index ? scheme.primary : scheme.outlineVariant,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// Chip compacto de país (bandera real).
class _CountryChip extends StatelessWidget {
  const _CountryChip({
    required this.country,
    required this.selected,
    required this.onTap,
  });

  final Country country;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final shad = ShadTheme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;
    final lineStrong = dark
        ? VeColors.lineStrongDark
        : VeColors.lineStrongLight;
    // TASK-34 p11: chip Ve con bandera — píldora card + borde line-strong;
    // seleccionado invierte la tinta (fg / bg), como el VeChip del kit.
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 32,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? scheme.onSurface : lineStrong,
            width: selected ? 1.4 : 1,
          ),
          color: selected ? scheme.onSurface : shad.card,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            // BANDERA REAL del país (assets/flags): "Global" usa ícono
            // public porque USD no tiene bandera de país.
            country == Country.US
                ? Icon(
                    Icons.public,
                    size: 14,
                    color: selected
                        ? scheme.surfaceContainerLowest
                        : scheme.primary,
                  )
                : Flag(country.currency, size: 14),
            const SizedBox(width: 6),
            Text(
              country.label,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 12.5,
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: selected
                    ? scheme.surfaceContainerLowest
                    : scheme.onSurface,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _WelcomeBullet extends StatelessWidget {
  const _WelcomeBullet({
    required this.icon,
    required this.color,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final shad = ShadTheme.of(context).colorScheme;
    // TASK-34 p11: cromática VeCard — superficie card, borde --line, radio 10.
    return Container(
      padding: const EdgeInsets.all(14),
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: shad.card,
        borderRadius: BorderRadius.circular(kShadRadius),
        border: Border.all(color: shad.border),
      ),
      child: Row(
        children: <Widget>[
          Container(
            width: 38,
            height: 38,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 19, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
