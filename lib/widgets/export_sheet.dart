/// ─── Exportación unificada (v19.8 · regla de envío v28 del dueño) ───────────
/// UN solo componente de salida para TODA la app: el mismo menú, los mismos
/// modos y el mismo look en cualquier módulo. Cada pantalla solo MAPEA su
/// información (CSV, PNG, PDF o texto) a un [ExportFormat] y llama
/// [showExportSheet]; nada de menús ad-hoc por pantalla.
///
/// REGLA DE ENVÍO (v28 · orden del dueño): solo existen DOS formas de enviar
/// información —
/// · COMPARTIR: exclusivo de ARCHIVOS (PNG/JPEG/PDF). Nunca abre el share
///   nativo con texto, así el menú del sistema no ofrece «enviar texto».
/// · COPIAR: todo TEXTO (CSV, JSON, resúmenes) va al portapapeles.
/// El texto jamás abre el share nativo; «Guardar» sigue disponible para todo.
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../core/fmt.dart' show toCSV;
import '../services/sharing.dart';
import 'ui.dart';

/// Tipo de formato: define las salidas posibles (v28).
enum ExportKind {
  /// Binario compartible (PNG, JPEG, PDF): Compartir · Guardar.
  archivo,

  /// Texto (CSV, JSON, resúmenes): Copiar · Guardar.
  texto,
}

/// Modo de salida elegido en la segunda hoja.
enum ExportMode { compartir, copiar, guardar }

/// Copia [text] al portapapeles y devuelve el aviso para el toast (v28).
/// Para flujos SIN contexto (la hoja ejecuta fuera del árbol).
Future<String> copiarTexto(String text, String aviso) async {
  await Clipboard.setData(ClipboardData(text: text));
  return aviso;
}

/// Un formato exportable del spec.
class ExportFormat {
  const ExportFormat({
    required this.icon,
    required this.label,
    required this.hint,
    required this.kind,
    required this.run,
  });

  final IconData icon;

  /// Nombre corto del formato: «CSV», «Imagen PNG», «PDF», «Texto»…
  final String label;

  /// Una línea de qué contiene: «La brecha diaria del rango».
  final String hint;

  /// Salidas posibles según el tipo (v28: texto no se comparte).
  final ExportKind kind;

  /// Ejecuta la exportación. Devuelve el mensaje del SnackBar (null=silencio).
  final Future<String?> Function(ExportMode mode) run;
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

/// CSV de filas (delimitador es-VE: «;») — TEXTO: se copia o se guarda.
ExportFormat csvFormat({
  required String hint,
  required String fileName,
  required List<List<String>> Function() rows,
}) {
  return ExportFormat(
    icon: Icons.table_view,
    label: 'CSV',
    hint: hint,
    kind: ExportKind.texto,
    run: (mode) async {
      final text = toCSV(rows(), delimiter: ';');
      if (mode == ExportMode.guardar) {
        final path = await downloadText(text, fileName: fileName);
        return path == null
            ? 'No se pudo guardar el CSV.'
            : 'Guardado en: $path';
      }
      return copiarTexto(text, 'CSV copiado');
    },
  );
}

/// PNG renderizado fuera de pantalla — ARCHIVO: se comparte o se guarda.
ExportFormat pngFormat({
  required String hint,
  required String fileName,
  required Future<Uint8List?> Function() build,
}) {
  return ExportFormat(
    icon: Icons.image_outlined,
    label: 'Imagen PNG',
    hint: hint,
    kind: ExportKind.archivo,
    run: (mode) async {
      final bytes = await build();
      if (bytes == null) return 'No pude generar la imagen.';
      if (mode == ExportMode.compartir) {
        // Solo el archivo viaja al share nativo: sin texto, el menú del
        // sistema nunca ofrece «enviar texto» (regla v28).
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

/// PDF (v31) — ARCHIVO: se comparte o se guarda, igual que el PNG pero con
/// su MIME de documento (el receptor abre un PDF, no una imagen). La
/// generación [build] devuelve bytes o null: ante fallo el mensaje es
/// humano («No pude generar el PDF»), jamás una excepción sin tratar.
ExportFormat pdfFormat({
  required String hint,
  required String fileName,
  required Future<Uint8List?> Function() build,
}) {
  return ExportFormat(
    icon: Icons.picture_as_pdf_outlined,
    label: 'PDF',
    hint: hint,
    kind: ExportKind.archivo,
    run: (mode) async {
      Uint8List? bytes;
      try {
        bytes = await build();
      } catch (_) {
        bytes = null; // la generación de un documento jamás tumba la app
      }
      if (bytes == null || bytes.isEmpty) {
        return 'No pude generar el PDF. Intenta de nuevo.';
      }
      if (mode == ExportMode.compartir) {
        await sharePdf(bytes, fileName);
        return null;
      }
      final path = await downloadBytes(bytes, fileName: fileName);
      return path == null
          ? 'No se pudo guardar el PDF.'
          : 'Guardado en: $path';
    },
  );
}

/// Texto plano (resúmenes, enlaces, respaldos legibles) — TEXTO: copiar/guardar.
ExportFormat textFormat({
  required String hint,
  required String fileName,
  required String Function() text,
}) {
  return ExportFormat(
    icon: Icons.notes,
    label: 'Texto',
    hint: hint,
    kind: ExportKind.texto,
    run: (mode) async {
      final t = text();
      if (mode == ExportMode.guardar) {
        final path = await downloadText(t, fileName: fileName);
        return path == null ? 'No se pudo guardar.' : 'Guardado en: $path';
      }
      return copiarTexto(t, 'Texto copiado');
    },
  );
}

/// Abre el menú UNIFICADO de exportación: formatos → salidas del tipo (v28:
/// archivo → Compartir/Guardar · texto → Copiar/Guardar).
Future<void> showExportSheet(BuildContext context, ExportSpec spec) async {
  // v23.3 (pez 2-a P0-1): chrome unificado del kit (showVeHalfSheet —
  // radio 14, asa, cabecera 48 + ✕).
  final fmt = await showVeHalfSheet<ExportFormat>(
    context: context,
    title: spec.title,
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          spec.subtitle,
          style: TextStyle(
            fontSize: 13.5,
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
                fontSize: 17,
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Text(f.hint, style: const TextStyle(fontSize: 11)),
            onTap: () => Navigator.pop(ctx, f),
          ),
      ],
    ),
  );
  if (fmt == null || !context.mounted) return;

  // Salidas según el TIPO (v28): el texto jamás se comparte, el archivo
  // jamás se copia como texto.
  final (icono, titulo, subtitulo, modo) = fmt.kind == ExportKind.archivo
      ? (
          Icons.ios_share,
          'Compartir',
          'Con otra app (WhatsApp, Telegram, correo…) — solo el archivo',
          ExportMode.compartir,
        )
      : (
          Icons.copy_rounded,
          'Copiar',
          'Al portapapeles, listo para pegar donde quieras',
          ExportMode.copiar,
        );
  final chosen = await showVeHalfSheet<ExportMode>(
    context: context,
    title: '${spec.title} · ${fmt.label}',
    builder: (ctx) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: Icon(icono, size: 22),
          title: Text(
            titulo,
            style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          subtitle: Text(subtitulo, style: const TextStyle(fontSize: 11)),
          onTap: () => Navigator.pop(ctx, modo),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          dense: true,
          leading: const Icon(Icons.download, size: 22),
          title: const Text(
            'Guardar en el dispositivo',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
          ),
          subtitle: const Text(
            'Descargar el archivo sin abrir otra app',
            style: TextStyle(fontSize: 11),
          ),
          onTap: () => Navigator.pop(ctx, ExportMode.guardar),
        ),
      ],
    ),
  );
  if (chosen == null || !context.mounted) return;

  // v31: la ejecución también se protege — si el share nativo o el guardado
  // fallan (sin manejador de compartir, almacenamiento caído…), el usuario
  // recibe un aviso humano en vez de un error sin tratar.
  String? msg;
  try {
    msg = await fmt.run(chosen);
  } catch (_) {
    msg = 'No se pudo completar la exportación. Intenta de nuevo.';
  }
  if (msg != null && context.mounted) {
    showToast(context, msg);
  }
}
