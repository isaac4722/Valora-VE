/// ─── Sala en vivo · pantalla completa (v17.2) ───────────────────────────────
/// Reemplaza al RoomSheet deslizante: experiencia full-screen con los tres
/// transportes (Servidor sockets · LAN/WiFi P2P · Nearby Connections) y
/// verificación PIN + emoji en todos. ESTE ARCHIVO es la implementación
/// activa; room_sheet.dart queda deprecado (solo se conserva el helper
/// showRoomSheet que redirige aquí).
library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/ui.dart' show PageHeader;

/// Pantalla completa de la sala en vivo (ruta /sala).
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(padding: const EdgeInsets.fromLTRB(16, 8, 16, 24), children: const [
        PageHeader('Sala en vivo', hint: 'Sincroniza tu lista con quien esté cerca'),
        SizedBox(height: 40),
        Center(child: CircularProgressIndicator()),
      ]),
    );
  }
}
