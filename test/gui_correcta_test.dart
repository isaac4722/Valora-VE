/// TASK-35 · p2 — GUI correcta: notch y toggle de tema.
///
/// 1. NOTCH: con insets reales simulados (59 px arriba · 34 abajo, como un
///    iPhone con notch), el contenido del shell nace BAJO la barra de estado
///    — nunca la campana de la cabecera ni las pestañas quedan debajo.
/// 2. TOGGLE DE TEMA (orden del dueño): el botón de arriba vuelve — un toque
///    alterna el brillo EFECTIVO (system incluido) y persiste la elección.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle, FontLoader, ByteData;
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import 'package:valorave/core/models.dart';
import 'package:valorave/core/shad_theme.dart';
import 'package:valorave/core/theme.dart';
import 'package:valorave/data/store.dart';
import 'package:valorave/services/alerts.dart';
import 'package:valorave/services/notifications.dart';
import 'package:valorave/state/app_state.dart';
import 'package:valorave/widgets/app_router.dart';
import 'package:valorave/widgets/app_tour.dart' show kTourDoneKey;
import 'package:valorave/widgets/ve/ve.dart' show showVeSheet;
import 'package:valorave/features/welcome/welcome_screen.dart';
import 'package:valorave/room/room_controller.dart';

Future<void> main() async {
  TestWidgetsFlutterBinding.ensureInitialized();

  // Fuentes REALES (no Ahem): Ahem mide cada glifo al ancho del fontSize y
  // fabrica overflows falsos («−10 %» = 60 px en Ahem, ~34 en Inter). Con
  // las fuentes del asset las medidas son las del teléfono de verdad.
  Future<void> una(String family, List<Future<ByteData>> assets) async {
    final loader = FontLoader(family);
    for (final a in assets) {
      loader.addFont(a);
    }
    await loader.load();
  }

  final root = rootBundle;
  await una('Inter', [
    root.load('assets/fonts/Inter-Regular.ttf'),
    root.load('assets/fonts/Inter-Medium.ttf'),
    root.load('assets/fonts/Inter-SemiBold.ttf'),
    root.load('assets/fonts/Inter-Bold.ttf'),
  ]);
  await una('SpaceGrotesk', [
    root.load('assets/fonts/SpaceGrotesk-Medium.ttf'),
    root.load('assets/fonts/SpaceGrotesk-Bold.ttf'),
  ]);
  await una('JetBrainsMono', [root.load('assets/fonts/JetBrainsMono.ttf')]);

  Future<(AppStore, ThemeController, SharedPreferences)> prep() async {
    SharedPreferences.setMockInitialValues({kTourDoneKey: true});
    final prefs = await SharedPreferences.getInstance();
    // Onboarded: el router manda directo a Inicio (no a la bienvenida).
    final store = AppStore.withData(
      const AppData(settings: Settings(onboarded: true)),
    );
    final theme = ThemeController();
    return (store, theme, prefs);
  }

  Widget host(AppStore store, ThemeController theme, SharedPreferences prefs) {
    final router = buildRouter(store: store);
    return MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: store),
        ChangeNotifierProvider<ThemeController>.value(value: theme),
        ChangeNotifierProvider(
          create: (_) => RatesPoller(
            store,
            NotificationsService(),
            AlertEngine(prefs),
          ),
        ),
        Provider<SharedPreferences>.value(value: prefs),
      ],
      child: ShadApp.custom(
        theme: ShadThemeVe.light(),
        darkTheme: ShadThemeVe.dark(),
        appBuilder: (context) => MaterialApp.router(
            // v20: sin banner DEBUG — ensuciaba los goldens (cinta diagonal
            // roja arriba a la derecha que el VLM marcaba como slop).
            debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          routerConfig: router,
        ),
      ),
    );
  }

  testWidgets('notch: la cabecera nace bajo el inset superior (59 px)', (
    tester,
  ) async {
    final (store, theme, prefs) = await prep();
    // Viewport móvil 390×844 @2x con notch (59 lógicos = 118 físicos)
    // y home indicator (34 lógicos = 68 físicos).
    tester.view
      ..physicalSize = const Size(780, 1688)
      ..devicePixelRatio = 2.0
      ..padding = FakeViewPadding(top: 118, bottom: 68);
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(store, theme, prefs));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // La campana de la cabecera de Inicio (primer contenido del shell)
    // empieza DEBAJO de la barra de estado — nunca bajo el notch.
    final bell = find.byIcon(LucideIcons.bell);
    expect(bell, findsOneWidget);
    expect(
      tester.getTopLeft(bell).dy,
      greaterThanOrEqualTo(59),
      reason: 'la cabecera debe nacer bajo el notch (inset 59)',
    );

    // Y las pestañas móviles: el contenido del tab respeta el inset inferior
    // (la barra pinta hasta el borde, el icono queda sobre el home indicator).
    final tabIcon = find.byIcon(LucideIcons.home);
    expect(tabIcon, findsOneWidget);
    final tabBottom = tester.getBottomLeft(tabIcon).dy;
    expect(tabBottom, lessThan(844 - 34 + 1));
  });

  testWidgets('toggle de tema: un toque alterna el brillo y persiste', (
    tester,
  ) async {
    final (store, theme, prefs) = await prep();
    tester.view
      ..physicalSize = const Size(780, 1688)
      ..devicePixelRatio = 2.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(store, theme, prefs));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Brillo efectivo claro (system en un host de test es claro) → luna.
    final moon = find.byIcon(LucideIcons.moon);
    expect(moon, findsOneWidget, reason: 'en claro se ofrece pasar a oscuro');

    await tester.tap(moon);
    await tester.pump();

    expect(theme.mode, ThemeMode.dark, reason: 'un toque fija el opuesto');
    expect(prefs.getString('valorave.themeMode'), 'dark');

    // Ahora el botón ofrece volver a claro (sol).
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.byIcon(LucideIcons.sun), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('escritorio: el toggle también vive en el sidebar (700+ px)', (
    tester,
  ) async {
    final (store, theme, prefs) = await prep();
    tester.view
      ..physicalSize = const Size(2560, 1600)
      ..devicePixelRatio = 2.0; // 1280×800 lógicos → sidebar visible
    addTearDown(tester.view.reset);

    await tester.pumpWidget(host(store, theme, prefs));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    // Cabecera de Inicio + marca del sidebar: DOS interruptores en escritorio.
    expect(find.byIcon(LucideIcons.moon), findsNWidgets(2));

    // El del sidebar (a la izquierda, x < 224) también alterna.
    final sidebarMoon = find.byIcon(LucideIcons.moon).first;
    expect(tester.getTopLeft(sidebarMoon).dx, lessThan(224));
    await tester.tap(sidebarMoon);
    await tester.pump();
    expect(theme.mode, ThemeMode.dark);
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('sheet Ve: TECHO — contenido larguío jamás cruza el notch', (
    tester,
  ) async {
    final (store, theme, prefs) = await prep();
    tester.view
      ..physicalSize = const Size(780, 1688)
      ..devicePixelRatio = 2.0
      ..padding = FakeViewPadding(top: 118, bottom: 68);
    addTearDown(tester.view.reset);

    // Host mínimo: un botón que abre una hoja Ve con contenido ENORME.
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider<ThemeController>.value(value: theme),
          Provider<SharedPreferences>.value(value: prefs),
        ],
        child: ShadApp.custom(
          theme: ShadThemeVe.light(),
          darkTheme: ShadThemeVe.dark(),
          appBuilder: (context) => MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            home: Scaffold(
              backgroundColor: Colors.white,
              body: Builder(
                builder: (context) => Center(
                  child: ElevatedButton(
                    onPressed: () => showVeSheet<void>(
                      context: context,
                      title: 'Hoja de prueba',
                      builder: (_) => Column(
                        children: List.generate(
                          60,
                          (i) => Padding(
                            padding: const EdgeInsets.all(12),
                            child: Text('fila $i'),
                          ),
                        ),
                      ),
                    ),
                    child: const Text('abrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('abrir'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // La cabecera de la hoja («Hoja de prueba») nace bajo el notch…
    final header = find.text('Hoja de prueba');
    expect(header, findsOneWidget);
    expect(
      tester.getTopLeft(header).dy,
      greaterThanOrEqualTo(59),
      reason: 'la cabecera de la hoja no puede cruzar el notch',
    );

    // …y el TECHO del 88 % de la altura útil: la hoja completa mide como
    // máximo (844 − 59) × 0.88 ≈ 690 → su borde superior no sube de 844 − 690.
    final firstRow = find.text('fila 0');
    expect(firstRow, findsOneWidget);
    final sheetTop = tester.getTopLeft(header).dy;
    expect(
      sheetTop,
      greaterThanOrEqualTo(844 - (844 - 59) * 0.88 - 1),
      reason: 'el techo del 88 % de la altura útil se respeta',
    );
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('auditoría: TODAS las rutas sin overflow a 390 con notch', (
    tester,
  ) async {
    // Recorre cada pantalla de la app a 390×844 con notch real: cualquier
    // RenderFlex overflow o excepción de layout revienta AQUÍ, no en el
    // teléfono del dueño.
    const routes = <String>[
      '/',
      '/conversor',
      '/lista',
      '/productos',
      '/analisis',
      '/historial',
      '/ajustes',
      '/tickets',
      '/sala',
      '/legal',
    ];
    for (final path in routes) {
      final (store, theme, prefs) = await prep();
      tester.view
        ..physicalSize = const Size(780, 1688)
        ..devicePixelRatio = 2.0
        ..padding = FakeViewPadding(top: 118, bottom: 68);
      addTearDown(tester.view.reset);

      final router = buildRouter(store: store);
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: store),
            ChangeNotifierProvider<ThemeController>.value(value: theme),
            ChangeNotifierProvider(
              create: (_) => RatesPoller(
                store,
                NotificationsService(),
                AlertEngine(prefs),
              ),
            ),
            // v18.0 · Sala Viva: la Lista y /sala comparten el controlador
            // de aplicación — sin él la auditoría no puede navegar a /lista.
            ChangeNotifierProvider(create: (_) => RoomController(store)),
            Provider<SharedPreferences>.value(value: prefs),
          ],
          child: ShadApp.custom(
            theme: ShadThemeVe.light(),
            darkTheme: ShadThemeVe.dark(),
            appBuilder: (context) => MaterialApp.router(
            // v20: sin banner DEBUG — ensuciaba los goldens (cinta diagonal
            // roja arriba a la derecha que el VLM marcaba como slop).
            debugShowCheckedModeBanner: false,
              theme: AppTheme.light(),
              darkTheme: AppTheme.dark(),
              routerConfig: router,
            ),
          ),
        ),
      );
      debugPrint("RUTA-AUDIT: $path");
      router.go(path);
      await tester.pump();
      // Bombeo largo: animaciones de entrada + settle de cada pantalla.
      await tester.pump(const Duration(milliseconds: 600));
      // Cualquier excepción de layout (overflow incluido) se atribuye a la
      // ruta que la causó.
      final exc = tester.takeException();
      expect(exc, isNull, reason: 'la ruta $path no debe lanzar: $exc');
      // Un widget visible cualquiera: la pantalla no quedó en blanco.
      expect(find.byType(Scaffold), findsWidgets);
      // Limpia el árbol antes de la siguiente ruta.
      await tester.pumpWidget(const SizedBox.shrink());
      await tester.pump(const Duration(milliseconds: 100));
    }
  });

  testWidgets('bienvenida (sin onboard): completa sin overflow a 320', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final store = AppStore.withData(const AppData());
    final theme = ThemeController();
    tester.view
      ..physicalSize = const Size(640, 1414) // 320×707: el más estrecho
      ..devicePixelRatio = 2.0
      ..padding = FakeViewPadding(top: 118, bottom: 68);
    addTearDown(tester.view.reset);

    final router = buildRouter(store: store);
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: store),
          ChangeNotifierProvider<ThemeController>.value(value: theme),
          Provider<SharedPreferences>.value(value: prefs),
        ],
        child: ShadApp.custom(
          theme: ShadThemeVe.light(),
          darkTheme: ShadThemeVe.dark(),
          appBuilder: (context) => MaterialApp.router(
            // v20: sin banner DEBUG — ensuciaba los goldens (cinta diagonal
            // roja arriba a la derecha que el VLM marcaba como slop).
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(),
            darkTheme: AppTheme.dark(),
            routerConfig: router,
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.byType(WelcomeScreen), findsOneWidget);
    await tester.pump(const Duration(seconds: 2));
  });
}
