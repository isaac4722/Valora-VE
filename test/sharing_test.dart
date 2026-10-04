/// Tests de los generadores de PNG para compartir (v18/v19.4): la tarjeta
/// del conversor (renderConversionSharePng) debe producir bytes reales.
/// Regresión del «No pude generar la tarjeta»: el GlobalKey estaba sobre un
/// KeyedSubtree (findRenderObject devolvía un render descendiente, el cast
/// a RenderRepaintBoundary reventaba y el catch lo tragaba → null SIEMPRE),
/// y los Future.delayed ganaban la carrera contra el vsync.
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/core/currencies.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/widgets/share_card.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('la tarjeta del conversor genera un PNG válido', (tester) async {
    await tester.pumpWidget(
      MaterialApp(theme: AppTheme.light(), home: const Scaffold()),
    );
    Uint8List? png;
    var done = false;
    renderConversionSharePng(
      tester.element(find.byType(Scaffold)),
      from: Currency.usd,
      to: Currency.ves,
      inputAmount: 10,
      resultAmount: 3624.5,
      rateLine: '1 USD = 362,45 Bs',
      sourceLabel: 'BCV · oficial',
      date: DateTime(2026, 9, 17),
    ).then((v) {
      png = v;
      done = true;
    });
    // Frames primero: montaje del árbol offstage + los dos endOfFrame
    // internos (montaje+layout y settle de pintura).
    for (var i = 0; i < 6 && !done; i++) {
      await tester.pump(const Duration(milliseconds: 16));
    }
    expect(
      find.byType(ConversionShareCard),
      findsOneWidget,
      reason: 'la tarjeta se montó offstage',
    );
    // El toImage/toByteData del engine necesitan el event loop real.
    await tester.runAsync(() async {
      var guard = 0;
      while (!done && guard++ < 200) {
        await Future<void>.delayed(const Duration(milliseconds: 10));
      }
    });
    // Antes del fix esto era null SIEMPRE (cast roto + carrera de frames).
    expect(png, isNotNull, reason: 'la generación no puede fallar');
    final bytes = png!;
    // Firma PNG (\x89PNG).
    expect(bytes[0], 0x89);
    expect(bytes[1], 0x50);
    expect(bytes[2], 0x4E);
    expect(bytes[3], 0x47);
    // 1080×1080 reescalado y comprimido: pesa de sobra esto.
    expect(bytes.length, greaterThan(5000));
    // El overlay se limpia (finally): no queda basura en el árbol.
    await tester.pump();
    expect(find.byType(ConversionShareCard), findsNothing);
  });
}
