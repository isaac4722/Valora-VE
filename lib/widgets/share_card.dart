/// ─── Tarjetas de compartir con identidad ValoraVE (v17.2 · v31) ──────────
/// Imagen DISEÑADA (no captura de pantalla): «de esta divisa a esta divisa
/// es tanto» (conversor) y «cóbrame por pago móvil» (hoja de cobro), con
/// marca, banderas, fecha y fuente.
///
/// CONVENCIÓN v31 (ver services/sharing.dart): las tarjetas se componen a
/// **360 px LÓGICOS** — el papel de teléfono de la app, con SU sistema
/// tipográfico (11 · 13,5 · 17 · 30) — y se rasterizan a pixelRatio 3 →
/// **1080×1080 físicos**. Antes se maquetaban a 1080 lógicos con fontSize
/// 30: el texto quedaba a 30 px en la imagen final (diminuto e
/// inconsistente con la constancia, que sí usa la escala de teléfono).
/// La cifra protagonista lleva FittedBox(scaleDown): números largos nunca
/// rompen la tarjeta. Se comparten desde memoria (captureWidget), sin
/// descargar archivo alguno.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/currencies.dart';
import '../core/fmt.dart';
import '../core/models.dart';
import '../services/sharing.dart' show renderOffstagePng;
import 'ui.dart' show Flag;

// Paleta de marca del artefacto exportado (papel azul profundo): compartida
// por las tarjetas y su chip de fecha — una sola identidad.
const Color _bg = Color(0xFF0E1424);
const Color _accent = Color(0xFF6C8CFF);
const Color _ink = Color(0xFFF4F6FB);
const Color _muted = Color(0xFF93A0BE);
const Color _line = Color(0xFF243050);

/// Tarjeta cuadrada (360 lógico → PNG 1080×1080) para el resultado del
/// conversor.
class ConversionShareCard extends StatelessWidget {
  const ConversionShareCard({
    super.key,
    required this.from,
    required this.to,
    required this.inputAmount,
    required this.resultAmount,
    required this.rateLine,
    required this.sourceLabel,
    required this.date,
  });

  final Currency from;
  final Currency to;
  final double inputAmount;
  final double resultAmount;

  /// «1 USD = 362,45 Bs» (ya formateado por el caller con fmt).
  final String rateLine;

  /// «BCV · Oficial» / «Paralelo · mercado».
  final String sourceLabel;

  final DateTime date;

  /// Lado lógico de la tarjeta (convención v31: 360 → 1080 px finales).
  static const double _size = 360;

  String _fecha() {
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    return '${date.day} ${meses[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      color: _bg,
      // Marco fino interior: tratamiento de borde firma (ReadWindow).
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Marca arriba: Valora + VE en acento, fecha a la derecha.
            Row(
              children: [
                const Text.rich(
                  TextSpan(
                    text: 'Valora',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                    children: [
                      TextSpan(text: ' VE', style: TextStyle(color: _accent)),
                    ],
                  ),
                ),
                const Spacer(),
                _DateChip(text: _fecha()),
              ],
            ),
            const Spacer(),
            // Ruta de divisas: bandera origen → bandera destino.
            Row(
              children: [
                Flag(from, size: 14),
                const SizedBox(width: 5),
                Text(
                  from.code,
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
                const SizedBox(width: 6),
                const Icon(Icons.east_rounded, size: 14, color: _accent),
                const SizedBox(width: 6),
                Text(
                  to.code,
                  style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
                const SizedBox(width: 5),
                Flag(to, size: 14),
              ],
            ),
            const SizedBox(height: 10),
            Text(
              'POR ${fmtNum(inputAmount, decimals: 2)} ${from.code}',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _muted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            // Cifra héroe: el resultado, protagonista absoluto.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                fmtMoney(resultAmount, to),
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 30,
                  height: 1.04,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(height: 2, width: 48, color: _accent),
            const SizedBox(height: 10),
            Text(
              rateLine,
              style: const TextStyle(
                fontFamily: 'SpaceGrotesk',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _ink,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              'Fuente: $sourceLabel',
              style: const TextStyle(fontSize: 11, color: _muted),
            ),
            const Spacer(),
            // Pie: regla + promesa de marca.
            Container(height: 0.5, color: _line),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.bolt_rounded, size: 11, color: _accent),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Tasas y precios, también sin conexión',
                    style: TextStyle(
                      fontSize: 11,
                      color: _muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  'ValoraVE',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip de fecha del marco (borde hairline, texto atenuado).
class _DateChip extends StatelessWidget {
  const _DateChip({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 3),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: _line, width: 0.5),
      ),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 11,
          color: _muted,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

/// ─── Tarjeta de Pago Móvil (v29 · H-29, orden del dueño) ──────────────────
/// El cobro comparte como IMAGEN de marca (regla global v28: Compartir es
/// solo archivos): 360 lógico → PNG 1080×1080 (convención v31), misma
/// paleta y marco de [ConversionShareCard] — marca arriba, cifra
/// protagonista con FittedBox, las líneas de la cuenta activa y pie con
/// hairline. Con [para] (modo «Mañana»), el cobro viaja fechado:
/// «Fecha: DD/MM (mañana)».
class PagoMovilShareCard extends StatelessWidget {
  const PagoMovilShareCard({
    super.key,
    required this.montoBs,
    required this.account,
    this.para,
  });

  /// Cifra a cobrar en bolívares.
  final double montoBs;

  /// Cuenta de cobro activa.
  final PayAccount account;

  /// Cobro planificado (v29 · H-22 «Mañana»): la fecha del día siguiente.
  final DateTime? para;

  /// Lado lógico de la tarjeta (convención v31: 360 → 1080 px finales).
  static const double _size = 360;

  String _fecha() {
    const meses = [
      'ene',
      'feb',
      'mar',
      'abr',
      'may',
      'jun',
      'jul',
      'ago',
      'sep',
      'oct',
      'nov',
      'dic',
    ];
    final d = para ?? DateTime.now();
    return '${d.day} ${meses[d.month - 1]} ${d.year}';
  }

  @override
  Widget build(BuildContext context) {
    // Las líneas EXACTAS del tipo de la cuenta (v30 · H-43): `dataLines` es
    // la única fuente — fila, copia, mensaje y esta tarjeta comparten
    // texto. Con [para] (modo «Mañana»), el cobro viaja fechado.
    final rows = <(String, String)>[
      for (final (label, value) in account.dataLines) (label, value),
      if (para != null)
        (
          'Fecha',
          '${para!.day.toString().padLeft(2, '0')}/'
              '${para!.month.toString().padLeft(2, '0')} (mañana)',
        ),
    ];

    return Container(
      width: _size,
      height: _size,
      color: _bg,
      // Marco fino interior: tratamiento de borde firma (ReadWindow).
      padding: const EdgeInsets.all(8),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: _line),
        ),
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Marca arriba: Valora + VE en acento, fecha a la derecha.
            Row(
              children: [
                const Text.rich(
                  TextSpan(
                    text: 'Valora',
                    style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                      color: _ink,
                    ),
                    children: [
                      TextSpan(text: ' VE', style: TextStyle(color: _accent)),
                    ],
                  ),
                ),
                const Spacer(),
                _DateChip(text: _fecha()),
              ],
            ),
            const Spacer(),
            Text(
              'COBRO POR PAGO MÓVIL',
              style: const TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: _muted,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 4),
            // Cifra protagonista: el monto en Bs, símbolo tras el número.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                '${fmtNum(montoBs, decimals: 2)} Bs',
                style: const TextStyle(
                  fontFamily: 'SpaceGrotesk',
                  fontSize: 30,
                  height: 1.04,
                  fontWeight: FontWeight.w700,
                  color: _ink,
                ),
              ),
            ),
            const SizedBox(height: 12),
            Container(height: 2, width: 48, color: _accent),
            const SizedBox(height: 10),
            // Las líneas de la cuenta activa — patrón recibo: rótulo a la
            // izquierda, valor a la derecha con FittedBox (una línea por
            // dato: la transferencia con fecha planificada llega a 5 filas
            // y la tarjeta cuadrada NUNCA desborda).
            for (final (label, value) in rows) ...[
              Row(
                children: [
                  Text(
                    label,
                    style: const TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      color: _muted,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerRight,
                      child: Text(
                        value,
                        textAlign: TextAlign.right,
                        style: const TextStyle(
                          fontFamily: 'SpaceGrotesk',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: _ink,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
            ],
            const Spacer(),
            // Pie: hairline + promesa de marca.
            Container(height: 0.5, color: _line),
            const SizedBox(height: 10),
            const Row(
              children: [
                Icon(Icons.bolt_rounded, size: 11, color: _accent),
                SizedBox(width: 5),
                Expanded(
                  child: Text(
                    'Tasas y precios, también sin conexión',
                    style: TextStyle(
                      fontSize: 11,
                      color: _muted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                Text(
                  'ValoraVE',
                  style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: _muted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Rasteriza [builder] offstage a PNG 1080 px de ancho (convención v31:
/// maquetado a 360 lógico × 3). No descarga ni escribe archivo: los bytes
/// viven en memoria y viajan por share/cache.
///
/// v31: UNA sola tubería — delega en [renderOffstagePng] (boundary a
/// prueba de key compuesto, frames acotados, overlay siempre retirado).
/// Antes eran dos mecanismos gemelos que podían divergir.
Future<Uint8List?> renderSharePng(
  BuildContext context,
  WidgetBuilder builder, {
  int targetWidth = 1080,
  double width = 360,
}) =>
    renderOffstagePng(
      context,
      Builder(builder: builder),
      targetWidth: targetWidth,
      width: width,
    );

/// Convierte el resultado del conversor con la tarjeta de marca.
Future<Uint8List?> renderConversionSharePng(
  BuildContext context, {
  required Currency from,
  required Currency to,
  required double inputAmount,
  required double resultAmount,
  required String rateLine,
  required String sourceLabel,
  required DateTime date,
}) =>
    renderSharePng(
      context,
      (_) => ConversionShareCard(
        from: from,
        to: to,
        inputAmount: inputAmount,
        resultAmount: resultAmount,
        rateLine: rateLine,
        sourceLabel: sourceLabel,
        date: date,
      ),
    );

/// Rasteriza la tarjeta de Pago Móvil offstage a PNG 1080×1080 (misma
/// tubería de [renderConversionSharePng]: sin archivo, desde memoria).
Future<Uint8List?> renderPagoMovilSharePng(
  BuildContext context, {
  required double montoBs,
  required PayAccount account,
  DateTime? para,
}) =>
    renderSharePng(
      context,
      (_) => PagoMovilShareCard(montoBs: montoBs, account: account, para: para),
    );
