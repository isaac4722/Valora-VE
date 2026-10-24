/// ─── Actualizaciones del canal dev (v22.4) ─────────────────────────────────
/// Pantalla empujada desde Ajustes («Buscar actualizaciones»). Comprueba las
/// Releases del propio repo en GitHub y avisa si hay una más nueva que el
/// build instalado.
///
/// v22.3 avisaba y mandaba al navegador (descarga manual + instalar a
/// mano). v22.4 — orden del dueño: «quiero que la app se descargue el APK
/// de la release temporalmente e instale, no un atajo y descargar e
/// instalar manual» — en Android el ciclo completo vive DENTRO de la app:
/// dio baja el APK a `<cache>/valora_update/` con progreso visible y al
/// terminar lanza el instalador del sistema por el canal first-party
/// `valorave/instalador` (FileProvider + REQUEST_INSTALL_PACKAGES en el
/// manifest del propio repo; el updater tercero siguió descartado por sus
/// conflictos de manifest). En web —sin filesystem ni instalador— queda
/// la vía navegador de v22.3 como respaldo honesto.
library;

import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/theme.dart';
import '../../core/version.dart';
import '../../data/github_releases.dart';
import '../../services/enlace_externo.dart';
import '../../services/instalador_apk.dart';
import '../../widgets/ui.dart';

/// Convierte las notas de GitHub (markdown de las Releases autogeneradas)
/// en texto plano digno de un Text: enlaces [texto](url) → texto, sin
/// encabezados #, sin negritas y sin la línea «Full Changelog» del
/// generador. Testeado en test/actualizaciones_test.dart.
@visibleForTesting
String notasPlanas(String md) {
  final sinEnlaces = md.replaceAllMapped(
    RegExp(r'\[([^\]]+)\]\([^)]*\)'),
    (m) => m.group(1)!,
  );
  final sinFormato = sinEnlaces
      .replaceAll(RegExp(r'^#{1,6}\s*', multiLine: true), '')
      .replaceAll('**', '')
      .replaceAll(RegExp(r'^\s*-{3,}\s*$', multiLine: true), '');
  final lineas = sinFormato.split('\n').where((l) {
    final t = l.trim();
    return t.isNotEmpty && !t.startsWith('Full Changelog');
  });
  return lineas.join('\n');
}

enum _Fase { cargando, lista, error }

enum _EstadoDescarga { pendiente, bajando, listo, fallo }

/// Estado de UNA descarga in-app de APK (v22.4), indexado por la URL del
/// asset en `_descargas` del estado de la pantalla.
class _Descarga {
  _EstadoDescarga estado = _EstadoDescarga.pendiente;

  /// Porcentaje entero: setState solo cuando cambia (dio manda por chunk).
  int pct = 0;
  String ruta = '';
  String error = '';
}

/// Cómo se pinta la fecha en pantalla: dd/mm/aaaa, como se lee en Venezuela.
String _fecha(DateTime? d) {
  if (d == null) return 'fecha desconocida';
  final dd = d.day.toString().padLeft(2, '0');
  final mm = d.month.toString().padLeft(2, '0');
  return '$dd/$mm/${d.year}';
}

class ActualizacionesScreen extends StatefulWidget {
  const ActualizacionesScreen({
    super.key,

    /// Seam de tests: cliente que entrega Releases fabricadas.
    this.cliente,

    /// Seam de tests (v22.4): instalador fabricado para ejercitar la
    /// descarga in-app y el lanzamiento del instalador sin plataforma.
    this.instalador,

    /// Seam de tests: versión ya resuelta («1.14.3-beta+46»), para no
    /// pasar por PackageInfo en widget tests.
    this.versionInstalada,
  });

  final GithubReleasesClient? cliente;
  final InstaladorApk? instalador;
  final String? versionInstalada;

  @override
  State<ActualizacionesScreen> createState() => _ActualizacionesScreenState();
}

class _ActualizacionesScreenState extends State<ActualizacionesScreen> {
  final GithubReleasesClient _clientePropio = GithubReleasesClient();

  /// Real en Android; stub en web. En el Linux de tests `disponible` es
  /// false (no es Android) y las filas vuelven a la vía navegador.
  late final InstaladorApk _instalador = widget.instalador ?? InstaladorApk();

  /// Descarga in-app por asset (clave: su URL de descarga).
  final Map<String, _Descarga> _descargas = {};

  _Fase _fase = _Fase.cargando;
  List<ReleaseInfo> _releases = const [];
  String _error = '';
  VersionTriple? _instalada;
  String _instaladaTexto = '';

  @override
  void initState() {
    super.initState();
    _comprobar();
  }

  /// Versión del build instalado: del seam en tests, de PackageInfo en la
  /// app real («1.14.3-beta» + «46» → «1.14.3-beta+46»).
  Future<String> _versionDePlataforma() async {
    final p = await PackageInfo.fromPlatform();
    return '${p.version}+${p.buildNumber}';
  }

  Future<void> _comprobar() async {
    setState(() => _fase = _Fase.cargando);
    try {
      final cruda = widget.versionInstalada ?? await _versionDePlataforma();
      final releases = await (widget.cliente ?? _clientePropio).listar();
      if (!mounted) return;
      setState(() {
        _instalada = VersionTriple.tryParse(cruda);
        _instaladaTexto = _instalada?.bonito ?? cruda;
        _releases = releases;
        _fase = _Fase.lista;
        _error = '';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _fase = _Fase.error;
        _error = e is ReleasesException ? e.mensaje : traducirFalloReleases(e);
      });
    }
  }

  /// Primera Release cuyo tag se sabe leer (la API manda la más reciente
  /// primero; un tag raro no bloquea el resto).
  ReleaseInfo? get _ultima {
    for (final r in _releases) {
      if (r.version != null) return r;
    }
    return null;
  }

  bool get _hayNovedad =>
      _instalada != null &&
      _ultima != null &&
      _ultima!.version!.esPosteriorA(_instalada!);

  Future<void> _abrir(String url) async {
    final ok = await abrirEnlaceExterno(Uri.parse(url));
    if (!mounted || ok) return;
    showToast(context, 'No se pudo abrir el enlace.', kind: ToastKind.error);
  }

  /// Ciclo completo v22.4 en Android: descarga DENTRO de la app con
  /// progreso visible y, al terminar, el instalador de Android sobre el
  /// archivo temporal. El navegador queda para web (vía v22.3).
  Future<void> _instalarApk(ReleaseAsset asset) async {
    final d = _descargas.putIfAbsent(asset.url, _Descarga.new);
    if (d.estado == _EstadoDescarga.bajando) return;

    // APK ya descargado antes (cache vivo): instalar directo, sin re-bajar.
    if (d.estado == _EstadoDescarga.listo) {
      final ok = await _instalador.instalar(d.ruta);
      if (!ok && mounted) {
        setState(() {
          d.estado = _EstadoDescarga.pendiente;
          d.ruta = '';
        });
        showToast(
          context,
          'El instalador no abrió (¿recicló Android el archivo?). '
          'Toca de nuevo para volver a descargar.',
          kind: ToastKind.error,
        );
      }
      return;
    }

    // Android 8+: el permiso «Instalar apps desconocidas» se concede UNA
    // vez. Preguntarlo ANTES de gastar la descarga; el diálogo ofrece el
    // ajuste exacto de ValoraVE.
    if (!await _instalador.puedeInstalar) {
      if (mounted) _dialogoPermisoOrigen();
      return;
    }

    setState(() {
      d.estado = _EstadoDescarga.bajando;
      d.pct = 0;
      d.error = '';
    });
    try {
      final ruta = await _instalador.descargar(
        url: asset.url,
        nombre: asset.nombre,
        progreso: (recibidos, total) {
          // El tamaño ya lo trae la Release (asset.bytes): si el servidor
          // no manda content-length, con eso se calcula el porcentaje.
          final esperado = total > 0 ? total : asset.bytes;
          final nuevo = esperado > 0 ? (recibidos * 100 ~/ esperado) : 0;
          if (nuevo <= d.pct) return;
          d.pct = nuevo.clamp(0, 100);
          if (mounted) setState(() {});
        },
      );
      if (!mounted) return;
      setState(() {
        d.ruta = ruta;
        d.pct = 100;
        d.estado = _EstadoDescarga.listo;
      });
      final ok = await _instalador.instalar(ruta);
      if (!ok && mounted) {
        setState(() {
          d.estado = _EstadoDescarga.fallo;
          d.error = 'No se pudo abrir el instalador de Android. '
              'Toca para reintentar.';
        });
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        d.estado = _EstadoDescarga.fallo;
        d.error = 'La descarga se interrumpió. Toca para reintentar.';
      });
    }
  }

  /// Android exige autorizar «Instalar apps desconocidas» para apps que
  /// instalan sus propios APK. Un diálogo en cristiano y el botón que
  /// lleva AL ajuste de ValoraVE (no al menú general de configuración).
  Future<void> _dialogoPermisoOrigen() {
    return showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Un permiso, una sola vez'),
        content: Text(
          'Android exige autorizar explícitamente que ValoraVE instale '
          'actualizaciones descargadas por sí misma (fuera de una tienda). '
          'Se concede una vez en «Instalar apps desconocidas» y de ahí en '
          'adelante las rondas nuevas se instalan directo.',
          style: TextStyle(height: 1.5, fontSize: 13, color: null),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Después'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await _instalador.abrirAjustesOrigen();
              if (!ok && mounted) {
                showToast(
                  context,
                  'Tu Android no expone ese ajuste; el instalador lo '
                  'pedirá al llegar.',
                  kind: ToastKind.info,
                );
              }
            },
            child: const Text('Abrir ajustes'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return PushScreen(
      title: 'Actualizaciones',
      subtitle: 'Canal de desarrollo · GitHub Releases',
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          _TarjetaVersion(texto: _instaladaTexto),
          const SizedBox(height: 8),
          switch (_fase) {
            _Fase.cargando => const _TarjetaCargando(),
            _Fase.error => _TarjetaError(
              mensaje: _error,
              onReintentar: _comprobar,
            ),
            _Fase.lista => _tarjetaEstado(context),
          },
          if (_fase == _Fase.lista && _releases.length > 1) ...[
            const SizedBox(height: 8),
            _TarjetaRecientes(releases: _releases, alAbrir: _abrir),
          ],
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _instalador.disponible
                  ? 'La consulta es anónima (api.github.com permite 60 por '
                      'hora desde tu conexión); la descarga ocurre dentro de '
                      'la app y la instalación la lanza Android. Nada sale '
                      'de tu teléfono.'
                  : 'La consulta es anónima (api.github.com permite 60 por '
                      'hora desde tu conexión) y la descarga pasa por tu '
                      'navegador. La app no envía nada que te identifique.',
              style: TextStyle(
                fontSize: 11,
                height: 1.5,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Lo que corresponde mostrar según lo que devolvió GitHub.
  Widget _tarjetaEstado(BuildContext context) {
    final ultima = _ultima;
    if (ultima == null) return _TarjetaSinReleases(alAbrir: _abrir);
    if (_hayNovedad) return _tarjetaNovedad(context, ultima);
    return _TarjetaAlDia(tag: ultima.tag);
  }

  Widget _tarjetaNovedad(BuildContext context, ReleaseInfo r) {
    final scheme = Theme.of(context).colorScheme;
    final apks = r.apks.toList()
      ..sort((a, b) => _prefAbi(a.abi).compareTo(_prefAbi(b.abi)));
    return VeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.system_update_alt_rounded,
                size: 20,
                color: VeColors.of(context).pos,
              ),
              const SizedBox(width: 8),
              const Text(
                'Hay una actualización',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'v${r.version!.bonito} · publicada el ${_fecha(r.publicada)}',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          if (r.notas.trim().isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              'QUÉ TRAE',
              style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            Text(
              notasPlanas(r.notas),
              style: const TextStyle(fontSize: 12.5, height: 1.5),
            ),
          ],
          const SizedBox(height: 12),
          Text(
            _instalador.disponible ? 'DESCARGAR E INSTALAR' : 'DESCARGAR APK',
            style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
          ),
          for (final a in apks)
            _FilaApk(
              asset: a,
              descarga: _descargas[a.url],
              enApp: _instalador.disponible,
              alAbrir: () => _abrir(a.url),
              alInstalar: () => _instalarApk(a),
            ),
          const SizedBox(height: 6),
          Text(
            _instalador.disponible
                ? 'El APK baja DENTRO de la app a una carpeta temporal y al '
                    'terminar Android abre su ventana de instalación sobre '
                    'él. Se instala ENCIMA de la app que ya tienes: la '
                    'firma es la misma de siempre.'
                : 'El APK baja en tu navegador; ábrelo desde la barra de '
                    'notificaciones para instalarlo. Se instala ENCIMA de '
                    'la app que ya tienes: la firma es la misma de siempre.',
            style: TextStyle(
              fontSize: 11,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: const Text(
                'Abrir en GitHub',
                style: TextStyle(fontSize: 12.5),
              ),
              onPressed: () => _abrir(r.paginaUrl),
            ),
          ),
        ],
      ),
    );
  }

  /// Orden de preferencia de ABIs en la lista (arm64 primero: el teléfono
  /// más común; universal de segundo: el comodín).
  static int _prefAbi(String? abi) {
    const orden = ['arm64-v8a', 'universal', 'armeabi-v7a', 'x86_64'];
    final i = orden.indexOf(abi ?? '');
    return i < 0 ? orden.length : i;
  }
}

/// Tu versión instalada, tal como la lee el teléfono.
class _TarjetaVersion extends StatelessWidget {
  const _TarjetaVersion({required this.texto});

  final String texto;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return VeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'TU VERSIÓN',
            style: VeText.labelCaps(9.5, color: scheme.primary),
          ),
          const SizedBox(height: 6),
          Text(
            'ValoraVE $kAppVersionVisible',
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 2),
          Text(
            '$texto · instalada desde el canal dev',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 8),
          Text(
            'Cada ronda de trabajo termina en un APK firmado, adjunto a la '
            'Release del repo. Aquí compruebas si salió una más nueva.',
            style: TextStyle(
              fontSize: 11.5,
              height: 1.45,
              color: scheme.onSurfaceVariant,
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaCargando extends StatelessWidget {
  const _TarjetaCargando();

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return VeCard(
      child: Row(
        children: [
          const SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 10),
          Text(
            'Buscando en GitHub…',
            style: TextStyle(fontSize: 13, color: scheme.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _TarjetaError extends StatelessWidget {
  const _TarjetaError({required this.mensaje, required this.onReintentar});

  final String mensaje;
  final VoidCallback onReintentar;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return VeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.wifi_off_rounded,
                size: 20,
                color: VeColors.of(context).warn,
              ),
              const SizedBox(width: 8),
              const Text(
                'No se pudo comprobar',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            mensaje,
            style: TextStyle(
              fontSize: 12.5,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              icon: const Icon(Icons.refresh_rounded, size: 16),
              label: const Text('Reintentar', style: TextStyle(fontSize: 12.5)),
              onPressed: onReintentar,
            ),
          ),
        ],
      ),
    );
  }
}

/// No hay Releases (o ninguna con tag legible): canal recién nacido.
class _TarjetaSinReleases extends StatelessWidget {
  const _TarjetaSinReleases({required this.alAbrir});

  final Future<void> Function(String url) alAbrir;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return VeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Aún no hay Releases legibles',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Cuando CI publique la primera con un tag «v…» (o si las que hay '
            'traen tags que no se saben leer), aparecerá aquí.',
            style: TextStyle(
              fontSize: 12,
              height: 1.5,
              color: scheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              icon: const Icon(Icons.open_in_new_rounded, size: 15),
              label: const Text(
                'Ver Releases en GitHub',
                style: TextStyle(fontSize: 12.5),
              ),
              onPressed: () => alAbrir(
                'https://github.com/isaac4722/Valora-VE/releases',
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TarjetaAlDia extends StatelessWidget {
  const _TarjetaAlDia({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return VeCard(
      child: Row(
        children: [
          Icon(
            Icons.check_circle_outline_rounded,
            size: 20,
            color: VeColors.of(context).pos,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Estás al día',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'La Release más reciente del canal es $tag, igual o '
                  'anterior a tu build.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Las últimas Releases del canal, por si se quiere bajar una anterior
/// (útil cuando una ronda trae problemas y hay que volver atrás).
class _TarjetaRecientes extends StatelessWidget {
  const _TarjetaRecientes({required this.releases, required this.alAbrir});

  final List<ReleaseInfo> releases;
  final Future<void> Function(String url) alAbrir;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return VeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'RELEASES RECIENTES',
            style: VeText.labelCaps(9.5, color: scheme.primary),
          ),
          for (final r in releases.take(5))
            // Material transparente: el ListTile pinta su ripple sobre la
            // superficie de VeCard (mismo fix documentado de
            // _VeSettingsCard en Ajustes).
            Material(
              type: MaterialType.transparency,
              child: ListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 4),
                visualDensity: VisualDensity.compact,
                leading: Icon(
                  Icons.sell_outlined,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),
                title: Text(
                  r.tag,
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(
                  _fecha(r.publicada),
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                trailing: const Icon(Icons.open_in_new_rounded, size: 15),
                onTap: () => alAbrir(r.paginaUrl),
              ),
            ),
        ],
      ),
    );
  }
}

/// Fila de un APK de la Release. Dos vidas desde v22.4:
/// - Android (enApp): tap = descargar in-app con progreso y lanzar el
///   instalador del sistema (el ciclo completo, orden del dueño).
/// - Web/desarrollo: tap = navegador, la vía v22.3 (respaldo honesto).
class _FilaApk extends StatelessWidget {
  const _FilaApk({
    required this.asset,
    required this.descarga,
    required this.enApp,
    required this.alAbrir,
    required this.alInstalar,
  });

  final ReleaseAsset asset;

  /// Estado de la descarga in-app (null = sin intento todavía).
  final _Descarga? descarga;
  final bool enApp;
  final VoidCallback alAbrir;
  final VoidCallback alInstalar;

  static String _rotulo(String? abi) => switch (abi) {
    'arm64-v8a' => 'Teléfonos modernos · arm64-v8a',
    'armeabi-v7a' => 'Androids viejos · armeabi-v7a',
    'x86_64' => 'Emuladores e Intel · x86_64',
    'universal' => 'Todo-en-uno · universal',
    _ => 'APK de la Release',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final d = descarga;
    final estado = d?.estado ?? _EstadoDescarga.pendiente;
    final pct = d?.pct ?? 0;
    final error = d?.error ?? '';

    final (Widget trailing, String subtitulo) = switch (estado) {
      _EstadoDescarga.bajando => (
        SizedBox(
          width: 78,
          child: Row(
            children: [
              Expanded(
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(2),
                  child: LinearProgressIndicator(
                    value: pct <= 0 ? null : pct / 100,
                    minHeight: 3,
                  ),
                ),
              ),
              const SizedBox(width: 6),
              SizedBox(
                width: 26,
                child: Text(
                  '$pct%',
                  textAlign: TextAlign.right,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontFeatures: const [FontFeature.tabularFigures()],
                    color: scheme.primary,
                  ),
                ),
              ),
            ],
          ),
        ),
        'Descargando… ${asset.tamano}',
      ),
      _EstadoDescarga.listo => (
        Icon(
          Icons.check_circle_rounded,
          size: 20,
          color: VeColors.of(context).pos,
        ),
        'Descargado · instalador de Android en camino',
      ),
      _EstadoDescarga.fallo => (
        Icon(
          Icons.error_outline_rounded,
          size: 20,
          color: VeColors.of(context).warn,
        ),
        error.isEmpty
            ? 'No se pudo descargar — toca para reintentar.'
            : error,
      ),
      _EstadoDescarga.pendiente => (
        Icon(
          enApp ? Icons.install_mobile_rounded : Icons.download_rounded,
          size: 20,
        ),
        '${asset.nombre} · ${asset.tamano}',
      ),
    };

    return Material(
      // Superficie propia para el ripple (fix del ListTile sobre VeCard).
      type: MaterialType.transparency,
      child: ListTile(
        dense: true,
        contentPadding: const EdgeInsets.symmetric(horizontal: 4),
        visualDensity: VisualDensity.compact,
        leading: Icon(Icons.android_rounded, size: 19, color: scheme.primary),
        title: Text(
          _rotulo(asset.abi),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
        ),
        subtitle: Text(
          subtitulo,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
        ),
        trailing: trailing,
        onTap: enApp ? alInstalar : alAbrir,
      ),
    );
  }
}
