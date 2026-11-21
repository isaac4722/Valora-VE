/// Servicios de plataforma como proveedores.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/connectivity.dart';
import '../services/notifications.dart';

/// Canal de notificaciones locales — se crea e init() en main(); el default
/// sin init() es la degradación honesta (host de pruebas).
final notificationsProvider = Provider<NotificationsService>((ref) {
  return NotificationsService();
});

/// Señal de red (v17.8): null cuando el host no tiene canal (tests/web).
final connectivityProvider = Provider<ConnectivityService?>((ref) => null);
