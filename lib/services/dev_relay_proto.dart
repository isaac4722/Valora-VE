/// ─── Protocolo del puente sin PC · lógica PURA (v21.7) ──────────────────────
/// Funciones sin I/O compartidas por la implementación VM, el stub web y los
/// tests. Vive aparte del condicional (dev_relay.dart) para que las pruebas
/// importen ambas piezas sin ambigüedad de símbolos.
library;

/// URL ws/wss del relay a partir de la base del preview.
///
/// Acepta `https://…`, `http://…`, `ws://…`, `wss://…` o dominio pelado
/// (asume https, que es lo que es un preview) con o sin `/` final; mapea el
/// esquema al transporte WebSocket y agrega rol `bridge` + token de sesión.
/// Lanza FormatException si la basura no tiene host o el esquema no es web.
String relayWsUrl(String base, String token) {
  final clean = base.trim();
  if (clean.isEmpty) {
    throw const FormatException('URL del preview vacía — pégala en el campo');
  }
  var s = clean.replaceAll(RegExp(r'/+$'), '');
  if (!RegExp(r'^[a-zA-Z][a-zA-Z0-9+.-]*://').hasMatch(s)) {
    s = 'https://$s'; // «preview-….space-z.ai» pelado → https → wss
  }
  final uri = Uri.tryParse(s);
  if (uri == null || uri.host.isEmpty) {
    throw FormatException('URL del preview inválida: $base');
  }
  final scheme = switch (uri.scheme) {
    'https' || 'wss' => 'wss',
    'http' || 'ws' => 'ws',
    final other => throw FormatException(
        'Esquema no soportado: $other — pega la URL del preview (https://…)',
      ),
  };
  return Uri(
    scheme: scheme,
    host: uri.host,
    port: uri.hasPort ? uri.port : null,
    path: '/api/ws',
    queryParameters: <String, String>{'role': 'bridge', 'token': token},
  ).toString();
}

/// Mensaje `hello` del puente-app. El piloto ya consume `device.model` y
/// `device.resolution.{w,h}` del cliente USB — misma forma, con
/// `source: 'app'` para que la UI distinga el origen.
Map<String, dynamic> relayHello({
  required String model,
  required int w,
  required int h,
}) =>
    <String, dynamic>{
      'type': 'hello',
      'device': <String, dynamic>{
        'model': model,
        'serial': 'puente-en-la-app',
        'resolution': <String, int>{'w': w, 'h': h},
        'source': 'app',
      },
    };
