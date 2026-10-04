/// welcome_screen.dart — Onboarding ValoraVE [Linear Edition]
/// Paso 0: Bienvenida -> Paso 1: País -> Paso 2: 7 Slides -> Paso 3: Done
library;

import \'package:flutter/material.dart\';
import \'package:flutter/services.dart\';
import \'package:go_router/go_router.dart\';
import \'package:lucide_icons_flutter/lucide_icons.dart\';
import \'package:provider/provider.dart\';
import \'package:shadcn_ui/shadcn_ui.dart\';

import \'../../core/currencies.dart\';
import \'../../data/store.dart\';
import \'../../widgets/ve/ve.dart\';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> with TickerProviderStateMixin {
  int _step = 0; // 0: welcome, 1: country, 2: slides, 3: done
  int _slideIndex = 0;
  Country _country = Country.VE;
  
  late final PageController _pageController;
  late final AnimationController _fadeController;

  static const _slides = [
    (LucideIcons.arrowLeftRight, \'Las tasas que importan\', \'BCV, paralelo, promedio y aristas del euro. Con TRM, Banxico y Real. El promedio es local: (BCV + paralelo) / 2.\', \'Sin intermediarios\'),
    (LucideIcons.calendarDays, \'Conversor con fecha\', \'¿Cuánto valía ayer? El conversor acepta fecha histórica y te muestra la ruta exacta del cálculo.\', \'Auditable\'),
    (LucideIcons.shoppingCart, \'Lista que comparte en vivo\', \'Presupuesto, vuelto y división de cuenta. Comparte con un código de 6 letras. Cambios al instante.\', \'P2P Realtime\'),
    (LucideIcons.bookMarked, \'Libro de precios\', \'Registra por tienda y producto. Fija metas y te avisamos cuando el precio cae.\', \'Ahorro inteligente\'),
    (LucideIcons.chartSpline, \'Brecha y devaluación\', \'Curvas BCV ↔ paralelo, calendario de devaluación e inflación personal con proyección amortiguada.\', \'Análisis real\'),
    (LucideIcons.bellRing, \'Avisos con cabeza\', \'Picos de tasa, metas y brechas. Tú defines los umbrales. Cero ruido.\', \'Solo lo importante\'),
    (LucideIcons.smartphone, \'Todo en tu teléfono\', \'Sin cuentas, sin nube. Datos locales, respaldo JSON, widgets y modo offline desde el arranque.\', \'Offline-first\'),
  ];

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _fadeController = AnimationController(vsync: this, duration: const Duration(milliseconds: 350));
    _fadeController.forward();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  void _next(AppStore store) {
    HapticFeedback.lightImpact();
    if (_step == 0) {
      _animateStep(1);
    } else if (_step == 1) {
      store.setCountry(_country);
      _animateStep(2);
    } else if (_step == 2) {
      if (_slideIndex < _slides.length - 1) {
        _pageController.nextPage(duration: const Duration(milliseconds: 350), curve: Curves.easeOutCubic);
      } else {
        _animateStep(3);
      }
    } else {
      _finish(store);
    }
  }

  void _animateStep(int next) {
    _fadeController.reverse().then((_) {
      setState(() => _step = next);
      _fadeController.forward();
    });
  }

  Future<void> _finish(AppStore store) async {
    await HapticFeedback.mediumImpact();
    store.finishOnboarding();
    if (mounted) context.go(\'/\');
  }

  double get _progress {
    if (_step == 0) return 0.15;
    if (_step == 1) return 0.35;
    if (_step == 2) return 0.35 + (0.55 * ((_slideIndex + 1) / _slides.length));
    return 1.0;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final theme = ShadTheme.of(context);

    return Scaffold(
      backgroundColor: theme.colorScheme.background,
      body: Stack(
        children: [
          // 1. Fondo ambiental Linear
          const VeAmbient(
            opacity: 0.6,
            child: SizedBox.expand(),
          ),
          
          // 2. Contenido
          SafeArea(
            child: Column(
              children: [
                // Header: Progreso + Acciones
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 16, 24, 0),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          VeEyebrow(
                            _step == 2 ? \'TUTORIAL ${_slideIndex + 1} / ${_slides.length}\' 
                            : _step == 3 ? \'COMPLETADO\' 
                            : \'VALORAVE • ONBOARDING\',
                          ),
                          if (_step == 2)
                            VeBtn(
                              label: \'Saltar\',
                              variant: VeBtnVariant.ghost,
                              size: VeBtnSize.sm,
                              onPressed: () => _animateStep(3),
                            ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      // Barra de progreso Linear
                      ClipRRect(
                        borderRadius: BorderRadius.circular(99),
                        child: LinearProgressIndicator(
                          value: _progress,
                          minHeight: 2,
                          backgroundColor: theme.colorScheme.muted,
                          valueColor: AlwaysStoppedAnimation(theme.colorScheme.primary),
                        ),
                      ),
                    ],
                  ),
                ),

                // Body Animado
                Expanded(
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24),
                      child: _buildStepContent(context),
                    ),
                  ),
                ),

                // 3. Sticky Bar Inferior
                VeStickyBar(
                  child: Row(
                    children: [
                      if (_step > 0 && _step < 3)
                        VeBtn(
                          label: \'Atrás\',
                          variant: VeBtnVariant.ghost,
                          icon: LucideIcons.chevronLeft,
                          onPressed: () {
                            HapticFeedback.selectionClick();
                            if (_step == 2 && _slideIndex > 0) {
                              _pageController.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
                            } else {
                              _animateStep(_step - 1);
                            }
                          },
                        )
                      else
                        const SizedBox(width: 80),

                      const Spacer(),

                      // Dots solo en slides
                      if (_step == 2)
                        Row(
                          children: List.generate(_slides.length, (i) {
                            final isActive = i == _slideIndex;
                            final isPast = i < _slideIndex;
                            return AnimatedContainer(
                              duration: const Duration(milliseconds: 300),
                              margin: const EdgeInsets.only(right: 6),
                              width: isActive ? 20 : 6,
                              height: 6,
                              decoration: BoxDecoration(
                                color: isActive ? theme.colorScheme.primary 
                                      : isPast ? theme.colorScheme.primary.withOpacity(0.4)
                                      : theme.colorScheme.border,
                                borderRadius: BorderRadius.circular(99),
                              ),
                            );
                          }),
                        ),

                      const Spacer(),

                      VeBtn(
                        label: _step == 0 ? \'Comenzar\' 
                               : _step == 1 ? \'Continuar\' 
                               : _step == 2 ? (_slideIndex == _slides.length - 1 ? \'Finalizar\' : \'Siguiente\')
                               : \'Empezar a usar ValoraVE\',
                        icon: _step == 3 ? LucideIcons.sparkles : LucideIcons.arrowRight,
                        iconTrailing: true,
                        onPressed: () => _next(store),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent(BuildContext context) {
    final theme = ShadTheme.of(context);
    switch (_step) {
      case 0:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 80, height: 80,
              decoration: BoxDecoration(
                color: theme.colorScheme.primary,
                borderRadius: BorderRadius.circular(24),
                boxShadow: [BoxShadow(color: theme.colorScheme.primary.withOpacity(0.2), blurRadius: 24, offset: const Offset(0, 8))],
              ),
              child: const Center(child: Text(\'V\', style: TextStyle(fontFamily: \'SpaceGrotesk\', fontSize: 42, fontWeight: FontWeight.w800, color: Colors.white))),
            ),
            const SizedBox(height: 28),
            VeTitle(\'Cuánto vale\ntu dinero.\', align: TextAlign.center),
            const SizedBox(height: 12),
            Text(
              \'Tasas, conversor histórico, lista en vivo y libro de precios.\nTodo en tu teléfono. Sin cuentas, sin humo.\',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14.5, height: 1.6, color: theme.colorScheme.mutedForeground),
            ),
            const SizedBox(height: 24),
            VeGroup(
              children: [
                _FeatureRow(icon: LucideIcons.zap, text: \'Tasas BCV + Paralelo en tiempo real\'),
                _FeatureRow(icon: LucideIcons.shieldCheck, text: \'100% offline y privado\'),
                _FeatureRow(icon: LucideIcons.users, text: \'Listas P2P sin registro\'),
              ],
            )
          ],
        );

      case 1:
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const VeEyebrow(\'PASO 1 DE 3\'),
            const SizedBox(height: 8),
            const VeTitle(\'Elige tu tablero\', size: 28),
            const SizedBox(height: 8),
            Text(\'Define la moneda protagonista. Podrás cambiarlo en Ajustes.\', style: TextStyle(color: theme.colorScheme.mutedForeground, fontSize: 13.5)),
            const SizedBox(height: 24),
            ...Country.values.map((c) {
              final selected = _country == c;
              return Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: VePanelCard(
                  selected: selected,
                  onTap: () {
                    HapticFeedback.selectionClick();
                    setState(() => _country = c);
                  },
                  child: Row(
                    children: [
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: selected ? theme.colorScheme.primary : theme.colorScheme.muted,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Icon(c == Country.VE ? LucideIcons.mapPin : c == Country.CO ? LucideIcons.flag : LucideIcons.globe, size: 18, color: selected ? Colors.white : theme.colorScheme.mutedForeground),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(c.label, style: TextStyle(fontWeight: FontWeight.w600, fontSize: 14, color: theme.colorScheme.foreground)),
                          Text(c == Country.VE ? \'Bolívar • BCV / Paralelo\' : c.currency.code, style: TextStyle(fontSize: 12, color: theme.colorScheme.mutedForeground)),
                        ]),
                      ),
                      if (selected) Icon(LucideIcons.circleCheck, color: theme.colorScheme.primary, size: 20)
                      else Icon(LucideIcons.circle, color: theme.colorScheme.border, size: 20),
                    ],
                  ),
                ),
              );
            }),
          ],
        );

      case 2:
        return PageView.builder(
          controller: _pageController,
          onPageChanged: (i) => setState(() => _slideIndex = i),
          itemCount: _slides.length,
          itemBuilder: (context, i) {
            final s = _slides[i];
            return Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  width: 64, height: 64,
                  decoration: BoxDecoration(color: theme.colorScheme.primary.withOpacity(0.08), borderRadius: BorderRadius.circular(18), border: Border.all(color: theme.colorScheme.border)),
                  child: Icon(s.$1, size: 28, color: theme.colorScheme.primary),
                ),
                const SizedBox(height: 22),
                VeBadge(label: s.$4, variant: VeBadgeVariant.muted),
                const SizedBox(height: 14),
                Text(s.$2, textAlign: TextAlign.center, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.5, color: theme.colorScheme.foreground)),
                const SizedBox(height: 12),
                Text(s.$3, textAlign: TextAlign.center, style: TextStyle(fontSize: 14, height: 1.6, color: theme.colorScheme.mutedForeground)),
              ],
            );
          },
        );

      default: // step 3
        return Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 72, height: 72,
              decoration: BoxDecoration(color: const Color(0xFF10B981).withOpacity(0.1), shape: BoxShape.circle),
              child: const Icon(LucideIcons.check, color: Color(0xFF10B981), size: 32),
            ),
            const SizedBox(height: 20),
            const VeTitle(\'Todo listo.\', align: TextAlign.center),
            const SizedBox(height: 10),
            Text(
              \'Tu tablero está configurado para ${_country.label}.\nFunciona sin conexión: puedes cargar tasas manuales en Ajustes.\',
              textAlign: TextAlign.center,
              style: TextStyle(color: theme.colorScheme.mutedForeground, height: 1.6, fontSize: 13.5),
            ),
            const SizedBox(height: 20),
            VeCard(
              padding: const EdgeInsets.all(14),
              child: Row(children: [
                Icon(LucideIcons.lightbulb, size: 16, color: theme.colorScheme.primary),
                const SizedBox(width: 10),
                Expanded(child: Text(\'Tip: Agrega el widget de tasa a tu home screen.\', style: TextStyle(fontSize: 12.5, color: theme.colorScheme.mutedForeground))),
              ]),
            )
          ],
        );
    }
  }
}

class _FeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;
  const _FeatureRow({required this.icon, required this.text});
  @override
  Widget build(BuildContext context) {
    final theme = ShadTheme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        Icon(icon, size: 14, color: theme.colorScheme.primary),
        const SizedBox(width: 8),
        Text(text, style: TextStyle(fontSize: 12.5, color: theme.colorScheme.mutedForeground, fontWeight: FontWeight.w500)),
      ]),
    );
  }
}
