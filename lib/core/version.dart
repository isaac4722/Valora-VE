/// ─── Versión visible de la app (v19.0) ─────────────────────────────────────
/// Fuente ÚNICA de la versión que el usuario ve: pie de constancias (PNG y
/// PDF), totales compartidos y Ajustes → Acerca de. La versión de build
/// sigue viviendo en pubspec.yaml (Regla 5 del AGENT.md); este archivo es el
/// espejo humano que viaja a los documentos generados — antes estaba suelta
/// en settings y los PDF ponían versiones viejas a mano.
library;

/// Versión visible (ronda v22.0 · «la app directa»: repo limpio de
/// documentación de proceso, rendimiento en dispositivos humildes
/// (copyWith O(campo), cinta aislada, sticky sin blur), minSdk al mínimo
/// estable del framework (24 · Android 7.0) y GUI más clara).
const String kAppVersionVisible = '22.0';
