/// ─── Trabajo en 2º plano (facade condicional) ───────────────────────────────
/// Misma API en cada plataforma: implementación VM (dart:io para el fetch
/// mínimo y el respaldo semanal en disco) o stub no-op de web — el
/// workmanager nativo no existe en el navegador y el tablero de la web se
/// refresca en primer plano (SSE del propio navegador).
library;

export 'workmanager_service_stub.dart'
    if (dart.library.io) 'workmanager_service_vm.dart';
