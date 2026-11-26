/// ─── Más (v30 · H-41) ──────────────────────────────────────────────────────
/// El hub de lo que no vive en la barra: SOLO los módulos autónomos —
/// Productos · Tickets · Ajustes · Actualizaciones · Privacidad y
/// licencias. Análisis, Historial, Sala en vivo y Cuentas viven en sus
/// sitios (pestaña · Lista · Lista · Ajustes e Inicio) y Escanear vive
/// donde se usa (captura de Lista y ficha de Productos). Sin buscador:
/// cinco módulos no lo necesitan.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../core/theme.dart';
import '../../core/ve_theme.dart';
import '../../core/version.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final modules = const <_ModuleItem>[
      _ModuleItem(
        icon: LucideIcons.package,
        title: 'Productos',
        body: 'Tu libro de precios por tienda y tus metas.',
        route: '/productos',
      ),
      _ModuleItem(
        icon: LucideIcons.receipt,
        title: 'Tickets',
        body: 'Las fotos de tus recibos, en orden.',
        route: '/tickets',
      ),
      _ModuleItem(
        icon: LucideIcons.settings,
        title: 'Ajustes',
        body: 'Cuentas, tasas, conexión, apariencia y datos.',
        route: '/ajustes',
      ),
      _ModuleItem(
        icon: LucideIcons.download,
        title: 'Actualizaciones',
        body: 'La versión nueva, descargada desde GitHub.',
        route: '/actualizaciones',
      ),
      _ModuleItem(
        icon: LucideIcons.gavel,
        title: 'Privacidad y licencias',
        body: 'Qué vive en tu teléfono y qué no.',
        route: '/legal',
      ),
    ];

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            Text(
              'Más',
              style: VeText.displayNum(
                30,
                color: scheme.onSurface,
                weight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Todo lo que no cabe en la barra, a un toque.',
              style: TextStyle(fontSize: 13.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 14),
            for (final item in modules)
              _ModuleRow(item: item, last: modules.last == item),
            const SizedBox(height: 18),
            Center(
              child: Text(
                'ValoraVE $kAppVersionVisible',
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModuleItem {
  const _ModuleItem({
    required this.icon,
    required this.title,
    required this.body,
    required this.route,
  });

  final IconData icon;
  final String title;
  final String body;
  final String route;
}

class _ModuleRow extends StatelessWidget {
  const _ModuleRow({required this.item, required this.last});

  final _ModuleItem item;
  final bool last;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        // Pestañas del shell: cambio de rama (go); el resto se apila (push).
        const branches = {'/ajustes', '/productos'};
        if (branches.contains(item.route)) {
          context.go(item.route);
        } else {
          context.push(item.route);
        }
      },
      borderRadius: BorderRadius.circular(10),
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 11),
        decoration: BoxDecoration(
          border: last
              ? null
              : Border(
                  bottom: BorderSide(
                    color: scheme.outlineVariant.withValues(alpha: 0.55),
                  ),
                ),
        ),
        child: Row(
          children: [
            Container(
              width: 38,
              height: 38,
              decoration: BoxDecoration(
                color: context.ve.colorScheme.muted,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                item.icon,
                size: 18,
                color: context.ve.colorScheme.foreground,
              ),
            ),
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
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      item.body,
                      maxLines: 1,
                      style: TextStyle(
                        fontSize: 11,
                        color: scheme.onSurfaceVariant,
                      ),
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
    );
  }
}
