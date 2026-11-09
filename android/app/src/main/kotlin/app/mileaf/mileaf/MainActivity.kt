package app.mileaf.mileaf

import android.content.pm.PackageManager
import android.os.Build
import java.security.MessageDigest
import io.flutter.plugin.common.MethodChannel

import app.mileaf.mileaf.map.AmapViewFactory
import app.mileaf.mileaf.map.AmapPlatformView
import io.flutter.embedding.android.FlutterActivity
import io.flutter.embedding.engine.FlutterEngine

class MainActivity : FlutterActivity() {
    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, "mileaf/map_configuration")
            .setMethodCallHandler { call, result ->
                if (call.method == "getProcessKey") {
                    result.success(AmapPlatformView.processKey)
                } else if (call.method != "getBinding") {
                    result.notImplemented()
                } else {
                    try {
                        result.success(mapBinding())
                    } catch (_: Exception) {
                        result.error("binding_unavailable", "Application identity unavailable", null)
                    }
                }
            }
        flutterEngine.platformViewsController.registry.registerViewFactory(
            "app.mileaf/amap",
            AmapViewFactory(this, flutterEngine.dartExecutor.binaryMessenger),
        )
    }

    @Suppress("DEPRECATION")
    private fun mapBinding(): Map<String, String> {
        val signatures = if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.P) {
            val info = packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNING_CERTIFICATES)
            info.signingInfo?.apkContentsSigners
        } else {
            packageManager.getPackageInfo(packageName, PackageManager.GET_SIGNATURES).signatures
        }
        require(!signatures.isNullOrEmpty())
        val binding = linkedMapOf("包名" to packageName)
        signatures.forEachIndexed { index, signature ->
            val digest = MessageDigest.getInstance("SHA-1").digest(signature.toByteArray())
            val label = if (signatures.size == 1) "签名 SHA-1" else "签名 SHA-1 ${index + 1}"
            binding[label] = digest.joinToString(":") { "%02X".format(it) }
        }
        return binding
    }
}
