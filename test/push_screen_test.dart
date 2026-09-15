/// Tests de las pantallas EMPUJADAS (v19): Sala y Tickets respetan notch y
/// barras del sistema (PushScreen con AppBar + back + SafeArea inferior),
/// espaciado uniforme y la opción «Servidor» sigue disponible.
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/core/models.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/features/room/room_screen.dart';
import 'package:valorave/room/room_controller.dart';

void main() {
  testWidgets('Sala: PushScreen con back, safe-area y modo Servidor visible', (
    tester,
  ) async {
    final store = AppStore.withData(const AppData());
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider(create: (_) => RoomController(store)),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          // Se EMPUJA como en producción (push sobre otra ruta → hay back).
          home: Builder(
            builder: (ctx) => TextButton(
              onPressed: () => Navigator.push(
                ctx,
                MaterialPageRoute<void>(builder: (_) => const RoomScreen()),
              ),
              child: const Text('abrir'),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    // Botón ATRÁS visible (AppBar) — la pantalla es empujada.
    expect(find.byIcon(Icons.arrow_back), findsOneWidget);
    // SafeArea inferior protege la barra de navegación de Android.
    expect(find.byType(SafeArea), findsWidgets);
    // Los 4 modos: tres P2P + SERVIDOR (orden del dueño: no se elimina).
    expect(find.text('Servidor'), findsOneWidget);
    expect(find.text('Cerca'), findsOneWidget);
    expect(find.text('WiFi o Hotspot'), findsOneWidget);
    expect(find.text('Bluetooth'), findsOneWidget);
  });

  testWidgets('Sala: modo servidor muestra la config del servidor propio', (
    tester,
  ) async {
    final store = AppStore.withData(const AppData());
    final ctrl = RoomController(store);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider.value(value: ctrl),
        ],
        child: MaterialApp(theme: AppTheme.light(), home: const RoomScreen()),
      ),
    );
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    // El tile Servidor puede quedar bajo el pliegue: drag del ListView.
    for (
      var i = 0;
      i < 10 && !find.text('Servidor').hitTestable().evaluate().isNotEmpty;
      i++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle(const Duration(milliseconds: 60));
    }
    await tester.tap(find.text('Servidor').hitTestable().first);
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    for (
      var i = 0;
      i < 10 && find.text('Tu servidor (socket.io)').evaluate().isEmpty;
      i++
    ) {
      await tester.drag(find.byType(ListView), const Offset(0, -250));
      await tester.pumpAndSettle(const Duration(milliseconds: 60));
    }
    expect(find.text('Tu servidor (socket.io)'), findsOneWidget);
    expect(find.byType(TextField), findsAtLeastNWidgets(2)); // URL + token
    expect(find.text('Probar conexión'), findsOneWidget);
    expect(find.text('¿Cómo monto mi servidor?'), findsOneWidget);
  });
}
