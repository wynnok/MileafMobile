package app.mileaf.mileaf

import app.mileaf.mileaf.map.AmapViewFactory
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "app.mileaf/amap",
            AmapViewFactory(this, flutterEngine.dartExecutor.binaryMessenger),
        )
    }
}
