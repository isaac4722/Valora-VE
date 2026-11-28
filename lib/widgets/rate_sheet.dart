/// ─── Selector de TASA visual (v19.0, orden del dueño) ────────────────────────
/// La tasa se elige con UNA forma visual en TODA la app (selector aparte del
/// selector de Moneda): filas [Bandera] [Nombre] [Precio + símbolo] con el
/// color de fondo ESTABLECIDO por categoría — oficial verde · promedio ámbar
/// · paralelo rojo · manual violeta.
///
/// Piezas:
/// · [RateTile]: la fila reutilizable (Inicio · hoja · donde haga falta).
/// · [showRateSheet]: hoja modal con las fuentes de UNA divisa (conversor,
///   Lista, Ajustes). La fila Manual abre el editor INLINE: la tasa manual
///   se fija desde cualquier pantalla, sin ir a Ajustes (encargo del dueño).
/// · [showManualRateEditor]: editor MoneyField (fijar / limpiar).
library;

import 'package:flutter/material.dart';

import '../core/currencies.dart';
import '../core/fmt.dart';
import '../core/theme.dart';
import '../data/store.dart';
import 'ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorave/providers/providers.dart';

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
class RateTile extends ConsumerWidget {
  const RateTile({
    super.key,
    required this.sourceId,
    required this.rate,
    required this.selected,
    required this.onTap,
    this.onEdit,
    this.freshness,
    this.showFlag = true,
    this.precision,
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

  /// Decimales de la tasa (v27 · precisión elegida por el usuario).
  final int? precision;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = Theme.of(context).colorScheme;
    final s = RateSource.of(sourceId);
    if (s == null) return const SizedBox.shrink();
    final ink = categoryInk(context, s.category);
    final has = rate > 0;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Material(
        // v34 · código de colores del dueño: el NOMBRE lleva la tinta de su
        // categoría (verde oficial · rojo mercado · naranja promedio · morado
        // manual) y la fila ACTIVA se marca con un DIFUMINADO del mismo
        // color que se desvanece hacia la derecha + barra de acento a la
        // izquierda. Sin etiquetas secundarias: el color dice el tipo.
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: selected
                ? BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    gradient: LinearGradient(
                      begin: Alignment.centerLeft,
                      end: Alignment.centerRight,
                      colors: [
                        ink.withValues(alpha: 0.16),
                        ink.withValues(alpha: 0.02),
                      ],
                    ),
                    border: Border(left: BorderSide(color: ink, width: 3)),
                  )
                : null,
            child: Row(
              children: <Widget>[
                if (showFlag) ...<Widget>[
                  Flag(s.currency, size: 22),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      Row(
                        children: <Widget>[
                          Flexible(
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              alignment: Alignment.centerLeft,
                              child: Text(
                                s.edgeName,
                                style: TextStyle(
                                  fontSize: 13.5,
                                  fontWeight: FontWeight.w800,
                                  color: has ? ink : scheme.onSurfaceVariant,
                                ),
                              ),
                            ),
                          ),
                          if (selected) ...<Widget>[
                            const SizedBox(width: 6),
                            Icon(
                              Icons.check_circle_rounded,
                              size: 14,
                              color: ink,
                            ),
                          ],
                        ],
                      ),
                      const SizedBox(height: 1),
                      // v34 · sin etiqueta secundaria: bajo el nombre vive
                      // SOLO la fecha de actualización (o el hint de acción
                      // si no hay valor). El tipo lo dice el color.
                      FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: Text(
                          has
                              ? (freshness ?? s.detail)
                              : (s.category == SourceCategory.manual
                                    ? 'Fija tu tasa con el lápiz'
                                    : 'Sin tasa aún para esta fuente'),
                          maxLines: 1,
                          style: TextStyle(
                            fontSize: 11,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: <Widget>[
                    Text(
                      has
                          ? (s.currency == Currency.eur
                                ? fmtEurRate(rate)
                                : (precision == null
                                      ? fmtRate(rate)
                                      : fmtRatePrecise(rate, precision!)))
                          : '—',
                      style: VeText.displayNum(
                        17,
                        color: has ? scheme.onSurface : scheme.onSurfaceVariant,
                      ),
                    ),
                    Text(
                      s.quote.symbol,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: ink,
                      ),
                    ),
                  ],
                ),
                if (s.category == SourceCategory.manual &&
                    onEdit != null) ...<Widget>[
                  const SizedBox(width: 6),
                  // v23.3 (pez 2-a P1-1): pista 44×44 + Semantics — el
                  // lápiz era un blanco de ~25 dp.
                  Semantics(
                    button: true,
                    label: 'Editar tasa manual',
                    child: InkWell(
                      onTap: onEdit,
                      borderRadius: BorderRadius.circular(999),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Center(
                          child: Icon(
                            Icons.edit_outlined,
                            size: 17,
                            color: scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ),
                  ),
                ] else
                  // v28 · affordance visible: chevron al final de TODA fila
                  // clicable — nunca parece texto plano (orden del dueño).
                  Padding(
                    padding: const EdgeInsets.only(left: 4),
                    child: Icon(
                      Icons.chevron_right_rounded,
                      size: 17,
                      color: scheme.onSurfaceVariant.withValues(
                        alpha: has ? 0.7 : 0.35,
                      ),
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

/// Selector de TASA (hoja modal): las fuentes de [currency] como filas
/// visuales con precio y categoría. La fila Manual abre el editor inline y
/// al guardar queda ACTIVA. [onPick] recibe el id elegido (y la hoja cierra).
Future<void> showRateSheet(
  BuildContext context, {
  required WidgetRef ref,
  required Currency currency,
  required RateContext ctx,
  required String currentId,
  required ValueChanged<String> onPick,
  String? title,
}) async {
  final store = ref.read(appStoreProvider);
  final sources = RateSource.sourcesFor(currency);
  // v23.3 (pez 2-a P0-1): chrome unificado del kit — showVeHalfSheet
  // (radio 14, asa, cabecera 48 + ✕, cuerpo con el controlador de la hoja).
  // Antes era un showModalBottomSheet crudo con radio 20, sin asa ni ✕ y
  // cabecera artesanal: el «mismo menú» con otra piel.
  final picked = await showVeHalfSheet<String>(
    context: context,
    title: title ?? 'Fuente de tasa · ${currency.label}',
    trailing: Flag(currency, size: 18),
    builder: (sheetCtx) => Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        for (final s in sources)
          RateTile(
            sourceId: s.id,
            rate: ctx.rate(s.id),
            selected: s.id == currentId,
            freshness: _freshnessOf(store, s.id),
            onTap: () async {
              if (s.category == SourceCategory.manual && ctx.rate(s.id) <= 0) {
                // Manual sin valor: el editor ES la selección.
                final saved = await showManualRateEditor(
                  sheetCtx,
                  ref: ref,
                  sourceId: s.id,
                );
                if (saved && sheetCtx.mounted) {
                  Navigator.of(sheetCtx).pop(s.id);
                }
                return;
              }
              Navigator.of(sheetCtx).pop(s.id);
            },
            onEdit: s.category == SourceCategory.manual
                ? () async {
                    final saved = await showManualRateEditor(
                      sheetCtx,
                      ref: ref,
                      sourceId: s.id,
                    );
                    if (saved && sheetCtx.mounted) {
                      Navigator.of(sheetCtx).pop(s.id);
                    }
                  }
                : null,
          ),
        const SizedBox(height: 6),
      ],
    ),
  );
  if (picked != null) onPick(picked);
}

String? _freshnessOf(AppStore store, String id) {
  // v34 · fix del «hace 9 horas» (hallazgo del dueño): la frescura que ve
  // el usuario es la de la ÚLTIMA CONSULTA del tablero (fetchedAt) — la
  // fecha de publicación de la API (updatedAt, p. ej. BCV 1 vez al día)
  // nunca se movía al actualizar a mano y el sello quedaba clavado.
  final fetched = store.board.fetchedAt;
  if (fetched != null) return timeAgo(fetched);
  final e = store.board.sources[id];
  return e == null ? null : timeAgo(e.updatedAt);
}

/// Editor de tasa manual (v19, encargo del dueño): MoneyField con formato
/// de miles en vivo + guardar/limpiar. Devuelve true si se guardó un valor.
Future<bool> showManualRateEditor(
  BuildContext context, {
  required WidgetRef ref,
  required String sourceId,
}) async {
  final s = RateSource.of(sourceId);
  if (s == null) return false;
  final store = ref.read(appStoreProvider);
  final current = store.data.manualRates[sourceId];

  final saved = await showDialog<bool>(
    context: context,
    builder: (ctx) => _ManualRateDialog(sourceId: sourceId, initial: current),
  );
  if (saved != true) return false;
  // Tras el diálogo el valor ya quedó en el store (el diálogo guarda).
  return (store.data.manualRates[sourceId] ?? 0) > 0;
}

class _ManualRateDialog extends ConsumerStatefulWidget {
  const _ManualRateDialog({required this.sourceId, this.initial});

  final String sourceId;
  final double? initial;

  @override
  ConsumerState<_ManualRateDialog> createState() => _ManualRateDialogState();
}

class _ManualRateDialogState extends ConsumerState<_ManualRateDialog> {
  late double _value = widget.initial ?? 0;

  @override
  Widget build(BuildContext context) {
    final store = ref.read(appStoreProvider);
    final s = RateSource.of(widget.sourceId)!;
    return AlertDialog(
      title: Text('Tasa manual ${s.currency.code}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          MoneyField(
            initialText: widget.initial == null
                ? ''
                : fmtNum(widget.initial!, decimals: 4),
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
              fontSize: 11,
              height: 1.4,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
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
