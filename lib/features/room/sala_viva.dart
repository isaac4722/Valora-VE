/// ─── Sala Viva (v19.0 → TASK-35 p4: lenguaje «Ve» del prototipo) ───────────
/// La sala EN VIVO: código + QR para invitar, miembros con roles, gobierno
/// del anfitrión (renombrar, expulsar, roles, cerrar) y salida limpia. Sin
/// PIN: el código de 6 letras ES el secreto (reescritura v19.0). Si la
/// conexión se cae, vuelve sola a la Lista — nunca un limbo.
///
/// Diseño: como el InviteSheet del prototipo (código en mono con tracking
/// amplio, QR centrado, miembros como filas divididas con badge de estado)
/// pero como PANTALLA completa con cabecera Ve y gobierno del anfitrión.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/theme.dart';
import '../../room/room_controller.dart';
import '../../room/room_transport.dart';
import '../../widgets/ui.dart';
import 'pin_emoji.dart';

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

    return PushScreen(
      title: title,
      subtitle: 'En vivo · ${room.modeLabel}',
      // Salida siempre a la mano (anfitrión cierra, invitado sale).
      action: VeIconBtn(
        icon: LucideIcons.doorOpen,
        label: room.isHost ? 'Cerrar sala' : 'Salir de la sala',
        onTap: _confirmLeave,
      ),
      child: VeEntry(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (room.lastError != null) _ErrorBanner(msg: room.lastError!),
            if (!room.connected) ...[
              const _ConnectingCard(),
              const SizedBox(height: 12),
            ],
            if (room.isViewer) const _ViewerNotice(),
            if (room.canAdmin) _AdminBar(onRename: _renameDialog, onClose: _confirmLeave),
            _CodigoQrCard(room: room),
            if (room.isHost && room.hasPin)
              Padding(
                padding: const EdgeInsets.only(top: 10),
                child: PinShowCard(pin: room.pinEmoji, compact: true),
              ),
            const SizedBox(height: 10),
            _MiembrosCard(room: room, members: members),
          ],
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
    final scheme = ShadTheme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: sem.negBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: sem.neg.withValues(alpha: 0.35)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(LucideIcons.circleAlert, size: 15, color: sem.neg),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                msg,
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12.5,
                  fontWeight: FontWeight.w600,
                  color: scheme.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Conectando… (la sala aparece cuando el hello/welcome termine).
class _ConnectingCard extends StatelessWidget {
  const _ConnectingCard();

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return VeCard(
      child: Row(
        children: [
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Conectando con la sala…',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: scheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Aviso de observador (rol de solo lectura).
class _ViewerNotice extends StatelessWidget {
  const _ViewerNotice();

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.muted,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: scheme.border),
        ),
        child: Row(
          children: [
            Icon(LucideIcons.eye, size: 14, color: scheme.foreground),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Eres observador: ves la lista en vivo, pero no la tocas.',
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 12,
                  color: scheme.foreground,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
            child: VeBtn(
              variant: VeBtnVariant.secondary,
              icon: LucideIcons.pencil,
              onPressed: onRename,
              child: const Text('Renombrar'),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: VeBtn(
              variant: VeBtnVariant.danger,
              icon: LucideIcons.doorClosed,
              onPressed: onClose,
              child: const Text('Cerrar sala'),
            ),
          ),
        ],
      ),
    );
  }
}

/// Código + QR + modo: lo que se comparte para invitar (patrón InviteSheet:
/// código mono con tracking amplio, «toca para copiar», QR centrado).
class _CodigoQrCard extends StatelessWidget {
  const _CodigoQrCard({required this.room});

  final RoomController room;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return VeCard(
      child: Column(
        children: [
          Row(
            children: [
              VeBadge(tone: VeTone.pos, child: Text(room.modeLabel)),
              const SizedBox(width: 6),
              if (room.roomName.isNotEmpty)
                Expanded(
                  child: Text(
                    room.roomName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: scheme.foreground,
                    ),
                  ),
                ),
              VeBadge(child: Text(room.isPublic ? 'pública' : 'privada')),
            ],
          ),
          const SizedBox(height: 14),
          Text(
            'CÓDIGO DE LA SALA',
            style: VeText.labelCaps(
              10.5,
              color: scheme.mutedForeground,
              weight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 6),
          InkWell(
            borderRadius: BorderRadius.circular(10),
            onTap: () {
              Clipboard.setData(ClipboardData(text: room.code));
              showToast(context, 'Código copiado', kind: ToastKind.ok);
            },
            child: Text(
              room.code.isEmpty ? '—' : room.code,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 28,
                fontWeight: FontWeight.w500,
                letterSpacing: 8.4, // tracking-[0.3em] del prototipo
                color: scheme.foreground,
              ),
            ),
          ),
          Text(
            'toca para copiar',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 10.5,
              color: scheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 14),
          if (room.code.isNotEmpty)
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: scheme.muted,
                borderRadius: BorderRadius.circular(12),
              ),
              child: QrImageView(
                // Deep link (v19.8): QR escaneado con la cámara del teléfono
                // → abre ValoraVE → hoja de unirse (modo · nombre · PIN).
                data:
                    'valorave://sala?c=${room.code}&m=${room.mode.id}'
                    '&p=${room.hasPin ? 1 : 0}',
                version: QrVersions.auto,
                size: 170,
                backgroundColor: Colors.transparent,
              ),
            ),
          const SizedBox(height: 10),
          Text(
            'Comparte el código o el QR — el QR abre la app de quien lo '
            'escanee${room.hasPin ? ' y pide el PIN de emojis' : ''}. La '
            'tecnología es ${room.modeLabel}.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              height: 1.45,
              color: scheme.mutedForeground,
            ),
          ),
          if (room.isHost && room.lanAddress.isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              'Este teléfono es la sala: ${room.lanAddress}',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: scheme.foreground,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

/// Miembros con roles (filas divididas del prototipo); el anfitrión
/// administra (expulsar · editor/observador) desde el menú de cada fila.
class _MiembrosCard extends StatelessWidget {
  const _MiembrosCard({required this.room, required this.members});

  final RoomController room;
  final List<RoomMember> members;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return VeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'MIEMBROS · ${members.length}',
                  style: VeText.labelCaps(
                    10.5,
                    color: scheme.mutedForeground,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              if (room.connected)
                VeBtn(
                  variant: VeBtnVariant.ghost,
                  size: VeBtnSize.sm,
                  icon: LucideIcons.messageCircle,
                  onPressed: room.sendTyping,
                  child: const Text('Avisar que escribo'),
                ),
            ],
          ),
          const SizedBox(height: 8),
          VeGroup(
            semantic: 'Miembros de la sala',
            children: [
              for (final m in members)
                _MemberTile(
                  room: room,
                  m: m,
                  isMe: m.id == room.myId || (m.id == 'host' && room.isHost),
                ),
            ],
          ),
        ],
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
    final scheme = ShadTheme.of(context).colorScheme;
    final isHostRow = m.id == 'host';
    final canManage = room.canAdmin && !isHostRow && m.id != room.myId;

    return Row(
      children: [
        // Inicial en círculo 28 (patrón prototipo).
        Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            color: scheme.muted,
            shape: BoxShape.circle,
          ),
          alignment: Alignment.center,
          child: Text(
            m.name.isEmpty ? '?' : m.name.characters.first.toUpperCase(),
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: scheme.foreground,
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
                      isMe ? '${m.name} · tú' : m.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w500,
                        color: scheme.foreground,
                      ),
                    ),
                  ),
                  if (m.typing) ...[
                    const SizedBox(width: 6),
                    Text(
                      'escribe…',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 10.5,
                        fontStyle: FontStyle.italic,
                        color: scheme.mutedForeground,
                      ),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 2),
              Text(
                isHostRow
                    ? 'Anfitrión'
                    : (m.role == 'viewer' ? 'Observador' : 'Editor'),
                style: TextStyle(
                  fontFamily: 'Inter',
                  fontSize: 11.5,
                  color: scheme.mutedForeground,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        if (isHostRow)
          const VeBadge(child: Text('Anfitrión'))
        else if (m.role == 'viewer')
            const VeBadge(tone: VeTone.warn, child: Text('Observador'))
          else
            const VeBadge(tone: VeTone.pos, dot: true, child: Text('Editor')),
        if (canManage)
          PopupMenuButton<String>(
            icon: Icon(
              LucideIcons.ellipsisVertical,
              size: 16,
              color: scheme.mutedForeground,
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
    );
  }
}
