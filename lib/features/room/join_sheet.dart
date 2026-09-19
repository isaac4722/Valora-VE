/// ─── Hoja de unirse (v19.8 · orden del dueño: conexión → nombre → PIN) ──────
/// El flujo de ENTRADA a una sala en un solo lugar, por pasos:
/// 1) Nombre (preguntado aquí, nunca antes: el lobby solo configura la
///    conexión; el nombre es de QUIEN entra, no de la pantalla).
/// 2) PIN de emojis si la sala lo pide (flag del QR/intento fallido).
/// 3) Conectar: estado vivo, errores claros y reintento del PIN si falló.
///
/// Puertas que la abren: código manual · escáner in-app · salas cercanas ·
/// deep link del QR (valorave://sala?c=…&m=…&p=1) desde la cámara.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../room/room_controller.dart';
import '../../room/room_transport.dart'
    show RoomAd, RoomMode, RoomModeX, SalaInvite;
import 'pin_emoji.dart';

/// Abre la hoja de unirse. [invite] prellena el código (QR/escáner);
/// [ad] entra al marcar una sala avistada (marca el host/puerto para el
/// dial directo). Si ambos son null, arranca pidiendo el código.
Future<void> showJoinSheet(
  BuildContext context, {
  SalaInvite? invite,
  RoomAd? ad,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _JoinSheet(invite: invite, ad: ad),
  );
}

class _JoinSheet extends StatefulWidget {
  const _JoinSheet({this.invite, this.ad});

  final SalaInvite? invite;
  final RoomAd? ad;

  @override
  State<_JoinSheet> createState() => _JoinSheetState();
}

class _JoinSheetState extends State<_JoinSheet> {
  late final TextEditingController _nameCtrl;
  late final TextEditingController _codeCtrl;
  String _pin = '';
  bool _askPin = false; // pide el teclado de emojis
  bool _pinError = false;
  String? _busyError;
  bool _connecting = false;

  @override
  void initState() {
    super.initState();
    final room = context.read<RoomController>();
    _nameCtrl = TextEditingController(text: room.myName);
    _codeCtrl = TextEditingController(
      text: widget.invite?.code ?? widget.ad?.code ?? '',
    );
    _askPin = widget.invite?.hasPin ?? false;
    if (widget.invite?.mode != null) {
      room.setMode(widget.invite!.mode!);
    } else if (widget.ad != null) {
      room.setMode(widget.ad!.mode);
    }
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _connect() async {
    final room = context.read<RoomController>();
    FocusScope.of(context).unfocus();
    setState(() => _connecting = true);
    final err = await room.join(
      name: _nameCtrl.text,
      code: _codeCtrl.text,
      ad: widget.ad,
      pin: _pin,
    );
    if (!mounted) return;
    setState(() => _connecting = false);
    if (err == null) {
      Navigator.of(context).pop();
      return;
    }
    // PIN incorrecto: vuelve a pedirlo con el error a la vista.
    if (err.contains('PIN')) {
      setState(() {
        _busyError = err;
        _askPin = true;
        _pinError = true;
        _pin = '';
      });
      return;
    }
    setState(() => _busyError = err);
  }

  bool get _canTry =>
      !_connecting &&
      _codeCtrl.text.trim().length >= 4 &&
      _nameCtrl.text.trim().isNotEmpty &&
      (!_askPin || _pin.characters.length == kPinLength);

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomController>();
    final scheme = Theme.of(context).colorScheme;
    final inv = widget.invite;
    final ad = widget.ad;
    final isPrefilled = inv != null || ad != null;
    final invLabel = inv?.roomName.isNotEmpty == true
        ? inv!.roomName
        : (ad?.label ?? '');
    final invHost = inv?.hostName.isNotEmpty == true
        ? inv!.hostName
        : (ad?.hostName ?? '');

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera con contexto.
            Padding(
              padding: const EdgeInsets.fromLTRB(0, 4, 0, 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      isPrefilled ? 'Unirme a la sala' : 'Unirme',
                      style: const TextStyle(
                        fontFamily: 'SpaceGrotesk',
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Cerrar',
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.close_rounded,
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                isPrefilled
                    ? 'Invitación por QR — revisa cómo quieres entrar'
                    : 'Pon el código de 6 letras, tu nombre y conéctate',
                style: TextStyle(fontSize: 12, color: scheme.onSurfaceVariant),
              ),
            ),
            const SizedBox(height: 4),

            // ── Paso 1 · Código (si no viene del QR/escáner) ──
            if (!isPrefilled) ...[
              TextField(
                controller: _codeCtrl,
                maxLength: 6,
                textCapitalization: TextCapitalization.characters,
                autofocus: true,
                onChanged: (v) {
                  _codeCtrl.text = v.toUpperCase();
                  _codeCtrl.selection = TextSelection.collapsed(
                    offset: _codeCtrl.text.length,
                  );
                  setState(() {});
                },
                decoration: const InputDecoration(
                  hintText: 'ABC123',
                  labelText: 'Código de la sala',
                  counterText: '',
                  prefixIcon: Icon(Icons.tag),
                  border: OutlineInputBorder(),
                  isDense: true,
                ),
              ),
              const SizedBox(height: 12),
            ] else
              // Contexto de la invitación: sala + anfitrión.
              _InviteContext(label: invLabel, host: invHost),

            // ── Paso 2 · Cómo me conecto (4 modos, compacto) ──
            Row(
              children: [
                for (final m in RoomMode.values)
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 2),
                      child: _ModeChip(
                        mode: m,
                        selected: room.mode == m,
                        onTap: () => context.read<RoomController>().setMode(m),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 12),

            // ── Paso 3 · Nombre ──
            TextField(
              controller: _nameCtrl,
              maxLength: 24,
              onChanged: (v) => setState(() {}),
              decoration: const InputDecoration(
                hintText: '¿Cómo te ven en la sala?',
                labelText: 'Tu nombre',
                counterText: '',
                prefixIcon: Icon(Icons.badge_outlined),
                border: OutlineInputBorder(),
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            // ── Paso 3 · PIN de emojis (si la sala lo pide) ──
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 220),
              child: _askPin
                  ? Column(
                      key: const ValueKey('pin-pad'),
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.lock_outline,
                              size: 15,
                              color: scheme.primary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                'Esta sala pide un PIN de 4 emojis',
                                style: VeText.labelCaps(
                                  10.5,
                                  color: scheme.primary,
                                ),
                              ),
                            ),
                            TextButton(
                              onPressed: _pin.isEmpty
                                  ? null
                                  : () => setState(() {
                                      _askPin = false;
                                      _pin = '';
                                      _pinError = false;
                                    }),
                              child: const Text(
                                'No tengo PIN',
                                style: TextStyle(fontSize: 11),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        PinEmojiPad(
                          entered: _pin,
                          onChanged: (v) => setState(() {
                            _pin = v;
                            _pinError = false;
                          }),
                          error: _pinError,
                        ),
                        const SizedBox(height: 4),
                      ],
                    )
                  : Padding(
                      key: const ValueKey('pin-off'),
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          Icon(
                            Icons.lock_open_outlined,
                            size: 14,
                            color: scheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Expanded(
                            child: Text(
                              'Si el anfitrión pidió PIN, te lo pedirá al '
                              'conectar.',
                              style: TextStyle(
                                fontSize: 11.5,
                                color: scheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
            ),

            // ── Estado: conectando / error ──
            if (_connecting)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Conectando por ${room.modeLabel}…',
                        style: const TextStyle(
                          fontSize: 12.5,
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
            if (_busyError != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 15,
                      color: VeColors.of(context).neg,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        _busyError!,
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: VeColors.of(context).neg,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

            // ── Acción ──
            FilledButton.icon(
              onPressed: _canTry ? _connect : null,
              icon: const Icon(Icons.login, size: 17),
              label: Text(
                _askPin && _pin.characters.length < kPinLength
                    ? 'Marca el PIN (${_pin.characters.length}/$kPinLength)'
                    : 'Unirme por ${room.modeLabel}',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InviteContext extends StatelessWidget {
  const _InviteContext({required this.label, required this.host});

  final String label;
  final String host;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: scheme.primary.withValues(alpha: 0.06),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: scheme.primary.withValues(alpha: 0.3)),
        ),
        child: Row(
          children: [
            Icon(Icons.qr_code_2, size: 18, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                label.isNotEmpty
                    ? (host.isNotEmpty
                          ? 'Sala «$label» de $host'
                          : 'Sala «$label»')
                    : 'Sala avistada cerca',
                style: const TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Chip compacto de modo de conexión para la hoja de unirse.
class _ModeChip extends StatelessWidget {
  const _ModeChip({
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
        padding: const EdgeInsets.symmetric(vertical: 8),
        decoration: BoxDecoration(
          color: selected ? scheme.primary.withValues(alpha: 0.08) : null,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected
                ? scheme.primary.withValues(alpha: 0.4)
                : scheme.outlineVariant,
          ),
        ),
        child: Column(
          children: [
            Icon(
              icon,
              size: 16,
              color: selected ? scheme.primary : scheme.onSurfaceVariant,
            ),
            const SizedBox(height: 3),
            Text(
              mode.id == 'wifi' ? 'WiFi' : mode.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 9.5,
                fontWeight: FontWeight.w700,
                color: selected ? scheme.primary : scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
