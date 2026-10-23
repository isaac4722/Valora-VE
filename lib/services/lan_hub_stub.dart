/// ─── Hub de sala por WiFi local · stub de WEB ───────────────────────────────
/// No hay ServerSocket/RawDatagramSocket en el navegador: el stub expone la
/// MISMA API que lan_hub_vm.dart pero honesta — conectar/escanear devuelve
/// false/vacío y la UI muestra el vacío en vez de colgarse. La sala en web
/// viaja por el servidor socket.io (room_transport la elige por defecto).
library;

import 'dart:async';

import '../room/room_transport.dart';

/// Gemelo del [LanHubImpl] real (lan_hub_vm.dart): mismas firmas públicas,
/// sin ningún efecto de red. Nadie descubre salas por broadcast en un
/// navegador — el transporte del servidor es el camino de la web.
class LanHubImpl {
  LanHubImpl();

  static const int kTcpPort = 48130;
  static const int kUdpPort = 48131;
  static const String kAdPrefix = 'VALORAVE2|';
  static const String kWho = 'VALORAVE2|WHO';
  static const String kLegacyAdPrefix = 'VALORAVE|';

  final StreamController<RoomEvent> _events =
      StreamController<RoomEvent>.broadcast();
  final StreamController<RoomStatus> _statuses =
      StreamController<RoomStatus>.broadcast();

  RoomStatus get status => RoomStatus.disconnected;
  Stream<RoomEvent> get events => _events.stream;
  Stream<RoomStatus> get statusStream => _statuses.stream;
  Stream<Map<String, dynamic>> get roomAds => const Stream.empty();
  bool get isHost => false;
  String? get hostIp => null;

  /// IP local: el navegador no la expone (privacidad) — null honesto.
  static Future<String?> localIPv4() async => null;

  Future<void> startHost({
    required String roomCode,
    required String myName,
    String roomName = '',
    bool isPublic = true,
  }) async {
    _statuses.add(RoomStatus.error);
  }

  Future<void> dial({required String roomCode, required String myName}) async {
    _statuses.add(RoomStatus.error);
  }

  Future<bool> connectToHost({
    required String host,
    required int port,
    required String roomCode,
    required String myName,
  }) async => false;

  Future<bool> startScan() async => false;

  Future<void> stopScan() async {}

  /// Un anuncio WiFi-local no llega al navegador: nada que parsear.
  static Map<String, dynamic>? parseAd(String raw) => null;

  Future<Map<String, dynamic>?> emit(
    String type,
    Map<String, dynamic> payload,
  ) async => null;

  Future<Map<String, dynamic>?> emitTo(
    String targetId,
    String type,
    Map<String, dynamic> payload,
  ) async => null;

  Future<void> disconnect() async {}

  /// Códigos vistos recientemente (contrato discover()): vacío en web.
  Future<List<String>> discover() async => const [];
}
