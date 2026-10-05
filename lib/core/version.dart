/// ─── Versión visible de la app (v19.0) ─────────────────────────────────────
/// Fuente ÚNICA de la versión que el usuario ve: pie de constancias (PNG y
/// PDF), totales compartidos y Ajustes → Acerca de. La versión de build
/// sigue viviendo en pubspec.yaml (Regla 5 del AGENT.md); este archivo es el
/// espejo humano que viaja a los documentos generados — antes estaba suelta
/// en settings y los PDF ponían versiones viejas a mano.
library;

/// Versión visible (ronda v21.3 · fiabilidad: el respaldo BCV de Venezuela
/// pasa de pydolarve.org —dominio caducado desde 07/2025— a DolarVZLA
/// rates.dolarvzla.com, CDN sin auth y con CORS abierto).
const String kAppVersionVisible = '21.3';
