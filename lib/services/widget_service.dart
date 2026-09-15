/// ─── Widgets de escritorio (home_widget) + shortcuts ────────────────────────
/// Familia de widgets 4×1 (§12.2 · subclassing en Kotlin): Tasa BCV ·
/// Paralelo · Brecha — los tres leen las mismas claves que esta servicio
/// escribe tras cada fetchBoard OK. Los 4 shortcuts (Lista · Conversor ·
/// Escanear · Tasa BCV) viven en quick_actions nativo de Flutter 3.47
/// (androidx shortcuts) — aquí se mapean las acciones.
library;

import 'package:home_widget/home_widget.dart';

import '../core/fmt.dart';

const _kAndroidGroup = 'valorave_widgets';

class WidgetService {
  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_kAndroidGroup);
  }

  /// Escribe tasas + brecha a la familia de widgets (llamar tras cada
  /// fetchBoard OK). Degradación honesta: si el canal no está disponible
  /// (host de prueba, OEM capado), el widget se salta — jamás produce
  /// errores async no manejados ni afecta al flujo del tablero.
  static Future<void> updateBcv({
    required double? bcv,
    required double? parallel,
  }) async {
    if (bcv == null || bcv <= 0) return;
    try {
      final now = DateTime.now();
      // v19.0: el widget también habla es-VE («832,49») — mismo formato que
      // toda la app, punto de miles y coma decimal.
      await HomeWidget.saveWidgetData<String>('widgetBcvRate', fmtNum(bcv, decimals: 2));
      await HomeWidget.saveWidgetData<String>(
          'widgetParallelRate', parallel == null ? '—' : fmtNum(parallel, decimals: 2));
      await HomeWidget.saveWidgetData<String>(
          'widgetBcvUpdated', '${now.hour}:${now.minute.toString().padLeft(2, '0')}');
      // Brecha para el widget «Brecha» (respaldo recalculado también en Kotlin).
      final gap = (parallel != null && parallel > 0)
          ? fmtPct((parallel / bcv - 1) * 100)
          : '—';
      await HomeWidget.saveWidgetData<String>('widgetGapPct', gap);
      // La familia completa se refresca con las mismas claves.
      for (final name in const [
        'BcvWidgetProvider',
        'ParallelWidgetProvider',
        'GapWidgetProvider',
      ]) {
        await HomeWidget.updateWidget(name: name, androidName: name);
      }
    } catch (_) {
      // Sin canal home_widget: los widgets de escritorio simplemente no se
      // actualizan; la app sigue normal.
    }
  }
}
