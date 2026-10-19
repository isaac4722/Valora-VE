/// ─── Servidor de pruebas local (v21.6 · puente de depuración remota) ────────
/// HTTP de loopback (127.0.0.1) para depuración asistida: el cliente del
/// puente (tools/remote-bridge) llega aquí vía el servicio `tcp:<puerto>`
/// de ADB (WebUSB en el navegador del dueño) — JAMÁS expuesto a la red:
/// solo ADB en el propio teléfono puede abrir un socket a su localhost,
/// igual que DevTools. Condicional como ins_server.dart: `dart:io` no
/// existe en web — el stub mantiene la misma API y no-op.
library;

export 'dev_bridge_stub.dart' if (dart.library.io) 'dev_bridge_vm.dart';
