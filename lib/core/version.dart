/// ─── Versión visible de la app (v19.0) ─────────────────────────────────────
/// Fuente ÚNICA de la versión que el usuario ve: pie de constancias (PNG y
/// PDF), totales compartidos y Ajustes → Acerca de. La versión de build
/// sigue viviendo en pubspec.yaml (Regla 5 del AGENT.md); este archivo es el
/// espejo humano que viaja a los documentos generados — antes estaba suelta
/// en settings y los PDF ponían versiones viejas a mano.
library;

/// Versión visible (ronda v21.4 · arranque: el slide 1 de la bienvenida ya
/// no muestra «Atrás» — un control muerto a la vista confunde al usuario
/// nuevo; se desvanece y el hueco se reserva para que los puntos no salten).
const String kAppVersionVisible = '21.4';
