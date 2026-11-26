/// ─── Sala Viva (v29 · H-38: reconstruida desde cero) ────────────────────────
/// La sala EN VIVO en el lenguaje de secciones v28/v29: TÍTULO + descripción
/// de una línea + detalles con hairlines, separadas por espacio en blanco,
/// cero cajas dentro de cajas.
///
/// · INVITAR — código grande mono que copia al tocar + QR con deep link +
///   notas de LAN/PIN.
/// · MIEMBROS — filas con rol, «escribe…» y gobierno inline del anfitrión
///   (rol/expulsar en cada fila).
/// · ACCIONES — renombrar y cerrar (anfitrión) o salir (invitado).
///
/// Sin PIN obligatorio: el código de 6 letras ES el secreto; el PIN de
/// emojis es el candado opcional. Si la conexión se cae, vuelve sola a la
/// Lista — nunca un limbo. Funcionalidad íntegra: modos P2P, servidor
/// propio, PIN, escaneo y deep links.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../room/room_controller.dart';
import '../../room/room_transport.dart';
import '../../widgets/ui.dart';
import 'pin_emoji.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorave/providers/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:valorave/core/ve_theme.dart';

const String kSalaVivaRoute = '/sala-viva';

class SalaVivaScreen extends ConsumerStatefulWidget {
  const SalaVivaScreen({super.key});

  @override
  ConsumerState<SalaVivaScreen> createState() => _SalaVivaScreenState();
}

class _SalaVivaScreenState extends ConsumerState<SalaVivaScreen> {
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
    final room = ref.read(roomControllerProvider);
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
    final room = ref.read(roomControllerProvider);
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
    final room = ref.read(roomControllerProvider);
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
    final room = ref.watch(roomControllerProvider);
    final members = room.visibleMembers;
    final title = room.roomName.isNotEmpty
        ? room.roomName
        : (room.code.isNotEmpty ? 'Sala ${room.code}' : 'Sala en vivo');

    return PushScreen(
      title: title,
      subtitle: 'En vivo · ${room.modeLabel}',
      child: VeEntry(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (room.lastError != null) _AvisoPlano(msg: room.lastError!),
            if (!room.connected) ...[
              const _Conectando(),
              const SizedBox(height: 12),
            ],
            if (room.isViewer) const _AvisoObservador(),

            // ── INVITAR ─────────────────────────────────────────────────
            VeEyebrow(
              hint:
                  'Comparte el código o el QR — el QR abre la app de quien lo '
                  'escanee${room.hasPin ? ' y pide el PIN de emojis' : ''}.',
              child: const Text('INVITAR'),
            ),
            _CodigoSala(room: room),
            const SizedBox(height: 10),
            _QrSala(room: room),
            // Notas de LAN/PIN (H-38): lo que el anfitrión debe saber para
            // que entren — dirección del teléfono-sala y candado de emojis.
            if (room.isHost && room.lanAddress.isNotEmpty)
              _NotaLan(address: room.lanAddress),
            if (room.isHost && room.hasPin) ...[
              const SizedBox(height: 10),
              PinShowCard(pin: room.pinEmoji, compact: true),
            ],

            // ── MIEMBROS ────────────────────────────────────────────────
            VeEyebrow(
              hint:
                  'El rol dice quién toca la lista: el anfitrión administra '
                  'desde cada fila.',
              child: Text('MIEMBROS · ${members.length}'),
            ),
            VeGroup(
              semantic: 'Miembros de la sala',
              children: [
                for (final m in members)
                  _FilaMiembro(
                    room: room,
                    m: m,
                    isMe: m.id == room.myId || (m.id == 'host' && room.isHost),
                  ),
              ],
            ),

            // ── ACCIONES ─────────────────────────────────────────────────
            VeEyebrow(
              hint: room.isHost
                  ? 'Al cerrar, todos vuelven a su lista con lo último '
                        'sincronizado.'
                  : 'El anfitrión y el resto siguen en la sala.',
              child: const Text('ACCIONES'),
            ),
            VeGroup(
              children: [
                if (room.canAdmin)
                  VeRow(
                    label: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          LucideIcons.pencil,
                          size: 14,
                          color: context.ve.colorScheme.foreground,
                        ),
                        const SizedBox(width: 6),
                        const Text('Renombrar sala'),
                      ],
                    ),
                    sub: const Text('El nombre se sincroniza con todos'),
                    showChevron: true,
                    semantic: 'Renombrar sala',
                    onTap: _renameDialog,
                  ),
                VeRow(
                  label: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        LucideIcons.doorOpen,
                        size: 14,
                        color: Theme.of(context).extension<VeInk>()!.neg,
                      ),
                      const SizedBox(width: 6),
                      Text(room.isHost ? 'Cerrar sala' : 'Salir de la sala'),
                    ],
                  ),
                  sub: Text(
                    room.isHost
                        ? 'Los invitados vuelven a su lista'
                        : 'Vuelves a tu lista local',
                  ),
                  danger: true,
                  showChevron: true,
                  semantic: room.isHost ? 'Cerrar sala' : 'Salir de la sala',
                  onTap: _confirmLeave,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Aviso plano (v25 «HOJA»): icono + texto en neg, sin fill ni borde.
class _AvisoPlano extends StatelessWidget {
  const _AvisoPlano({required this.msg});

  final String msg;

  @override
  Widget build(BuildContext context) {
    final sem = VeColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
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
                fontSize: 13.5,
                fontWeight: FontWeight.w600,
                color: sem.neg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Conectando… (la sala aparece cuando el hello/welcome termine).
class _Conectando extends StatelessWidget {
  const _Conectando();

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    return Row(
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
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: scheme.foreground,
            ),
          ),
        ),
      ],
    );
  }
}

/// Aviso de observador (rol de solo lectura).
class _AvisoObservador extends StatelessWidget {
  const _AvisoObservador();

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(LucideIcons.eye, size: 14, color: scheme.foreground),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              'Eres observador: ves la lista en vivo, pero no la tocas.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                color: scheme.foreground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Código GRANDE mono que copia al tocar (H-38 · v32 centrado): tracking
/// amplio del prototipo, un solo renglón, CENTRADO en la pantalla — es el
/// protagonista de la sección INVITAR, junto al QR que también va centrado.
class _CodigoSala extends StatelessWidget {
  const _CodigoSala({required this.room});

  final RoomController room;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    return Column(
      // v32 (orden del dueño): la sala se crea SEPARADA y CENTRADA — el
      // código y el QR comparten el eje del papel.
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: () {
            Clipboard.setData(ClipboardData(text: room.code));
            showToast(context, 'Código copiado', kind: ToastKind.ok);
          },
          child: FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              room.code.isEmpty ? '—' : room.code,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 30,
                fontWeight: FontWeight.w500,
                letterSpacing: 8.4, // tracking-[0.3em] del prototipo
                color: scheme.foreground,
              ),
            ),
          ),
        ),
        const SizedBox(height: 2),
        Text(
          'toca para copiar',
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11,
            color: scheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// QR con deep link (v19.8): escaneado con la cámara del teléfono abre
/// ValoraVE → hoja de unirse (modo · nombre · PIN). El lienzo del QR lleva
/// fondo propio: es el área de silencio que el escáner necesita, no una caja
/// decorativa.
class _QrSala extends StatelessWidget {
  const _QrSala({required this.room});

  final RoomController room;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    if (room.code.isEmpty) return const SizedBox.shrink();
    return Center(
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: scheme.muted,
          borderRadius: BorderRadius.circular(12),
        ),
        child: QrImageView(
          data:
              'valorave://sala?c=${room.code}&m=${room.mode.id}'
              '&p=${room.hasPin ? 1 : 0}',
          version: QrVersions.auto,
          size: 170,
          backgroundColor: Colors.transparent,
        ),
      ),
    );
  }
}

/// Nota de LAN (H-38): en los modos sin internet, este teléfono ES la sala.
class _NotaLan extends StatelessWidget {
  const _NotaLan({required this.address});

  final String address;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(LucideIcons.wifi, size: 13, color: scheme.mutedForeground),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              'Este teléfono es la sala: comparte la red y entra desde '
              '$address.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 11,
                height: 1.45,
                color: scheme.mutedForeground,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Miembro: fila con rol y «escribe…»; el anfitrión gobierna INLINE
/// (cambiar rol · sacar) desde la propia fila (v28: sin menús flotantes).
class _FilaMiembro extends ConsumerWidget {
  const _FilaMiembro({required this.room, required this.m, required this.isMe});

  final RoomController room;
  final RoomMember m;
  final bool isMe;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final scheme = context.ve.colorScheme;
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
              fontSize: 13.5,
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
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        isMe ? '${m.name} · tú' : m.name,
                        maxLines: 1,
                        style: TextStyle(
                          fontFamily: 'Inter',
                          fontSize: 13.5,
                          fontWeight: FontWeight.w500,
                          color: scheme.foreground,
                        ),
                      ),
                    ),
                  ),
                  if (m.typing) ...[
                    const SizedBox(width: 6),
                    Text(
                      'escribe…',
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 11,
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
                  fontSize: 11,
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
        if (canManage) ...[
          // v28 · acciones INLINE (sin menú flotante): cambiar rol y sacar,
          // botones de icono identificables con pista de 44 px.
          VeIconBtn(
            icon: m.role == 'viewer'
                ? Icons.edit_note_rounded
                : Icons.visibility_outlined,
            label: m.role == 'viewer' ? 'Hacer editor' : 'Hacer observador',
            size: 32,
            iconSize: 16,
            onTap: () => room.setMemberRole(
              m.id,
              m.role == 'viewer' ? 'editor' : 'viewer',
            ),
          ),
          const SizedBox(width: 4),
          VeIconBtn(
            icon: Icons.person_remove_rounded,
            label: 'Sacar de la sala',
            size: 32,
            iconSize: 16,
            danger: true,
            onTap: () async {
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
            },
          ),
        ],
      ],
    );
  }
}
