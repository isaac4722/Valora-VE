/// ─── Bloqueo biométrico opcional (mejora 1 dp6) ─────────────────────────────
/// local_auth: huella/rostro/PIN del dispositivo. Se activa en Ajustes →
/// Apariencia si el dispositivo lo soporta; se pregunta al abrir la app.
library;

import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  Future<bool> get canCheck async {
    final bio = await _auth.canCheckBiometrics;
    final supported = await _auth.isDeviceSupported();
    return bio || supported;
  }

  Future<bool> authenticate({required String reason}) async {
    if (!await canCheck) return true; // sin soporte: no bloquea
    try {
      return await _auth.authenticate(localizedReason: reason);
    } catch (_) {
      return false;
    }
  }
}
