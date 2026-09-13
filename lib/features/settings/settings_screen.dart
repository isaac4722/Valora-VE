/// ─── Ajustes (§9.8 · 8 anclas) ──────────────────────────────────────────────
/// país · personalización (ticker 3×3×3) · monedas y tasas (por módulo +
/// manuales + salud) · apariencia (light/dark/system) · alertas (spikes,
/// metas, brecha, daily, reminder, permiso) · respaldo (export/import
/// replace+merge/resetAll conservando tablero) · tutorial · legal.
library;

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:go_router/go_router.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/backup.dart';
import '../../data/board.dart';
import '../../data/store.dart';
import '../../services/alerts.dart';
import '../../services/biometric.dart';
import '../../services/notifications.dart';
import '../../services/sharing.dart';
import '../../state/app_state.dart';
import '../../widgets/app_tour.dart';
import '../../widgets/ui.dart';

part 'settings_sections.dart';
part 'settings_alertas.dart';
part 'settings_system.dart';

/// Versión visible de la app (la del marketing); el buildNumber real viene
/// de PackageInfo en la fila «Acerca de».
const String kAppVersionVisible = '17.8';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const PageHeader('Ajustes', hint: 'Todo lo que la app decide contigo'),
          _Pais(store: store),
          _DatosConexion(store: store),
          _Personalizacion(store: store),
          _Monedas(store: store),
          _Diagnostico(),
          _Apariencia(),
          _Alertas(store: store),
          _Respaldo(store: store),
          _TutorialLegal(store: store),
        ],
      ),
    );
  }
}

/// Datos y conexión (v17.2): modo offline total + cada cuánto se consultan
/// las APIs. Todo vive en Settings (store) y el poller lo lee en vivo.
class _DatosConexion extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = store.settings;
    final poller = context.read<RatesPoller>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Datos y conexión'),
      // Ancla del tour (v17.8): el paso «Modo offline total» enfoca este card.
      KeyedSubtree(
        key: TourKeys.conexion,
        child: Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
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
              title: const Text('Modo offline total',
                  style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800)),
              subtitle: Text(
                s.offlineMode
                    ? 'Activo: la app NO consulta ninguna API. Todo se lee de tu libro local y tus tasas manuales.'
                    : 'Desactivado: la app consulta las APIs de tasas según el intervalo de abajo.',
                style: TextStyle(fontSize: 12, height: 1.4, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 6),
            Text('Intervalo de consulta de tasas',
                style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 8),
            Wrap(spacing: 6, runSpacing: 6, children: [
              for (final e in _intervalos.entries)
                ChipTag(e.value,
                    selected: !s.offlineMode && s.pollMinutes == e.key,
                    onTap: s.offlineMode
                        ? null
                        : () {
                            store.setPollMinutes(e.key);
                            poller.markActive(); // reprograma el ciclo
                          }),
            ]),
            const SizedBox(height: 10),
            // SSE en vivo (17.7): push opcional del despliegue web ValoraVE.
            // El polling SIEMPRE sigue como latido — esto lo acelera.
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Container(
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
              title: const Text('SSE en vivo (opcional)',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              subtitle: Text(
                  s.sseUrl.isEmpty
                      ? 'Desactivado. Si despliegas el servidor web ValoraVE, pega su URL: el tablero llega por push sin esperar el intervalo'
                      : '${s.sseUrl} · ${poller.sseConnected ? 'stream conectado' : 'sin conexión — el ciclo normal sigue'}',
                  style: TextStyle(fontSize: 11, height: 1.35, color: scheme.onSurfaceVariant)),
              trailing: Text(s.sseUrl.isEmpty ? 'Añadir' : 'Editar',
                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              onTap: s.offlineMode ? null : () => _askSseUrl(context, store),
            ),
            const SizedBox(height: 4),
            Text(
              'Las tasas descargadas se guardan en tu teléfono (una fila por fecha y fuente, sin duplicados) y siguen disponibles sin conexión.',
              style: TextStyle(fontSize: 11.5, height: 1.45, color: scheme.onSurfaceVariant),
            ),
          ]),
        ),
      ),
      ),
    ]);
  }

  /// Diálogo de URL del servidor SSE (17.7): vacío = desactivar. El poller
  /// detecta el cambio de settings solo (listener del store).
  Future<void> _askSseUrl(BuildContext context, AppStore store) async {
    final ctrl = TextEditingController(text: store.settings.sseUrl);
    final url = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Servidor SSE en vivo'),
        content: Column(mainAxisSize: MainAxisSize.min, children: [
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
              style: TextStyle(fontSize: 11.5)),
        ]),
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
  }
}

