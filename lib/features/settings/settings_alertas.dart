/// ─── Ajustes · alertas (parte de settings_screen.dart) ─────────────────────
/// Permiso de notificaciones + picos + metas de tasa + brecha + cambio
/// diario + recordatorio + «Probar aviso» (17.7 price_targets vía ficha).
/// Parte del archivo principal: comparte privacidad e imports.
part of 'settings_screen.dart';

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
      SectionTitle('Alertas'),
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
            Row(children: [
              Expanded(
                child: Text('Subida de producto > ${fmtNum(alerts.productRiseThreshold, decimals: 0)} %',
                    style: const TextStyle(fontSize: 12.5)),
              ),
              Slider(
                value: alerts.productRiseThreshold,
                min: 5,
                max: 50,
                divisions: 9,
                label: '${alerts.productRiseThreshold.toStringAsFixed(0)} %',
                onChanged: (v) {
                  alerts.setThreshold('product', v);
                  setState(() {});
                },
              ),
            ]),
            TextButton.icon(
              // Prueba REAL de la tubería Android: pide POST_NOTIFICATIONS si
              // falta y dispara por flutter_local_notifications (canal
              // General), además de escribir en el centro interno.
              onPressed: () async {
                final notifs = context.read<NotificationsService>();
                var granted = await notifs.areEnabled();
                if (!granted) granted = await notifs.requestPermission();
                final String body = granted
                    ? 'Si lees esto en la bandeja del sistema, los canales '
                        'funcionan: picos, metas, brecha y recordatorio usan '
                        'la misma tubería.'
                    : 'Sin permiso POST_NOTIFICATIONS el aviso solo aparece '
                        'aquí. Actívalo desde el sistema o reintenta.';
                await notifs.show(
                  channelId: 'default',
                  title: 'Aviso de prueba',
                  body: body,
                  tag: 'valorave-test',
                );
                store.pushNotification(kind: NotifKind.test, title: 'Aviso de prueba', body: body);
                if (context.mounted) {
                  showToast(context,
                      granted
                          ? 'Notificación enviada a la bandeja del sistema'
                          : 'Permiso de notificaciones denegado',
                      kind: granted ? ToastKind.ok : ToastKind.warn);
                }
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

