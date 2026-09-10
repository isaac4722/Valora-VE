/// ─── Sala en vivo · UI (lobby + sala activa) — §9.9 room-share ──────────────
/// Selector de modo «Servidor · Cerca (sin internet) · WiFi local», código
/// grande + copia + QR (qr_flutter), miembros con presencia y typing,
/// estado de conexión visible, fallback outbox.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../data/store.dart';
import '../../room/room_transport.dart';
import '../../widgets/ui.dart';

/// Abre la hoja de sala desde la Lista.
void showRoomSheet(BuildContext context) {
  final store = context.read<AppStore>();
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    builder: (_) => ChangeNotifierProvider(
      create: (_) => RoomController(store),
      child: const RoomSheet(),
    ),
  );
}

class RoomSheet extends StatefulWidget {
  const RoomSheet({super.key});

  @override
  State<RoomSheet> createState() => _RoomSheetState();
}

class _RoomSheetState extends State<RoomSheet> {
  final _nameCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomController>();
    final scheme = Theme.of(context).colorScheme;
    final connected = room.connected;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.72,
        maxChildSize: 0.94,
        builder: (context, scroll) => connected || room.status == RoomStatus.connecting
            ? _ActiveRoom(controller: room)
            : ListView(
                controller: scroll,
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
                children: [
                  Row(children: [
                    Icon(Icons.groups_outlined, size: 20, color: scheme.primary),
                    const SizedBox(width: 8),
                    Text('Compra en grupo', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800, color: scheme.onSurface)),
                  ]),
                  const SizedBox(height: 6),
                  Text('Comparte la lista en tiempo real. Los cambios viajan por el '
                          'camino que tú elijas; sin conexión queda en outbox y sale al reconectar.',
                      style: TextStyle(fontSize: 12.5, height: 1.45, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 14),
                  // Selector de modo.
                  SegmentedChips<String>(
                    options: const ['server', 'nearby', 'lan'],
                    value: room.mode,
                    onChanged: room.setMode,
                    labelOf: (m) => switch (m) {
                      'nearby' => 'Cerca (sin internet)',
                      'lan' => 'WiFi local',
                      _ => 'Servidor',
                    },
                  ),
                  const SizedBox(height: 6),
                  Text(
                    switch (room.mode) {
                      'nearby' => 'WiFi-Direct/Bluetooth/BLE: no necesita internet, solo cercanía.',
                      'lan' => 'Mismo WiFi: el creador anuncia la sala, los demás la descubren sola.',
                      _ => 'Un servidor socket.io con el protocolo lista-sync (URL en Ajustes → Sala).',
                    },
                    style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _nameCtrl,
                    decoration: const InputDecoration(hintText: 'Tu nombre (máx 24)'),
                    maxLength: 24,
                  ),
                  const SizedBox(height: 8),
                  // Crear.
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Crear sala'),
                      onPressed: () async {
                        final err = await room.join(
                            code: '', name: _nameCtrl.text.isEmpty ? 'Comprador' : _nameCtrl.text, mode: room.mode);
                        setState(() => _error = err);
                      },
                    ),
                  ),
                  const Padding(
                    padding: EdgeInsets.symmetric(vertical: 10),
                    child: Row(children: [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: Text('o únete', style: TextStyle(fontSize: 11.5)),
                      ),
                      Expanded(child: Divider()),
                    ]),
                  ),
                  TextField(
                    controller: _codeCtrl,
                    textCapitalization: TextCapitalization.characters,
                    maxLength: 6,
                    decoration: const InputDecoration(hintText: 'CÓDIGO DE 6 LETRAS'),
                  ),
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.login, size: 16),
                      label: const Text('Unirme a la sala'),
                      onPressed: () async {
                        final code = _codeCtrl.text.trim().toUpperCase();
                        if (code.length != 6) {
                          setState(() => _error = 'El código tiene 6 letras');
                          return;
                        }
                        final err = await room.join(
                            code: code, name: _nameCtrl.text.isEmpty ? 'Comprador' : _nameCtrl.text, mode: room.mode);
                        setState(() => _error = err);
                      },
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 8),
                    Text(_error!, style: TextStyle(fontSize: 12.5, color: VeColors.of(context).neg)),
                  ],
                ],
              ),
      ),
    );
  }
}

class _ActiveRoom extends StatelessWidget {
  const _ActiveRoom({required this.controller});
  final RoomController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 20),
      children: [
        Row(children: [
          LiveDot(color: controller.connected ? VeColors.of(context).pos : VeColors.of(context).warn),
          const SizedBox(width: 8),
          Text('En vivo · ${controller.code}',
              style: VeText.displayNum(20, color: scheme.onSurface)),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.close, color: VeColors.of(context).neg),
            tooltip: 'Salir de la sala',
            onPressed: () async {
              await controller.leave();
              if (context.mounted) Navigator.pop(context);
            },
          ),
        ]),
        Text('Modo: ${controller.transportName} · ${store.cart.length} ítems en la lista',
            style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 12),
        Center(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(14),
            ),
            child: QrImageView(
              data: 'valorave://sala/${controller.code}',
              size: 140,
            ),
          ),
        ),
        const SizedBox(height: 10),
        Center(
          child: OutlinedButton.icon(
            icon: const Icon(Icons.copy, size: 14),
            label: Text('Copiar código ${controller.code}', style: const TextStyle(fontSize: 12.5)),
            onPressed: () => copiarAlPortapapeles(context, controller.code, 'Código copiado'),
          ),
        ),
        const SizedBox(height: 16),
        Text('MIEMBROS (${controller.members.length}/8)', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
        const SizedBox(height: 6),
        for (final m in controller.members)
          ListTile(
            dense: true,
            contentPadding: EdgeInsets.zero,
            leading: LiveDot(color: m.online ? VeColors.of(context).pos : scheme.onSurfaceVariant),
            title: Text(m.name, style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w600)),
            subtitle: m.typing ? const Text('escribiendo…', style: TextStyle(fontSize: 11.5)) : null,
            trailing: m.name == controller.myName
                ? Stamp('tú', color: scheme.primary)
                : null,
          ),
        const SizedBox(height: 8),
        Text(
          'Los ítems que agregues o marques viajan a la sala al instante. '
              'Si pierdes conexión, los cambios quedan en el outbox y salen al reconectar.',
          style: TextStyle(fontSize: 11.5, height: 1.5, color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}

extension on RoomController {
  String get transportName => switch (mode) {
        'nearby' => 'Cerca',
        'lan' => 'WiFi local',
        _ => 'Servidor',
      };
}
