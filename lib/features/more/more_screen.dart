/// ─── Más (v27) ─────────────────────────────────────────────────────────────
/// El hub de todo lo que no cabe en la barra: módulos de dinero, herramientas
/// de compartir y la configuración de la app. Un buscador local filtra por
/// nombre o descripción, así ningún módulo queda escondido detrás de un
/// icono que hay que adivinar.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../core/ve_theme.dart';
import '../../core/version.dart';
import '../../widgets/ui.dart';

class MoreScreen extends ConsumerStatefulWidget {
  const MoreScreen({super.key});

  @override
  ConsumerState<MoreScreen> createState() => _MoreScreenState();
}

class _MoreScreenState extends ConsumerState<MoreScreen> {
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final query = _q.text.trim().toLowerCase();

    final groups = <_ModuleGroup>[
      _ModuleGroup(
        title: 'Tu dinero',
        items: const [
          _ModuleItem(
            icon: LucideIcons.chartColumn,
            title: 'Análisis',
            body: 'Brecha, devaluación, inflación y tus gastos.',
            route: '/analisis',
          ),
          _ModuleItem(
            icon: LucideIcons.package,
            title: 'Productos',
            body: 'Tu libro de precios por tienda y tus metas.',
            route: '/productos',
          ),
          _ModuleItem(
            icon: LucideIcons.history,
            title: 'Historial',
            body: 'Compras, constancias y exportaciones.',
            route: '/historial',
          ),
          _ModuleItem(
            icon: LucideIcons.receipt,
            title: 'Tickets',
            body: 'Las fotos de tus recibos, en orden.',
            route: '/tickets',
          ),
        ],
      ),
      _ModuleGroup(
        title: 'Compartir',
        items: const [
          _ModuleItem(
            icon: LucideIcons.radio,
            title: 'Sala en vivo',
            body: 'Crea o únete a una lista compartida.',
            route: '/sala',
          ),
          _ModuleItem(
            icon: LucideIcons.landmark,
            title: 'Cuentas y Pago Móvil',
            body: 'Tus datos de cobro, listos para compartir.',
            route: '/ajustes/cuentas',
          ),
          _ModuleItem(
            icon: LucideIcons.scanLine,
            title: 'Escanear',
            body: 'Lee un código o la etiqueta de un producto.',
            route: '/escanear',
          ),
        ],
      ),
      _ModuleGroup(
        title: 'La app',
        items: const [
          _ModuleItem(
            icon: LucideIcons.settings,
            title: 'Ajustes',
            body: 'Tasas, apariencia, respaldos y privacidad.',
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
        ],
      ),
    ];

    final visible = <_ModuleGroup>[
      for (final g in groups)
        if (query.isEmpty)
          g
        else
          _ModuleGroup(
            title: g.title,
            items: g.items
                .where(
                  (i) =>
                      i.title.toLowerCase().contains(query) ||
                      i.body.toLowerCase().contains(query),
                )
                .toList(),
          ),
    ]..removeWhere((g) => g.items.isEmpty);

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
            VeInput(
              controller: _q,
              placeholder: 'Buscar módulo',
              semantic: 'Buscar módulo',
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 4),
            if (visible.isEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24),
                child: Text(
                  'Nada con «${_q.text.trim()}». Prueba con «tasas», «lista» o «cuentas».',
                  style: TextStyle(
                    fontSize: 13.5,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              )
            else
              for (final g in visible) ...[
                Padding(
                  padding: const EdgeInsets.fromLTRB(2, 18, 2, 2),
                  child: Text(
                    g.title.toUpperCase(),
                    style: VeText.labelCaps(
                      11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ),
                for (final item in g.items)
                  _ModuleRow(item: item, last: g.items.last == item),
              ],
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

class _ModuleGroup {
  const _ModuleGroup({required this.title, required this.items});

  final String title;
  final List<_ModuleItem> items;
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

class _ModuleRow extends ConsumerWidget {
  const _ModuleRow({required this.item, required this.last});

  final _ModuleItem item;
  final bool last;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      onTap: () {
        const branches = {'/ajustes', '/productos', '/historial', '/analisis'};
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
                  FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
                    item.body,
                    maxLines: 1,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  )),
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
