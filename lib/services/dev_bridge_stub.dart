/// ─── Stub web del servidor de pruebas (v21.6) ───────────────────────────────
/// `dart:io` (HttpServer) no existe en el build web: esta versión no-op
/// mantiene la MISMA API estática que dev_bridge_vm.dart para que las
/// llamadas de main.dart y Ajustes compilen en todas las plataformas.
/// El puente remoto solo tiene sentido sobre un teléfono físico (ADB),
/// así que no hay nada que compensar en web.
library;

class DevBridge {
  /// Igual que la VM: constantes de preferencias y API de arranque completa.
  /// Las firmas regresan los MISMOS tipos (start → `Future<bool>`) para que
  /// los dependientes compilen idénticos contra cualquiera de las dos.
  static const int kBasePort = 8090;
  static const String kPrefEnabled = 'valorave.dev-server';
  static const String kPrefToken = 'valorave.dev-token';

  static bool get supported => false;
  static bool get running => false;
  static int get port => 0;
  static String? get token => null;
  static int get uptimeSec => 0;

  /// main.dart: lee la preferencia y arranca si corresponde. No-op en web.
  static Future<void> init({
    required dynamic store,
    required dynamic prefs,
    bool debug = false,
  }) async {}

  static Future<bool> start({required dynamic store, int? port}) async =>
      false;

  static Future<void> stop() async {}

  /// Token mostrado en Ajustes (solo lectura aquí: se crea en el teléfono).
  static String ensureToken(dynamic prefs) => '';

  /// ValoraApp: vincula el router único para el endpoint /nav. No-op en web.
  static void bindRouter(dynamic router) {}
}
