/// ─── Deep link de la Sala (v19.8 · orden del dueño) ─────────────────────────
/// El QR de una sala es un enlace `valorave://sala?c=CODE&m=MODE&p=0|1`.
/// Escaneado con la CÁMARA del teléfono (cualquier app de escáner), el
/// sistema ofrece abrir ValoraVE: la app arranca, el servicio recibe el
/// enlace (inicial o en caliente), lo parsea a [SalaInvite] y navega al
/// lobby de la Sala, que abre la hoja de unirse (modo · nombre · PIN) y
/// conecta si la sala sigue activa.
///
/// Transporte: MethodChannel `valorave/deeplink` contra MainActivity.kt
/// (initialIntent + onNewIntent). En web/tests el canal no existe y todo
/// degrada en silencio — nada de la app depende de él.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../room/room_transport.dart';

/// Invitación pendiente de un deep link: el lobby la consume al abrirse.
final ValueNotifier<SalaInvite?> salaInviteRequest = ValueNotifier<SalaInvite?>(
  null,
);

class DeepLinkService {
  DeepLinkService._();

  static const MethodChannel _channel = MethodChannel('valorave/deeplink');
  static GoRouter? _router;

  /// Se llama desde ValoraApp (initState) con el router ÚNICO de la sesión.
  static void bind(GoRouter router) => _router = router;

  /// Registra el handler de enlaces en caliente y toma el enlace inicial
  /// (el que ABRÓ la app). Tolerante: sin canal (web/tests) no pasa nada.
  static Future<void> init() async {
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'onLink') {
        _handle('${call.arguments}');
      }
      return null;
    });
    try {
      final initial = await _channel.invokeMethod<String>('getInitial');
      if (initial != null && initial.isNotEmpty) {
        _handle(initial);
      }
    } on MissingPluginException {
      // Web/tests: sin canal nativo.
    } on PlatformException {
      // Igual: la app no depende del deep link.
    }
  }

  /// Parsea y enruta un enlace de sala.
  static void _handle(String raw) {
    final invite = SalaInvite.tryParse(raw);
    if (invite == null) return;
    salaInviteRequest.value = invite;
    // Lleva al lobby de la Sala: la pantalla consume la invitación y
    // abre la hoja de unirse. Si el router aún no existe (arranque
    // temprano), la invitación queda pendiente para cuando el lobby se
    // abra manualmente.
    final router = _router;
    if (router != null) {
      router.go('/sala');
    }
  }
}
