/// ─── Versión visible de la app (v19.0) ─────────────────────────────────────
/// Fuente ÚNICA de la versión que el usuario ve: pie de constancias (PNG y
/// PDF), totales compartidos y Ajustes → Acerca de. La versión de build
/// sigue viviendo en pubspec.yaml (Regla 5 del AGENT.md); este archivo es el
/// espejo humano que viaja a los documentos generados — antes estaba suelta
/// en settings y los PDF ponían versiones viejas a mano.
library;

/// Versión visible (ronda v22.3 · actualizador del canal dev: la app se
/// entera de las Releases de GitHub del propio repo y descarga el APK de
/// cada ronda desde el navegador).
const String kAppVersionVisible = '22.3';
