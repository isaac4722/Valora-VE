/// ─── Hoja de Pago Móvil (v23 · comparativa CalculaYa 1.1.0) ─────────────────
/// «Pago Móvil» desde el Conversor cuando el par toca VES (v29 · H-29: con
/// el bolívar de destino cobra el RESULTADO; con el de origen, el MONTO
/// escrito): la hoja arma el mensaje de cobro con el monto en bolívares y
/// la cuenta elegida. v30 (H-43): solo cobra con cuentas en Bs
/// (`cobraEnBs`) — el Zelle, en dólares, no entra a esta hoja. Sin
/// cuentas: invita a configurarlas (Ajustes → Cuentas). Dato sensible:
/// el aviso de la hoja lo dice claro antes de compartir.
///
/// v29 (H-29 · regla global del dueño): DOS acciones — Compartir = IMAGEN
/// (tarjeta de marca PagoMovilShareCard 1080×1080 rasterizada offstage,
/// sin texto adjunto) y Copiar = TEXTO (portapapeles + aviso). Con el modo
/// «Mañana» del Conversor, el cobro viaja fechado («Fecha: DD/MM
/// (mañana)»).
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../services/sharing.dart' show sharePng;
import '../../widgets/share_card.dart' show renderPagoMovilSharePng;
import '../../widgets/ui.dart';
import '../../widgets/bank_badge.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorave/providers/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

/// Mensaje de cobro por Pago Móvil: monto es-VE + datos de la cuenta.
/// v30 (H-43): las líneas del TIPO salen de `dataLines` — la única
/// fuente de verdad (fila · copia · mensaje · tarjeta comparten texto).
/// Texto plano, sin marcas — lo pega cualquier chat.
/// v28/v29: símbolo SIEMPRE tras el número («Pago Móvil · 1.234,50 Bs»).
/// v29: con [para] (modo «Mañana»), el cobro viaja fechado.
String pagoMovilMessage(double montoBs, PayAccount a, {DateTime? para}) {
  final buf = StringBuffer(
    'Pago Móvil · ${fmtNum(montoBs, decimals: 2)} Bs',
  );
  if (para != null) {
    buf.write(
      '\nFecha: ${para.day.toString().padLeft(2, '0')}/'
      '${para.month.toString().padLeft(2, '0')} (mañana)',
    );
  }
  for (final (label, value) in a.dataLines) {
    buf.write('\n$label: $value');
  }
  return buf.toString();
}

/// Abre la hoja de Pago Móvil con [montoBs] ya convertido.
/// [para] (v29 · «Mañana»): fecha el cobro para el día siguiente.
Future<void> showPagoMovilSheet(
  BuildContext context, {
  required WidgetRef ref,
  required double montoBs,
  DateTime? para,
}) async {
  final store = ref.read(appStoreProvider);
  // v30 (H-43): la hoja cobra en BOLÍVARES — solo cuentas `cobraEnBs`
  // (pago móvil y transferencia). El Zelle (USD) no arma cobros aquí.
  final accounts = store.data.accounts.where((a) => a.cobraEnBs).toList();

  // v23.3 (pez 2-a P0-1): chrome del kit (showVeSheet — radio 14, asa,
  // cabecera 48 + ✕). v29 (H-29): título «Pago Móvil» a secas — el
  // verbo vive en los dos botones de la regla global.
  await showVeSheet<void>(
    context: context,
    title: 'Pago Móvil',
    builder: (ctx) => _PagoMovilSheet(
      montoBs: montoBs,
      accounts: accounts,
      para: para,
    ),
  );
}

class _PagoMovilSheet extends ConsumerStatefulWidget {
  const _PagoMovilSheet({
    required this.montoBs,
    required this.accounts,
    this.para,
  });

  final double montoBs;
  final List<PayAccount> accounts;

  /// Cobro planificado con la tasa de hoy (v29 · H-22 «Mañana»).
  final DateTime? para;

  @override
  ConsumerState<_PagoMovilSheet> createState() => _PagoMovilSheetState();
}

class _PagoMovilSheetState extends ConsumerState<_PagoMovilSheet> {
  int _sel = 0;

  @override
  void initState() {
    super.initState();
    final i = widget.accounts.indexWhere((a) => a.isDefault);
    _sel = i < 0 ? 0 : i;
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final VeInk? ink = Theme.of(context).extension<VeInk>();

    // Sin cuentas: la hoja invita a configurarlas — un solo destino claro.
    if (widget.accounts.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              LucideIcons.smartphone,
              size: 30,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 10),
            const Text(
              'Agrega tu cuenta y el mensaje sale solo',
              style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Guarda tu pago móvil o tu transferencia una vez; después el '
              'Conversor arma el cobro por ti.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            VeBtn(
              variant: VeBtnVariant.primary,
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/ajustes/cuentas');
              },
              child: const Text('Ir a Ajustes'),
            ),
          ],
        ),
      );
    }

    final account = widget.accounts[_sel.clamp(0, widget.accounts.length - 1)];
    final msg = pagoMovilMessage(widget.montoBs, account, para: widget.para);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // El monto manda: cifra grande tabular en ReadWindow del sistema.
          // v29: el modo «Mañana» dice su intención al lado del cobro.
          ReadWindow(
            child: FittedBox(fit: BoxFit.scaleDown, alignment: Alignment.centerLeft, child: Text(
              '${fmtNum(widget.montoBs, decimals: 2)} Bs',
              maxLines: 1,
              style: VeText.displayNum(
                30,
                color: scheme.onSurface,
                weight: FontWeight.w700,
              ),
            )),
          ),
          if (widget.para != null) ...[
            const SizedBox(height: 6),
            Text(
              'Cobro planificado con la tasa de hoy',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
          const SizedBox(height: 10),
          if (widget.accounts.length > 1)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Wrap(
                spacing: 8,
                runSpacing: 6,
                children: [
                  for (final (i, a) in widget.accounts.indexed)
                    VeChip(
                      active: i == _sel,
                      onTap: () => setState(() => _sel = i),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          BankBadge(bank: a.bank, size: 16),
                          const SizedBox(width: 5),
                          Flexible(child: Text(a.displayLabel)),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: scheme.surfaceContainerLow,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(
              msg,
              style: const TextStyle(
                fontSize: 13.5,
                height: 1.5,
                fontFeatures: [FontFeature.tabularFigures()],
              ),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Icon(Icons.info_outline, size: 13, color: ink?.warn),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'Compartes tus datos de cobro con quien reciba el mensaje.',
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          // v29 (H-29 · regla global): Compartir = IMAGEN de marca;
          // Copiar = TEXTO. Ambas a todo lo ancho, como mandan los pies.
          Row(
            children: [
              Expanded(
                child: Semantics(
                  label: 'Compartir tarjeta de cobro',
                  child: VeBtn(
                    size: VeBtnSize.lg,
                    variant: VeBtnVariant.primary,
                    icon: LucideIcons.share2,
                    expands: true,
                    onPressed: () => _compartirTarjeta(account),
                    child: const Text('Compartir'),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Semantics(
                  label: 'Copiar mensaje de cobro',
                  child: VeBtn(
                    size: VeBtnSize.lg,
                    variant: VeBtnVariant.secondary,
                    icon: LucideIcons.copy,
                    expands: true,
                    onPressed: () => copiarAlPortapapeles(
                      context,
                      msg,
                      'Mensaje de cobro copiado',
                    ),
                    child: const Text('Copiar'),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Compartir = SOLO la imagen (v28/v29): la tarjeta de marca 1080×1080
  /// se rasteriza offstage y viaja por el share nativo sin texto adjunto.
  Future<void> _compartirTarjeta(PayAccount account) async {
    final png = await renderPagoMovilSharePng(
      context,
      montoBs: widget.montoBs,
      account: account,
      para: widget.para,
    );
    if (png == null) {
      if (mounted) {
        showToast(context, 'No pude generar la tarjeta', kind: ToastKind.warn);
      }
      return;
    }
    try {
      await sharePng(png, 'pago-movil-valorave.png');
    } catch (_) {
      // El share nativo falla (escritorio/pruebas): el cobro no se pierde —
      // el mensaje queda en el portapapeles como plan B honesto.
      if (mounted) {
        copiarAlPortapapeles(
          context,
          pagoMovilMessage(widget.montoBs, account, para: widget.para),
          'No se pudo compartir; mensaje copiado',
        );
      }
    }
  }
}
