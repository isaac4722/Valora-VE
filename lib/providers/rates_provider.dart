/// Ciclo de tasas como proveedor (el `ratesProvider`+`RatesNotifier` de
/// CalculaYa, en dialecto ValoraVE): el poller nace de las dependencias ya
/// montadas y vive lo que vive el ProviderScope.
library;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart' show ChangeNotifierProvider;

import '../services/alerts.dart';
import '../state/app_state.dart' show RatesPoller;
import 'services_provider.dart';
import 'shared_prefs_provider.dart';
import 'store_provider.dart';

/// Motor de alertas (umbrales en SharedPreferences).
final alertsProvider = Provider<AlertEngine>((ref) {
  return AlertEngine(ref.watch(sharedPreferencesProvider));
});

/// Ciclo de tasas: poll 60 s + SSE opcional + apagado idle.
final ratesPollerProvider = ChangeNotifierProvider<RatesPoller>((ref) {
  return RatesPoller(
    ref.watch(appStoreProvider),
    ref.watch(notificationsProvider),
    ref.watch(alertsProvider),
    connectivity: ref.watch(connectivityProvider),
  );
});
