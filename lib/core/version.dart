/// ─── Versión visible de la app (v19.0) ─────────────────────────────────────
/// Fuente ÚNICA de la versión que el usuario ve: pie de constancias (PNG y
/// PDF), totales compartidos y Ajustes → Acerca de. La versión de build
/// sigue viviendo en pubspec.yaml (Regla 5 del AGENT.md); este archivo es el
/// espejo humano que viaja a los documentos generados — antes estaba suelta
/// en settings y los PDF ponían versiones viejas a mano.
library;

/// Versión visible (ronda v21.7 · puente sin PC: la app conecta al relay del
/// preview con WebSocket saliente (rol bridge) — «todo dentro de la preview»
/// sin helper en la PC del dueño; captura de UI viva vía RepaintBoundary).
const String kAppVersionVisible = '21.7';
