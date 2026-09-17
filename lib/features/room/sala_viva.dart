/// ─── Sala Viva (v19.0 · reescrita sobre el protocolo hello/welcome) ─────────
/// La sala EN VIVO: código + QR para invitar, miembros con roles, gobierno
/// del anfitrión (renombrar, expulsar, roles, cerrar) y salida limpia. Sin
/// PIN: el código de 6 letras ES el secreto (reescritura v19.0). Si la
/// conexión se cae, vuelve sola a la Lista — nunca un limbo.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../room/room_controller.dart';
import '../../room/room_transport.dart';
import '../../widgets/ui.dart';

const String kSalaVivaRoute = '/sala-viva';

class SalaVivaScreen extends StatefulWidget {
  const SalaVivaScreen({super.key});

  @override
  State<SalaVivaScreen> createState() => _SalaVivaScreenState();
}

class _SalaVivaScreenState extends State<SalaVivaScreen> {
  RoomController? _watched;

  void _onRoomChanged() {
    if (!mounted) return;
    final room = _watched;
    if (room == null) return;
    if (!room.connected && room.status != RoomStatus.connecting) {
      // La conexión cayó: vuelve a la Lista — nunca un limbo.
      context.go('/lista');
    }
  }

  @override
  void initState() {
    super.initState();
    final room = context.read<RoomController>();
    if (!room.connected && room.status != RoomStatus.connecting) {
      // Sin sala: nada que ver aquí.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) context.go('/lista');
      });
      return;
    }
    // La conexión puede caerse mientras estamos dentro.
    _watched = room;
    room.addListener(_onRoomChanged);
  }

  @override
  void dispose() {
    _watched?.removeListener(_onRoomChanged);
    super.dispose();
  }

  Future<void> _confirmLeave() async {
    final room = context.read<RoomController>();
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(room.isHost ? '¿Cerrar tu sala?' : '¿Salir de la sala?'),
        content: Text(
          room.isHost
              ? 'Al cerrar, todos los invitados vuelven a su lista con lo '
                    'último sincronizado.'
              : 'El anfitrión y el resto siguen en la sala.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Quedarme'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(room.isHost ? 'Cerrar sala' : 'Salir'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await room.leave();
      if (mounted) context.go('/lista');
    }
  }

  Future<void> _renameDialog() async {
    final room = context.read<RoomController>();
    final c = TextEditingController(text: room.roomName);
    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Renombrar sala'),
        content: TextField(
          controller: c,
          maxLength: 32,
          autofocus: true,
          decoration: const InputDecoration(
            hintText: 'Nombre de la sala',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(c.text),
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
    // Fix leak: dispose del controller del diálogo (cada apertura dejaba
    // uno vivo).
    c.dispose();
    if (name != null && name.trim().isNotEmpty) {
      await room.renameRoom(name);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomController>();
    final members = room.visibleMembers;
    final title = room.roomName.isNotEmpty
        ? room.roomName
        : (room.code.isNotEmpty ? 'Sala ${room.code}' : 'Sala en vivo');

    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.surfaceContainerLowest,
      appBar: AppBar(
        title: Text(title),
        actions: [
          IconButton(
            tooltip: 'Salir de la sala',
            icon: const Icon(Icons.logout),
            onPressed: _confirmLeave,
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          PageHeader(title, hint: 'En vivo · ${room.modeLabel}'),
          if (room.lastError != null) _ErrorBanner(msg: room.lastError!),
          if (!room.connected) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text(
                        'Conectando con la sala…',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (room.isViewer)
            _ViewerNotice(
              card: Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: [
                      Icon(
                        Icons.visibility_outlined,
                        size: 16,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                      const SizedBox(width: 8),
                      const Expanded(
                        child: Text(
                          'Eres observador: ves la lista en vivo, pero no la tocas.',
                          style: TextStyle(fontSize: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          if (room.canAdmin)
            _AdminBar(onRename: _renameDialog, onClose: _confirmLeave),
          _CodigoQrCard(room: room),
          _MiembrosCard(room: room, members: members),
        ],
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
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sem.neg.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: sem.neg.withValues(alpha: 0.35)),
        ),
        child: Row(
          children: [
            Icon(Icons.error_outline, size: 16, color: sem.neg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: sem.neg,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ViewerNotice extends StatelessWidget {
  const _ViewerNotice({required this.card});

  final Widget card;

  @override
  Widget build(BuildContext context) =>
      Padding(padding: const EdgeInsets.only(bottom: 10), child: card);
}

/// Barra de gobierno del anfitrión: renombrar y cerrar.
class _AdminBar extends StatelessWidget {
  const _AdminBar({required this.onRename, required this.onClose});

  final VoidCallback onRename;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: onRename,
              icon: const Icon(Icons.edit, size: 15),
              label: const Text('Renombrar', style: TextStyle(fontSize: 12.5)),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.tonalIcon(
              onPressed: onClose,
              icon: const Icon(Icons.close, size: 15),
              label: const Text(
                'Cerrar sala',
                style: TextStyle(fontSize: 12.5),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Código + QR + modo: lo que se comparte para invitar.
class _CodigoQrCard extends StatelessWidget {
  const _CodigoQrCard({required this.room});

  final RoomController room;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Stamp(room.modeLabel, color: sem.pos),
                const SizedBox(width: 6),
                if (room.roomName.isNotEmpty)
                  Expanded(
                    child: Text(
                      room.roomName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                Stamp(room.isPublic ? 'pública' : 'privada'),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              'CÓDIGO DE LA SALA',
              style: VeText.labelCaps(10.5, color: scheme.primary),
            ),
            const SizedBox(height: 6),
            InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () {
                Clipboard.setData(ClipboardData(text: room.code));
                showToast(context, 'Código copiado', kind: ToastKind.ok);
              },
              child: Text(
                room.code.isEmpty ? '—' : room.code,
                style: VeText.displayNum(38, color: scheme.onSurface),
              ),
            ),
            Text(
              'toca para copiar',
              style: TextStyle(fontSize: 10.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            if (room.code.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: scheme.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: QrImageView(
                  data: 'valorave-sala:${room.code}',
                  version: QrVersions.auto,
                  size: 170,
                  backgroundColor: Colors.transparent,
                ),
              ),
            const SizedBox(height: 8),
            Text(
              'Comparte el código o el QR — quien lo tenga entra con la '
              'tecnología ${room.modeLabel}.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            if (room.isHost && room.lanAddress.isNotEmpty) ...[
              const SizedBox(height: 8),
              Text(
                'Este teléfono es la sala: ${room.lanAddress}',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 11,
                  color: scheme.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Miembros con roles; el anfitrión administra (expulsar · editor/observador).
class _MiembrosCard extends StatelessWidget {
  const _MiembrosCard({required this.room, required this.members});

  final RoomController room;
  final List<RoomMember> members;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    'MIEMBROS (${members.length})',
                    style: VeText.labelCaps(10.5, color: scheme.primary),
                  ),
                ),
                if (room.connected)
                  IconButton(
                    tooltip: 'Avisar que estás escribiendo',
                    icon: Icon(Icons.keyboard, size: 17, color: scheme.primary),
                    onPressed: room.sendTyping,
                  ),
              ],
            ),
            for (final m in members)
              _MemberTile(
                room: room,
                m: m,
                isMe: m.id == room.myId || (m.id == 'host' && room.isHost),
              ),
          ],
        ),
      ),
    );
  }
}

class _MemberTile extends StatelessWidget {
  const _MemberTile({required this.room, required this.m, required this.isMe});

  final RoomController room;
  final RoomMember m;
  final bool isMe;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isHostRow = m.id == 'host';
    final canManage = room.canAdmin && !isHostRow && m.id != room.myId;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: scheme.primary.withValues(alpha: 0.10),
            child: Text(
              m.name.isEmpty ? '?' : m.name.characters.first.toUpperCase(),
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                color: scheme.primary,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(
                        isMe ? '${m.name} (tú)' : m.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurface,
                        ),
                      ),
                    ),
                    if (m.typing) ...[
                      const SizedBox(width: 6),
                      Text(
                        'escribe…',
                        style: TextStyle(
                          fontSize: 10.5,
                          fontStyle: FontStyle.italic,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ],
                ),
                Text(
                  isHostRow
                      ? 'Anfitrión'
                      : (m.role == 'viewer' ? 'Observador' : 'Editor'),
                  style: TextStyle(
                    fontSize: 11,
                    color: scheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          if (canManage)
            PopupMenuButton<String>(
              icon: Icon(
                Icons.more_vert,
                size: 17,
                color: scheme.onSurfaceVariant,
              ),
              onSelected: (v) async {
                if (v == 'role') {
                  await room.setMemberRole(
                    m.id,
                    m.role == 'viewer' ? 'editor' : 'viewer',
                  );
                } else if (v == 'kick') {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: Text('¿Sacar a ${m.name}?'),
                      content: const Text(
                        'Solo sale esta persona; el resto de la sala sigue.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(context).pop(false),
                          child: const Text('Cancelar'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.of(context).pop(true),
                          child: const Text('Sacar'),
                        ),
                      ],
                    ),
                  );
                  if (ok == true) await room.kickMember(m.id);
                }
              },
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'role',
                  child: Text(
                    m.role == 'viewer' ? 'Hacer editor' : 'Hacer observador',
                  ),
                ),
                const PopupMenuItem(
                  value: 'kick',
                  child: Text('Sacar de la sala'),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
