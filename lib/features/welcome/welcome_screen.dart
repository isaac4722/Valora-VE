/// ─── Onboarding (§9.9): Paso0 Bienvenida → Paso1 País (obligatorio) →
/// Paso2 · 7 slides → Paso3 Done. «Saltar tutorial» disponible desde el
/// paso 2; se puede reabrir desde Ajustes (reopenTutorial). Coach-marks
/// descartables viven en prefs (valorave.tips-dismissed / tip-seen:).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/currencies.dart';
import '../../core/theme.dart';
import '../../data/store.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  int _step = 0;
  Country _country = Country.VE;

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

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.read<AppStore>();

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          child: Column(
            children: [
              Expanded(
                child: _buildStep(context),
              ),
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
                    Row(
                      children: [
                        for (int i = 0; i < (_step == 2 ? _slides.length : 1); i++)
                          Container(
                            width: 6,
                            height: 6,
                            margin: const EdgeInsets.only(left: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: (_step == 2 ? i <= _slideIndex : i == 0)
                                  ? scheme.primary
                                  : scheme.outlineVariant,
                            ),
                          ),
                      ],
                    ),
                    FilledButton(
                      onPressed: () async {
                        if (_step == 0) {
                          setState(() => _step = 1);
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
                            ? 'Comenzar'
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

  int _slideIndex = 0;

  Future<void> _finish(BuildContext context, AppStore store) async {
    store.finishOnboarding();
    if (context.mounted) context.go('/');
  }

  Widget _buildStep(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    switch (_step) {
      case 0:
        return Center(
          child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Container(
              width: 72,
              height: 72,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(20),
              ),
              alignment: Alignment.center,
              child: const Text('V', style: TextStyle(
                  fontFamily: 'SpaceGrotesk', fontSize: 38,
                  fontWeight: FontWeight.w700, color: Colors.white)),
            ),
            const SizedBox(height: 22),
            Text('ValoraVE', style: VeText.displayNum(30, color: scheme.onSurface)),
            const SizedBox(height: 10),
            Text(
              'Cuánto vale tu dinero en Venezuela: tasas, conversor, lista en vivo y libro de precios. Todo en tu teléfono, sin cuentas.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14, height: 1.5, color: scheme.onSurfaceVariant),
            ),
          ]),
        );
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
