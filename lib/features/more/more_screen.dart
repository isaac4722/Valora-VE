/// ─── Más · hub de módulos poco frecuentes («resumir sin quitar») ────────────
/// Finanzas, Análisis, Historial y Ajustes viven aquí (ramas stateful del
/// shell); Tutorial y legal sale del shell igual que siempre (/legal).
/// Design doc: docs/designs/2026-11-20-gui-simple.md (G2).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../widgets/ui.dart';

class MoreScreen extends StatelessWidget {
  const MoreScreen({super.key});

  static const List<(_HubEntry, String)> _entries = [
    (
      _HubEntry(
        icon: Icons.account_balance_wallet_outlined,
        title: 'Finanzas',
        subtitle: 'Ingresos y gastos normalizados en USD',
      ),
      '/finanzas',
    ),
    (
      _HubEntry(
        icon: Icons.bar_chart_outlined,
        title: 'Análisis',
        subtitle: 'Brecha BCV-paralelo, devaluación e inflación personal',
      ),
      '/analisis',
    ),
    (
      _HubEntry(
        icon: Icons.receipt_long_outlined,
        title: 'Historial',
        subtitle: 'Asientos de compras, filtros y exportación CSV',
      ),
      '/historial',
    ),
    (
      _HubEntry(
        icon: Icons.settings_outlined,
        title: 'Ajustes',
        subtitle: 'País, tasas, alertas, respaldo y tema',
      ),
      '/ajustes',
    ),
    (
      _HubEntry(
        icon: Icons.menu_book_outlined,
        title: 'Tutorial y legal',
        subtitle: 'Vuelve a ver el tutorial, privacidad y licencias',
      ),
      '/legal',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Material(
      color: scheme.surface,
      child: CustomScrollView(
        slivers: [
          const SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
            sliver: SliverToBoxAdapter(
              child: PageHeader('Más', hint: 'Todo lo demás, a un toque'),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            sliver: SliverList.separated(
              itemCount: _entries.length,
              separatorBuilder: (_, _) => const SizedBox(height: 8),
              itemBuilder: (context, i) {
                final (entry, location) = _entries[i];
                return _HubCard(entry: entry, onTap: () => context.go(location));
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _HubEntry {
  const _HubEntry({required this.icon, required this.title, required this.subtitle});
  final IconData icon;
  final String title;
  final String subtitle;
}

class _HubCard extends StatelessWidget {
  const _HubCard({required this.entry, required this.onTap});
  final _HubEntry entry;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return TapScale(
      onTap: onTap,
      child: Semantics(
        button: true,
        label: '${entry.title}: ${entry.subtitle}',
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
          decoration: BoxDecoration(
            color: scheme.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: scheme.outlineVariant),
          ),
          child: Row(children: [
            Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: scheme.primary.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(entry.icon, size: 20, color: scheme.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(entry.title,
                      style: const TextStyle(
                          fontSize: 14.5, fontWeight: FontWeight.w700, letterSpacing: -0.2)),
                  const SizedBox(height: 2),
                  Text(entry.subtitle,
                      style: TextStyle(
                          fontSize: 12, color: scheme.onSurfaceVariant, height: 1.25)),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, size: 20, color: scheme.onSurfaceVariant),
          ]),
        ),
      ),
    );
  }
}
