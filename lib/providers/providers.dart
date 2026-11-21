/// ─── Proveedores Riverpod de ValoraVE (patrón CalculaYa) ───────────────────
/// Flutter Riverpod 3 con notifiers manuales (sin codegen): el estado de la
/// app vive aquí. `main()` crea lo que hidrata antes del primer frame
/// (store Hive, prefs, tema, notificaciones) y lo inyecta con overrides;
/// lo demás (poller de tasas, Sala Viva, alertas) nace solo bajo demanda.
///
/// Consumo en pantallas (igual que CalculaYa):
///   class MiPantalla extends ConsumerWidget {
///     Widget build(BuildContext context, WidgetRef ref) {
///       final store = ref.watch(appStoreProvider);
library;

export 'rates_provider.dart';
export 'room_provider.dart';
export 'services_provider.dart';
export 'shared_prefs_provider.dart';
export 'store_provider.dart';
