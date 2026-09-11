/// ─── Menú propio de compartir/guardar (v17.2, decisión del dueño) ───────────
/// NUNCA se lanza el share nativo de Android directo con un PNG/PDF: primero
/// aparece ESTE menú preguntando «cómo» (texto · imagen · PDF) y en cada
/// formato si se quiere compartir o descargar (guardar sin compartir).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../services/sharing.dart';

/// Opción del menú: formato + modo. [onRun] ejecuta la acción y devuelve un
/// mensaje de resultado (null = silencio, éxito sin detalle).
class ShareMenuAction {
  const ShareMenuAction({
    required this.icon,
    required this.label,
    required this.hint,
    required this.onRun,
  });

  final IconData icon;
  final String label;
  final String hint;

  /// Devuelve el texto para el SnackBar (o null para no mostrar nada).
  final Future<String?> Function() onRun;
}

/// Abre el menú y ejecuta la opción elegida mostrando el resultado.
Future<void> showShareMenu(
  BuildContext context, {
  required String title,
  required List<ShareMenuAction> actions,
}) async {
  final picked = await showModalBottomSheet<ShareMenuAction>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          const SizedBox(height: 4),
          const Text('Elige cómo quieres salir de ValoraVE',
              style: TextStyle(fontSize: 12, color: Colors.black54)),
          const SizedBox(height: 10),
          for (final a in actions)
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: Icon(a.icon, size: 22),
              title: Text(a.label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w700)),
              subtitle: Text(a.hint, style: const TextStyle(fontSize: 11.5)),
              onTap: () => Navigator.pop(ctx, a),
            ),
        ]),
      ),
    ),
  );
  if (picked == null || !context.mounted) return;
  final messenger = ScaffoldMessenger.of(context);
  final msg = await picked.onRun();
  if (msg != null) {
    messenger.showSnackBar(SnackBar(content: Text(msg), behavior: SnackBarBehavior.floating));
  }
}

/// Atajos comunes de ejecución (compartir / descargar).
Future<String?> runSharePng(Uint8List bytes, String name) async {
  await sharePng(bytes, name);
  return null;
}

Future<String?> runDownloadBytes(Uint8List bytes, String name) async {
  final path = await downloadBytes(bytes, fileName: name);
  return path == null ? 'No se pudo guardar el archivo.' : 'Guardado en: $path';
}
