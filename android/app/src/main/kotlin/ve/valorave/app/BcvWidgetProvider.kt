package ve.valorave.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/**
 * Widget 4×1 «Tasa BCV» (§12.2 · 13 widgets base, cierre con este + panel).
 *
 * Los valores los escribe la app Flutter vía home_widget (widget_service.dart).
 * home_widget guarda en el archivo de SharedPreferences «HomeWidgetPreferences»
 * — HomeWidgetPlugin.getData(context) es, textualmente, getSharedPreferences de
 * ese nombre — así que aquí lo leemos DIRECTAMENTE en vez de importar la clase
 * del plugin: el plugin vive en otro módulo y su paquete no es visible en
 * compile time (falló :app:compileReleaseKotlin por eso). Mismo mecanismo,
 * cero acoplamiento.
 *
 * Claves (String crudo, putString en saveWidgetData):
 *   widgetBcvRate · widgetBcvUpdated · widgetParallelRate.
 * Sin red en el widget: solo datos ya guardados por la app.
 */
class BcvWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        // Mismo mecanismo de home_widget (nombre de archivo exacto del plugin).
        val data = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val rate = data.getString("widgetBcvRate", null) ?: "—"
        val updated = data.getString("widgetBcvUpdated", null) ?: ""
        val parallel = data.getString("widgetParallelRate", null) ?: "—"

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_bcv).apply {
                setTextViewText(R.id.widget_rate, rate)
                setTextViewText(R.id.widget_updated, updated)
                setTextViewText(R.id.widget_parallel, "Paralelo $parallel")
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
