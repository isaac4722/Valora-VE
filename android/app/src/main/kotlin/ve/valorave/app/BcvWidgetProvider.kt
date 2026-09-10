package ve.valorave.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews
import es.antonioheres.home_widget.HomeWidgetPlugin
import ve.valorave.app.R

/**
 * Widget 4×1 «Tasa BCV» (§12.2 · 13 widgets base, cierre con este + panel).
 * Los valores los escribe la app Flutter vía home_widget (widget_service.dart)
 * en el grupo «valorave_widgets»: widgetBcvRate · widgetBcvUpdated ·
 * widgetParallelRate. Sin red en el widget: solo datos ya guardados.
 */
class BcvWidgetProvider : AppWidgetProvider() {
    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val data = HomeWidgetPlugin.getData(context)
        val rate = data.getString("widgetBcvRate", "—")
        val updated = data.getString("widgetBcvUpdated", "")
        val parallel = data.getString("widgetParallelRate", "—")

        for (id in appWidgetIds) {
            val views = RemoteViews(context.packageName, R.layout.widget_bcv).apply {
                setTextViewText(R.id.widget_rate, rate)
                setTextViewText(R.id.widget_updated, updated ?: "")
                setTextViewText(R.id.widget_parallel, "Paralelo $parallel")
            }
            appWidgetManager.updateAppWidget(id, views)
        }
    }
}
