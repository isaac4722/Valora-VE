package ve.valorave.app

import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

/// MainActivity: Flutter puro. Los widgets de escritorio viven en
/// Widgets.kt (home_widget los registra); el puente de Bluetooth clásico
/// RFCOMM de la Sala Viva (BtSppPlugin, v18.0) se registra aquí.
class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(engine: FlutterEngine) {
        super.configureFlutterEngine(engine)
        engine.plugins.add(BtSppPlugin())
    }
}
