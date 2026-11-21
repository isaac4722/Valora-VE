/// SharedPreferences como proveedor (patrón CalculaYa) — la instancia se
/// carga en `main()` antes del primer frame y entra por overrides.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Debe sobre-escribirse en main() vía ProviderScope.overrides.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider debe sobre-escribirse en main() '
    'vía ProviderScope.overrides.',
  );
});
