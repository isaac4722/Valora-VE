/// ─── Búsqueda global (dp4) ──────────────────────────────────────────────────
/// Pantalla completa accesible desde la lupa de la cabecera: una sola caja
/// que busca en módulos, productos del catálogo, compras con tienda y
/// avisos del centro, con matching sin acentos («analisis» halla «Análisis»).
///
/// dp5 fix: un SOLO aviso discreto al abrir un resultado (el quirk del dp4
/// apilaba dos SnackBar que tapaban contenido — corregido por decisión del
/// dueño: calidad profesional).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../data/store.dart';
import '../../widgets/ui.dart';

class GlobalSearchScreen extends StatefulWidget {
  const GlobalSearchScreen({super.key});

  @override
  State<GlobalSearchScreen> createState() => _GlobalSearchScreenState();
}

class _GlobalSearchScreenState extends State<GlobalSearchScreen> {
  final TextEditingController _q = TextEditingController();
  String _query = '';

  void _go(String location) {
    // dp5: aviso discreto único (no bloquea el contenido).
    showToast(context, 'Abriendo…');
    Navigator.of(context).pop();
    if (location == '/historial' || location == '/ajustes') {
      context.push(location);
    } else {
      context.go(location);
    }
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    final String q = fold(_query.trim().toLowerCase());

    bool hit(String s) => fold(s.toLowerCase()).contains(q);

    // ── Resultados por grupo ────────────────────────────────────────────────
    final List<(String, String, IconData, String)> modulos = _kSearchModules
        .where(((String, String, IconData, String) r) => q.isEmpty || hit(r.$1))
        .toList();
    final List<Product> productos = q.isEmpty
        ? const <Product>[]
        : store.products
              .where(
                (Product p) =>
                    hit(p.name) || (p.barcode ?? '').contains(_query.trim()),
              )
              .toList();
    final List<Purchase> compras = q.isEmpty
        ? const <Purchase>[]
        : store.purchases
              .where((Purchase c) => c.store != null && hit(c.store!))
              .toList();
    final List<NotificationItem> notifs = q.isEmpty
        ? const <NotificationItem>[]
        : store.notifs
              .where((NotificationItem n) => hit('${n.title} ${n.body}'))
              .toList();
    final bool sinResultados =
        q.isNotEmpty &&
        modulos.isEmpty &&
        productos.isEmpty &&
        compras.isEmpty &&
        notifs.isEmpty;

    return Scaffold(
      appBar: AppBar(
        title: TextField(
          controller: _q,
          autofocus: true,
          onChanged: (String v) => setState(() => _query = v),
          decoration: const InputDecoration(
            hintText: 'Buscar módulos, productos, compras…',
            border: InputBorder.none,
          ),
          style: TextStyle(fontSize: 15.5, color: scheme.onSurface),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: <Widget>[
          if (q.isEmpty) ...<Widget>[
            Text(
              'BUSCAR EN TODA LA APP',
              style: TextStyle(
                fontSize: 11,
                letterSpacing: 1.1,
                fontWeight: FontWeight.w700,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Módulos, productos del catálogo, compras con tienda y '
              'avisos. Escribe para filtrar — sin acentos también.',
              style: TextStyle(
                fontSize: 13,
                height: 1.45,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          if (modulos.isNotEmpty) ...<Widget>[
            const _GroupLabel('Módulos'),
            for (final (String title, String sub, IconData icon, String loc)
                in modulos)
              ListTile(
                leading: Icon(icon, color: scheme.primary),
                title: Text(title, style: const TextStyle(fontSize: 14.5)),
                subtitle: Text(
                  sub,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                dense: true,
                onTap: () => _go(loc),
              ),
          ],
          if (productos.isNotEmpty) ...<Widget>[
            const _GroupLabel('Productos'),
            for (final Product p in productos.take(8))
              ListTile(
                leading: Icon(
                  Icons.inventory_2_outlined,
                  color: scheme.primary,
                ),
                title: Text(p.name, style: const TextStyle(fontSize: 14.5)),
                subtitle: Text(
                  p.latestRecord == null
                      ? 'Catálogo · sin precio aún'
                      : 'Catálogo · ${fmtUSD(p.latestRecord!.price)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                dense: true,
                onTap: () => _go('/productos'),
              ),
          ],
          if (compras.isNotEmpty) ...<Widget>[
            const _GroupLabel('Compras'),
            for (final Purchase c in compras.take(8))
              ListTile(
                leading: Icon(
                  Icons.receipt_long_outlined,
                  color: scheme.primary,
                ),
                title: Text(
                  c.store ?? 'Sin tienda',
                  style: const TextStyle(fontSize: 14.5),
                ),
                subtitle: Text(
                  '${fmtDate(c.date)} · ${fmtUSD(c.totalUSD)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                dense: true,
                onTap: () => _go('/historial'),
              ),
          ],
          if (notifs.isNotEmpty) ...<Widget>[
            const _GroupLabel('Avisos'),
            for (final NotificationItem n in notifs.take(8))
              ListTile(
                leading: Icon(
                  Icons.notifications_outlined,
                  color: scheme.primary,
                ),
                title: Text(n.title, style: const TextStyle(fontSize: 14.5)),
                subtitle: Text(
                  n.body,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
                dense: true,
                onTap: () => _go('/'),
              ),
          ],
          if (sinResultados)
            Padding(
              padding: const EdgeInsets.only(top: 40),
              child: Column(
                children: <Widget>[
                  Icon(
                    Icons.search_off,
                    size: 42,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Sin resultados para «$_query»',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

/// Módulos navegables con hint (paralelo al NAV_ITEMS del web).
const List<(String, String, IconData, String)>
_kSearchModules = <(String, String, IconData, String)>[
  ('Inicio', 'Tasas del día y resumen', Icons.home_outlined, '/'),
  ('Divisas', 'Conversor con fecha histórica', Icons.swap_horiz, '/conversor'),
  (
    'Lista',
    'Lista de compras y vuelto',
    Icons.shopping_cart_outlined,
    '/lista',
  ),
  (
    'Productos',
    'Catálogo y metas de precio',
    Icons.inventory_2_outlined,
    '/productos',
  ),
  (
    'Análisis',
    'Brecha, gastos y devaluación',
    Icons.bar_chart_outlined,
    '/analisis',
  ),
  ('Historial', 'Compras como asientos', Icons.history, '/historial'),
  ('Tickets', 'Fotos de tus recibos', Icons.receipt_long_outlined, '/tickets'),
  ('Ajustes', 'País, cinta y apariencia', Icons.settings_outlined, '/ajustes'),
];

class _GroupLabel extends StatelessWidget {
  const _GroupLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 14, bottom: 2),
      child: Text(
        text.toUpperCase(),
        style: TextStyle(
          fontSize: 11,
          letterSpacing: 1.1,
          fontWeight: FontWeight.w700,
          color: scheme.onSurfaceVariant,
        ),
      ),
    );
  }
}
