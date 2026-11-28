/// ─── Versión visible de la app (v19.0) ─────────────────────────────────────
/// Fuente ÚNICA de la versión que el usuario ve: pie de constancias (PNG y
/// PDF), totales compartidos y Ajustes → Acerca de. La versión de build
/// sigue viviendo en pubspec.yaml (Regla 5 del AGENT.md); este archivo es el
/// espejo humano que viaja a los documentos generados — antes estaba suelta
/// en settings y los PDF ponían versiones viejas a mano.
library;

/// Versión visible (ronda v34 · GUI del dueño: fixes de la ronda de
/// errores — barra de bienvenida centrada, bandera US en Global/USD,
/// frescura por última consulta, icono del tema centrado, conversor sin
/// notas y con código de colores por tipo de tasa, tarjetas en Inicio,
/// Ajustes, Sala y rejerarquización de la Lista).
const String kAppVersionVisible = '34';
