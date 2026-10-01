/// ─── Historial de compras (§9.5 + v17.2 multitienda/peso · TASK-34 p9) ───────
/// Presentación del prototipo web: título con sub-contador y acciones, chips
/// de periodo + tiendas, búsqueda compacta, y las compras como FILAS en un
/// grupo dividido (tienda + fecha/ítems a la izquierda, total tabular +
/// insignia a la derecha) que abren la ficha en sheet Ve — igual que el
/// original. La ficha muestra los renglones con su tienda (multitienda v17.2),
/// el ticket (miniatura → visor con zoom 8×), editar y anular/eliminar.
///
/// Lógica intacta: filtros periodo/tienda/search (multitienda cubre
/// PurchaseItem.store), paginación 20, export unificado (compras CSV ·
/// movimientos CSV) desde la barra pegajosa, constancia mensual.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../widgets/export_sheet.dart';
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
    final filtered = _filtered(store);
    final pages = (filtered.length / 20).ceil().clamp(1, 9999);
    final cur = _page.clamp(0, pages - 1);
    final items = filtered.skip(cur * 20).take(20).toList();
    // Suma honesta del filtro (como el sub del título del prototipo).
    final sum = filtered.fold<double>(0, (a, p) => a + p.totalUSD);
    final storesInPurchases = <String>{
      for (final p in store.purchases) ...[
        if ((p.store ?? '').trim().isNotEmpty) p.store!.trim(),
        for (final i in p.items)
          if ((i.store ?? '').trim().isNotEmpty) i.store!.trim(),
      ],
    }.toList()..sort();

    return Scaffold(
      body: Stack(
        children: [
          VeEntry(
            child: Builder(
              builder: (listCtx) {
                final scheme = ShadTheme.of(listCtx).colorScheme;
                return ListView(
                  // Padding inferior extra: la barra pegadiza de export siempre
                  // presente puede tapar la última fila + el paginador.
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 116),
                  children: [
                    VeTitle(
                      sub: Text('${filtered.length} compras · ${fmtUSD(sum)}'),
                      right: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          VeIconBtn(
                            icon: LucideIcons.images,
                            onTap: () => context.push('/tickets'),
                            label: 'Galería de tickets',
                          ),
                          const SizedBox(width: 4),
                          VeIconBtn(
                            icon: LucideIcons.fileText,
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StatementScreen(),
                              ),
                            ),
                            label: 'Constancia mensual',
                          ),
                        ],
                      ),
                      child: const Text('Historial'),
                    ),
                    // ── Chips de periodo (scroll horizontal como el prototipo).
                    SizedBox(
                      height: 30,
                      child: ListView(
                        scrollDirection: Axis.horizontal,
                        children: [
                          for (final p in kPeriods)
                            Padding(
                              padding: EdgeInsets.only(
                                right: p == kPeriods.last ? 0 : 8,
                              ),
                              child: VeChip(
                                active: _period == p,
                                onTap: () => setState(() {
                                  _period = p;
                                  _page = 0;
                                }),
                                child: Text(_periodLabel(p)),
                              ),
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 10),
                    VeInput(
                      placeholder: 'Buscar por producto, tienda o nota',
                      onChanged: (v) => setState(() {
                        _search = v;
                        _page = 0;
                      }),
                    ),
                    // ── Por tienda: chips (requisito I: cubre también ítems de
                    // compras multitienda). Solo si hay tiendas que mostrar.
                    if (storesInPurchases.isNotEmpty) ...[
                      VeEyebrow(child: const Text('POR TIENDA')),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        children: [
                          VeChip(
                            active: _storeFilter == null,
                            onTap: () => setState(() {
                              _storeFilter = null;
                              _page = 0;
                            }),
                            child: const Text('Todas'),
                          ),
                          for (final s in storesInPurchases.take(8))
                            VeChip(
                              active: _storeFilter == s,
                              onTap: () => setState(() {
                                _storeFilter = s;
                                _page = 0;
                              }),
                              child: Text(s),
                            ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 16),
                    // ── Asientos: grupo dividido con una fila por compra.
                    if (items.isEmpty)
                      VeEmpty(
                        title: 'Sin compras',
                        sub:
                            'No hay compras con este filtro. Cierra una compra desde Lista.',
                        action: VeBtn(
                          size: VeBtnSize.sm,
                          onPressed: () => context.go('/lista'),
                          child: const Text('Ir a Lista'),
                        ),
                      )
                    else
                      VeGroup(
                        semantic: 'Compras del historial',
                        children: [
                          for (final p in items)
                            VeRow(
                              semantic:
                                  'Compra en ${p.store ?? 'varias tiendas'} por ${fmtUSD(p.totalUSD)}',
                              onTap: () => _openDetail(context, store, p),
                              label: Text(
                                p.store?.isNotEmpty == true
                                    ? p.store!
                                    : 'Compra multitienda',
                              ),
                              sub: Text(
                                '${fmtDate(p.date)} · ${p.items.length} '
                                '${p.items.length == 1 ? 'ítem' : 'ítems'}'
                                '${p.ticketPhoto != null && p.ticketPhoto!.isNotEmpty ? ' · con ticket' : ''}',
                              ),
                              right: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    fmtUSD(p.totalUSD),
                                    style: TextStyle(
                                      fontWeight: FontWeight.w600,
                                      color: scheme.foreground,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  if (p.ticketPhoto != null &&
                                      p.ticketPhoto!.isNotEmpty)
                                    const VeBadge(
                                      tone: VeTone.pos,
                                      child: Text('Ticket'),
                                    )
                                  else if (p.rateSourceId != null)
                                    VeBadge(
                                      child: Text(
                                        RateSource.of(p.rateSourceId!)?.label ??
                                            p.rateSourceId!,
                                      ),
                                    ),
                                ],
                              ),
                            ),
                        ],
                      ),
                    // ── Paginador del prototipo: Anterior · Página X de Y ·
                    // Siguiente (compacto, centrado, con botones Ve).
                    if (items.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          VeBtn(
                            size: VeBtnSize.sm,
                            enabled: cur > 0,
                            onPressed: () => setState(() => _page = cur - 1),
                            child: const Text('Anterior'),
                          ),
                          Expanded(
                            child: Text(
                              'Página ${cur + 1} de $pages · 20 por página',
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                fontFamily: 'Inter',
                                fontSize: 12,
                              ),
                            ),
                          ),
                          VeBtn(
                            size: VeBtnSize.sm,
                            enabled: cur < pages - 1,
                            onPressed: () => setState(() => _page = cur + 1),
                            child: const Text('Siguiente'),
                          ),
                        ],
                      ),
                    ],
                  ],
                );
              },
            ),
          ),
          // ── Barra pegadiza: el canal unificado de export del prototipo.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: VeStickyBar(
              children: [
                Expanded(
                  child: VeBtn(
                    size: VeBtnSize.lg,
                    icon: LucideIcons.table2,
                    onPressed: () => _exportPurchases(context, filtered),
                    child: const Text('CSV compras'),
                  ),
                ),
                Expanded(
                  child: VeBtn(
                    size: VeBtnSize.lg,
                    icon: LucideIcons.listOrdered,
                    onPressed: () => _exportMovements(context, store),
                    child: const Text('CSV movimientos'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _periodLabel(String p) => switch (p) {
    '7d' => '7 días',
    '30d' => '30 días',
    '90d' => '90 días',
    '365d' => '1 año',
    _ => 'Todo',
  };

  // ─────────────────────────────────────────────────── Ficha (sheet Ve) ─────

  void _openDetail(BuildContext context, AppStore store, Purchase purchase) {
    showVeSheet(
      context: context,
      title: purchase.store?.isNotEmpty == true
          ? purchase.store!
          : 'Compra multitienda',
      footer: Builder(
        builder: (sheetCtx) => Row(
          children: [
            VeBtn(
              variant: VeBtnVariant.danger,
              icon: LucideIcons.trash2,
              onPressed: () {
                Navigator.of(sheetCtx).pop();
                _confirmDelete(context, store, purchase);
              },
              child: const Text('Eliminar'),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: VeBtn(
                onPressed: () {
                  Navigator.of(sheetCtx).pop();
                  _edit(context, store, purchase);
                },
                child: const Text('Editar'),
              ),
            ),
          ],
        ),
      ),
      builder: (ctx) => _DetailBody(purchase: purchase),
    );
  }

  void _confirmDelete(BuildContext context, AppStore store, Purchase p) {
    showVeSheet(
      context: context,
      title: 'Eliminar compra',
      dismissible: true,
      footer: Builder(
        builder: (sheetCtx) => Row(
          children: [
            Expanded(
              child: VeBtn(
                onPressed: () => Navigator.of(sheetCtx).pop(),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: VeBtn(
                variant: VeBtnVariant.danger,
                onPressed: () {
                  store.deletePurchase(p.id);
                  Navigator.of(sheetCtx).pop();
                  setState(() => _page = 0);
                  showToast(context, 'Compra eliminada', kind: ToastKind.ok);
                },
                child: const Text('Eliminar'),
              ),
            ),
          ],
        ),
      ),
      builder: (ctx) => const Padding(
        padding: EdgeInsets.symmetric(vertical: 4),
        child: Text(
          'Se quita el asiento del historial. Los productos registrados no se tocan.',
        ),
      ),
    );
  }

  void _edit(BuildContext context, AppStore store, Purchase purchase) {
    final storeCtrl = TextEditingController(text: purchase.store ?? '');
    final notesCtrl = TextEditingController(text: purchase.notes ?? '');
    showVeSheet(
      context: context,
      title: 'Editar compra',
      footer: Builder(
        builder: (ctx) => Row(
          children: [
            Expanded(
              child: VeBtn(
                onPressed: () => Navigator.of(ctx).pop(),
                child: const Text('Cancelar'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: VeBtn(
                variant: VeBtnVariant.primary,
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
                  Navigator.of(ctx).pop();
                },
                child: const Text('Guardar'),
              ),
            ),
          ],
        ),
      ),
      builder: (ctx) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const VeEyebrow(child: Text('TIENDA')),
          VeInput(controller: storeCtrl, placeholder: 'Nombre de la tienda'),
          const VeEyebrow(child: Text('NOTAS')),
          VeInput(controller: notesCtrl, placeholder: 'Una nota para ti'),
        ],
      ),
    ).whenComplete(() {
      // Fix leak: los controllers del diálogo se disponen al cerrarlo.
      storeCtrl.dispose();
      notesCtrl.dispose();
    });
  }

  Future<void> _exportPurchases(
    BuildContext context,
    List<Purchase> list,
  ) async {
    List<List<String>> rows() => [
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
      for (final p in list)
        [
          fmtDate(p.date),
          p.store ?? '',
          p.totalUSD.toStringAsFixed(2),
          p.totalBS.toStringAsFixed(2),
          p.rate.toStringAsFixed(4),
          p.rateSourceId ?? '',
          p.paidTotal?.toStringAsFixed(2) ?? '',
          '${p.items.length}',
        ],
    ];
    await showExportSheet(
      context,
      ExportSpec(
        title: 'Compras',
        subtitle: '${list.length} compras guardadas',
        formats: [
          csvFormat(
            hint: 'Una fila por compra: tienda, montos y tasa',
            fileName: 'compras-valorave.csv',
            rows: rows,
          ),
        ],
      ),
    );
  }

  Future<void> _exportMovements(BuildContext context, AppStore store) async {
    List<List<String>> rows() => [
      [
        'Fecha',
        'Producto',
        'Cantidad',
        'PrecioUSD',
        'PrecioOriginal',
        'Moneda',
        'Tienda',
      ],
      for (final p in store.purchases)
        for (final i in p.items)
          [
            fmtDate(p.date),
            i.name,
            '${i.quantity}',
            i.priceUSD.toStringAsFixed(4),
            i.originalPrice.toStringAsFixed(2),
            i.currency,
            // Multitienda (v17.2): el ítem manda; si no tiene tienda propia,
            // cae a la de la compra — igual que la ficha en pantalla.
            i.store ?? p.store ?? '',
          ],
    ];
    await showExportSheet(
      context,
      ExportSpec(
        title: 'Movimientos de precios',
        subtitle: 'Cada ítem de cada compra con su moneda original',
        formats: [
          csvFormat(
            hint: 'Una fila por ítem: precio, moneda y tienda',
            fileName: 'movimientos-precios-valorave.csv',
            rows: rows,
          ),
        ],
      ),
    );
  }
}

/// Cuerpo de la ficha: cabecera con la cifra grande (como el prototipo:
/// eyebrow fecha + 32 px tabular + equivalente Bs), renglones en grupo
/// dividido — con grupo de tienda cuando la compra es multitienda — y la
/// miniatura del ticket que abre el visor con zoom.
class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.purchase});

  final Purchase purchase;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final bytes = _ticketBytes();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // ── Cabecera: cifra protagonista.
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  VeEyebrow(child: Text(fmtDate(purchase.date).toUpperCase())),
                  Text(
                    fmtUSD(purchase.totalUSD),
                    style: VeText.displayNum(
                      32,
                      color: scheme.foreground,
                      weight: FontWeight.w600,
                    ).copyWith(letterSpacing: -0.03),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    purchase.totalBS > 0
                        ? 'Bs ${fmtNum(purchase.totalBS)} · tasa ${fmtRate(purchase.rate)}'
                        : 'Tasa ${fmtRate(purchase.rate)}',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: scheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
            VeBadge(child: Text('${purchase.items.length} ítems')),
          ],
        ),
        // ── Renglones (con grupos de tienda en multitienda v17.2).
        const SizedBox(height: 8),
        for (final g in _itemGroups(purchase)) ...[
          if (g.$1 != null)
            Padding(
              padding: const EdgeInsets.only(top: 10, bottom: 6),
              child: Row(
                children: [
                  Icon(
                    LucideIcons.store,
                    size: 12,
                    color: scheme.mutedForeground,
                  ),
                  const SizedBox(width: 5),
                  Text(
                    g.$1!,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                      color: scheme.mutedForeground,
                    ),
                  ),
                ],
              ),
            ),
          VeGroup(
            children: [
              for (final i in g.$2)
                VeRow(
                  label: Text(_itemLabel(i, purchase)),
                  right: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(fmtUSD(i.priceUSD)),
                      const SizedBox(width: 8),
                      Text(
                        fmtUSD(i.priceUSD * i.quantity),
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ],
        // ── Ticket: miniatura + visor (zoom 8×, compartir).
        if (bytes != null) ...[
          const VeEyebrow(child: Text('TICKET')),
          Row(
            children: [
              GestureDetector(
                onTap: () => _viewTicket(context),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.memory(
                    bytes,
                    width: 56,
                    height: 56,
                    fit: BoxFit.cover,
                    gaplessPlayback: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: VeBtn(
                  size: VeBtnSize.sm,
                  icon: LucideIcons.scanSearch,
                  onPressed: () => _viewTicket(context),
                  child: const Text('Ver con zoom'),
                ),
              ),
            ],
          ),
        ],
      ],
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

  void _viewTicket(BuildContext context) {
    final bytes = _ticketBytes();
    if (bytes == null) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        child: SizedBox(
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
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Cerrar',
                      color: Colors.white70,
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
}

/// Texto plano de la compra (compartir sin foto). Se mantiene como utilidad
/// pública: la usan accesibilidad y compartir en texto.
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
