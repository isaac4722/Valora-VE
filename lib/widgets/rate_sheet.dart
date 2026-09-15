/// ─── Selector de TASA visual (v19.0, orden del dueño) ────────────────────────
/// La tasa se elige con UNA forma visual en TODA la app (selector aparte del
/// selector de Moneda): filas [Bandera] [Nombre] [Precio + símbolo] con el
/// color de fondo ESTABLECIDO por categoría — oficial verde · promedio ámbar
/// · paralelo rojo · manual violeta.
///
/// Piezas:
/// · [RateTile]: la fila reutilizable (Inicio · hoja · donde haga falta).
/// · [RateGroupHeader]: encabezado «USD» / «EUR» de la lista agrupada.
/// · [showRateSheet]: hoja modal con las fuentes de UNA divisa (conversor,
///   Lista, Ajustes). La fila Manual abre el editor INLINE: la tasa manual
///   se fija desde cualquier pantalla, sin ir a Ajustes (encargo del dueño).
/// · [showManualRateEditor]: editor MoneyField (fijar / limpiar).
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/currencies.dart';
import '../core/fmt.dart';
import '../core/theme.dart';
import '../data/store.dart';
import 'ui.dart';

/// Tinta de categoría (colores establecidos de la app).
Color categoryInk(BuildContext context, SourceCategory cat) {
  final VeInk sem = VeColors.of(context);
  return switch (cat) {
    SourceCategory.official => sem.pos,
    SourceCategory.mixed => sem.warn,
    SourceCategory.parallel => sem.neg,
    SourceCategory.manual => sem.manual,
  };
}

/// Fila de tasa: [Bandera] [Nombre + detalle] [Precio + símbolo], fondo con
/// el color de categoría y estado «activa» (borde + check).
class RateTile extends StatelessWidget {
  const RateTile({
    super.key,
    required this.sourceId,
    required this.rate,
    required this.selected,
    required this.onTap,
    this.onEdit,
    this.freshness,
    this.showFlag = true,
  });

  final String sourceId;

  /// Valor de la tasa (<= 0 → «sin definir», fila atenuada).
  final double rate;
  final bool selected;
  final VoidCallback onTap;

  /// Acción de edición (solo filas manuales: abre el editor inline).
  final VoidCallback? onEdit;

  /// Texto de frescura («hace 5 min») — opcional.
  final String? freshness;
  final bool showFlag;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final s = RateSource.of(sourceId);
    if (s == null) return const SizedBox.shrink();
    final ink = categoryInk(context, s.category);
    final has = rate > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      child: Material(
        color: has
            ? ink.withValues(alpha: selected ? 0.14 : 0.07)
            : scheme.surfaceContainerHigh.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: selected ? Border.all(color: ink, width: 1.4) : null,
            ),
            child: Row(children: <Widget>[
              if (showFlag) ...<Widget>[
                Flag(s.currency, size: 22),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Row(children: <Widget>[
                      Flexible(
                        child: Text(
                          s.edgeName,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: has ? scheme.onSurface : scheme.onSurfaceVariant),
                        ),
                      ),
                      if (selected) ...<Widget>[
                        const SizedBox(width: 6),
                        Icon(Icons.check_circle_rounded, size: 15, color: ink),
                      ],
                    ]),
                    const SizedBox(height: 1),
                    Text(
                      has
                          ? (freshness ?? s.detail)
                          : 'Toca el lápiz para fijar tu tasa',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 10.5,
                          color: has
                              ? scheme.onSurfaceVariant
                              : scheme.onSurfaceVariant.withValues(alpha: 0.8)),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: <Widget>[
                Text(
                  has
                      ? (s.currency == Currency.eur ? fmtEurRate(rate) : fmtRate(rate))
                      : '—',
                  style: VeText.displayNum(17,
                      color: has ? scheme.onSurface : scheme.onSurfaceVariant),
                ),
                Text(
                  s.quote.symbol,
                  style: TextStyle(
                      fontSize: 10.5, fontWeight: FontWeight.w700, color: ink),
                ),
              ]),
              if (s.category == SourceCategory.manual && onEdit != null) ...<Widget>[
                const SizedBox(width: 6),
                InkWell(
                  onTap: onEdit,
                  borderRadius: BorderRadius.circular(999),
                  child: Padding(
                    padding: const EdgeInsets.all(5),
                    child: Icon(Icons.edit_outlined,
                        size: 15, color: scheme.onSurfaceVariant),
                  ),
                ),
              ] else
                const SizedBox(width: 8),
            ]),
          ),
        ),
      ),
    );
  }
}

/// Encabezado de grupo de la lista de cotización: bandera + código + regla.
class RateGroupHeader extends StatelessWidget {
  const RateGroupHeader(this.currency, {super.key, this.hint});

  final Currency currency;

  /// Pista del grupo (p. ej. «1 USD = X», «aristas del euro»).
  final String? hint;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 6, left: 10, right: 10),
      child: Row(children: <Widget>[
        Flag(currency, size: 16),
        const SizedBox(width: 7),
        Text(
          currency.code,
          style: TextStyle(
            fontFamily: 'SpaceGrotesk',
            fontSize: 12,
            fontWeight: FontWeight.w800,
            letterSpacing: 1.1,
            color: scheme.onSurface,
          ),
        ),
        if (hint != null) ...<Widget>[
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              hint!,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
            ),
          ),
        ],
        const SizedBox(width: 8),
        const Expanded(child: Divider(height: 1)),
      ]),
    );
  }
}

/// Selector de TASA (hoja modal): las fuentes de [currency] como filas
/// visuales con precio y categoría. La fila Manual abre el editor inline y
/// al guardar queda ACTIVA. [onPick] recibe el id elegido (y la hoja cierra).
Future<void> showRateSheet(
  BuildContext context, {
  required Currency currency,
  required RateContext ctx,
  required String currentId,
  required ValueChanged<String> onPick,
  String? title,
}) async {
  final store = context.read<AppStore>();
  final sources = RateSource.sourcesFor(currency);
  final picked = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        padding: const EdgeInsets.symmetric(vertical: 8),
        children: <Widget>[
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 10),
            child: Row(children: <Widget>[
              Flag(currency, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title ?? 'Fuente de tasa · ${currency.label}',
                  style: VeText.labelCaps(10.5, color: Theme.of(sheetCtx).colorScheme.primary),
                ),
              ),
            ]),
          ),
          for (final s in sources)
            RateTile(
              sourceId: s.id,
              rate: ctx.rate(s.id),
              selected: s.id == currentId,
              freshness: _freshnessOf(store, s.id),
              onTap: () async {
                if (s.category == SourceCategory.manual && ctx.rate(s.id) <= 0) {
                  // Manual sin valor: el editor ES la selección.
                  final saved = await showManualRateEditor(sheetCtx, sourceId: s.id);
                  if (saved && sheetCtx.mounted) Navigator.of(sheetCtx).pop(s.id);
                  return;
                }
                Navigator.of(sheetCtx).pop(s.id);
              },
              onEdit: s.category == SourceCategory.manual
                  ? () async {
                      final saved =
                          await showManualRateEditor(sheetCtx, sourceId: s.id);
                      if (saved && sheetCtx.mounted) Navigator.of(sheetCtx).pop(s.id);
                    }
                  : null,
            ),
          const SizedBox(height: 6),
        ],
      ),
    ),
  );
  if (picked != null) onPick(picked);
}

String? _freshnessOf(AppStore store, String id) {
  final e = store.board.sources[id];
  return e == null ? null : timeAgo(e.updatedAt);
}

/// Editor de tasa manual (v19, encargo del dueño): MoneyField con formato
/// de miles en vivo + guardar/limpiar. Devuelve true si se guardó un valor.
Future<bool> showManualRateEditor(
  BuildContext context, {
  required String sourceId,
}) async {
  final s = RateSource.of(sourceId);
  if (s == null) return false;
  final store = context.read<AppStore>();
  final current = store.data.manualRates[sourceId];

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ManualRateDialog(
      sourceId: sourceId,
      initial: current,
    ),
  );
  if (saved != true) return false;
  // Tras el diálogo el valor ya quedó en el store (el diálogo guarda).
  return (store.data.manualRates[sourceId] ?? 0) > 0;
}

class _ManualRateDialog extends StatefulWidget {
  const _ManualRateDialog({required this.sourceId, this.initial});

  final String sourceId;
  final double? initial;

  @override
  State<_ManualRateDialog> createState() => _ManualRateDialogState();
}

class _ManualRateDialogState extends State<_ManualRateDialog> {
  late double _value = widget.initial ?? 0;

  @override
  Widget build(BuildContext context) {
    final store = context.read<AppStore>();
    final s = RateSource.of(widget.sourceId)!;
    return AlertDialog(
      title: Text('Tasa manual ${s.currency.code}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MoneyField(
            initialText:
                widget.initial == null ? '' : fmtNum(widget.initial!, decimals: 4),
            autofocus: true,
            // setState: sin él, «Guardar» no se rehabilita al escribir (el
            // árbol del diálogo no se reconstruye solo).
            onChanged: (v) => setState(() => _value = v),
            decoration: InputDecoration(
              hintText: '1 ${s.base.code} = ? ${s.quote.code}',
              suffixText: s.quote.code,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Tu tasa vive solo en este teléfono y entra al cálculo al '
            'momento. No necesita conexión.',
            style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: Theme.of(context).colorScheme.onSurfaceVariant),
          ),
        ],
      ),
      actions: <Widget>[
        if ((widget.initial ?? 0) > 0)
          TextButton(
            onPressed: () {
              store.setManualRate(widget.sourceId, 0);
              Navigator.of(context).pop(false);
            },
            child: const Text('Limpiar'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _value <= 0
              ? null
              : () {
                  store.setManualRate(widget.sourceId, _value);
                  Navigator.of(context).pop(true);
                },
          child: const Text('Guardar'),
        ),
      ],
    );
  }
}
