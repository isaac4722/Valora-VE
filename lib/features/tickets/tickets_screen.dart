/// ─── Tickets · Galería de fotos de recibos (dp6, módulo 13 · TASK-34 p10) ────
/// Presentación del prototipo web: grilla de tarjetas con la foto en 4:3,
/// tienda en semibold y fecha · total en tabular; tile punteado «Agregar»
/// que adjunta una foto a una compra EXISTENTE del historial (mejora real
/// sobre el prototipo: allí la foto solo se toma al cerrar la compra).
/// Visor a pantalla completa con zoom 8×, compartir imagen y quitar foto
/// de la compra (la compra nunca se borra desde aquí). Foto perdida →
/// estado honesto.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/currencies.dart';
import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/shad_theme.dart' show kShadRadius;
import '../../core/theme.dart';
import '../../data/store.dart';
import '../../services/photo_compress.dart';
import '../../services/sharing.dart';
import '../../widgets/ui.dart';
import '../lista/checkout_modal.dart' show photoToDataUrl;

/// Extrae los bytes de un data URL 'data:image/...;base64,…' (o base64
/// crudo). Devuelve null si no se puede decodificar — la celda muestra el
/// estado «imagen rota» en vez de romper la grilla.

class TicketsScreen extends StatelessWidget {
  const TicketsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    final shad = ShadTheme.of(context).colorScheme;
    final withPhoto =
        store.purchases
            .where((p) => p.ticketPhoto != null && p.ticketPhoto!.isNotEmpty)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    // Peso de las fotos: data URLs estimadas (length×0.75) + tamaño REAL
    // de los archivos tickets/*.jpg (v20.4: las fotos viven fuera del JSON).

    // v19: PushScreen — notch/barras respetadas + botón atrás visible.
    return PushScreen(
      title: 'Tickets',
      subtitle: 'Fotos de tus recibos, siempre a mano',
      child: VeEntry(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            VeTitle(
              // v21: cuando la galería está vacía NO se repite «Sin fotos
              // todavía» — el estado vacío de abajo ya dice cómo llenarla.
              sub: withPhoto.isEmpty
                  ? null
                  : _GallerySubtitle(withPhoto: withPhoto),
              child: const Text('Galería'),
            ),
            if (withPhoto.isEmpty && store.purchases.isNotEmpty)
              // Hay compras pero ninguna con foto: la acción directa.
              _NoTicketsYet(onAdd: () => _addTicket(context, store))
            else if (withPhoto.isEmpty)
              _NoTicketsYet(onAdd: null)
            else ...[
              // ── Grilla del prototipo: 2 columnas en móvil, 3 en tablet.
              LayoutBuilder(
                builder: (context, c) {
                  final cols = c.maxWidth >= 560 ? 3 : 2;
                  return GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                      crossAxisCount: cols,
                      mainAxisSpacing: 12,
                      crossAxisSpacing: 12,
                      // Tarjeta: imagen 4:3 + bloque de texto (~52 px).
                      childAspectRatio: cols == 2 ? 0.78 : 0.68,
                    ),
                    // +1 por el tile punteado «Agregar» al final.
                    itemCount: withPhoto.length + 1,
                    itemBuilder: (context, i) {
                      if (i == withPhoto.length) {
                        return _AddTile(
                          onTap: () => _addTicket(context, store),
                        );
                      }
                      final p = withPhoto[i];
                      return _TicketCard(
                        purchase: p,
                        onTap: () => _openViewer(context, store, p),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 16),
              Text(
                'La foto se comprime a 1024 px al guardarla. Cada ticket queda atado a su compra del historial.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: shad.mutedForeground,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  /// Adjunta (o reemplaza) la foto de una compra existente: picker de
  /// compra → cámara → compresión 1024 px. El mismo conducto del checkout.
  void _addTicket(BuildContext context, AppStore store) {
    final candidates =
        store.purchases
            .where((p) => p.ticketPhoto == null || p.ticketPhoto!.isEmpty)
            .toList()
          ..sort((a, b) => b.date.compareTo(a.date));
    String selected = '';

    showVeSheet(
      context: context,
      title: 'Agregar ticket',
      footer: Builder(
        builder: (sheetCtx) => VeBtn(
          variant: VeBtnVariant.primary,
          size: VeBtnSize.lg,
          expands: true,
          icon: LucideIcons.camera,
          onPressed: () async {
            final purchaseId = selected.isEmpty ? null : selected;
            Navigator.of(sheetCtx).pop();
            await _pickAndAttach(context, store, purchaseId);
          },
          child: const Text('Tomar o elegir foto'),
        ),
      ),
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheet) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const VeEyebrow(child: Text('COMPRA ASOCIADA')),
            if (candidates.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 8),
                child: Text(
                  'Todas tus compras ya tienen ticket. Cierra una compra nueva desde Lista para adjuntar otra foto.',
                ),
              )
            else ...[
              VeGroup(
                semantic: 'Compras sin ticket',
                children: [
                  VeRow(
                    label: const Text('Sin compra (suelta)'),
                    onTap: () => setSheet(() => selected = ''),
                    right: selected.isEmpty
                        ? const Icon(LucideIcons.check, size: 15)
                        : null,
                  ),
                  for (final p in candidates.take(12))
                    VeRow(
                      label: Text(
                        p.store?.isNotEmpty == true ? p.store! : 'Multitienda',
                      ),
                      sub: Text('${fmtDate(p.date)} · ${fmtUSD(p.totalUSD)}'),
                      onTap: () => setSheet(() => selected = p.id),
                      right: selected == p.id
                          ? const Icon(LucideIcons.check, size: 15)
                          : null,
                    ),
                ],
              ),
              const SizedBox(height: 10),
              const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'Solo se listan compras que aún no tienen ticket.',
                  style: TextStyle(fontFamily: 'Inter', fontSize: 12),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _pickAndAttach(
    BuildContext context,
    AppStore store,
    String? purchaseId,
  ) async {
    try {
      final picker = ImagePicker();
      final photo = await picker.pickImage(
        source: ImageSource.camera,
        maxWidth: 1024,
        maxHeight: 1024,
        imageQuality: 72,
      );
      if (photo == null) return;
      var bytes = await photo.readAsBytes();
      final compressed = await compressJpeg(bytes, quality: 72, maxDim: 1024);
      if (compressed != null) bytes = compressed;
      if (purchaseId != null) {
        final p = store.purchases.where((x) => x.id == purchaseId).firstOrNull;
        if (p != null) {
          // v20.4: la foto va a ARCHIVO (tickets/x.jpg) y la compra guarda
          // SOLO la ruta relativa. Si ya tenía foto-archivo, se borra la
          // anterior: cero huérfanos en el disco.
          final oldRef = p.ticketPhoto;
          final path = await saveTicketFile(bytes);
          if (path != null &&
              oldRef != null &&
              oldRef.isNotEmpty &&
              isTicketPath(oldRef)) {
            unawaited(deleteTicketFile(oldRef));
          }
          store.updatePurchase(
            p.id,
            p.copyWith(ticketPhoto: path ?? photoToDataUrl(bytes)),
          );
          if (context.mounted) {
            showToast(context, 'Ticket adjuntado', kind: ToastKind.ok);
          }
          return;
        }
      }
      // Sin compra asociada (suelta): no hay dónde colgarla en el modelo de
      // la app — se informa con honestidad en vez de perder la foto.
      if (context.mounted) {
        showToast(
          context,
          'Elige una compra para guardar la foto',
          kind: ToastKind.warn,
        );
      }
    } catch (_) {
      if (context.mounted) {
        showToast(context, 'No se pudo tomar la foto', kind: ToastKind.error);
      }
    }
  }

  void _openViewer(BuildContext context, AppStore store, Purchase p) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (_) => _TicketViewer(store: store, purchase: p),
      ),
    );
  }
}

/// Estado vacío punteado del prototipo: con compras → CTA directo a
/// adjuntar; sin compras → ir a la lista para cerrar la primera.
class _NoTicketsYet extends StatelessWidget {
  const _NoTicketsYet({this.onAdd});

  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    return VeEmpty(
      icon: LucideIcons.images,
      title: 'Sin tickets todavía',
      sub:
          'Fotografía el recibo al cerrar una compra (Checkout · Añadir foto) '
          'y aparecerá aquí, con su fecha y total.',
      action: onAdd == null
          ? VeBtn(
              size: VeBtnSize.sm,
              onPressed: () => context.push('/lista'),
              child: const Text('Ir a la lista de compras'),
            )
          : VeBtn(
              size: VeBtnSize.sm,
              icon: LucideIcons.camera,
              onPressed: onAdd,
              child: const Text('Adjuntar a una compra'),
            ),
    );
  }
}

/// Tarjeta del prototipo: imagen 4:3 (placeholder con degradado sutil e
/// icono receipt si no hay foto) + tienda semibold + fecha · total tabular.
/// El borde sube a line-strong al pasar el cursor (escritorio).
class _TicketCard extends StatefulWidget {
  const _TicketCard({required this.purchase, required this.onTap});

  final Purchase purchase;
  final VoidCallback onTap;

  @override
  State<_TicketCard> createState() => _TicketCardState();
}

class _TicketCardState extends State<_TicketCard> {
  bool _hover = false;

  /// Caché de la carga (data URL o archivo): el hover re-dispara build y un
  /// Future nuevo por build parpadearía el placeholder y releería el disco.
  late final Future<Uint8List?> _bytesFuture = loadTicketBytes(
    widget.purchase.ticketPhoto,
  );

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context).colorScheme;
    final scheme = Theme.of(context).colorScheme;
    final bool dark = Theme.of(context).brightness == Brightness.dark;

    return Semantics(
      button: true,
      label:
          'Ticket de ${widget.purchase.date.day} de ${kMeses[widget.purchase.date.month - 1]}'
          '${widget.purchase.store == null || widget.purchase.store!.isEmpty ? '' : ' · ${widget.purchase.store}'}',
      child: MouseRegion(
        onEnter: (_) => setState(() => _hover = true),
        onExit: (_) => setState(() => _hover = false),
        child: GestureDetector(
          onTap: widget.onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 140),
            clipBehavior: Clip.antiAlias,
            decoration: BoxDecoration(
              color: shad.card,
              borderRadius: BorderRadius.circular(kShadRadius),
              border: Border.all(
                color: _hover
                    ? (dark
                          ? VeColors.lineStrongDark
                          : VeColors.lineStrongLight)
                    : shad.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // ── Zona de imagen 4:3 (como el prototipo).
                Expanded(
                  child: Container(
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: dark
                            ? [
                                shad.muted,
                                shad.mutedForeground.withValues(alpha: 0.08),
                              ]
                            : [
                                shad.muted,
                                shad.mutedForeground.withValues(alpha: 0.14),
                              ],
                      ),
                    ),
                    // v20.4: la foto puede venir de ARCHIVO (async) o de
                    // un data URL legado — FutureBuilder resuelve ambos.
                    child: FutureBuilder<Uint8List?>(
                      future: _bytesFuture,
                      builder: (context, snap) {
                        final bytes = snap.data;
                        if (bytes == null) {
                          return Center(
                            child: Icon(
                              LucideIcons.imageOff,
                              size: 26,
                              color: shad.mutedForeground,
                            ),
                          );
                        }
                        return Image.memory(
                          bytes,
                          fit: BoxFit.cover,
                          gaplessPlayback: true,
                          errorBuilder: (_, _, _) => Icon(
                            LucideIcons.imageOff,
                            size: 26,
                            color: shad.mutedForeground,
                          ),
                        );
                      },
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.purchase.store?.isNotEmpty == true
                            ? widget.purchase.store!
                            : 'Compra',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: shad.foreground,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        '${fmtDate(widget.purchase.date)} · ${fmtUSD(widget.purchase.totalUSD)}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 12,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Tile punteado «Agregar» del prototipo (misma altura que las tarjetas).
class _AddTile extends StatelessWidget {
  const _AddTile({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final shad = ShadTheme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: 'Agregar foto de ticket',
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kShadRadius),
          ),
          foregroundDecoration: _DashedAddDecoration(
            color: shad.mutedForeground.withValues(alpha: 0.55),
            radius: kShadRadius,
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Spacer(),
              Icon(LucideIcons.camera, size: 24, color: shad.mutedForeground),
              const SizedBox(height: 6),
              Text(
                'Foto del ticket',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  color: shad.mutedForeground,
                ),
              ),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Agregar',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: shad.foreground,
                    ),
                  ),
                  Text(
                    'Zoom 1–8× al abrir',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 12,
                      color: shad.mutedForeground,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Marco punteado del tile «Agregar» (línea discontinua de 1.5 px).
class _DashedAddDecoration extends Decoration {
  const _DashedAddDecoration({required this.color, required this.radius});

  final Color color;
  final double radius;

  @override
  BoxPainter createBoxPainter([VoidCallback? onChanged]) {
    return _DashedAddPainter(color, radius);
  }
}

class _DashedAddPainter extends BoxPainter {
  _DashedAddPainter(this.color, this.radius);

  final Color color;
  final double radius;

  @override
  void paint(Canvas canvas, Offset offset, ImageConfiguration configuration) {
    if (configuration.size == null) return;
    final size = configuration.size!;
    final rect = offset & size;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final rrect = RRect.fromRectAndRadius(
      rect.deflate(0.75),
      Radius.circular(radius),
    );
    // Rejilla de guiones: camina el perímetro con dash 6 / gap 5.
    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      bool draw = true;
      while (dist < metric.length) {
        final len = draw ? 6.0 : 5.0;
        if (draw) {
          canvas.drawPath(
            metric.extractPath(dist, (dist + len).clamp(0, metric.length)),
            paint,
          );
        }
        dist += len;
        draw = !draw;
      }
    }
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
  Uint8List? _bytes;

  @override
  void initState() {
    super.initState();
    // v20.4: la foto puede vivir en archivo (async) o ser data URL legada.
    loadTicketBytes(widget.purchase.ticketPhoto).then((b) {
      if (mounted && !_removed) setState(() => _bytes = b);
    });
  }

  Future<void> _share() async {
    final bytes = _bytes ?? await loadTicketBytes(widget.purchase.ticketPhoto);
    if (bytes == null) {
      if (!mounted) return;
      showToast(
        context,
        'La foto no se puede leer para compartir.',
        kind: ToastKind.error,
      );
      return;
    }
    await sharePng(
      bytes,
      'ticket-valorave-${fmtDate(widget.purchase.date).replaceAll(' ', '-')}.png',
    );
  }

  Future<void> _removePhoto() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Quitar la foto del ticket?'),
        content: const Text(
          'La compra y sus montos se quedan intactos; solo se quita la foto del recibo.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('Quitar foto'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    // v20.4: si la foto era un ARCHIVO, se borra del disco (sin huérfanos).
    final ref = widget.purchase.ticketPhoto;
    if (ref != null && ref.isNotEmpty && isTicketPath(ref)) {
      unawaited(deleteTicketFile(ref));
    }
    widget.store.updatePurchase(
      widget.purchase.id,
      widget.purchase.copyWith(clearTicket: true),
    );
    if (!mounted) return;
    setState(() => _removed = true);
    showToast(
      context,
      'Foto quitada. La compra sigue intacta.',
      kind: ToastKind.ok,
    );
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.purchase;
    final bytes = _removed ? null : _bytes;

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // maxLines + ellipsis: fecha larga y tienda libre del usuario
            // envolvían y desbordaban la AppBar de 56 px (fix overflow).
            Text(
              fmtDateLong(p.date),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 14.5,
                fontWeight: FontWeight.w600,
                color: Colors.white,
              ),
            ),
            if (p.store?.isNotEmpty == true)
              Text(
                p.store!,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11,
                  color: Colors.white.withValues(alpha: 0.72),
                ),
              ),
          ],
        ),
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
      body: Column(
        children: [
          Expanded(
            child: bytes == null
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.image_not_supported_outlined,
                          size: 42,
                          color: Colors.white.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          'Esta foto ya no está disponible.',
                          style: TextStyle(
                            fontFamily: 'Inter',
                            fontSize: 12.5,
                            color: Colors.white.withValues(alpha: 0.72),
                          ),
                        ),
                      ],
                    ),
                  )
                : InteractiveViewer(
                    panEnabled: true,
                    maxScale: 8,
                    child: Center(
                      child: Image.memory(bytes, fit: BoxFit.contain),
                    ),
                  ),
          ),
          // Franja de contexto de la compra: total pagado + equivalente Bs +
          // tasa usada, tinta clara sobre negro.
          Container(
            width: double.infinity,
            color: Colors.black,
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL PAGADO',
                  style: VeText.labelCaps(
                    9,
                    color: Colors.white.withValues(alpha: 0.55),
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '${fmtMoney(p.paidUSD, Currency.usd)} · ${fmtMoney(p.totalBS, Currency.ves)} · 1 USD = ${fmtRate(p.rate)}',
                  style: VeText.displayNum(16, color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'Zoom con dos dedos hasta 8× · la compra vive en Historial',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 10.5,
                    color: Colors.white.withValues(alpha: 0.55),
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


/// Subtítulo de la galería: nº de fotos + peso total. Las fotos-archivo se
/// miden con su tamaño REAL en disco; las data URLs legadas se estiman
/// (length × 0.75 ≈ bytes crudos del base64).
class _GallerySubtitle extends StatelessWidget {
  const _GallerySubtitle({required this.withPhoto});

  final List<Purchase> withPhoto;

  @override
  Widget build(BuildContext context) {
    final n = withPhoto.length;
    return FutureBuilder<int>(
      future: _totalBytes(),
      builder: (context, snap) {
        final mb = (snap.data ?? 0) / 1048576;
        final peso = mb < 0.1 ? '≤0.1' : mb.toStringAsFixed(1);
        return Text('$n ${n == 1 ? 'foto' : 'fotos'} · $peso MB');
      },
    );
  }

  Future<int> _totalBytes() async {
    var total = 0;
    for (final p in withPhoto) {
      final ref = p.ticketPhoto!;
      if (isTicketPath(ref)) {
        total += await ticketFileSize(ref);
      } else {
        total += (ref.length * 0.75).round();
      }
    }
    return total;
  }
}
