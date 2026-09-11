/// ─── Tickets · Galería de fotos de recibos (dp6, módulo 13) ────────────────
/// Adaptación del dp6 a la arquitectura v17: las fotos NO viven como archivos
/// sueltos sino como `ticketPhoto` (data URL comprimida) de cada compra, así
/// cada ticket conserva su fecha, tienda y total. Grilla 3×, visor a pantalla
/// completa con zoom hasta 8×, compartir imagen y quitar foto de la compra
/// (la compra nunca se borra desde aquí). Foto perdida → estado honesto.
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../services/sharing.dart';
import '../../widgets/ui.dart';

/// Extrae los bytes de un data URL 'data:image/...;base64,…' (o base64
/// crudo). Devuelve null si no se puede decodificar — la celda muestra el
/// estado «imagen rota» en vez de romper la grilla.
Uint8List? ticketBytes(String? dataUrl) {
  if (dataUrl == null || dataUrl.isEmpty) return null;
  final b64 = dataUrl.contains(',') ? dataUrl.split(',').last : dataUrl;
  try {
    return base64Decode(b64);
  } catch (_) {
    return null;
  }
}

class TicketsScreen extends StatelessWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final scheme = Theme.of(context).colorScheme;
    final withPhoto = store.purchases
        .where((p) => p.ticketPhoto != null && p.ticketPhoto!.isNotEmpty)
        .toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PageHeader('Tickets', hint: 'Fotos de tus recibos, siempre a mano'),
          if (withPhoto.isEmpty)
            EmptyState(
              'Sin tickets todavía',
              icon: Icons.receipt_rounded,
              hint:
                  'Fotografía el recibo al cerrar una compra (Checkout · Añadir foto) y aparecerá aquí, con su fecha y total.',
              actionLabel: 'Ir a la lista de compras',
              onAction: () => context.push('/lista'),
            )
          else ...[
            Text(
              '${withPhoto.length} ${withPhoto.length == 1 ? 'foto' : 'fotos'} · de la más nueva a la más vieja',
              style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            GridView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                mainAxisSpacing: 10,
                crossAxisSpacing: 10,
                childAspectRatio: 0.72,
              ),
              itemCount: withPhoto.length,
              itemBuilder: (context, i) => _TicketTile(
                purchase: withPhoto[i],
                onTap: () => _openViewer(context, store, withPhoto[i]),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              'Las fotos se comprimen al guardarlas (~200 KB) para no llenar el teléfono.',
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  void _openViewer(BuildContext context, AppStore store, Purchase p) {
    Navigator.of(context).push(MaterialPageRoute<void>(
      fullscreenDialog: true,
      builder: (_) => _TicketViewer(store: store, purchase: p),
    ));
  }
}

/// Celda de la grilla: foto + fecha + tienda debajo. La imagen rota
/// (data URL corrupto) degrada a icono sin romper el layout.
class _TicketTile extends StatelessWidget {
  const _TicketTile({required this.purchase, required this.onTap});

  final Purchase purchase;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final bytes = ticketBytes(purchase.ticketPhoto);
    return Semantics(
      button: true,
      label:
          'Ticket de ${purchase.date.day} de ${kMeses[purchase.date.month - 1]}${purchase.store == null || purchase.store!.isEmpty ? '' : ' · ${purchase.store}'}',
      child: TapScale(
        onTap: onTap,
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: double.infinity,
                color: scheme.surfaceContainerHigh.withValues(alpha: 0.5),
                child: bytes == null
                    ? Icon(Icons.image_not_supported_outlined,
                        size: 26, color: scheme.onSurfaceVariant)
                    : Image.memory(bytes,
                        fit: BoxFit.cover, gaplessPlayback: true),
              ),
            ),
          ),
          const SizedBox(height: 5),
          Text(fmtDate(purchase.date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                  fontSize: 10.5, fontWeight: FontWeight.w700)),
          Text(purchase.store?.isNotEmpty == true ? purchase.store! : 'Compra',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style:
                  TextStyle(fontSize: 9.5, color: scheme.onSurfaceVariant)),
        ]),
      ),
    );
  }
}

/// Visor a pantalla completa: fondo tinta, zoom 8×, barra con fecha/tienda y
/// acciones (compartir imagen · quitar foto de la compra). Quitar NO borra
/// la compra: solo el adjunto, con confirmación.
class _TicketViewer extends StatefulWidget {
  const _TicketViewer({required this.store, required this.purchase});

  final AppStore store;
  final Purchase purchase;

  @override
  State<_TicketViewer> createState() => _TicketViewerState();
}

class _TicketViewerState extends State<_TicketViewer> {
  bool _removed = false;

  Future<void> _share() async {
    final bytes = ticketBytes(widget.purchase.ticketPhoto);
    if (bytes == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('La foto no se puede leer para compartir.')));
      return;
    }
    await sharePng(
        bytes,
        'ticket-valorave-${fmtDate(widget.purchase.date).replaceAll(' ', '-')}.png');
  }

  Future<void> _removePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar la foto del ticket?'),
        content: const Text(
            'La compra y sus montos se quedan intactos; solo se quita la foto del recibo.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Quitar foto')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    widget.store.updatePurchase(
        widget.purchase.id, widget.purchase.copyWith(clearTicket: true));
    if (!mounted) return;
    setState(() => _removed = true);
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Foto quitada. La compra sigue intacta.')));
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    final bytes = _removed ? null : ticketBytes(p.ticketPhoto);

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(fmtDateLong(p.date),
              style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: Colors.white)),
          if (p.store?.isNotEmpty == true)
            Text(p.store!,
                style: TextStyle(
                    fontSize: 11,
                    color: Colors.white.withValues(alpha: 0.72))),
        ]),
        actions: [
          IconButton(
            tooltip: 'Compartir imagen',
            onPressed: bytes == null ? null : _share,
            icon: const Icon(Icons.ios_share_rounded),
          ),
          IconButton(
            tooltip: 'Quitar foto de la compra',
            onPressed: _removePhoto,
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: Column(children: [
        Expanded(
          child: bytes == null
              ? Center(
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.image_not_supported_outlined,
                        size: 42, color: Colors.white.withValues(alpha: 0.5)),
                    const SizedBox(height: 10),
                    Text('Esta foto ya no está disponible.',
                        style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.72))),
                  ]),
                )
              : InteractiveViewer(
                  panEnabled: true,
                  maxScale: 8,
                  child: Center(child: Image.memory(bytes, fit: BoxFit.contain)),
                ),
        ),
        // Franja de contexto de la compra: total pagado + equivalente Bs +
        // tasa usada, tinta clara sobre negro.
        Container(
          width: double.infinity,
          color: Colors.black,
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('TOTAL PAGADO',
                style: VeText.labelCaps(
                    9, color: Colors.white.withValues(alpha: 0.55))),
            const SizedBox(height: 3),
            Text(
              '${fmtMoney(p.paidUSD, Currency.usd)} · ${fmtMoney(p.totalBS, Currency.ves)} · 1 USD = ${fmtRate(p.rate)}',
              style: VeText.displayNum(16, color: Colors.white),
            ),
            const SizedBox(height: 2),
            Text(
              'Zoom con dos dedos hasta 8× · la compra vive en Historial',
              style: TextStyle(
                  fontSize: 10.5,
                  color: Colors.white.withValues(alpha: 0.55)),
            ),
          ]),
        ),
      ]),
    );
  }
}
