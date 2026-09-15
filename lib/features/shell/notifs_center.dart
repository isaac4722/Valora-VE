/// ─── Centro de notificaciones (campana → bottom sheet, §9.9) ────────────────
/// Ring 50 · 9 kinds con tintes · marcar leída al tocar · Leídas · Limpiar ·
/// CTA a permisos en Ajustes. Dedupe de título 10 min vive en el store.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../core/fmt.dart';

void showNotificationCenter(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => const NotificationCenterSheet(),
  );
}

class NotificationCenterSheet extends StatefulWidget {
  const NotificationCenterSheet({super.key});

  @override
  State<NotificationCenterSheet> createState() =>
      _NotificationCenterSheetState();
}

class _NotificationCenterSheetState extends State<NotificationCenterSheet> {
  Color _ink(BuildContext context, NotifKind t) {
    final VeInk sem = VeColors.of(context);
    return switch (t) {
      NotifKind.spike => sem.warn,
      NotifKind.target => Theme.of(context).colorScheme.primary,
      NotifKind.threshold => Theme.of(context).colorScheme.primary,
      NotifKind.gap => sem.warn,
      NotifKind.daily => sem.pos,
      NotifKind.reminder => Theme.of(context).colorScheme.onSurfaceVariant,
      NotifKind.bcv => sem.pos,
      NotifKind.test => Theme.of(context).colorScheme.primary,
      NotifKind.info => Theme.of(context).colorScheme.onSurfaceVariant,
    };
  }

  String _label(NotifKind t) => switch (t) {
    NotifKind.spike => 'pico',
    NotifKind.target => 'meta de tasa',
    NotifKind.threshold => 'umbral',
    NotifKind.gap => 'brecha',
    NotifKind.daily => 'cambio diario',
    NotifKind.reminder => 'recordatorio',
    NotifKind.bcv => 'BCV',
    NotifKind.test => 'prueba',
    NotifKind.info => 'aviso',
  };

  IconData _icon(NotifKind t) => switch (t) {
    NotifKind.spike => Icons.bolt_outlined,
    NotifKind.target => Icons.adjust,
    NotifKind.threshold => Icons.trending_up,
    NotifKind.gap => Icons.call_split,
    NotifKind.daily => Icons.today_outlined,
    NotifKind.reminder => Icons.alarm,
    NotifKind.bcv => Icons.account_balance_outlined,
    NotifKind.test => Icons.science_outlined,
    NotifKind.info => Icons.info_outline,
  };

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final items = store.notifs;
    final unread = items.where((n) => !n.read).length;

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      maxChildSize: 0.85,
      builder: (context, scroll) => Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(18, 2, 18, 10),
            child: Row(
              children: [
                Icon(
                  Icons.notifications_outlined,
                  size: 19,
                  color: Theme.of(context).colorScheme.primary,
                ),
                const SizedBox(width: 8),
                Text(
                  'Notificaciones',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: Theme.of(context).colorScheme.onSurface,
                  ),
                ),
                if (unread > 0) ...[
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.primary.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Text(
                      '$unread nueva${unread == 1 ? '' : 's'}',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                ],
                const Spacer(),
                TextButton(
                  onPressed: () => store.markAllRead(),
                  child: const Text('Leídas', style: TextStyle(fontSize: 12.5)),
                ),
                TextButton(
                  onPressed: () => store.clearNotifications(),
                  style: TextButton.styleFrom(
                    foregroundColor: VeColors.of(context).neg,
                  ),
                  child: const Text(
                    'Limpiar',
                    style: TextStyle(fontSize: 12.5),
                  ),
                ),
              ],
            ),
          ),
          Divider(
            height: 1,
            color: Theme.of(context).colorScheme.outlineVariant,
          ),
          Expanded(
            child: items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.notifications_off_outlined,
                          size: 40,
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                        const SizedBox(height: 10),
                        const Text(
                          'Todo tranquilo',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 15,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 34),
                          child: Text(
                            'Aquí van llegando los avisos de picos de tasa, tus metas, la brecha y los recordatorios.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 13,
                              height: 1.45,
                              color: Theme.of(
                                context,
                              ).colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.builder(
                    controller: scroll,
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    itemCount: items.length,
                    itemBuilder: (context, i) {
                      final n = items[i];
                      final Color ink = _ink(context, n.kind);
                      return InkWell(
                        onTap: () => store.markRead(n.id),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 18,
                            vertical: 11,
                          ),
                          color: n.read
                              ? null
                              : Theme.of(
                                  context,
                                ).colorScheme.primary.withValues(alpha: 0.04),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 30,
                                height: 30,
                                decoration: BoxDecoration(
                                  color: ink.withValues(alpha: 0.12),
                                  borderRadius: BorderRadius.circular(9),
                                ),
                                child: Icon(
                                  _icon(n.kind),
                                  size: 15,
                                  color: ink,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            n.title,
                                            style: TextStyle(
                                              fontSize: 13.5,
                                              fontWeight: n.read
                                                  ? FontWeight.w600
                                                  : FontWeight.w800,
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.onSurface,
                                            ),
                                          ),
                                        ),
                                        Text(
                                          timeAgo(n.at),
                                          style: TextStyle(
                                            fontSize: 11.5,
                                            color: Theme.of(
                                              context,
                                            ).colorScheme.onSurfaceVariant,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      n.body,
                                      style: TextStyle(
                                        fontSize: 12.5,
                                        height: 1.4,
                                        color: Theme.of(
                                          context,
                                        ).colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                    const SizedBox(height: 5),
                                    Row(
                                      children: [
                                        Text(
                                          _label(n.kind),
                                          style: VeText.labelCaps(
                                            9,
                                            color: ink,
                                            weight: FontWeight.w700,
                                          ),
                                        ),
                                        if (!n.read) ...[
                                          const SizedBox(width: 6),
                                          Container(
                                            width: 6,
                                            height: 6,
                                            decoration: BoxDecoration(
                                              color: Theme.of(
                                                context,
                                              ).colorScheme.primary,
                                              shape: BoxShape.circle,
                                            ),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(18, 6, 18, 10),
              child: Row(
                children: [
                  Text(
                    'Avisos del sistema activos',
                    style: VeText.labelCaps(
                      9.5,
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      context.go('/ajustes');
                    },
                    child: const Text(
                      'Configurar alertas',
                      style: TextStyle(fontSize: 12.5),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
