/// ─── Onboarding (§9.9 · v18.0) ──────────────────────────────────────────────
/// UNA sola pantalla: marca + lo que hace + datos tuyos + país con banderas.
/// El PageView de 3 páginas (dp4) se RETIRÓ por orden del dueño (v18.0
/// RECHECK): entre la bienvenida paginada y el walkthrough completo la app
/// tenía DOS tutoriales — ahora la bienvenida es una pantalla corta y el
/// ÚNICO tutorial es el walkthrough (app_tour.dart), que arranca solo al
/// terminar la bienvenida y se repite desde Ajustes → Tutorial.
///
/// Flujo: pantalla única (chips preseleccionan el país) → «Comenzar» fija el
/// país → «Todo listo» → a la app. No rejugable como tutorial (decisión del
/// dueño): «Volver a ver la bienvenida» en Ajustes la reabre.
///
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
  int _step = 0; // 0 pantalla única · 1 done
  Country _country = Country.VE;

  Future<void> _finish(BuildContext context, AppStore store) async {
    store.finishOnboarding();
    if (context.mounted) context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    return Scaffold(
      body: SafeArea(
        child: _step == 0
            ? _SingleWelcome(
                country: _country,
                onPickCountry: (c) => setState(() => _country = c),
                onBegin: () {
                  store.setCountry(_country);
                  setState(() => _step = 1);
                },
              )
            : _DoneScreen(country: _country, onFinish: () => _finish(context, store)),
      ),
    );
  }
}

/// ─── Pantalla única ─────────────────────────────────────────────────────────
/// Todo el contenido de las 3 páginas del dp4 condensado en UN scroll corto:
/// marca arriba, tres viñetas, tarjeta «datos reales» y el país con banderas.
class _SingleWelcome extends StatelessWidget {
  const _SingleWelcome({
    required this.country,
    required this.onPickCountry,
    required this.onBegin,
  });

  final Country country;
  final ValueChanged<Country> onPickCountry;
  final VoidCallback onBegin;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);

    return Column(
      children: <Widget>[
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(26, 18, 26, 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                const SizedBox(height: 16),
                // Marca (dp4: tipografía pura, sin logo).
                Center(
                  child: RichText(
                    text: TextSpan(
                      style: VeText.displayNum(40, color: scheme.onSurface, weight: FontWeight.w700),
                      children: <InlineSpan>[
                        const TextSpan(text: 'Valora'),
                        TextSpan(text: 'VE', style: TextStyle(color: scheme.primary)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                    'Precios y divisas de Venezuela',
                    style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: scheme.onSurfaceVariant),
                  ),
                ),
                Center(
                  child: Text(
                    'El instrumento para registrar, comparar y calcular.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 22),
                _WelcomeBullet(
                  icon: Icons.swap_horiz,
                  color: scheme.primary,
                  title: 'Tasas con contexto',
                  body: 'Oficial, promedio y paralelo, siempre con la fuente a la vista.',
                ),
                const SizedBox(height: 12),
                _WelcomeBullet(
                  icon: Icons.receipt_long_outlined,
                  color: sem.pos,
                  title: 'Tu libro de precios',
                  body: 'Compras como asientos contables, con ticket y totales al cambio.',
                ),
                const SizedBox(height: 12),
                _WelcomeBullet(
                  icon: Icons.calculate_outlined,
                  color: sem.warn,
                  title: 'Cálculos que sirven',
                  body: 'Sueldo en divisas, vuelto, presupuesto y análisis del mes.',
                ),
                const SizedBox(height: 18),
                // Datos reales (adaptación del aviso «prototipo» del dp4).
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
                          Expanded(
                            child: Text(
                              'Tasas en vivo, datos tuyos',
                              style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w700, color: scheme.onSurface),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Las cotizaciones llegan de APIs públicas (BCV, paralelo, TRM, '
                        'Banxico, Banco Central de Brasil). Tus registros, listas y '
                        'compras viven solo en este teléfono: sin cuentas ni claves. '
                        'Sin conexión la app sigue igual y acepta tasas manuales.',
                        style: TextStyle(fontSize: 13, height: 1.45, color: scheme.onSurfaceVariant),
                      ),
                      const Divider(height: 22),
                      // Leyenda de categorías (dp6).
                      CategoryLegend(),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                // País EN la bienvenida con BANDERAS reales (assets/flags).
                Center(child: _Kicker('¿Desde dónde miras las tasas?')),
                const SizedBox(height: 10),
                Center(
                  child: Text(
                    'Define el tablero protagonista. Lo puedes cambiar en Ajustes.',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12.5, height: 1.4, color: scheme.onSurfaceVariant),
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 14),
              ],
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(26, 4, 26, 18),
          child: SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onBegin,
              child: Text('Comenzar en ${country.label}'),
            ),
          ),
        ),
      ],
    );
  }
}

/// ─── Cierre ─────────────────────────────────────────────────────────────────
class _DoneScreen extends StatelessWidget {
  const _DoneScreen({required this.country, required this.onFinish});

  final Country country;
  final VoidCallback onFinish;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 34),
        child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(Icons.check_circle_outline, size: 56, color: scheme.primary),
          const SizedBox(height: 18),
          Text('Todo listo', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: scheme.onSurface)),
          const SizedBox(height: 8),
          Text(
            'Tu tablero queda configurado para ${country.label}. Sin conexión funciona igual: registra tasas manuales en Ajustes cuando no haya red. El tutorial completo de la app arranca ahora — y lo puedes repetir desde Ajustes cuando quieras.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 13.5, height: 1.55, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 26),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: onFinish,
              child: const Text('Empezar a usar ValoraVE'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Chip compacto de país (bandera real).
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
          // BANDERA REAL del país (assets/flags): "Global" usa ícono
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

/// Rótulo pequeño de sección.
class _Kicker extends StatelessWidget {
  const _Kicker(this.text);

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
