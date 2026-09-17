/// ─── Widgets de Inicio: catálogo con VISTA PREVIA y TAMAÑO (v19.4) ──────────
/// Orden del dueño: los widgets del Inicio deben poder verse ANTES de
/// añadirse, y su contenido adapta al tamaño que elija el usuario (el
/// «Widget Resizing» de Android, dentro de la app).
///
/// Piezas:
/// · [HomeWidgetSize] — compacto / normal / grande: el CONTENIDO de cada
///   widget decide qué significa cada tamaño (más o menos filas, más o
///   menos detalle). Nada de cajas vacías que estiran el aire.
/// · [HomeWidgetSpec] — un widget del catálogo: qué es, cómo se describe
///   y cómo se construye para Inicio y para la vista previa.
/// · [HomeWidgetController] — visibles + tamaños, persistidos en
///   SharedPreferences (valorave.home.*). Por defecto TODO visible y en
///   normal: quien no toca nada ve el Inicio de siempre.
/// · [showHomeWidgetCatalog] — la hoja del catálogo: cada widget con su
///   PREVIEW REAL (el mismo builder, sin interacción), selector de
///   tamaño y botón de añadir/quitar.
library;

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Tamaño elegido por el usuario para un widget de Inicio.
enum HomeWidgetSize { s, m, l }

extension HomeWidgetSizeX on HomeWidgetSize {
  /// Etiqueta corta para el selector.
  String get label => switch (this) {
    HomeWidgetSize.s => 'Compacto',
    HomeWidgetSize.m => 'Normal',
    HomeWidgetSize.l => 'Grande',
  };

  /// Icono del selector (la misma metáfora del resizing de Android).
  IconData get icon => switch (this) {
    HomeWidgetSize.s => Icons.photo_size_select_small_rounded,
    HomeWidgetSize.m => Icons.crop_square_rounded,
    HomeWidgetSize.l => Icons.photo_size_select_large_rounded,
  };
}

/// Un widget del catálogo de Inicio.
class HomeWidgetSpec {
  const HomeWidgetSpec({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.builder,
    this.sizes = const <HomeWidgetSize>[
      HomeWidgetSize.s,
      HomeWidgetSize.m,
      HomeWidgetSize.l,
    ],
  });

  /// Id estable para persistencia (no renombrar en vano).
  final String id;

  /// Nombre tal cual se muestra.
  final String title;

  /// Una línea honesta de qué muestra el widget.
  final String description;

  final IconData icon;

  /// Construye el widget (Inicio y vista previa usan EL MISMO builder:
  /// lo que ves en la hoja es lo que queda en Inicio).
  final Widget Function(BuildContext context, HomeWidgetSize size) builder;

  /// Tamaños con contenido DISTINTO. Vacío = contenido fijo (el widget
  /// no muestra el selector).
  final List<HomeWidgetSize> sizes;
}

/// Visibles y tamaños de los widgets de Inicio, persistidos en prefs.
/// Por defecto: todos visibles en tamaño normal — el Inicio de siempre.
class HomeWidgetController extends ChangeNotifier {
  HomeWidgetController(this._prefs, {required List<String> knownIds}) {
    _load(knownIds);
  }

  static const String _kVisible = 'valorave.home.widgets';
  static const String _kHidden = 'valorave.home.widgets.off';
  static const String _kSizePrefix = 'valorave.home.size.';

  final SharedPreferences _prefs;
  final Map<String, HomeWidgetSize> _sizes = <String, HomeWidgetSize>{};
  List<String> _visible = <String>[];
  List<String> _hidden = <String>[];

  List<String> get visible => List<String>.unmodifiable(_visible);

  bool isVisible(String id) => _visible.contains(id);

  HomeWidgetSize sizeOf(String id) => _sizes[id] ?? HomeWidgetSize.m;

  void _load(List<String> knownIds) {
    final stored = _prefs.getStringList(_kVisible);
    if (stored == null || stored.isEmpty) {
      // Sin preferencias guardadas (primera vez o lista vaciada a mano):
      // todo visible. Una lista vacía explícita NO se persiste como tal —
      // reiniciar con el Inicio pelado sería un susto injusto; el estado
      // vacío se vive en la sesión y se recupera al reabrir.
      // GrowABLE: setVisible muta esta lista (remove/add).
      _visible = knownIds.toList();
      return;
    }
    // Los QUITADOS por el usuario se recuerdan aparte (_kHidden): sin eso,
    // un id ausente del stored se tomaría por «nuevo de actualización» y
    // volvería a aparecer tras cada reinicio.
    final hidden = _prefs.getStringList(_kHidden) ?? const <String>[];
    _hidden = hidden.where(knownIds.contains).toList();
    // El orden guardado manda; ids NUEVOS de actualizaciones entran
    // visibles al final; ids retirados se botan.
    _visible = <String>[
      ...stored.where(knownIds.contains),
      ...knownIds.where(
        (k) => !stored.contains(k) && !_hidden.contains(k),
      ),
    ];
    for (final id in knownIds) {
      final raw = _prefs.getString('$_kSizePrefix$id');
      for (final s in HomeWidgetSize.values) {
        if (s.name == raw) _sizes[id] = s;
      }
    }
  }

  Future<void> setVisible(String id, bool shown) async {
    if (shown == isVisible(id)) return;
    if (shown) {
      _visible.add(id);
      _hidden.remove(id);
    } else {
      _visible.remove(id);
      if (!_hidden.contains(id)) _hidden.add(id);
    }
    notifyListeners();
    await _prefs.setStringList(_kVisible, _visible);
    await _prefs.setStringList(_kHidden, _hidden);
  }

  Future<void> setSize(String id, HomeWidgetSize size) async {
    if (_sizes[id] == size) return;
    _sizes[id] = size;
    notifyListeners();
    await _prefs.setString('$_kSizePrefix$id', size.name);
  }
}

/// Hoja del catálogo: cada widget con su VISTA PREVIA real, su selector
/// de tamaño (si aplica) y el botón de añadir/quitar.
Future<void> showHomeWidgetCatalog(
  BuildContext context, {
  required HomeWidgetController controller,
  required List<HomeWidgetSpec> specs,
}) {
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
      builder: (sheetCtx, scroll) => ListenableBuilder(
        // La hoja VIVE el estado: quitar/añadir y el cambio de tamaño
        // refrescan el botón y la PREVIEW al instante — lo que ves al
        // tocar un tamaño es lo que queda en Inicio.
        listenable: controller,
        builder: (context, _) => _WidgetCatalogSheet(
          controller: controller,
          specs: specs,
          scrollController: scroll,
        ),
      ),
    ),
  );
}

class _WidgetCatalogSheet extends StatelessWidget {
  const _WidgetCatalogSheet({
    required this.controller,
    required this.specs,
    required this.scrollController,
  });

  final HomeWidgetController controller;
  final List<HomeWidgetSpec> specs;
  final ScrollController scrollController;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      controller: scrollController,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      children: [
        Row(
          children: [
            Icon(Icons.widgets_outlined, size: 20, color: scheme.primary),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Widgets de Inicio',
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          'Míralos tal como quedan y decide cuáles viven en tu Inicio. '
          'El tamaño cambia cuánto muestran, no solo su marco.',
          style: TextStyle(
            fontSize: 12,
            height: 1.4,
            color: scheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 14),
        for (final spec in specs)
          _CatalogEntry(
            spec: spec,
            controller: controller,
          ),
        // Cierre explícito: cerrar por gestos está bien, pero un botón
        // claro no deja la salida al ensayo.
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

/// Una entrada del catálogo: preview + nombre + tamaños + añadir/quitar.
class _CatalogEntry extends StatelessWidget {
  const _CatalogEntry({required this.spec, required this.controller});

  final HomeWidgetSpec spec;
  final HomeWidgetController controller;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final added = controller.isVisible(spec.id);
    final size = controller.sizeOf(spec.id);
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: added
                ? scheme.primary.withValues(alpha: 0.45)
                : scheme.outlineVariant,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(spec.icon, size: 17, color: scheme.primary),
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
                  // Estado y acción en una sola pastilla.
                  SizedBox(
                    height: 34,
                    child: added
                        ? FilledButton.tonalIcon(
                            onPressed: () =>
                                controller.setVisible(spec.id, false),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
                            ),
                            icon: const Icon(Icons.check, size: 15),
                            label: const Text('En Inicio'),
                          )
                        : FilledButton.icon(
                            onPressed: () => controller.setVisible(spec.id, true),
                            style: FilledButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                              ),
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
              // Vista previa REAL: el mismo builder del Inicio, sin
              // interacción (los taps de la preview no hacen nada).
              _WidgetPreview(spec: spec, size: size),
              if (spec.sizes.isNotEmpty) ...<Widget>[
                const SizedBox(height: 10),
                Row(
                  children: [
                    Icon(
                      Icons.photo_size_select_large_outlined,
                      size: 14,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        'Tamaño del contenido',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: scheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<HomeWidgetSize>(
                    segments: [
                      for (final s in spec.sizes)
                        ButtonSegment(
                          value: s,
                          icon: Icon(s.icon, size: 15),
                          label: Text(s.label),
                        ),
                    ],
                    selected: <HomeWidgetSize>{
                      spec.sizes.contains(size) ? size : HomeWidgetSize.m,
                    },
                    onSelectionChanged: (sel) =>
                        controller.setSize(spec.id, sel.first),
                    showSelectedIcon: false,
                    style: ButtonStyle(
                      visualDensity: VisualDensity.compact,
                      textStyle: const WidgetStatePropertyAll(
                        TextStyle(fontSize: 12),
                      ),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Caja de vista previa: pinta el widget en un ancho de teléfono real
/// (360 dp) y lo escala para que quepa — lo que se ve es lo que queda.
class _WidgetPreview extends StatelessWidget {
  const _WidgetPreview({required this.spec, required this.size});

  final HomeWidgetSpec spec;
  final HomeWidgetSize size;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return SizedBox(
      height: 172,
      width: double.infinity,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Material(
          // El mismo fondo del Inicio: la preview no parece otra cosa.
          color: scheme.surfaceContainerLowest,
          child: IgnorePointer(
            child: OverflowBox(
              maxWidth: double.infinity,
              maxHeight: double.infinity,
              alignment: Alignment.topLeft,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.topLeft,
                child: SizedBox(
                  width: 360,
                  child: spec.builder(context, size),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
