package ve.valorave.app

import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.widget.RemoteViews

/**
 * Familia de widgets de tasa (§12.2 · plan documentado: subclassing).
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
 *   widgetBcvRate · widgetBcvUpdated · widgetParallelRate · widgetGapPct.
 * Sin red en el widget: solo datos ya guardados por la app.
 *
 * Familia (misma celda 4×1, cada uno protagonista de una cifra):
 *   · BcvWidgetProvider     — tasa BCV + paralelo secundario.
 *   · ParallelWidgetProvider — paralelo protagonista + BCV secundario.
 *   · GapWidgetProvider      — brecha % protagonista + ambas tasas.
 */
abstract class BaseRatesWidget : AppWidgetProvider() {

    protected class Rates(val bcv: String, val parallel: String, val updated: String, val gap: String)

    // v19.0: Dart escribe cifras es-VE («1.234,56») — el respaldo Kotlin las
    // parsea tolerante y las vuelve a formatear con coma decimal.
    private fun parseVe(s: String?): Double? =
        s?.replace(".", "")?.replace(',', '.')?.toDoubleOrNull()

    private fun fmtVePct(v: Double): String =
        String.format("%+.1f %%", v).replace('.', ',')

    protected fun read(context: Context): Rates {
        val data = context.getSharedPreferences("HomeWidgetPreferences", Context.MODE_PRIVATE)
        val bcv = data.getString("widgetBcvRate", null) ?: "—"
        val parallel = data.getString("widgetParallelRate", null) ?: "—"
        val updated = data.getString("widgetBcvUpdated", null) ?: ""
        // Brecha recalculada del par guardado (Dart también la escribe en
        // widgetGapPct; aquí es respaldo si solo llegaron las tasas).
        val gap = data.getString("widgetGapPct", null) ?: run {
            val b = parseVe(bcv)
            val p = parseVe(parallel)
            if (b != null && p != null && b > 0) {
                fmtVePct((p / b - 1) * 100)
            } else "—"
        }
        return Rates(bcv, parallel, updated, gap)
    }

    override fun onUpdate(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetIds: IntArray,
    ) {
        val r = read(context)
        for (id in appWidgetIds) {
            appWidgetManager.updateAppWidget(id, render(context, r))
        }
    }

    /** Cada widget pinta SU layout con las mismas tasas leídas. */
    protected abstract fun render(context: Context, r: Rates): RemoteViews
}

/** Widget 4×1 «Tasa BCV»: el oficial como héroe, paralelo de secundario. */
class BcvWidgetProvider : BaseRatesWidget() {
    override fun render(context: Context, r: Rates): RemoteViews =
        RemoteViews(context.packageName, R.layout.widget_bcv).apply {
            setTextViewText(R.id.widget_rate, r.bcv)
            setTextViewText(R.id.widget_updated, r.updated)
            setTextViewText(R.id.widget_parallel, "Paralelo ${r.parallel}")
        }
}

/** Widget 4×1 «Paralelo»: el mercado como héroe, BCV de secundario. */
class ParallelWidgetProvider : BaseRatesWidget() {
    override fun render(context: Context, r: Rates): RemoteViews =
        RemoteViews(context.packageName, R.layout.widget_parallel).apply {
            setTextViewText(R.id.widget_rate, r.parallel)
            setTextViewText(R.id.widget_updated, r.updated)
            setTextViewText(R.id.widget_secondary, "BCV ${r.bcv}")
        }
}

/** Widget 4×1 «Brecha»: la distancia BCV↔paralelo como héroe (§9.7 gap). */
class GapWidgetProvider : BaseRatesWidget() {
    override fun render(context: Context, r: Rates): RemoteViews =
        RemoteViews(context.packageName, R.layout.widget_gap).apply {
            setTextViewText(R.id.widget_rate, r.gap)
            setTextViewText(R.id.widget_updated, r.updated)
            setTextViewText(R.id.widget_secondary, "BCV ${r.bcv} · Paralelo ${r.parallel}")
        }
}
