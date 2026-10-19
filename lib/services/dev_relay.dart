/// ─── Puente sin PC · la app conecta al relay del preview (v21.7) ────────────
/// El TELÉFONO es quien abre la conexión: WebSocket saliente (dart:io) hacia
/// el relay del preview con rol `bridge` — el dueño no corre NADA en su PC
/// (pedido literal: «que todo sea dentro de la preview»). Habla el mismo
/// protocolo de tools/remote-bridge/server.js: hello → {type:'cmd'} →
/// {type:'result'} + frames binarios (JPEG/PNG) que el piloto ya sabe
/// dibujar. Condicional como dev_bridge e ins_server: implementación VM en
/// móvil/escritorio, stub no-op en web con la MISMA API.
///
/// Límite honesto: este puente vive DENTRO de la app, así que puede servir
/// /health /test /nav /erase (es su propio servidor de pruebas) y capturar
/// su propia pantalla (RepaintBoundary), pero NO puede inyectar toques ni
/// teclas (eso exige ADB: USB o helper) — las respuestas lo dicen.
library;

export 'dev_relay_stub.dart' if (dart.library.io) 'dev_relay_vm.dart';
export 'dev_relay_proto.dart' show relayHello, relayWsUrl;
