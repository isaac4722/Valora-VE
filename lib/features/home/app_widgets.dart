/// ─── App Widgets: los de la PANTALLA DE INICIO de Android (v19.6) ─────────
/// Orden del dueño: los widgets configurables DENTRO de la app («Widgets
/// de Inicio» v19.4) se retiran. El «+» del Inicio queda como puerta a los
/// App Widgets de verdad — los que viven en el launcher de Android (la
/// familia Tasa BCV · Paralelo · Brecha que el sistema lista en su
/// selector de widgets):
///
/// · PREVIEW fiel antes de añadir: se pinta aquí con el MISMO diseño del
///   widget nativo (título · cifra héroe · secundario · hora) y las tasas
///   vivas del tablero — lo que ves es lo que queda en el launcher.
///   Diseño adaptado de las tarjetas de referencia del dueño (fondo
///   #121417, borde #3A4048, esquinas 18).
/// · AÑADIR en un toque: Android 8+ pide el pin al launcher
///   (requestPinAppWidget por el canal «valorave/widgets»); si el
///   launcher no lo soporta, sale la guía manual de 3 pasos.
/// · TAMAÑO: en el launcher se estiran de ~2×1 a 4×2 y el contenido se
///   recompone solo (COMPACT · NORMAL · BIG — BcvWidgetProvider).
library;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../core/fmt.dart';
import '../../data/store.dart';

/// Canal nativo de App Widgets (MainActivity.kt · pin en el launcher).
const MethodChannel _kPinChannel = MethodChannel('valorave/widgets');

/// Un widget de la familia nativa, tal como lo muestra esta galería.
class _AppWidgetSpec {
  const _AppWidgetSpec({
    required this.provider,
    required this.title,
    required this.description,
    required this.badge,
    required this.hero,
    required this.secondary,
  });

  /// Clase Kotlin del proveedor (destino del pin).
  final String provider;

  /// Nombre tal cual el launcher lo lista (AndroidManifest).
  final String title;

  final String description;

  /// Título del diseño del widget («BCV · USD» …).
  final String badge;

  /// Cifra protagonista — la MISMA que el widget nativo muestra.
  final String hero;

  /// Línea secundaria del widget nativo.
  final String secondary;
}

/// Hoja de la galería de App Widgets (v19.6). El «+» del Inicio abre
/// esta puerta; nada de esto se configura DENTRO de la app.
Future<void> showAppWidgetGallery(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (ctx) => DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      maxChildSize: 0.95,
      builder: (sheetCtx, scroll) => _AppWidgetsSheet(scrollController: scroll),
    ),
  );
}

class _AppWidgetsSheet extends StatelessWidget {
  const _AppWidgetsSheet({required this.scrollController});

  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final store = context.watch<AppStore>();

    // Tasas vivas del tablero — la preview muestra lo que el widget va a
    // pintar; sin datos, guiones honestos (igual que el widget nativo).
    final bcv = store.board.sources['ves-bcv']?.rate;
    final parallel = store.board.sources['ves-parallel']?.rate;
    final fetched = store.board.fetchedAt;
    final hora = fetched == null
        ? ''
        : '${fetched.hour}:${fetched.minute.toString().padLeft(2, '0')}';
    String fmt(double? v) =>
        (v == null || v <= 0) ? '—' : fmtNum(v, decimals: 2);
    final gap = (bcv != null && bcv > 0 && parallel != null && parallel > 0)
        ? fmtPct((parallel / bcv - 1) * 100, forceSign: true)
        : '—';

    final specs = <_AppWidgetSpec>[
      _AppWidgetSpec(
        provider: 'BcvWidgetProvider',
        title: 'Tasa BCV',
        description: 'El dólar oficial, con el paralelo al lado.',
        badge: 'BCV · USD',
        hero: fmt(bcv),
        secondary: 'Paralelo ${fmt(parallel)}',
      ),
      _AppWidgetSpec(
        provider: 'ParallelWidgetProvider',
        title: 'Paralelo',
        description: 'El dólar paralelo, con el BCV al lado.',
        badge: 'PARALELO · USD',
        hero: fmt(parallel),
        secondary: 'BCV ${fmt(bcv)}',
      ),
      _AppWidgetSpec(
        provider: 'GapWidgetProvider',
        title: 'Brecha',
        description: 'Cuánto separa al oficial del paralelo, en %.',
        badge: 'BRECHA BCV ↔ PARALELO',
        hero: gap,
        secondary: 'BCV ${fmt(bcv)} · Paralelo ${fmt(parallel)}',
      ),
    ];

    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Icon(
              Icons.add_to_home_screen_outlined,
              size: 20,
              color: scheme.primary,
            ),
            const SizedBox(width: 8),
            const Expanded(
              child: Text(
                'App Widgets',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Los widgets de ValoraVE viven en tu pantalla de inicio de '
          'Android, no aquí adentro. Míralos tal como quedan y añádelos '
          'en un toque.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        for (final spec in specs) _GalleryEntry(spec: spec, hora: hora),
        // El tamaño se cambia en el launcher, no en la app.
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              Icons.photo_size_select_large_outlined,
              size: 15,
              color: scheme.onSurfaceVariant,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Se estiran: mantén presionado el widget en tu pantalla '
                'de inicio y arrastra el marco — de 2×1 a 4×2, y el '
                'contenido se recompone solo.',
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.4,
                  color: scheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
        // Cierre explícito: la salida clara no deja la hoja al ensayo.
        const SizedBox(height: 14),
        SizedBox(
          width: double.infinity,
          child: FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.check_rounded, size: 17),
            label: const Text('Listo'),
          ),
        ),
      ],
    );
  }
}

/// Una entrada de la galería: título + botón de añadir, descripción y
/// la preview fiel del widget (diseño del nativo, cifras del tablero).
class _GalleryEntry extends StatelessWidget {
  const _GalleryEntry({required this.spec, required this.hora});

  final _AppWidgetSpec spec;
  final String hora;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.outlineVariant),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  _entryIcon(context, spec.title),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      spec.title,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ),
                  SizedBox(
                    height: 34,
                    child: FilledButton.icon(
                      onPressed: () => _pinToHome(context, spec.provider),
                      style: FilledButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                      ),
                      icon: const Icon(Icons.add, size: 16),
                      label: const Text('Añadir'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                spec.description,
                style: TextStyle(
                  fontSize: 11.5,
                  height: 1.35,
                  color: scheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 10),
              _AppWidgetPreview(
                badge: spec.badge,
                hero: spec.hero,
                secondary: spec.secondary,
                hora: hora,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Icono por widget: banco para el oficial, mercado para el paralelo,
  /// flechas encontradas para la brecha.
  Widget _entryIcon(BuildContext context, String title) {
    final IconData icon = switch (title) {
      'Paralelo' => Icons.storefront_outlined,
      'Brecha' => Icons.compare_arrows_rounded,
      _ => Icons.account_balance_rounded,
    };
    return Icon(icon, size: 17, color: Theme.of(context).colorScheme.primary);
  }
}

/// Preview fiel del widget nativo (bucket NORMAL del BcvWidgetProvider):
/// mismo fondo, borde, radios, colores y jerarquía de los layouts en
/// res/layout/widget_*.xml — lo que se ve aquí es lo que queda allá.
class _AppWidgetPreview extends StatelessWidget {
  const _AppWidgetPreview({
    required this.badge,
    required this.hero,
    required this.secondary,
    required this.hora,
  });

  final String badge;
  final String hero;
  final String secondary;
  final String hora;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF121417),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFF3A4048)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  badge,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: Color(0xFF8FA7C4),
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    // ≈ letterSpacing 0.1 del layout nativo.
                    letterSpacing: 1.1,
                  ),
                ),
              ),
              Text(
                hora,
                style: const TextStyle(color: Color(0xFF5F6672), fontSize: 10),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            hero,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(
              color: Color(0xFFECEEF1),
              fontSize: 30,
              fontWeight: FontWeight.w700,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            secondary,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Color(0xFF9AA1AB), fontSize: 11),
          ),
        ],
      ),
    );
  }
}

/// Pide al launcher fijar el widget (Android 8+). El launcher muestra SU
/// propio diálogo de confirmación — aquí solo se avisa. Si la vía no
/// existe (launcher sin soporte, Android viejo, canal caído), la guía
/// manual con los pasos del sistema.
Future<void> _pinToHome(BuildContext context, String provider) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await _kPinChannel.invokeMethod<bool>('pinWidget', {'provider': provider});
    messenger?.showSnackBar(
      const SnackBar(
        content: Text(
          'Mira tu pantalla de inicio: el launcher pide confirmar el widget.',
        ),
      ),
    );
  } on MissingPluginException {
    // La hoja pudo cerrarse mientras el canal contestaba: solo con la
    // pantalla viva se abre la guía.
    if (context.mounted) _showManualSteps(context);
  } on PlatformException {
    if (context.mounted) _showManualSteps(context);
  }
}

/// Guía manual (launcher sin requestPinAppWidget): los pasos clásicos
/// de Android, sin inventar menús.
Future<void> _showManualSteps(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: const Text('Añadir a mano'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tu pantalla de inicio no deja añadir widgets desde la app. '
            'Los pasos de siempre:',
          ),
          SizedBox(height: 12),
          Text(
            '1. Mantén presionado un espacio vacío de tu pantalla de '
            'inicio.',
          ),
          SizedBox(height: 6),
          Text('2. Toca «Widgets».'),
          SizedBox(height: 6),
          Text('3. Busca ValoraVE y elige Tasa BCV, Paralelo o Brecha.'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(ctx).pop(),
          child: const Text('Listo'),
        ),
      ],
    ),
  );
}
