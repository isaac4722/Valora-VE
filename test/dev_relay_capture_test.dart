/// Tests de DevCapture (v21.7) — SIN toImage: el rasterizador del
/// flutter_tester completa la captura pero deja el frame-loop sin asentar y
/// el runner cuelga (comprobado con probe: PASO1-5 ok → timeout del test).
/// Por eso la matemática del pixelRatio es función PURA (probada aquí) y el
/// único camino con UI que se prueba es el guard honesto (sin boundary →
/// null, sin toImage). La captura real se verifica con hardware en el pilot.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/services/dev_relay_vm.dart';

void main() {
  group('DevCapture.pixelRatioFor (pura)', () {
    test('720 objetivo desde 1080 lógicos ≈ 0.667', () {
      expect(DevCapture.pixelRatioFor(1080, 720), closeTo(0.6667, 0.001));
    });

    test('target mayor que la UI → tope 3.0 (sin escalados absurdos)', () {
      expect(DevCapture.pixelRatioFor(100, 720), 3.0);
      expect(DevCapture.pixelRatioFor(200, 4000), 3.0);
    });

    test('UI sin ancho válido → 1.0 (sin división rara)', () {
      expect(DevCapture.pixelRatioFor(0, 720), 1.0);
      expect(DevCapture.pixelRatioFor(-5, 720), 1.0);
    });
  });

  testWidgets('capture sin boundary montado → null honesto', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(home: SizedBox.shrink()),
    );
    await tester.pumpAndSettle();
    // En este árbol nadie montó DevCapture.key → sin render object: null,
    // jamás excepción (la herramienta no puede tumbar nada).
    final bytes = await DevCapture.capture();
    expect(bytes, isNull);
  });
}
