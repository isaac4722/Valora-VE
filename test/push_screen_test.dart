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
import 'package:valorave/room/room_transport.dart';
import 'package:valorave/widgets/ui.dart';

void main() {
  testWidgets('Sala: PushScreen con back, safe-area y modo Servidor visible', (tester) async {
    final store = AppStore.withData(const AppData());
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider(create: (_) => RoomController(store)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        // Se EMPUJA como en producción (push sobre otra ruta → hay back).
        home: Builder(
          builder: (ctx) => TextButton(
            onPressed: () => Navigator.push(ctx,
                MaterialPageRoute<void>(builder: (_) => const RoomScreen())),
            child: const Text('abrir'),
          ),
        ),
      ),
    ));
    await tester.tap(find.text('abrir'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    // Botón ATRÁS visible (AppBar) — la pantalla es empujada.
    expect(find.byType(BackButton), findsOneWidget);
    // SafeArea inferior protege la barra de navegación de Android.
    expect(find.byType(SafeArea), findsWidgets);
    // El modo SERVIDOR sigue existiendo (orden del dueño: no se elimina).
    expect(find.text('Servidor (sockets)'), findsOneWidget);
    expect(find.text('Cerca (sin internet)'), findsOneWidget);
    expect(find.text('Hotspot (sin internet)'), findsOneWidget);
    expect(find.text('WiFi local (LAN)'), findsOneWidget);
    expect(find.text('Bluetooth directo (RFCOMM)'), findsOneWidget);
    expect(find.byType(PushScreen), findsOneWidget);
    // Sin PageHeader pegado al borde: el título vive en el AppBar.
    expect(find.byType(PageHeader), findsNothing);
  });

  testWidgets('Sala: modo servidor muestra la config del servidor propio', (tester) async {
    final store = AppStore.withData(const AppData());
    final ctrl = RoomController(store);
    await tester.pumpWidget(MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider.value(value: ctrl),
      ],
      child: MaterialApp(theme: AppTheme.light(), home: const RoomScreen()),
    ));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    await tester.tap(find.text('Servidor (sockets)'));
    await tester.pumpAndSettle(const Duration(milliseconds: 100));
    expect(find.text('Tu servidor (socket.io)'), findsOneWidget);
    expect(find.byType(TextField), findsAtLeastNWidgets(2)); // host:puerto + token
    expect(find.text('Probar conexión'), findsOneWidget);
  });
}
