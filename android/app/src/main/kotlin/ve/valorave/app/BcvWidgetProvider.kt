package ve.valorave.app

import android.app.PendingIntent
import android.appwidget.AppWidgetManager
import android.appwidget.AppWidgetProvider
import android.content.Context
import android.content.Intent
import android.os.Bundle
import android.util.TypedValue
import android.view.View
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
 *
 * v19.5 — tamaño modificable con contenido adaptativo: al redimensionar,
 * onAppWidgetOptionsChanged re-renderiza con el bucket que cabe en el
 * espacio garantizado (COMPACT = solo la cifra; NORMAL = diseño completo;
 * BIG = cifras más grandes para 4×2). Patrón de la doc oficial «Provide
 * flexible widget layouts» con las OPTION_APPWIDGET_MIN_*.
 */
abstract class BaseRatesWidget : AppWidgetProvider() {

    protected class Rates(val bcv: String, val parallel: String, val updated: String, val gap: String)

    /** Bucket de tamaño: qué contenido cabe sin recortes. */
    protected enum class Bucket { COMPACT, NORMAL, BIG }

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
        for (id in appWidgetIds) {
            updateOne(context, appWidgetManager, id)
        }
    }

    /** El usuario soltó el marco de resize → re-render con el bucket nuevo. */
    override fun onAppWidgetOptionsChanged(
        context: Context,
        appWidgetManager: AppWidgetManager,
        appWidgetId: Int,
        newOptions: Bundle?,
    ) {
        updateOne(context, appWidgetManager, appWidgetId)
    }

    private fun updateOne(context: Context, manager: AppWidgetManager, id: Int) {
        val options = manager.getAppWidgetOptions(id) ?: Bundle()
        manager.updateAppWidget(id, render(context, read(context), bucketOf(options)))
    }

    /**
     * Bucket por el espacio GARANTIZADO en retrato: MIN_WIDTH × MIN_HEIGHT.
     * COMPACT hasta ~2 celdas de ancho o una celda baja (el diseño completo
     * necesita ~90 dp de alto); BIG a partir del 4×2 completo.
     */
    private fun bucketOf(o: Bundle): Bucket {
        val w = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_WIDTH, 0)
        val h = o.getInt(AppWidgetManager.OPTION_APPWIDGET_MIN_HEIGHT, 0)
        if ((w in 1..140) || (h in 1..80)) return Bucket.COMPACT
        if (w >= 250 && h >= 120) return Bucket.BIG
        return Bucket.NORMAL
    }

    /** Tocar el widget abre la app (FLAG_IMMUTABLE: targetSdk 31+ lo exige). */
    protected fun openAppOnClick(context: Context, rv: RemoteViews) {
        val intent = context.packageManager.getLaunchIntentForPackage(context.packageName) ?: return
        val pi = PendingIntent.getActivity(
            context,
            0,
            intent,
            PendingIntent.FLAG_UPDATE_CURRENT or PendingIntent.FLAG_IMMUTABLE,
        )
        rv.setOnClickPendingIntent(R.id.widget_root, pi)
    }

    /**
     * Contenido adaptativo: en COMPACT sobrevive solo la cifra; en BIG todo
     * crece. setTextViewTextSize llega desde API 16 y setViewVisibility desde
     * el principio — el mínimo del repo (21) cubre ambas.
     */
    protected fun applyBucket(
        rv: RemoteViews,
        b: Bucket,
        secondaryId: Int,
        updatedId: Int = R.id.widget_updated,
    ) {
        val meta = if (b == Bucket.COMPACT) View.GONE else View.VISIBLE
        rv.setViewVisibility(R.id.widget_title, meta)
        rv.setViewVisibility(R.id.widget_meta, meta)
        when (b) {
            Bucket.COMPACT -> {
                rv.setTextViewTextSize(R.id.widget_rate, TypedValue.COMPLEX_UNIT_SP, 18f)
            }
            Bucket.NORMAL -> {
                rv.setTextViewTextSize(R.id.widget_rate, TypedValue.COMPLEX_UNIT_SP, 30f)
                rv.setTextViewTextSize(R.id.widget_title, TypedValue.COMPLEX_UNIT_SP, 11f)
                rv.setTextViewTextSize(secondaryId, TypedValue.COMPLEX_UNIT_SP, 11f)
                rv.setTextViewTextSize(updatedId, TypedValue.COMPLEX_UNIT_SP, 10f)
            }
            Bucket.BIG -> {
                rv.setTextViewTextSize(R.id.widget_rate, TypedValue.COMPLEX_UNIT_SP, 44f)
                rv.setTextViewTextSize(R.id.widget_title, TypedValue.COMPLEX_UNIT_SP, 13f)
                rv.setTextViewTextSize(secondaryId, TypedValue.COMPLEX_UNIT_SP, 13f)
                rv.setTextViewTextSize(updatedId, TypedValue.COMPLEX_UNIT_SP, 11f)
            }
        }
    }

    /** Cada widget pinta SU layout con las mismas tasas leídas. */
    protected abstract fun render(context: Context, r: Rates, b: Bucket): RemoteViews
}

/** Widget 4×1 «Tasa BCV»: el oficial como héroe, paralelo de secundario. */
class BcvWidgetProvider : BaseRatesWidget() {
    override fun render(context: Context, r: Rates, b: Bucket): RemoteViews =
        RemoteViews(context.packageName, R.layout.widget_bcv).apply {
            setTextViewText(R.id.widget_rate, r.bcv)
            setTextViewText(R.id.widget_updated, r.updated)
            setTextViewText(R.id.widget_parallel, "Paralelo ${r.parallel}")
            applyBucket(this, b, R.id.widget_parallel)
            openAppOnClick(context, this)
        }
}

/** Widget 4×1 «Paralelo»: el mercado como héroe, BCV de secundario. */
class ParallelWidgetProvider : BaseRatesWidget() {
    override fun render(context: Context, r: Rates, b: Bucket): RemoteViews =
        RemoteViews(context.packageName, R.layout.widget_parallel).apply {
            setTextViewText(R.id.widget_rate, r.parallel)
            setTextViewText(R.id.widget_updated, r.updated)
            setTextViewText(R.id.widget_secondary, "BCV ${r.bcv}")
            applyBucket(this, b, R.id.widget_secondary)
            openAppOnClick(context, this)
        }
}

/** Widget 4×1 «Brecha»: la distancia BCV↔paralelo como héroe (§9.7 gap). */
class GapWidgetProvider : BaseRatesWidget() {
    override fun render(context: Context, r: Rates, b: Bucket): RemoteViews =
        RemoteViews(context.packageName, R.layout.widget_gap).apply {
            setTextViewText(R.id.widget_rate, r.gap)
            setTextViewText(R.id.widget_updated, r.updated)
            setTextViewText(R.id.widget_secondary, "BCV ${r.bcv} · Paralelo ${r.parallel}")
            applyBucket(this, b, R.id.widget_secondary)
            openAppOnClick(context, this)
        }
}
