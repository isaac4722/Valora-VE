/// ─── Tests del entry Lowder (solo rama test/lowder) ─────────────────────────
/// Verifica que la solución demo carga de assets/lowder/demo.low y pinta su
/// pantalla de aterrizaje — el mismo camino que recorre el editor web y la
/// app al arrancar desde este entry.
///
/// Un SOLO testWidgets: Lowder vive en estado estático (soluciones y fábricas
/// registradas una sola vez por proceso) — montarlo dos veces duplicaría el
/// registro; se valida aterrizaje y botón en el mismo árbol.
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:valorave/lowder_entry.dart';

void main() {
  testWidgets('la solución demo carga del .low: landing y navegación', (
    tester,
  ) async {
    await tester.pumpWidget(ValoraLowder());

    // Lowder muestra splash mientras init() lee y parsea el .low: pump
    // hasta que la pantalla de aterrizaje reemplace al splash (tolerante).
    var aparecio = false;
    for (var i = 0; i < 40 && !aparecio; i++) {
      await tester.pump(const Duration(milliseconds: 100));
      aparecio = find.text('Hola desde un .low').evaluate().isNotEmpty;
    }
    expect(aparecio, isTrue, reason: 'assets/lowder/demo.low debía cargar');

    // La landing trae el botón que navega al detalle por routeName. Ojo:
    // Lowder pinta las etiquetas de botón en title case (getText context
    // «button» → Strings.getTitle) — «Ver el detalle» llega como título.
    expect(find.text('Ver El Detalle'), findsOneWidget);
  });
}
