/// Tests del actualizador del canal dev (v22.3 + v22.4): comparador de
/// versiones, parser del payload real de la API de Releases (el formato del
/// repo, con sus DOS estilos de nombre de APK), traducción de fallos
/// (rate-limit de GitHub incluido) y la pantalla completa — novedad, al
/// día, sin releases y reintento tras fallo. v22.4 añade el ciclo IN-APP:
/// la descarga real del APK (adaptador de dio sin red → archivo en disco
/// temporal) y la pantalla con instalador fabricado (progreso, permiso,
/// fallo y reintento). El cliente real se ejercita a través de adaptadores
/// de dio que devuelven el cuerpo crudo, sin tocar la red.
library;

import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:valorave/core/shad_theme.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/github_releases.dart';
import 'package:valorave/features/actualizaciones/actualizaciones_screen.dart';
import 'package:valorave/services/instalador_apk.dart';

void main() {
  group('VersionTriple (v22.3): parse de tags y pubspec', () {
    test('v1.0.2-beta: el formato de las 3 Releases históricas del repo', () {
      final v = VersionTriple.tryParse('v1.0.2-beta');
      expect(v, isNotNull);
      expect(v!.mayor, 1);
      expect(v.menor, 0);
      expect(v.parche, 2);
      expect(v.pre, 'beta');
      expect(v.build, 0);
      expect(v.bonito, '1.0.2-beta');
    });

    test('1.14.3-beta+46: como lo arma PackageInfo (versión + buildNumber)', () {
      final v = VersionTriple.tryParse('1.14.3-beta+46');
      expect(v, isNotNull);
      expect(v!.build, 46);
      expect(v.bonito, '1.14.3-beta+46');
    });

    test('prefijos y sufijos raros: mayúscula, rc con punto y build', () {
      final v = VersionTriple.tryParse('V2.1.0-rc.1+7');
      expect(v, isNotNull);
      expect(v!.mayor, 2);
      expect(v.pre, 'rc.1');
      expect(v.build, 7);
    });

    test('lo que no se sabe leer da null (se ignora al comparar)', () {
      expect(VersionTriple.tryParse(''), isNull);
      expect(VersionTriple.tryParse('v1'), isNull);
      expect(VersionTriple.tryParse('1.2'), isNull);
      expect(VersionTriple.tryParse('main'), isNull);
      expect(VersionTriple.tryParse('lorito'), isNull);
      expect(VersionTriple.tryParse('1.14.3-beta+'), isNotNull); // build roto→0
    });

    test('comparación: el build solo decide entre versiones iguales', () {
      final a = VersionTriple.tryParse('1.14.3-beta+46')!;
      final b = VersionTriple.tryParse('1.14.3-beta+45')!;
      expect(a.esPosteriorA(b), isTrue);
      expect(b.esPosteriorA(a), isFalse);
      // Un build más alto NO compensa un parche más viejo.
      final vieja = VersionTriple.tryParse('1.14.2-beta+99')!;
      expect(a.esPosteriorA(vieja), isTrue);
      // Mayor y menor dominan primero.
      expect(
        VersionTriple.tryParse('2.0.0')!.esPosteriorA(
              VersionTriple.tryParse('1.99.99')!,
            ),
        isTrue,
      );
    });

    test('comparación: estable > pre-release, y orden natural entre pre', () {
      final estable = VersionTriple.tryParse('1.0.0')!;
      final beta = VersionTriple.tryParse('1.0.0-beta')!;
      final beta1 = VersionTriple.tryParse('1.0.0-beta.1')!;
      expect(estable.esPosteriorA(beta), isTrue);
      expect(beta1.esPosteriorA(beta), isTrue);
      expect(estable == VersionTriple.tryParse('v1.0.0'), isTrue);
    });
  });

  group('ReleaseInfo/ReleaseAsset (v22.3): el payload del repo', () {
    test('assets: filtrar APK, detectar ABI en ambos estilos de nombre', () {
      final moderna = ReleaseAsset.fromJson({
        'name': 'valorave-v1.14.3-beta-build-20261024-arm64-v8a.apk',
        'size': 25469440,
        'browser_download_url': 'https://ejemplo/arm64.apk',
      });
      final antigua = ReleaseAsset.fromJson({
        'name': 'app-universal-release.apk',
        'size': 831488,
        'browser_download_url': 'https://ejemplo/universal.apk',
      });
      final aab = ReleaseAsset.fromJson({
        'name': 'app-release.aab',
        'size': 38746112,
        'browser_download_url': 'https://ejemplo/app.aab',
      });
      expect(moderna.esApk, isTrue);
      expect(moderna.abi, 'arm64-v8a');
      expect(moderna.tamano, '24,3 MB');
      expect(antigua.esApk, isTrue);
      expect(antigua.abi, 'universal');
      expect(antigua.tamano, '812 KB');
      expect(aab.esApk, isFalse);
      expect(ReleaseAsset.fromJson({'name': 'x.apk', 'size': 0, 'browser_download_url': ''}).tamano, '—');
    });

    test('ReleaseInfo: de los 6 adjuntos de CI, apks son los 4 APK', () {
      final r = ReleaseInfo.fromJson(_mapaNovedad());
      expect(r.tag, 'v1.14.3-beta+46');
      expect(r.version!.bonito, '1.14.3-beta+46');
      expect(r.publicada, isNotNull);
      expect(r.apks.length, 4);
      expect(
        r.apks.every((a) => a.abi != null),
        isTrue,
        reason: 'los 4 APK de CI traen su ABI en el nombre',
      );
    });
  });

  group('traducirFalloReleases (v22.3): fallos en cristiano', () {
    test('403 con rate-limit agotado explica el techo de 60 por hora', () {
      final e = _dioError(403, extra: {'x-ratelimit-remaining': ['0']});
      expect(traducirFalloReleases(e), contains('60 por hora'));
    });

    test('timeout y 404 tienen su propio mensaje', () {
      final opts = RequestOptions(path: 'x');
      expect(
        traducirFalloReleases(
          DioException(
            requestOptions: opts,
            type: DioExceptionType.connectionTimeout,
          ),
        ),
        contains('conexión'),
      );
      expect(traducirFalloReleases(_dioError(404)), contains('no expone'));
    });
  });

  group('GithubReleasesClient.listar (v22.3): parse real vía dio', () {
    test('parsea el cuerpo crudo de la API y respeta el orden', () async {
      final dio = Dio()..httpClientAdapter = _AdaptadorFijo(200, [
        _mapaNovedad(),
        _mapaVieja(),
      ]);
      final releases = await GithubReleasesClient(dio: dio).listar();
      expect(releases.length, 2);
      expect(releases.first.tag, 'v1.14.3-beta+46');
      expect(releases.last.version!.bonito, '1.0.2-beta');
    });

    test('403 de rate-limit llega como ReleasesException traducida', () async {
      final dio = Dio()
        ..httpClientAdapter = _AdaptadorFijo(403, {'message': 'rate'},
            extra: {'x-ratelimit-remaining': ['0']});
      try {
        await GithubReleasesClient(dio: dio).listar();
        fail('debía lanzar');
      } on ReleasesException catch (e) {
        expect(e.mensaje, contains('60 por hora'));
      }
    });
  });

  group('notasPlanas (v22.3): markdown de GitHub a texto de la app', () {
    test('enlaces → texto, sin #, sin negritas, sin Full Changelog', () {
      final salida = notasPlanas(
        '## Qué trae\n'
        '- **Actualizaciones**: revisa [GitHub Releases](https://github.com/x/y)\n'
        '\n---\n'
        '**Full Changelog**: v1...v2\n'
        '\n\n',
      );
      expect(salida.contains('#'), isFalse);
      expect(salida.contains('**'), isFalse);
      expect(salida.contains('Full Changelog'), isFalse);
      expect(salida.contains('https'), isFalse);
      expect(salida.contains('GitHub Releases'), isTrue);
    });
  });

  group('Pantalla Actualizaciones (v22.3)', () {
    testWidgets('con Release más nueva: anuncia, lista APK y muestra notas', (
      tester,
    ) async {
      final falso = _ClienteFalso()..respuesta = [ReleaseInfo.fromJson(_mapaNovedad())];
      await _pump(tester, cliente: falso);
      expect(find.text('Hay una actualización'), findsOneWidget);
      expect(find.textContaining('v1.14.3-beta+46'), findsOneWidget);
      expect(find.text('ValoraVE 22.4'), findsOneWidget);
      expect(find.textContaining('revisa GitHub Releases'), findsOneWidget);
      // Las 4 filas de descarga (la primera, arm64, orden preferente).
      await _arrastrarHasta(
        tester,
        find.text('Teléfonos modernos · arm64-v8a'),
      );
      expect(find.text('Teléfonos modernos · arm64-v8a'), findsOneWidget);
      expect(find.text('Todo-en-uno · universal'), findsOneWidget);
    });

    testWidgets('al día: la Release más reciente no supera al build', (
      tester,
    ) async {
      final falso = _ClienteFalso()
        ..respuesta = [
          ReleaseInfo.fromJson(_mapaVieja()),
          ReleaseInfo.fromJson(_mapaVieja(tag: 'v1.0.1-beta')),
        ];
      await _pump(tester, cliente: falso);
      expect(find.text('Estás al día'), findsOneWidget);
      expect(find.textContaining('v1.0.2-beta'), findsWidgets);
      // El canal recorre hacia atrás: las viejas quedan a un toque.
      expect(find.text('RELEASES RECIENTES'), findsOneWidget);
    });

    testWidgets('sin Releases legibles: lo dice y enlaza al repo', (
      tester,
    ) async {
      final falso = _ClienteFalso()..respuesta = [];
      await _pump(tester, cliente: falso);
      expect(find.text('Aún no hay Releases legibles'), findsOneWidget);
      expect(find.text('Ver Releases en GitHub'), findsOneWidget);
    });

    testWidgets('fallo de red: mensaje humano y Reintentar re-consulta', (
      tester,
    ) async {
      final falso = _ClienteFalso()
        ..error = const ReleasesException(
          'No se pudo hablar con GitHub. Revisa tu conexión a internet.',
        );
      await _pump(tester, cliente: falso);
      expect(find.text('No se pudo comprobar'), findsOneWidget);
      expect(find.textContaining('Revisa tu conexión'), findsOneWidget);
      expect(falso.llamadas, 1);
      // El reintento sale del fallo: el falso cambia a respuesta buena.
      falso.error = null;
      falso.respuesta = [ReleaseInfo.fromJson(_mapaVieja())];
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
      expect(falso.llamadas, 2);
      expect(find.text('Estás al día'), findsOneWidget);
    });

    testWidgets('tocar un APK avisa cuando el sistema no puede abrir', (
      tester,
    ) async {
      // En el entorno de test (host Linux, instalador real disponible
      // = false) las filas conservan la vía navegador de v22.3. Nadie
      // atiende el canal de url_launcher: el falso contesta «no pude
      // abrir», que es justo el camino prometido (fallo de plataforma →
      // aviso, nunca silencio).
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(
            const MethodChannel('plugins.flutter.io/url_launcher'),
            (call) async => false,
          );
      final falso = _ClienteFalso()..respuesta = [ReleaseInfo.fromJson(_mapaNovedad())];
      await _pump(tester, cliente: falso);
      await _arrastrarHasta(
        tester,
        find.text('Teléfonos modernos · arm64-v8a'),
      );
      await tester.tap(find.text('Teléfonos modernos · arm64-v8a'));
      await tester.pumpAndSettle(const Duration(milliseconds: 200));
      expect(find.textContaining('No se pudo abrir el enlace'), findsOneWidget);
    });
  });

  group('InstaladorApk · descarga in-app (v22.4)', () {
    test('disponible: gate honesto — el host de tests no es Android', () {
      // En Android real el VM impl responde true; en web el stub responde
      // false y en este host (Linux) también — es la regla que devuelve
      // las filas a la vía navegador fuera del teléfono.
      expect(InstaladorApk().disponible, isFalse);
    });

    test(
      'descarga: escribe el APK en <carpeta>/valora_update y avisa el progreso',
      () async {
        final temp = await Directory.systemTemp.createTemp('valora_test_apk');
        addTearDown(() => temp.delete(recursive: true));
        final dio = Dio()..httpClientAdapter = _AdaptadorApk();
        final progreso = <int>[];
        final ruta = await InstaladorApk(dio: dio).descargar(
          url: 'https://github.com/x/arm64-v8a.apk',
          nombre: 'valorave-arm64.apk',
          carpetaBase: temp.path,
          progreso: (recibidos, total) => progreso.add(recibidos),
        );
        final archivo = File(ruta);
        expect(await archivo.exists(), isTrue);
        expect(await archivo.length(), _AdaptadorApk.tamano);
        // La ruta cuelga de la carpeta que el FileProvider del manifest
        // declara (valora_update/ bajo el cache) y conserva el nombre
        // original del asset — el instalador debe encontrarlo ahí.
        expect(ruta, contains('valora_update'));
        expect(ruta, endsWith('valorave-arm64.apk'));
        expect(progreso.isNotEmpty, isTrue);
        expect(progreso.last, _AdaptadorApk.tamano);
      },
    );
  });

  group('Instalación in-app en la pantalla (v22.4)', () {
    testWidgets(
      'Android: tocar el APK descarga in-app y lanza el instalador',
      (tester) async {
        final falso = _InstaladorFalso();
        final cliente = _ClienteFalso()
          ..respuesta = [ReleaseInfo.fromJson(_mapaNovedad())];
        await _pump(tester, cliente: cliente, instalador: falso);
        // La pantalla sabe que está en Android: cambia la etiqueta y el
        // hint cuenta la verdad del ciclo in-app (case-insensitive: el
        // hint usa «DENTRO», el pie del ListView usa «dentro» y queda
        // fuera del viewport perezoso).
        expect(find.text('DESCARGAR E INSTALAR'), findsOneWidget);
        expect(
          find.textContaining(RegExp('dentro de la app', caseSensitive: false)),
          findsWidgets,
        );
        await _arrastrarHasta(
          tester,
          find.text('Teléfonos modernos · arm64-v8a'),
        );
        await tester.tap(find.text('Teléfonos modernos · arm64-v8a'));
        await tester.pumpAndSettle(const Duration(milliseconds: 200));
        expect(falso.descargas, 1);
        expect(falso.instalaciones, 1);
        expect(
          find.text('Descargado · instalador de Android en camino'),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'sin permiso de orígenes desconocidos: diálogo con Abrir ajustes',
      (tester) async {
        final falso = _InstaladorFalso()..permiso = false;
        final cliente = _ClienteFalso()
          ..respuesta = [ReleaseInfo.fromJson(_mapaNovedad())];
        await _pump(tester, cliente: cliente, instalador: falso);
        await _arrastrarHasta(
          tester,
          find.text('Teléfonos modernos · arm64-v8a'),
        );
        await tester.tap(find.text('Teléfonos modernos · arm64-v8a'));
        await tester.pumpAndSettle(const Duration(milliseconds: 200));
        // Preguntado ANTES de gastar la descarga:
        expect(falso.descargas, 0);
        expect(find.text('Un permiso, una sola vez'), findsOneWidget);
        await tester.tap(find.text('Abrir ajustes'));
        await tester.pumpAndSettle(const Duration(milliseconds: 200));
        expect(falso.ajustesAbiertos, 1);
      },
    );

    testWidgets(
      'descarga interrumpida: estado de fallo y reintento limpio',
      (tester) async {
        final falso = _InstaladorFalso()..errorDescarga = true;
        final cliente = _ClienteFalso()
          ..respuesta = [ReleaseInfo.fromJson(_mapaNovedad())];
        await _pump(tester, cliente: cliente, instalador: falso);
        await _arrastrarHasta(
          tester,
          find.text('Teléfonos modernos · arm64-v8a'),
        );
        await tester.tap(find.text('Teléfonos modernos · arm64-v8a'));
        await tester.pumpAndSettle(const Duration(milliseconds: 200));
        expect(
          find.text('La descarga se interrumpió. Toca para reintentar.'),
          findsOneWidget,
        );
        expect(falso.instalaciones, 0);
        falso.errorDescarga = false;
        await tester.tap(find.text('Teléfonos modernos · arm64-v8a'));
        await tester.pumpAndSettle(const Duration(milliseconds: 200));
        expect(falso.descargas, 2);
        expect(falso.instalaciones, 1);
      },
    );
  });
}

/// La Release que CI publicaría para esta ronda: 4 APK + AAB + ZIP con los
/// nombres semánticos de build.yml (v18.0) y notas autogeneradas.
Map<String, dynamic> _mapaNovedad() => {
  'tag_name': 'v1.14.3-beta+46',
  'name': 'v22.3 — actualizador del canal dev',
  'body':
      '## Qué trae\n'
      '- **Actualizaciones**: revisa [GitHub Releases](https://github.com/isaac4722/Valora-VE/releases)\n'
      '\n---\n'
      '**Full Changelog**: v1...v2\n',
  'html_url': 'https://github.com/isaac4722/Valora-VE/releases/tag/v1.14.3-beta%2B46',
  'published_at': '2026-10-24T02:30:00Z',
  'prerelease': false,
  'assets': [
    {
      'name': 'valorave-v1.14.3-beta-build-20261024-arm64-v8a.apk',
      'size': 25469440,
      'browser_download_url': 'https://github.com/x/arm64-v8a.apk',
    },
    {
      'name': 'valorave-v1.14.3-beta-build-20261024-universal.apk',
      'size': 45211648,
      'browser_download_url': 'https://github.com/x/universal.apk',
    },
    {
      'name': 'valorave-v1.14.3-beta-build-20261024-armeabi-v7a.apk',
      'size': 23401216,
      'browser_download_url': 'https://github.com/x/armeabi-v7a.apk',
    },
    {
      'name': 'valorave-v1.14.3-beta-build-20261024-x86_64.apk',
      'size': 24123392,
      'browser_download_url': 'https://github.com/x/x86_64.apk',
    },
    {
      'name': 'valorave-v1.14.3-beta-build-20261024.aab',
      'size': 38746112,
      'browser_download_url': 'https://github.com/x/app.aab',
    },
    {
      'name': 'valorave-v1.14.3-beta-build-20261024-completo.zip',
      'size': 157001216,
      'browser_download_url': 'https://github.com/x/completo.zip',
    },
  ],
};

/// Una Release vieja con el estilo de nombre ANTIGUO de los APK (v1.0.x,
/// antes del renombrado semántico): también tiene que parsear.
Map<String, dynamic> _mapaVieja({String tag = 'v1.0.2-beta'}) => {
  'tag_name': tag,
  'name': tag,
  'body': 'Primeras versiones del canal.',
  'html_url': 'https://github.com/isaac4722/Valora-VE/releases/tag/$tag',
  'published_at': '2025-08-11T18:00:00Z',
  'prerelease': false,
  'assets': [
    {
      'name': 'app-arm64-v8a-release.apk',
      'size': 19922944,
      'browser_download_url': 'https://github.com/x/vieja-arm64.apk',
    },
    {
      'name': 'app-release.aab',
      'size': 28311552,
      'browser_download_url': 'https://github.com/x/vieja.aab',
    },
  ],
};

DioException _dioError(int codigo, {Map<String, List<String>>? extra}) {
  final opts = RequestOptions(path: 'x');
  return DioException(
    requestOptions: opts,
    response: Response<Map<String, dynamic>>(
      requestOptions: opts,
      statusCode: codigo,
      data: {},
      headers: Headers.fromMap({
        ...(extra ?? const {}),
      }),
    ),
  );
}

/// Adaptador de dio que devuelve un cuerpo fijo sin tocar la red: el
/// cliente real de la app se ejercita completo (URL, headers, decode).
class _AdaptadorFijo implements HttpClientAdapter {
  _AdaptadorFijo(this.codigo, this.cuerpo, {this.extra});

  final int codigo;
  final Object cuerpo;
  final Map<String, List<String>>? extra;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelReceiveProgress,
  ) async {
    return ResponseBody(
      Stream.value(utf8.encode(jsonEncode(cuerpo))),
      codigo,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
        ...?extra,
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Cliente falso con el mismo contrato del real (seam de la pantalla).
class _ClienteFalso extends GithubReleasesClient {
  List<ReleaseInfo> respuesta = [];
  Object? error;
  int llamadas = 0;

  @override
  Future<List<ReleaseInfo>> listar() async {
    llamadas++;
    if (error != null) throw error!;
    return respuesta;
  }
}

/// El mismo patrón del push_screen_test: ShadApp.custom + MaterialApp con
/// el tema de la app. La versión instalada va por el seam, sin PackageInfo.
Future<void> _pump(
  WidgetTester tester, {
  required GithubReleasesClient cliente,
  InstaladorApk? instalador,
  String instalada = '1.14.2-beta+45',
}) async {
  await tester.pumpWidget(
    ShadApp.custom(
      theme: ShadThemeVe.light(),
      darkTheme: ShadThemeVe.dark(),
      appBuilder: (context) => MaterialApp(
        theme: AppTheme.light(),
        home: ActualizacionesScreen(
          cliente: cliente,
          instalador: instalador,
          versionInstalada: instalada,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 120));
}

Future<void> _arrastrarHasta(WidgetTester tester, Finder objetivo) async {
  await tester.scrollUntilVisible(
    objetivo,
    240,
    scrollable: find.byType(Scrollable).first,
    duration: const Duration(milliseconds: 40),
  );
  await tester.pumpAndSettle(const Duration(milliseconds: 60));
}

/// Adaptador de dio que sirve UN APK de 12 KB en 3 chunks con su
/// content-length: ejercita la descarga real del VM impl (archivo en
/// disco, progreso por chunk, carpeta valora_update) sin tocar la red.
class _AdaptadorApk implements HttpClientAdapter {
  static const int tamano = 4096 * 3;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelReceiveProgress,
  ) async {
    return ResponseBody(
      Stream<Uint8List>.fromIterable([
        Uint8List(4096)..fillRange(0, 4096, 65),
        Uint8List(4096)..fillRange(0, 4096, 65),
        Uint8List(4096)..fillRange(0, 4096, 65),
      ]),
      200,
      headers: {
        Headers.contentTypeHeader: ['application/octet-stream'],
        Headers.contentLengthHeader: ['$tamano'],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

/// Instalador falso con el contrato del real (seam v22.4 de la pantalla):
/// cuenta descargas/instalaciones/ajustes y se rompe a voluntad para
/// ejercitar fallo de red, permiso negado y reinstalación.
class _InstaladorFalso implements InstaladorApk {
  bool permiso = true;
  bool errorDescarga = false;
  int descargas = 0;
  int instalaciones = 0;
  int ajustesAbiertos = 0;

  @override
  bool get disponible => true; // «Android» en estos tests

  @override
  Future<bool> get puedeInstalar async => permiso;

  @override
  Future<String> descargar({
    required String url,
    required String nombre,
    String? carpetaBase,
    void Function(int recibidos, int total)? progreso,
  }) async {
    descargas++;
    if (errorDescarga) throw const SocketException('red rota');
    progreso?.call(1200, 1200); // completo de una (100 %)
    return '/cache/valora_update/$nombre';
  }

  @override
  Future<bool> instalar(String ruta) async {
    instalaciones++;
    return true;
  }

  @override
  Future<bool> abrirAjustesOrigen() async {
    ajustesAbiertos++;
    return true;
  }
}
