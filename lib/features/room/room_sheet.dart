/// ─── Sala en vivo · REDIRECT (v17.2) ────────────────────────────────────────
/// El sheet deslizante se retiró (decisión del dueño): showRoomSheet lleva
/// a la pantalla completa /sala (room_screen.dart). El resto del archivo
/// viejo se eliminó; la implementación activa vive en room_screen.dart.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

/// Redirige a la sala en vivo como PANTALLA COMPLETA (v17.2): la hoja
/// deslizante se retiró por decisión del dueño. La implementación activa
/// vive en room_screen.dart (ruta /sala).
void showRoomSheet(BuildContext context) {
  GoRouter.of(context).push('/sala');
}
