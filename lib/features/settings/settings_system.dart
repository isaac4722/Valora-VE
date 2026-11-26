/// ─── Ajustes · respaldo y tutorial/legal (parte de settings_screen.dart) ───
/// Respaldo JSON (replace/merge) + zona de peligro + tutorial/legal + acerca.
/// Parte del archivo principal: comparte privacidad e imports.
/// v32: GUI plana — botones del kit a todo lo ancho, filas del kit para el
/// bloque «Acerca de», zona de peligro en tinta negativa sin caja.
part of 'settings_screen.dart';

/// Ancla respaldo: export/import (replace|merge) + zona peligro.
class _Respaldo extends StatelessWidget {
  const _Respaldo({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ink = VeColors.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: VeBtn(
            variant: VeBtnVariant.primary,
            icon: LucideIcons.share,
            onPressed: () => showExportSheet(
              context,
              ExportSpec(
                title: 'Respaldo de tus datos',
                subtitle:
                    'JSON completo: listas, productos y preferencias',
                formats: [
                  ExportFormat(
                    icon: Icons.data_object,
                    label: 'JSON',
                    hint: 'Todo tu historial en un archivo',
                    // v28 · JSON = TEXTO: se copia o se guarda; jamás abre
                    // el share nativo.
                    kind: ExportKind.texto,
                    run: (mode) async {
                      final name =
                          'backup-valorave-${SnapshotPoint.dayKey(DateTime.now())}.json';
                      // v20.4: las fotos-archivo viajan en el bloque
                      // ticketFiles (el JSON de estado queda como siempre;
                      // las fotos no se pierden).
                      final text = exportBackupJson(
                        store.data,
                        ticketFiles: await collectTicketFiles(store.data),
                      );
                      if (mode == ExportMode.guardar) {
                        final path = await downloadText(
                          text,
                          fileName: name,
                        );
                        return path == null
                            ? 'No se pudo guardar el respaldo.'
                            : 'Guardado en: $path';
                      }
                      return copiarTexto(text, 'Respaldo copiado');
                    },
                  ),
                ],
              ),
            ),
            child: const Text('Exportar respaldo JSON'),
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: VeBtn(
                variant: VeBtnVariant.secondary,
                onPressed: () => _import(context, merge: false),
                child: const Text('Reemplazar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: VeBtn(
                variant: VeBtnVariant.secondary,
                onPressed: () => _import(context, merge: true),
                child: const Text('Fusionar'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          'Fusionar suma por id y no toca tu carrito ni tus ajustes. '
          'Reemplazar conserva el tablero vivo.',
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 16),
        // ── Zona peligro (v32: tinta negativa sobre el papel, sin caja).
        Text(
          'Zona peligro',
          style: TextStyle(
            fontSize: 13.5,
            fontWeight: FontWeight.w800,
            color: ink.neg,
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          width: double.infinity,
          child: VeBtn(
            variant: VeBtnVariant.secondary,
            icon: LucideIcons.trash2,
            onPressed: () {
              showDialog<void>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('¿Borrar todo?'),
                  content: const Text(
                    'Se borran productos, compras, lista y plantillas. El '
                    'tablero de tasas se conserva.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx),
                      child: const Text('Cancelar'),
                    ),
                    FilledButton(
                      style: FilledButton.styleFrom(
                        backgroundColor: ink.neg,
                      ),
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
            child: Text(
              'Borrar todos mis datos',
              style: TextStyle(color: ink.neg),
            ),
          ),
        ),
      ],
    );
  }

  Future<void> _import(BuildContext context, {required bool merge}) async {
    final picked = await FilePicker.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (picked.isEmpty) return;
    final raw = await picked.single.readAsBytes().then(
      (b) => utf8.decode(b, allowMalformed: true),
    );
    final result = importBackup(store.data, raw, merge: merge);
    if (!result.ok) {
      if (context.mounted) {
        showToast(
          context,
          result.error ?? 'Archivo respaldo inválido',
          kind: ToastKind.error,
        );
      }
      return;
    }
    // v20.4: restaurar las fotos-archivo del bloque ticketFiles si viene.
    final tfRaw = (jsonDecode(raw) as Map)['ticketFiles'];
    if (tfRaw is Map && tfRaw.isNotEmpty) {
      await restoreTicketFiles(Map<String, dynamic>.from(tfRaw));
    }
    if (merge) {
      final r = mergeBackupData(
        store.data,
        AppData.fromJson(
          Map<String, dynamic>.from((jsonDecode(raw) as Map)['data'] as Map),
        ),
      );
      store.replaceAll(r.data);
      if (context.mounted) {
        final c = r.counts;
        // v23.3: tasas propias y cuentas solo cuando entraron (toast corto).
        final extra = [
          if (c.customRates > 0) '${c.customRates} tasas',
          if (c.accounts > 0) '${c.accounts} cuentas',
        ].join(', ');
        showToast(
          context,
          'Fusión: ${c.products} productos nuevos, '
          '${c.records} registros, ${c.transactions} movimientos, '
          '${c.purchases} compras'
          '${extra.isEmpty ? '' : ', $extra'}',
          kind: ToastKind.ok,
        );
      }
    } else {
      final incoming = AppData.fromJson(
        Map<String, dynamic>.from((jsonDecode(raw) as Map)['data'] as Map),
      );
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
        settings: incoming.settings,
        // v23.3 (pez 2-b P0-1): las listas v23 viajan con el respaldo en
        // replace — antes caían a [] y se perdían en silencio.
        customRates: incoming.customRates,
        accounts: incoming.accounts,
      );
      store.replaceAll(replaced);
      if (context.mounted) {
        showToast(
          context,
          'Reemplazo: ${incoming.products.length} productos, '
          '${incoming.purchases.length} compras',
          kind: ToastKind.ok,
        );
      }
    }
  }
}

/// Ancla tutorial + legal + versión (v32 filas del kit).
/// v17.8: UN solo tutorial completo (rejugable) — la lista de recorridos por
/// módulo se retiró con el nuevo motor (orden del dueño: no una lista, un
/// único walkthrough completo).
class _TutorialLegal extends StatelessWidget {
  const _TutorialLegal({required this.store});
  final AppStore store;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 10),
        // Ancla del tour (v17.8): el paso final explica este mismo sitio.
        KeyedSubtree(
          key: TourKeys.tutorial,
          child: VeGroup(
            semantic: 'Acerca de ValoraVE',
            children: [
              // El tutorial clásico se retiró (v28): cada sección se
              // explica sola — la fila muerta de «Tutorial» se fue con él.
              VeRow(
                label: const Text('Volver a ver la bienvenida'),
                showChevron: true,
                semantic: 'Volver a ver la bienvenida',
                onTap: () {
                  store.reopenTutorial();
                  context.go('/bienvenida');
                },
              ),
              // Canal dev (v22.3): la app se entera de las Releases de
              // GitHub del repo — comprueba si hay APK más nuevo que el
              // build instalado y deja descargarlo desde el navegador.
              VeRow(
                label: const Text('Buscar actualizaciones'),
                sub: const Text('APK de cada ronda en GitHub Releases.'),
                showChevron: true,
                semantic: 'Buscar actualizaciones',
                onTap: () => context.push('/actualizaciones'),
              ),
              VeRow(
                label: const Text('Licencias y privacidad'),
                showChevron: true,
                semantic: 'Licencias y privacidad',
                onTap: () => context.push('/legal'),
              ),
              FutureBuilder<PackageInfo>(
                future: PackageInfo.fromPlatform(),
                builder: (context, snap) => VeRow(
                  label: const Text('Acerca de ValoraVE'),
                  sub: Text(
                    'ValoraVE $kAppVersionVisible · build '
                    '${snap.data?.buildNumber} · es-VE · offline-first',
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'ValoraVE es un libro de precios y divisas de Venezuela: todo lo '
          'que guardas vive en este teléfono.',
          style: TextStyle(
            fontSize: 11,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
