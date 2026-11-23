/// ─── Ajustes (v27 · hub + subpantallas) ───────────────────────────────────
/// El módulo de Ajustes se reconstruye como un hub: seis grupos, una línea
/// por ajuste y el valor actual a la vista. Cada grupo abre su propia
/// pantalla (General · Tasas · Cuentas · Apariencia · Datos), así el móvil
/// no arrastra una lista interminable ni esconde funciones al final.
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

// v18.0: la versión visible vive en core/version.dart (fuente única — la
// usan las constancias PNG/PDF y los totales compartidos). Se re-exporta
// aquí para no romper a quien ya importaba SettingsScreen por ella.
export '../../core/version.dart' show kAppVersionVisible;

part 'settings_sections.dart';
part 'settings_alertas.dart';
part 'settings_system.dart';
part 'cuentas_pago_movil.dart';

/// Hub de Ajustes: grupos con una línea por ajuste y el valor actual.
class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    final theme = ref.watch(themeControllerProvider);
    final scheme = Theme.of(context).colorScheme;
    final country = CountryX.from(store.settings.country);

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Ajustes',
              style: VeText.displayNum(
                26,
                color: scheme.onSurface,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'La app, a tu manera.',
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            _SettingsGroup(
              title: 'General',
              items: [
                _SettingsTile(
                  icon: LucideIcons.globe2,
                  title: 'País y moneda',
                  value: country.label,
                  anchor: TourKeys.conexion,
                  onTap: () => context.push('/ajustes/general'),
                ),
                _SettingsTile(
                  icon: LucideIcons.hash,
                  title: 'Decimales',
                  value: '${store.settings.precision} decimales',
                  onTap: () => context.push('/ajustes/general'),
                ),
                _SettingsTile(
                  icon: LucideIcons.palette,
                  title: 'Apariencia',
                  value: switch (theme.mode) {
                    ThemeMode.light => 'Claro',
                    ThemeMode.dark => 'Grafito',
                    ThemeMode.system => 'Sistema',
                  },
                  onTap: () => context.push('/ajustes/apariencia'),
                ),
                _SettingsTile(
                  icon: LucideIcons.fingerprint,
                  title: 'Bloqueo biométrico',
                  value: store.settings.biometricLock ? 'Activado' : 'Apagado',
                  onTap: () => context.push('/ajustes/apariencia'),
                ),
              ],
            ),
            _SettingsGroup(
              title: 'Tasas',
              items: [
                _SettingsTile(
                  icon: LucideIcons.repeat2,
                  title: 'Fuentes y manuales',
                  value: 'BCV, paralelo, tuyas',
                  onTap: () => context.push('/ajustes/tasas'),
                ),
                _SettingsTile(
                  icon: LucideIcons.bellRing,
                  title: 'Alertas',
                  value: store.settings.spikeAlerts
                      ? 'Picos activos'
                      : 'Sin picos',
                  onTap: () => context.push('/ajustes/tasas'),
                ),
                _SettingsTile(
                  icon: LucideIcons.activity,
                  title: 'Diagnóstico de fuentes',
                  value: 'Probar regiones',
                  onTap: () => context.push('/ajustes/tasas'),
                ),
              ],
            ),
            _SettingsGroup(
              title: 'Pago móvil',
              items: [
                _SettingsTile(
                  icon: LucideIcons.landmark,
                  title: 'Cuentas de cobro',
                  value:
                      '${store.data.accounts.length} de ${AppStore.kMaxAccounts}',
                  onTap: () => context.push('/ajustes/cuentas'),
                ),
              ],
            ),
            _SettingsGroup(
              title: 'Datos',
              items: [
                _SettingsTile(
                  icon: LucideIcons.databaseBackup,
                  title: 'Respaldo',
                  value: 'Exportar o restaurar',
                  anchor: TourKeys.tutorial,
                  onTap: () => context.push('/ajustes/datos'),
                ),
                _SettingsTile(
                  icon: LucideIcons.scrollText,
                  title: 'Registros de la app',
                  value: 'Solo en tu teléfono',
                  onTap: () => context.push('/ajustes/datos'),
                ),
                _SettingsTile(
                  icon: LucideIcons.download,
                  title: 'Actualizaciones',
                  value: 'Canal de desarrollo',
                  onTap: () => context.push('/ajustes/datos'),
                ),
              ],
            ),
            _SettingsGroup(
              title: 'Acerca de',
              items: [
                _SettingsTile(
                  icon: LucideIcons.info,
                  title: 'ValoraVE',
                  value: kAppVersionVisible,
                  onTap: () => context.push('/ajustes/datos'),
                ),
                _SettingsTile(
                  icon: LucideIcons.gavel,
                  title: 'Privacidad y licencias',
                  value: 'Qué vive en tu teléfono',
                  onTap: () => context.push('/ajustes/datos'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _SettingsGroup extends ConsumerWidget {
  const _SettingsGroup({required this.title, required this.items});

  final String title;
  final List<_SettingsTile> items;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(2, 18, 2, 2),
          child: Text(
            title.toUpperCase(),
            style: VeText.labelCaps(10.5, color: scheme.onSurfaceVariant),
          ),
        ),
        for (final item in items)
          KeyedSubtree(
            key: item.anchor,
            child: InkWell(
              onTap: item.onTap,
              borderRadius: BorderRadius.circular(10),
              child: Container(
                padding: const EdgeInsets.symmetric(vertical: 11),
                decoration: BoxDecoration(
                  border: item == items.last
                      ? null
                      : Border(
                          bottom: BorderSide(
                            color: scheme.outlineVariant.withValues(
                              alpha: 0.55,
                            ),
                          ),
                        ),
                ),
                child: Row(
                  children: [
                    Icon(item.icon, size: 18, color: scheme.onSurfaceVariant),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            item.title,
                            style: const TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            item.value,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11.5,
                              color: scheme.onSurfaceVariant,
                            ),
                          ),
                        ],
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
          ),
      ],
    );
  }
}

class _SettingsTile {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.value,
    required this.onTap,
    this.anchor,
  });

  final IconData icon;
  final String title;
  final String value;
  final VoidCallback onTap;
  final Key? anchor;
}

/// Andamiaje de subpantalla: back, título, subtítulo y contenido. Una sola
/// piel para los cinco grupos de Ajustes.
class SettingsSubpage extends ConsumerWidget {
  const SettingsSubpage({
    super.key,
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: VeIconBtn(
                icon: LucideIcons.arrowLeft,
                label: 'Volver',
                size: 36,
                iconSize: 16,
                onTap: () =>
                    context.canPop() ? context.pop() : context.go('/ajustes'),
              ),
            ),
            Text(
              title,
              style: VeText.displayNum(
                26,
                color: scheme.onSurface,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              subtitle,
              style: TextStyle(fontSize: 12.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 4),
            child,
          ],
        ),
      ),
    );
  }
}

class SettingsGeneralPage extends ConsumerWidget {
  const SettingsGeneralPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    return SettingsSubpage(
      title: 'General',
      subtitle: 'País, precisión y cómo se conecta la app.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Pais(store: store),
          const SizedBox(height: 4),
          _Precision(store: store),
          const SizedBox(height: 4),
          _DatosConexion(store: store),
          const SizedBox(height: 4),
          const _AppWidgetsRow(),
        ],
      ),
    );
  }
}

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
                      fontSize: 13,
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

class SettingsTasasPage extends ConsumerWidget {
  const SettingsTasasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    return SettingsSubpage(
      title: 'Tasas',
      subtitle: 'Las fuentes que usa tu app, tus tasas y tus alertas.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Monedas(store: store),
          _Alertas(store: store),
          _Diagnostico(),
        ],
      ),
    );
  }
}

class SettingsCuentasPage extends ConsumerWidget {
  const SettingsCuentasPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SettingsSubpage(
      title: 'Cuentas y Pago Móvil',
      subtitle: 'Tus datos de cobro, listos para compartir.',
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [CuentasPagoMovil()],
      ),
    );
  }
}

class SettingsAparienciaPage extends ConsumerWidget {
  const SettingsAparienciaPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return const SettingsSubpage(
      title: 'Apariencia',
      subtitle: 'Claro, grafito o el tema del sistema.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [_Apariencia()],
      ),
    );
  }
}

class SettingsDatosPage extends ConsumerWidget {
  const SettingsDatosPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    return SettingsSubpage(
      title: 'Datos y acerca de',
      subtitle: 'Respaldo, registros, actualizaciones y tutorial.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Respaldo(store: store),
          _Registros(),
          _TutorialLegal(store: store),
        ],
      ),
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
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    subtitle: Text(
                      s.offlineMode
                          ? 'Encendido: la app no consulta ninguna API. Todo sale de tu libro y tus tasas manuales.'
                          : 'Apagado: la app consulta las tasas según el intervalo de abajo.',
                      style: TextStyle(
                        fontSize: 12,
                        height: 1.4,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Intervalo de consulta de tasas',
                    style: VeText.labelCaps(
                      9.5,
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
                        fontSize: 12,
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
                      fontSize: 11.5,
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
              style: TextStyle(fontSize: 11.5),
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
