/// ─── Historial de compras (§9.5 + v17.2 multitienda/peso) ────────────────────
/// Asiento por compra (fecha small-caps, tienda, líneas ledger-dots, total
/// rule-double, stamp de fuente) · filtros periodo/mes/tienda/search/producto ·
/// filtro POR TIENDA que cubre también PurchaseItem.store (multitienda v17.2) ·
/// peso capturado por ítem cuando existe · paginación 20 · Ver (modal con
/// zoom de ticket) / Editar / Eliminar · export: compras CSV · movimientos
/// CSV · JSON backup · constancia.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../services/sharing.dart';
import '../../widgets/ui.dart';
import '../statement/statement_screen.dart';

const List<String> kPeriods = ['Todo', '7d', '30d', '90d', '365d'];

class HistoryScreen extends StatefulWidget {
  const HistoryScreen({super.key});

  @override
  State<HistoryScreen> createState() => _HistoryScreenState();
}

class _HistoryScreenState extends State<HistoryScreen> {
  String _period = 'Todo';
  String? _storeFilter;
  String _search = '';
  int _page = 0;

  List<Purchase> _filtered(AppStore store) {
    var list = store.purchases;
    final days = switch (_period) {
      '7d' => 7,
      '30d' => 30,
      '90d' => 90,
      '365d' => 365,
      _ => 0,
    };
    if (days > 0) {
      final from = DateTime.now().subtract(Duration(days: days));
      list = list.where((p) => p.date.isAfter(from)).toList();
    }
    if (_storeFilter != null) {
      // Multitienda v17.2: la tienda puede vivir en la compra (Purchase.store)
      // o en cada ítem (PurchaseItem.store) — el filtro cubre ambos niveles.
      list = list
          .where(
            (p) =>
                (p.store ?? '') == _storeFilter ||
                p.items.any((i) => (i.store ?? '') == _storeFilter),
          )
          .toList();
    }
    if (_search.trim().isNotEmpty) {
      final q = fold(_search.toLowerCase());
      list = list
          .where(
            (p) =>
                fold(p.items.map((i) => i.name).join(' ')).contains(q) ||
                fold((p.store ?? '').toLowerCase()).contains(q) ||
                fold((p.notes ?? '').toLowerCase()).contains(q),
          )
          .toList();
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final filtered = _filtered(store);
    final pages = (filtered.length / 20).ceil().clamp(1, 9999);
    final items = filtered.skip(_page * 20).take(20).toList();
    final storesInPurchases = <String>{
      for (final p in store.purchases) ...[
        if ((p.store ?? '').trim().isNotEmpty) p.store!.trim(),
        for (final i in p.items)
          if ((i.store ?? '').trim().isNotEmpty) i.store!.trim(),
      ],
    }.toList()..sort();

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PageHeader(
            'Historial de compras',
            hint: 'Asientos por compra, con ticket y export',
            action: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  tooltip: 'Galería de tickets',
                  icon: const Icon(Icons.photo_library_outlined, size: 19),
                  onPressed: () => context.push('/tickets'),
                ),
                IconButton(
                  tooltip: 'Constancia mensual',
                  icon: const Icon(Icons.picture_as_pdf_outlined, size: 19),
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const StatementScreen()),
                  ),
                ),
              ],
            ),
          ),
          // Filtros.
          Wrap(
            spacing: 6,
            children: [
              for (final p in kPeriods)
                ChipTag(
                  p,
                  selected: _period == p,
                  onTap: () => setState(() {
                    _period = p;
                    _page = 0;
                  }),
                ),
            ],
          ),
          const SizedBox(height: 8),
          TextField(
            onChanged: (v) => setState(() {
              _search = v;
              _page = 0;
            }),
            decoration: const InputDecoration(
              hintText: 'Buscar por producto, tienda o nota',
              prefixIcon: Icon(Icons.search, size: 18),
            ),
          ),
          if (storesInPurchases.isNotEmpty) ...[
            const SizedBox(height: 8),
            // Segmento «por tienda» (requisito I): filtra compras de tienda
            // única y también ítems dentro de compras multitienda.
            Text(
              'POR TIENDA',
              style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                ChipTag(
                  'Todas las tiendas',
                  selected: _storeFilter == null,
                  onTap: () => setState(() {
                    _storeFilter = null;
                    _page = 0;
                  }),
                ),
                for (final s in storesInPurchases.take(8))
                  ChipTag(
                    s,
                    selected: _storeFilter == s,
                    onTap: () => setState(() {
                      _storeFilter = s;
                      _page = 0;
                    }),
                  ),
              ],
            ),
          ],
          // Export bar. Wrap: los 2 botones + contador no caben en 360 dp
          // con escala 1.0 (fix overflow) — envuelven en vez de desbordar.
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              OutlinedButton.icon(
                onPressed: () => _exportPurchases(context, filtered),
                icon: const Icon(Icons.table_view, size: 14),
                label: const Text(
                  'Compras CSV',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
              OutlinedButton.icon(
                onPressed: () => _exportMovements(context, store),
                icon: const Icon(Icons.format_list_numbered, size: 14),
                label: const Text(
                  'Movimientos CSV',
                  style: TextStyle(fontSize: 11.5),
                ),
              ),
              const SizedBox(width: 6),
              // Contador honesto: todas las compras son navegables (páginas).
              Text(
                '${filtered.length} de ${store.purchases.length} compras',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 10),
          // Asientos.
          if (items.isEmpty)
            EmptyState(
              'Nada registrado en este filtro',
              icon: Icons.receipt_long_outlined,
              hint:
                  'Cierra una compra desde la Lista y aparecerá aquí como asiento.',
              actionLabel: 'Ir a la Lista',
              onAction: () => context.go('/lista'),
            )
          else
            for (final p in items)
              _Seat(purchase: p, onChanged: () => setState(() => _page = 0)),
          Paginator(
            page: _page + 1,
            totalPages: pages,
            onPage: (p) => setState(() => _page = p - 1),
          ),
        ],
      ),
    );
  }

  void _exportPurchases(BuildContext context, List<Purchase> list) {
    final rows = <List<String>>[
      [
        'Fecha',
        'Tienda',
        'TotalUSD',
        'TotalBs',
        'Tasa',
        'Fuente',
        'Pagado',
        'Items',
      ],
    ];
    for (final p in list) {
      rows.add([
        fmtDate(p.date),
        p.store ?? '',
        p.totalUSD.toStringAsFixed(2),
        p.totalBS.toStringAsFixed(2),
        p.rate.toStringAsFixed(4),
        p.rateSourceId ?? '',
        p.paidTotal?.toStringAsFixed(2) ?? '',
        '${p.items.length}',
      ]);
    }
    showShareFile(context, 'compras-valorave.csv', toCSV(rows));
  }

  void _exportMovements(BuildContext context, AppStore store) {
    final rows = <List<String>>[
      [
        'Fecha',
        'Producto',
        'Cantidad',
        'PrecioUSD',
        'PrecioOriginal',
        'Moneda',
        'Tienda',
      ],
    ];
    for (final p in store.purchases) {
      for (final i in p.items) {
        rows.add([
          fmtDate(p.date),
          i.name,
          '${i.quantity}',
          i.priceUSD.toStringAsFixed(4),
          i.originalPrice.toStringAsFixed(2),
          i.currency,
          p.store ?? '',
        ]);
      }
    }
    showShareFile(context, 'movimientos-precios-valorave.csv', toCSV(rows));
  }
}

/// Asiento de compra: cabecera + líneas punteadas + total doble filete.
class _Seat extends StatelessWidget {
  const _Seat({required this.purchase, required this.onChanged});
  final Purchase purchase;
  final VoidCallback onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final ticket = _ticketBytes(); // decodificado UNA vez por build
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(
                  fmtDate(purchase.date).toUpperCase(),
                  style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
                ),
                const SizedBox(width: 8),
                // Flexible + ellipsis: la tienda es texto libre del usuario
                // y con nombres largos desbordaba el asiento (fix overflow).
                if (purchase.store != null)
                  Expanded(
                    child: Text(
                      purchase.store!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            // Multitienda (v17.2): si la compra no tiene tienda única, los
            // ítems se agrupan bajo SU tienda (PurchaseItem.store).
            for (final g in _itemGroups(purchase)) ...[
              if (g.$1 != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 2),
                  child: Row(
                    children: [
                      Icon(
                        Icons.storefront_outlined,
                        size: 12,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 5),
                      Text(
                        g.$1!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              for (final i in g.$2)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 2),
                  child: LedgerRow(
                    label: _itemLabel(i, purchase),
                    value: fmtUSD(i.priceUSD * i.quantity),
                  ),
                ),
            ],
            const SizedBox(height: 8),
            const RuleDouble(),
            const SizedBox(height: 8),
            Row(
              children: [
                // Miniatura del ticket (si la compra trae foto) → abre el modal.
                if (ticket != null)
                  GestureDetector(
                    onTap: () => _view(context),
                    child: Tooltip(
                      message: 'Ver ticket',
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.memory(
                          ticket,
                          width: 44,
                          height: 44,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                        ),
                      ),
                    ),
                  ),
                if (purchase.rateSourceId != null)
                  Stamp(
                    RateSource.of(purchase.rateSourceId!)?.label ??
                        purchase.rateSourceId!,
                    color: scheme.primary,
                  )
                else
                  const Spacer(),
                const Spacer(),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      fmtUSD(purchase.totalUSD),
                      style: VeText.displayNum(19, color: scheme.onSurface),
                    ),
                    if (purchase.totalBS > 0)
                      Text(
                        'Bs ${fmtNum(purchase.totalBS)}',
                        style: TextStyle(
                          fontSize: 11,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                TextButton.icon(
                  onPressed: () => _view(context),
                  icon: const Icon(Icons.visibility_outlined, size: 14),
                  label: const Text('Ver', style: TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () => _edit(context),
                  icon: const Icon(Icons.edit_outlined, size: 14),
                  label: const Text('Editar', style: TextStyle(fontSize: 12)),
                ),
                TextButton.icon(
                  onPressed: () {
                    final store = context.read<AppStore>();
                    showDialog<void>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: const Text('Eliminar compra'),
                        content: const Text(
                          'Se quita el asiento del historial. Los productos registrados no se tocan.',
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(dctx),
                            child: const Text('Cancelar'),
                          ),
                          FilledButton(
                            onPressed: () {
                              store.deletePurchase(purchase.id);
                              Navigator.pop(dctx);
                              onChanged();
                            },
                            style: FilledButton.styleFrom(
                              backgroundColor: VeColors.of(context).neg,
                            ),
                            child: const Text('Eliminar'),
                          ),
                        ],
                      ),
                    );
                  },
                  icon: Icon(
                    Icons.delete_outline,
                    size: 14,
                    color: VeColors.of(context).neg,
                  ),
                  label: Text(
                    'Eliminar',
                    style: TextStyle(
                      fontSize: 12,
                      color: VeColors.of(context).neg,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  /// Etiqueta del ítem con el PESO capturado (si existe) y, en compras de
  /// tienda única con ítem de otra tienda, el renglón de esa tienda (v17.2).
  String _itemLabel(PurchaseItem i, Purchase p) {
    var label = '${i.quantity} × ${i.name}';
    if ((i.size ?? 0) > 0) {
      final size = i.size!;
      final unit = (i.sizeUnit ?? '').trim();
      label +=
          ' · ${fmtNum(size, decimals: size % 1 == 0 ? 0 : 2)}'
          '${unit.isEmpty ? '' : ' $unit'}';
    }
    if (p.store != null &&
        (i.store ?? '').trim().isNotEmpty &&
        i.store!.trim() != p.store!.trim()) {
      label += ' · ${i.store!.trim()}';
    }
    return label;
  }

  /// Grupos (tienda, ítems) preservando el orden del asiento. Una compra con
  /// tienda única (store != null) NO agrupa: sale como siempre.
  List<(String?, List<PurchaseItem>)> _itemGroups(Purchase p) {
    if (p.store != null) return [(null, p.items)];
    final map = <String, List<PurchaseItem>>{};
    final order = <String>[];
    for (final i in p.items) {
      final key = (i.store ?? '').trim();
      if (!map.containsKey(key)) order.add(key);
      (map[key] ??= []).add(i);
    }
    return [for (final k in order) (k.isEmpty ? null : k, map[k]!)];
  }

  /// Bytes del ticket (data URL 'data:image/jpeg;base64,…' → JPEG crudo).
  /// Null honesto si no hay foto o el data URL está corrupto.
  Uint8List? _ticketBytes() {
    final raw = purchase.ticketPhoto;
    if (raw == null || raw.isEmpty) return null;
    try {
      final b64 = raw.contains(',') ? raw.substring(raw.indexOf(',') + 1) : raw;
      return base64Decode(b64);
    } catch (_) {
      return null;
    }
  }

  /// Comparte el ticket como JPEG (mismo patrón share_plus del repo).
  Future<void> _shareTicket(Uint8List bytes) async {
    await SharePlus.instance.share(
      ShareParams(
        text: 'Ticket de compra · ValoraVE',
        files: [
          XFile.fromData(
            bytes,
            mimeType: 'image/jpeg',
            name: 'ticket-valorave.jpg',
          ),
        ],
      ),
    );
  }

  void _view(BuildContext context) {
    final bytes = _ticketBytes();
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        child: bytes == null
            ? InteractiveViewer(
                maxScale: 8,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Text(
                    purchaseDetailText(purchase, context),
                    style: const TextStyle(fontSize: 13, height: 1.5),
                  ),
                ),
              )
            : SizedBox(
                width: double.maxFinite,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 14, 12, 6),
                      child: Row(
                        children: [
                          Expanded(
                            child: Text(
                              '${purchase.store ?? 'Compra'} · ${fmtDate(purchase.date)} · ${fmtUSD(purchase.totalUSD)}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          IconButton(
                            icon: const Icon(Icons.close, size: 18),
                            tooltip: 'Cerrar',
                            onPressed: () => Navigator.pop(ctx),
                          ),
                        ],
                      ),
                    ),
                    Flexible(
                      child: InteractiveViewer(
                        minScale: 1,
                        maxScale: 8,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Image.memory(bytes, fit: BoxFit.contain),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(18, 6, 18, 12),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.tonalIcon(
                          onPressed: () => _shareTicket(bytes),
                          icon: const Icon(Icons.ios_share, size: 15),
                          label: const Text('Compartir ticket'),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  void _edit(BuildContext context) {
    final store = context.read<AppStore>();
    final storeCtrl = TextEditingController(text: purchase.store ?? '');
    final notesCtrl = TextEditingController(text: purchase.notes ?? '');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Editar compra'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: storeCtrl,
              decoration: const InputDecoration(hintText: 'Tienda'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: notesCtrl,
              decoration: const InputDecoration(hintText: 'Notas'),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () {
              store.updatePurchase(
                purchase.id,
                purchase.copyWith(
                  store: storeCtrl.text.trim().isEmpty
                      ? null
                      : storeCtrl.text.trim(),
                  notes: notesCtrl.text.trim().isEmpty
                      ? null
                      : notesCtrl.text.trim(),
                ),
              );
              Navigator.pop(ctx);
              onChanged();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    ).whenComplete(() {
      // Fix leak: los controllers del diálogo se disponen al cerrarlo
      // (cada edición dejaba dos vivos para siempre).
      storeCtrl.dispose();
      notesCtrl.dispose();
    });
  }
}

String purchaseDetailText(Purchase p, BuildContext context) {
  final lines = <String>[
    'Compra · ${fmtDate(p.date)}',
    if (p.store != null) p.store!,
    '',
    for (final i in p.items)
      '${i.quantity} × ${i.name}'
          '${(i.size ?? 0) > 0 ? ' · ${fmtNum(i.size!, decimals: i.size! % 1 == 0 ? 0 : 2)} ${i.sizeUnit ?? ''}' : ''}'
          '${(i.store ?? '').trim().isNotEmpty && p.store == null ? ' · ${i.store!.trim()}' : ''}'
          ' — ${fmtUSD(i.priceUSD * i.quantity)}',
    '',
    'Total: ${fmtUSD(p.totalUSD)}',
    if (p.totalBS > 0) 'Total Bs: ${fmtNum(p.totalBS)}',
    if (p.notes != null) 'Notas: ${p.notes}',
  ];
  return lines.join('\n');
}
