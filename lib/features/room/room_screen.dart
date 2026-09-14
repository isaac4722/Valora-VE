/// ─── Sala en vivo · CONFIGURACIÓN de la sala (v18.0) ───────────────────────
/// Esta pantalla arma la sala: 5 modos (Servidor · Cerca/Nearby · WiFi
/// local · Hotspot · Bluetooth RFCOMM), servidor propio configurable,
/// descubrimiento de salas públicas o entrada por código, verificación
/// PIN+emoji en TODOS los caminos. Al CONECTAR te lleva a la Lista con un
/// toast «En sala» — la sala se VIVE en su propia pantalla (/sala-viva,
/// distinta de esta). Nada de datos móviles: los transportes directos
/// (LAN/Hotspot/Nearby/BT) son 100% locales.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../room/room_transport.dart';
import '../../widgets/ui.dart';

/// Pantalla de configuración de la sala (ruta /sala).
class RoomScreen extends StatefulWidget {
  const RoomScreen({super.key});

  @override
  State<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends State<RoomScreen> {
  @override
  Widget build(BuildContext context) {
    // Controlador de APLICACIÓN (v18.0): la Sala Viva y la Lista lo comparten.
    final ctrl = context.watch<RoomController>();
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      backgroundColor: scheme.surfaceContainerLowest,
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        children: [
          const PageHeader('Sala en vivo',
              hint: 'Comparte tu lista sin internet, con quien esté cerca'),
          if (ctrl.lastError != null) _ErrorBanner(msg: ctrl.lastError!),
          if (ctrl.connected) ...[
            _EnSalaBanner(ctrl: ctrl),
          ] else if (ctrl.needsPairing || ctrl.verifying) ...[
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
      ),
    );
  }
}

/// Post-join común (v18.0): toast + a la Lista — la sala se vive aparte.
Future<void> _afterJoin(BuildContext context, String? err) async {
  if (err != null) {
    if (context.mounted) showToast(context, err, kind: ToastKind.error);
    return;
  }
  if (context.mounted) {
    showToast(context, 'En sala · la lista se sincroniza', kind: ToastKind.ok);
    context.go('/lista');
  }
}

// ─── Banner «En sala» (configuración) ───────────────────────────────

class _EnSalaBanner extends StatelessWidget {
  const _EnSalaBanner({required this.ctrl});
  final RoomController ctrl;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    final title = ctrl.roomName.isNotEmpty ? ctrl.roomName : 'Sala ${ctrl.code}';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(children: [
          Row(children: [
            const LiveBadge(live: true),
            const SizedBox(width: 8),
            Expanded(
              child: Text(title,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
            ),
          ]),
          const SizedBox(height: 4),
          Text(
            'Ya estás en sala (${ctrl.modeLabel}${ctrl.isHost ? ' · anfitrión' : ''}). '
            'La lista se sincroniza sola; los miembros y roles se ven en la Sala Viva.',
            style: TextStyle(fontSize: 12.5, height: 1.5, color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Row(children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: () => context.push('/sala-viva'),
                icon: const Icon(Icons.groups_2_outlined, size: 18),
                label: const Text('Abrir Sala Viva'),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.tonal(
              style: FilledButton.styleFrom(
                  backgroundColor: sem.neg.withValues(alpha: 0.14),
                  foregroundColor: sem.neg),
              onPressed: () async => ctrl.leave(),
              child: const Text('Salir'),
            ),
          ]),
        ]),
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
    ('bt', Icons.bluetooth_rounded, 'Bluetooth directo (RFCOMM)',
        'Bluetooth clásico teléfono a teléfono: emparejas y listo, sin internet ni WiFi. Varios invitados.'),
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
                if (context.mounted) await _afterJoin(context, err);
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
                if (context.mounted) await _afterJoin(context, err);
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
                if (context.mounted) await _afterJoin(context, err);
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
