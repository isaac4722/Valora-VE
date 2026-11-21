/// Sala Viva como proveedor — controlador de APLICACIÓN: la Lista, la
/// configuración de sala y la Sala Viva comparten el MISMO estado (v18.0).
library;

import 'package:flutter_riverpod/legacy.dart' show ChangeNotifierProvider;

import '../room/room_controller.dart';
import 'store_provider.dart';

final roomControllerProvider = ChangeNotifierProvider<RoomController>((ref) {
  return RoomController(ref.watch(appStoreProvider));
});
