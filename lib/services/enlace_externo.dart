/// ─── Enlaces fuera de la app (v22.3) ────────────────────────────────────────
/// Abre una URL en el navegador del sistema (pestaña nueva en web). Es el
/// transporte de descarga del canal dev: el APK de la Release baja por el
/// navegador y lo instala el instalador de Android — el mismo gesto manual
/// de siempre, sin permisos nuevos ni código nativo propio.
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
