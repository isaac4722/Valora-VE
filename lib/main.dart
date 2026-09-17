/// ─── ValoraVE · arranque de la app ─────────────────────────────────────────
/// Offline-first: Hive + SharedPreferences hidratan ANTES del primer frame;
/// fuentes empaquetadas (Inter + Space Grotesk) tipografían igual sin red;
/// el tablero pinta vacío honesto y refresca cuando haya conectividad.
/// v17.8: la señal de red (connectivity_plus) se conoce desde el arranque —
/// sin red NO se finge «Buscando tasas…» ni se martillea cada 60 s: la app
/// client-side funciona completa con lo guardado y se actualiza sola al
/// volver la conexión.
library;

import 'package:dynamic_color/dynamic_color.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/theme.dart';
import 'data/store.dart';
import 'services/biometric.dart';
import 'services/connectivity.dart';
import 'services/notifications.dart';
import 'services/quick_actions.dart';
import 'services/widget_service.dart';
import 'services/workmanager_service.dart';
import 'state/app_state.dart';
import 'widgets/app_router.dart';
import 'widgets/app_tips.dart' show kSessionsKey;

/// [documentsDir] es un seam de pruebas: null en producción (path_provider
/// resuelve el directorio); en tests/host se pasa un directorio temporal
/// para que Hive hidrate sin canales de plataforma.
Future<void> main({String? documentsDir}) async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);

  final store = AppStore();
  await store.hydrate(testDir: documentsDir);
  final prefs = await SharedPreferences.getInstance();
  // Sesiones para el motor de tips (v19): los tips contextuales empiezan a
  // partir de la SEGUNDA apertura — nunca «de una vez» tras el tutorial.
  final sessions = prefs.getInt(kSessionsKey) ?? 0;
  await prefs.setInt(kSessionsKey, sessions + 1);
  final theme = ThemeController();
  await theme.load(prefs);
  // Señal de red (v17.8): tolerante — si el canal no existe (host de
  // pruebas) queda «online» y nada de la app se bloquea.
  final connectivity = ConnectivityService();
  try {
    await connectivity.init();
  } catch (_) {
    // Degradación honesta: sin señal de conectividad la app funciona igual
    // con el ciclo clásico de reintentos.
  }
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

  runApp(
    MultiProvider(
      providers: appProviders(
        store: store,
        theme: theme,
        notifs: notifs,
        prefs: prefs,
        connectivity: connectivity,
      ),
      child: ValoraApp(store: store),
    ),
  );
}

class ValoraApp extends StatefulWidget {
  const ValoraApp({super.key, required this.store});

  /// El mismo store que vive en los providers: el router lo necesita como
  /// refreshListenable y se crea una única vez en initState.
  final AppStore store;

  @override
  State<ValoraApp> createState() => _ValoraAppState();
}

class _ValoraAppState extends State<ValoraApp> with WidgetsBindingObserver {
  /// Router ÚNICO por sesión (ver contrato en app_router.dart): crearlo
  /// dentro de build() reiniciaba la navegación en cada mutación del store
  /// y atrapaba al usuario en la pantalla de bienvenida.
  late final GoRouter _router = buildRouter(store: widget.store);

  /// Bloqueo biométrico al abrir (17.7): mientras no se resuelva la primera
  /// autenticación se muestra la puerta de marca — jamás el contenido.
  bool _locked = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // Shortcuts del launcher (4 del manifest PWA): tras el primer frame,
    // con el router único ya montado. Falla silencioso sin canal nativo.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      QuickActionsService.bind(_router);
      QuickActionsService.init();
    });
    // Primer refresco tras el primer frame (no bloquea LCP).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final poller = context.read<RatesPoller>();
      poller.refreshNow();
      poller.startAuto();
    });
    // Puerta biométrica (17.7): sin lock configurado o sin soporte → entra
    // directo (canCheck false NUNCA bloquea — ver biometric.dart).
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      if (!widget.store.settings.biometricLock) {
        setState(() => _locked = false);
        return;
      }
      final ok = await _tryUnlock();
      if (mounted) setState(() => _locked = !ok);
    });
  }

  Future<bool> _tryUnlock() async {
    try {
      return await BiometricService().authenticate(
        reason: 'Desbloquea ValoraVE para ver tus tasas y tus datos',
      );
    } catch (_) {
      return true; // degradación honesta: sin canal, no bloquea
    }
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
    // Puerta biométrica (17.7): mientras está cerrada no se monta el árbol
    // de navegación — la marca sí, con reintento. Sin lock → directo.
    if (_locked) {
      final theme = context.watch<ThemeController>();
      return DynamicColorBuilder(
        builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
          return MaterialApp(
            title: 'ValoraVE',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light(
              theme.dynamicColor ? lightDynamic?.harmonized() : null,
            ),
            darkTheme: AppTheme.dark(
              theme.dynamicColor ? darkDynamic?.harmonized() : null,
            ),
            themeMode: theme.mode,
            locale: const Locale('es', 'VE'),
            // Delegates es-VE (fix): sin ellos, MaterialComponents en inglés
            // (showDatePicker «SELECT DATE»/CANCEL/OK) en una UI 100 % es-VE.
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const <Locale>[Locale('es', 'VE'), Locale('es')],
            home: _BiometricLockScreen(
              onRetry: () async {
                final ok = await _tryUnlock();
                if (mounted) setState(() => _locked = !ok);
              },
            ),
          );
        },
      );
    }
    // SOLO el tema se mira aquí: observar el store en la raíz reconstruía
    // MaterialApp en cada mutación (60 s de poller, cada tap) y, con el
    // router creado en build, fabricaba un GoRouter nuevo por ciclo.
    // Las pantallas se suscriben al store individualmente.
    final theme = context.watch<ThemeController>();
    // Material You (dp6 · mejora 2): DynamicColorBuilder no exige canal —
    // sin plataforma devuelve null y el tema queda 100 % de marca.
    return DynamicColorBuilder(
      builder: (ColorScheme? lightDynamic, ColorScheme? darkDynamic) {
        return MaterialApp.router(
          title: 'ValoraVE',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(
            theme.dynamicColor ? lightDynamic?.harmonized() : null,
          ),
          darkTheme: AppTheme.dark(
            theme.dynamicColor ? darkDynamic?.harmonized() : null,
          ),
          themeMode: theme.mode,
          locale: const Locale('es', 'VE'),
          // Delegates es-VE (fix): ídem arriba — componentes Material en
          // español real (date pickers, tooltips de texto, etc.).
          localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: const <Locale>[Locale('es', 'VE'), Locale('es')],
          routerConfig: _router,
        );
      },
    );
  }
}

/// Puerta biométrica de marca (17.7): tipografía pura + sello + botón de
/// reintentar. Se pinta SOLO mientras el lock está activo y sin resolver;
/// sin soporte biométrico la app nunca llega a mostrarla dos veces (el
/// postFrame la abre en el primer intento).
class _BiometricLockScreen extends StatelessWidget {
  const _BiometricLockScreen({required this.onRetry});
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              RichText(
                text: TextSpan(
                  style: VeText.displayNum(
                    40,
                    color: scheme.onSurface,
                    weight: FontWeight.w700,
                  ),
                  children: <InlineSpan>[
                    const TextSpan(text: 'Valora'),
                    TextSpan(
                      text: 'VE',
                      style: TextStyle(color: scheme.primary),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Icon(Icons.fingerprint, size: 42, color: scheme.primary),
              const SizedBox(height: 12),
              Text(
                'Tus datos viven solo aquí',
                style: TextStyle(
                  fontSize: 14.5,
                  fontWeight: FontWeight.w700,
                  color: scheme.onSurface,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Desbloquea con tu huella o tu PIN de pantalla para entrar.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 12.5,
                  height: 1.45,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 22),
              FilledButton.icon(
                onPressed: () => onRetry(),
                icon: const Icon(Icons.lock_open, size: 16),
                label: const Text('Desbloquear'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
