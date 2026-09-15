/// ─── Conectividad (v17.8 · offline REAL) ───────────────────────────────────
/// La app declara ser client-side + offline y constantemente no lo lograba
/// (señal del dueño): sin saber SI HAY red, cada arranque/reanudo/intento
/// quemaba 7 s de timeouts fingiendo «Buscando tasas…» y reintentaba cada
/// 60 s martillando la batería.
///
/// Este servicio da la señal que faltaba:
/// · Estado vivo online/offline (connectivity_plus, plugin oficial).
/// · Al quedarse SIN red: el poller NO consulta (cero timeouts muertos),
///   NO reintenta en bucle, y la UI muestra el estado offline honesto.
/// · Al VOLVER la red: refresco inmediato (si el usuario lo permite).
/// · Degradación honesta: sin canal de plataforma (tests/previews) se
///   asume ONLINE y nada se bloquea — la app jamás depende de un plugin.
library;

import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService({Connectivity? plugin})
    : _plugin = plugin ?? Connectivity();

  final Connectivity _plugin;
  StreamSubscription<List<ConnectivityResult>>? _sub;
  final StreamController<bool> _changes = StreamController<bool>.broadcast();

  /// Optimista hasta la primera señal real: sin red conocida, la app NO se
  /// declara offline por capricho (los datos locales funcionan igual).
  bool _online = true;

  bool get isOnline => _online;

  /// Cambios de estado (solo cuando DE VERDAD cambia — sin ruido).
  Stream<bool> get onLineChanged => _changes.stream;

  /// Primer sondeo + suscripción a cambios. Tolerante: cualquier fallo del
  /// canal (host de pruebas, OEM raro) deja el estado en «online» y el
  /// stream vivo pero en silencio.
  Future<void> init() async {
    try {
      final results = await _plugin.checkConnectivity();
      _online = !results.contains(ConnectivityResult.none);
    } catch (_) {
      _online = true; // sin canal: se asume con red (degradación honesta)
    }
    try {
      _sub = _plugin.onConnectivityChanged.listen(
        (results) {
          final now = !results.contains(ConnectivityResult.none);
          if (now != _online) {
            _online = now;
            if (!_changes.isClosed) _changes.add(now);
          }
        },
        onError: (_) {
          /* canal muerto: el último estado queda vigente */
        },
      );
    } catch (_) {
      // Sin EventChannel disponible: el servicio queda en sondeo estático.
    }
  }

  /// Útil para «Reintentar» manual: re-consulta AHORA y devuelve el estado.
  Future<bool> recheck() async {
    try {
      final results = await _plugin.checkConnectivity();
      final now = !results.contains(ConnectivityResult.none);
      if (now != _online) {
        _online = now;
        if (!_changes.isClosed) _changes.add(now);
      }
    } catch (_) {
      // Sin canal: conserva el estado vigente.
    }
    return _online;
  }

  void dispose() {
    _sub?.cancel();
    _changes.close();
  }
}
