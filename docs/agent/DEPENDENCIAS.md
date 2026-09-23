# Dependencias (todas oficiales de pub.dev, versiones compatibles entre sí)

Resueltas con Flutter 3.47.3 stable (canal stable sin pin en CI). El gate
`analyze`+`test` protege de roturas por actualizaciones.

| Paquete | Versión | Por qué |
|---|---|---|
| provider | ^6.1.5 | estado + DI (decisión cerrada del dueño §4) |
| go_router | ^16.3.0 | shell 8 rutas + ramas stateful (GUI dp4) |
| hive_ce + hive_ce_flutter | ^2.20.0 / ^2.3.4 | persistencia offline-first (JSON en cajas) — Community Edition (v19) |
| path_provider | ^2.1.5 | rutas de datos |
| **path_provider_android (override)** | **2.2.17** | §trap 3: 2.3.x arrastra jni/NDK C++ (2.4 GB); 2.2.17 es Kotlin puro |
| shared_preferences | ^2.3.2 | prefs UI (tema, tips, recientes) |
| dio | ^5.7.0 | tablero de tasas + **SSE propio** (§trap 1) |
| connectivity_plus | ^7.3.1 | offline real (v17.8): saber cuándo NO hay red |
| flutter_local_notifications | ^17.2.4 | 5 canales locales (SIN FCM, decisión §4.7) |
| file_picker | ^12.2.0 | §trap 2: 11.x rompe KGP en AGP≥9 sin builtInKotlin |
| home_widget | ^0.9.4 | widget 4×1 BCV |
| workmanager | ^0.10.10 | refresco horario + respaldo semanal |
| permission_handler | ^11.3.1 | permisos con justificación |
| local_auth | ^2.3.0 | bloqueo biométrico opcional |
| package_info_plus | ^10.x | APP_VERSION en Ajustes |
| share_plus | ^13.x | compartir PNG/PDF/CSV |
| image_picker | ^1.1.2 | foto de ticket (maxWidth 1024 + quality 72 = compresión nativa) |
| mobile_scanner | ^5.x | escáner continuo con zoom |
| nearby_connections | ^4.1.0 | sala P2P sin internet (WiFi-Direct/BT/BLE, P2P_STAR) |
| syncfusion_flutter_charts | ^34.2.8 | brecha, evolución, histórico, donut, barras (major 34: exige intl 0.20, alineada al Flutter 3.47 del CI; APIs usadas —SfCartesian/Series/Axes— estables) |
| dynamic_color | ^1.7.0 | Material You (opcional) |
| qr_flutter | ^4.1.0 | QR de sala |
| pdf + printing | ^3.11.1 / ^5.13.2 | constancias PDF |
| intl | ^0.20.3 | formato es-VE (0.20.3: lo exige flutter_localizations) |
| flutter_localizations | sdk | delegates es-VE — showDatePicker y componentes Material en español real (fix v19.3) |
| nested | ^1.0.0 | (tipado de listas de providers) |

## Trampas conocidas respetadas (§8 del prompt)
1. **`eventsource` PROHIBIDO** (ancla http ^0.13) → SSE propio sobre dio en
   `lib/data/sse_stream.dart`.
2. **`file_picker` NO 11.x** → 12.2 (su `android_file_picker` respeta el flag
   KGP). API nueva: `FilePicker.pickFiles()` estático + `readAsBytes()`.
3. **`path_provider_android` 2.2.17 override** — nunca 2.3.x (NDK).
4. **`win32 6.x` compartido** por package_info_plus 10 + share_plus 13 +
   file_picker 12 — NO bajar ninguno de los tres.
5. Heap de Gradle: CI 16 GB `-Xmx5g`; local 4 GB `-Xmx2g` temporal (no subir).
