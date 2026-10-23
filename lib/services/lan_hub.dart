/// ─── Hub de sala por WiFi local (facade condicional) ────────────────────────
/// El mismo `LanHubImpl` para cada plataforma: implementación VM (TCP +
/// broadcast UDP de dart:io) o stub no-op de web. La sala por WiFi local
/// es función nativa — en web la sala viaja por el servidor socket.io
/// (`server/lista-sync/`) y «Cerca» es plugin de Google.
library;

export 'lan_hub_stub.dart' if (dart.library.io) 'lan_hub_vm.dart';
