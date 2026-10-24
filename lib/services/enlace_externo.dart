/// ─── Enlaces fuera de la app (v22.3) ────────────────────────────────────────
/// Abre una URL en el navegador del sistema (pestaña nueva en web). Fue el
/// transporte de descarga del canal dev en v22.3; desde v22.4 es el
/// RESPALDO (web y escritorio de desarrollo): en Android el APK baja
/// dentro de la app y la instalación la lanza el canal
/// `valorave/instalador` — el navegador queda para las Releases viejas y
/// para ver la página del repo.
///
/// `url_launcher` es first-party (flutter.dev) y su familia linux/web/windows
/// ya viajaba en el lock como transitiva; aquí pasa a dependencia directa
/// y explícita (AGENT.md pide consultarlo antes — orden del dueño v22.3).
library;

import 'package:url_launcher/url_launcher.dart';

/// Abre [url] fuera de la app. Devuelve false si el sistema no encuentra
/// con qué abrirla (la pantalla que llama decide el aviso).
Future<bool> abrirEnlaceExterno(Uri url) async {
  try {
    return await launchUrl(url, mode: LaunchMode.externalApplication);
  } catch (_) {
    // PlatformException cuando ninguna app sabe abrir la URL (pasa en
    // emuladores sin navegador). El usuario ya tiene el mensaje de la
    // pantalla; aquí el detalle técnico no aporta.
    return false;
  }
}
