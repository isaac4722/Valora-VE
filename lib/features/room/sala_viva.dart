/// ─── Sala Viva · la sala EN VIVO tiene pantalla propia (v18.0) ─────────────
/// Distinta de la configuración (/sala): aquí se VIVE la sala — código + QR
/// para invitar, miembros con sus roles (anfitrión arriba, «(tú)» marcado),
/// salir/cerrar/renombrar/editar roles (solo el anfitrión) y regreso
/// automático a la Lista si la conexión se corta. Al finalizar la compra, el
/// anfitrión cierra la sala y todos vuelven solos.
library;

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../core/theme.dart';
import '../../room/room_transport.dart';
import '../../widgets/app_tips.dart';
import '../../widgets/ui.dart';

/// Ruta de la Sala Viva (push desde la Lista o la configuración de sala).
const String kSalaVivaRoute = '/sala-viva';

class SalaVivaScreen extends StatefulWidget {
  const SalaVivaScreen({super.key});

  @override
  State<SalaVivaScreen> createState() => _SalaVivaScreenState();
}

class _SalaVivaScreenState extends State<SalaVivaScreen> {
  RoomController? _ctrl;
  bool _listening = false;

  @override
  void dispose() {
    _ctrl?.removeListener(_onRoomChanged);
    super.dispose();
  }

  /// Regreso automático: sin sala no hay nada que ver aquí — a la Lista.
  /// Tip de bienvenida a la sala (v19): la PRIMERA vez que se entra a una
  /// sala, UN tip enseña el código+QR — reglas del motor de tips.
  void _onRoomChanged() {
    final ctrl = _ctrl;
    if (ctrl == null || !mounted) return;
    if (ctrl.connected && !_salutedTip) {
      _salutedTip = true;
      unawaited(maybeShowTipOnce(
        context,
        id: 'sala.qr',
        title: 'Invita con el código o el QR',
        body: 'Quien tenga el código de 6 letras —o escanee el QR de esta '
            'pantalla— entra a tu sala y ve la lista en vivo, con o sin '
            'internet.',
      ));
    }
    if (!ctrl.connected && ctrl.status != RoomStatus.connecting) {
      context.go('/lista');
    }
  }

  bool _salutedTip = false;

  @override
  Widget build(BuildContext context) {
    final ctrl = _ctrl ??= context.read<RoomController>();
    if (!_listening) {
      _listening = true;
      ctrl.addListener(_onRoomChanged);
    }
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    final members = ctrl.visibleMembers;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          final title = ctrl.roomName.isNotEmpty
              ? ctrl.roomName
              : (ctrl.code.isNotEmpty ? 'Sala ${ctrl.code}' : 'Sala en vivo');
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              PageHeader(title, hint: 'En vivo · ${ctrl.modeLabel}'),
              if (ctrl.lastError != null) _ErrorBanner(msg: ctrl.lastError!),
              if (!ctrl.connected) ...[
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(children: [
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          ctrl.status == RoomStatus.connecting
                              ? 'Conectando…'
                              : 'La sala se desconectó. Volviendo a tu lista…',
                          style: TextStyle(
                              fontSize: 13, color: scheme.onSurfaceVariant),
                        ),
                      ),
                    ]),
                  ),
                ),
              ] else ...[
                _CodigoQrCard(ctrl: ctrl),
                const SizedBox(height: 10),
                if (ctrl.isViewer)
                  Card(
                    color: sem.warn.withValues(alpha: 0.08),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(children: [
                        Icon(Icons.visibility_outlined,
                            size: 18, color: sem.warn),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Eres OBSERVADOR: puedes ver la lista en vivo, '
                            'pero no modificarla. El anfitrión decide quién edita.',
                            style: TextStyle(
                                fontSize: 12.5,
                                height: 1.45,
                                fontWeight: FontWeight.w600,
                                color: sem.warn),
                          ),
                        ),
                      ]),
                    ),
                  ),
                _MiembrosCard(ctrl: ctrl, members: members),
                const SizedBox(height: 12),
                if (ctrl.canAdmin) ...[
                  Row(children: [
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _renameDialog,
                        icon: const Icon(Icons.drive_file_rename_outline,
                            size: 18),
                        label: const Text('Renombrar'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _closeDialog,
                        icon: const Icon(Icons.lock_outline, size: 18),
                        label: const Text('Cerrar sala'),
                      ),
                    ),
                  ]),
                  const SizedBox(height: 8),
                ],
                Row(children: [
                  Expanded(
                    child: FilledButton.tonal(
                      onPressed: ctrl.sendTyping,
                      child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.edit_note_rounded, size: 18),
                            SizedBox(width: 6),
                            Text('Avisar que escribo'),
                          ]),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(
                    style: FilledButton.styleFrom(
                        backgroundColor: sem.neg.withValues(alpha: 0.14),
                        foregroundColor: sem.neg),
                    onPressed: () async {
                      final ok = await _confirmLeave(context);
                      if (ok == true) await ctrl.leave();
                    },
                    child: const Text('Salir'),
                  ),
                ]),
                const SizedBox(height: 10),
                Text(
                  'La lista se sincroniza sola entre los miembros. Si se corta '
                  'la conexión, tus cambios quedan en el outbox y salen al '
                  'reconectar. Al finalizar la compra, el anfitrión cierra la '
                  'sala y todos vuelven a su lista.',
                  style: TextStyle(
                      fontSize: 11.5,
                      height: 1.5,
                      color: scheme.onSurfaceVariant),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  // ── Diálogos ──────────────────────────────────────────────────────────────

  Future<bool?> _confirmLeave(BuildContext context) async {
    final ctrl = _ctrl!;
    return showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(ctrl.isHost ? '¿Cerrar tu sala?' : '¿Salir de la sala?'),
        content: Text(ctrl.isHost
            ? 'Si solo sales, la sala sigue viva para los demás. Usa '
                '«Cerrar sala» para terminarla para todos.'
            : 'Dejas de recibir los cambios en vivo. Puedes volver a entrar '
                'con el código.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Quedarme')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Salir')),
        ],
      ),
    );
  }

  Future<void> _renameDialog() async {
    final ctrl = _ctrl!;
    final c = TextEditingController(text: ctrl.roomName);
    final name = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Renombrar la sala'),
        content: TextField(
          controller: c,
          autofocus: true,
          maxLength: 32,
          decoration:
              const InputDecoration(labelText: 'Nombre', isDense: true),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text),
              child: const Text('Renombrar')),
        ],
      ),
    );
    if (name != null && name.trim().isNotEmpty) {
      await ctrl.renameRoom(name);
    }
    c.dispose();
  }

  Future<void> _closeDialog() async {
    final ctrl = _ctrl!;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cerrar la sala?'),
        content: const Text(
            'Todos los miembros salen de la sala y vuelven a su lista. La '
            'lista sincronizada deja de actualizarse.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar')),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cerrar sala')),
        ],
      ),
    );
    if (ok == true) {
      await ctrl.closeRoom();
      if (mounted) context.go('/lista');
    }
  }
}

// ─── Código + QR + PIN ──────────────────────────────────────────────────────

class _CodigoQrCard extends StatelessWidget {
  const _CodigoQrCard({required this.ctrl});
  final RoomController ctrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            Stamp(ctrl.modeLabel, color: sem.pos),
            if (ctrl.roomName.isNotEmpty) ...[
              const SizedBox(width: 8),
              Flexible(
                  child: Text(ctrl.roomName,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                          fontSize: 13.5, fontWeight: FontWeight.w800))),
            ],
            const Spacer(),
            Stamp(ctrl.isPublic ? 'pública' : 'privada'),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            Expanded(
              child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('CÓDIGO DE LA SALA',
                        style: VeText.labelCaps(
                            9.5, color: scheme.onSurfaceVariant)),
                    const SizedBox(height: 4),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                          ctrl.code.isEmpty ? '—' : ctrl.code,
                          style: VeText.displayNum(38,
                              color: scheme.onSurface,
                              weight: FontWeight.w700)),
                    ),
                    const SizedBox(height: 6),
                    Row(children: [
                      TextButton.icon(
                        onPressed: () {
                          Clipboard.setData(
                              ClipboardData(text: ctrl.code));
                          showToast(context, 'Código copiado',
                              kind: ToastKind.ok);
                        },
                        icon: const Icon(Icons.copy_rounded, size: 16),
                        label: const Text('Copiar'),
                      ),
                      if (ctrl.isHost && ctrl.emoji.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Text('PIN ${ctrl.pin} · ${ctrl.emoji}',
                              style: TextStyle(
                                  fontSize: 11.5,
                                  color: scheme.onSurfaceVariant)),
                        ),
                    ]),
                  ]),
            ),
            const SizedBox(width: 12),
            if (ctrl.code.isNotEmpty)
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: scheme.outlineVariant)),
                child: QrImageView(
                  data: 'valorave-sala:${ctrl.code}',
                  size: 104,
                  backgroundColor: Colors.white,
                ),
              ),
          ]),
          if (ctrl.isHost)
            Padding(
              padding: const EdgeInsets.only(top: 10),
              child: Row(children: [
                const Icon(Icons.dns_rounded, size: 15),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    ctrl.lanAddress.isNotEmpty
                        ? 'Este teléfono es el servidor: ${ctrl.lanAddress}'
                        : 'Eres el anfitrión. Los invitados entran con el '
                            'código y verifican PIN + emoji.',
                    style: TextStyle(
                        fontSize: 11.5, color: scheme.onSurfaceVariant),
                  ),
                ),
              ]),
            ),
        ]),
      ),
    );
  }
}

// ─── Miembros + roles ───────────────────────────────────────────────────────

class _MiembrosCard extends StatelessWidget {
  const _MiembrosCard({required this.ctrl, required this.members});
  final RoomController ctrl;
  final List<RoomMember> members;

  static const _roleLabels = <String, String>{
    'host': 'ANFITRIÓN',
    'editor': 'EDITOR',
    'viewer': 'OBSERVADOR',
  };

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SectionTitle('Miembros (${members.length})'),
          Card(
            child: Column(children: [
              for (final m in members)
                ListTile(
                  dense: true,
                  leading: Icon(
                    m.online
                        ? Icons.person_rounded
                        : Icons.person_off_rounded,
                    size: 20,
                    color: m.online ? sem.pos : scheme.onSurfaceVariant,
                  ),
                  title: Text(
                    m.id == ctrl.myId || (m.id == 'host' && ctrl.isHost)
                        ? '${m.name} (tú)'
                        : m.name,
                    style: const TextStyle(
                        fontSize: 13.5, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    _roleLabels[m.role] ?? 'EDITOR',
                    style: VeText.labelCaps(
                        8.5, color: scheme.onSurfaceVariant),
                  ),
                  trailing: _trailing(context, m),
                ),
            ]),
          ),
        ]);
  }

  /// Acciones por miembro (solo anfitrión, nunca sobre sí mismo).
  Widget? _trailing(BuildContext context, RoomMember m) {
    if (m.typing) {
      return Text('escribiendo…',
          style: TextStyle(
              fontSize: 11, color: Theme.of(context).colorScheme.onSurfaceVariant));
    }
    if (!ctrl.canAdmin || m.id == 'host' || m.id == ctrl.myId) return null;
    return IconButton(
      icon: const Icon(Icons.more_vert_rounded, size: 20),
      onPressed: () => _memberMenu(context, m),
    );
  }

  Future<void> _memberMenu(BuildContext context, RoomMember m) async {
    final action = await showModalBottomSheet<String>(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 6),
            child: Text(m.name,
                style: const TextStyle(
                    fontSize: 15, fontWeight: FontWeight.w800)),
          ),
          ListTile(
            leading: Icon(m.role == 'viewer'
                ? Icons.edit_outlined
                : Icons.visibility_outlined),
            title: Text(m.role == 'viewer'
                ? 'Permitir editar la lista'
                : 'Convertir en observador'),
            subtitle: Text(m.role == 'viewer'
                ? 'Podrá agregar y tachar ítems'
                : 'Solo verá la lista, sin editar'),
            onTap: () => Navigator.pop(ctx, 'role'),
          ),
          ListTile(
            leading: const Icon(Icons.person_remove_outlined),
            title: const Text('Expulsar de la sala'),
            onTap: () => Navigator.pop(ctx, 'kick'),
          ),
        ]),
      ),
    );
    if (action == 'role') {
      await ctrl.setMemberRole(m.id, m.role == 'viewer' ? 'editor' : 'viewer');
    } else if (action == 'kick') {
      await ctrl.kickMember(m.id);
    }
  }
}

class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.msg});
  final String msg;

  @override
  Widget build(BuildContext context) {
    final sem = VeColors.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      color: sem.neg.withValues(alpha: 0.08),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Row(children: [
          Icon(Icons.error_outline, size: 18, color: sem.neg),
          const SizedBox(width: 8),
          Expanded(
              child: Text(msg,
                  style: TextStyle(fontSize: 12.5, color: sem.neg))),
        ]),
      ),
    );
  }
}
