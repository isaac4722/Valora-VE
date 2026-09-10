/// ─── ValoraVE · arranque de la app ─────────────────────────────────────────
/// Offline-first: Hive + SharedPreferences hidratan ANTES del primer frame;
/// fuentes empaquetadas (Inter + Space Grotesk) tipografían igual sin red;
/// el tablero pinta vacío honesto y refresca cuando haya conectividad.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'data/store.dart';
import 'services/notifications.dart';
import 'services/widget_service.dart';
import 'services/workmanager_service.dart';
import 'state/app_state.dart';
import 'widgets/app_router.dart';

/// [documentsDir] es un seam de pruebas: null en producción (path_provider
/// resuelve el directorio); en tests/host se pasa un directorio temporal
/// para que Hive hidrate sin canales de plataforma.
Future<void> main({String? documentsDir}) async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final store = AppStore();
  await store.hydrate(testDir: documentsDir);
  final prefs = await SharedPreferences.getInstance();
  final theme = ThemeController();
  await theme.load(prefs);
  final notifs = NotificationsService();
  try {
    await notifs.init();
  } catch (_) {
    // Degradación honesta: sin canal de notificaciones (host de prueba,
    // OEM capado) la app arranca igual; el centro de notificaciones interno
    // sigue funcionando. El arranque jamás depende de un plugin.
  }
  try {
    await WidgetService.init();
  } catch (_) {
    // Ídem: sin canal home_widget (host de prueba) no hay widgets de
    // escritorio, pero nada del resto de la app se ve afectado.
  }
  try {
    await initWorkmanager();
  } catch (_) {
    // workmanager puede fallar en tests/emuladores sin servicios de Google.
  }

  runApp(MultiProvider(
    providers: appProviders(store: store, theme: theme, notifs: notifs, prefs: prefs),
    child: const ValoraApp(),
  ));
}

class ValoraApp extends StatefulWidget {
  const ValoraApp({super.key});

  @override
  State<ValoraApp> createState() => _ValoraAppState();
}

class _ValoraAppState extends State<ValoraApp> with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Primer refresco tras el primer frame (no bloquea LCP).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final poller = context.read<RatesPoller>();
      poller.refreshNow();
      poller.startAuto();
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final poller = context.read<RatesPoller>();
    if (state == AppLifecycleState.resumed) {
      poller.markActive();
      poller.refreshNow();
    } else if (state == AppLifecycleState.paused) {
      poller.markIdle();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = context.watch<ThemeController>();
    final store = context.watch<AppStore>();
    return MaterialApp.router(
      title: 'ValoraVE',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      darkTheme: AppTheme.dark(),
      themeMode: theme.mode,
      locale: const Locale('es', 'VE'),
      routerConfig: buildRouter(
        onboarded: store.settings.onboarded,
      ),
    );
  }
}
