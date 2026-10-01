/// ─── PIN de emojis (v19.8 · orden del dueño: «tipo 2FA de Google») ──────────
/// La sala puede pedir un PIN de 4 EMOJIS para unirse: no es criptografía,
/// es el candado de la puerta — evita que cualquiera que esté cerca (o que
/// aviste la sala en el escaneo) entre por error o de gratis. Los emojis se
/// dicen EN PERSONA (el anfitrión los muestra en su pantalla).
///
/// Formato: String de 4 emojis exactos, en orden: '🍏🌵⚡⭐'.
/// Viaja en el payload del `hello` y se valida contra el del anfitrión.
///
/// TASK-35 (p4): cromática «Ve» del prototipo — celdas bg-subtle con borde
/// fuerte, rejilla de 6 columnas con botones de 36 px, como el JoinSheet.
library;

import 'package:flutter/material.dart';
import 'package:shadcn_ui/shadcn_ui.dart';

import '../../core/theme.dart';
import '../../widgets/ve/ve.dart';

/// Paleta fija de 12 (los mismos para todos: reconocibles, distinguibles
/// entre sí y sin pares confusos).
const List<String> kPinEmojis = <String>[
  '🍎', // manzana roja
  '🍌', // banano
  '🌵', // cactus
  '🐳', // ballena
  '⚡', // rayo
  '🔥', // fuego
  '🌙', // luna
  '⭐', // estrella
  '🍕', // pizza
  '🎧', // audífonos
  '🚀', // cohete
  '🦋', // mariposa
];

/// Longitud del PIN (4, como los códigos de emparejamiento de Google).
const int kPinLength = 4;

/// Genera un PIN aleatorio de 4 emojis (seam inyectable para tests).
String generatePinEmoji([int Function(int max)? nextInt]) {
  final rnd =
      nextInt ?? (int max) => DateTime.now().microsecondsSinceEpoch % max;
  final pool = [...kPinEmojis];
  final out = <String>[];
  for (var i = 0; i < kPinLength; i++) {
    out.add(pool.removeAt(rnd(pool.length)));
  }
  return out.join();
}

/// ¿Es un PIN válido? (4 emojis de la paleta — copia exacta del anfitrión).
bool isValidPin(String pin) {
  final chars = pin.characters.toList();
  return chars.length == kPinLength && chars.every(kPinEmojis.contains);
}

/// Tarjeta del ANFITRIÓN: su PIN en grande + regenerar + explicación.
/// Se muestra al crear la sala con PIN y dentro de la Sala Viva.
class PinShowCard extends StatelessWidget {
  const PinShowCard({
    super.key,
    required this.pin,
    this.onRegenerate,
    this.compact = false,
  });

  final String pin;

  /// Solo en el lobby (antes de crear): cambia el PIN generado.
  final VoidCallback? onRegenerate;

  /// En Sala Viva: sin botones, solo consulta.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    return VeCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(LucideIcons.lock, size: 13, color: scheme.foreground),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  'PIN DE LA SALA',
                  style: VeText.labelCaps(
                    10.5,
                    color: scheme.mutedForeground,
                    weight: FontWeight.w600,
                  ),
                ),
              ),
              if (onRegenerate != null)
                VeBtn(
                  variant: VeBtnVariant.ghost,
                  size: VeBtnSize.sm,
                  icon: LucideIcons.dice5,
                  onPressed: onRegenerate,
                  child: const Text('Cambiar'),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (final e in pin.characters.take(kPinLength))
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: scheme.muted,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: _lineStrong(context)),
                  ),
                  alignment: Alignment.center,
                  child: Text(e, style: const TextStyle(fontSize: 24)),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            compact
                ? 'Quien quiera unirse debe marcar estos 4 emojis en este '
                      'orden. Muéstraselos en persona.'
                : 'Quien escanee el QR o tenga el código también necesitará '
                      'estos 4 emojis en este orden. Dáselos en persona a '
                      'quien invites.',
            style: TextStyle(
              fontFamily: 'Inter',
              fontSize: 11.5,
              height: 1.45,
              color: scheme.mutedForeground,
            ),
          ),
        ],
      ),
    );
  }
}

Color _lineStrong(BuildContext context) {
  final dark = ShadTheme.of(context).brightness == Brightness.dark;
  return dark ? VeColors.lineStrongDark : VeColors.lineStrongLight;
}

/// Teclado de emojis del INVITADO: marca los 4 emojis del PIN. Estilo
/// emparejamiento de Google (JoinSheet del prototipo): fichas de 44 px
/// bg-subtle + rejilla de 6 columnas con teclas de 36 px.
class PinEmojiPad extends StatelessWidget {
  const PinEmojiPad({
    super.key,
    required this.entered,
    required this.onChanged,
    this.error = false,
  });

  /// Lo marcado hasta ahora (String de emojis, crece al tocar).
  final String entered;
  final ValueChanged<String> onChanged;

  /// Rojo cuando el intento falló (se limpia al volver a tocar).
  final bool error;

  @override
  Widget build(BuildContext context) {
    final scheme = ShadTheme.of(context).colorScheme;
    final VeInk ink = Theme.of(context).extension<VeInk>()!;
    final chars = entered.characters.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fichas del progreso (4 huecos de 44 px, como el prototipo).
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < kPinLength; i++)
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: i < chars.length ? scheme.accent : scheme.muted,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: error
                        ? ink.neg
                        : (i < chars.length
                              ? _lineStrong(context)
                              : scheme.border),
                    width: error || i < chars.length ? 1.2 : 1,
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  i < chars.length ? chars[i] : '',
                  style: const TextStyle(fontSize: 22),
                ),
              ),
          ],
        ),
        const SizedBox(height: 10),
        // Teclado: 6 columnas × 2 filas (12 emojis), teclas de 36 px.
        GridView.count(
          crossAxisCount: 6,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 6,
          crossAxisSpacing: 6,
          childAspectRatio: 1.35,
          padding: EdgeInsets.zero,
          children: [
            for (final e in kPinEmojis)
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () {
                  if (chars.length >= kPinLength) return;
                  onChanged(entered + e);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.card,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: scheme.border),
                  ),
                  alignment: Alignment.center,
                  child: Text(e, style: const TextStyle(fontSize: 17)),
                ),
              ),
          ],
        ),
        // Borrar / limpiar (ghost sm a la derecha, como el prototipo).
        Align(
          alignment: Alignment.centerRight,
          child: VeBtn(
            variant: VeBtnVariant.ghost,
            size: VeBtnSize.sm,
            icon: LucideIcons.delete,
            enabled: entered.isNotEmpty,
            onPressed: entered.isEmpty
                ? null
                : () => onChanged(
                    entered.characters
                        .toList()
                        .sublist(0, chars.length - 1)
                        .join(),
                  ),
            child: const Text('Borrar'),
          ),
        ),
      ],
    );
  }
}
