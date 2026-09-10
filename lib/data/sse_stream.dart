/// ─── SSE propio sobre dio (§trap 1) ─────────────────────────────────────────
/// El paquete `eventsource` 0.4.0 ancla `http ^0.13` y rompe la resolución
/// con el resto del árbol (sessiones previas): cliente SSE mínimo propio que
/// consume `/api/rates/stream` de un despliegue web ValoraVE (snapshot
/// inicial `event:rates` + deltas + `:ping` 25 s). Si el servidor no
/// responde, la app sigue con su ciclo propio de polling — el SSE es una
/// mejora, nunca un bloqueo.
library;

import 'dart:async';
import 'dart:convert';

import 'package:dio/dio.dart';

/// Evento SSE crudo (data ya decodificada cuando es JSON válido).
class SseEvent {
  final String event;
  final String data;
  const SseEvent(this.event, this.data);

  dynamic get json {
    try {
      return jsonDecode(data);
    } catch (_) {
      return null;
    }
  }
}

/// Cliente SSE sobre dio: escucha un stream de texto por chunks y emite
/// eventos parseados (event:, data:, líneas «:ping» ignoradas).
class SseClient {
  final Dio dio;
  final CancelToken _cancel = CancelToken();

  SseClient(this.dio);

  /// Conecta y devuelve un stream de eventos. Reconexión es cosa del caller.
  Stream<SseEvent> connect(String url, {Map<String, String>? headers}) {
    final controller = StreamController<SseEvent>.broadcast();
    var buffer = '';
    String eventName = 'message';
    final dataLines = <String>[];

    dio
        .get<ResponseBody>(
      url,
      options: Options(
        responseType: ResponseType.stream,
        headers: {
          'Accept': 'text/event-stream',
          'Cache-Control': 'no-cache',
          ...?headers,
        },
        // Sin timeout de receive: el stream vive hasta que muere.
        receiveTimeout: null,
        validateStatus: (s) => s != null && s < 500,
      ),
      cancelToken: _cancel,
    )
        .then((res) {
      // (sin campo: la respuesta se consume por su stream)
      final body = res.data!;
      body.stream.listen(
        (bytes) {
          buffer += utf8.decode(bytes, allowMalformed: true);
          // SSE: eventos separados por \n\n.
          while (true) {
            final sep = buffer.indexOf('\n\n');
            if (sep < 0) break;
            final chunk = buffer.substring(0, sep);
            buffer = buffer.substring(sep + 2);
            for (final line in chunk.split('\n')) {
              if (line.startsWith(':')) continue; // comentario/ping
              if (line.startsWith('event:')) {
                eventName = line.substring(6).trim();
              } else if (line.startsWith('data:')) {
                dataLines.add(line.substring(5).trimLeft());
              }
            }
            if (dataLines.isNotEmpty) {
              controller.add(SseEvent(eventName, dataLines.join('\n')));
              eventName = 'message';
              dataLines.clear();
            }
          }
        },
        onDone: controller.close,
        onError: controller.addError,
        cancelOnError: true,
      );
    }).catchError(controller.addError);

    controller.onCancel = () {
      _cancel.cancel();
    };
    return controller.stream;
  }

  void close() {
    if (!_cancel.isCancelled) _cancel.cancel();
  }
}

/// ─── RatesStream · adaptador del tablero en vivo ────────────────────────────
/// Mapea los payloads `{sources, providers, degraded, lastUpdate}` del
/// servidor a un flujo de mapas que el store normaliza (setRateBoard).
class RatesStream {
  final Dio dio;
  final String url;
  final _controller = StreamController<Map<String, dynamic>>.broadcast();
  SseClient? _client;
  StreamSubscription<SseEvent>? _sub;
  bool _connected = false;

  RatesStream({required this.dio, required this.url});

  bool get connected => _connected;
  Stream<Map<String, dynamic>> get boards => _controller.stream;

  void start() {
    stop();
    _client = SseClient(dio);
    _sub = _client!.connect(url).listen((ev) {
      if (ev.event == 'rates' || ev.event == 'message') {
        final j = ev.json;
        if (j is Map) {
          _connected = true;
          _controller.add(Map<String, dynamic>.from(j));
        }
      }
    }, onDone: () => _connected = false, onError: (_) => _connected = false);
  }

  void stop() {
    _sub?.cancel();
    _client?.close();
    _connected = false;
  }

  void dispose() {
    stop();
    _controller.close();
  }
}
