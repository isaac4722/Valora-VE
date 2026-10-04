/// ─── Exportación unificada (v19.8 · orden del dueño) ────────────────────────
/// UN solo componente de compartir/descargar para TODA la app: el mismo
/// menú, los mismos modos y el mismo look en cualquier módulo. Cada pantalla
/// solo MAPEA su información (CSV, PNG o texto) a un [ExportSpec] y llama
/// [showExportSheet]; nada de menús ad-hoc por pantalla.
///
/// Diseño (dos niveles, como el share de siempre pero visible):
/// 1) La hoja lista los FORMATOS disponibles del spec (CSV · Imagen · Texto).
/// 2) Al elegir formato, segunda hoja con los MODOS: Compartir (otra app)
///    o Guardar (descargar al dispositivo).
library;

import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../core/fmt.dart' show toCSV;
import '../services/sharing.dart';
import 'ui.dart';

/// Un formato exportable del spec.
class ExportFormat {
  const ExportFormat({
    required this.icon,
    required this.label,
    required this.hint,
    required this.run,
  });

  final IconData icon;

  /// Nombre corto del formato: «CSV», «Imagen PNG», «Texto»…
  final String label;

  /// Una línea de qué contiene: «La brecha diaria del rango».
  final String hint;

  /// Ejecuta la exportación. [share]=true comparte con otra app;
  /// false guarda/descarga. Devuelve el mensaje del SnackBar (null=silencio).
  final Future<String?> Function(bool share) run;
}

/// Especificación de lo exportable de una pantalla.
class ExportSpec {
  const ExportSpec({
    required this.title,
    required this.subtitle,
    required this.formats,
  });

  /// Título de la hoja: «Brecha BCV ↔ Paralelo».
  final String title;

  /// Contexto corto: «1 M · 30 días con datos».
  final String subtitle;

  /// Formatos disponibles.
  final List<ExportFormat> formats;
}

/// Fuentes comunes → formato listo para el spec.

/// CSV de filas (delimitador es-VE: «;»).
ExportFormat csvFormat({
  required String hint,
  required String fileName,
  required List<List<String>> Function() rows,
}) {
  return ExportFormat(
    icon: Icons.table_view,
    label: 'CSV',
    hint: hint,
    run: (share) async {
      final text = toCSV(rows(), delimiter: ';');
      if (share) {
        await shareFile(fileName, text);
        return 'CSV compartido';
      }
      final path = await downloadText(text, fileName: fileName);
      return path == null ? 'No se pudo guardar el CSV.' : 'Guardado en: $path';
    },
  );
}

/// PNG renderizado fuera de pantalla (documento propio del módulo).
ExportFormat pngFormat({
  required String hint,
  required String fileName,
  required Future<Uint8List?> Function() build,
}) {
  return ExportFormat(
    icon: Icons.image_outlined,
    label: 'Imagen PNG',
    hint: hint,
    run: (share) async {
      final bytes = await build();
      if (bytes == null) return 'No pude generar la imagen.';
      if (share) {
        await sharePng(bytes, fileName);
        return null;
      }
      final path = await downloadBytes(bytes, fileName: fileName);
      return path == null
          ? 'No se pudo guardar la imagen.'
          : 'Guardado en: $path';
    },
  );
}

/// Texto plano compartible (resúmenes, enlaces, respaldos legibles).
ExportFormat textFormat({
  required String hint,
  required String fileName,
  required String Function() text,
}) {
  return ExportFormat(
    icon: Icons.notes,
    label: 'Texto',
    hint: hint,
    run: (share) async {
      final t = text();
      if (share) {
        await shareFile(fileName, t);
        return 'Texto compartido';
      }
      final path = await downloadText(t, fileName: fileName);
      return path == null ? 'No se pudo guardar.' : 'Guardado en: $path';
    },
  );
}

/// Abre el menú UNIFICADO de exportación: formatos → (compartir|guardar).
Future<void> showExportSheet(BuildContext context, ExportSpec spec) async {
  final fmt = await showModalBottomSheet<ExportFormat>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              spec.title,
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 4),
            Text(
              spec.subtitle,
              style: TextStyle(
                fontSize: 12,
                color: Theme.of(ctx).colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 10),
            for (final f in spec.formats)
              ListTile(
                contentPadding: EdgeInsets.zero,
                dense: true,
                leading: Icon(f.icon, size: 22),
                title: Text(
                  f.label,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                subtitle: Text(f.hint, style: const TextStyle(fontSize: 11.5)),
                onTap: () => Navigator.pop(ctx, f),
              ),
          ],
        ),
      ),
    ),
  );
  if (fmt == null || !context.mounted) return;

  // Modo: compartir (otra app) o guardar (descarga).
  final share = await showModalBottomSheet<bool>(
    context: context,
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${spec.title} · ${fmt.label}',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 10),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.ios_share, size: 22),
              title: const Text(
                'Compartir',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Con otra app (WhatsApp, Telegram, correo…)',
                style: TextStyle(fontSize: 11.5),
              ),
              onTap: () => Navigator.pop(ctx, true),
            ),
            ListTile(
              contentPadding: EdgeInsets.zero,
              dense: true,
              leading: const Icon(Icons.download, size: 22),
              title: const Text(
                'Guardar en el dispositivo',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700),
              ),
              subtitle: const Text(
                'Descargar el archivo sin abrir otra app',
                style: TextStyle(fontSize: 11.5),
              ),
              onTap: () => Navigator.pop(ctx, false),
            ),
          ],
        ),
      ),
    ),
  );
  if (share == null || !context.mounted) return;

  final msg = await fmt.run(share);
  if (msg != null && context.mounted) {
    showToast(context, msg);
  }
}
