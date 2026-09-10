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

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final store = AppStore();
  await store.hydrate();
  final prefs = await SharedPreferences.getInstance();
  final theme = ThemeController();
  await theme.load(prefs);
  final notifs = NotificationsService();
  await notifs.init();
  await WidgetService.init();
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
