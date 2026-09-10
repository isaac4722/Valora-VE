# Reglas ProGuard para ValoraVE (ofuscación --obfuscate en Dart + R8 aquí).

# socket.io / engine.io usan Gson internamente vía reflection en algunos modelos.
-keep class io.socket.** { *; }
-dontwarn io.socket.**

# Hive funciona por binario propio (sin reflection); nothing to keep.
# flutter_local_notifications: mantener iconos de notificación.
-keep class com.dexterous.** { *; }

# google Nearby (librería nativa del sistema, sin keep necesario).

# home_widget actualiza el widget vía Class.forName("ve.valorave.app.
# BcvWidgetProvider") (reflexión por nombre); el manifest ya lo conserva,
# pero el keep explícito garantiza que R8 no lo renombre jamás.
-keep class ve.valorave.app.BcvWidgetProvider { *; }

# workmanager resuelve nuestros workers y callback por reflexión.
-keep class ve.valorave.app.** { *; }
