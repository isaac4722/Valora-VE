/// Store y tema como proveedores — AppStore hidrata Hive ANTES del primer
/// frame (offline-first) y ThemeController carga sus prefs; ambos se crean
/// en main() y entran por overrides.
library;

import 'package:flutter_riverpod/legacy.dart' show ChangeNotifierProvider;

import '../data/store.dart';
import '../state/app_state.dart' show ThemeController;

/// Store de la app (Hive ya hidratado). Debe sobre-escribirse en main().
final appStoreProvider = ChangeNotifierProvider<AppStore>((ref) {
  throw UnimplementedError(
    'appStoreProvider debe sobre-escribirse en main() vía '
    'ProviderScope.overrides.',
  );
});

/// Tema light/dark/system + Material You opt-in.
final themeControllerProvider = ChangeNotifierProvider<ThemeController>((ref) {
  throw UnimplementedError(
    'themeControllerProvider debe sobre-escribirse en main() vía '
    'ProviderScope.overrides.',
  );
});
