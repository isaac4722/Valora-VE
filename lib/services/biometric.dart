/// ─── Bloqueo biométrico opcional (mejora 1 dp6 · toggle en 17.7) ────────────
/// local_auth: huella/rostro/PIN del dispositivo. Se activa en Ajustes →
/// Apariencia si el dispositivo lo soporta; se pregunta al abrir la app.
/// Sin soporte (host de pruebas, OEM capado) NUNCA bloquea: authenticate
/// devuelve true y la app entra normal — degradación honesta.
library;

import 'package:local_auth/local_auth.dart';

class BiometricService {
  final LocalAuthentication _auth = LocalAuthentication();

  /// ¿Hay biometría o PIN de dispositivo disponible? Tolerante: entornos sin
  /// canal de plataforma (tests, previews) → false sin lanzar.
  Future<bool> get canCheck async {
    try {
      final bio = await _auth.canCheckBiometrics;
      final supported = await _auth.isDeviceSupported();
      return bio || supported;
    } catch (_) {
      return false;
    }
  }

  /// Pide huella/rostro. Sin soporte → true (no bloquea). Con soporte y
  /// fallo/cancelación → false (la puerta queda cerrada con reintentos).
  Future<bool> authenticate({required String reason}) async {
    if (!await canCheck) return true; // sin soporte: no bloquea
    try {
      return await _auth.authenticate(localizedReason: reason);
    } catch (_) {
      return false;
    }
  }
}
