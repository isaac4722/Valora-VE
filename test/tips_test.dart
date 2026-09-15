/// Tests del motor de tips contextuales (v19.0): reglas de disparo,
/// una-sola-vez, cooldown por sesiones y honestidad de los textos.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/converter/converter_screen.dart';
import 'package:valorave/widgets/app_tips.dart';
import 'package:valorave/widgets/app_tour.dart' show kTourDoneKey;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Catálogo de tips', () {
    test('ids únicos, scopes conocidos, texto con contexto', () {
      final ids = kTipRules.map((t) => t.id).toList();
      expect(ids.toSet().length, ids.length, reason: 'ids únicos');
      const scopes = {'home', 'conversor', 'lista', 'productos'};
      for (final t in kTipRules) {
        expect(scopes.contains(t.scope), isTrue, reason: 'scope de «${t.id}»');
        expect(t.title.length, lessThan(40), reason: 'título corto');
        expect(t.body.length, greaterThan(60), reason: 'cuerpo con contexto');
        expect(t.body.length, lessThan(220), reason: 'cuerpo no pared de texto');
      }
    });

    test('motor apagado sin tutorial o con 1 sola sesión', () async {
      SharedPreferences.setMockInitialValues({});
      var prefs = await SharedPreferences.getInstance();
      // Sin tour y sin sesiones.
      expect(tipsEngineEnabled(prefs), isFalse);
      // Tour hecho pero 1ª sesión: tips aún no.
      await prefs.setBool(kTourDoneKey, true);
      await prefs.setInt(kSessionsKey, 1);
      expect(tipsEngineEnabled(prefs), isFalse);
      // 2ª sesión y sin tips previos: habilitado.
      await prefs.setInt(kSessionsKey, 2);
      expect(tipsEngineEnabled(prefs), isTrue);
    });

    test('cooldown de 6 h entre tips', () async {
      final ahora = DateTime(2026, 9, 16, 12);
      SharedPreferences.setMockInitialValues({
        kTourDoneKey: true,
        kSessionsKey: 5,
        kTipLastAt: ahora.subtract(const Duration(hours: 2)).millisecondsSinceEpoch,
      });
      final prefs = await SharedPreferences.getInstance();
      expect(tipsEngineEnabled(prefs, now: ahora), isFalse, reason: 'hace 2 h');
      final hace7h = ahora.subtract(const Duration(hours: 7)).millisecondsSinceEpoch;
      await prefs.setInt(kTipLastAt, hace7h);
      expect(tipsEngineEnabled(prefs, now: ahora), isTrue, reason: 'hace 7 h');
    });
  });

  group('Disparo en pantalla', () {
    testWidgets('conversor: muestra UN tip la primera vez y no repite', (tester) async {
      SharedPreferences.setMockInitialValues({
        kTourDoneKey: true,
        kSessionsKey: 5,
      });
      final prefs = await SharedPreferences.getInstance();
      final store = AppStore.withData(const AppData());
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          Provider<SharedPreferences>.value(value: prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ConverterScreen()),
        ),
      ));
      // El trigger dispara tras el primer frame; el overlay no tiene
      // animaciones infinitas → algunos frames y aparece.
      for (var i = 0;
          i < 20 && find.text('Escribe en cualquiera de los dos').evaluate().isEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Escribe en cualquiera de los dos'), findsOneWidget);
      expect(find.text('TIP'), findsOneWidget);
      // Se marcó ANTES de mostrarse: una sola vez por instalación.
      expect(isTipShown(prefs, 'conversor.inverso'), isTrue);
      // Entendido cierra.
      await tester.tap(find.text('Entendido'));
      for (var i = 0;
          i < 20 && find.text('Escribe en cualquiera de los dos').evaluate().isNotEmpty;
          i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Escribe en cualquiera de los dos'), findsNothing);
      // Re-montar la pantalla NO vuelve a mostrarlo (id ya visto).
      await tester.pumpWidget(MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          Provider<SharedPreferences>.value(value: prefs),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const Scaffold(body: ConverterScreen()),
        ),
      ));
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(find.text('Escribe en cualquiera de los dos'), findsNothing);
    });

    testWidgets('sin SharedPreferences en el árbol → silencio (no explota)', (tester) async {
      final store = AppStore.withData(const AppData());
      await tester.pumpWidget(MultiProvider(
        providers: [ChangeNotifierProvider.value(value: store)],
        child: const MaterialApp(
          home: Scaffold(body: ConverterScreen()),
        ),
      ));
      for (var i = 0; i < 6; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }
      expect(tester.takeException(), isNull);
    });
  });
}
