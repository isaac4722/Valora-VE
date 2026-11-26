/// ─── Ajustes (v30 · H-42 · UNA pantalla por secciones) ─────────────────────/// Ajustes en UNA pantalla por secciones (v30 · H-42, cero reutilización
/// del hub de fichas): Cuentas y cobro (primero) · Tasas y fuentes ·
/// General (país · decimales · conexión · widgets) · Apariencia · Datos y
/// acerca de. Las subpantallas v27 murieron: `/ajustes/general|tasas|
/// apariencia|datos` REDIRIGEN aquí y solo `/ajustes/cuentas` sobrevive
/// (deep link del Conversor e Inicio — aterriza en la sección 1).
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

/// Ajustes en UNA pantalla (v30 · H-42): las cinco secciones viven en la
/// misma hoja — sin hub de fichas ni subpantallas.
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
            const VeEyebrow(child: Text('CUENTAS Y COBRO')),
            const CuentasPagoMovil(),
            // ── 2 · Tasas y fuentes: monedas por módulo, manuales, propias,
            // alertas y diagnóstico.
            const VeEyebrow(child: Text('TASAS Y FUENTES')),
            _Monedas(store: store),
            _Alertas(store: store),
            const _Diagnostico(),
            // ── 3 · General: país · decimales · conexión · widgets.
            const VeEyebrow(child: Text('GENERAL')),
            _Pais(store: store),
            _Precision(store: store),
            _DatosConexion(store: store),
            const _AppWidgetsRow(),
            // ── 4 · Apariencia: tema, Material You, biometría.
            const VeEyebrow(child: Text('APARIENCIA')),
            const _Apariencia(),
            // ── 5 · Datos y acerca de: respaldo, registros, tutorial/legal.
            const VeEyebrow(child: Text('DATOS Y ACERCA DE')),
            _Respaldo(store: store),
            const _Registros(),
            _TutorialLegal(store: store),
          ],
        ),
      ),
    );
  }
}

/// Precisión decimal (v27 · REA CalculaYa): 2, 3 o 4 decimales. La API
/// Precisión decimal (v27 · REA CalculaYa): 2, 3 o 4 decimales. La API
/// publica 4; el usuario elige cuántos ver en tasas y resultados.
class _Precision extends ConsumerWidget {
  const _Precision({required this.store});

  final AppStore store;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VeEyebrow(
          hint: 'Las tasas llegan con cuatro decimales. Tú eliges cuántos ver.',
          child: Text('DECIMALES'),
        ),
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
        const VeEyebrow(
          hint:
              'Tasa BCV, paralelo y brecha en la pantalla de inicio de Android.',
          child: Text('WIDGETS DE ANDROID'),
        ),
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () => showAppWidgetGallery(context),
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 8),
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
                    'Añadir un widget',
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
/// Sección de Ajustes v25 «HOJA»: PLANA — solo el ancestro Material
/// transparente que exigen los ListTiles/SwitchListTiles Material de las
/// secciones; la separación entre secciones la pone el aire, no una caja.
class _VeSettingsCard extends ConsumerWidget {
  const _VeSettingsCard({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Material(type: MaterialType.transparency, child: child);
  }
}

/// Datos y conexión (v17.2): modo offline total + cada cuánto se consultan
/// las APIs. Todo vive en Settings (store) y el poller lo lee en vivo.
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
    final poller = ref.read(ratesPollerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const VeEyebrow(child: Text('DATOS Y CONEXIÓN')),
        // Ancla del tour (v17.8): el paso «Datos y conexión» enfoca este card.
        KeyedSubtree(
          key: TourKeys.conexion,
          child: _VeSettingsCard(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
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
                    title: const Text(
                      'No consultar tasas automáticamente',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      s.offlineMode
                          ? 'Encendido: la app no consulta ninguna API. Todo sale de tu libro y tus tasas manuales.'
                          : 'Apagado: la app consulta las tasas según el intervalo de abajo.',
                      style: TextStyle(
                        fontSize: 13.5,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
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
                          selected: !s.offlineMode && s.pollMinutes == e.key,
                          onTap: s.offlineMode
                              ? null
                              : () {
                                  store.setPollMinutes(e.key);
                                  poller.markActive(); // reprograma el ciclo
                                },
                        ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  // SSE en vivo (17.7): push opcional del despliegue web ValoraVE.
                  // El polling SIEMPRE sigue como latido — esto lo acelera.
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    dense: true,
                    // v21.2: el LED de estado ya no es un punto mudo —
                    // tooltip y etiqueta semántica según su color real.
                    leading: Tooltip(
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
                          margin: const EdgeInsets.only(top: 4),
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
                    title: const Text(
                      'Actualización en vivo (opcional)',
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    subtitle: Text(
                      s.sseUrl.isEmpty
                          ? 'Apagado. Si tienes un servidor ValoraVE, pega su URL: las tasas llegan al instante.'
                          : '${s.sseUrl} · ${poller.sseConnected ? 'stream conectado' : 'sin conexión; el ciclo normal sigue'}',
                      style: TextStyle(
                        fontSize: 11,
                        height: 1.35,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    trailing: Text(
                      s.sseUrl.isEmpty ? 'Añadir' : 'Editar',
                      style: const TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    onTap: s.offlineMode
                        ? null
                        : () => _askSseUrl(context, store),
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
              ),
            ),
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
