/// ─── Sala · lobby de conexión (v29 · H-38: reconstruido desde cero) ─────────
/// El lobby en el lenguaje de secciones v28/v29: TÍTULO + descripción de una
/// línea + detalles con hairlines, separadas por espacio en blanco, cero
/// cajas dentro de cajas.
///
/// · CÓMO SE CONECTAN — la configuración primero (orden del dueño): TRES
///   modos P2P sin internet (Cerca · WiFi o Hotspot · Bluetooth) + el
///   servidor propio, cada uno con su tecnología.
/// · INTENCIÓN (v20) — «dependiendo lo que se vaya a usar salga algo y no
///   salga otro»: segmentos CORTOS («Unirme» · «Crear») que jamás se
///   recortan; solo el flujo elegido se pinta.
/// · SALAS CERCANAS — escucha en vivo de las públicas.
///
/// Unirse (hoja JoinSheet del prototipo: modo · nombre · código · PIN) ·
/// Crear (anfitrión, con PIN de emojis opcional) · escaneo de QR y deep
/// links. Toda la funcionalidad P2P/servidor/PIN intacta.
library;

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme.dart';
import '../../room/room_controller.dart';
import '../../room/room_transport.dart';
import '../../services/deep_link.dart' show salaInviteRequest;
import '../../widgets/ui.dart';
import '../scanner/scanner_screen.dart';
import 'join_sheet.dart';
import 'pin_emoji.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:valorave/providers/providers.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:valorave/core/ve_theme.dart';

class RoomScreen extends ConsumerStatefulWidget {
  const RoomScreen({super.key});

  @override
  ConsumerState<RoomScreen> createState() => _RoomScreenState();
}

class _RoomScreenState extends ConsumerState<RoomScreen> {
  late final TextEditingController _roomNameCtrl;
  late final TextEditingController _hostNameCtrl;
  String? _busyError;
  bool _creating = false;

  /// v20 (orden del dueño): INTENCIÓN primero — «dependiendo lo que se vaya
  /// a usar salga algo y no salga otro». 0 = Unirme · 1 = Crear. Solo el
  /// flujo elegido se pinta (antes salían las DOS tarjetas con todo el
  /// texto de ambas).
  int _intent = 0;

  @override
  void initState() {
    super.initState();
    final room = ref.read(roomControllerProvider);
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
    // En sala: a la Lista (la entrada «Sala en vivo» lleva a la Sala Viva).
    if (ref.read(roomControllerProvider).connected) {
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
    final room = ref.watch(roomControllerProvider);
    final busy = room.status == RoomStatus.connecting || _creating;

    return PushScreen(
      title: 'Sala en vivo',
      subtitle: 'Sincroniza la lista P2P — sin internet, sin cuentas',
      child: VeEntry(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
          children: [
            if (room.connected) _EnSalaRow(room: room),
            if (_busyError != null || room.lastError != null) ...[
              _AvisoPlano(msg: _busyError ?? room.lastError!),
              const SizedBox(height: 10),
            ],
            if (busy && !_creating) ...[
              const _Conectando(),
              const SizedBox(height: 10),
            ],
            // 1º CÓMO SE CONECTAN (la configuración primero, orden del dueño).
            _ComoSeConectan(room: room),
            // 2º El servidor propio, solo en su modo.
            if (room.mode == RoomMode.servidor) ...[
              const SizedBox(height: 10),
              const _SeccionServidor(),
            ],
            // 3º INTENCIÓN (v20): Unirme o Crear — segmentos cortos que
            // jamás se recortan (H-38).
            VeEyebrow(
              hint: 'Elige primero qué vas a hacer — solo ese flujo se pinta.',
              child: const Text('TU INTENCIÓN'),
            ),
            VeSegmented<int>(
              value: _intent,
              onChanged: (v) => setState(() => _intent = v),
              segments: const [
                VeSegment(value: 0, label: 'Unirme'),
                VeSegment(value: 1, label: 'Crear'),
              ],
            ),
            const SizedBox(height: 10),
            if (_intent == 0)
              // FLUJO UNIRSE: puerta + QR — nada de crear.
              _FlujoUnirse(busy: busy)
            else
              // FLUJO CREAR: anfitrión completo — nada de unirse.
              _FlujoCrear(
                room: room,
                roomNameCtrl: _roomNameCtrl,
                hostNameCtrl: _hostNameCtrl,
                busy: busy,
                creating: _creating,
                onRun: _run,
                onCreating: (v) => setState(() => _creating = v),
              ),
            // 4º SALAS CERCANAS (escucha en vivo de las públicas).
            const SizedBox(height: 10),
            _SalasCercanas(room: room, busy: busy),
          ],
        ),
      ),
    );
  }
}

/// Banner cuando YA hay sala activa: directo a la Sala Viva.
class _EnSalaRow extends StatelessWidget {
  const _EnSalaRow({required this.room});

  final RoomController room;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    final title = room.roomName.isNotEmpty
        ? room.roomName
        : 'Sala ${room.code}';
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => context.push('/sala-viva'),
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
            child: Row(
              children: [
                const VeBadge(
                  tone: VeTone.pos,
                  dot: true,
                  child: Text('En sala'),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '$title · ${room.visibleMembers.length} en la sala',
                      maxLines: 1,
                      style: TextStyle(
                        fontFamily: 'Inter',
                        fontSize: 13.5,
                        fontWeight: FontWeight.w600,
                        color: scheme.foreground,
                      ),
                    ),
                  ),
                ),
                Icon(
                  LucideIcons.chevronRight,
                  size: 15,
                  color: scheme.mutedForeground,
                ),
              ],
            ),
          ),
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
    return Row(
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
    );
  }
}

/// Conectando… con cancelar (como el resto de la app, en Ve).
class _Conectando extends ConsumerWidget {
  const _Conectando();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(roomControllerProvider);
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
            'Conectando por ${live.modeLabel}…',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              fontWeight: FontWeight.w600,
              color: scheme.foreground,
            ),
          ),
        ),
        VeBtn(
          variant: VeBtnVariant.ghost,
          size: VeBtnSize.sm,
          onPressed: () => live.leave(),
          child: const Text('Cancelar'),
        ),
      ],
    );
  }
}

/// CÓMO SE CONECTAN (H-38): sección con filas de hairline — un modo por
/// fila, cada uno con SU tecnología; la activa lleva el check a la derecha.
class _ComoSeConectan extends StatelessWidget {
  const _ComoSeConectan({required this.room});

  final RoomController room;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VeEyebrow(
          hint:
              'Tres modos sin internet y el servidor propio — cada uno con '
              'su tecnología.',
          child: const Text('CÓMO SE CONECTAN'),
        ),
        VeGroup(
          semantic: 'Modos de conexión',
          children: [
            for (final m in RoomMode.values)
              VeRow(
                label: Text(m.label),
                // tech·hint es LARGO (verificación visual 390: a 1 línea
                // quedaba «Sin configurar…» «el Hot…»). 3 líneas explícitas:
                // el texto completo cabe y respira.
                sub: Text('${m.tech} · ${m.hint}'),
                onTap: () => room.setMode(m),
                right: room.mode == m
                    ? Icon(
                        LucideIcons.check,
                        size: 15,
                        color: scheme.foreground,
                      )
                    : Icon(
                        switch (m) {
                          RoomMode.cerca => LucideIcons.radioTower,
                          RoomMode.wifi => LucideIcons.router,
                          RoomMode.bt => LucideIcons.bluetooth,
                          RoomMode.servidor => LucideIcons.server,
                        },
                        size: 15,
                        color: scheme.mutedForeground,
                      ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Puerta de unirse (v19.8): la hoja JoinSheet hace el flujo completo
/// (modo · nombre · código · PIN). Aquí solo el atajo: botón grande + escanear.
class _FlujoUnirse extends StatelessWidget {
  const _FlujoUnirse({required this.busy});

  final bool busy;

  Future<void> _scanQr(BuildContext context) async {
    // v20: modo QR del escáner — antes se abría el lector de EAN y el QR
    // de invitación jamás se leía.
    final raw = await ScannerScreen.scan(context, qr: true);
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: VeBtn(
                variant: VeBtnVariant.primary,
                icon: LucideIcons.logIn,
                enabled: !busy,
                onPressed: busy ? null : () => showJoinSheet(context),
                child: const Text('Unirme con el código'),
              ),
            ),
            const SizedBox(width: 8),
            VeBtn(
              variant: VeBtnVariant.secondary,
              icon: LucideIcons.scanLine,
              enabled: !busy,
              onPressed: busy ? null : () => _scanQr(context),
              child: const Text('Escanear QR'),
            ),
          ],
        ),
      ],
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
    final scheme = context.ve.colorScheme;
    return VeRow(
      label: Text(ad.label),
      sub: Text('${ad.code} · anfitrión ${ad.hostName}'),
      showChevron: true,
      semantic: 'Sala ${ad.label}',
      onTap: busy ? null : onTap,
      right: Icon(
        switch (ad.mode) {
          RoomMode.cerca => LucideIcons.radioTower,
          RoomMode.wifi => LucideIcons.router,
          RoomMode.bt => LucideIcons.bluetooth,
          RoomMode.servidor => LucideIcons.server,
        },
        size: 15,
        color: scheme.mutedForeground,
      ),
    );
  }
}

/// FLUJO CREAR: anfitrión completo — nombres, sala pública, PIN de emojis,
/// botón y búsqueda de salas existentes (antes de crear una nueva, se puede
/// mirar si ya existe una con ese nombre).
class _FlujoCrear extends ConsumerStatefulWidget {
  const _FlujoCrear({
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
  ConsumerState<_FlujoCrear> createState() => _FlujoCrearState();
}

class _FlujoCrearState extends ConsumerState<_FlujoCrear> {
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
    final scheme = context.ve.colorScheme;
    final matches = _matches;
    return KeyedSubtree(
      // Ancla de tests: la búsqueda y sus resultados viven SOLO en el
      // flujo CREAR (v20: flujos exclusivos).
      key: const Key('lobby-crear'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu teléfono es el anfitrión: comparte el código de 6 letras.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 13.5,
              color: scheme.mutedForeground,
            ),
          ),
          const SizedBox(height: 12),
          VeInput(
            controller: widget.hostNameCtrl,
            placeholder: '¿Cómo te ven en la sala?',
            onChanged: room.setMyName,
            semantic: 'Tu nombre como anfitrión',
          ),
          const SizedBox(height: 8),
          VeInput(
            controller: widget.roomNameCtrl,
            placeholder: 'Nombre de la sala (opcional)',
            onChanged: room.setRoomName,
            semantic: 'Nombre de la sala',
          ),
          const SizedBox(height: 12),
          // Sala pública.
          _ToggleRow(
            label: 'Sala pública',
            sub: room.isPublic
                ? 'Aparece en el escaneo de salas cercanas'
                : 'Solo entra quien tenga el código',
            value: room.isPublic,
            onChanged: room.setPublic,
          ),
          const SizedBox(height: 10),
          // ── PIN de emojis (v19.8 · orden del dueño): el candado de la
          // puerta — nadie se une por azar sin los 4 emojis.
          _ToggleRow(
            label: 'Pedir PIN de emojis',
            sub: 'Quien se une marca los 4 emojis que le muestres',
            value: room.hasPin,
            onChanged: (v) => room.setPin(
              v
                  ? (room.pinEmoji.isNotEmpty
                        ? room.pinEmoji
                        : generatePinEmoji())
                  : '',
            ),
          ),
          if (room.hasPin) ...[
            const SizedBox(height: 10),
            PinShowCard(
              pin: room.pinEmoji,
              onRegenerate: () => room.setPin(generatePinEmoji()),
            ),
          ],
          const SizedBox(height: 12),
          VeBtn(
            variant: VeBtnVariant.primary,
            size: VeBtnSize.lg,
            expands: true,
            icon: LucideIcons.plus,
            enabled: !widget.busy,
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
            child: Text('Crear por ${room.modeLabel}'),
          ),
          // ── Buscar sala (v19.4 · orden del dueño): antes de crear una
          // nueva, se puede mirar si ya existe una con ese nombre.
          const SizedBox(height: 12),
          VeInput(
            controller: _searchCtrl,
            enabled: !widget.busy,
            placeholder: 'Buscar sala por nombre o código',
            semantic: 'Buscar sala',
            onChanged: (v) {
              setState(() {});
              // Escribir ya escucha: sin tocar el botón de Salas
              // cercanas, una sola vez por búsqueda.
              final hayTexto = v.trim().isNotEmpty;
              if (hayTexto && !_scanKicked && !room.scanning && !widget.busy) {
                _scanKicked = true;
                room.startScan();
              } else if (!hayTexto) {
                _scanKicked = false;
              }
            },
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
                  fontFamily: 'Inter',
                  fontSize: 13.5,
                  height: 1.4,
                  color: scheme.mutedForeground,
                ),
              )
            else
              VeGroup(
                children: [
                  for (final ad in matches)
                    _RoomAdTile(
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
                ],
              ),
          ],
        ],
      ),
    );
  }
}

/// Fila etiqueta + subtítulo + interruptor Ve (patrón Ajustes).
class _ToggleRow extends StatelessWidget {
  const _ToggleRow({
    required this.label,
    required this.sub,
    required this.value,
    required this.onChanged,
  });

  final String label;
  final String sub;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    return Semantics(
      label: label,
      toggled: value,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.foreground,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sub,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 11,
                    height: 1.35,
                    color: scheme.mutedForeground,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          VeToggle(value: value, onChanged: onChanged, label: label),
        ],
      ),
    );
  }
}

/// SALAS CERCANAS (H-38): sección propia de escucha — las públicas del modo
/// activo aparecen al tocar «Escuchar».
class _SalasCercanas extends ConsumerStatefulWidget {
  const _SalasCercanas({required this.room, required this.busy});

  final RoomController room;
  final bool busy;

  @override
  ConsumerState<_SalasCercanas> createState() => _SalasCercanasState();
}

class _SalasCercanasState extends ConsumerState<_SalasCercanas> {
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
    final room = ref.watch(roomControllerProvider);
    final scheme = context.ve.colorScheme;
    return KeyedSubtree(
      key: const Key('lobby-cercanas'),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          VeEyebrow(
            hint: 'Salas públicas por ${room.modeLabel}. ${room.mode.hint}',
            right: VeBtn(
              variant: VeBtnVariant.ghost,
              size: VeBtnSize.sm,
              icon: room.scanning ? LucideIcons.circleStop : LucideIcons.radar,
              enabled: !widget.busy,
              onPressed: widget.busy
                  ? null
                  : () => room.scanning ? room.stopScan() : room.startScan(),
              child: Text(room.scanning ? 'Parar' : 'Escuchar'),
            ),
            child: const Text('SALAS CERCANAS'),
          ),
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
                    fontFamily: 'Inter',
                    fontSize: 13.5,
                    color: scheme.mutedForeground,
                  ),
                ),
              ],
            )
          else if (!room.scanning && room.foundRooms.isEmpty)
            Text(
              'Toca «Escuchar» para ver las salas públicas cerca.',
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                color: scheme.mutedForeground,
              ),
            )
          else
            VeGroup(
              children: [
                for (final ad in room.foundRooms)
                  _RoomAdTile(
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
              ],
            ),
        ],
      ),
    );
  }
}

/// ─── Servidor propio (v19 · devuelto por orden del dueño) ──────────────────
/// Config del relay socket.io del usuario: URL host:puerto, token opcional,
/// probar conexión y guía mínima del server.js de referencia. El modo NO se
/// elimina: quien tenga su servidor lo usa con o sin internet.
class _SeccionServidor extends ConsumerStatefulWidget {
  const _SeccionServidor();

  @override
  ConsumerState<_SeccionServidor> createState() => _SeccionServidorState();
}

class _SeccionServidorState extends ConsumerState<_SeccionServidor> {
  late final TextEditingController _addr;
  late final TextEditingController _token;
  String? _probeMsg;
  bool _probing = false;
  bool _guide = false;

  @override
  void initState() {
    super.initState();
    final room = ref.read(roomControllerProvider);
    _addr = TextEditingController(text: room.serverAddress);
    _token = TextEditingController(text: room.serverToken);
  }

  @override
  void dispose() {
    _addr.dispose();
    _token.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final scheme = context.ve.colorScheme;
    final ink = VeColors.of(context);
    final room = ref.watch(roomControllerProvider);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        VeEyebrow(
          hint:
              'El servidor solo TRANSPORTA: la lista, los roles y la '
              'verificación viven en el teléfono del anfitrión.',
          child: const Text('TU SERVIDOR (SOCKET.IO)'),
        ),
        VeInput(
          controller: _addr,
          placeholder: 'http://192.168.1.20:3000',
          keyboardType: TextInputType.url,
          onChanged: room.setServerAddress,
          semantic: 'URL del servidor',
        ),
        const SizedBox(height: 8),
        VeInput(
          controller: _token,
          placeholder: 'Token (opcional)',
          onChanged: room.setServerToken,
          semantic: 'Token del servidor',
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 6,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            VeBtn(
              variant: VeBtnVariant.secondary,
              icon: _probing ? null : LucideIcons.plugZap,
              enabled: !_probing,
              onPressed: _probing
                  ? null
                  : () async {
                      setState(() => _probing = true);
                      final msg = await room.probeServer();
                      if (!mounted) return;
                      setState(() {
                        _probing = false;
                        _probeMsg = msg ?? 'Conexión OK';
                      });
                    },
              child: _probing
                  ? const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Probar conexión'),
            ),
            VeBtn(
              variant: VeBtnVariant.ghost,
              onPressed: () => setState(() => _guide = !_guide),
              child: Text(_guide ? 'Ocultar guía' : '¿Cómo monto mi servidor?'),
            ),
          ],
        ),
        if (_probeMsg != null)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              _probeMsg!,
              style: TextStyle(
                fontFamily: 'Inter',
                fontSize: 13.5,
                fontWeight: FontWeight.w700,
                color: _probeMsg == 'Conexión OK' ? ink.pos : ink.neg,
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
              fontFamily: 'Inter',
              fontSize: 13.5,
              height: 1.5,
              color: scheme.mutedForeground,
            ),
          ),
        ],
      ],
    );
  }
}
