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
import '../../data/store.dart';
import '../../services/alerts.dart';
import '../../services/notifications.dart';
import '../../services/sharing.dart';
import '../../state/app_state.dart';
import '../../widgets/ui.dart';

/// Versión visible de la app (la del marketing); el buildNumber real viene
/// de PackageInfo en la fila «Acerca de».
const String kAppVersionVisible = '17.1';

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
          _Personalizacion(store: store),
          _Monedas(store: store),
          _Apariencia(),
          _Alertas(store: store),
          _Respaldo(store: store),
          _TutorialLegal(store: store),
        ],
      ),
    );
  }
}

/// Ancla país: protagonista + foco 6 + orden subir/bajar/reset.
class _Pais extends StatelessWidget {
  const _Pais({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final country = CountryX.from(store.settings.country);
    final order = CurrencyX.focusOrder(store.settings.currencyOrder);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('País', index: 1),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Tablero configurado para ${country.label}',
                style: TextStyle(fontSize: 14.5, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            const SizedBox(height: 10),
            Wrap(spacing: 6, children: [
              for (final c in Country.values)
                ChipTag(c.label, selected: country == c, onTap: () => store.setCountry(c)),
            ]),
            const SizedBox(height: 12),
            Text('Orden del foco', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            for (int i = 0; i < order.length; i++)
              Row(children: [
                Flag(order[i], size: 16),
                const SizedBox(width: 8),
                Expanded(child: Text(order[i].label, style: const TextStyle(fontSize: 12.5))),
                IconButton(
                  icon: const Icon(Icons.arrow_upward, size: 15),
                  onPressed: i == 0 ? null : () => _move(context, order, i, i - 1),
                ),
                IconButton(
                  icon: const Icon(Icons.arrow_downward, size: 15),
                  onPressed: i == order.length - 1 ? null : () => _move(context, order, i, i + 1),
                ),
              ]),
            TextButton(
              onPressed: () => store.setSetting('currencyOrder', <String>[]),
              child: const Text('Restablecer orden'),
            ),
            // Espejo del Home: quitar el sueldo guardado (con confirmación).
            if (store.settings.effectiveSalary() != null)
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton.icon(
                  onPressed: () => _confirmQuitSalary(context),
                  icon: const Icon(Icons.payments_outlined, size: 16),
                  label: const Text('Quitar sueldo'),
                ),
              ),
          ]),
        ),
      ),
    ]);
  }

  /// Confirmación + setSetting('salary', null) — espejo del «Quitar sueldo»
  /// del Home (§9.1), aquí donde vive el país/foco.
  void _confirmQuitSalary(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar el sueldo?'),
        content: const Text('Se borra el sueldo guardado (monto, base/variable o rango). '
            'Podrás escribirlo de nuevo cuando quieras.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
            onPressed: () {
              store.setSetting('salary', null);
              Navigator.pop(ctx);
            },
            child: const Text('Quitar'),
          ),
        ],
      ),
    );
  }

  void _move(BuildContext context, List<Currency> order, int from, int to) {
    final codes = order.map((c) => c.code).toList();
    final item = codes.removeAt(from);
    codes.insert(to, item);
    store.setSetting('currencyOrder', codes);
  }
}

/// Ancla personalización: ticker modo/tamaño/velocidad con preview.
class _Personalizacion extends StatelessWidget {
  const _Personalizacion({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Personalización', index: 2),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('Cinta de cotizaciones (solo Inicio)',
                style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700, color: scheme.onSurface)),
            const SizedBox(height: 8),
            Text('Modo', style: VeText.labelCaps(9, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            SegmentedChips<String>(
              options: const ['featured', 'focus', 'off'],
              value: store.settings.tickerMode,
              onChanged: (v) => store.setSetting('tickerMode', v),
              labelOf: (v) => switch (v) { 'focus' => 'Divisas clave', 'off' => 'Apagada', _ => 'Mi país' },
            ),
            const SizedBox(height: 8),
            Text('Tamaño', style: VeText.labelCaps(9, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            SegmentedChips<String>(
              options: const ['compact', 'normal', 'large'],
              value: store.settings.tickerSize,
              onChanged: (v) => store.setSetting('tickerSize', v),
              labelOf: (v) => switch (v) { 'compact' => 'Compacta', 'large' => 'Grande', _ => 'Normal' },
            ),
            const SizedBox(height: 8),
            Text('Velocidad', style: VeText.labelCaps(9, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            SegmentedChips<int>(
              options: const [90, 120, 180],
              value: store.settings.tickerSpeed,
              onChanged: (v) => store.setSetting('tickerSpeed', v),
              labelOf: (v) => v == 90 ? 'Lenta' : (v == 180 ? 'Rápida' : 'Normal'),
            ),
            const SizedBox(height: 10),
            // Preview estático del modo elegido.
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                switch (store.settings.tickerMode) {
                  'off' => 'Cinta apagada.',
                  'focus' => 'Vista: tus divisas del foco en el orden elegido (1 USD = X).',
                  _ => 'Vista: fuentes protagonistas de ${CountryX.from(store.settings.country).label} + euro.',
                },
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
              ),
            ),
          ]),
        ),
      ),
    ]);
  }
}

/// Ancla monedas: fuente global + por módulo + manuales + salud.
class _Monedas extends StatelessWidget {
  const _Monedas({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ctx = store.contextOf();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Monedas y tasas', index: 3),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            for (final c in CurrencyX.focusMain) ...[
              Text(c.label, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700)),
              const SizedBox(height: 6),
              SourcePills(
                sources: RateSource.sourcesFor(c).map((s) => s.id).toList(),
                value: store.sourceFor(c),
                onChanged: (id) => store.setRateSource(c, id),
              ),
              const SizedBox(height: 4),
              if (ctx.rate(store.sourceFor(c)) > 0)
                Text('Activa: ${fmtRate(ctx.rate(store.sourceFor(c)))}',
                    style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              const SizedBox(height: 10),
            ],
            Text('Fuente por módulo', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 6),
            for (final module in RateModule.values)
              _ModuleSource(store: store, module: module),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Refresco automático de tasas', style: TextStyle(fontSize: 13)),
              subtitle: const Text('Consulta el tablero en segundo plano al abrir la app',
                  style: TextStyle(fontSize: 11)),
              value: store.settings.autoRefresh,
              onChanged: (v) => store.setSetting('autoRefresh', v),
            ),
            const SizedBox(height: 8),
            Text('Tasas manuales (offline)', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 4),
            const _ManualRates(),
          ]),
        ),
      ),
    ]);
  }
}

class _ModuleSource extends StatelessWidget {
  const _ModuleSource({required this.store, required this.module});
  final AppStore store;
  final RateModule module;

  @override
  Widget build(BuildContext context) {
    final label = switch (module) {
      RateModule.converter => 'Conversor',
      RateModule.calculator => 'Lista',
      RateModule.finance => 'Finanzas',
    };
    final current = store.settings.rateSourcesByModule[moduleRateKey(module.code, 'VES')];
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(children: [
        Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5))),
        Text(current == null ? 'Global' : (RateSource.of(current)?.label ?? current),
            style: TextStyle(fontSize: 12, color: Theme.of(context).colorScheme.primary)),
        PopupMenuButton<String>(
          icon: const Icon(Icons.more_vert, size: 16),
          onSelected: (v) => store.setModuleRateSource(
              module, Currency.ves, v == 'global' ? null : v),
          itemBuilder: (_) => [
            const PopupMenuItem(value: 'global', child: Text('Global')),
            for (final s in RateSource.sourcesFor(Currency.ves))
              PopupMenuItem(value: s.id, child: Text(s.label)),
          ],
        ),
      ]),
    );
  }
}

/// Editor de tasa manual por fuente + banner de salud.
class _ManualRates extends StatelessWidget {
  const _ManualRates();

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    return Column(children: [
      for (final id in ['ves-manual', 'cop-manual', 'brl-manual', 'mxn-manual'])
        _ManualField(store: store, sourceId: id),
    ]);
  }
}

class _ManualField extends StatefulWidget {
  const _ManualField({required this.store, required this.sourceId});
  final AppStore store;
  final String sourceId;

  @override
  State<_ManualField> createState() => _ManualFieldState();
}

class _ManualFieldState extends State<_ManualField> {
  late final TextEditingController _ctrl =
      TextEditingController(text: widget.store.data.manualRates[widget.sourceId] == null
          ? ''
          : '${widget.store.data.manualRates[widget.sourceId]}');

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = RateSource.of(widget.sourceId)!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(children: [
        SourceDot(SourceCategory.manual),
        const SizedBox(width: 8),
        Expanded(child: Text('Tasa manual ${s.currency.code}', style: const TextStyle(fontSize: 12.5))),
        SizedBox(
          width: 120,
          child: TextField(
            controller: _ctrl,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(hintText: '${s.base.code}→${s.quote.code}'),
          ),
        ),
        TextButton(
          onPressed: () {
            final v = parseLocaleNum(_ctrl.text) ?? 0;
            widget.store.setManualRate(widget.sourceId, v);
          },
          child: const Text('Guardar'),
        ),
      ]),
    );
  }
}

/// Ancla apariencia.
class _Apariencia extends StatelessWidget {
  const _Apariencia();

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Apariencia', index: 4),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: SegmentedChips<ThemeMode>(
            options: const [ThemeMode.light, ThemeMode.dark, ThemeMode.system],
            value: theme.mode,
            onChanged: (v) => theme.setMode(v, context.read<SharedPreferences>()),
            labelOf: (v) => switch (v) { ThemeMode.light => 'Claro', ThemeMode.dark => 'Grafito', _ => 'Sistema' },
          ),
        ),
      ),
    ]);
  }
}

/// Ancla alertas: permiso + picos + metas de tasa + brecha + daily.
class _Alertas extends StatefulWidget {
  const _Alertas({required this.store});
  final AppStore store;

  @override
  State<_Alertas> createState() => _AlertasState();
}

class _AlertasState extends State<_Alertas> {
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final notifs = context.read<NotificationsService>();
    final ok = await notifs.areEnabled();
    if (mounted) setState(() => _granted = ok);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final alerts = context.read<AlertEngine>();
    final notifs = context.read<NotificationsService>();
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Alertas', index: 5),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text('Permiso de notificaciones',
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ),
              Stamp(_granted ? 'concedido' : 'sin permiso',
                  color: _granted ? VeColors.of(context).pos : VeColors.of(context).warn),
              TextButton(
                onPressed: () async {
                  await notifs.requestPermission();
                  _checkPermission();
                },
                child: const Text('Activar'),
              ),
            ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Picos de tasa', style: TextStyle(fontSize: 13)),
              subtitle: Text('Vigila BCV y paralelo; cooldown 30 min por fuente', style: const TextStyle(fontSize: 11)),
              value: store.settings.spikeAlerts,
              onChanged: (v) => store.setSetting('spikeAlerts', v),
            ),
            if (store.settings.spikeAlerts)
              Wrap(spacing: 6, children: [
                for (final e in spikeSensitivities.entries)
                  ChipTag('${e.key} (${e.value} %)',
                      selected: store.settings.spikeThreshold == e.value,
                      onTap: () => store.setSetting('spikeThreshold', e.value)),
              ]),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Meta de tasa BCV', style: TextStyle(fontSize: 13)),
              subtitle: Text(store.settings.targetBcv == null
                  ? 'Apagada — avisa una vez al cruzar, rearma al bajar'
                  : 'Meta: ${fmtRate(store.settings.targetBcv!)} Bs/USD',
              style: const TextStyle(fontSize: 11)),
              value: store.settings.targetBcv != null,
              onChanged: (v) async {
                if (!v) {
                  store.setSetting('rateTargetAlerts.bcv', null);
                  return;
                }
                final ctrl = TextEditingController();
                final value = await _askValue(context, 'Meta BCV (Bs por USD)', ctrl);
                if (value != null) store.setSetting('rateTargetAlerts.bcv', value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Meta de tasa paralelo', style: TextStyle(fontSize: 13)),
              value: store.settings.targetParallel != null,
              onChanged: (v) async {
                if (!v) {
                  store.setSetting('rateTargetAlerts.parallel', null);
                  return;
                }
                final ctrl = TextEditingController();
                final value = await _askValue(context, 'Meta paralelo (Bs por USD)', ctrl);
                if (value != null) store.setSetting('rateTargetAlerts.parallel', value);
              },
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Recordatorio diario de precios', style: TextStyle(fontSize: 13)),
              subtitle: Text(alerts.reminderEnabled
                  ? 'Avisa a las ${alerts.reminderHour}:00 (con la app abierta o cerrada, ±1 h)'
                  : 'Un aviso al día para registrar tus precios',
                  style: const TextStyle(fontSize: 11)),
              value: alerts.reminderEnabled,
              onChanged: (v) {
                alerts.setReminderEnabled(v);
                setState(() {});
              },
            ),
            if (alerts.reminderEnabled)
              Wrap(spacing: 6, children: [
                for (final h in const [7, 8, 9, 12, 19, 21])
                  ChipTag('$h:00',
                      selected: alerts.reminderHour == h,
                      onTap: () {
                        alerts.setReminderHour(h);
                        setState(() {});
                      }),
              ]),
            Row(children: [
              Expanded(
                child: Text('Brecha BCV↔paralelo > ${fmtNum(alerts.gapThreshold, decimals: 0)} %',
                    style: const TextStyle(fontSize: 12.5)),
              ),
              Slider(
                value: alerts.gapThreshold,
                min: 5,
                max: 50,
                divisions: 9,
                label: '${alerts.gapThreshold.toStringAsFixed(0)} %',
                onChanged: (v) {
                  alerts.setThreshold('gap', v);
                  setState(() {});
                },
              ),
            ]),
            Row(children: [
              Expanded(
                child: Text('Cambio diario > ${fmtNum(alerts.dailyThreshold, decimals: 0)} %',
                    style: const TextStyle(fontSize: 12.5)),
              ),
              Slider(
                value: alerts.dailyThreshold,
                min: 1,
                max: 15,
                divisions: 14,
                label: '${alerts.dailyThreshold.toStringAsFixed(0)} %',
                onChanged: (v) {
                  alerts.setThreshold('daily', v);
                  setState(() {});
                },
              ),
            ]),
            TextButton.icon(
              onPressed: () {
                store.pushNotification(kind: NotifKind.test, title: 'Aviso de prueba',
                    body: 'Si lo ves, el centro de notificaciones está vivo.');
              },
              icon: const Icon(Icons.science_outlined, size: 15),
              label: const Text('Probar aviso'),
            ),
            Text('El permiso se gestiona aquí (única fuente, §9.8): '
                    'POST_NOTIFICATIONS en API 33+.',
                style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant)),
          ]),
        ),
      ),
    ]);
  }

  Future<double?> _askValue(BuildContext context, String title, TextEditingController ctrl) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(controller: ctrl, keyboardType: const TextInputType.numberWithOptions(decimal: true)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Fijar')),
        ],
      ),
    );
    if (ok != true) return null;
    return parseLocaleNum(ctrl.text);
  }
}

/// Ancla respaldo: export/import (replace|merge) + zona peligro.
class _Respaldo extends StatelessWidget {
  const _Respaldo({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Respaldo', index: 6),
      Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                icon: const Icon(Icons.ios_share, size: 16),
                label: const Text('Exportar respaldo JSON'),
                onPressed: () => showShareFile(
                    context,
                    'backup-valorave-${SnapshotPoint.dayKey(DateTime.now())}.json',
                    exportBackupJson(store.data)),
              ),
            ),
            const SizedBox(height: 8),
            Row(children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _import(context, merge: false),
                  child: const Text('Reemplazar', style: TextStyle(fontSize: 12.5)),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  onPressed: () => _import(context, merge: true),
                  child: const Text('Fusionar', style: TextStyle(fontSize: 12.5)),
                ),
              ),
            ]),
            const SizedBox(height: 6),
            Text('Fusionar une por id y no toca tu carrito ni tus ajustes. '
                    'Reemplazar conserva el tablero vivo y el resto entra del archivo.',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
            const Divider(height: 24),
            Text('Zona peligro', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: VeColors.of(context).neg)),
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(foregroundColor: VeColors.of(context).neg),
                icon: const Icon(Icons.delete_forever, size: 16),
                label: const Text('Borrar todos los datos (conserva tablero)'),
                onPressed: () {
                  showDialog<void>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('¿Borrar todo?'),
                      content: const Text('Productos, compras, movimientos, lista y plantillas se '
                          'eliminan. El tablero de tasas vivo se conserva.'),
                      actions: [
                        TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
                        FilledButton(
                          style: FilledButton.styleFrom(backgroundColor: VeColors.of(context).neg),
                          onPressed: () {
                            store.resetAll();
                            Navigator.pop(ctx);
                          },
                          child: const Text('Borrar todo'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
          ]),
        ),
      ),
    ]);
  }

  Future<void> _import(BuildContext context, {required bool merge}) async {
    final picked = await FilePicker.pickFiles(type: FileType.custom, allowedExtensions: ['json']);
    if (picked.isEmpty) return;
    final raw = await picked.single.readAsBytes().then((b) => utf8.decode(b, allowMalformed: true));
    final result = importBackup(store.data, raw, merge: merge);
    if (!result.ok) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(result.error ?? 'Archivo respaldo inválido'),
            behavior: SnackBarBehavior.floating));
      }
      return;
    }
    if (merge) {
      final r = mergeBackupData(store.data, AppData.fromJson(
          Map<String, dynamic>.from((jsonDecode(raw) as Map)['data'] as Map)));
      store.replaceAll(r.data);
      if (context.mounted) {
        final c = r.counts;
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Fusión: ${c.products} productos nuevos, '
                '${c.records} registros, ${c.transactions} movimientos, ${c.purchases} compras'),
            behavior: SnackBarBehavior.floating));
      }
    } else {
      final incoming = AppData.fromJson(Map<String, dynamic>.from((jsonDecode(raw) as Map)['data'] as Map));
      final replaced = AppData(
        version: kDataVersion,
        board: store.board, // tablero vivo
        rateSource: {
          for (final e in incoming.rateSource.entries)
            if (RateSource.of(e.value) != null) e.key: e.value,
        },
        manualRates: incoming.manualRates,
        converter: incoming.converter,
        products: incoming.products,
        transactions: incoming.transactions,
        cart: incoming.cart,
        purchases: incoming.purchases,
        budget: incoming.budget,
        basket: incoming.basket,
        stores: incoming.stores,
        templates: incoming.templates,
        settings: incoming.settings,
      );
      store.replaceAll(replaced);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text('Reemplazo: ${incoming.products.length} productos, '
                '${incoming.purchases.length} compras'),
            behavior: SnackBarBehavior.floating));
      }
    }
  }
}

/// Ancla tutorial + legal + versión.
class _TutorialLegal extends StatelessWidget {
  const _TutorialLegal({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Tutorial y legal', index: 7),
      Card(
        child: Column(children: [
          ListTile(
            leading: Icon(Icons.school_outlined, color: scheme.primary),
            title: const Text('Volver a ver el tutorial', style: TextStyle(fontSize: 13.5)),
            onTap: () {
              store.reopenTutorial();
              context.go('/bienvenida');
            },
          ),
          FutureBuilder<PackageInfo>(
            future: PackageInfo.fromPlatform(),
            builder: (context, snap) => ListTile(
              leading: const Icon(Icons.info_outline),
              title: const Text('Acerca de ValoraVE', style: TextStyle(fontSize: 13.5)),
              subtitle: Text(
                  'ValoraVE $kAppVersionVisible · build ${snap.data?.buildNumber} · es-VE · offline-first',
                  style: const TextStyle(fontSize: 11.5)),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.gavel_outlined),
            title: const Text('Licencias y privacidad', style: TextStyle(fontSize: 13.5)),
            onTap: () => context.push('/legal'),
          ),
        ]),
      ),
    ]);
  }
}
