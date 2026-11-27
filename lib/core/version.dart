/// ─── Versión visible de la app (v19.0) ─────────────────────────────────────
/// Fuente ÚNICA de la versión que el usuario ve: pie de constancias (PNG y
/// PDF), totales compartidos y Ajustes → Acerca de. La versión de build
/// sigue viviendo en pubspec.yaml (Regla 5 del AGENT.md); este archivo es el
/// espejo humano que viaja a los documentos generados — antes estaba suelta
/// en settings y los PDF ponían versiones viejas a mano.
library;

/// Versión visible (ronda v33 · revisión Goldfish de textos: ortografía y
/// gramática de la UI y la documentación, README al día con la realidad
/// v31/v32 — solo APK, cuatro transportes de Sala, Ajustes por secciones —
/// y bitácoras al día con las rondas v25 y v29–v32).
const String kAppVersionVisible = '33';
