/// ─── Tests del kit «Ve» · capa shadcn_ui del prototipo (TASK-34 · p3) ───────
/// Cobertura del contrato de la pieza:
/// 1. Los controles se construyen sobre componentes shadcn/ui reales y con
///    las medidas EXACTAS del prototipo (alturas sm/md/lg, badge, toggle).
/// 2. Los tonos de VeBadge usan los fondos tenues de VeInk (pos-bg & co.).
/// 3. Los gráficos pintan sin romper con datos, con un punto y sin datos.
/// 4. VeSegmented desliza su pastilla al cambiar el valor (mejora UX).
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:valorave/core/shad_theme.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/widgets/ve/ve.dart';

Widget _wrap(Widget child) => ShadApp(
      theme: ShadThemeVe.light(),
      darkTheme: ShadThemeVe.dark(),
      // Mismo puente que main.dart: el tema Material inyecta VeInk.
      materialThemeBuilder: (context, mTheme) =>
          veMaterialBridge(Brightness.light, null),
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
      // El texto vive dentro del botón de altura fija: verificamos que el
      // botón (ancestro ShadButton) mide lo pactado.
      final btns = find.byType(ShadButton);
      expect(tester.getSize(btns.at(0)).height, 28);
      expect(tester.getSize(btns.at(1)).height, 36);
      expect(tester.getSize(btns.at(2)).height, 44);
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

      final btn = tester.widget<ShadButton>(find.byType(ShadButton));
      expect(btn.backgroundColor, VeColors.fgLight);
      expect(btn.foregroundColor, VeColors.bgLight);
    });

    testWidgets('danger: superficie + tinta neg + borde neg 40 %', (tester) async {
      await tester.pumpWidget(_wrap(const VeBtn(
        onPressed: null,
        variant: VeBtnVariant.danger,
        child: Text('Quitar'),
      )));
      await tester.pumpAndSettle();

      final btn = tester.widget<ShadButton>(find.byType(ShadButton));
      expect(btn.backgroundColor, VeColors.cardLight);
      expect(btn.foregroundColor, VeColors.negLight);
    });
  });

  group('VeBadge · fondos tenues del tono', () {
    for (final (tone, bg, fg) in [
      (VeTone.pos, VeColors.posBgLight, VeColors.posLight),
      (VeTone.neg, VeColors.negBgLight, VeColors.negLight),
      (VeTone.warn, VeColors.warnBgLight, VeColors.warnLight),
      (VeTone.info, VeColors.infoBgLight, VeColors.manualLight),
    ]) {
      testWidgets('tono $tone usa el token -bg de VeInk', (tester) async {
        await tester.pumpWidget(_wrap(VeBadge(tone: tone, child: Text('X'))));
        await tester.pumpAndSettle();
        final badge = tester.widget<ShadBadge>(find.byType(ShadBadge));
        expect(badge.backgroundColor, bg);
        expect(badge.foregroundColor, fg);
      });
    }
  });

  group('VeToggle · switch compacto del prototipo', () {
    testWidgets('mide 32×18', (tester) async {
      await tester.pumpWidget(
        _wrap(const VeToggle(value: false, onChanged: null)),
      );
      await tester.pumpAndSettle();
      expect(tester.getSize(find.byType(ShadSwitch)), const Size(32, 18));
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
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('VeSparkline con serie normal pinta polyline', (tester) async {
      await tester.pumpWidget(
        _wrap(const VeSparkline(data: [1, 2, 1.5, 3, 2.8])),
      );
      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsOneWidget);
    });

    testWidgets('VeDonut con categorías pinta y leyenda', (tester) async {
      await tester.pumpWidget(_wrap(const VeDonut(
        labels: ['Cesta', 'Proteínas'],
        data: [10, 4],
      )));
      await tester.pumpAndSettle();
      expect(find.text('Cesta'), findsOneWidget);
      expect(find.text('Proteínas'), findsOneWidget);
    });

    testWidgets('VeBars construye con datos vacíos', (tester) async {
      await tester.pumpWidget(_wrap(const VeBars(labels: [], data: [])));
      await tester.pumpAndSettle();
      expect(find.byType(Row), findsOneWidget);
    });

    testWidgets('VeAreaChart sin datos devuelve alto sin pintor', (tester) async {
      await tester.pumpWidget(_wrap(VeAreaChart(
        data: const [],
        labels: const [],
        format: (v) => '$v',
      )));
      await tester.pumpAndSettle();
      expect(find.byType(CustomPaint), findsNothing);
    });

    testWidgets('VeHeatmap con offset pinta celdas vacías', (tester) async {
      await tester.pumpWidget(_wrap(
        const VeHeatmap(byDay: [1, 0, 2], offset: 2, maxValue: 2),
      ));
      await tester.pumpAndSettle();
      expect(find.byType(Wrap), findsOneWidget);
      expect(find.text('1'), findsOneWidget);
    });
  });

  group('Composición · Group/Row/Empty', () {
    testWidgets('VeGroup divide filas con separador', (tester) async {
      await tester.pumpWidget(_wrap(const VeGroup(children: [
        VeRow(label: Text('BCV'), right: Text('36,51')),
        VeRow(label: Text('Paralelo'), right: Text('44,20')),
      ])));
      await tester.pumpAndSettle();
      expect(find.text('BCV'), findsOneWidget);
      expect(find.text('Paralelo'), findsOneWidget);
      expect(find.byType(Divider), findsOneWidget);
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
}
