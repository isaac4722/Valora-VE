/// ─── Constancia mensual (§9.9 monthly-statement) ────────────────────────────
/// Scopes Mensual | Trimestral | Anual (flechas ciclan). v17.8: la
/// constancia es de COMPRAS (la rama «finanzas» se retiró con el módulo):
/// nº compras + total USD + total Bs ponderado + asiento por tienda.
/// Anexos trim/anual (tienda, top 6). Tres caminos NUNCA auto-print:
/// PNG 1080×1350 (4:5 real desde v31: 360×450 lógicos ×3) · Compartir · PDF.
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../../core/fmt.dart';
import '../../core/models.dart';
import 'constancia_pdf.dart';
import '../../core/theme.dart';
import '../../core/version.dart';
import '../../data/store.dart';
import '../../services/sharing.dart';
import '../../widgets/export_sheet.dart';
import '../../widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorave/providers/providers.dart';

// Tinta del papel: ES el token de marca primaryLight (una sola verdad en
// core/theme.dart) — antes un duplicado crudo Color(0xFF22354E) que podía
// derivar si el token cambiaba.
const kInkAccent = VeColors.primaryLight;
// v17.8: kInkPos/kInkNeg se retiraron con la constancia de finanzas (la
// constancia ahora es solo de compras); se conservan en el historial git.

class StatementScreen extends ConsumerStatefulWidget {
  const StatementScreen({super.key});

  @override
  ConsumerState<StatementScreen> createState() => _StatementScreenState();
}

class _StatementScreenState extends ConsumerState<StatementScreen> {
  int _scope = 0; // 0 mensual · 1 trimestral · 2 anual
  int _offset = 0; // hacia atrás desde hoy

  /// RepaintBoundary del documento: fuente REAL del PNG 1080×1350.
  final GlobalKey _docKey = GlobalKey();

  String get _scopeLabel => switch (_scope) {
    0 => 'Mensual',
    1 => 'Trimestral',
    _ => 'Anual',
  };

  String get _pngName => 'constancia-${_scopeLabel.toLowerCase()}-valorave.png';

  DateTimeRange get _range {
    final now = DateTime.now();
    switch (_scope) {
      case 0:
        final start = DateTime(now.year, now.month - _offset, 1);
        return DateTimeRange(
          start: start,
          end: DateTime(now.year, now.month - _offset + 1, 0),
        );
      case 1:
        final startMonth = now.month - _offset * 3;
        final start = DateTime(now.year, startMonth - 2, 1);
        return DateTimeRange(
          start: start,
          end: DateTime(now.year, startMonth + 1, 0),
        );
      default:
        return DateTimeRange(
          start: DateTime(now.year - _offset, 1, 1),
          end: DateTime(now.year - _offset, 12, 31),
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final store = ref.watch(appStoreProvider);
    final scheme = Theme.of(context).colorScheme;
    final range = _range;
    final purchases = store.purchases
        .where(
          (p) => !p.date.isBefore(range.start) && !p.date.isAfter(range.end),
        )
        .toList();

    final suffix = _scope == 0
        ? ''
        : ' — ${fmtMesCorto(range.end.month)} ${range.end.year}';
    final label =
        '${fmtMesCorto(range.start.month)} ${range.start.year}$suffix';

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Constancia'),
        actions: [
          IconButton(
            tooltip: 'Período anterior',
            icon: const Icon(Icons.chevron_left),
            onPressed: () => setState(() => _offset++),
          ),
          TextButton(
            onPressed: () => setState(() {
              _scope = (_scope + 1) % 3;
              _offset = 0;
            }),
            child: Text(_scopeLabel),
          ),
          IconButton(
            tooltip: 'Período siguiente',
            icon: const Icon(Icons.chevron_right),
            onPressed: _offset > 0 ? () => setState(() => _offset--) : null,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Documento: RepaintBoundary REAL (preview en pantalla). El PNG
          // del generador usa el MISMO widget compuesto off-stage (v18.0):
          // este preview es solo eso, preview — el share ya no depende de
          // que esta tarjeta siga montada tras el scroll.
          RepaintBoundary(
            key: _docKey,
            child: StatementDoc(
              label: label,
              scopeLabel: _scopeLabel,
              purchases: purchases,
            ),
          ),
          const SizedBox(height: 16),
          // Camino ÚNICO de salida: menú propio texto/imagen/PDF con
          // compartir o descargar por formato (v17.2). Nunca auto-print ni
          // share directo.
          PrimaryButton(
            'Compartir o guardar…',
            icon: Icons.ios_share,
            onPressed: () =>
                unawaited(_shareMenu(context, store, range, label, purchases)),
          ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            icon: const Icon(Icons.print_outlined, size: 17),
            label: const Text('Imprimir'),
            onPressed: () => _printPdf(context, store, range, label, purchases),
          ),
        ],
      ),
    );
  }

  /// Genera el PNG de la constancia (v18.0): compone el documento
  /// OFF-STAGE (nunca depende del preview visible) y, si algo raro pasa,
  /// cae al boundary visible como último recurso.
  /// v31: 360 px LÓGICOS (la convención única de rasterizado) → 1080 px
  /// finales; el documento mide 450 de alto (4:5 → 1080×1350 real).
  Future<Uint8List?> _renderDocPng(
    DateTimeRange range,
    String label,
    List<Purchase> purchases,
  ) async {
    final off = await renderOffstagePng(
      context,
      constanciaPngCanvas(
        StatementDoc(label: label, scopeLabel: _scopeLabel, purchases: purchases),
      ),
      width: 360,
    );
    if (off != null) return off;
    return captureWidget(_docKey, targetWidth: 1080);
  }

  /// Exportación UNIFICADA (v19.8): texto · PNG · PDF, cada uno con
  /// compartir o guardar — el mismo componente de toda la app.
  /// v31: el PDF viaja por [pdfFormat] (MIME de documento, errores en
  /// cristiano) igual que el PNG y el CSV.
  Future<void> _shareMenu(
    BuildContext context,
    AppStore store,
    DateTimeRange range,
    String label,
    List<Purchase> purchases,
  ) async {
    await showExportSheet(
      context,
      ExportSpec(
        title: 'Constancia $_scopeLabel · $label',
        subtitle: 'Elige el formato; luego compartes o guardas',
        formats: [
          textFormat(
            hint: 'Resumen legible para pegar donde quieras',
            fileName: 'constancia-valorave.txt',
            text: () => _plainText(range, label, purchases),
          ),
          pngFormat(
            hint: 'PNG de la constancia (1080×1350, 4:5) para redes o chat',
            fileName: _pngName,
            build: () => _renderDocPng(range, label, purchases),
          ),
          pdfFormat(
            hint: 'Documento A4 con encabezado, tabla y numeración de página',
            fileName: 'constancia-valorave.pdf',
            build: () async {
              try {
                final doc = await _buildPdf(store, range, label, purchases);
                return await doc.save();
              } catch (_) {
                return null; // un fallo de generación jamás tumba la app
              }
            },
          ),
        ],
      ),
    );
  }

  /// Texto plano del período (opción «Texto» del menú).
  String _plainText(
    DateTimeRange range,
    String label,
    List<Purchase> purchases,
  ) {
    final b = StringBuffer('Constancia $_scopeLabel · $label — ValoraVE\n\n');
    b
      ..writeln('Compras: ${purchases.length}')
      ..writeln(
        'Total USD: ${fmtUSD(purchases.fold<double>(0, (a, p) => a + p.totalUSD))}',
      )
      ..writeln(
        'Total Bs ponderado: ${fmtNum(purchases.fold<double>(0, (a, p) => a + p.totalBS))} Bs',
      );
    return b.toString();
  }

  Future<void> _printPdf(
    BuildContext context,
    AppStore store,
    DateTimeRange range,
    String label,
    List<Purchase> purchases,
  ) async {
    // v31: la impresión también se protege — un fallo de fuentes o de
    // motor no puede tumbar la hoja; el usuario recibe un aviso humano.
    try {
      final doc = await _buildPdf(store, range, label, purchases);
      await Printing.layoutPdf(onLayout: (_) async => await doc.save());
    } catch (_) {
      if (context.mounted) {
        showToast(context, 'No pude preparar el PDF. Intenta de nuevo.');
      }
    }
  }

  /// PDF de calidad (v17.2 · v31): delega en [buildConstanciaPdf] —
  /// ver constancia_pdf.dart (encabezado y pie en TODAS las páginas,
  /// fuentes de la app, márgenes uniformes de 44 pt, tabla con cabecera
  /// repetida y numeración «Página n»).
  Future<pw.Document> _buildPdf(
    AppStore store,
    DateTimeRange range,
    String label,
    List<Purchase> purchases,
  ) =>
      buildConstanciaPdf(
        scopeLabel: _scopeLabel,
        label: label,
        purchases: purchases,
      );
}

/// ─── Documento de la constancia (v18.0: público y reutilizable) ───────────
/// El MISMO widget sirve de preview en pantalla Y de fuente del PNG
/// off-stage: una sola definición, cero deriva visual entre lo que se ve
/// y lo que se comparte.
class StatementDoc extends ConsumerWidget {
  const StatementDoc({
    super.key,
    required this.label,
    required this.scopeLabel,
    required this.purchases,
  });

  final String label;
  final String scopeLabel;
  final List<Purchase> purchases;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final totalBs = purchases.fold<double>(0, (a, p) => a + p.totalBS);
    final byStore = <String, double>{};
    for (final p in purchases) {
      final s = p.store ?? 'Sin tienda';
      byStore[s] = (byStore[s] ?? 0) + p.totalUSD;
    }
    final sorted = byStore.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return Container(
      // v31: el documento es RESPONSIVO (se apila en pantalla, se reparte
      // en el lienzo fijo 360×450 del PNG). El 4:5 exacto lo pone el
      // lienzo [constanciaPngCanvas], no la tarjeta: Spacer/minHeight
      // rompían en contenedores de altura no acotada (ListView/Overlay).
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: scheme.outlineVariant),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Grupo 1: cabecera + asientos (se apilan natural).
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: kInkAccent,
                  borderRadius: BorderRadius.circular(9),
                ),
                alignment: Alignment.center,
                child: const Text(
                  'V',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 17,
                    fontWeight: FontWeight.w700,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'ValoraVE',
                    style: VeText.displayNum(17, color: kInkAccent),
                  ),
                  Text(
                    'Constancia de compras',
                    style: const TextStyle(
                      fontSize: 11,
                      color: Colors.black54,
                    ),
                  ),
                ],
              ),
              const Spacer(),
              // Flexible: en trimestral/anual el rótulo supera el ancho del
              // documento a textScale >=1.25 (fix overflow).
              Flexible(
                child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
                  label.toUpperCase(),
                  maxLines: 1,
                  style: VeText.labelCaps(11, color: Colors.black54),
                )),
              ),
            ],
          ),
          const Divider(height: 26),
          if (purchases.isEmpty) ...[
            const StatementRow(label: 'Compras', value: '0', color: kInkAccent),
            const SizedBox(height: 10),
          ] else ...[
            StatementRow(
              label: 'Compras',
              value: '${purchases.length}',
              color: kInkAccent,
              big: true,
            ),
            StatementRow(
              label: 'Total USD',
              value: fmtUSD(
                purchases.fold<double>(0, (a, p) => a + p.totalUSD),
              ),
              color: kInkAccent,
            ),
            StatementRow(
              label: 'Total Bs ponderado',
              value: '${fmtNum(totalBs)} Bs',
              color: kInkAccent,
            ),
            const SizedBox(height: 10),
            for (final e in sorted.take(6))
              StatementRow(
                label: e.key,
                value: fmtUSD(e.value),
                color: Colors.black87,
              ),
          ],
            ],
          ),
          const SizedBox(height: 16),
          // black54: black38 daba contraste ≈2.7:1 sobre papel — ilegible
          // en el PNG compartido (piso WCAG para texto pequeño: 4.5:1).
          Text(
            'Generado ${fmtDateTime(DateTime.now())} · ValoraVE $kAppVersionVisible',
            style: const TextStyle(fontSize: 11, color: Colors.black54),
          ),
        ],
      ),
    );
  }
}

/// Lienzo del PNG de la constancia (v31): 360×450 lógicos → 1080×1350
/// físicos (4:5 EXACTO) con la convención única de rasterizado. El MISMO
/// [StatementDoc] sirve de preview en pantalla (responsivo) y de fuente
/// del PNG (repartido en el lienzo): una sola definición.
Widget constanciaPngCanvas(StatementDoc doc) =>
    SizedBox(width: 360, height: 450, child: doc);

/// Fila asiento del documento (rótulo · línea punteada · cifra).
class StatementRow extends ConsumerWidget {
  const StatementRow({
    super.key,
    required this.label,
    required this.value,
    required this.color,
    this.big = false,
  });

  final String label;
  final String value;
  final Color color;
  final bool big;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          // Flexible + ellipsis: el label es el nombre de tienda (texto
          // libre) y desbordaba el documento a textScale >=1.2 (fix).
          Flexible(
            child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
              label,
              maxLines: 1,
              style: const TextStyle(fontSize: 13.5, color: Colors.black54),
            )),
          ),
          const SizedBox(width: 6),
          const Expanded(child: LedgerLine()),
          Text(
            value,
            style: TextStyle(
              fontFamily: 'SpaceGrotesk',
              fontSize: big ? 17 : 13.5,
              fontWeight: FontWeight.w700,
              fontFeatures: const [FontFeature.tabularFigures()],
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

/// Línea punteada del documento.
class LedgerLine extends ConsumerWidget {
  const LedgerLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return LayoutBuilder(
      builder: (context, c) {
        final count = (c.maxWidth / 5).floor().clamp(0, 60);
        return Row(
          children: [
            for (var i = 0; i < count; i++)
              Expanded(
                child: Container(
                  height: 1.2,
                  margin: const EdgeInsets.symmetric(horizontal: 1),
                  decoration: const BoxDecoration(
                    color: Color(0x33000000),
                    shape: BoxShape.circle,
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
