/// ─── Onboarding (§9.9 · v17.8) ─────────────────────────────────────────────
/// Paso0 Bienvenida (3 páginas dp4) → Paso1 País (obligatorio) → Paso2 Done.
/// El tutorial de 7 slides (PageView) se RETIRÓ por orden del dueño: la app
/// tiene ahora UN walkthrough completo (app_tour.dart) que arranca solo al
/// terminar la bienvenida y se repite desde Ajustes → Tutorial. La
/// bienvenida multipantalla del dp4 NO es rejugable (decisión del dueño):
/// una sola vez en la primera instalación; «Volver a ver la bienvenida»
/// en Ajustes la reabre.
///
/// Página 1 · marca y promesa. Página 2 · lo que hace la app.
/// Página 3 · datos reales de APIs y offline-first + país con banderas.
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
  int _step = 0; // 0 bienvenida · 1 país · 2 done
  Country _country = Country.VE;

  static const int _kWelcomePages = 3;

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
                          _PageThree(
                            scheme: scheme,
                            country: _country,
                            onPickCountry: (c) => setState(() => _country = c),
                          ),
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
                    if (_step > 0)
                      TextButton(
                        onPressed: () => setState(() => _step--),
                        child: const Text('Atrás'),
                      )
                    else
                      const SizedBox(width: 80),
                    FilledButton(
                      onPressed: () {
                        if (_step == 0) {
                          _nextWelcomePage();
                        } else if (_step == 1) {
                          store.setCountry(_country);
                          setState(() => _step = 2);
                        } else {
                          _finish(context, store);
                        }
                      },
                      child: Text(
                        _step == 0
                            ? (_welcomePage < _kWelcomePages - 1 ? 'Siguiente' : 'Comenzar')
                            : _step == 1
                                ? 'Elegir ${_country.label}'
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
                      // BANDERA REAL (assets/flags): la selección de país
                      // nunca más un icono genérico (v17.8, orden del dueño).
                      Flag(c.currency, size: 22),
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
      default:
        return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.check_circle_outline, size: 56, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 18),
            Text('Todo listo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Text(
              'Tu tablero queda configurado para ${_country.label}. Sin conexión funciona igual: registra tasas manuales en Ajustes cuando no haya red. El tutorial completo de la app arranca ahora — y lo puedes repetir desde Ajustes cuando quieras.',
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
/// Ola 1 (protocolo v2): el PAÍS se elige aquí — la bienvenida completa al
/// paso obligatorio con la selección ya hecha (confirmación, no sorpresa).
class _PageThree extends StatelessWidget {
  const _PageThree({required this.scheme, required this.country, required this.onPickCountry});

  final ColorScheme scheme;
  final Country country;
  final ValueChanged<Country> onPickCountry;

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
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
                  'compras viven solo en este teléfono: sin cuentas ni claves.',
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
          const SizedBox(height: 14),
          // Ola 1 → v17.8: el país EN la bienvenida con BANDERAS reales
          // (assets/flags) — chips compactos que preseleccionan el paso
          // obligatorio siguiente.
          Text('¿DESDE DÓNDE MIRAS LAS TASAS?',
              style: VeText.labelCaps(9.5, color: scheme.primary)),
          const SizedBox(height: 8),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            alignment: WrapAlignment.center,
            children: [
              for (final c in Country.values)
                _CountryChip(
                  country: c,
                  selected: country == c,
                  onTap: () => onPickCountry(c),
                ),
            ],
          ),
          const SizedBox(height: 12),
        ],
      ),
    );
  }
}

/// Chip compacto de país para la página 3 de la bienvenida (Ola 1).
class _CountryChip extends StatelessWidget {
  const _CountryChip({required this.country, required this.selected, required this.onTap});

  final Country country;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
              color: selected ? scheme.primary : scheme.outlineVariant,
              width: selected ? 1.4 : 1),
          color: selected ? scheme.primary.withValues(alpha: 0.07) : scheme.surface,
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          // BANDERA REAL del país (assets/flags, v17.8): "Global" usa ícono
          // public porque USD no tiene bandera de país.
          country == Country.US
              ? Icon(Icons.public, size: 14, color: scheme.primary)
              : Flag(country.currency, size: 14),
          const SizedBox(width: 6),
          Text(country.label,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: selected ? FontWeight.w800 : FontWeight.w500)),
        ]),
      ),
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
