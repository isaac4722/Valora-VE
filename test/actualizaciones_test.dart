/// Tests del actualizador del canal dev (v22.3): comparador de versiones,
/// parser del payload real de la API de Releases (el formato del repo, con
/// sus DOS estilos de nombre de APK), traducción de fallos (rate-limit de
/// GitHub incluido) y la pantalla completa — novedad, al día, sin releases
/// y reintento tras fallo. El cliente real se ejercita a través de un
/// adaptador de dio que devuelve el cuerpo crudo, sin tocar la red.
library;

import 'dart:convert';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:valorave/core/shad_theme.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/github_releases.dart';
import 'package:valorave/features/actualizaciones/actualizaciones_screen.dart';

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
      expect(find.text('ValoraVE 22.3'), findsOneWidget);
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
      // En el entorno de test nadie atiende el canal de url_launcher: el
      // falso contesta «no pude abrir», que es justo el camino que esta
      // pieza promete (fallo de plataforma → aviso, nunca silencio).
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
      // En el entorno de test no hay navegador que atienda el canal de
      // url_launcher: el servicio de la app convierte eso en aviso, no
      // en silencio ni en excepción.
      expect(find.textContaining('No se pudo abrir el enlace'), findsOneWidget);
    });
  });
}

// ── Fixtures ────────────────────────────────────────────────────────────────

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
