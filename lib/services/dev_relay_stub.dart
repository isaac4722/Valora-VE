/// ─── Stub web del puente sin PC (v21.7) ─────────────────────────────────────
/// `dart:io` (WebSocket de cliente) no existe en el build web: esta versión
/// no-op mantiene la MISMA API estática que dev_relay_vm.dart para que
/// main.dart y Ajustes compilen idénticos en todas las plataformas. El
/// puente sin PC solo tiene sentido sobre el teléfono físico — igual que el
/// servidor de pruebas (DevBridge), no hay nada que compensar en web.
library;

import 'package:flutter/widgets.dart';

class DevRelay {
  /// Igual que la VM: constantes de preferencias y API completa. Las firmas
  /// regresan los MISMOS tipos para que los dependientes compilen igual.
  static const String kPrefUrl = 'valorave.relay-url';
  static const String kPrefToken = 'valorave.relay-token';
  static const String kPrefAuto = 'valorave.relay-auto';

  static bool get supported => false;
  static bool get connected => false;
  static String get status => 'off';
  static bool get configured => false;
  static String get url => '';

  static Future<void> init({
    required dynamic store,
    required dynamic prefs,
  }) async {}

  static Future<bool> connect({required dynamic store}) async => false;

  static Future<void> disconnect() async {}

  static void loadConfig(dynamic prefs) {}

  static Future<void> saveConfig(
    dynamic prefs, {
    required String url,
    required String token,
  }) async {}

  static Future<void> setAuto(dynamic prefs, {required bool on}) async {}

  /// En web no hay canal que despache comandos: error honesto.
  static Future<(Map<String, dynamic>, List<int>?)> handleCmd(
    Map<String, dynamic> msg,
  ) async {
    final id = (msg['id'] as String?) ?? '';
    return (
      {
        'type': 'result',
        'id': id,
        'ok': false,
        'error': 'Puente sin PC no disponible en web — vive en el teléfono.',
      },
      null,
    );
  }
}

class DevCapture {
  static final GlobalKey key = GlobalKey();

  /// En web no hay captura (stub): el builder de main.dart pasa de largo.
  static Widget wrap(BuildContext context, Widget? child) =>
      child ?? const SizedBox.shrink();

  static Future<List<int>?> capture({double targetWidth = 720}) async => null;
}
