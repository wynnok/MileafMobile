package app.mileaf.mileaf.map

import android.content.Context
import android.graphics.Bitmap
import android.graphics.Canvas
import android.graphics.Color
import android.graphics.Paint
import android.view.View
import androidx.lifecycle.DefaultLifecycleObserver
import androidx.lifecycle.LifecycleOwner
import com.amap.api.maps.AMap
import com.amap.api.maps.CameraUpdateFactory
import com.amap.api.maps.MapsInitializer
import com.amap.api.maps.TextureMapView
import com.amap.api.maps.model.BitmapDescriptor
import com.amap.api.maps.model.BitmapDescriptorFactory
import com.amap.api.maps.model.LatLng
import com.amap.api.maps.model.LatLngBounds
import com.amap.api.maps.model.Marker
import com.amap.api.maps.model.MarkerOptions
import com.amap.api.maps.model.PolylineOptions
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.MethodCall
import io.flutter.plugin.common.MethodChannel
import io.flutter.plugin.platform.PlatformView

/**
 * Android-only AMap surface. The Flutter side owns consent and failure policy;
 * this view only maps a GCJ-02 scene onto AMap overlays and camera.
 */
class AmapPlatformView(
    private val context: Context,
    private val viewId: Int,
    messenger: BinaryMessenger,
    private val lifecycleOwner: LifecycleOwner,
    private val params: Map<*, *>,
) : PlatformView, MethodChannel.MethodCallHandler, DefaultLifecycleObserver {
    companion object {
        internal var processKey: String? = null
    }

    private val channel = MethodChannel(messenger, "mileaf/amap_$viewId")
    private var mapView: TextureMapView? = null
    private var amap: AMap? = null
    private var placeholder: View? = null
    private var selectedMarker: Marker? = null
    private var points: List<LatLng> = emptyList()
    private var paddingPx: Int = 36
    private var loaded = false
    private var failed = false
    private var disposed = false
    private var mapCreated = false

    init {
        channel.setMethodCallHandler(this)
        lifecycleOwner.lifecycle.addObserver(this)
        try {
            require(params["consent"] == true) { "consent required" }
            val key = (params["apiKey"] as? String)?.trim()
            require(!key.isNullOrEmpty()) { "api key required" }
            require(processKey == null || processKey == key) { "restart required" }
            MapsInitializer.updatePrivacyShow(context, true, true)
            MapsInitializer.updatePrivacyAgree(context, true)
            if (processKey == null) {
                MapsInitializer.setApiKey(key)
                processKey = key
            }
            val view = TextureMapView(context)
            view.onCreate(null)
            mapCreated = true
            mapView = view
            amap = view.map
            configureMap()
            applyScene(params["scene"])
        } catch (t: Throwable) {
            failed = true
            placeholder = View(context)
            channel.invokeMethod("onMapFailed", mapOf("code" to "init_failed"))
        }
    }

    private fun configureMap() {
        val map = amap ?: return
        val ui = map.uiSettings
        ui.setZoomControlsEnabled(false)
        ui.setCompassEnabled(false)
        ui.setScaleControlsEnabled(false)
        ui.setMyLocationButtonEnabled(false)
        ui.setRotateGesturesEnabled(false)
        ui.setTiltGesturesEnabled(false)
        val interactive = params["interactive"] == true
        ui.setScrollGesturesEnabled(interactive)
        ui.setZoomGesturesEnabled(interactive)
        map.setOnMapLoadedListener {
            loaded = true
            channel.invokeMethod(
                "onMapLoaded",
                mapOf("approvalNumber" to map.mapContentApprovalNumber),
            )
        }
    }

    private fun applyScene(raw: Any?) {
        val scene = raw as? Map<*, *> ?: return
        val map = amap ?: return
        map.clear()
        selectedMarker = null
        points = emptyList()
        val colors = scene["colors"] as? Map<*, *> ?: emptyMap<Any, Any>()
        val lineColor = (colors["line"] as? Number)?.toInt() ?: Color.rgb(47, 125, 88)
        val startColor = (colors["start"] as? Number)?.toInt() ?: lineColor
        val endColor = (colors["end"] as? Number)?.toInt() ?: Color.rgb(20, 32, 25)
        val selectedColor = (colors["selected"] as? Number)?.toInt() ?: Color.rgb(185, 129, 61)
        paddingPx = (scene["padding"] as? Number)?.toInt() ?: 36

        val all = mutableListOf<LatLng>()
        val segments = scene["segments"] as? List<*> ?: emptyList<Any>()
        for (segment in segments) {
            val part = (segment as? List<*>)?.mapNotNull { toLatLng(it) } ?: emptyList()
            if (part.size > 1) {
                map.addPolyline(
                    PolylineOptions()
                        .addAll(part)
                        .color(lineColor)
                        .width(4f),
                )
            }
            all.addAll(part)
        }
        val start = toLatLng(scene["start"])
        val end = toLatLng(scene["end"])
        val selected = toLatLng(scene["selected"])
        start?.let {
            map.addMarker(
                MarkerOptions()
                    .position(it)
                    .icon(dot(startColor, 7f))
                    .anchor(0.5f, 0.5f),
            )
            all.add(it)
        }
        end?.let {
            map.addMarker(
                MarkerOptions()
                    .position(it)
                    .icon(dot(endColor, 7f))
                    .anchor(0.5f, 0.5f),
            )
            all.add(it)
        }
        selected?.let {
            selectedMarker = map.addMarker(
                MarkerOptions()
                    .position(it)
                    .icon(dot(selectedColor, 6f))
                    .anchor(0.5f, 0.5f),
            )
        }
        points = all.distinct()
        map.setMapType(if (scene["night"] == true) AMap.MAP_TYPE_NIGHT else AMap.MAP_TYPE_NORMAL)
        val interactive = scene["interactive"] == true
        map.uiSettings.setScrollGesturesEnabled(interactive)
        map.uiSettings.setZoomGesturesEnabled(interactive)
        fit()
    }

    private fun fit() {
        val map = amap ?: return
        if (points.isEmpty()) return
        if (points.size == 1) {
            map.moveCamera(CameraUpdateFactory.newLatLngZoom(points.first(), 15f))
            return
        }
        var south = points.first().latitude
        var north = south
        var west = points.first().longitude
        var east = west
        for (point in points) {
            if (point.latitude < south) south = point.latitude
            if (point.latitude > north) north = point.latitude
            if (point.longitude < west) west = point.longitude
            if (point.longitude > east) east = point.longitude
        }
        map.moveCamera(
            CameraUpdateFactory.newLatLngBounds(
                LatLngBounds(LatLng(south, west), LatLng(north, east)),
                paddingPx,
            ),
        )
    }

    private fun setSelected(raw: Any?) {
        val map = amap ?: return
        selectedMarker?.remove()
        selectedMarker = null
        val point = toLatLng(raw)
        if (point != null) {
            selectedMarker = map.addMarker(
                MarkerOptions()
                    .position(point)
                    .icon(dot(Color.rgb(185, 129, 61), 6f))
                    .anchor(0.5f, 0.5f),
            )
            map.moveCamera(CameraUpdateFactory.newLatLng(point))
        }
    }

    private fun toLatLng(raw: Any?): LatLng? {
        val pair = raw as? List<*> ?: return null
        if (pair.size < 2) return null
        val lat = (pair[0] as? Number)?.toDouble() ?: return null
        val lon = (pair[1] as? Number)?.toDouble() ?: return null
        if (!lat.isFinite() || !lon.isFinite() || lat !in -90.0..90.0 || lon !in -180.0..180.0) {
            return null
        }
        return LatLng(lat, lon)
    }

    private fun dot(color: Int, radiusDp: Float): BitmapDescriptor {
        val density = context.resources.displayMetrics.density
        val radius = (radiusDp * density).coerceAtLeast(1f)
        val size = (radius * 2f).toInt().coerceAtLeast(1)
        val bitmap = Bitmap.createBitmap(size, size, Bitmap.Config.ARGB_8888)
        val canvas = Canvas(bitmap)
        val paint = Paint(Paint.ANTI_ALIAS_FLAG).apply {
            this.color = color
            style = Paint.Style.FILL
        }
        canvas.drawCircle(size / 2f, size / 2f, size / 2f, paint)
        return BitmapDescriptorFactory.fromBitmap(bitmap)
    }

    override fun onMethodCall(call: MethodCall, result: MethodChannel.Result) {
        when (call.method) {
            "getStatus" -> result.success(
                mapOf(
                    "status" to if (loaded) "loaded" else if (failed) "failed" else "loading",
                    "approvalNumber" to amap?.mapContentApprovalNumber,
                ),
            )
            "setScene" -> {
                applyScene(call.arguments)
                result.success(null)
            }
            "setSelected" -> {
                setSelected(call.arguments)
                result.success(null)
            }
            "fitBounds" -> {
                fit()
                result.success(null)
            }
            "zoomIn" -> {
                amap?.moveCamera(CameraUpdateFactory.zoomIn())
                result.success(null)
            }
            "zoomOut" -> {
                amap?.moveCamera(CameraUpdateFactory.zoomOut())
                result.success(null)
            }
            else -> result.notImplemented()
        }
    }

    override fun getView(): View = mapView ?: placeholder ?: View(context)

    override fun onCreate(owner: LifecycleOwner) {
        if (!disposed && !mapCreated) {
            mapView?.onCreate(null)
            mapCreated = true
        }
    }

    override fun onResume(owner: LifecycleOwner) {
        if (!disposed) mapView?.onResume()
    }

    override fun onPause(owner: LifecycleOwner) {
        if (!disposed) mapView?.onPause()
    }

    override fun onDestroy(owner: LifecycleOwner) {
        dispose()
    }

    override fun dispose() {
        if (disposed) return
        disposed = true
        channel.setMethodCallHandler(null)
        lifecycleOwner.lifecycle.removeObserver(this)
        mapView?.onDestroy()
        mapView = null
        amap = null
    }
}
