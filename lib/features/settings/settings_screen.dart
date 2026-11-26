/// ─── Ajustes (v30 · H-42 · v32 refactor de GUI) ─────────────────────────────
/// Ajustes en UNA pantalla por secciones. v32 (orden del dueño): GUI
/// refactorizada al lenguaje «HOJA» de la app — CADA sección con UN
/// encabezado SOLO (sin dobles rótulos), filas planas del kit (VeRow /
/// VeToggle / VeBtn), switches Material fuera, cajas dentro de cajas fuera,
/// separación uniforme y nada encogido.
///
/// Secciones: Cuentas y cobro (primero — el deep link del Conversor e Inicio
/// aterriza aquí) · Tasas y fuentes · Alertas · Diagnóstico · País y
/// decimales · Datos y conexión · Apariencia · Respaldo · Acerca de.
/// Las subpantallas v27 murieron: `/ajustes/general|tasas|apariencia|datos`
/// REDIRIGEN aquí y solo `/ajustes/cuentas` sobrevive.
library;

import 'dart:convert';

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/backup.dart';
import '../../data/board.dart';
import '../../data/store.dart';
import '../../services/biometric.dart';
import '../../services/sharing.dart';
import '../../services/ticket_files.dart';
import '../../services/ve_log.dart';
import 'package:talker_flutter/talker_flutter.dart';
import '../../widgets/export_sheet.dart';
import '../../widgets/bank_badge.dart';
import '../../widgets/app_tour.dart';
import '../../widgets/rate_sheet.dart';
import '../../widgets/ui.dart';
import '../../core/banks_ve.dart';
import '../../core/version.dart';
import '../home/app_widgets.dart' show showAppWidgetGallery;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorave/providers/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

part 'settings_sections.dart';
part 'settings_alertas.dart';
part 'settings_system.dart';
part 'cuentas_pago_movil.dart';

/// Ajustes en UNA pantalla (v30 · H-42) con GUI refactorizada (v32): una
/// sección = un encabezado solo + filas planas del kit.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            // ── Título SOLO (v32: los títulos no llevan nada al lado).
            Text(
              'Ajustes',
              style: VeText.displayNum(
                30,
                color: scheme.onSurface,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'La app, a tu manera.',
              style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
            ),
            // ── 1 · Cuentas y cobro (H-42: PRIMERO — el deep link del
            // Conversor e Inicio aterriza directo en esta sección).
            const VeEyebrow(
              hint:
                  'Guarda tus datos de cobro una vez y comparte el cobro '
                  'desde el Conversor. Todo queda en este teléfono.',
              child: Text('CUENTAS Y COBRO'),
            ),
            const CuentasPagoMovil(),
            // ── 2 · Tasas y fuentes: monedas por módulo, manuales y propias.
            const VeEyebrow(
              hint:
                  'De dónde sale cada tasa: la fuente por divisa y por '
                  'módulo, más tus tasas manuales.',
              child: Text('TASAS Y FUENTES'),
            ),
            _Monedas(store: store),
            // ── 3 · Alertas: permiso + picos + metas + recordatorio.
            const VeEyebrow(
              hint:
                  'Avisos útiles sin ruido: picos de tasa, metas que tú '
                  'fijas y el recordatorio de precios.',
              child: Text('ALERTAS'),
            ),
            _Alertas(store: store),
            // ── 4 · Diagnóstico: salud de las fuentes, a pedido.
            const VeEyebrow(
              hint: 'Consulta cada región y mide su respuesta. Si una falla, '
                  'las demás siguen.',
              child: Text('DIAGNÓSTICO DE FUENTES'),
            ),
            const _Diagnostico(),
            // ── 5 · País y decimales: el foco del tablero y la escala.
            const VeEyebrow(
              hint: 'Tu tablero en tu país y la escala decimal que quieres '
                  'ver.',
              child: Text('PAÍS Y DECIMALES'),
            ),
            _Pais(store: store),
            _Precision(store: store),
            // ── 6 · Datos y conexión: offline, intervalo, en vivo, widgets.
            const VeEyebrow(
              hint:
                  'Cuándo consulta la app y qué hace sin red. Las tasas se '
                  'guardan en tu teléfono.',
              child: Text('DATOS Y CONEXIÓN'),
            ),
            _DatosConexion(store: store),
            const _AppWidgetsRow(),
            // ── 7 · Apariencia: tema, Material You, biometría.
            const VeEyebrow(
              hint: 'El tono de la app y el candado al abrir.',
              child: Text('APARIENCIA'),
            ),
            const _Apariencia(),
            // ── 8 · Respaldo: exportar, importar y zona de peligro.
            const VeEyebrow(
              hint:
                  'Tus datos viven en este teléfono: respalda y recupera '
                  'cuando cambies de equipo.',
              child: Text('RESPALDO'),
            ),
            _Respaldo(store: store),
            // ── 9 · Acerca de: registros, bienvenida, actualizaciones, legal.
            const VeEyebrow(
              hint: 'La versión, los registros y los papeles de la casa.',
              child: Text('ACERCA DE'),
            ),
            const _Registros(),
            _TutorialLegal(store: store),
          ],
        ),
      ),
    );
  }
}

/// v32 · Fila plana de INTERRUPTOR del kit — sustituye a los
/// SwitchListTile de Material: título 13.5 w600, sub 11 muda con altura
/// cómoda y el VeToggle de la app a la derecha, centrado. Sin cajas.
class _FilaSwitch extends StatelessWidget {
  const _FilaSwitch({
    required this.titulo,
    required this.value,
    required this.onChanged,
    this.sub,
  });

  final String titulo;
  final String? sub;
  final bool value;
  final ValueChanged<bool>? onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  titulo,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.onSurface,
                  ),
                ),
                if (sub != null && sub!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    sub!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      height: 1.35,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 12),
          VeToggle(value: value, onChanged: onChanged),
        ],
      ),
    );
  }
}

/// Precisión decimal (v27 · REA CalculaYa): 2, 3 o 4 decimales. La API
/// publica 4; el usuario elige cuántos ver en tasas y resultados. v32: fila
/// plana — chips a lo ancho y nota muda, sin caja.
class _Precision extends ConsumerWidget {
  const _Precision({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        Row(
          children: [
            for (final d in const [2, 3, 4]) ...[
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(right: d == 4 ? 0 : 6),
                  child: ChipTag(
                    '$d decimales',
                    selected: store.settings.precision == d,
                    onTap: () => store.setPrecision(d),
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Se aplica a las tasas y al resultado del conversor. El redondeo '
          'sigue siendo un modo aparte en el conversor.',
          style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

class _AppWidgetsRow extends ConsumerWidget {
  const _AppWidgetsRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    if (kIsWeb) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 4),
        // v32: fila plana del kit — icono · título · chevron, sin caja.
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => showAppWidgetGallery(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Row(
              children: [
                Icon(
                  LucideIcons.layoutGrid,
                  size: 18,
                  color: scheme.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Añadir un widget de Android',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 17,
                  color: scheme.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Datos y conexión (v17.2 · v32 GUI plana): modo offline total + cada
/// cuánto se consultan las APIs + el empujón SSE opcional. Todo vive en
/// Settings (store) y el poller lo lee en vivo. Switches del kit.
class _DatosConexion extends ConsumerWidget {
  const _DatosConexion({required this.store});
  final AppStore store;

  static const _intervalos = <int, String>{
    1: 'Cada minuto (en vivo)',
    5: 'Cada 5 minutos',
    15: 'Cada 15 minutos',
    30: 'Cada 30 minutos',
    60: 'Cada hora (ahorro máximo)',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = store.settings;
    final poller = ref.watch(ratesPollerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Ancla del tour (v17.8): el paso «Datos y conexión» enfoca este bloque.
        KeyedSubtree(
          key: TourKeys.conexion,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _FilaSwitch(
                titulo: 'No consultar tasas automáticamente',
                sub: s.offlineMode
                    ? 'Encendido: la app no consulta ninguna API. Todo sale '
                          'de tu libro y tus tasas manuales.'
                    : 'Apagado: la app consulta las tasas según el intervalo '
                          'de abajo.',
                value: s.offlineMode,
                onChanged: (v) {
                  store.setOfflineMode(v);
                  if (v) {
                    poller.stopAuto(); // offline total: sin más consultas
                  } else {
                    poller.markActive(); // reanuda el ciclo ya
                    poller.refreshNow();
                  }
                },
              ),
              if (!s.offlineMode) ...[
                const SizedBox(height: 6),
                Text(
                  'Intervalo de consulta de tasas',
                  style: VeText.labelCaps(
                    11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final e in _intervalos.entries)
                      ChipTag(
                        e.value,
                        selected: s.pollMinutes == e.key,
                        onTap: () {
                          store.setPollMinutes(e.key);
                          poller.markActive(); // reprograma el ciclo
                        },
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 10),
        // SSE en vivo (17.7): fila plana con LED de estado honesto.
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: s.offlineMode ? null : () => _askSseUrl(context, store),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Tooltip(
                  message: s.sseUrl.isEmpty
                      ? 'Sin servidor configurado'
                      : (poller.sseConnected
                            ? 'Conectado en vivo'
                            : 'Sin conexión; sigue el ciclo normal'),
                  child: Semantics(
                    label: s.sseUrl.isEmpty
                        ? 'Estado: sin servidor configurado'
                        : (poller.sseConnected
                              ? 'Estado: conectado en vivo'
                              : 'Estado: sin conexión'),
                    child: Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: s.sseUrl.isEmpty
                            ? scheme.outlineVariant
                            : (poller.sseConnected
                                  ? VeColors.of(context).pos
                                  : VeColors.of(context).warn),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Actualización en vivo (opcional)',
                        style: TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        s.sseUrl.isEmpty
                            ? 'Apagado. Si tienes un servidor ValoraVE, pega '
                                  'su URL: las tasas llegan al instante.'
                            : '${s.sseUrl} · ${poller.sseConnected ? 'stream conectado' : 'sin conexión; el ciclo normal sigue'}',
                        style: TextStyle(
                          fontSize: 11,
                          height: 1.35,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Text(
                  s.sseUrl.isEmpty ? 'Añadir' : 'Editar',
                  style: const TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Las tasas se guardan en tu teléfono y siguen disponibles sin conexión.',
          style: TextStyle(
            fontSize: 11,
            height: 1.45,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  /// Diálogo de URL del servidor SSE (17.7): vacío = desactivar. El poller
  /// detecta el cambio de settings solo (listener del store).
  Future<void> _askSseUrl(BuildContext context, AppStore store) async {
    final ctrl = TextEditingController(text: store.settings.sseUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Servidor SSE en vivo'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ctrl,
              autofocus: true,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                hintText: 'https://tu-despliegue.valorave.app',
                labelText: 'URL base del despliegue web',
              ),
            ),
            const SizedBox(height: 10),
            const Text(
              'La app se suscribe a /api/rates/stream de ese servidor. Si falla '
              'o lo dejas vacío, el ciclo de consulta normal sigue igual.',
              style: TextStyle(fontSize: 11),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(null),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(ctrl.text.trim()),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    if (url != null) store.setSseUrl(url);
    // FIX 9P·Performance: el controller del diálogo se dispone al cerrar
    // (cada apertura de «Servidor SSE» dejaba uno vivo). La URL ya se leyó.
    ctrl.dispose();
  }
}
