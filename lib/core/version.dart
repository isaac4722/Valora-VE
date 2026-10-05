/// ─── Versión visible de la app (v19.0) ─────────────────────────────────────
/// Fuente ÚNICA de la versión que el usuario ve: pie de constancias (PNG y
/// PDF), totales compartidos y Ajustes → Acerca de. La versión de build
/// sigue viviendo en pubspec.yaml (Regla 5 del AGENT.md); este archivo es el
/// espejo humano que viaja a los documentos generados — antes estaba suelta
/// en settings y los PDF ponían versiones viejas a mano.
library;

/// Versión visible (ronda v21.2 · tacto y movimiento: transición unificada
/// de pantallas empujadas, háptica sutil en confirmaciones clave y
/// controles mudos que hablan — tooltips y semántica).
const String kAppVersionVisible = '21.2';
