package app.mileaf.mileaf.map

import android.content.Context
import androidx.lifecycle.LifecycleOwner
import io.flutter.plugin.common.BinaryMessenger
import io.flutter.plugin.common.StandardMessageCodec
import io.flutter.plugin.platform.PlatformView
import io.flutter.plugin.platform.PlatformViewFactory

class AmapViewFactory(
    private val lifecycleOwner: LifecycleOwner,
    private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
    override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
        AmapPlatformView(
            context = context,
            viewId = viewId,
            messenger = messenger,
            lifecycleOwner = lifecycleOwner,
            params = args as? Map<*, *> ?: emptyMap<String, Any>(),
        )
}
