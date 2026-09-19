/// ─── PIN de emojis (v19.8 · orden del dueño: «tipo 2FA de Google») ──────────
/// La sala puede pedir un PIN de 4 EMOJIS para unirse: no es criptografía,
/// es el candado de la puerta — evita que cualquiera que esté cerca (o que
/// aviste la sala en el escaneo) entre por error o de gratis. Los emojis se
/// dicen EN PERSONA (el anfitrión los muestra en su pantalla).
///
/// Formato: String de 4 emojis exactos, en orden: '🍏🌵⚡⭐'.
/// Viaja en el payload del `hello` y se valida contra el del anfitrión.
library;

import 'package:flutter/material.dart';

import '../../core/theme.dart';

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
    final scheme = Theme.of(context).colorScheme;
    return Card(
      child: Padding(
        padding: EdgeInsets.all(compact ? 14 : 14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(
                  Icons.emoji_events_outlined,
                  size: 16,
                  color: scheme.primary,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    'PIN DE LA SALA',
                    style: VeText.labelCaps(10.5, color: scheme.primary),
                  ),
                ),
                if (onRegenerate != null)
                  TextButton.icon(
                    onPressed: onRegenerate,
                    icon: const Icon(Icons.casino, size: 14),
                    label: const Text(
                      'Cambiar',
                      style: TextStyle(fontSize: 12),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final e in pin.characters.take(kPinLength))
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: scheme.outlineVariant),
                    ),
                    alignment: Alignment.center,
                    child: Text(e, style: const TextStyle(fontSize: 28)),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              compact
                  ? 'Quien quiera unirse debe marcar estos 4 emojis en este '
                        'orden. Muéstraselos en persona.'
                  : 'Quien escanee el QR o tenga el código también necesitará '
                        'estos 4 emojis en este orden. Dáselos en persona a '
                        'quien invites.',
              style: TextStyle(
                fontSize: 11.5,
                height: 1.4,
                color: scheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Teclado de emojis del INVITADO: marca los 4 emojis del PIN. Estilo
/// emparejamiento de Google: fichas grandes, orden visible, borrar y rehacer.
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
    final scheme = Theme.of(context).colorScheme;
    final sem = VeColors.of(context);
    final chars = entered.characters.toList();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Fichas del progreso (4 huecos).
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < kPinLength; i++)
              Container(
                width: 58,
                height: 58,
                decoration: BoxDecoration(
                  color: error
                      ? sem.neg.withValues(alpha: 0.10)
                      : (i < chars.length
                            ? scheme.primary.withValues(alpha: 0.08)
                            : scheme.surfaceContainerHighest),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: error
                        ? sem.neg.withValues(alpha: 0.5)
                        : (i < chars.length
                              ? scheme.primary.withValues(alpha: 0.4)
                              : scheme.outlineVariant),
                  ),
                ),
                alignment: Alignment.center,
                child: Text(
                  i < chars.length ? chars[i] : '',
                  style: const TextStyle(fontSize: 28),
                ),
              ),
          ],
        ),
        const SizedBox(height: 14),
        // Teclado: 4 columnas (12 emojis).
        GridView.count(
          crossAxisCount: 4,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 8,
          crossAxisSpacing: 8,
          childAspectRatio: 1.15,
          padding: EdgeInsets.zero,
          children: [
            for (final e in kPinEmojis)
              InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: () {
                  if (chars.length >= kPinLength) return;
                  onChanged(entered + e);
                },
                child: Container(
                  decoration: BoxDecoration(
                    color: scheme.surfaceContainerLowest,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: scheme.outlineVariant),
                  ),
                  alignment: Alignment.center,
                  child: Text(e, style: const TextStyle(fontSize: 26)),
                ),
              ),
          ],
        ),
        // Borrar / limpiar.
        Align(
          alignment: Alignment.centerRight,
          child: TextButton.icon(
            onPressed: entered.isEmpty
                ? null
                : () => onChanged(
                    entered.characters
                        .toList()
                        .sublist(0, chars.length - 1)
                        .join(),
                  ),
            icon: const Icon(Icons.backspace_outlined, size: 15),
            label: const Text('Borrar', style: TextStyle(fontSize: 12)),
          ),
        ),
      ],
    );
  }
}
