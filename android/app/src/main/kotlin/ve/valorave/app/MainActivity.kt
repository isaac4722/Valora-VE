package ve.valorave.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.os.Build
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel

/// MainActivity: Flutter puro. Los widgets de escritorio viven en
/// Widgets.kt (home_widget los registra); el puente de Bluetooth clásico
/// RFCOMM de la Sala Viva (BtSppPlugin, v18.0) se registra aquí; y desde
/// v19.6 también el canal de App Widgets: la galería de la app pide el
/// pin del widget en la pantalla de inicio (requestPinAppWidget).
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        engine.plugins.add(BtSppPlugin())
        MethodChannel(engine.dartExecutor.binaryMessenger, "valorave/widgets")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "pinWidget" ->
                        pinWidget(call.argument<String>("provider"), result)
                    else -> result.notImplemented()
                }
            }
    }

    /// Pide al launcher fijar el widget en la pantalla de inicio
    /// (requestPinAppWidget, Android 8+). El launcher muestra SU diálogo
    /// de confirmación — aquí solo se contesta si la vía existe; los
    /// launchers sin soporte (o Android viejo) devuelven error y el lado
    /// Dart muestra la guía manual de 3 pasos.
    private fun pinWidget(provider: String?, result: MethodChannel.Result) {
        if (Build.VERSION.SDK_INT < 26) {
            result.error("unsupported", "requestPinAppWidget es API 26+", null)
            return
        }
        val mgr = getSystemService(AppWidgetManager::class.java)
        if (mgr == null || !mgr.isRequestPinAppWidgetSupported) {
            result.error("unsupported", "el launcher no soporta pin", null)
            return
        }
        // Mapa explícito (nada de Class.forName: sobrevive a minify).
        val cls = when (provider) {
            "ParallelWidgetProvider" -> ParallelWidgetProvider::class.java
            "GapWidgetProvider" -> GapWidgetProvider::class.java
            else -> BcvWidgetProvider::class.java
        }
        val ok = mgr.requestPinAppWidget(ComponentName(this, cls), null, null)
        if (ok) {
            result.success(true)
        } else {
            result.error("denied", "el launcher rechazó el pin", null)
        }
    }
}
