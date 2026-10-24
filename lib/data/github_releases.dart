/// ─── GitHub Releases del canal dev (v22.3) ──────────────────────────────────
/// El canal de distribución del desarrollo ya vive en el propio repo: el job
/// `release` de build.yml adjunta los 4 APK + el AAB a una Release en cada
/// tag «v*». Esta pieza es el OJO de la app hacia ese canal: consulta la API
/// pública de Releases (anónima, 60/h por IP — de sobra para el dueño y sus
/// teléfonos de prueba), compara versiones y entrega los enlaces de descarga.
///
/// Decisiones de la pieza (orden del dueño: «crea el actualizador… no para
/// producción»):
/// - Plugin tercero (`github_release_apk_updater`) descartado: exige
///   FileProvider con external-path, REQUEST_INSTALL_PACKAGES en el manifest
///   y su historial registra conflictos de fusión de manifest hasta 1.0.11.
/// - v22.3: la descarga iba por el NAVEGADOR. v22.4 (orden del dueño: la
///   app descarga e instala sin gestos manuales): la descarga es IN-APP
///   (dio → cache/valora_update, en services/instalador_apk_vm.dart) y la
///   instalación la lanza el canal first-party `valorave/instalador`
///   (FileProvider escrito por el propio repo). El navegador queda como
///   vía de respaldo en web.
/// - Sin tokens dentro del APK: el repo es público y la lectura de Releases
///   no lleva credenciales (AGENT.md: jamás commitear secretos).
library;

import 'package:dio/dio.dart';

/// Versión semántica parseada de un tag de Release o del pubspec instalado.
/// Formatos que acepta — todo lo demás se ignora en silencio al comparar:
///   `v1.0.2-beta` · `1.14.3-beta+46` · `v1.0.0` · `2.1.0-rc.1+7`
class VersionTriple implements Comparable<VersionTriple> {
  const VersionTriple(
    this.mayor,
    this.menor,
    this.parche, {
    this.pre,
    this.build = 0,
  });

  final int mayor;
  final int menor;
  final int parche;

  /// Sufijo `-beta`, `-rc.1`… (`null` = release estable).
  final String? pre;

  /// Número tras «+» (0 cuando el tag no lo trae).
  final int build;

  static final RegExp _nucleo = RegExp(
    r'^(\d+)\.(\d+)\.(\d+)(?:-([0-9A-Za-z][0-9A-Za-z.\-]*))?$',
  );

  /// Devuelve null si el texto no es una versión que sepa comparar.
  static VersionTriple? tryParse(String cruda) {
    var s = cruda.trim();
    if (s.isEmpty) return null;
    if (s[0].toLowerCase() == 'v') s = s.substring(1);
    var build = 0;
    final mas = s.indexOf('+');
    if (mas >= 0) {
      build = int.tryParse(s.substring(mas + 1)) ?? 0;
      s = s.substring(0, mas);
    }
    final m = _nucleo.firstMatch(s);
    if (m == null) return null;
    return VersionTriple(
      int.parse(m.group(1)!),
      int.parse(m.group(2)!),
      int.parse(m.group(3)!),
      pre: m.group(4),
      build: build,
    );
  }

  @override
  int compareTo(VersionTriple other) {
    var d = mayor.compareTo(other.mayor);
    if (d != 0) return d;
    d = menor.compareTo(other.menor);
    if (d != 0) return d;
    d = parche.compareTo(other.parche);
    if (d != 0) return d;
    // Estable > pre-release; entre pre-releases, orden alfabético natural.
    if (pre == null && other.pre != null) return 1;
    if (pre != null && other.pre == null) return -1;
    if (pre != null && other.pre != null) {
      d = pre!.compareTo(other.pre!);
      if (d != 0) return d;
    }
    return build.compareTo(other.build);
  }

  /// ¿Esta versión es MÁS NUEVA que [otra]? (comparación estricta).
  bool esPosteriorA(VersionTriple otra) => compareTo(otra) > 0;

  /// Forma canónica que se muestra: `1.14.3-beta+46`.
  String get bonito =>
      '$mayor.$menor.$parche${pre == null ? '' : '-$pre'}'
      '${build > 0 ? '+$build' : ''}';

  @override
  String toString() => bonito;

  @override
  bool operator ==(Object other) =>
      other is VersionTriple && compareTo(other) == 0;

  @override
  int get hashCode => Object.hash(mayor, menor, parche, pre, build);
}

/// Un archivo adjunto de una Release (APK, AAB, ZIP, checksums…).
class ReleaseAsset {
  const ReleaseAsset({
    required this.nombre,
    required this.bytes,
    required this.url,
  });

  final String nombre;
  final int bytes;
  final String url;

  bool get esApk => nombre.toLowerCase().endsWith('.apk');

  /// ABI que trae el nombre (`arm64-v8a`, `universal`…) o null si no se lee.
  /// Cubre los DOS formatos de nombre que ha tenido el repo: el actual
  /// `valorave-v…-{abi}.apk` y el antiguo `app-{abi}-release.apk`.
  String? get abi {
    for (final a in const [
      'arm64-v8a',
      'armeabi-v7a',
      'x86_64',
      'universal',
    ]) {
      if (nombre.contains(a)) return a;
    }
    return null;
  }

  /// Tamaño legible con coma decimal es-VE: «24,3 MB» / «812 KB».
  String get tamano {
    if (bytes <= 0) return '—';
    const mb = 1024 * 1024;
    if (bytes >= mb) {
      return '${(bytes / mb).toStringAsFixed(1).replaceAll('.', ',')} MB';
    }
    return '${bytes ~/ 1024} KB';
  }

  factory ReleaseAsset.fromJson(Map<String, dynamic> j) => ReleaseAsset(
    nombre: (j['name'] ?? '') as String,
    bytes: (j['size'] ?? 0) as int,
    url: (j['browser_download_url'] ?? '') as String,
  );
}

/// Una Release de GitHub, solo con lo que la app usa.
class ReleaseInfo {
  const ReleaseInfo({
    required this.tag,
    required this.titulo,
    required this.notas,
    required this.paginaUrl,
    required this.publicada,
    required this.preLanzamiento,
    required this.adjuntos,
    required this.version,
  });

  final String tag;
  final String titulo;
  final String notas;
  final String paginaUrl;
  final DateTime? publicada;
  final bool preLanzamiento;
  final List<ReleaseAsset> adjuntos;

  /// Versión parseada del tag (null = tag ilegible: se muestra pero no
  /// participa en la comparación «hay novedad»).
  final VersionTriple? version;

  Iterable<ReleaseAsset> get apks => adjuntos.where((a) => a.esApk);

  factory ReleaseInfo.fromJson(Map<String, dynamic> j) => ReleaseInfo(
    tag: (j['tag_name'] ?? '') as String,
    titulo: (j['name'] ?? '') as String,
    notas: (j['body'] ?? '') as String,
    paginaUrl: (j['html_url'] ?? '') as String,
    publicada: DateTime.tryParse((j['published_at'] ?? '') as String),
    preLanzamiento: (j['prerelease'] ?? false) as bool,
    adjuntos: [
      for (final a
          in ((j['assets'] ?? const <dynamic>[]) as List<dynamic>)
              .whereType<Map<String, dynamic>>())
        ReleaseAsset.fromJson(a),
    ],
    version: VersionTriple.tryParse((j['tag_name'] ?? '') as String),
  );
}

/// Fallo hablando con la API de Releases, ya traducido a humano.
class ReleasesException implements Exception {
  const ReleasesException(this.mensaje);
  final String mensaje;

  @override
  String toString() => mensaje;
}

/// Traduce cualquier fallo del fetch a una frase que le sirve al dueño:
/// distingue el rate-limit anónimo de GitHub de la falta de conexión.
/// Testeado con excepciones de dio fabricadas (test/actualizaciones_test.dart).
String traducirFalloReleases(Object e) {
  if (e is DioException) {
    final codigo = e.response?.statusCode;
    final sobrante = e.response?.headers.value('x-ratelimit-remaining');
    if ((codigo == 403 || codigo == 429) && sobrante == '0') {
      return 'GitHub limitó las consultas anónimas de esta conexión '
          '(60 por hora). Espera un rato y vuelve a probar.';
    }
    if (codigo == 404) {
      return 'El repo todavía no expone Releases. Publica la primera '
          'con un tag «v…» y vuelve a comprobar.';
    }
    switch (e.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'No se pudo hablar con GitHub. Revisa tu conexión a internet.';
      default:
        break;
    }
    return 'GitHub respondió con un error ($codigo). '
        'Vuelve a probar en unos minutos.';
  }
  return 'GitHub respondió algo que la app no entendió. '
      'Vuelve a probar en unos minutos.';
}

/// Cliente de la API pública de Releases. Anónimo a propósito: el repo es
/// público y así se queda — cualquier token iría DENTRO del APK y sería
/// extraíble (vía inválida para este canal).
class GithubReleasesClient {
  GithubReleasesClient({Dio? dio, this.repo = 'isaac4722/Valora-VE'})
    : _dio = dio ?? _fabricarDio();

  final Dio _dio;
  final String repo;

  /// Máximo de Releases por consulta (la API devuelve la más reciente
  /// primero). Con 10 alcanza para ver varias rondas hacia atrás.
  static const int maximo = 10;

  static Dio _fabricarDio() => Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 10),
      sendTimeout: const Duration(seconds: 10),
      headers: const {'Accept': 'application/vnd.github+json'},
    ),
  );

  /// Releases más recientes primero, tal como las devuelve la API.
  Future<List<ReleaseInfo>> listar() async {
    try {
      final res = await _dio.get<List<dynamic>>(
        'https://api.github.com/repos/$repo/releases?per_page=$maximo',
      );
      return [
        for (final e in res.data ?? const <dynamic>[])
          if (e is Map<String, dynamic>) ReleaseInfo.fromJson(e),
      ];
    } catch (e) {
      // DioException y cualquier sorpresa del parseo llegan al mismo sitio:
      // un mensaje humano en pantalla. El detalle técnico va al log local.
      throw ReleasesException(traducirFalloReleases(e));
    }
  }
}
