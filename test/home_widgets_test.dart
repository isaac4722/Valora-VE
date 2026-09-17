/// Tests de los widgets de Inicio (v19.4): catálogo con vista previa,
/// añadir/quitar y tamaño adaptable del contenido — orden del dueño.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/home/home_widgets.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:valorave/widgets/app_router.dart';
import 'package:valorave/widgets/app_tour.dart' show kTourDoneKey;

Purchase _compra(int i) => Purchase(
  id: 'c$i',
  date: DateTime(2026, 9, 1 + i),
  store: 'Tienda $i',
  items: const <PurchaseItem>[],
  totalUSD: 1.0 + i,
  totalBS: 0,
  rate: 1,
);

Transaction _ingreso(int i) => Transaction(
  id: 't$i',
  type: 'income',
  category: FinanceCategory.otrosIngresos,
  amount: 10,
  currency: 'USD',
  amountUSD: 10,
  date: DateTime(2026, 9, 2 + i),
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('HomeWidgetController (persistencia)', () {
    test('por defecto todo visible y tamaño normal', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = HomeWidgetController(prefs, knownIds: const ['a', 'b']);
      expect(c.visible, const ['a', 'b']);
      expect(c.isVisible('a'), isTrue);
      expect(c.sizeOf('a'), HomeWidgetSize.m);
    });

    test('quitar/añadir y tamaño se guardan en prefs', () async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final c = HomeWidgetController(prefs, knownIds: const ['a', 'b']);
      await c.setVisible('a', false);
      await c.setSize('b', HomeWidgetSize.l);
      // Un controlador NUEVO (reinicio de la app) lee lo mismo.
      final c2 = HomeWidgetController(prefs, knownIds: const ['a', 'b']);
      expect(c2.visible, const ['b']);
      expect(c2.sizeOf('b'), HomeWidgetSize.l);
      expect(c2.isVisible('a'), isFalse);
    });

    test('ids nuevos de actualizaciones entran visibles; muertos se botan',
    () async {
      SharedPreferences.setMockInitialValues({
        'valorave.home.widgets': <String>['vieja', 'b'],
      });
      final prefs = await SharedPreferences.getInstance();
      final c = HomeWidgetController(prefs, knownIds: const ['a', 'b']);
      // 'vieja' ya no existe → fuera; 'a' es nueva → visible al final.
      expect(c.visible, const ['b', 'a']);
    });
  });

  group('Widgets de Inicio (UI)', () {
    late AppStore store;
    late RatesPoller poller;
    late NotificationsService notifs;
    late SharedPreferences prefs;

    // Descripciones estables del catálogo (una por entrada).
    final descRegistros =
        'Tus últimas compras e ingresos, de lo más nuevo a lo más viejo.';
    final descCotizacion =
        'Las tasas del país con todas sus fuentes. Toca una fila para '
        'calcular con ella; contenido fijo — es la puerta de la app.';

    /// El scroll de la hoja del catálogo.
    final sheetScroll = find
        .descendant(
          of: find.byType(DraggableScrollableSheet),
          matching: find.byType(Scrollable),
        )
        .first;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      // El tour auto-arrancaría y taparía la UI: ya visto, como un
      // usuario que lo completó.
      await prefs.setBool(kTourDoneKey, true);
      store = AppStore.withData(
        AppData(
          settings: const Settings(onboarded: true),
          purchases: <Purchase>[for (var i = 0; i < 5; i++) _compra(i)],
          transactions: <Transaction>[
            for (var i = 0; i < 5; i++) _ingreso(i),
          ],
        ),
      );
      notifs = NotificationsService();
      final alerts = AlertEngine(prefs);
      poller = RatesPoller(store, notifs, alerts);
    });

    Future<void> pumpHome(WidgetTester tester) async {
      final router = buildRouter(store: store);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            Provider<SharedPreferences>.value(value: prefs),
            ChangeNotifierProvider.value(value: poller),
          ],
          child: MaterialApp.router(
            theme: AppTheme.light(),
            routerConfig: router,
          ),
        ),
      );
      await tester.pump();
    }

    Future<void> abrirCatalogo(WidgetTester tester) async {
      // La tarjeta vive al pie del Inicio. ensureVisible (no
      // scrollUntilVisible): el Column de secciones construye la tarjeta
      // aunque esté fuera de pantalla y el scrollUntil la daría por
      // «hallada» sin mover nada.
      final tarjeta = find
          .text('Añade o quita secciones y elige cuánto muestra cada una.')
          .last;
      await tester.ensureVisible(tarjeta);
      await tester.pump(const Duration(milliseconds: 300));
      await tester.tap(tarjeta);
      // Bombeo acotado (NO pumpAndSettle): el LoadingState del home con
      // tablero vacío tiene un spinner infinito que nunca asienta.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 400));
      // La hoja abierta: su subtítulo único (el botón «Listo» vive al
      // final del scroll — se toca en cerrarCatalogo).
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      expect(
        find.textContaining('Míralos tal como quedan y decide'),
        findsOneWidget,
      );
    }

    Future<void> cerrarCatalogo(WidgetTester tester) async {
      await tester.scrollUntilVisible(
        find.text('Listo'),
        400,
        scrollable: sheetScroll,
      );
      await tester.tap(find.text('Listo'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
    }

    /// Lleva la entrada de [desc] a la vista y monta también su mitad de
    /// abajo (preview + selector): el scrollUntilVisible solo alinea la
    /// descripción y deja el resto bajo el pliegue de la hoja.
    Future<void> irAEntrada(WidgetTester tester, String desc) async {
      await tester.scrollUntilVisible(
        find.text(desc),
        400,
        scrollable: sheetScroll,
      );
      await tester.pump();
      await tester.drag(sheetScroll, const Offset(0, -300));
      await tester.pump();
    }

    /// Toca [target] dentro de la hoja llevándolo a la vista ANTES: los
    /// botones viven arriba o abajo de la descripción alineada y un tap
    /// a ciegas se pierde en el material de la hoja. Tras el
    /// ensureVisible se da un margen de arrastre: pegado al borde
    /// superior, el tap cae en el material y no en el botón.
    Future<void> tocar(WidgetTester tester, Finder target) async {
      await tester.ensureVisible(target);
      await tester.pump(const Duration(milliseconds: 200));
      await tester.drag(sheetScroll, const Offset(0, 80));
      await tester.pump(const Duration(milliseconds: 200));
      await tester.tap(target);
      await tester.pump();
    }

    /// El Container de la entrada del catálogo que muestra [desc].
    Finder entradaDe(String desc) => find
        .ancestor(of: find.text(desc), matching: find.byType(Container))
        .first;

    testWidgets('por defecto: secciones de siempre + tarjeta de widgets',
    (tester) async {
      await pumpHome(tester);
      expect(find.text('COTIZACIÓN PRINCIPAL'), findsOneWidget);
      expect(find.text('DIVISAS DEL FOCO'), findsOneWidget);
      expect(find.text('RESUMEN DEL MES'), findsOneWidget);
      expect(find.text('HERRAMIENTAS'), findsOneWidget);
      expect(
        find.text('Añade o quita secciones y elige cuánto muestra cada una.'),
        findsOneWidget,
      );
    });

    testWidgets('el catálogo muestra la PREVIEW real antes de añadir',
    (tester) async {
      await pumpHome(tester);
      await abrirCatalogo(tester);
      // La entrada de Cotización (primera) con su preview: el MISMO
      // contenido del Inicio se pinta dentro de la hoja.
      expect(find.text('Cotización principal'), findsOneWidget);
      // El título de sección mayúscula vive DOS veces: Inicio + preview.
      expect(find.text('COTIZACIÓN PRINCIPAL'), findsNWidgets(2));
      // Selector de tamaño SOLO donde el contenido adapta: la primera
      // entrada (Cotización) NO tiene — su contenido es fijo.
      final entradaCotizacion = find
          .ancestor(
            of: find.text(descCotizacion),
            matching: find.byType(Container),
          )
          .first;
      expect(
        find.descendant(
          of: entradaCotizacion,
          matching: find.byType(SegmentedButton<HomeWidgetSize>),
        ),
        findsNothing,
        reason: 'Cotización no redimensiona',
      );
      expect(
        find.descendant(
          of: entradaCotizacion,
          matching: find.text('En Inicio'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('quitar y volver a añadir un widget', (tester) async {
      await pumpHome(tester);
      await abrirCatalogo(tester);
      // Con la hoja abierta: 'Registros recientes' vive en Inicio (la
      // preview de esa entrada está bajo el pliegue de la hoja).
      expect(find.text('REGISTROS RECIENTES'), findsOneWidget);
      await irAEntrada(tester, descRegistros);
      final entrada = entradaDe(descRegistros);
      // Quitar: el botón En Inicio de ESA entrada (la preview de la
      // primera entrada ya se verificó en su propio test).
      await tocar(
        tester,
        find.descendant(of: entrada, matching: find.text('En Inicio')),
      );
      // El Inicio lo soltó (queda la preview) y el botón cambió a Añadir.
      expect(find.text('REGISTROS RECIENTES'), findsOneWidget);
      expect(
        find.descendant(of: entrada, matching: find.text('Añadir')),
        findsOneWidget,
      );
      // Volver a añadir: hoja fresca (cerrar y reabrir) y el botón
      // Añadir de la misma entrada.
      await cerrarCatalogo(tester);
      await abrirCatalogo(tester);
      await irAEntrada(tester, descRegistros);
      await tocar(
        tester,
        find.descendant(
          of: entradaDe(descRegistros),
          matching: find.text('Añadir'),
        ),
      );
      await cerrarCatalogo(tester);
      expect(find.text('REGISTROS RECIENTES'), findsOneWidget);
    });

    testWidgets('el contenido adapta al tamaño: registros 3/3 → 2/2',
    (tester) async {
      await pumpHome(tester);
      // Normal (default): 3 compras + 3 ingresos.
      expect(find.textContaining('Compra · Tienda'), findsNWidgets(3));
      expect(find.textContaining('Ingreso · Otros'), findsNWidgets(3));
      // Compacto desde el catálogo.
      await abrirCatalogo(tester);
      await irAEntrada(tester, descRegistros);
      await tocar(
        tester,
        find.descendant(
          of: entradaDe(descRegistros),
          matching: find.text('Compacto'),
        ),
      );
      await cerrarCatalogo(tester);
      // Con la hoja cerrada solo cuenta el Inicio: 2+2.
      expect(find.textContaining('Compra · Tienda'), findsNWidgets(2));
      expect(find.textContaining('Ingreso · Otros'), findsNWidgets(2));
    });

    testWidgets('quitar TODO muestra el estado vacío honesto', (
      tester,
    ) async {
      // Estado «todo quitado» sembrado directo en prefs (el camino UI de
      // quitar widget a widget lo cubren el test de quitar/añadir y los
      // unitarios del controlador): visible = lista muerta, los 7 vivos
      // en la lista de ocultos.
      await prefs.setStringList('valorave.home.widgets', <String>['-']);
      await prefs.setStringList('valorave.home.widgets.off', <String>[
        'cotizacion',
        'divisas',
        'resumen',
        'alertas',
        'tiendas',
        'registros',
        'herramientas',
      ]);
      await pumpHome(tester);
      expect(find.text('Inicio limpio'), findsOneWidget);
      // Y la salida sigue a la mano.
      expect(
        find.text('Añade o quita secciones y elige cuánto muestra cada una.'),
        findsOneWidget,
      );
    });
  });
}
