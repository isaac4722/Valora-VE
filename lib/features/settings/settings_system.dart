/// ─── Ajustes · respaldo y tutorial/legal (parte de settings_screen.dart) ───
/// Respaldo JSON (replace/merge) + zona de peligro + tutorial/legal + acerca.
/// Parte del archivo principal: comparte privacidad e imports.
part of 'settings_screen.dart';

/// Ancla respaldo: export/import (replace|merge) + zona peligro.
class _Respaldo extends StatelessWidget {
  const _Respaldo({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Respaldo'),
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
        showToast(context, result.error ?? 'Archivo respaldo inválido', kind: ToastKind.error);
      }
      return;
    }
    if (merge) {
      final r = mergeBackupData(store.data, AppData.fromJson(
          Map<String, dynamic>.from((jsonDecode(raw) as Map)['data'] as Map)));
      store.replaceAll(r.data);
      if (context.mounted) {
        final c = r.counts;
        showToast(context,
            'Fusión: ${c.products} productos nuevos, '
            '${c.records} registros, ${c.transactions} movimientos, ${c.purchases} compras',
            kind: ToastKind.ok);
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
        showToast(context,
            'Reemplazo: ${incoming.products.length} productos, '
            '${incoming.purchases.length} compras',
            kind: ToastKind.ok);
      }
    }
  }
}

/// Ancla tutorial + legal + versión.
/// v17.8: UN solo tutorial completo (rejugable) — la lista de recorridos por
/// módulo se retiró con el nuevo motor (orden del dueño: no una lista, un
/// único walkthrough completo).
class _TutorialLegal extends StatelessWidget {
  const _TutorialLegal({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Tutorial y legal'),
      // Ancla del tour (v17.8): el paso final explica este mismo sitio.
      KeyedSubtree(
        key: TourKeys.tutorial,
        child: Card(
          child: Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text('Tutorial de la app',
                    style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: scheme.onSurface)),
              ),
            ),
            ListTile(
              dense: true,
              leading: Icon(Icons.school_outlined, size: 19, color: scheme.primary),
              title: const Text('Ver el tutorial completo', style: TextStyle(fontSize: 13)),
              subtitle: const Text('13 pasos por toda la app, anclados a cada pantalla', style: TextStyle(fontSize: 11)),
              trailing: const Icon(Icons.play_arrow_rounded, size: 20),
              onTap: () => runAppTour(context),
            ),
          ]),
        ),
      ),
      const SizedBox(height: 8),
      Card(
        child: Column(children: [
          ListTile(
            leading: Icon(Icons.waving_hand_outlined, color: scheme.primary),
            title: const Text('Volver a ver la bienvenida', style: TextStyle(fontSize: 13.5)),
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
