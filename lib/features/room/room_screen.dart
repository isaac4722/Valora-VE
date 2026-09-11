/// ─── Sala en vivo · pantalla completa (v17.2, decisión del dueño) ───────────
/// Lobby con 5 modos (Servidor · Cerca/Nearby · WiFi local · Hotspot ·
/// Bluetooth), servidor propio configurable desde aquí, descubrimiento de
/// salas públicas (Nearby + UDP) o entrada por código, verificación PIN+emoji
/// en TODOS los caminos y walkthrough propio. Nada de datos móviles para la
/// sala: los transportes directos (LAN/Hotspot/Nearby/BT) son 100% locales.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/theme.dart';
import '../../data/store.dart';
import '../../room/room_transport.dart';
import '../../widgets/ui.dart';
import '../../widgets/walkthrough.dart';
import '../../widgets/walkthroughs_content.dart';

/// Pantalla completa de la sala (ruta /sala). Abre con showRoomSheet()
/// desde la Lista o con context.push('/sala').
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  RoomController? _ctrl;

  RoomController _make(AppStore store) {
    final c = RoomController(store);
    c.attachStoreListener();
    return c;
  }

  @override
  void initState() {
    super.initState();
    // Walkthrough de /sala (ruta fuera del shell: dispara aquí, una vez).
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeWalkthrough());
  }

  void _maybeWalkthrough() {
    if (!mounted) return;
    final wt = kWalkthroughs['/sala'];
    if (wt == null) return;
    final SharedPreferences prefs;
    try {
      prefs = context.read<SharedPreferences>();
    } on ProviderNotFoundException {
      return; // tests/previews sin prefs: no-op
    }
    maybeRunWalkthrough(context, prefs, '/sala', wt.title, wt.steps);
  }

  @override
  void dispose() {
    _ctrl?.detachStoreListener();
    _ctrl?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final store = context.watch<AppStore>();
    _ctrl ??= _make(store);
    final ctrl = _ctrl!;
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListenableBuilder(
        listenable: ctrl,
        builder: (context, _) {
          final connected = ctrl.connected;
          final pairing = ctrl.needsPairing || ctrl.verifying;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              PageHeader('Sala en vivo',
                  hint: connected
                      ? 'Sincronizando en ${ctrl.modeLabel}'
                      : 'Comparte tu lista sin internet, con quien esté cerca'),
              if (ctrl.lastError != null) _ErrorBanner(msg: ctrl.lastError!),
              if (connected) ...[
                _ActiveRoom(ctrl: ctrl),
              ] else if (pairing) ...[
                _PairingPanel(ctrl: ctrl),
              ] else ...[
                _ModePicker(ctrl: ctrl),
                if (ctrl.mode == 'server') _ServerConfig(ctrl: ctrl),
                _IdentityName(ctrl: ctrl),
                _HostOptions(ctrl: ctrl),
                _JoinByCode(ctrl: ctrl),
                _NearbyRooms(ctrl: ctrl),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ─── Lobby ──────────────────────────────────────────────────────────────────

String _modeName(String mode) => switch (mode) {
      'lan' => 'WiFi local',
      'hotspot' => 'Hotspot',
      'nearby' => 'Cerca',
      'bt' => 'Bluetooth',
      _ => 'Servidor',
    };

class _ModePicker extends StatelessWidget {
  const _ModePicker({required this.ctrl});
  final RoomController ctrl;

  static const _modes = <(String, IconData, String, String)>[
    ('nearby', Icons.sensors_rounded, 'Cerca (sin internet)',
        'WiFi Direct / Bluetooth del teléfono con Nearby Connections. Máximo 10 personas.'),
    ('lan', Icons.wifi_rounded, 'WiFi local (LAN)',
        'Con el router de la casa o del local: todo por la red local, sin internet.'),
    ('hotspot', Icons.wifi_tethering_rounded, 'Hotspot (sin internet)',
        'El anfitrión activa su punto de acceso y los invitados se conectan a él: misma red local, cero datos móviles.'),
    ('server', Icons.dns_rounded, 'Servidor (sockets)',
        'Conecta con tu propio servidor socket.io o usa este teléfono como servidor.'),
    ('bt', Icons.bluetooth_rounded, 'Bluetooth',
        'Emparejamiento y datos por Bluetooth vía Nearby (BLE/Classic).'),
  ];

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Elige el modo'),
      for (final m in _modes)
        Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => ctrl.setMode(m.$1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
              child: Row(children: [
                Icon(m.$2,
                    size: 22,
                    color: ctrl.mode == m.$1 ? scheme.primary : scheme.onSurfaceVariant),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(m.$3,
                        style: const TextStyle(
                            fontSize: 14, fontWeight: FontWeight.w800)),
                    const SizedBox(height: 2),
                    Text(m.$4,
                        style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: scheme.onSurfaceVariant)),
                  ]),
                ),
                if (ctrl.mode == m.$1)
                  Icon(Icons.check_circle, size: 18, color: scheme.primary),
              ]),
            ),
          ),
        ),
    ]);
  }
}

/// Config del servidor propio (solo modo server): host:puerto, token,
/// probar conexión, guía y «usar este teléfono como servidor».
class _ServerConfig extends StatefulWidget {
  const _ServerConfig({required this.ctrl});
  final RoomController ctrl;

  @override
  State<_ServerConfig> createState() => _ServerConfigState();
}

class _ServerConfigState extends State<_ServerConfig> {
  late final TextEditingController _addr =
      TextEditingController(text: widget.ctrl.serverAddress);
  late final TextEditingController _token =
      TextEditingController(text: widget.ctrl.serverToken);
  String? _probeMsg;
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
      margin: const EdgeInsets.only(top: 4, bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('Tu servidor (socket.io)',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: scheme.onSurface)),
          const SizedBox(height: 8),
          TextField(
            controller: _addr,
            keyboardType: TextInputType.url,
            decoration: const InputDecoration(
                labelText: 'host:puerto',
                hintText: '192.168.1.20:3000',
                isDense: true),
            onChanged: widget.ctrl.setServerAddress,
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _token,
            decoration: const InputDecoration(
                labelText: 'Token (opcional)', isDense: true),
            onChanged: widget.ctrl.setServerToken,
          ),
          const SizedBox(height: 10),
          Row(children: [
            FilledButton.tonal(
              onPressed: () async {
                widget.ctrl.setServerAddress(_addr.text);
                final msg = await widget.ctrl.probeServer();
                setState(() => _probeMsg = msg ?? 'Conexión OK');
              },
              child: const Text('Probar conexión'),
            ),
            const SizedBox(width: 8),
            TextButton(
              onPressed: () => setState(() => _guide = !_guide),
              child: Text(_guide ? 'Ocultar guía' : '¿Cómo monto mi servidor?'),
            ),
          ]),
          if (_probeMsg != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Stamp(_probeMsg!,
                  color: _probeMsg == 'Conexión OK' ? VeColors.of(context).pos : null),
            ),
          if (_guide) ...[
            const SizedBox(height: 10),
            Text(
              '1. Instala Node.js y ejecuta: npm i socket.io\n'
              '2. Crea un server.js que escuche el puerto (ej. 3000).\n'
              '3. Abre host:puerto aquí. También puedes usar este teléfono '
              'como servidor en modo WiFi local: crea la sala y comparte la '
              'IP:puerto que aparece dentro.',
              style: TextStyle(fontSize: 12, height: 1.5, color: scheme.onSurfaceVariant),
            ),
          ],
        ]),
      ),
    );
  }
}

/// Nombre del participante.
class _IdentityName extends StatefulWidget {
  const _IdentityName({required this.ctrl});
  final RoomController ctrl;

  @override
  State<_IdentityName> createState() => _IdentityNameState();
}

class _IdentityNameState extends State<_IdentityName> {
  late final TextEditingController _c = TextEditingController(text: widget.ctrl.myName);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: TextField(
          controller: _c,
          decoration: const InputDecoration(
              labelText: 'Tu nombre en la sala', isDense: true),
          onChanged: (v) => widget.ctrl.setMyName(v),
        ),
      ),
    );
  }
}

/// Opciones del anfitrión: nombre de sala + pública/privada + crear.
class _HostOptions extends StatelessWidget {
  const _HostOptions({required this.ctrl});
  final RoomController ctrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(children: [
            Expanded(
              child: Text('Crear una sala',
                  style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: scheme.onSurface)),
            ),
            ChipTag('Pública',
                selected: ctrl.isPublic,
                onTap: () => ctrl.setPublic(true)),
            const SizedBox(width: 6),
            ChipTag('Privada',
                selected: !ctrl.isPublic,
                onTap: () => ctrl.setPublic(false)),
          ]),
          const SizedBox(height: 6),
          Text(
            ctrl.isPublic
                ? 'Pública: aparece en «salas cercanas» de otros con la app.'
                : 'Privada: solo se entra con el código.',
            style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          TextField(
            onChanged: ctrl.setRoomName,
            decoration: const InputDecoration(
                labelText: 'Nombre de la sala (opcional)', isDense: true),
          ),
          const SizedBox(height: 10),
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: () async {
                final err = await ctrl.join(name: ctrl.myName, code: '');
                if (err != null && context.mounted) {
                  showToast(context, err, kind: ToastKind.error);
                }
              },
              icon: const Icon(Icons.add_circle_outline),
              label: const Text('Crear sala ahora'),
            ),
          ),
        ]),
      ),
    );
  }
}

/// Unirse por código manual.
class _JoinByCode extends StatefulWidget {
  const _JoinByCode({required this.ctrl});
  final RoomController ctrl;

  @override
  State<_JoinByCode> createState() => _JoinByCodeState();
}

class _JoinByCodeState extends State<_JoinByCode> {
  final _code = TextEditingController();

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Unirme con código',
              style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Row(children: [
            Expanded(
              child: TextField(
                controller: _code,
                textCapitalization: TextCapitalization.characters,
                decoration: const InputDecoration(
                    labelText: 'Código de la sala', isDense: true),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              onPressed: () async {
                final err = await widget.ctrl
                    .join(name: widget.ctrl.myName, code: _code.text.trim().toUpperCase());
                if (err != null && context.mounted) {
                  showToast(context, err, kind: ToastKind.error);
                }
              },
              child: const Text('Entrar'),
            ),
          ]),
        ]),
      ),
    );
  }
}

/// Descubrimiento de salas públicas (Nearby + UDP LAN).
class _NearbyRooms extends StatelessWidget {
  const _NearbyRooms({required this.ctrl});
  final RoomController ctrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final rooms = ctrl.foundRooms.where((r) => !r.stale).toList();
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      SectionTitle('Salas cercanas',
          actionLabel: ctrl.scanning ? 'Buscando…' : 'Buscar',
          onAction: ctrl.scanning
              ? () => ctrl.stopScan()
              : () async {
                  await ctrl.startScan();
                }),
      if (rooms.isEmpty)
        Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Text(
              'Sin salas a la vista. Quien cree una sala pública y esté cerca (o en tu misma red WiFi) aparecerá aquí.',
              style: TextStyle(fontSize: 12.5, height: 1.45, color: scheme.onSurfaceVariant),
            ),
          ),
        )
      else
        for (final r in rooms)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            child: ListTile(
              leading: Text(r.emoji, style: const TextStyle(fontSize: 22)),
              title: Text(r.label,
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800)),
              subtitle: Text('${_modeName(r.mode)} · anfitrión: ${r.hostName} · ${r.code}',
                  style: const TextStyle(fontSize: 11.5)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () async {
                final err = await ctrl.joinAd(r, ctrl.myName);
                if (err != null && context.mounted) {
                  showToast(context, err, kind: ToastKind.error);
                }
              },
            ),
          ),
    ]);
  }
}

// ─── Verificación PIN + emoji (invitado) ────────────────────────────────────

class _PairingPanel extends StatefulWidget {
  const _PairingPanel({required this.ctrl});
  final RoomController ctrl;

  @override
  State<_PairingPanel> createState() => _PairingPanelState();
}

class _PairingPanelState extends State<_PairingPanel> {
  String _pin = '';
  String? _emoji;

  @override
  Widget build(BuildContext context) {
    final ctrl = widget.ctrl;
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          const Stamp('Verificación de sala', color: null),
          const SizedBox(height: 10),
          Text(
            ctrl.verifying ? 'Verificando…' : 'Pide el PIN y el emoji al anfitrión',
            style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            'Si el emoji no coincide con el del anfitrión, la conexión se cancela: así nadie interfiere entre salas distintas.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, height: 1.45, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 14),
          // PIN 4 dígitos.
          Row(mainAxisAlignment: MainAxisAlignment.center, children: [
            for (int i = 0; i < 4; i++)
              Container(
                width: 46,
                height: 54,
                margin: const EdgeInsets.symmetric(horizontal: 4),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: scheme.outlineVariant),
                  color: scheme.surfaceContainerLow,
                ),
                child: Text(
                  i < _pin.length ? _pin[i] : '',
                  style: VeText.displayNum(24, color: scheme.onSurface, weight: FontWeight.w700),
                ),
              ),
          ]),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 6,
            children: [
              for (final d in '0123456789'.split(''))
                InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: _pin.length < 4 ? () => setState(() => _pin += d) : null,
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    child: Text(d, style: VeText.displayNum(17, color: scheme.onSurface)),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          const Text('¿Cuál es el emoji del anfitrión?',
              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            children: [
              for (final e in RoomPairing.emojis)
                ChoiceChip(
                  label: Text(e, style: const TextStyle(fontSize: 20)),
                  selected: _emoji == e,
                  onSelected: (_) => setState(() => _emoji = e),
                ),
            ],
          ),
          if (ctrl.pairingError != null) ...[
            const SizedBox(height: 8),
            Text(ctrl.pairingError!,
                style: TextStyle(color: VeColors.of(context).neg, fontSize: 12.5)),
          ],
          const SizedBox(height: 14),
          FilledButton(
            onPressed: (ctrl.verifying || _pin.length < 4 || _emoji == null)
                ? null
                : () {
                    HapticFeedback.mediumImpact();
                    ctrl.submitPairing(_pin, _emoji!);
                  },
            child: Text(ctrl.verifying ? 'Enviando…' : 'Verificar y entrar'),
          ),
        ]),
      ),
    );
  }
}

// ─── Sala activa ────────────────────────────────────────────────────────────

class _ActiveRoom extends StatelessWidget {
  const _ActiveRoom({required this.ctrl});
  final RoomController ctrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      // Código + QR + copiar.
      Card(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(children: [
            Row(children: [
              Stamp(ctrl.modeLabel, color: sem.pos),
              if (ctrl.roomName.isNotEmpty) ...[
                const SizedBox(width: 8),
                Flexible(child: Text(ctrl.roomName,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800))),
              ],
              const Spacer(),
              Stamp(ctrl.isPublic ? 'pública' : 'privada'),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('CÓDIGO DE LA SALA', style: VeText.labelCaps(9.5, color: scheme.onSurfaceVariant)),
                  const SizedBox(height: 4),
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(ctrl.code.isEmpty ? '—' : ctrl.code,
                        style: VeText.displayNum(38, color: scheme.onSurface, weight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 6),
                  Row(children: [
                    TextButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: ctrl.code));
                        showToast(context, 'Código copiado', kind: ToastKind.ok);
                      },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copiar'),
                    ),
                    if (ctrl.isHost && ctrl.emoji.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Text('PIN ${ctrl.pin} · ${ctrl.emoji}',
                            style: const TextStyle(fontSize: 11.5, color: Color(0xFF93A0BE))),
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
                          : 'Eres el anfitrión. Los invitados entran con el código y verifican PIN + emoji.',
                      style: TextStyle(fontSize: 11.5, color: scheme.onSurfaceVariant),
                    ),
                  ),
                ]),
              ),
          ]),
        ),
      ),
      // Miembros.
      SectionTitle('Miembros (${ctrl.members.length + 1})'),
      Card(
        child: Column(children: [
          for (final m in ctrl.members)
            ListTile(
              dense: true,
              leading: Icon(
                m.online ? Icons.person_rounded : Icons.person_off_rounded,
                size: 20,
                color: m.online ? sem.pos : scheme.onSurfaceVariant,
              ),
              title: Text(m.name,
                  style: const TextStyle(fontSize: 13.5, fontWeight: FontWeight.w700)),
              trailing: m.typing
                  ? Text('escribiendo…', style: TextStyle(fontSize: 11, color: scheme.onSurfaceVariant))
                  : null,
            ),
        ]),
      ),
      const SizedBox(height: 10),
      Row(children: [
        Expanded(
          child: FilledButton.tonal(
            onPressed: ctrl.sendTyping,
            child: const Row(mainAxisSize: MainAxisSize.min, children: [
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
            await ctrl.leave();
          },
          child: const Text('Salir'),
        ),
      ]),
      const SizedBox(height: 8),
      Text(
        'La lista se sincroniza sola entre los miembros de la sala. Si se corta la conexión, tus cambios quedan en el outbox y salen al reconectar.',
        style: TextStyle(fontSize: 11.5, height: 1.5, color: scheme.onSurfaceVariant),
      ),
    ]);
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
          Expanded(child: Text(msg, style: TextStyle(fontSize: 12.5, color: sem.neg))),
        ]),
      ),
    );
  }
}
