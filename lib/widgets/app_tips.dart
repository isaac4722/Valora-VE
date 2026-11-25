/// ─── Tips contextuales con reglas (v19.0, orden del dueño) ──────────────────
/// La MISMA forma visual del tutorial (motor coach_mark.dart), pero disparada
/// por REGLAS y no por el onboarding: cada tip sale «en algún momento X»,
/// cuando ocurre la acción a la que ayuda.
///
/// Reglas del motor (todas configurables aquí):
/// · El tutorial manda: sin tour visto (completo o saltado) NO hay tips —
///   nunca se apilan sobre el onboarding.
/// · Sesiones: los tips empiezan a partir de la SEGUNDA apertura de la app
///   (valorave.sessions): nada de tips «de una vez» tras el tutorial.
/// · Frecuencia: a lo sumo UN tip cada 6 h (valorave.tip.last) y UNO por
///   evaluación — espaciados, nunca una cortina de consejos.
/// · Una sola vez: cada tip se ve UNA vez por instalación
///   (clave `valorave.tip.<id>`), y se marca ANTES de mostrarse.
/// · Un overlay a la vez: si el tour corre o hay un tip en pantalla, se
///   salta la evaluación en silencio.
///
/// Disparadores: [runTipsForScope] (post-frame de cada pantalla, con su
/// scope) y [maybeShowTipOnce] (bajo nivel, para disparadores propios como
/// la Sala Viva al conectarse).
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/currencies.dart';
import '../data/store.dart';
import 'app_tour.dart' show TourKeys, isTourDone;

/// Preferencias del motor.
const String kTipPrefix = 'valorave.tip.';
const String kTipLastAt = 'valorave.tip.last';
const String kSessionsKey = 'valorave.sessions';
const int kTipMinSessions = 2;
const Duration kTipCooldown = Duration(hours: 6);

/// Regla de un tip: QUÉ dice, DÓNDE enfoca (misma ancla que el tour cuando
/// aplica) y CUÁNDO aplica ([when] sobre el estado vivo de la app).
class TipRule {
  const TipRule({
    required this.id,
    required this.scope,
    required this.title,
    required this.body,
    this.anchor,
    this.flags = const <Currency>[],
    required this.when,
  });

  final String id;

  /// Pantalla que lo dispara: 'home' · 'conversor' · 'lista' · 'productos'.
  final String scope;
  final String title;
  final String body;
  final GlobalKey? anchor;
  final List<Currency> flags;
  final bool Function(AppStore store) when;
}

/// Catálogo de tips (v19.0). Cortos, exactos y con contexto real: cada uno
/// enseña algo que la zona enfocada HACE, en el momento en que sirve.
final List<TipRule> kTipRules = <TipRule>[
  TipRule(
    id: 'home.manual',
    scope: 'home',
    anchor: TourKeys.cotizacion,
    title: 'Sin red, sin problema',
    body:
        'Pega tu propia tasa: en «Tasas» toca la fila Manual y escribe el '
        'valor. No necesitas ir a Ajustes y la app calcula con ella al instante.',
    when: (s) => s.data.manualRates.isEmpty && s.snapshots.isNotEmpty,
  ),
  TipRule(
    id: 'conversor.fecha',
    scope: 'conversor',
    anchor: TourKeys.convFecha,
    title: 'La tasa de otro día',
    body:
        'Toca «Ayer» o «Elegir fecha» para calcular con la tasa real de ese '
        'día, guardada en tu teléfono. Útil para cuentas pasadas.',
    when: (s) => s.snapshots.length >= 2,
  ),
  TipRule(
    id: 'conversor.inverso',
    scope: 'conversor',
    anchor: TourKeys.convFuente,
    title: 'Escribe en cualquiera de los dos',
    body:
        'El campo de abajo también se edita: escribe lo que quieres '
        'CONSEGUIR y la app te dice cuánto ENTREGAR. Perfecto para el '
        'vuelto.',
    when: (s) => true,
  ),
  TipRule(
    id: 'lista.finalizar',
    scope: 'lista',
    anchor: TourKeys.listaSala,
    title: 'Cierra la compra',
    body:
        'Con la lista lista, «Finalizar compra» guarda tienda, monto y '
        'ticket en tu historial — y alimenta los gastos de Análisis.',
    when: (s) => s.cart.length >= 5,
  ),
  TipRule(
    id: 'lista.presupuesto',
    scope: 'lista',
    title: 'Presupuesto en tu moneda',
    body:
        'Fija el presupuesto en la divisa que uses: elígela junto al '
        'monto y la barra te dice cuánto llevas consumido.',
    when: (s) => s.data.budget.amount <= 0 && s.cart.length >= 3,
  ),
  TipRule(
    id: 'productos.meta',
    scope: 'productos',
    anchor: TourKeys.prodBusqueda,
    title: 'Metas de precio',
    body:
        'En la ficha de un producto puedes fijar una META: cuando su '
        'último precio quede por debajo, te avisamos.',
    when: (s) => s.products.length >= 3,
  ),
];

/// ─── Estado puro (testeable sin UI) ─────────────────────────────────────────
/// ¿El motor está habilitado? Tutorial visto + suficientes sesiones +
/// cooldown cumplido. [now] seam para tests.
bool tipsEngineEnabled(SharedPreferences prefs, {DateTime? now}) {
  if (!isTourDone(prefs)) return false;
  final sessions = prefs.getInt(kSessionsKey) ?? 0;
  if (sessions < kTipMinSessions) return false;
  final last = prefs.getInt(kTipLastAt) ?? 0;
  if (last > 0 &&
      (now ?? DateTime.now()).millisecondsSinceEpoch - last <
          kTipCooldown.inMilliseconds) {
    return false;
  }
  return true;
}

bool isTipShown(SharedPreferences prefs, String id) =>
    prefs.getBool('$kTipPrefix$id') ?? false;

/// Bajo nivel: muestra UN tip una única vez (id ya visto → no-op). Respeta
/// los gates del motor; devuelve true si se mostró. Para disparadores
/// propios (p. ej. la Sala Viva al conectarse).
///
/// v28 (regla del dueño «sin sobrecapas»): el motor QUEDA DESACTIVADO — los
/// tips contextuales eran capas superpuestas sobre el contenido y
/// complicaban la navegación. La guía vive ahora EN la página (descripción
/// de cada sección). El catálogo [kTipRules] se conserva intacto por si el
/// dueño quiere reactivar el motor.
Future<bool> maybeShowTipOnce(
  BuildContext context, {
  required WidgetRef ref,
  required String id,
  required String title,
  required String body,
  GlobalKey? anchor,
  List<Currency> flags = const <Currency>[],
  bool force = false,
}) async {
  // v28 · sobrecapas fuera: NINGÚN overlay de tips, ni siquiera a pedido.
  return false;
}

/// Punto de entrada por pantalla: evalúa las reglas del [scope] contra el
/// estado vivo y muestra a lo sumo EL PRIMER tip que aplique. Post-frame de
/// cada pantalla (TipsTrigger) — barato cuando nada aplica.
///
/// v28 · sobrecapas fuera: el disparador por pantalla es no-op (ver
/// [maybeShowTipOnce]). La orientación vive en la descripción de cada sección.
Future<void> runTipsForScope(
  BuildContext context,
  WidgetRef ref,
  String scope,
) async {
  return;
}

/// Widget de cero píxeles que dispara la evaluación del scope tras el
/// primer frame de la pantalla que lo monta (igual que _TourTrigger).
class TipsTrigger extends ConsumerStatefulWidget {
  const TipsTrigger({super.key, required this.scope});

  final String scope;

  @override
  ConsumerState<TipsTrigger> createState() => _TipsTriggerState();
}

class _TipsTriggerState extends ConsumerState<TipsTrigger> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) runTipsForScope(context, ref, widget.scope);
    });
  }

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
