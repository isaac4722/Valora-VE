/// ─── Instalador del canal dev · implementación nativa (v22.4) ───────────────
/// Dos mitades, ambas first-party:
/// 1. DESCARGA: dio (familia ya en el lock, misma del tablero de tasas)
///    escribe el APK en `<cache>/valora_update/<nombre>.apk` con progreso
///    por chunk. Carpeta del CACHE del sistema: Android puede reciclarla
///    sin pedirle nada al dueño y FileProvider la comparte con el
///    instalador sin permisos de almacenamiento.
/// 2. INSTALACIÓN: canal `valorave/instalador` (MainActivity.kt). El
///    intent ACTION_INSTALL_PACKAGE muestra la ventana de instalación de
///    Android sobre un archivo servido por FileProvider — sin plugins
///    terceros (el updater de pub.dev se descartó en v22.3 por sus
///    conflictos de manifest: aquí el manifest lo escribe el propio repo).
///
/// Permiso: REQUEST_INSTALL_PACKAGES está declarado en el manifest; en
/// Android 8+ el dueño concede «Instalar apps desconocidas» para ValoraVE
/// UNA sola vez — `puedeInstalar` lo consulta y la pantalla ofrece abrir
/// ese ajuste exacto (abrirAjustesOrigen) antes de gastar la descarga.
library;

import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// Carpeta bajo el cache donde viven los APK descargados. MISMO nombre que
/// `res/xml/file_paths.xml` declara al FileProvider (`cache-path`).
const String kCarpetaApk = 'valora_update';

/// El canal del lado Kotlin (MainActivity.configureFlutterEngine).
const MethodChannel _canal = MethodChannel('valorave/instalador');

class InstaladorApk {
  InstaladorApk({Dio? dio}) : _dioPropio = dio;

  /// Dio sin timeouts: el timeout de chunks no aplica a un APK de 25 MB en
  /// conexión lenta — la descarga larga es válida, solo importa que HAYA
  /// movimiento (dio corta por sí solo si la conexión muere).
  final Dio? _dioPropio;

  Dio get _dio => _dioPropio ?? Dio();

  /// La pieza solo tiene sentido en Android: en web ni hay filesystem, y
  /// en el Linux/macOS de desarrollo no existe el canal ni el instalador
  /// (la pantalla vuelve a la vía navegador de v22.3).
  bool get disponible => !kIsWeb && Platform.isAndroid;

  /// ¿Android ya concedió «Instalar apps desconocidas» a ValoraVE?
  /// Siempre true en API 24–25 (allí el ajuste es global del sistema y el
  /// instalador pide lo suyo); consulta real del paquete en API 26+.
  Future<bool> get puedeInstalar async {
    if (!disponible) return false;
    try {
      return await _canal.invokeMethod<bool>('puedeInstalar') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Descarga el APK de la Release a la carpeta temporal y devuelve la
  /// ruta absoluta. [progreso] llega por chunk (recibidos, total; total
  /// puede ser 0 si el servidor no manda content-length). [carpetaBase]
  /// es el seam de tests: la ruta PADRE de `valora_update/` (real: cache
  /// del SO; en tests, un directorio temporal). Va como String a propósito
  /// — ningún tipo de dart:io en firmas que comparten impl y stub.
  Future<String> descargar({
    required String url,
    required String nombre,
    String? carpetaBase,
    void Function(int recibidos, int total)? progreso,
  }) async {
    final base = carpetaBase != null
        ? Directory(carpetaBase)
        : await getTemporaryDirectory();
    final carpeta = Directory('${base.path}/$kCarpetaApk');
    if (!await carpeta.exists()) {
      await carpeta.create(recursive: true);
    }
    final destino = '${carpeta.path}/$nombre';
    await _dio.download(
      url,
      destino,
      deleteOnError: true, // un APK a medias nunca queda tirado en el cache
      onReceiveProgress: progreso,
    );
    return destino;
  }

  /// Lanza el instalador de Android sobre el APK ya descargado. false si
  /// el sistema no pudo abrir la ventana (la pantalla avisa, sin crash).
  Future<bool> instalar(String ruta) async {
    if (!disponible) return false;
    try {
      return await _canal.invokeMethod<bool>('instalar', {'ruta': ruta}) ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  /// Abre el ajuste de sistema «Instalar apps desconocidas» de ESTA app
  /// (API 26+). false si el dispositivo no lo expone.
  Future<bool> abrirAjustesOrigen() async {
    if (!disponible) return false;
    try {
      return await _canal.invokeMethod<bool>('abrirAjustesOrigen') ?? false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }
}
