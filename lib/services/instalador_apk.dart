/// ─── Instalación in-app del APK del canal dev (v22.4 · facade condicional) ──
/// El canal dev ya publica cada ronda como Release del repo con 4 APK. En
/// v22.3 la app AVISABA y mandaba al navegador (descarga manual + instalar
/// a mano). Orden del dueño para v22.4: la app descarga el APK DENTRO de
/// sí misma a una carpeta temporal y lanza el instalador de Android — sin
/// atajos ni gestos manuales de por medio.
///
/// Nativo (Android): descarga con dio a `<cache>/valora_update/` y el canal
/// `valorave/instalador` (MainActivity) abre el instalador del sistema vía
/// FileProvider. Web: no hay filesystem ni instalador — el stub responde
/// «no disponible» y la pantalla conserva la vía navegador de v22.3.
library;

export 'instalador_apk_stub.dart' if (dart.library.io) 'instalador_apk_vm.dart';
