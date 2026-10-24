package ve.valorave.app

import android.appwidget.AppWidgetManager
import android.content.ComponentName
import android.content.Intent
import android.net.Uri
import android.os.Build
import android.provider.Settings
import androidx.core.content.FileProvider
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File

/// MainActivity: Flutter puro. Los widgets de escritorio viven en
/// Widgets.kt (home_widget los registra); el puente de Bluetooth clásico
/// RFCOMM de la Sala Viva (BtSppPlugin, v18.0) se registra aquí; desde
/// v19.6 también el canal de App Widgets (requestPinAppWidget); desde
/// v19.8 el canal de DEEP LINKS de la sala: el QR `valorave://sala?c=…`
/// escaneado con la cámara del teléfono abre la app directo al flujo de
/// unirse (canal `valorave/deeplink`: getInitial + onNewIntent); y desde
/// v22.4 el canal del INSTALADOR del canal dev (valorave/instalador): la
/// app descarga el APK de la Release a su cache y este canal lanza la
/// ventana de instalación de Android sobre el archivo via FileProvider.
class MainActivity : FlutterActivity() {
    private var deeplinkChannel: MethodChannel? = null

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
        deeplinkChannel = MethodChannel(
            engine.dartExecutor.binaryMessenger, "valorave/deeplink"
        ).also { channel ->
            channel.setMethodCallHandler { call, result ->
                when (call.method) {
                    // El enlace que ABRÓ la app (intent inicial).
                    "getInitial" -> result.success(intent?.dataString)
                    else -> result.notImplemented()
                }
            }
        }
        MethodChannel(engine.dartExecutor.binaryMessenger, "valorave/instalador")
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "puedeInstalar" -> result.success(puedeInstalarApk())
                    "instalar" -> {
                        val ruta = call.argument<String>("ruta")
                        if (ruta.isNullOrEmpty()) {
                            result.error("badargs", "ruta vacía", null)
                        } else {
                            try {
                                iniciarInstalacion(ruta)
                                result.success(true)
                            } catch (e: Exception) {
                                result.error("install_failed", e.message, null)
                            }
                        }
                    }
                    "abrirAjustesOrigen" -> result.success(abrirAjustesOrigen())
                    else -> result.notImplemented()
                }
            }
    }

    /// Canal dev v22.4: ¿Android 8+ ya le concedió a ValoraVE «Instalar
    /// apps desconocidas»? En API 24–25 el ajuste es global del sistema y
    /// el instalador de Android pide lo suyo en pantalla — aquí no sobra.
    private fun puedeInstalarApk(): Boolean {
        if (Build.VERSION.SDK_INT < 26) return true
        return packageManager.canRequestPackageInstalls()
    }

    /// Canal dev v22.4: lanza la ventana de instalación de Android sobre el
    /// APK que Dart ya descargó en `<cache>/valora_update/`. El archivo va
    /// por FileProvider (content://) porque pasarlo como file:// crashea
    /// desde API 24. Sin FLAG_ACTIVITY_NEW_TASK: MainActivity es una
    /// Activity y el instalador abre sobre ella.
    private fun iniciarInstalacion(ruta: String) {
        val archivo = File(ruta)
        if (!archivo.exists()) {
            throw IllegalStateException(
                "el APK descargado ya no está en el cache (el sistema lo recicló)"
            )
        }
        val uri = FileProvider.getUriForFile(
            this, "$packageName.instalador", archivo
        )
        val intent = Intent(Intent.ACTION_INSTALL_PACKAGE).apply {
            setDataAndType(uri, "application/vnd.android.package-archive")
            addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION)
        }
        startActivity(intent)
    }

    /// Canal dev v22.4: abre el ajuste de sistema «Instalar apps
    /// desconocidas» de ESTA app (API 26+), el que el dueño concede UNA
    /// vez. false si el dispositivo no expone el ajuste (la pantalla Dart
    /// conserva su diálogo explicativo).
    private fun abrirAjustesOrigen(): Boolean {
        if (Build.VERSION.SDK_INT < 26) return false
        return try {
            startActivity(
                Intent(
                    Settings.ACTION_MANAGE_UNKNOWN_APP_SOURCES,
                    Uri.parse("package:$packageName")
                )
            )
            true
        } catch (e: Exception) {
            false
        }
    }

    /// Sala viva: llega un enlace mientras la app ya corre (singleTop).
    override fun onNewIntent(intent: Intent) {
        super.onNewIntent(intent)
        setIntent(intent)
        intent.dataString?.let { uri ->
            deeplinkChannel?.invokeMethod("onLink", uri)
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
