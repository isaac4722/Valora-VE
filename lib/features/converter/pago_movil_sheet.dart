/// ─── Hoja de Pago Móvil (v23 · comparativa CalculaYa 1.1.0) ─────────────────
/// «Compartir Pago Móvil» desde el Conversor cuando el destino es VES: la
/// hoja arma el mensaje de cobro con el monto en bolívares y la cuenta
/// elegida. Sin cuentas: invita a configurarlas (Ajustes → Cuentas). Dato
/// sensible: el aviso de la hoja lo dice claro antes de compartir.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/fmt.dart';
import '../../core/models.dart';
import '../../core/theme.dart';
import '../../widgets/ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorave/providers/providers.dart';

/// Mensaje de cobro por Pago Móvil: monto es-VE + datos de la cuenta.
/// Texto plano, sin marcas — lo pega cualquier chat.
String pagoMovilMessage(double montoBs, PayAccount a) {
  final buf = StringBuffer('Pago Móvil — Bs ${fmtNum(montoBs, decimals: 2)}');
  buf.write('\nBanco: ${a.bank}');
  buf.write('\nCuenta ${a.typeLabel.toLowerCase()}: ${a.number}');
  if (a.docId.isNotEmpty) buf.write('\nCI: ${a.docId}');
  if (a.phone.isNotEmpty) buf.write('\nTeléfono: ${a.phone}');
  return buf.toString();
}

/// Abre la hoja de Pago Móvil con [montoBs] ya convertido.
Future<void> showPagoMovilSheet(
  BuildContext context, {
  required WidgetRef ref,
  required double montoBs,
}) async {
  final store = ref.read(appStoreProvider);
  final accounts = store.data.accounts;

  // v23.3 (pez 2-a P0-1): chrome del kit (showVeSheet — radio 14, asa,
  // cabecera 48 + ✕). Antes un modal crudo de radio 20 con título propio
  // dentro del cuerpo y sin pie del sistema.
  await showVeSheet<void>(
    context: context,
    title: 'Compartir Pago Móvil',
    builder: (ctx) => _PagoMovilSheet(montoBs: montoBs, accounts: accounts),
  );
}

class _PagoMovilSheet extends ConsumerStatefulWidget {
  const _PagoMovilSheet({required this.montoBs, required this.accounts});

  final double montoBs;
  final List<PayAccount> accounts;

  @override
  ConsumerState<_PagoMovilSheet> createState() => _PagoMovilSheetState();
}

class _PagoMovilSheetState extends ConsumerState<_PagoMovilSheet> {
  int _sel = 0;

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
              style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 6),
            Text(
              'Guarda tu banco, número, cédula y teléfono una vez; después '
              'el Conversor arma el cobro por ti.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 12.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 14),
            VeBtn(
              variant: VeBtnVariant.primary,
              onPressed: () {
                Navigator.of(context).pop();
                context.go('/ajustes');
              },
              child: const Text('Ir a Ajustes'),
            ),
          ],
        ),
      );
    }

    final account = widget.accounts[_sel.clamp(0, widget.accounts.length - 1)];
    final msg = pagoMovilMessage(widget.montoBs, account);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // v23.3: el título vive en la cabecera del chrome (antes se
          // repetía dentro del cuerpo con estilo propio de 16 w700).
          // El monto manda: cifra grande tabular en ReadWindow del sistema.
          ReadWindow(
            child: Text(
              'Bs ${fmtNum(widget.montoBs, decimals: 2)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VeText.displayNum(
                30,
                color: scheme.onSurface,
                weight: FontWeight.w700,
              ),
            ),
          ),
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
                      child: Text(a.bank),
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
                fontSize: 12.5,
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
          Row(
            children: [
              Expanded(
                child: VeBtn(
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
              const SizedBox(width: 8),
              Expanded(
                child: VeBtn(
                  variant: VeBtnVariant.primary,
                  icon: LucideIcons.share2,
                  expands: true,
                  onPressed: () => SharePlus.instance.share(
                    ShareParams(text: msg),
                  ),
                  child: const Text('Compartir'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
