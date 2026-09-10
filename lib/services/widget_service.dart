/// ─── Widgets de escritorio (home_widget) + shortcuts ────────────────────────
/// Widget BCV 4×1: escribe la última tasa del tablero en el grupo
/// «valorave_widgets» cada vez que el tablero se actualiza. Los 4 shortcuts
/// (Lista · Conversor · Escanear · Tasa BCV) viven en quick_actions nativo
/// de Flutter 3.47 (androidx shortcuts) — aquí se mapean las acciones.
library;

import 'package:home_widget/home_widget.dart';

const _kAndroidGroup = 'valorave_widgets';

class WidgetService {
  static Future<void> init() async {
    await HomeWidget.setAppGroupId(_kAndroidGroup);
  }

  /// Escribe tasas al widget (llamar tras cada fetchBoard OK).
  /// Degradación honesta: si el canal no está disponible (host de prueba,
  /// OEM capado), el widget se salta — jamás produce errores async no
  /// manejados ni afecta al flujo del tablero.
  static Future<void> updateBcv({
    required double? bcv,
    required double? parallel,
  }) async {
    if (bcv == null || bcv <= 0) return;
    try {
      final now = DateTime.now();
      await HomeWidget.saveWidgetData<String>('widgetBcvRate', bcv.toStringAsFixed(2));
      await HomeWidget.saveWidgetData<String>(
          'widgetParallelRate', parallel == null ? '—' : parallel.toStringAsFixed(2));
      await HomeWidget.saveWidgetData<String>(
          'widgetBcvUpdated', '${now.hour}:${now.minute.toString().padLeft(2, '0')}');
      await HomeWidget.updateWidget(name: 'BcvWidgetProvider', androidName: 'BcvWidgetProvider');
    } catch (_) {
      // Sin canal home_widget: el widget de escritorio simplemente no se
      // actualiza; la app sigue normal.
    }
  }
}
