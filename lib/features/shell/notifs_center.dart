/// ─── Centro de notificaciones (campana → hoja Ve, §9.9 · TASK-35 p3) ────────
/// Ring 50 · 9 kinds con tintes · marcar leída al tocar · Leídas · Limpiar ·
/// CTA a permisos en Ajustes. Dedupe de título 10 min vive en el store.
///
/// Diseño del prototipo (Overlays.tsx · AlertsSheet): hoja con título
/// «Alertas · N», filas divididas con chip de icono de 28 px sobre el fondo
/// tenue del tono, y pie con el botón principal «Configurar alertas».
/// Techo del sheet: 88 % de la altura útil (nada sube sin límite).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../core/fmt.dart';
import '../../widgets/ve/ve.dart';

/// Abre el centro de avisos (hoja «Ve» del prototipo, con techo).
void showNotificationCenter(BuildContext context) {
  final store = context.read<AppStore>();
  showVeSheet<void>(
    context: context,
    title: 'Alertas · ${store.notifs.length}',
    trailing: _AlertsTrailing(),
    footer: Builder(
      builder: (ctx) => VeBtn(
        variant: VeBtnVariant.primary,
        size: VeBtnSize.lg,
        expands: true,
        onPressed: () {
          Navigator.of(ctx).pop();
          ctx.go('/ajustes');
        },
        child: const Text('Configurar alertas'),
      ),
    ),
    builder: (_) => const NotificationCenterBody(),
  );
}

/// Acciones compactas del título: «Leídas» y «Limpiar» (ghost sm), como
/// los enlaces de texto del diseño anterior pero en lenguaje Ve.
class _AlertsTrailing extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final unread = store.notifs.where((n) => !n.read).length;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (unread > 0) ...[
          VeBtn(
            variant: VeBtnVariant.ghost,
            size: VeBtnSize.sm,
            onPressed: () => store.markAllRead(),
            child: const Text('Leídas'),
          ),
          const SizedBox(width: 4),
        ],
        VeBtn(
          variant: VeBtnVariant.ghost,
          size: VeBtnSize.sm,
          onPressed: store.notifs.isEmpty ? null : store.clearNotifications,
          child: const Text('Limpiar'),
        ),
      ],
    );
  }
}

/// Cuerpo scrolleable del centro de avisos: filas divididas por borde con
/// chip de icono por tono (patrón AlertsSheet del prototipo).
class NotificationCenterBody extends StatelessWidget {
  const NotificationCenterBody({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final items = store.notifs;

    if (items.isEmpty) {
      return const VeEmpty(
        icon: LucideIcons.bell,
        title: 'Todo tranquilo',
        sub: 'Aquí van llegando los avisos de picos de tasa, tus metas, la '
            'brecha y los recordatorios.',
      );
    }

    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: ShadTheme.of(context).colorScheme.border),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0)
              Divider(
                height: 1,
                thickness: 1,
                color: ShadTheme.of(context).colorScheme.border,
              ),
            _NotifRow(n: items[i]),
          ],
        ],
      ),
    );
  }
}

class _NotifRow extends StatelessWidget {
  const _NotifRow({required this.n});

  final NotificationItem n;

  (IconData, VeTone) _icon(NotifKind t) => switch (t) {
    NotifKind.spike => (LucideIcons.zap, VeTone.warn),
    NotifKind.target => (LucideIcons.crosshair, VeTone.info),
    NotifKind.threshold => (LucideIcons.trendingUp, VeTone.info),
    NotifKind.gap => (LucideIcons.arrowLeftRight, VeTone.warn),
    NotifKind.daily => (LucideIcons.calendarDays, VeTone.pos),
    NotifKind.reminder => (LucideIcons.alarmClock, VeTone.neutral),
    NotifKind.bcv => (LucideIcons.landmark, VeTone.pos),
    NotifKind.test => (LucideIcons.flaskConical, VeTone.info),
    NotifKind.info => (LucideIcons.info, VeTone.neutral),
  };

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

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final scheme = ShadTheme.of(context).colorScheme;
    final (icon, tone) = _icon(n.kind);

    return InkWell(
      onTap: () => store.markRead(n.id),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Chip de icono 28 px sobre el fondo tenue del tono (AlertsSheet).
            Container(
              width: 28,
              height: 28,
              decoration: BoxDecoration(color: _toneBg(context, tone)),
              child: Icon(icon, size: 14, color: _toneFg(context, tone)),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: n.read ? FontWeight.w500 : FontWeight.w600,
                      color: scheme.foreground,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    n.body,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12.5,
                      height: 1.4,
                      color: scheme.mutedForeground,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      Text(
                        _label(n.kind).toUpperCase(),
                        style: VeText.labelCaps(
                          9,
                          color: _toneFg(context, tone),
                          weight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        timeAgo(n.at),
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 11,
                          color: scheme.mutedForeground,
                        ),
                      ),
                      const Spacer(),
                      if (!n.read)
                        Container(
                          width: 6,
                          height: 6,
                          decoration: BoxDecoration(
                            color: scheme.foreground,
                            shape: BoxShape.circle,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _toneBg(BuildContext context, VeTone tone) {
    final ink = VeColors.of(context);
    return switch (tone) {
      VeTone.pos => ink.posBg,
      VeTone.neg => ink.negBg,
      VeTone.warn => ink.warnBg,
      VeTone.info => ink.infoBg,
      VeTone.neutral => ShadTheme.of(context).colorScheme.muted,
    };
  }

  Color _toneFg(BuildContext context, VeTone tone) {
    final ink = VeColors.of(context);
    return switch (tone) {
      VeTone.pos => ink.pos,
      VeTone.neg => ink.neg,
      VeTone.warn => ink.warn,
      VeTone.info => ink.manual,
      VeTone.neutral => ShadTheme.of(context).colorScheme.mutedForeground,
    };
  }
}
