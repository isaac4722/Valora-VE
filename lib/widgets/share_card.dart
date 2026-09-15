/// ─── Tarjeta de compartir con identidad ValoraVE (v17.2) ────────────────────
/// Imagen DISEÑADA (no captura de pantalla): «de esta divisa a esta divisa
/// es tanto» con marca, banderas, fecha y fuente. Se compone como widget
/// offstage 1080×1080 y se rasteriza con captureWidget (comparte desde
/// memoria, sin descargar archivo alguno — regla del dueño).
library;

import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/currencies.dart';
import '../core/fmt.dart';
import '../services/sharing.dart' show captureWidget;
import 'ui.dart' show Flag;

/// Tarjeta cuadrada 1080×1080 para el resultado del conversor.
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

  /// «BCV · oficial» / «Paralelo · mercado».
  final String sourceLabel;
  final DateTime date;

  static const double _size = 1080;
  static const Color _bg = Color(0xFF0E1424);
  static const Color _accent = Color(0xFF6C8CFF);
  static const Color _ink = Color(0xFFF4F6FB);
  static const Color _muted = Color(0xFF93A0BE);
  static const Color _line = Color(0xFF243050);

  String _fecha() {
    const meses = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sep', 'oct', 'nov', 'dic'];
    return '${date.day} ${meses[date.month - 1]} ${date.year}';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: _size,
      height: _size,
      color: _bg,
      // Marco fino interior: tratamiento de borde firma (ReadWindow).
      padding: const EdgeInsets.all(20),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: _line, width: 2),
        ),
        padding: const EdgeInsets.fromLTRB(64, 56, 64, 56),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Marca arriba: Valora + VE en acento, fecha a la derecha.
            Row(children: [
              const Text.rich(TextSpan(
                text: 'Valora',
                style: TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 40,
                    fontWeight: FontWeight.w700,
                    color: _ink),
                children: [
                  TextSpan(text: ' VE', style: TextStyle(color: _accent)),
                ],
              )),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(color: _line, width: 1.5),
                ),
                child: Text(_fecha(),
                    style: const TextStyle(
                        fontSize: 24, color: _muted, fontWeight: FontWeight.w500)),
              ),
            ]),
            const Spacer(),
            // Ruta de divisas: bandera origen → bandera destino.
            Row(children: [
              Flag(from, size: 40),
              const SizedBox(width: 12),
              Text(from.code,
                  style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: _muted)),
              const SizedBox(width: 14),
              const Icon(Icons.east_rounded, size: 34, color: _accent),
              const SizedBox(width: 14),
              Text(to.code,
                  style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 30,
                      fontWeight: FontWeight.w700,
                      color: _muted)),
              const SizedBox(width: 12),
              Flag(to, size: 40),
            ]),
            const SizedBox(height: 26),
            Text('POR ${fmtNum(inputAmount, decimals: 2)} ${from.code}',
                style: const TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 27,
                    fontWeight: FontWeight.w600,
                    color: _muted,
                    letterSpacing: 1.2)),
            const SizedBox(height: 10),
            // Cifra héroe: el resultado, protagonista absoluto.
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(fmtMoney(resultAmount, to),
                  style: const TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 118,
                      height: 1.04,
                      fontWeight: FontWeight.w700,
                      color: _ink)),
            ),
            const SizedBox(height: 30),
            Container(height: 2, width: 148, color: _accent),
            const SizedBox(height: 22),
            Text(rateLine,
                style: const TextStyle(
                    fontFamily: 'SpaceGrotesk',
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    color: _ink)),
            const SizedBox(height: 8),
            Text('Fuente: $sourceLabel',
                style: const TextStyle(fontSize: 27, color: _muted)),
            const Spacer(),
            // Pie: regla + promesa de marca.
            Container(height: 1.5, color: _line),
            const SizedBox(height: 22),
            const Row(children: [
              Icon(Icons.bolt_rounded, size: 30, color: _accent),
              SizedBox(width: 10),
              Expanded(
                child: Text('Tasas y precios, también sin conexión',
                    style: TextStyle(
                        fontSize: 26, color: _muted, fontWeight: FontWeight.w500)),
              ),
              Text('ValoraVE',
                  style: TextStyle(
                      fontFamily: 'SpaceGrotesk',
                      fontSize: 26,
                      fontWeight: FontWeight.w700,
                      color: _muted)),
            ]),
          ],
        ),
      ),
    );
  }
}

/// Rasteriza [builder] offstage a PNG (1080 px de ancho). No descarga ni
/// escribe archivo: los bytes viven en memoria y viajan por share/cache.
Future<Uint8List?> renderSharePng(
  BuildContext context,
  WidgetBuilder builder, {
  int targetWidth = 1080,
}) async {
  final key = GlobalKey();
  final overlay = Overlay.maybeOf(context, rootOverlay: true);
  if (overlay == null) return null;
  late final OverlayEntry entry;
  entry = OverlayEntry(
      builder: (_) => Positioned(
            // Fuera de pantalla pero PINTADO: Offstage no ejecuta paint y
            // RepaintBoundary.toImage produciría una imagen vacía.
            left: -4000,
            top: 0,
            child: Material(
                type: MaterialType.transparency,
                child: KeyedSubtree(key: key, child: Builder(builder: builder))),
          ));
  overlay.insert(entry);
  try {
    // Dos frames: montaje + layout final del árbol offstage.
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    return await captureWidget(key, targetWidth: targetWidth);
  } finally {
    entry.remove();
  }
}

/// Conviene el resultado del conversor con la tarjeta de marca.
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
