/// ─── Registro de eventos 100 % LOCAL (v20.4 · talker) ──────────────────────
///
/// `VeLog` envuelve un Talker con buffer en memoria del teléfono: errores de
/// red del tablero, reconexiones SSE, fallos del worker en 2º plano y
/// eventos de la Sala Viva quedan a un toque en Ajustes → Diagnóstico →
/// «Registros de la app».
///
/// PRIVACIDAD (regla del dueño): nada sale del dispositivo — talker es un
/// buffer local, sin telemetría, sin nube, sin cuentas. Rotación acotada a
/// 500 entradas para no crecer sin techo.
library;

import 'package:talker_flutter/talker_flutter.dart';

/// Instancia única de la app (los isolates de fondo tienen el suyo: el
/// buffer no cruza el límite de isolate — se documenta en cada hook).
final Talker veTalker = Talker(
  settings: TalkerSettings(
    enabled: true,
    useHistory: true,
    maxHistoryItems: 500,
    useConsoleLogs: false,
  ),
);

/// Helpers con contexto «Ve» prefijado (grep amigable en el visor).
abstract final class VeLog {
  /// Errores que rompen un camino (fetch fallido, disco lleno…).
  static void e(String where, Object error, [StackTrace? st]) =>
      veTalker.handle(error, st, '[$where]');

  /// Avisos recuperables (sin red, reconexión, tarea en fondo fallida…).
  static void w(String where, String message) =>
      veTalker.warning('[$where] $message');

  /// Eventos informativos (sala creada, respaldo semanal escrito…).
  static void i(String where, String message) => veTalker.info('[$where] $message');
}
