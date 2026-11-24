/// ─── Aviso de modo caché (v27.2 · REA CalculaYa) ───────────────────────────
/// Cuando el usuario congela la tasa, todos los cálculos de la app usan la
/// misma cifra. Este aviso lo dice en todas las pantallas del shell y deja
/// «Actualizar» a un toque: apaga el caché, refresca y vuelve a congelar.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../core/fmt.dart';
import '../core/ve_theme.dart';
import '../widgets/ui.dart';
import 'package:valorave/providers/providers.dart';

class CacheModeBanner extends ConsumerWidget {
  const CacheModeBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final store = ref.watch(appStoreProvider);
    if (!store.settings.cacheMode) return const SizedBox.shrink();
    final poller = ref.watch(ratesPollerProvider);
    final scheme = context.ve.colorScheme;
    final at = store.board.fetchedAt;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      padding: const EdgeInsets.fromLTRB(12, 6, 6, 6),
      decoration: BoxDecoration(
        color: scheme.muted,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: scheme.border),
      ),
      child: Row(
        children: [
          Icon(LucideIcons.database, size: 15, color: scheme.foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Modo caché',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: scheme.foreground,
                  ),
                ),
                Text(
                  'Tasa congelada: ${at == null ? 'sin hora' : timeAgo(at)}.',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    color: scheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          VeBtn(
            variant: VeBtnVariant.ghost,
            size: VeBtnSize.sm,
            onPressed: () => store.refreshCache(poller.refreshNow),
            child: const Text('Actualizar'),
          ),
        ],
      ),
    );
  }
}
