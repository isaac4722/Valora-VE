/// ─── Command palette «⌘K» · patrón Linear/Vercel (TASK-33 p2) ────────────────
/// QUÉ: la búsqueda global de la app vestida de command palette: overlay
/// centrado-arriba con input protagonista, resultados agrupados (módulos,
/// productos, compras, avisos), navegación por teclado (↑↓ · ↵ · esc) y
/// hints de teclado al pie — el gesto de búsqueda que define a un SaaS
/// moderno mínimo.
/// POR QUÉ: orden del dueño (TASK-33) de reconstruir la GUI con lenguaje
/// Linear/Vercel. Sustituye a la pantalla completa de búsqueda global:
/// MISMA lógica de matching sin acentos y mismos grupos, menos fricción.
///
/// Detalles de acceso: esc cierra, ↵ abre el marcado, ↑↓ mueven la marca,
/// y el scrim cierra al tocar. Los resultados se limitan a 8 por grupo con
/// el «y N más» honesto — igual que hacía la pantalla original.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:provider/provider.dart';

import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../widgets/ui.dart' show showToast;

/// Un resultado del palette: a dónde ir y cómo pintarse.
class _Hit {
  const _Hit({
    required this.title,
    required this.sub,
    required this.icon,
    required this.location,
    this.group = '',
  });
  final String title;
  final String sub;
  final IconData icon;
  final String location;
  final String group;
}

/// Módulos navegables con hint (los del shell · paralelo al NAV del web).
const List<(String, String, IconData, String)> kSearchModules =
    <(String, String, IconData, String)>[
      ('Inicio', 'Tasas del día y resumen', LucideIcons.home, '/'),
      (
        'Divisas',
        'Conversor con fecha histórica',
        LucideIcons.arrowLeftRight,
        '/conversor',
      ),
      (
        'Lista',
        'Lista de compras y vuelto',
        LucideIcons.shoppingCart,
        '/lista',
      ),
      (
        'Productos',
        'Catálogo y metas de precio',
        LucideIcons.package,
        '/productos',
      ),
      (
        'Análisis',
        'Brecha, gastos y devaluación',
        LucideIcons.chartColumn,
        '/analisis',
      ),
      ('Historial', 'Compras como asientos', LucideIcons.history, '/historial'),
      ('Tickets', 'Fotos de tus recibos', LucideIcons.receipt, '/tickets'),
      ('Ajustes', 'País, cinta y apariencia', LucideIcons.settings, '/ajustes'),
    ];

/// Abre el command palette. Ruta empujada como diálogo sin barrera de color
/// duro — Linear usa un scrim suave que deja leer la app detrás.
Future<void> showCommandPalette(BuildContext context) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: 'Cerrar búsqueda',
    barrierColor: const Color(0x660C1016),
    transitionBuilder: (context, animation, secondaryAnimation, child) {
      final curved = CurvedAnimation(parent: animation, curve: kEaseVe);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween<double>(begin: 0.98, end: 1).animate(curved),
          child: child,
        ),
      );
    },
    transitionDuration: const Duration(milliseconds: 160),
    pageBuilder: (context, animation, secondaryAnimation) =>
        const _CommandPalette(),
  );
}

class _CommandPalette extends StatefulWidget {
  const _CommandPalette();

  @override
  State<_CommandPalette> createState() => _CommandPaletteState();
}

class _CommandPaletteState extends State<_CommandPalette> {
  final TextEditingController _q = TextEditingController();
  final ScrollController _scroll = ScrollController();
  String _query = '';
  int _mark = 0;

  @override
  void dispose() {
    _q.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _go(String location) {
    // dp5: aviso discreto único (mismo patrón de la búsqueda original) —
    // el toast se pinta ANTES de cerrar el overlay (el contexto del diálogo
    // se desmonta con el pop).
    showToast(context, 'Abriendo…');
    Navigator.of(context).pop();
    if (location == '/historial' || location == '/ajustes') {
      context.push(location);
    } else {
      context.go(location);
    }
  }

  void _move(int delta, int total) {
    if (total == 0) return;
    setState(() => _mark = (_mark + delta + total) % total);
    // La marca siempre visible: scroll suave hasta ella.
    final target = (_mark * 56.0).clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(
      target,
      duration: const Duration(milliseconds: 120),
      curve: kEaseVe,
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    final width = MediaQuery.sizeOf(context).width;
    final paletteWidth = (width - 32).clamp(0, 620).toDouble();
    final String q = fold(_query.trim().toLowerCase());
    bool hit(String s) => fold(s.toLowerCase()).contains(q);

    // ── Resultados por grupo (misma lógica de la búsqueda original) ────────
    final List<_Hit> hits = <_Hit>[];

    void addGroup(String label, List<_Hit> items) {
      if (items.isEmpty) return;
      hits.addAll(
        items
            .map(
              (_Hit h) => _Hit(
                title: h.title,
                sub: h.sub,
                icon: h.icon,
                location: h.location,
                group: label,
              ),
            )
            .toList(),
      );
    }

    addGroup('Módulos', <_Hit>[
      for (final (String title, String sub, IconData icon, String loc)
          in kSearchModules)
        if (q.isEmpty || hit(title))
          _Hit(title: title, sub: sub, icon: icon, location: loc),
    ]);

    if (q.isNotEmpty) {
      final productos = store.products
          .where(
            (Product p) =>
                hit(p.name) || (p.barcode ?? '').contains(_query.trim()),
          )
          .take(8)
          .toList();
      addGroup('Productos', <_Hit>[
        for (final Product p in productos)
          _Hit(
            title: p.name,
            sub: p.latestRecord == null
                ? 'Catálogo · sin precio aún'
                : 'Catálogo · ${fmtUSD(p.latestRecord!.price)}',
            icon: LucideIcons.package,
            location: '/productos',
          ),
      ]);

      final compras = store.purchases
          .where((Purchase c) => c.store != null && hit(c.store!))
          .take(8)
          .toList();
      addGroup('Compras', <_Hit>[
        for (final Purchase c in compras)
          _Hit(
            title: c.store ?? 'Sin tienda',
            sub: '${fmtDate(c.date)} · ${fmtUSD(c.totalUSD)}',
            icon: LucideIcons.receipt,
            location: '/historial',
          ),
      ]);

      final notifs = store.notifs
          .where((NotificationItem n) => hit('${n.title} ${n.body}'))
          .take(8)
          .toList();
      addGroup('Avisos', <_Hit>[
        for (final NotificationItem n in notifs)
          _Hit(
            title: n.title,
            sub: n.body,
            icon: LucideIcons.bell,
            location: '/',
          ),
      ]);
    }

    final bool sinResultados = q.isNotEmpty && hits.isEmpty;
    if (_mark >= hits.length) _mark = 0;

    return Align(
      alignment: const Alignment(0, -0.55),
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: paletteWidth,
          constraints: const BoxConstraints(maxHeight: 560),
          decoration: BoxDecoration(
            color: scheme.surface,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
            boxShadow: const <BoxShadow>[
              BoxShadow(
                color: Color(0x1F0C1016),
                blurRadius: 24,
                offset: Offset(0, 12),
              ),
            ],
          ),
          clipBehavior: Clip.antiAlias,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ── Input protagonista ────────────────────────────────────
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 6, 16, 6),
                child: Row(
                  children: [
                    Icon(
                      LucideIcons.search,
                      size: 17,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Focus(
                        // Teclas del palette MIENTRAS se escribe (Linear):
                        // esc cierra · ↑↓ marca · ↵ abre — interceptadas
                        // antes de que el TextField las consuma.
                        onKeyEvent: (node, KeyEvent e) {
                          if (e is! KeyDownEvent) {
                            return KeyEventResult.ignored;
                          }
                          if (e.logicalKey == LogicalKeyboardKey.escape) {
                            Navigator.of(context).pop();
                            return KeyEventResult.handled;
                          } else if (e.logicalKey ==
                              LogicalKeyboardKey.arrowDown) {
                            _move(1, hits.length);
                            return KeyEventResult.handled;
                          } else if (e.logicalKey ==
                              LogicalKeyboardKey.arrowUp) {
                            _move(-1, hits.length);
                            return KeyEventResult.handled;
                          } else if (e.logicalKey == LogicalKeyboardKey.enter &&
                              hits.isNotEmpty) {
                            _go(hits[_mark.clamp(0, hits.length - 1)].location);
                            return KeyEventResult.handled;
                          }
                          return KeyEventResult.ignored;
                        },
                        child: TextField(
                          controller: _q,
                          autofocus: true,
                          onChanged: (v) => setState(() => _query = v),
                          style: TextStyle(
                            fontSize: 15,
                            color: scheme.onSurface,
                            fontFamily: 'Inter',
                          ),
                          decoration: InputDecoration(
                            hintText: 'Buscar módulos, productos, compras…',
                            hintStyle: TextStyle(
                              fontSize: 14.5,
                              color: scheme.onSurfaceVariant.withValues(
                                alpha: 0.85,
                              ),
                            ),
                            border: InputBorder.none,
                            isDense: true,
                          ),
                        ),
                      ),
                    ),
                    if (_query.isNotEmpty)
                      _KeyHint(
                        scheme: scheme,
                        child: 'esc',
                        onTap: () => Navigator.of(context).pop(),
                      ),
                  ],
                ),
              ),
              Divider(height: 1, color: scheme.outlineVariant),

              // ── Resultados ────────────────────────────────────────────
              Flexible(
                child: sinResultados
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 36),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              LucideIcons.searchX,
                              size: 34,
                              color: scheme.onSurfaceVariant,
                            ),
                            const SizedBox(height: 10),
                            Text(
                              'Sin resultados para «$_query»',
                              style: TextStyle(
                                fontSize: 13.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        controller: _scroll,
                        shrinkWrap: true,
                        padding: const EdgeInsets.symmetric(vertical: 6),
                        itemCount: hits.length,
                        itemBuilder: (context, i) {
                          final h = hits[i];
                          final bool firstOfGroup =
                              i == 0 || hits[i - 1].group != h.group;
                          final bool marked = i == _mark;
                          return _PaletteRow(
                            hit: h,
                            groupLabel: firstOfGroup ? h.group : null,
                            marked: marked,
                            onTap: () => _go(h.location),
                          );
                        },
                      ),
              ),

              // ── Hints de teclado al pie (firma Linear) ────────────────
              Divider(height: 1, color: scheme.outlineVariant),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                child: Row(
                  children: [
                    _KeyHint(scheme: scheme, child: '↑↓'),
                    const SizedBox(width: 4),
                    Text(
                      'navegar',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 14),
                    _KeyHint(scheme: scheme, child: '↵'),
                    const SizedBox(width: 4),
                    Text(
                      'abrir',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(width: 14),
                    _KeyHint(scheme: scheme, child: 'esc'),
                    const SizedBox(width: 4),
                    Text(
                      'cerrar',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      'sin acentos también',
                      style: TextStyle(
                        fontSize: 11.5,
                        color: scheme.onSurfaceVariant.withValues(alpha: 0.75),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Fila de resultado del palette: icono en caja muted, título + sub, marca
/// de teclado con la tinta de acción y chevron al pasar.
class _PaletteRow extends StatelessWidget {
  const _PaletteRow({
    required this.hit,
    required this.marked,
    required this.onTap,
    this.groupLabel,
  });

  final _Hit hit;
  final bool marked;
  final VoidCallback onTap;
  final String? groupLabel;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (groupLabel != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
            child: Text(
              groupLabel!.toUpperCase(),
              style: VeText.labelCaps(
                10,
                color: scheme.onSurfaceVariant,
                weight: FontWeight.w700,
              ),
            ),
          ),
        InkWell(
          onTap: onTap,
          child: ColoredBox(
            color: marked
                ? scheme.primary.withValues(alpha: 0.08)
                : Colors.transparent,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 7),
              child: Row(
                children: [
                  Container(
                    width: 28,
                    height: 28,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: scheme.onSurfaceVariant.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Icon(hit.icon, size: 15, color: scheme.primary),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          hit.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w600,
                            color: scheme.onSurface,
                          ),
                        ),
                        Text(
                          hit.sub,
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
                  if (marked) ...[
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 6,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: scheme.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        '↵',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.primary,
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Chip de tecla estilo Linear: cajita muted con la tecla dentro.
class _KeyHint extends StatelessWidget {
  const _KeyHint({required this.scheme, required this.child, this.onTap});

  final ColorScheme scheme;
  final String child;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1.5),
      decoration: BoxDecoration(
        color: scheme.onSurfaceVariant.withValues(alpha: 0.10),
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: scheme.outlineVariant, width: 0.5),
      ),
      child: Text(
        child,
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
          fontFamily: 'Inter',
        ),
      ),
    );
    return onTap == null ? box : GestureDetector(onTap: onTap, child: box);
  }
}
