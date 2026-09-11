/// ─── Onboarding (§9.9): Paso0 Bienvenida (3 páginas dp4) → Paso1 País
/// (obligatorio) → Paso2 · 7 slides → Paso3 Done. «Saltar tutorial»
/// disponible desde el paso 2; el tutorial reabre desde Ajustes
/// (reopenTutorial). La bienvenida multipantalla del dp4 NO es rejugable
/// (decisión del dueño): una sola vez en la primera instalación.
///
/// Página 1 · marca y promesa. Página 2 · lo que hace la app.
/// Página 3 · datos reales de APIs y offline-first.
/// Sin logotipo gráfico: la marca es tipografía pura «ValoraVE».
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/currencies.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../widgets/ui.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  final PageController _pageCtrl = PageController();
  int _welcomePage = 0;
  int _step = 0; // 0 bienvenida · 1 país · 2 slides · 3 done
  Country _country = Country.VE;
  int _slideIndex = 0;

  static const int _kWelcomePages = 3;

  static const List<(IconData, String, String)> _slides = [
    (Icons.currency_exchange, 'Las tasas que importan',
        'BCV, paralelo, promedio y las aristas del euro, con TRM de Colombia, Banxico y el real brasileño. El promedio se calcula aquí mismo: (BCV + paralelo) / 2, sin intermediarios.'),
    (Icons.calendar_month, 'Conversor con fecha',
        '¿Cuánto valía tu plata ayer o hace una semana? El conversor acepta fecha histórica y te muestra la ruta del cálculo con las fuentes que usó.'),
    (Icons.shopping_cart_outlined, 'Lista que comparte en vivo',
        'Arma tu lista, ponle presupuesto, calcula el vuelto y divide la cuenta. Comparte la sala con un código de 6 letras: los cambios llegan al instante, con o sin internet.'),
    (Icons.inventory_2_outlined, 'Libro de precios',
        'Registra los precios que pagas, por tienda y por producto. Fija metas y la app te avisa cuando algo queda por debajo.'),
    (Icons.analytics_outlined, 'Brecha y devaluación',
        'Dos curvas para la brecha BCV↔paralelo, calendario de devaluación, inflación personal y proyección con memoria (amortiguada, sin ciencia ficción).'),
    (Icons.notifications_outlined, 'Avisos con cabeza',
        'Picos de tasa, metas alcanzadas, brecha grande o cambio diario: tú eliges los umbrales. Nada de ruido.'),
    (Icons.phone_android, 'Todo en tu teléfono',
        'Los datos viven en tu equipo, sin cuentas ni nube. Respaldo a JSON con fusión, widgets de tasa y todo funciona sin conexión desde el primer arranque.'),
  ];

  void _nextWelcomePage() {
    if (_welcomePage < _kWelcomePages - 1) {
      _pageCtrl.nextPage(duration: const Duration(milliseconds: 280), curve: Curves.easeOutCubic);
    } else {
      setState(() => _step = 1);
    }
  }

  @override
  void dispose() {
    _pageCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.read<AppStore>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: _step == 0 ? 26 : 24),
          child: Column(
            children: [
              // Saltar (bienvenida dp4): pasa directo al país obligatorio.
              if (_step == 0)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => setState(() => _step = 1),
                    child: Text('Saltar',
                        style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant)),
                  ),
                ),
              Expanded(
                child: _step == 0
                    ? PageView(
                        controller: _pageCtrl,
                        onPageChanged: (int i) => setState(() => _welcomePage = i),
                        children: <Widget>[
                          _PageOne(scheme: scheme),
                          _PageTwo(scheme: scheme, sem: VeColors.of(context)),
                          _PageThree(scheme: scheme),
                        ],
                      )
                    : _buildStep(context),
              ),
              if (_step == 0) ...<Widget>[
                // Puntos de progreso del dp4 (píldora en la página activa).
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: <Widget>[
                    for (int i = 0; i < _kWelcomePages; i++)
                      AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: i == _welcomePage ? 22 : 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: i == _welcomePage ? scheme.primary : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 16),
              ],
              Padding(
                padding: const EdgeInsets.only(bottom: 18),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    if (_step >= 2)
                      TextButton(
                        onPressed: () => _finish(context, store),
                        child: const Text('Saltar tutorial'),
                      )
                    else if (_step > 0)
                      TextButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Atrás'),
                      )
                    else
                      const SizedBox(width: 80),
                    if (_step == 2)
                      Row(
                        children: [
                          for (int i = 0; i < _slides.length; i++)
                            Container(
                              width: 6,
                              height: 6,
                              margin: const EdgeInsets.only(left: 4),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: i <= _slideIndex ? scheme.primary : scheme.outlineVariant,
                              ),
                            ),
                        ],
                      ),
                    FilledButton(
                      onPressed: () {
                        if (_step == 0) {
                          _nextWelcomePage();
                        } else if (_step == 1) {
                          store.setCountry(_country);
                          setState(() => _step = 2);
                        } else if (_step == 2) {
                          if (_slideIndex < _slides.length - 1) {
                            setState(() => _slideIndex++);
                          } else {
                            setState(() => _step = 3);
                          }
                        } else {
                          _finish(context, store);
                        }
                      },
                      child: Text(
                        _step == 0
                            ? (_welcomePage < _kWelcomePages - 1 ? 'Siguiente' : 'Comenzar')
                            : _step == 1
                                ? 'Elegir ${_country.label}'
                                : _step == 2
                                    ? (_slideIndex == _slides.length - 1 ? 'Listo' : 'Siguiente')
                                    : 'Empezar a usar ValoraVE',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _finish(BuildContext context, AppStore store) async {
    store.finishOnboarding();
    if (context.mounted) context.go('/');
  }

  Widget _buildStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (_step) {
      case 1:
        return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('¿Desde dónde miras las tasas?', style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 6),
            Text('Define el tablero protagonista. Lo puedes cambiar en Ajustes.',
                style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 18),
            for (final c in Country.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  onTap: () => setState(() => _country = c),
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                          color: _country == c
                              ? scheme.primary
                              : scheme.outlineVariant,
                          width: _country == c ? 1.4 : 1),
                      color: _country == c
                          ? scheme.primary.withValues(alpha: 0.06)
                          : scheme.surface,
                    ),
                    child: Row(children: [
                      Icon(c.currency == Currency.usd ? Icons.public : Icons.flag_outlined,
                          size: 18, color: scheme.primary),
                      const SizedBox(width: 10),
                      Expanded(child: Text(c.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600))),
                      Text(c.currency.code,
                          style: VeText.displayNum(12.5, color: scheme.onSurfaceVariant)),
                    ]),
                  ),
                ),
              ),
          ]),
        );
      case 2:
        final (icon, title, body) = _slides[_slideIndex];
        return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 58,
              height: 58,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.09),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Icon(icon, size: 26, color: scheme.primary),
            ),
            const SizedBox(height: 20),
            Text(title, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 10),
            Text(body, textAlign: TextAlign.center,
                style: TextStyle(fontSize: 13.5, height: 1.55, color: scheme.onSurfaceVariant)),
          ]),
        );
      default:
        return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_outline, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 18),
            Text('Todo listo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Tu tablero queda configurado para ${_country.label}. Sin conexión funciona igual: registra tasas manuales en Ajustes cuando no haya red.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 13.5, height: 1.55, color: scheme.onSurfaceVariant),
            ),
          ]),
        );
    }
  }
}

/// Página 1 · marca y promesa (patrón dp4: tipografía pura, sin logo).
class _PageOne extends StatelessWidget {
  const _PageOne({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        const Spacer(flex: 2),
        RichText(
          text: TextSpan(
            style: VeText.displayNum(44, color: scheme.onSurface, weight: FontWeight.w700),
            children: <InlineSpan>[
              const TextSpan(text: 'Valora'),
              TextSpan(text: 'VE', style: TextStyle(color: scheme.primary)),
            ],
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'Precios y divisas de Venezuela',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
        ),
        const SizedBox(height: 6),
        Text(
          'El instrumento para registrar, comparar y calcular.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 13.5, height: 1.45, color: scheme.onSurfaceVariant),
        ),
        const Spacer(flex: 3),
      ],
    );
  }
}

/// Página 2 · lo que hace (las tres viñetas del dp4).
class _PageTwo extends StatelessWidget {
  const _PageTwo({required this.scheme, required this.sem});

  final ColorScheme scheme;
  final VeInk sem;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const _PageKicker('Lo que hace'),
        const SizedBox(height: 18),
        _WelcomeBullet(
          icon: Icons.swap_horiz,
          color: scheme.primary,
          title: 'Tasas con contexto',
          body: 'Oficial, promedio y paralelo, siempre con la fuente a la vista.',
        ),
        const SizedBox(height: 14),
        _WelcomeBullet(
          icon: Icons.receipt_long_outlined,
          color: sem.pos,
          title: 'Tu libro de precios',
          body: 'Compras como asientos contables, con ticket y totales al cambio.',
        ),
        const SizedBox(height: 14),
        _WelcomeBullet(
          icon: Icons.calculate_outlined,
          color: sem.warn,
          title: 'Cálculos que sirven',
          body: 'Sueldo en divisas, vuelto, presupuesto y análisis del mes.',
        ),
      ],
    );
  }
}

/// Página 3 · datos reales de APIs y todo local (adaptación del aviso
/// «prototipo» del dp4 a la app real: nada de demo, sin cuentas, sin nube).
class _PageThree extends StatelessWidget {
  const _PageThree({required this.scheme});

  final ColorScheme scheme;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        const _PageKicker('Antes de empezar'),
        const SizedBox(height: 18),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(Icons.cloud_done_outlined, size: 20, color: scheme.primary),
                  const SizedBox(width: 8),
                  Text(
                    'Tasas en vivo, datos tuyos',
                    style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: scheme.onSurface),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                'Las cotizaciones llegan de APIs públicas (BCV, paralelo, TRM, '
                'Banxico, Banco Central de Brasil). Tus registros, listas y '
                'finanzas viven solo en este teléfono: sin cuentas ni claves.',
                style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant),
              ),
              const SizedBox(height: 8),
              Text(
                'Si te quedas sin conexión, la app sigue funcionando con el '
                'último tablero guardado y acepta tasas manuales. El tutorial '
                'completo lo puedes relanzar desde Ajustes cuando quieras.',
                style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant),
              ),
              const Divider(height: 22),
              // Leyenda de categorías (dp6): qué significa cada color del libro.
              CategoryLegend(),
            ],
          ),
        ),
      ],
    );
  }
}

/// Rótulo pequeño de sección para las páginas 2 y 3.
class _PageKicker extends StatelessWidget {
  const _PageKicker(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 11.5,
        letterSpacing: 1.2,
        fontWeight: FontWeight.w700,
        color: scheme.primary,
      ),
    );
  }
}

class _WelcomeBullet extends StatelessWidget {
  const _WelcomeBullet({required this.icon, required this.color, required this.title, required this.body});

  final IconData icon;
  final Color color;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Row(
        children: <Widget>[
          Container(
            padding: const EdgeInsets.all(9),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, size: 21, color: color),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  title,
                  style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: scheme.onSurface),
                ),
                const SizedBox(height: 3),
                Text(
                  body,
                  style: TextStyle(fontSize: 12.5, height: 1.4, color: scheme.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
