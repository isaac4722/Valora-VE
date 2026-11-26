/// ─── Versión visible de la app (v19.0) ─────────────────────────────────────
/// Fuente ÚNICA de la versión que el usuario ve: pie de constancias (PNG y
/// PDF), totales compartidos y Ajustes → Acerca de. La versión de build
/// sigue viviendo en pubspec.yaml (Regla 5 del AGENT.md); este archivo es el
/// espejo humano que viaja a los documentos generados — antes estaba suelta
/// en settings y los PDF ponían versiones viejas a mano.
library;

/// Versión visible (ronda v31 · revisión integral del dueño:
/// reconstrucción v29/v30 — Conversor calculadora con «Mañana», Lista sin
/// plantillas con sala propia, Análisis en 4 secciones, Más sin
/// duplicados, Ajustes en UNA pantalla con cuentas por tipo de cobro —
/// más exportación PDF/imágenes profesional y builds solo APK).
const String kAppVersionVisible = '31';
