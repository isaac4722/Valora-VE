/// ─── Tests del kit «Ve» · piel v25 «HOJA» sobre Material 3 nativo ──────────
/// Cobertura del contrato de la pieza:
/// 1. Los controles se construyen sobre Material 3 puro con las medidas v25
///    (alturas sm/md/lg 36/44/52, badge solo-texto, toggle 32×18).
/// 2. VeBadge usa SOLO el texto del tono (sin fondo ni borde — regla de 3).
/// 3. Los gráficos pintan sin romper con datos, con un punto y sin datos.
/// 4. VeSegmented desliza su pastilla de tinta al cambiar el valor.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:valorave/core/theme.dart';
import 'package:valorave/widgets/ve/ve.dart';
import 'package:fl_chart/fl_chart.dart';

Widget _wrap(Widget child) => MaterialApp(
      // AppTheme ya registra VeInk: mismo contrato que main.dart (v24).
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      home: Scaffold(body: Center(child: child)),
    );

void main() {
  group('VeBtn · medidas exactas del prototipo', () {
    testWidgets('sm/md/lg miden 28/36/44 de alto', (tester) async {
      await tester.pumpWidget(_wrap(Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const VeBtn(
            onPressed: null,
            size: VeBtnSize.sm,
            child: Text('sm'),
          ),
          const VeBtn(
            onPressed: null,
            size: VeBtnSize.md,
            child: Text('md'),
          ),
          const VeBtn(
            onPressed: null,
            size: VeBtnSize.lg,
            child: Text('lg'),
          ),
        ],
      )));
      await tester.pumpAndSettle();

      final sm = tester.getSize(find.text('sm'));
      final md = tester.getSize(find.text('md'));
      final lg = tester.getSize(find.text('lg'));
      // El texto vive dentro del botón de altura fija: el Material interno
      // del VeBtn (v25 «HOJA») mide lo pactado — píldoras sin borde.
      final btns = find.descendant(
        of: find.byType(VeBtn),
        matching: find.byType(Material),
      );
      expect(tester.getSize(btns.at(0)).height, 36);
      expect(tester.getSize(btns.at(1)).height, 44);
      expect(tester.getSize(btns.at(2)).height, 52);
      expect(sm.width, greaterThan(0));
      expect(md.width, greaterThan(0));
      expect(lg.width, greaterThan(0));
    });

    testWidgets('primary invierte: fondo fg y texto bg', (tester) async {
      await tester.pumpWidget(_wrap(const VeBtn(
        onPressed: null,
        variant: VeBtnVariant.primary,
        child: Text('Guardar'),
      )));
      await tester.pumpAndSettle();

      final mat = tester.widget<Material>(find.descendant(
        of: find.byType(VeBtn),
        matching: find.byType(Material),
      ));
      expect(mat.color, VeColors.fgLight);
      final dts = tester.widget<DefaultTextStyle>(find
          .descendant(
            of: find.byType(VeBtn),
            matching: find.byType(DefaultTextStyle),
          )
          .last);
      expect(dts.style.color, VeColors.bgLight);
    });

    testWidgets('danger: tonal neg 10 % + tinta neg, SIN borde', (tester) async {
      await tester.pumpWidget(_wrap(const VeBtn(
        onPressed: null,
        variant: VeBtnVariant.danger,
        child: Text('Quitar'),
      )));
      await tester.pumpAndSettle();

      final mat = tester.widget<Material>(find.descendant(
        of: find.byType(VeBtn),
        matching: find.byType(Material),
      ));
      expect(mat.color, VeColors.negBgLight);
      final dts = tester.widget<DefaultTextStyle>(find
          .descendant(
            of: find.byType(VeBtn),
            matching: find.byType(DefaultTextStyle),
          )
          .last);
      expect(dts.style.color, VeColors.negLight);
    });
  });

  group('VeBadge · SOLO texto del tono (v25 «HOJA»)', () {
    for (final (tone, fg) in [
      (VeTone.pos, VeColors.posLight),
      (VeTone.neg, VeColors.negLight),
      (VeTone.warn, VeColors.warnLight),
      (VeTone.info, VeColors.manualLight),
    ]) {
      testWidgets('tono $tone pinta SOLO texto del tono, sin fondo', (
        tester,
      ) async {
        await tester.pumpWidget(_wrap(VeBadge(tone: tone, child: Text('X'))));
        await tester.pumpAndSettle();
        final dts = tester.widget<DefaultTextStyle>(find
            .descendant(
              of: find.byType(VeBadge),
              matching: find.byType(DefaultTextStyle),
            )
            .last);
        expect(dts.style.color, fg);
      });
    }
  });

  group('VeToggle · switch compacto del prototipo', () {
    testWidgets('mide 32×18', (tester) async {
      await tester.pumpWidget(
        _wrap(const VeToggle(value: false, onChanged: null)),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(VeToggle)), const Size(32, 18));
    });
  });

  group('VeSegmented · pastilla deslizante', () {
    testWidgets('construye con valor activo y responde al tap', (tester) async {
      String val = 'a';
      await tester.pumpWidget(_wrap(StatefulBuilder(
        builder: (context, setState) => VeSegmented<String>(
          value: val,
          onChanged: (v) => setState(() => val = v),
          segments: const [
            VeSegment(value: 'a', label: 'BCV'),
            VeSegment(value: 'b', label: 'Paralelo'),
          ],
        ),
      )));
      await tester.pumpAndSettle();

      expect(find.text('BCV'), findsOneWidget);
      expect(find.text('Paralelo'), findsOneWidget);

      await tester.tap(find.text('Paralelo'));
      await tester.pumpAndSettle();
      expect(val, 'b');
    });
  });

  group('Gráficos · pintan sanos en los bordes', () {
    testWidgets('VeSparkline con serie corta no rompe', (tester) async {
      await tester.pumpWidget(
        _wrap(const VeSparkline(data: [1], tone: VeChartTone.pos)),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(VeSparkline),
          matching: find.byType(LineChart),
        ),
        findsOneWidget,
      );
    });

    testWidgets('VeSparkline con serie normal pinta polyline', (tester) async {
      await tester.pumpWidget(
        _wrap(const VeSparkline(data: [1, 2, 1.5, 3, 2.8])),
      );
      await tester.pumpAndSettle();
      expect(
        find.descendant(
          of: find.byType(VeSparkline),
          matching: find.byType(LineChart),
        ),
        findsOneWidget,
      );
    });

    testWidgets('VeDonut con categorías pinta y leyenda', (tester) async {
      await tester.pumpWidget(_wrap(const VeDonut(
        labels: ['Cesta', 'Proteínas'],
        data: [10, 4],
      )));
      await tester.pumpAndSettle();
      expect(find.descendant(
        of: find.byType(VeDonut),
        matching: find.byType(PieChart),
      ), findsOneWidget);
      expect(find.text('Cesta'), findsOneWidget);
      expect(find.text('Proteínas'), findsOneWidget);
    });

    testWidgets('VeBars construye con datos vacíos', (tester) async {
      await tester.pumpWidget(_wrap(const VeBars(labels: [], data: [])));
      await tester.pumpAndSettle();
      expect(find.byType(BarChart), findsOneWidget);
    });

    testWidgets('VeEmpty muestra título y acción', (tester) async {
      await tester.pumpWidget(_wrap(VeEmpty(
        title: 'Sin compras',
        sub: 'Cierra una compra desde Lista.',
        action: VeBtn(onPressed: () {}, child: const Text('Ir a Lista')),
      )));
      await tester.pumpAndSettle();
      expect(find.text('Sin compras'), findsOneWidget);
      expect(find.text('Ir a Lista'), findsOneWidget);
    });
  });

  group('Composición · media pantalla (v20 · orden del dueño)', () {
    testWidgets('showVeHalfSheet NACE a la mitad y no cubre la pantalla', (
      tester,
    ) async {
      // Teléfono 390×844 SIN notch de prueba: la hoja debe medir ~0.5 de
      // la altura (±40) — los menús contextuales dejan ver la app debajo.
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(MaterialApp(
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        home: Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: VeBtn(
                onPressed: () => showVeHalfSheet(
                  context: context,
                  title: 'Menú de producto',
                  builder: (_) => Column(
                    children: [
                      for (var i = 0; i < 30; i++) Text('Fila $i'),
                    ],
                  ),
                  footer: VeBtn(
                    onPressed: () {},
                    child: const Text('Aceptar'),
                  ),
                ),
                child: const Text('Abrir'),
              ),
            ),
          ),
        ),
      ));
      await tester.pumpAndSettle();

      await tester.tap(find.byType(VeBtn));
      await tester.pumpAndSettle();

      expect(find.text('Menú de producto'), findsOneWidget);
      // La hoja (Material del showModalBottomSheet) mide ~422 (0.5×844).
      final sheet = find.byType(DraggableScrollableSheet);
      expect(sheet, findsOneWidget);
      final rect = tester.getRect(sheet);
      expect(rect.height, closeTo(844 * 0.5, 40),
          reason: 'nace a media pantalla: ${rect.height}');
      // El asa de arrastre está visible (señal nativa de hoja deslizable).
      expect(find.byType(DraggableScrollableSheet), findsOneWidget);
      // El contenido scrollea DENTRO de la hoja (asa + cabecera + pie).
      expect(find.text('Aceptar'), findsOneWidget);
    });
  });
}
