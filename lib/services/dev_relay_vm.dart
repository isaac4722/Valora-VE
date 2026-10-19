/// ─── Puente sin PC · implementación VM (v21.7) ──────────────────────────────
/// WebSocket saliente (dart:io) del teléfono hacia el relay del preview con
/// rol `bridge` + token de sesión: el dueño no corre helper ni abre NADA en
/// su PC — la app misma es el puente (pedido: «todo dentro de la preview»).
///
/// Qué atiende (protocolo server.js, idéntico al cliente USB del navegador):
///   · `appcmd`  → HTTP real a `127.0.0.1:<puerto>` del servidor de pruebas
///                 local (DevBridge v21.6): /health /test /nav /erase.
///   · `shot`    → captura de la UI viva (DevCapture: RepaintBoundary →
///                 PNG → JPEG si la plataforma puede) y frame binario.
///   · `stream`  → enciende/apaga el flujo periódico (≈1 fps) del mismo
///                 camino que `shot`, con meta {type:'stream'} cada 8 frames.
///   · `tap|swipe|text|key|shell` → error honesto: inyectar entrada exige
///                 ADB (USB o helper); este puente no es root ni shell.
///
/// Reconexión con backoff 2/5/10/15/30 s; 4001 (token) y 4003 (otro puente
/// tomó el control) NO reintentan solos — quedan con estado claro en Ajustes.
/// Nunca lanza hacia el arranque: es una herramienta, no un requisito.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' show ImageByteFormat, PlatformDispatcher;

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/version.dart';
import '../data/store.dart';
import 'dev_bridge_vm.dart';
import 'dev_relay_proto.dart';
import 'photo_compress.dart' show compressJpeg;

class DevRelay {
  /// Claves de preferencias (SharedPreferences ya vive a nivel de app).
  static const String kPrefUrl = 'valorave.relay-url';
  static const String kPrefToken = 'valorave.relay-token';
  static const String kPrefAuto = 'valorave.relay-auto';

  static WebSocket? _ws;
  static bool _manual = true; // true = el dueño cerró: sin reintentos
  static bool _streaming = false;
  static bool _streamBusy = false;
  static int _frameCount = 0;
  static int _attempt = 0;
  static Timer? _retry;
  static Timer? _streamTimer;
  static String _status = 'off';
  static String _url = '';
  static String _token = '';

  static bool get supported => true;
  static bool get connected => _ws != null && _ws!.readyState == WebSocket.open;
  static String get status => _status;
  static bool get configured => _url.isNotEmpty && _token.isNotEmpty;
  static String get url => _url;

  /// Lee URL/token persistidos (Ajustes los guarda; init los carga).
  static void loadConfig(SharedPreferences prefs) {
    _url = prefs.getString(kPrefUrl)?.trim() ?? '';
    _token = prefs.getString(kPrefToken)?.trim() ?? '';
  }

  /// main.dart: auto-conecta SOLO si el dueño dejó el interruptor encendido
  /// con URL y token guardados. Tolerante: cualquier fallo queda en status.
  static Future<void> init({
    required AppStore store,
    required SharedPreferences prefs,
  }) async {
    loadConfig(prefs);
    if (configured && prefs.getBool(kPrefAuto) == true) {
      await connect(store: store);
    }
  }

  static Future<void> saveConfig(
    SharedPreferences prefs, {
    required String url,
    required String token,
  }) async {
    _url = url.trim();
    _token = token.trim();
    await prefs.setString(kPrefUrl, _url);
    await prefs.setString(kPrefToken, _token);
  }

  static Future<void> setAuto(SharedPreferences prefs, {required bool on}) {
    return prefs.setBool(kPrefAuto, on);
  }

  // ── Ciclo de conexión ─────────────────────────────────────────────────────
  static Future<bool> connect({required AppStore store}) async {
    await disconnect();
    if (!configured) {
      _status = 'sin configurar (URL y token del preview)';
      return false;
    }
    _manual = false;
    _attempt = 0;
    _status = 'conectando…';
    return _open();
  }

  static Future<void> disconnect() async {
    _manual = true;
    _retry?.cancel();
    _retry = null;
    _stopStream();
    final ws = _ws;
    _ws = null;
    try {
      await ws?.close();
    } catch (_) {
      // ya cerrado: desconectar es idempotente
    }
    _status = 'off';
  }

  static Future<bool> _open() async {
    try {
      final uri = Uri.parse(relayWsUrl(_url, _token));
      final ws = await WebSocket.connect(uri.toString())
          .timeout(const Duration(seconds: 12));
      _ws = ws;
      _attempt = 0;
      _status = 'conectado';
      ws.listen(
        _onData,
        onDone: () => _closed(ws),
        onError: (Object _) => _closed(ws),
      );
      unawaited(_hello());
      return true;
    } catch (e) {
      _status = 'no conectó: ${_short(e)}';
      if (!_manual) _scheduleRetry();
      return false;
    }
  }

  static void _closed(WebSocket ws) {
    if (_ws != ws) return; // ya fue reemplazada por otra conexión
    _ws = null;
    _stopStream();
    if (_manual) {
      _status = 'off';
      return;
    }
    switch (ws.closeCode ?? 0) {
      case 4001:
        _status = 'token inválido — revísalo en Ajustes → Diagnóstico';
        return; // sin reintento: la basura no se arregla sola
      case 4003:
        _status = 'otro puente tomó el control (¿USB en el preview?)';
        return; // sin peleas: el dueño decide cuál volver a encender
      default:
        _scheduleRetry();
    }
  }

  static void _scheduleRetry() {
    _retry?.cancel();
    const delays = [2, 5, 10, 15, 30];
    final d = delays[_attempt.clamp(0, delays.length - 1)];
    _attempt++;
    _status = 'reintentando en ${d}s';
    _retry = Timer(Duration(seconds: d), () {
      if (!_manual) _open();
    });
  }

  // ── Protocolo del relay ───────────────────────────────────────────────────
  static Future<void> _onData(dynamic data) async {
    if (data is! String) return; // el puente-app solo RECIBE texto
    Map<String, dynamic> msg;
    try {
      final decoded = jsonDecode(data);
      if (decoded is! Map<String, dynamic>) return;
      msg = decoded;
    } catch (_) {
      return;
    }
    if (msg['type'] != 'cmd') return;
    final (result, binary) = await handleCmd(msg);
    _sendJson(result);
    if (binary != null && connected) _ws!.add(binary);
  }

  static Future<void> _hello() async {
    final (w, h) = _screen();
    _sendJson(relayHello(model: await _deviceModel(), w: w, h: h));
  }

  /// Núcleo de comandos — SIN WebSocket para poder probarlo directo
  /// (test/dev_relay_test.dart): devuelve el {type:'result'} a enviar y los
  /// bytes binarios (frame) si el comando produce imagen.
  static Future<(Map<String, dynamic>, List<int>?)> handleCmd(
    Map<String, dynamic> msg,
  ) async {
    final id = (msg['id'] as String?) ?? '';
    final action = (msg['action'] as String?) ?? '';
    final args = (msg['args'] as Map?)?.cast<String, dynamic>() ?? const {};
    switch (action) {
      case 'appcmd':
        return _appcmd(id, args);
      case 'shot':
        return _shot(id);
      case 'stream':
        _setStreaming(args['on'] == true);
        return (_ok(id, {'streaming': _streaming}), null);
      case 'tap':
      case 'swipe':
      case 'text':
      case 'key':
      case 'shell':
        return (
          _err(
            id,
            '«$action» necesita ADB (USB o helper en la PC) — este puente '
            'vive DENTRO de la app y no inyecta toques. Sí funcionan: '
            'pantalla, /health, /test, /nav y /erase.',
          ),
          null,
        );
      default:
        return (_err(id, 'acción desconocida: $action'), null);
    }
  }

  static Future<(Map<String, dynamic>, List<int>?)> _appcmd(
    String id,
    Map<String, dynamic> args,
  ) async {
    if (!DevBridge.running) {
      return (
        _err(
          id,
          'Servidor de pruebas apagado — enciéndelo en Ajustes → Diagnóstico.',
        ),
        null,
      );
    }
    final path = (args['path'] as String?) ?? '/health';
    final token = args['token'] as String?;
    final client = HttpClient();
    client.connectionTimeout = const Duration(seconds: 8);
    try {
      final req = await client
          .getUrl(Uri.parse('http://127.0.0.1:${DevBridge.port}$path'));
      if (token != null && token.isNotEmpty) {
        req.headers.add('x-valora-token', token);
      }
      final res = await req.close().timeout(const Duration(seconds: 12));
      final body = await res.transform(utf8.decoder).join();
      Map<String, dynamic>? json;
      try {
        json = jsonDecode(body) as Map<String, dynamic>;
      } catch (_) {
        // respuesta no-JSON: viaja como null (igual que el cliente USB)
      }
      return (_ok(id, {'status': res.statusCode, 'json': json}), null);
    } catch (e) {
      return (_err(id, 'app $path: ${_short(e)}'), null);
    } finally {
      client.close();
    }
  }

  static Future<(Map<String, dynamic>, List<int>?)> _shot(String id) async {
    final bytes = await DevCapture.capture(targetWidth: 720);
    if (bytes == null) {
      return (
        _err(id, 'Captura no disponible (¿UI sin renderizar todavía?)'),
        null,
      );
    }
    return (_ok(id, {'bytes': bytes.length, 'source': 'app'}), bytes);
  }

  static void _setStreaming(bool on) {
    _streaming = on;
    _streamTimer?.cancel();
    if (!on) return;
    _frameCount = 0;
    _streamTimer = Timer.periodic(
      const Duration(milliseconds: 900),
      (_) => unawaited(_streamTick()),
    );
  }

  static void _stopStream() {
    _streaming = false;
    _streamTimer?.cancel();
    _streamTimer = null;
  }

  static Future<void> _streamTick() async {
    if (!connected || !_streaming || _streamBusy) return;
    _streamBusy = true;
    try {
      final bytes = await DevCapture.capture(targetWidth: 720);
      if (bytes != null && connected) _ws!.add(bytes);
      _frameCount++;
      if (connected && _frameCount % 8 == 1) {
        final (w, h) = _screen();
        _sendJson(<String, dynamic>{
          'type': 'stream',
          'w': w,
          'h': h,
          'device': <String, int>{'w': w, 'h': h},
        });
      }
    } catch (_) {
      // captura fallida: el próximo tick reintenta solo
    } finally {
      _streamBusy = false;
    }
  }

  // ── Utilidades ────────────────────────────────────────────────────────────
  static void _sendJson(Map<String, dynamic> msg) {
    if (connected) _ws!.add(jsonEncode(msg));
  }

  static (int, int) _screen() {
    try {
      final v = PlatformDispatcher.instance.views.first;
      return (v.physicalSize.width.round(), v.physicalSize.height.round());
    } catch (_) {
      return (0, 0);
    }
  }

  static Future<String> _deviceModel() async {
    try {
      final info = await DeviceInfoPlugin().androidInfo;
      final m = '${info.manufacturer} ${info.model}'.trim();
      return m.isEmpty ? 'Android' : m;
    } catch (_) {
      return 'Android (app v$kAppVersionVisible)';
    }
  }

  static String _short(Object e) {
    final s = '$e';
    return s.length <= 120 ? s : '${s.substring(0, 117)}…';
  }

  static Map<String, dynamic> _ok(String id, Map<String, dynamic> data) =>
      {'type': 'result', 'id': id, 'ok': true, 'data': data};

  static Map<String, dynamic> _err(String id, String error) =>
      {'type': 'result', 'id': id, 'ok': false, 'error': error};
}

/// Captura de la UI viva: RepaintBoundary GLOBAL instalado por main.dart en
/// el `builder` de MaterialApp.router (rodea el Navigator completo). La
/// captura sale del MISMO árbol que ve el usuario — sin screencap nativo,
/// sin permisos: es la app fotografiándose a sí misma.
class DevCapture {
  static final GlobalKey key = GlobalKey();

  /// Envoltura para el builder de MaterialApp (identidad si no hay hijo).
  static Widget wrap(BuildContext context, Widget? child) =>
      RepaintBoundary(key: key, child: child ?? const SizedBox.shrink());

  /// Relación de píxeles para lograr [targetWidth] px de ancho desde un
  /// boundary de [logicalWidth] px lógicos (pura — probada sin UI).
  static double pixelRatioFor(double logicalWidth, double targetWidth) {
    if (logicalWidth <= 0) return 1.0;
    return (targetWidth / logicalWidth).clamp(0.1, 3.0);
  }

  /// Captura → PNG; si la plataforma puede re-encodear, JPEG (4-6× más
  /// liviano — compressJpeg es la MISMA función de los tickets). Devuelve
  /// null honesto si no hay UI renderizada aún o la captura falló.
  static Future<List<int>?> capture({double targetWidth = 720}) async {
    try {
      final ctx = key.currentContext;
      final ro = ctx?.findRenderObject();
      if (ro is! RenderRepaintBoundary) return null;
      if (!ro.attached || !ro.hasSize || ro.size.isEmpty) return null;
      final logicalW = ro.size.width;
      if (logicalW <= 0) return null;
      final pixelRatio = pixelRatioFor(logicalW, targetWidth);
      final image = await ro.toImage(pixelRatio: pixelRatio);
      final sideW = image.width;
      final sideH = image.height;
      final data = await image.toByteData(format: ImageByteFormat.png);
      image.dispose();
      if (data == null) return null;
      final png =
          data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes);
      final maxSide = sideW > sideH ? sideW : sideH;
      final jpeg = await compressJpeg(png, quality: 55, maxDim: maxSide);
      return jpeg ?? png;
    } catch (_) {
      return null;
    }
  }
}
