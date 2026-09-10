/// ─── Shortcuts nativos (quick_actions) §12.2/§14 ────────────────────────────
/// Los 4 shortcuts del manifest de la PWA, ahora en el launcher Android:
/// Lista · Conversor · Escanear (abre la Lista y lanza el escáner) ·
/// Tasa BCV (abre Inicio con el tablero fresco).
///
/// El transporte es el plugin oficial quick_actions; en hosts sin canal
/// (tests) falla silencioso: ningún shortcut es crítico para arrancar.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:quick_actions/quick_actions.dart';

/// Petición de escaneo pendiente: la Lista la observa y abre el escáner
/// (señal ligera sin acoplar el service a las pantallas).
final ValueNotifier<bool> scanRequest = ValueNotifier<bool>(false);

class QuickActionsService {
  QuickActionsService._();

  static final QuickActions _plugin = const QuickActions();
  static GoRouter? _router;

  /// Se llama desde ValoraApp (initState) con el router ÚNICO de la sesión.
  static void bind(GoRouter router) => _router = router;

  /// Registra los 4 shortcuts del manifest y conecta el handler de arranque.
  static Future<void> init() async {
    try {
      _plugin.initialize(_handle);
      // Sin iconos custom: Android usa el ícono de la app (evita depender
      // de drawables que no existen en este árbol).
      await _plugin.setShortcutItems(<ShortcutItem>[
        const ShortcutItem(type: 'action_lista', localizedTitle: 'Lista'),
        const ShortcutItem(type: 'action_conversor', localizedTitle: 'Conversor'),
        const ShortcutItem(type: 'action_escanear', localizedTitle: 'Escanear'),
        const ShortcutItem(type: 'action_bcv', localizedTitle: 'Tasa BCV'),
      ]);
    } catch (e) {
      // Degradación honesta: sin shortcuts el resto de la app vive igual.
      debugPrint('[quick_actions] no disponible: $e');
    }
  }

  static void _handle(String type) {
    final GoRouter? router = _router;
    if (router == null) return;
    switch (type) {
      case 'action_lista':
        router.go('/lista');
      case 'action_conversor':
        router.go('/conversor');
      case 'action_escanear':
        // Entra a la Lista y pide el escáner (el screen observa scanRequest).
        router.go('/lista');
        scanRequest.value = true;
      case 'action_bcv':
        // Inicio con tablero fresco: el héroe de la tasa es la primera carta.
        router.go('/');
      default:
        router.go('/');
    }
  }
}
