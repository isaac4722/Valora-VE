/// ─── Sala · lobby de conexión (v19.0 · reescrita desde 0) ───────────────────
/// TRES modos P2P sin internet (Cerca · WiFi o Hotspot · Bluetooth), cada
/// uno con su tecnología. Crear = ser anfitrión; Unirse = código de 6 letras
/// o una sala avistada en el escaneo. La sala EN VIVO se vive en su propia
/// pantalla (/sala-viva); aquí solo se configura y entra.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../room/room_controller.dart';
import '../../room/room_transport.dart';
import '../../widgets/ui.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _roomNameCtrl;
  late final TextEditingController _codeCtrl;
  String? _busyError;

  @override
  void initState() {
    super.initState();
    final room = context.read<RoomController>();
    _nameCtrl = TextEditingController(text: room.myName);
    _roomNameCtrl = TextEditingController(text: room.roomName);
    _codeCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _roomNameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _run(Future<String?> Function() action) async {
    setState(() => _busyError = null);
    final err = await action();
    if (!mounted) return;
    if (err != null) {
      setState(() => _busyError = err);
      return;
    }
    // En sala: a la Lista (el strip «En sala» lleva a la Sala Viva).
    if (context.read<RoomController>().connected) {
      showToast(context, 'En sala · la lista se sincroniza', kind: ToastKind.ok);
      context.go('/lista');
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomController>();
    final scheme = Theme.of(context).colorScheme;
    final busy = room.status == RoomStatus.connecting;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      appBar: AppBar(
        title: const Text('Sala en vivo'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const PageHeader('Sala en vivo',
              hint: 'Sincroniza la lista P2P — sin internet, sin cuentas'),
          if (room.connected) _EnSalaBanner(room: room),
          if (_busyError != null || room.lastError != null) ...[
            _ErrorBanner(msg: _busyError ?? room.lastError!),
            const SizedBox(height: 10),
          ],
          if (busy) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(children: [
                  const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Conectando por ${room.modeLabel}…',
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                  TextButton(
                    onPressed: () => room.leave(),
                    child: const Text('Cancelar'),
                  ),
                ]),
              ),
            ),
            const SizedBox(height: 10),
          ],
          _NameCard(ctrl: _nameCtrl),
          _ModePicker(room: room),
          _CreateCard(
            room: room,
            nameCtrl: _nameCtrl,
            roomNameCtrl: _roomNameCtrl,
            busy: busy,
            onRun: _run,
          ),
          _JoinCard(
            room: room,
            nameCtrl: _nameCtrl,
            codeCtrl: _codeCtrl,
            busy: busy,
            onRun: _run,
          ),
          _ScanCard(room: room, nameCtrl: _nameCtrl, busy: busy, onRun: _run),
        ],
      ),
    );
  }
}

/// Banner cuando YA hay sala activa: directo a la Sala Viva.
class _EnSalaBanner extends StatelessWidget {
  const _EnSalaBanner({required this.room});

  final RoomController room;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final title = room.roomName.isNotEmpty ? room.roomName : 'Sala ${room.code}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/sala-viva'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(children: [
            const LiveBadge(live: true, label: 'En sala'),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '$title · ${room.visibleMembers.length} en la sala',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: scheme.onSurface),
              ),
            ),
            Icon(Icons.arrow_forward, size: 16, color: scheme.primary),
          ]),
        ),
      ),
    );
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.msg});

  final String msg;

  @override
  Widget build(BuildContext context) {
    final sem = VeColors.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: sem.neg.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: sem.neg.withValues(alpha: 0.35)),
      ),
      child: Row(children: [
        Icon(Icons.error_outline, size: 16, color: sem.neg),
        const SizedBox(width: 8),
        Expanded(
          child: Text(msg,
              style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: sem.neg)),
        ),
      ]),
    );
  }
}

class _NameCard extends StatelessWidget {
  const _NameCard({required this.ctrl});

  final TextEditingController ctrl;

  @override
  Widget build(BuildContext context) {
    final room = context.read<RoomController>();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('TU NOMBRE', style: VeText.labelCaps(10.5, color: scheme.primary)),
            const SizedBox(height: 8),
            TextField(
              controller: ctrl,
              maxLength: 24,
              onChanged: room.setMyName,
              decoration: const InputDecoration(
                hintText: '¿Cómo te ven en la sala?',
                counterText: '',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// TRES modos P2P, cada uno con SU tecnología — nada de internet.
class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.room});

  final RoomController room;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CÓMO SE CONECTAN', style: VeText.labelCaps(10.5, color: scheme.primary)),
            const SizedBox(height: 4),
            Text('Todo P2P: los teléfonos se hablan directo, sin internet.',
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            for (final m in RoomMode.values)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _ModeTile(
                  mode: m,
                  selected: room.mode == m,
                  onTap: () => room.setMode(m),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.mode,
    required this.selected,
    required this.onTap,
  });

  final RoomMode mode;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final icon = switch (mode) {
      RoomMode.cerca => Icons.wifi_tethering,
      RoomMode.wifi => Icons.router_outlined,
      RoomMode.bt => Icons.bluetooth,
    };
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: selected ? scheme.primary.withValues(alpha: 0.07) : null,
          border: Border.all(
              color: selected
                  ? scheme.primary.withValues(alpha: 0.4)
                  : scheme.outlineVariant),
        ),
        child: Row(children: [
          Icon(icon, size: 20, color: selected ? scheme.primary : scheme.onSurfaceVariant),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(mode.label,
                    style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w800,
                        color: scheme.onSurface)),
                const SizedBox(height: 2),
                Text(mode.tech,
                    style: TextStyle(
                        fontSize: 11, color: scheme.onSurfaceVariant)),
                Text(mode.hint,
                    style: TextStyle(
                        fontSize: 10.5, color: scheme.onSurfaceVariant)),
              ],
            ),
          ),
          if (selected)
            Icon(Icons.check_circle, size: 18, color: scheme.primary),
        ]),
      ),
    );
  }
}

typedef _RoomAction = Future<void> Function(Future<String?> Function() action);

class _CreateCard extends StatelessWidget {
  const _CreateCard({
    required this.room,
    required this.nameCtrl,
    required this.roomNameCtrl,
    required this.busy,
    required this.onRun,
  });

  final RoomController room;
  final TextEditingController nameCtrl;
  final TextEditingController roomNameCtrl;
  final bool busy;
  final _RoomAction onRun;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('CREAR SALA', style: VeText.labelCaps(10.5, color: scheme.primary)),
            const SizedBox(height: 4),
            Text('Tu teléfono es el anfitrión: comparte el código de 6 letras.',
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            TextField(
              controller: roomNameCtrl,
              maxLength: 32,
              onChanged: room.setRoomName,
              decoration: const InputDecoration(
                hintText: 'Nombre de la sala (opcional)',
                counterText: '',
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text('Sala pública',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              subtitle: Text(
                  room.isPublic
                      ? 'Aparece en el escaneo de salas cercanas'
                      : 'Solo entra quien tenga el código',
                  style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant)),
              value: room.isPublic,
              onChanged: room.setPublic,
            ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: busy
                    ? null
                    : () => onRun(() => room.create(
                          name: nameCtrl.text,
                          roomName: roomNameCtrl.text,
                          isPublic: room.isPublic,
                        )),
                icon: const Icon(Icons.add_home_work, size: 17),
                label: Text('Crear por ${room.modeLabel}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _JoinCard extends StatelessWidget {
  const _JoinCard({
    required this.room,
    required this.nameCtrl,
    required this.codeCtrl,
    required this.busy,
    required this.onRun,
  });

  final RoomController room;
  final TextEditingController nameCtrl;
  final TextEditingController codeCtrl;
  final bool busy;
  final _RoomAction onRun;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('UNIRSE CON CÓDIGO', style: VeText.labelCaps(10.5, color: scheme.primary)),
            const SizedBox(height: 4),
            Text('Pide el código de 6 letras al anfitrión.',
                style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant)),
            const SizedBox(height: 10),
            Row(children: [
              Expanded(
                child: TextField(
                  controller: codeCtrl,
                  maxLength: 6,
                  textCapitalization: TextCapitalization.characters,
                  onChanged: (v) => codeCtrl.text = v.toUpperCase(),
                  decoration: const InputDecoration(
                    hintText: 'ABC123',
                    counterText: '',
                    border: OutlineInputBorder(),
                    isDense: true,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              FilledButton.tonal(
                onPressed: busy
                    ? null
                    : () => onRun(
                        () => room.join(name: nameCtrl.text, code: codeCtrl.text)),
                child: const Text('Unirse'),
              ),
            ]),
          ],
        ),
      ),
    );
  }
}

class _ScanCard extends StatefulWidget {
  const _ScanCard({
    required this.room,
    required this.nameCtrl,
    required this.busy,
    required this.onRun,
  });

  final RoomController room;
  final TextEditingController nameCtrl;
  final bool busy;
  final _RoomAction onRun;

  @override
  State<_ScanCard> createState() => _ScanCardState();
}

class _ScanCardState extends State<_ScanCard> {
  @override
  void dispose() {
    // Al salir del lobby, el escaneo muere (no gasta batería de regalo).
    WidgetsBinding.instance.addPostFrameCallback((_) {
      widget.room.stopScan();
    });
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomController>();
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              Expanded(
                child: Text('SALAS CERCANAS',
                    style: VeText.labelCaps(10.5, color: scheme.primary)),
              ),
              TextButton.icon(
                onPressed: widget.busy
                    ? null
                    : () => room.scanning
                        ? room.stopScan()
                        : room.startScan(),
                icon: Icon(
                    room.scanning ? Icons.stop_circle : Icons.radar,
                    size: 17),
                label: Text(room.scanning ? 'Parar' : 'Escuchar'),
              ),
            ]),
            Text(
              'Salas públicas por ${room.modeLabel}. ${room.mode.hint}',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            if (room.scanning && room.foundRooms.isEmpty)
              Row(children: [
                const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2)),
                const SizedBox(width: 8),
                Text('Buscando…',
                    style:
                        TextStyle(fontSize: 12, color: scheme.onSurfaceVariant)),
              ]),
            for (final ad in room.foundRooms)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: widget.busy
                      ? null
                      : () => widget.onRun(() => room.join(
                          name: widget.nameCtrl.text,
                          code: ad.code,
                          ad: ad)),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    child: Row(children: [
                      Icon(
                        switch (ad.mode) {
                          RoomMode.cerca => Icons.wifi_tethering,
                          RoomMode.wifi => Icons.router_outlined,
                          RoomMode.bt => Icons.bluetooth,
                        },
                        size: 18,
                        color: scheme.primary,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(ad.label,
                                style: const TextStyle(
                                    fontSize: 13, fontWeight: FontWeight.w700)),
                            Text(
                                '${ad.code} · anfitrión ${ad.hostName}',
                                style: TextStyle(
                                    fontSize: 11,
                                    color: scheme.onSurfaceVariant)),
                          ],
                        ),
                      ),
                      Icon(Icons.login, size: 16, color: scheme.primary),
                    ]),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
