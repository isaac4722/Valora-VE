/// ─── Versión visible de la app (v19.0) ─────────────────────────────────────
/// Fuente ÚNICA de la versión que el usuario ve: pie de constancias (PNG y
/// PDF), totales compartidos y Ajustes → Acerca de. La versión de build
/// sigue viviendo en pubspec.yaml (Regla 5 del AGENT.md); este archivo es el
/// espejo humano que viaja a los documentos generados — antes estaba suelta
/// en settings y los PDF ponían versiones viejas a mano.
library;

/// Versión visible (ronda v22.1 · fuera la herramienta de depuración:
/// el repo es solo la app — sin puente remoto, sin servidor de pruebas
/// dentro de la app; optimizaciones de rendimiento y minSdk estable de
/// la ronda v22.0 intactas).
const String kAppVersionVisible = '22.1';
