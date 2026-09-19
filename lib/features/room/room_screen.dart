/// ─── Sala · lobby de conexión (v19.8 · orden del dueño) ─────────────────────
/// TRES modos P2P sin internet (Cerca · WiFi o Hotspot · Bluetooth) + el
/// servidor propio, cada uno con su tecnología. La pantalla arranca por la
/// CONFIGURACIÓN de conexión (cómo se conectan) y de ahí a las acciones:
/// Unirme (hoja: modo · nombre · PIN) · Crear (anfitrión, con PIN de emojis
/// opcional) · Salas cercanas (escucha en vivo). El nombre ya NO vive arriba:
/// lo pregunta la hoja de unirse al momento de entrar.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../room/room_controller.dart';
import '../../room/room_transport.dart';
import '../../services/deep_link.dart' show salaInviteRequest;
import '../../widgets/ui.dart';
import '../scanner/scanner_screen.dart';
import 'join_sheet.dart';
import 'pin_emoji.dart';

class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  late final TextEditingController _roomNameCtrl;
  late final TextEditingController _hostNameCtrl;
  String? _busyError;
  bool _creating = false;

  @override
  void initState() {
    super.initState();
    final room = context.read<RoomController>();
    _roomNameCtrl = TextEditingController(text: room.roomName);
    _hostNameCtrl = TextEditingController(text: room.myName);
    // Deep link (QR externo escaneado con la cámara): si hay invitación
    // pendiente, abre la hoja de unirse prellenada.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final inv = salaInviteRequest.value ?? room.consumePendingInvite();
      if (inv != null) {
        salaInviteRequest.value = null;
        showJoinSheet(context, invite: inv);
      }
    });
  }

  @override
  void dispose() {
    _roomNameCtrl.dispose();
    _hostNameCtrl.dispose();
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
      showToast(
        context,
        'En sala · la lista se sincroniza',
        kind: ToastKind.ok,
      );
      context.go('/lista');
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomController>();
    final scheme = Theme.of(context).colorScheme;
    final busy = room.status == RoomStatus.connecting || _creating;

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
          const PageHeader(
            'Sala en vivo',
            hint: 'Sincroniza la lista P2P — sin internet, sin cuentas',
          ),
          if (room.connected) _EnSalaBanner(room: room),
          if (_busyError != null || room.lastError != null) ...[
            _ErrorBanner(msg: _busyError ?? room.lastError!),
            const SizedBox(height: 10),
          ],
          if (busy && !_creating) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Conectando por ${room.modeLabel}…',
                        style: TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    TextButton(
                      onPressed: () => room.leave(),
                      child: const Text('Cancelar'),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
          ],
          // 1º CÓMO SE CONECTAN (la configuración primero, orden del dueño).
          _ModePicker(room: room),
          // 2º El servidor propio, solo en su modo.
          if (room.mode == RoomMode.servidor) ...[
            const SizedBox(height: 10),
            _ServerCard(room: room),
          ],
          // 3º UNIRSE: una sola puerta — la hoja pregunta el resto.
          const SizedBox(height: 10),
          _JoinEntryCard(room: room, busy: busy),
          // 4º CREAR: anfitrión, con PIN de emojis opcional.
          const SizedBox(height: 10),
          _CreateCard(
            room: room,
            roomNameCtrl: _roomNameCtrl,
            hostNameCtrl: _hostNameCtrl,
            busy: busy,
            creating: _creating,
            onRun: _run,
            onCreating: (v) => setState(() => _creating = v),
          ),
          // 5º SALAS CERCANAS: escucha en vivo.
          const SizedBox(height: 10),
          _ScanCard(room: room, busy: busy),
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
    final title = room.roomName.isNotEmpty
        ? room.roomName
        : 'Sala ${room.code}';
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(14),
        onTap: () => context.push('/sala-viva'),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
          child: Row(
            children: [
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
                    color: scheme.onSurface,
                  ),
                ),
              ),
              Icon(Icons.arrow_forward, size: 16, color: scheme.primary),
            ],
          ),
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
    );
  }
}

/// Puerta única de unirse (v19.8): la hoja hace el flujo completo (modo ·
/// nombre · PIN · conectar). Aquí solo el atajo: botón grande + escanear.
class _JoinEntryCard extends StatelessWidget {
  const _JoinEntryCard({required this.room, required this.busy});

  final RoomController room;
  final bool busy;

  Future<void> _scanQr(BuildContext context) async {
    final raw = await ScannerScreen.scan(context);
    if (raw == null || raw == '__manual__' || !context.mounted) return;
    final invite = SalaInvite.tryParse(raw);
    if (!context.mounted) return;
    if (invite == null) {
      showToast(context, 'Ese QR no es de una sala', kind: ToastKind.warn);
      return;
    }
    await showJoinSheet(context, invite: invite);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'UNIRSE A UNA SALA',
              style: VeText.labelCaps(10.5, color: scheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              'Tienes el código o un QR del anfitrión: te preguntamos cómo '
              'conectarte, tu nombre y el PIN si la sala lo pide.',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: busy ? null : () => showJoinSheet(context),
                    icon: const Icon(Icons.login, size: 17),
                    label: const Text('Unirme'),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: busy ? null : () => _scanQr(context),
                  icon: const Icon(Icons.qr_code_scanner, size: 17),
                  label: const Text('Escanear QR'),
                ),
              ],
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
            Text(
              'CÓMO SE CONECTAN',
              style: VeText.labelCaps(10.5, color: scheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              'Tres modos P2P sin internet — y tu propio servidor si lo prefieres.',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
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
      RoomMode.servidor => Icons.dns_rounded,
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
                : scheme.outlineVariant,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    mode.label,
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                      color: scheme.onSurface,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    mode.tech,
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    mode.hint,
                    style: TextStyle(
                      fontSize: 10.5,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (selected)
              Icon(Icons.check_circle, size: 18, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

typedef _RoomAction = Future<void> Function(Future<String?> Function() action);

/// Fila de una sala avistada (escaneo o búsqueda): modo · nombre · código
/// y anfitrión. Tap → hoja de unirse prellenada (pregunta nombre y PIN).
class _RoomAdTile extends StatelessWidget {
  const _RoomAdTile({
    required this.ad,
    required this.busy,
    required this.onTap,
  });

  final RoomAd ad;
  final bool busy;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: busy ? null : onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Row(
          children: [
            Icon(
              switch (ad.mode) {
                RoomMode.cerca => Icons.wifi_tethering,
                RoomMode.wifi => Icons.router_outlined,
                RoomMode.bt => Icons.bluetooth,
                RoomMode.servidor => Icons.dns_rounded,
              },
              size: 18,
              color: scheme.primary,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    ad.label,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  Text(
                    '${ad.code} · anfitrión ${ad.hostName}',
                    style: TextStyle(
                      fontSize: 11,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Icon(Icons.login, size: 16, color: scheme.primary),
          ],
        ),
      ),
    );
  }
}

class _CreateCard extends StatefulWidget {
  const _CreateCard({
    required this.room,
    required this.roomNameCtrl,
    required this.hostNameCtrl,
    required this.busy,
    required this.creating,
    required this.onRun,
    required this.onCreating,
  });

  final RoomController room;
  final TextEditingController roomNameCtrl;
  final TextEditingController hostNameCtrl;
  final bool busy;
  final bool creating;
  final _RoomAction onRun;
  final ValueChanged<bool> onCreating;

  @override
  State<_CreateCard> createState() => _CreateCardState();
}

class _CreateCardState extends State<_CreateCard> {
  late final TextEditingController _searchCtrl;

  /// El escaneo se arranca UNA vez por búsqueda: cada arranque limpia la
  /// lista y la repuebla; reiniciarlo en cada tecla dejaría la búsqueda
  /// en blanco siempre. Se resetea al vaciar el campo.
  bool _scanKicked = false;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  /// Nombre/código/anfitrión sin tildes ni mayúsculas: «mercado» encuentra
  /// «Mercado del barrio» y «ANITA» encuentra a «Anita».
  static String _norm(String s) => s
      .toLowerCase()
      .replaceAll('á', 'a')
      .replaceAll('é', 'e')
      .replaceAll('í', 'i')
      .replaceAll('ó', 'o')
      .replaceAll('ú', 'u')
      .replaceAll('ü', 'u')
      .replaceAll('ñ', 'n');

  List<RoomAd> get _matches {
    final q = _norm(_searchCtrl.text.trim());
    if (q.isEmpty) return const <RoomAd>[];
    return widget.room.foundRooms
        .where(
          (ad) =>
              _norm(ad.roomName).contains(q) ||
              ad.code.toLowerCase().contains(q) ||
              _norm(ad.hostName).contains(q),
        )
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final scheme = Theme.of(context).colorScheme;
    final matches = _matches;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'CREAR SALA',
              style: VeText.labelCaps(10.5, color: scheme.primary),
            ),
            const SizedBox(height: 4),
            Text(
              'Tu teléfono es el anfitrión: comparte el código de 6 letras.',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: widget.hostNameCtrl,
              maxLength: 24,
              onChanged: room.setMyName,
              decoration: const InputDecoration(
                hintText: '¿Cómo te ven en la sala?',
                labelText: 'Tu nombre (anfitrión)',
                counterText: '',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: widget.roomNameCtrl,
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
              title: const Text(
                'Sala pública',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                room.isPublic
                    ? 'Aparece en el escaneo de salas cercanas'
                    : 'Solo entra quien tenga el código',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              value: room.isPublic,
              onChanged: room.setPublic,
            ),
            // ── PIN de emojis (v19.8 · orden del dueño): el candado de la
            // puerta — nadie se une por azar sin los 4 emojis.
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              title: const Text(
                'Pedir PIN de emojis',
                style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
              ),
              subtitle: Text(
                'Quien se une marca los 4 emojis que le muestres',
                style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant),
              ),
              value: room.hasPin,
              onChanged: (v) => room.setPin(
                v
                    ? (room.pinEmoji.isNotEmpty
                          ? room.pinEmoji
                          : generatePinEmoji())
                    : '',
              ),
            ),
            if (room.hasPin)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: PinShowCard(
                  pin: room.pinEmoji,
                  onRegenerate: () => room.setPin(generatePinEmoji()),
                ),
              ),
            const SizedBox(height: 4),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.busy
                    ? null
                    : () => widget.onRun(
                        () => room.create(
                          name: widget.hostNameCtrl.text,
                          roomName: widget.roomNameCtrl.text,
                          isPublic: room.isPublic,
                          pin: room.pinEmoji,
                        ),
                      ),
                icon: const Icon(Icons.add_home_work, size: 17),
                label: Text('Crear por ${room.modeLabel}'),
              ),
            ),
            // ── Buscar sala (v19.4 · orden del dueño): antes de crear una
            // nueva, se puede mirar si ya existe una con ese nombre.
            const SizedBox(height: 6),
            TextField(
              controller: _searchCtrl,
              enabled: !widget.busy,
              onChanged: (v) {
                setState(() {});
                // Escribir ya escucha: sin tocar el botón de Salas
                // cercanas, una sola vez por búsqueda.
                final hayTexto = v.trim().isNotEmpty;
                if (hayTexto &&
                    !_scanKicked &&
                    !room.scanning &&
                    !widget.busy) {
                  _scanKicked = true;
                  room.startScan();
                } else if (!hayTexto) {
                  _scanKicked = false;
                }
              },
              decoration: const InputDecoration(
                hintText: 'Buscar sala por nombre o código',
                counterText: '',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            if (_searchCtrl.text.trim().isNotEmpty) ...<Widget>[
              const SizedBox(height: 8),
              if (matches.isEmpty)
                Text(
                  room.scanning
                      ? 'Nada todavía. Las salas públicas van apareciendo '
                            'mientras escucha.'
                      : 'Sin salas con ese nombre ahora mismo. Puedes crearla '
                            'con el botón de arriba.',
                  style: TextStyle(
                    fontSize: 11.5,
                    height: 1.4,
                    color: scheme.onSurfaceVariant,
                  ),
                )
              else ...<Widget>[
                for (final ad in matches)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _RoomAdTile(
                      ad: ad,
                      busy: widget.busy,
                      onTap: () => showJoinSheet(
                        context,
                        invite: SalaInvite(
                          code: ad.code,
                          mode: ad.mode,
                          roomName: ad.roomName,
                          hostName: ad.hostName,
                        ),
                        ad: ad,
                      ),
                    ),
                  ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}

class _ScanCard extends StatefulWidget {
  const _ScanCard({required this.room, required this.busy});

  final RoomController room;
  final bool busy;

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
            Row(
              children: [
                Expanded(
                  child: Text(
                    'SALAS CERCANAS',
                    style: VeText.labelCaps(10.5, color: scheme.primary),
                  ),
                ),
                TextButton.icon(
                  onPressed: widget.busy
                      ? null
                      : () =>
                            room.scanning ? room.stopScan() : room.startScan(),
                  icon: Icon(
                    room.scanning ? Icons.stop_circle : Icons.radar,
                    size: 17,
                  ),
                  label: Text(room.scanning ? 'Parar' : 'Escuchar'),
                ),
              ],
            ),
            Text(
              'Salas públicas por ${room.modeLabel}. ${room.mode.hint}',
              style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 10),
            if (room.scanning && room.foundRooms.isEmpty)
              Row(
                children: [
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Buscando…',
                    style: TextStyle(
                      fontSize: 12,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            for (final ad in room.foundRooms)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _RoomAdTile(
                  ad: ad,
                  busy: widget.busy,
                  onTap: () => showJoinSheet(
                    context,
                    invite: SalaInvite(
                      code: ad.code,
                      mode: ad.mode,
                      roomName: ad.roomName,
                      hostName: ad.hostName,
                    ),
                    ad: ad,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// ─── Servidor propio (v19 · devuelto por orden del dueño) ──────────────────
/// Config del relay socket.io del usuario: URL host:puerto, token opcional,
/// probar conexión y guía mínima del server.js de referencia. El modo NO se
/// elimina: quien tenga su servidor lo usa con o sin internet.
class _ServerCard extends StatefulWidget {
  const _ServerCard({required this.room});

  final RoomController room;

  @override
  State<_ServerCard> createState() => _ServerCardState();
}

class _ServerCardState extends State<_ServerCard> {
  late final TextEditingController _addr = TextEditingController(
    text: widget.room.serverAddress,
  );
  late final TextEditingController _token = TextEditingController(
    text: widget.room.serverToken,
  );
  String? _probeMsg;
  bool _probing = false;
  bool _guide = false;

  @override
  void dispose() {
    _addr.dispose();
    _token.dispose();
    super.dispose();
  }

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
                Icon(Icons.dns_rounded, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Tu servidor (socket.io)',
                    style: const TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'El servidor solo TRANSPORTA: la lista, los roles y la verificación '
              'viven en el teléfono del anfitrión. Sirve para grupos lejos o con '
              'datos móviles.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _addr,
              keyboardType: TextInputType.url,
              decoration: const InputDecoration(
                labelText: 'URL del servidor',
                hintText: 'http://192.168.1.20:3000',
                isDense: true,
              ),
              onChanged: widget.room.setServerAddress,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _token,
              decoration: const InputDecoration(
                labelText: 'Token (opcional)',
                isDense: true,
              ),
              onChanged: widget.room.setServerToken,
            ),
            const SizedBox(height: 10),
            // Wrap: los 2 botones suman ~309 px y no caben en los 300 px
            // útiles de 360 dp (fix overflow) — envuelven si hace falta.
            Wrap(
              spacing: 8,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FilledButton.tonal(
                  onPressed: _probing
                      ? null
                      : () async {
                          setState(() => _probing = true);
                          final msg = await widget.room.probeServer();
                          if (!mounted) return;
                          setState(() {
                            _probing = false;
                            _probeMsg = msg ?? 'Conexión OK';
                          });
                        },
                  child: _probing
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Probar conexión'),
                ),
                TextButton(
                  onPressed: () => setState(() => _guide = !_guide),
                  child: Text(
                    _guide ? 'Ocultar guía' : '¿Cómo monto mi servidor?',
                  ),
                ),
              ],
            ),
            if (_probeMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(
                  _probeMsg!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: _probeMsg == 'Conexión OK'
                        ? VeColors.of(context).pos
                        : VeColors.of(context).neg,
                  ),
                ),
              ),
            if (_guide) ...[
              const SizedBox(height: 10),
              Text(
                '1. Instala Node.js y ejecuta: npm i socket.io\n'
                '2. server.js mínimo: al recibir `join` mete el socket al room '
                'del código y responde {ok: true, id: socket.id}; reenvía '
                '`room_event` a los demás del room (añadiendo from: socket.id) '
                'y `room_event_to` solo al destino.\n'
                '3. Abre la URL aquí y prueba la conexión. También puedes usar '
                'el modo WiFi local con este teléfono como servidor.',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.5,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
