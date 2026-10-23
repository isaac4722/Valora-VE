/// ─── Fotos de ticket en ARCHIVO (v20.4 · facade condicional) ────────────────
/// La implementación VM escribe JPEG en `<docs>/tickets/` (path_provider);
/// en web no hay filesystem y el stub responde honesto (null/false/0) para
/// que el caller conserve la foto como data URL — contrato original.
library;

export 'ticket_files_stub.dart' if (dart.library.io) 'ticket_files_vm.dart';
