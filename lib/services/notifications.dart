/// ─── Notificaciones locales (sin FCM — decisión cerrada §4.7) ───────────────
/// flutter_local_notifications con 5 canales: rate_alerts · price_targets ·
/// reminders · room_activity · default. POST_NOTIFICATIONS se pide en
/// Ajustes → Alertas (nunca en el arranque).
library;

import 'package:flutter_local_notifications/flutter_local_notifications.dart';

const _kChannels = <AndroidNotificationChannel>[
  AndroidNotificationChannel(
    'rate_alerts',
    'Alertas de tasa',
    description: 'Picos y metas de tasa BCV/paralelo',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'price_targets',
    'Metas de precio',
    description: 'Productos que cruzan su meta',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'reminders',
    'Recordatorios',
    description: 'Registro diario de gastos',
    importance: Importance.defaultImportance,
  ),
  AndroidNotificationChannel(
    'room_activity',
    'Sala en vivo',
    description: 'Actividad de la lista compartida',
    importance: Importance.high,
  ),
  AndroidNotificationChannel(
    'default',
    'General',
    description: 'Avisos varios',
    importance: Importance.defaultImportance,
  ),
];

class NotificationsService {
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _inited = false;

  Future<void> init() async {
    if (_inited) return;
    const settings = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _plugin.initialize(const InitializationSettings(android: settings));
    final impl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    for (final c in _kChannels) {
      await impl?.createNotificationChannel(c);
    }
    _inited = true;
  }

  /// ¿Permiso concedido? (API 33+ POST_NOTIFICATIONS).
  Future<bool> areEnabled() async {
    final impl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    return await impl?.areNotificationsEnabled() ?? true;
  }

  Future<bool> requestPermission() async {
    final impl = _plugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();
    final granted = await impl?.requestNotificationsPermission();
    return granted ?? true;
  }

  /// Muestra una notificación local (tag:valorave-*, url interna de destino).
  Future<void> show({
    required String channelId,
    required String title,
    required String body,
    String? tag,
  }) async {
    try {
      if (!_inited) await init();
      final details = NotificationDetails(
        android: AndroidNotificationDetails(
          channelId,
          _kChannels
              .firstWhere(
                (c) => c.id == channelId,
                orElse: () => _kChannels.last,
              )
              .name,
          channelDescription: 'ValoraVE',
          importance: Importance.high,
          priority: Priority.high,
          styleInformation: BigTextStyleInformation(body),
        ),
      );
      await _plugin.show(
        tag?.hashCode ?? title.hashCode,
        title,
        body,
        details,
        payload: tag,
      );
    } catch (_) {
      // Sin canal de notificaciones (host de pruebas, OEM capado, motor en
      // 2º plano sin plugins): el aviso del sistema se salta — el centro
      // interno (persist) sigue funcionando. Nunca rompe el flujo.
    }
  }
}
