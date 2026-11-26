/// ─── Ajustes · alertas (parte de settings_screen.dart) ─────────────────────
/// Permiso de notificaciones + picos + metas de tasa + brecha + cambio
/// diario + recordatorio + «Probar aviso» (17.7 price_targets vía ficha).
/// Parte del archivo principal: comparte privacidad e imports.
/// v32: GUI plana — switches del kit, botones del kit, sin caja.
part of 'settings_screen.dart';

/// Ancla alertas: permiso + picos + metas de tasa + brecha + daily.
class _Alertas extends ConsumerStatefulWidget {
  const _Alertas({required this.store});
  final AppStore store;

  @override
  ConsumerState<_Alertas> createState() => _AlertasState();
}

class _AlertasState extends ConsumerState<_Alertas> {
  bool _granted = false;

  @override
  void initState() {
    super.initState();
    _checkPermission();
  }

  Future<void> _checkPermission() async {
    final notifs = ref.read(notificationsProvider);
    final ok = await notifs.areEnabled();
    if (mounted) setState(() => _granted = ok);
  }

  @override
  Widget build(BuildContext context) {
    final store = widget.store;
    final alerts = ref.watch(alertsProvider);
    final notifs = ref.read(notificationsProvider);
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // Permiso: fila plana con sello de estado y acción del kit.
        Row(
          children: [
            Expanded(
              child: Text(
                'Permiso de notificaciones',
                style: const TextStyle(
                  fontSize: 13.5,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Stamp(
              _granted ? 'concedido' : 'sin permiso',
              color: _granted
                  ? VeColors.of(context).pos
                  : VeColors.of(context).warn,
            ),
            const SizedBox(width: 8),
            GhostButton(
              'Activar',
              onPressed: () async {
                await notifs.requestPermission();
                _checkPermission();
              },
            ),
          ],
        ),
        _FilaSwitch(
          titulo: 'Picos de tasa',
          sub: 'Avisa cuando BCV o paralelo se muevan fuerte. 30 min entre '
              'avisos.',
          value: store.settings.spikeAlerts,
          onChanged: (v) => store.setSetting('spikeAlerts', v),
        ),
        if (store.settings.spikeAlerts)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              children: [
                for (final e in spikeSensitivities.entries)
                  ChipTag(
                    '${e.key} (${e.value} %)',
                    selected: store.settings.spikeThreshold == e.value,
                    onTap: () =>
                        store.setSetting('spikeThreshold', e.value),
                  ),
              ],
            ),
          ),
        _FilaSwitch(
          titulo: 'Meta de tasa BCV',
          sub: store.settings.targetBcv == null
              ? 'Apagada. Avisa una vez al cruzar el precio.'
              : 'Meta: ${fmtRate(store.settings.targetBcv!)} Bs/USD',
          value: store.settings.targetBcv != null,
          onChanged: (v) async {
            if (!v) {
              store.setSetting('rateTargetAlerts.bcv', null);
              setState(() {});
              return;
            }
            final ctrl = TextEditingController();
            final value = await _askValue(
              context,
              'Meta BCV (Bs por USD)',
              ctrl,
            );
            if (value != null) {
              store.setSetting('rateTargetAlerts.bcv', value);
            }
            if (mounted) setState(() {});
          },
        ),
        _FilaSwitch(
          titulo: 'Meta de tasa paralelo',
          sub: store.settings.targetParallel == null
              ? 'Apagada. Avisa una vez al cruzar el precio.'
              : 'Meta: ${fmtRate(store.settings.targetParallel!)} Bs/USD',
          value: store.settings.targetParallel != null,
          onChanged: (v) async {
            if (!v) {
              store.setSetting('rateTargetAlerts.parallel', null);
              setState(() {});
              return;
            }
            final ctrl = TextEditingController();
            final value = await _askValue(
              context,
              'Meta paralelo (Bs por USD)',
              ctrl,
            );
            if (value != null) {
              store.setSetting('rateTargetAlerts.parallel', value);
            }
            if (mounted) setState(() {});
          },
        ),
        _FilaSwitch(
          titulo: 'Recordatorio diario de precios',
          sub: alerts.reminderEnabled
              ? 'Avisa a las ${alerts.reminderHour}:00 (con la app abierta o '
                    'cerrada, ±1 h)'
              : 'Un aviso al día para que registres tus precios.',
          value: alerts.reminderEnabled,
          onChanged: (v) {
            alerts.setReminderEnabled(v);
            setState(() {});
          },
        ),
        if (alerts.reminderEnabled)
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Wrap(
              spacing: 6,
              children: [
                for (final h in const [7, 8, 9, 12, 19, 21])
                  ChipTag(
                    '$h:00',
                    selected: alerts.reminderHour == h,
                    onTap: () {
                      alerts.setReminderHour(h);
                      setState(() {});
                    },
                  ),
              ],
            ),
          ),
        // Umbrales: fila de rótulo + slider a todo lo ancho (v32: el
        // slider respira en su propia fila, el % se lee completo).
        _UmbralRow(
          titulo: 'Brecha BCV↔paralelo',
          valor: alerts.gapThreshold,
          min: 5,
          max: 50,
          divisiones: 9,
          onChanged: (v) {
            alerts.setThreshold('gap', v);
            setState(() {});
          },
        ),
        _UmbralRow(
          titulo: 'Cambio diario',
          valor: alerts.dailyThreshold,
          min: 1,
          max: 15,
          divisiones: 14,
          onChanged: (v) {
            alerts.setThreshold('daily', v);
            setState(() {});
          },
        ),
        _UmbralRow(
          titulo: 'Subida de producto',
          valor: alerts.productRiseThreshold,
          min: 5,
          max: 50,
          divisiones: 9,
          onChanged: (v) {
            alerts.setThreshold('product', v);
            setState(() {});
          },
        ),
        const SizedBox(height: 6),
        GhostButton(
          // Prueba REAL de la tubería Android: pide POST_NOTIFICATIONS si
          // falta y dispara por flutter_local_notifications (canal
          // General), además de escribir en el centro interno.
          'Probar aviso',
          icon: Icons.science_outlined,
          onPressed: () async {
            final notifs2 = ref.read(notificationsProvider);
            var granted = await notifs2.areEnabled();
            if (!granted) granted = await notifs2.requestPermission();
            final String body = granted
                ? 'Si lees esto en la bandeja del sistema, los canales '
                      'funcionan: picos, metas, brecha y recordatorio usan '
                      'la misma tubería.'
                : 'Sin permiso POST_NOTIFICATIONS el aviso solo aparece '
                      'aquí. Actívalo desde el sistema o reintenta.';
            await notifs2.show(
              channelId: 'default',
              title: 'Aviso de prueba',
              body: body,
              tag: 'valorave-test',
            );
            store.pushNotification(
              kind: NotifKind.test,
              title: 'Aviso de prueba',
              body: body,
            );
            if (context.mounted) {
              showToast(
                context,
                granted
                    ? 'Notificación enviada a la bandeja del sistema'
                    : 'Permiso de notificaciones denegado',
                kind: granted ? ToastKind.ok : ToastKind.warn,
              );
            }
          },
        ),
        const SizedBox(height: 6),
        Text(
          'El permiso de notificaciones se gestiona aquí.',
          style: TextStyle(
            fontSize: 11,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  Future<double?> _askValue(
    BuildContext context,
    String title,
    TextEditingController ctrl,
  ) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: ctrl,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Fijar'),
          ),
        ],
      ),
    );
    if (ok != true) {
      // FIX 9P·Performance: el controller lo crea quien llama y nunca se
      // disponía — cada meta fijada dejaba un controller vivo.
      ctrl.dispose();
      return null;
    }
    final v = parseLocaleNum(ctrl.text); // leer ANTES de disponer
    ctrl.dispose();
    return v;
  }
}

/// v32 · Fila de umbral: rótulo con el % actual (completo, sin recortes) y
/// el slider a todo lo ancho debajo — antes el slider exprimía el rótulo.
class _UmbralRow extends StatelessWidget {
  const _UmbralRow({
    required this.titulo,
    required this.valor,
    required this.min,
    required this.max,
    required this.divisiones,
    required this.onChanged,
  });

  final String titulo;
  final double valor;
  final double min;
  final double max;
  final int divisiones;
  final ValueChanged<double> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '$titulo > ${fmtNum(valor, decimals: 0)} %',
          style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600),
        ),
        SliderTheme(
          data: SliderTheme.of(context).copyWith(trackHeight: 3),
          child: Slider(
            value: valor.clamp(min, max),
            min: min,
            max: max,
            divisions: divisiones,
            label: '${valor.toStringAsFixed(0)} %',
            onChanged: onChanged,
          ),
        ),
        SizedBox(height: scheme.brightness == Brightness.dark ? 2 : 0),
      ],
    );
  }
}
