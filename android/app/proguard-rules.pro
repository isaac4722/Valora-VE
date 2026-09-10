# Reglas ProGuard para ValoraVE (ofuscación --obfuscate en Dart + R8 aquí).

# socket.io / engine.io usan Gson internamente vía reflection en algunos modelos.
-keep class io.socket.** { *; }
-dontwarn io.socket.**

# Hive funciona por binario propio (sin reflection); nothing to keep.
# flutter_local_notifications: mantener iconos de notificación.
-keep class com.dexterous.** { *; }

# google Nearby (librería nativa del sistema, sin keep necesario).
