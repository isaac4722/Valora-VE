/// ─── Hoja de unirse (v19.8 → TASK-35 p4: diseño JoinSheet del prototipo) ───
/// El flujo de ENTRADA a una sala en un solo lugar, por pasos (como el
/// prototipo web): 1 · Conexión (chips) → 2 · Tu nombre (chips + propio) →
/// 3 · Código de la sala (6 columnas con flechas) → PIN de 4 emojis si la
/// sala lo pide. Barra de progreso al pie del título y botón principal en
/// el pie de la hoja. TECHO: la hoja Ve nunca supera el 88 % útil.
///
/// Puertas que la abren: código manual · escáner in-app · salas cercanas ·
/// deep link del QR (valorave://sala?c=…&m=…&p=1) desde la cámara.
library;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/theme.dart';
import '../../room/room_controller.dart';
import '../../room/room_transport.dart'
    show RoomAd, RoomMode, RoomModeX, SalaInvite;
import '../../widgets/ve/ve.dart';
import 'pin_emoji.dart';

/// Alfabeto del código de sala (RoomProtocol.newCode: 6 chars sin O/I).
const String _kAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

/// Abre la hoja de unirse. [invite] prellena el código (QR/escáner);
/// [ad] entra al marcar una sala avistada (marca el host/puerto para el
/// dial directo). Si ambos son null, arranca con las ruedas de letras.
Future<void> showJoinSheet(
  BuildContext context, {
  SalaInvite? invite,
  RoomAd? ad,
}) {
  return showVeSheet<void>(
    context: context,
    title: 'Unirse a una sala',
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
  late final List<int> _codeIdx;
  String _pin = '';
  bool _askPin = false; // pide el teclado de emojis
  bool _pinError = false;
  String? _busyError;
  bool _connecting = false;
  bool _customName = false;
  // ¿El usuario marcó el código? Las ruedas nacen en «AAAAAA» (código VÁLIDO
  // desde el inicio, a diferencia del prototipo donde code nace vacío): el
  // paso 3 se cuenta cuando el código fue MARCADO a mano o llega pre-llenado
  // por invite/anuncio — así «Paso X de 3» arranca en 1 como el prototipo.
  bool _codeTouched = false;

  String get _word => String.fromCharCodes(
    _codeIdx.map((i) => _kAlphabet.codeUnitAt(i)),
  );

  @override
  void initState() {
    super.initState();
    final room = context.read<RoomController>();
    _nameCtrl = TextEditingController(text: room.myName);
    final preset = widget.invite?.code ?? widget.ad?.code ?? '';
    _codeTouched = preset.length == 6;
    _codeIdx = [
      for (var i = 0; i < 6; i++)
        _kAlphabet.indexOf(preset.length > i ? preset[i] : 'A').clamp(0, 31),
    ];
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
    super.dispose();
  }

  Future<void> _connect() async {
    final room = context.read<RoomController>();
    FocusScope.of(context).unfocus();
    setState(() => _connecting = true);
    final err = await room.join(
      name: _nameCtrl.text,
      code: _word,
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
      _nameCtrl.text.trim().isNotEmpty &&
      (!_askPin || _pin.characters.length == kPinLength);

  /// Paso vivo (como el prototipo): 1 conexión · 2 nombre · 3 código.
  /// El prototipo cuenta 1 + nombre + código; aquí el código cuenta cuando
  /// fue dializado (las ruedas nacen llenas) — «Paso 1 de 3» al abrir.
  int get _step =>
      1 + (_nameCtrl.text.trim().isNotEmpty ? 1 : 0) + (_codeTouched ? 1 : 0);

  void _bump(int col, int delta) {
    setState(() {
      _codeTouched = true;
      _codeIdx[col] = (_codeIdx[col] + delta + _kAlphabet.length) %
          _kAlphabet.length;
    });
  }

  @override
  Widget build(BuildContext context) {
    final room = context.watch<RoomController>();
    final scheme = ShadTheme.of(context).colorScheme;
    final inv = widget.invite;
    final ad = widget.ad;
    final isPrefilled = inv != null || ad != null;
    final invLabel = inv?.roomName.isNotEmpty == true
        ? inv!.roomName
        : (ad?.label ?? '');
    final invHost = inv?.hostName.isNotEmpty == true
        ? inv!.hostName
        : (ad?.hostName ?? '');

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Barra de progreso (h-1 del prototipo).
        Container(
          height: 4,
          decoration: BoxDecoration(
            color: scheme.muted,
            borderRadius: BorderRadius.circular(999),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (_step / 3).clamp(0, 1),
            child: Container(
              decoration: BoxDecoration(
                color: scheme.foreground,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Paso $_step de 3',
          style: VeText.labelCaps(
            9.5,
            color: scheme.mutedForeground,
            weight: FontWeight.w600,
          ),
        ),

        // Contexto de la invitación (QR/escáner): sala + anfitrión.
        if (isPrefilled) ...[
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(LucideIcons.qrCode, size: 14, color: scheme.foreground),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  invLabel.isNotEmpty
                      ? (invHost.isNotEmpty
                            ? 'Sala «$invLabel» de $invHost'
                            : 'Sala «$invLabel»')
                      : 'Sala avistada cerca',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: scheme.foreground,
                  ),
                ),
              ),
            ],
          ),
        ],

        // ── 1 · Conexión ──
        const _StepEyebrow('1 · Conexión', top: 16),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final m in RoomMode.values)
              VeChip(
                active: room.mode == m,
                onTap: () => context.read<RoomController>().setMode(m),
                child: Text(m.id == 'wifi' ? 'WiFi local' : m.label),
              ),
          ],
        ),

        // ── 2 · Tu nombre ──
        const _StepEyebrow('2 · Tu nombre', top: 18),
        Builder(
          builder: (context) {
            final chips = <String>{
              if (room.myName.trim().isNotEmpty) room.myName.trim(),
              'Casa',
              'Mamá',
              'Luis',
            }.toList();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final n in chips)
                      VeChip(
                        active: !_customName && _nameCtrl.text.trim() == n,
                        onTap: () {
                          setState(() {
                            _customName = false;
                            _nameCtrl.text = n;
                          });
                        },
                        child: Text(n),
                      ),
                    VeChip(
                      dashed: true,
                      active: _customName,
                      onTap: () => setState(() {
                        _customName = true;
                        _nameCtrl.clear();
                      }),
                      child: const Text('Elegir otro'),
                    ),
                  ],
                ),
                if (_customName) ...[
                  const SizedBox(height: 8),
                  VeInput(
                    controller: _nameCtrl,
                    autofocus: true,
                    placeholder: 'Tu nombre en la sala',
                    onChanged: (_) => setState(() {}),
                  ),
                ],
              ],
            );
          },
        ),

        // ── 3 · Código de la sala ──
        const _StepEyebrow('3 · Código de la sala', top: 18),
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: scheme.card,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: scheme.border),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  for (var i = 0; i < 6; i++) ...[
                    if (i > 0) const SizedBox(width: 6),
                    _LetterWheel(
                      letter: _kAlphabet[_codeIdx[i]],
                      onUp: () => _bump(i, 1),
                      onDown: () => _bump(i, -1),
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              Text.rich(
                TextSpan(
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    color: scheme.mutedForeground,
                  ),
                  children: [
                    const TextSpan(
                      text: 'Usa las flechas de cada columna para armar ',
                    ),
                    TextSpan(
                      text: _word,
                      style: TextStyle(
                        fontFamily: 'JetBrainsMono',
                        fontWeight: FontWeight.w600,
                        letterSpacing: 2,
                        color: scheme.foreground,
                      ),
                    ),
                  ],
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),

        // ── PIN de 4 emojis (si la sala lo pide) ──
        const _StepEyebrow('PIN de 4 emojis (opcional)', top: 18),
        if (!_askPin)
          Text(
            'Si el anfitrión pidió PIN, te lo pedirá al conectar.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 12.5,
              color: scheme.mutedForeground,
            ),
          )
        else ...[
          PinEmojiPad(
            entered: _pin,
            onChanged: (v) => setState(() {
              _pin = v;
              _pinError = false;
            }),
            error: _pinError,
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: VeBtn(
              variant: VeBtnVariant.ghost,
              size: VeBtnSize.sm,
              onPressed: _pin.isEmpty
                  ? null
                  : () => setState(() {
                      _askPin = false;
                      _pin = '';
                      _pinError = false;
                    }),
              child: const Text('No tengo PIN'),
            ),
          ),
        ],

        // ── Estado: conectando / error ──
        if (_connecting) ...[
          const SizedBox(height: 14),
          Row(
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
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: scheme.foreground,
                  ),
                ),
              ),
              VeBtn(
                variant: VeBtnVariant.ghost,
                size: VeBtnSize.sm,
                onPressed: () => room.leave(),
                child: const Text('Cancelar'),
              ),
            ],
          ),
        ],
        if (_busyError != null) ...[
          const SizedBox(height: 12),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                LucideIcons.circleAlert,
                size: 15,
                color: VeColors.of(context).neg,
              ),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  _busyError!,
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: VeColors.of(context).neg,
                  ),
                ),
              ),
            ],
          ),
        ],

        // ── Acción principal (pie de la hoja) ──
        const SizedBox(height: 16),
        VeBtn(
          variant: VeBtnVariant.primary,
          size: VeBtnSize.lg,
          expands: true,
          icon: LucideIcons.logIn,
          enabled: _canTry,
          onPressed: _canTry ? _connect : null,
          child: Text(
            _askPin && _pin.characters.length < kPinLength
                ? 'Marca el PIN (${_pin.characters.length}/$kPinLength)'
                : 'Unirme por ${room.modeLabel}',
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Al unirte, la lista del anfitrión reemplaza la tuya aquí.',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontFamily: 'Inter',
            fontSize: 11.5,
            color: scheme.mutedForeground,
          ),
        ),
      ],
    );
  }
}

/// Rótulo de paso (eyebrow caps con aire propio, como el prototipo).
class _StepEyebrow extends StatelessWidget {
  const _StepEyebrow(this.text, {this.top = 0});

  final String text;
  final double top;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Padding(
      padding: EdgeInsets.only(top: top, bottom: 8),
      child: Text(
        text,
        style: VeText.labelCaps(
          10.5,
          color: scheme.mutedForeground,
          weight: FontWeight.w600,
        ),
      ),
    );
  }
}

/// Columna de letra del código (JoinSheet del prototipo): botón ▲ arriba,
/// celda mono 20 px sobre bg-subtle con bordes horizontales, botón ▼ abajo.
class _LetterWheel extends StatelessWidget {
  const _LetterWheel({
    required this.letter,
    required this.onUp,
    required this.onDown,
  });

  final String letter;
  final VoidCallback onUp;
  final VoidCallback onDown;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final bool dark = ShadTheme.of(context).brightness == Brightness.dark;
    final Color lineStrong = dark
        ? VeColors.lineStrongDark
        : VeColors.lineStrongLight;

    return Container(
      width: 44,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: scheme.background,
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: lineStrong),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _wheelBtn(context, LucideIcons.chevronUp, onUp, 'Letra siguiente'),
          Container(
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: scheme.muted,
              border: Border.symmetric(
                horizontal: BorderSide(color: scheme.border),
              ),
            ),
            child: Text(
              letter,
              style: TextStyle(
                fontFamily: 'JetBrainsMono',
                fontSize: 20,
                fontWeight: FontWeight.w500,
                color: scheme.foreground,
              ),
            ),
          ),
          _wheelBtn(
            context,
            LucideIcons.chevronDown,
            onDown,
            'Letra anterior',
          ),
        ],
      ),
    );
  }

  Widget _wheelBtn(
    BuildContext context,
    IconData icon,
    VoidCallback onTap,
    String label,
  ) {
    final scheme = ShadTheme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: label,
      child: InkWell(
        onTap: onTap,
        child: SizedBox(
          width: double.infinity,
          height: 26,
          child: Icon(icon, size: 14, color: scheme.mutedForeground),
        ),
      ),
    );
  }
}
