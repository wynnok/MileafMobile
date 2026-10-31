# Flutter 地图技术方案：双端共享 Dart 外壳 + 两个原生适配器

> 2026-10-31 技术提案，**等待确认**。本文只做技术方案，不修改 Spec、tickets、代码，不提交。
> 产品/视觉冲突与 ticket 影响见[高德地图接入方案](map-integration-proposal.md)；本文只回答“Flutter 技术栈下具体怎么写”。
>
> **2026-10-31 实施结果**：Android 高德 `TextureMapView` 已落地；iOS 当时因尚无 iOS key 先落 MapKit 过渡（`MapKitPlatform`），`AmapIosPlatform` 待 key。共享 Dart 外壳/页面/测试已双端共用。

**基线**：Flutter 3.47.7 / Dart 3.13.5；Android AGP 9.1、Gradle 9.3.1、Kotlin 2.4、compileSdk 36、minSdk 24；高德 Android SDK 11.3.100；iOS 15+、高德 iOS SDK（AMap3DMap）。

> **2026-10-31 双端修正**：上一版把 iOS 放在 S5，是验证顺序，不是最终范围。这是双端应用，最终方案必须是 **Android + iOS 共享同一套 Dart 外壳，各用一个薄原生适配器**。iOS 高德需要单独的 **iOS key（绑定 Bundle ID `app.mileaf.mileaf`）**；Android key 不能用于 iOS。没有 iOS key 时，iOS 只能用 MapKit 过渡或路线速写，不能算“高德双端完成”。
>
> **2026-10-31 iOS AMap 落地（取代 MapKit 过渡）**：iOS 生产路径改为 `AmapIosPlatform` + `MAMapView` + `AMap3DMap-NO-IDFA` 11.2.100；`MapKitPlatform` 移除。iOS key 用 `ios/Flutter/AMap.local.xcconfig` 注入，仓库不保存真实值；`AMapFoundation-NO-IDFA` 排除 arm64 simulator，运行证据以 arm64 真机为准。

## 1. 结论

本应用需要的是**一套 Dart 地图外壳 + 两个平台适配器**，不是“Android 平台视图 + iOS 以后再说”：

1. **共享 Dart 外壳**：`MapScene` / `MapCanvas` / `MapConsent` / `MapChrome` / `RouteSketch` / 页面布局 / 测试全部双端共用；
2. **Android 适配器**：`AndroidView` + Kotlin `TextureMapView` + 高德 Android SDK 11.3.100；
3. **iOS 适配器**：`UiKitView` + Objective-C/Swift `MAMapView` + 高德 iOS SDK（AMap3DMap）；
4. **iOS key**：在同一个高德应用下新增 iOS Key，绑定 `Bundle ID = app.mileaf.mileaf`；这是双端高德的硬前提；
5. **没有 iOS key 的过渡**：iOS 用 `MapKitPlatform`（Apple 地图，无需 key）保持真实地图可用，或退到路线速写；Dart 层不变，拿到 iOS key 后只替换 iOS 适配器；
6. **不把 `amap_map` 作为首选**：它确实一套 Dart API 双端，但固定旧 SDK、AGP 9 未知、1.0.15 约 19 个月未更新；可以作为 Gate 0 失败后的备选，不是默认架构。

```text
Flutter UI（C 页面，双端同一套）
  └─ MapCanvas（Dart 状态机 + C 外壳）
      ├─ MapPlatform（接口）
      │   ├─ AmapAndroidPlatform → AndroidView → TextureMapView（GCJ-02）
      │   ├─ AmapIosPlatform     → UiKitView   → MAMapView（GCJ-02）
      │   ├─ MapKitPlatform      → UiKitView   → MKMapView（过渡，无 key）
      │   └─ SketchPlatform      → CustomPainter 路线速写
      └─ MapConsent / MapChrome / MapStates
```

一句话：**Flutter 管“看什么、什么时候能看、失败怎么办”；Android/iOS 各自只负责“把 GCJ-02 底图和覆盖物画出来”。**

## 2. 方案对比

| 方案 | Flutter 侧做法 | 优点 | 问题 | 结论 |
| --- | --- | --- | --- | --- |
| **双端平台视图（推荐）** | 共享 `MapCanvas` + Android `AndroidView` + iOS `UiKitView` | 双端同一套 UI/状态/测试；两端都能用最新高德 SDK；iOS 不依赖旧插件 | 需要 Kotlin + ObjC/Swift 两个薄适配器；平台视图裁剪/z-order 要真机确认 | **采用** |
| `amap_map` 插件 | `AMapWidget` + `AMapController` | 一套 Dart API 双端；接入快 | 固定 10.1.200（Android 4KB 对齐）；1.0.15 约 19 个月未更新；AGP 9 未知；`onMapCreated` 要等 `waitForMap`，dispose 有悬挂风险 | 备选，不是默认 |
| Android 平台视图 + iOS 速写 | Android 原生 + iOS `SketchPlatform` | 实现最快 | **不是双端地图**；iOS 没有真实底图，不能作为最终方案 | 仅过渡 |
| `flutter_map` + 高德瓦片 | 现有 `CandidateMap` | 改动最小 | 高德没有公开可授权的 XYZ 端点；非公开地址不能作为正式方案 | 不采用 |
| WebView + 高德 JS | `webview_flutter` + 本地 HTML | 纯前端 | 需要 JS key，不是 Android/iOS key；性能/手势/隐私更差 | 不采用 |
| `google_maps_flutter` / MapLibre | 其他插件 | 生态成熟 | 无高德底图/中国坐标合规；与用户 key 不匹配 | 不采用 |

**为什么不用 `amap_map` 作为默认**：它虽然是双端一套 Dart API，但 Android 侧固定高德 10.1.200（4KB 对齐，不适合 targetSdk 36 的 16KB 设备），AGP 9/Gradle 9 兼容性未知；iOS 侧 pod 依赖 `AMap3DMap` 且插件 1.0.15 约 19 个月未更新。它可以作为 Gate 0 失败后的快速备选，但不应在没有验证前成为主架构。

**为什么不接受“Android 平台视图 + iOS 速写”作为最终**：这会让 iOS 用户永远看不到真实底图，与“双端应用”直接冲突。它只能是 iOS key 未到位时的临时降级。

## 3. 模块分层

```text
lib/src/map/
  geo.dart                 Wgs84Point / Gcj02Point / wgs84ToGcj02
  map_scene.dart           MapScene / MapRoute / 分段、空/单点、选中点
  map_consent.dart         MapConsentController（SharedPreferences + ValueNotifier）
  map_platform.dart        MapPlatform 接口、MapCallbacks、MapFailure
  amap_android_platform.dart  AndroidView + MethodChannel + TextureMapView
  amap_ios_platform.dart      UiKitView + MethodChannel + MAMapView
  mapkit_platform.dart        UiKitView + MKMapView（无 iOS key 的过渡）
  sketch_platform.dart        CustomPainter 路线速写
  map_canvas.dart          MapCanvas：状态机、加载/失败/同意、C 外壳
  map_chrome.dart          标签、展开、署名、全屏控件
  map_privacy_sheet.dart
  drive_map_page.dart
```

| 模块 | 职责 | 不做什么 |
| --- | --- | --- |
| `geo.dart` | 坐标类型、校验、WGS84→GCJ-02 | 不读 DTO、不请求网络 |
| `map_scene.dart` | 把行程/充电数据整理成“分段 + 起终点 + 选中点” | 不画图、不碰 SDK |
| `map_consent.dart` | 一次性同意、持久化、撤销 | 不初始化 SDK |
| `map_platform.dart` | 抽象“给我一个地图视图” | 不依赖高德/MapKit 类型 |
| `amap_android_platform.dart` | AndroidView、channel、加载/失败、审图号 | 不接收 session/token/API client |
| `amap_ios_platform.dart` | UiKitView、channel、MAMapView、加载/失败、审图号 | 不接收 session/token/API client |
| `mapkit_platform.dart` | iOS 无 key 时的 MKMapView 过渡 | 不冒充高德；坐标规则单独校准 |
| `sketch_platform.dart` | 纸面路线速写、无底图兜底 | 不画假道路/假地名 |
| `map_canvas.dart` | 选择平台、状态机、C 布局、无障碍 | 不重算业务数据 |
| `map_chrome.dart` | 视觉外壳 | 不改地图数据 |

## 4. Dart API 设计

### 4.1 坐标类型：用类型阻止 WGS84 混进高德

```dart
@immutable
class Wgs84Point {
  const Wgs84Point(this.lat, this.lon);
  final double lat;
  final double lon;

  bool get isValid =>
      lat.isFinite && lon.isFinite && lat >= -90 && lat <= 90 && lon >= -180 && lon <= 180;
}

@immutable
class Gcj02Point {
  const Gcj02Point(this.lat, this.lon);
  final double lat;
  final double lon;
}

/// 只在中国大陆范围内偏移；境外、非法值原样返回或丢弃，由调用方决定。
Gcj02Point? wgs84ToGcj02(Wgs84Point? point) { /* 标准算法 + outOfChina */ }
```

- `MapScene` 只保存 `Wgs84Point`；Android/iOS 高德适配器在构造 creation params 时才转成 `Gcj02Point`。
- 原生侧只接收 GCJ-02，不知道 WGS84 的存在；测试可以断言“源 scene 不变、发给原生的点是 GCJ-02”。
- `MapKitPlatform` 是例外：MapKit 在中国境内的坐标处理必须用固定点单独校准，不能复用高德 GCJ-02 假设；见 6.3。

### 4.2 `MapScene`：地图只认这一种输入

```dart
@immutable
class MapScene {
  const MapScene({
    required this.segments,
    this.start,
    this.end,
    this.selected,
    this.selectedLabel,
    this.interactive = false,
    this.brightness = Brightness.light,
  });

  final List<List<Wgs84Point>> segments; // 已按 null 断开
  final Wgs84Point? start;
  final Wgs84Point? end;
  final Wgs84Point? selected;
  final String? selectedLabel;
  final bool interactive;
  final Brightness brightness;

  int get pointCount => segments.fold(0, (sum, part) => sum + part.length);
  bool get isEmpty => pointCount == 0 && start == null && end == null;
  bool get isSinglePoint => pointCount == 1 && start == null && end == null;
}
```

工厂（放在 `map_scene.dart`，不放页面）：

```dart
MapScene driveScene({
  required List<DrivePoint> points,
  required Wgs84Point? start,
  required Wgs84Point? end,
  required int selectedIndex,
  required Brightness brightness,
  required bool interactive,
}) {
  final segments = <List<Wgs84Point>>[];
  var current = <Wgs84Point>[];
  for (final p in points) {
    final point = Wgs84Point(p.lat?.toDouble() ?? double.nan, p.lon?.toDouble() ?? double.nan);
    if (!point.isValid) {
      if (current.isNotEmpty) segments.add(current);
      current = <Wgs84Point>[];
      continue;
    }
    current.add(point);
  }
  if (current.isNotEmpty) segments.add(current);
  // selected 只从有效点里取；start/end 单独传入，不参与折线
  return MapScene(...);
}
```

- 缺失点断开、不跨缺口连线；0 点/1 点/多点语义不变。
- `selected` 不进折线，只做标记；`selectedLabel` 给语义/标记用。
- 充电场景用 `MapScene(segments: [], start: location, end: null)`，页面决定是否显示单点。

### 4.3 `MapPlatform`：一个很窄的接口

```dart
abstract interface class MapPlatform {
  String get providerName; // '高德地图' / 'Apple 地图'
  bool get supported;
  Widget build(MapScene scene, MapCallbacks callbacks);
}

class MapCallbacks {
  const MapCallbacks({required this.onLoaded, required this.onFailed, required this.onApprovalNumber});
  final void Function() onLoaded;
  final void Function(MapFailure failure) onFailed;
  final void Function(String number) onApprovalNumber;
}

enum MapFailure { unsupported, noNativeLibrary, initFailed, timeout, disposed }
```

- `providerName` 让同意书/隐私页显示真实供应商；iOS 用 MapKit 过渡时不能写“高德地图”。
- 高德适配器还要回传审图号；MapKit 使用系统自带署名，不需要审图号。

生产选择：

```dart
MapPlatform defaultMapPlatform() {
  if (Platform.isAndroid) return AmapAndroidPlatform();
  if (Platform.isIOS) {
    return hasAmapIosKey ? AmapIosPlatform() : MapKitPlatform();
  }
  return SketchPlatform();
}
```

- `hasAmapIosKey` 只用于“iOS 是否已配置高德 key”的构建期判断；没有 key 时不要创建 `MAMapView`，直接 MapKit 过渡。
- 两端页面只依赖 `MapCanvas`/`MapPlatform`，不出现 `AndroidView`/`UiKitView`/`MAMapView` 类型。
- 测试注入 `FakeMapPlatform`，记录 `scene`、可手动 `completeLoad()`/`fail()`；不依赖平台视图。

### 4.4 `MapCanvas`：状态机 + C 外壳

```dart
enum MapStatus { consentRequired, unsupported, loading, ready, failed, empty }

class MapCanvas extends StatefulWidget {
  const MapCanvas({
    super.key,
    required this.scene,
    required this.consent,
    this.platform,
    this.interactive = false,
    this.onOpenFullScreen,
    this.onRequestConsent,
  });
  final MapScene scene;
  final MapConsentController consent;
  final MapPlatform? platform;
  final bool interactive;
  final VoidCallback? onOpenFullScreen;
  final VoidCallback? onRequestConsent;
}
```

状态转移：

```text
init / didUpdateWidget
  ├─ consent 未加载/未同意 → consentRequired
  ├─ platform 不支持（无高德 key 且 MapKit 不可用） → unsupported
  ├─ scene.isEmpty → empty
  └─ 其他 → loading（创建平台视图，启动 15s 计时）

native onMapLoaded / onApprovalNumber → ready（取消计时）
native onMapFailed / 15s 超时 → failed（保留结果，显示重试）
重试 → loading（generation++，重建平台视图）
撤销同意 → consentRequired（销毁平台视图）
切车/退出详情 → dispose（generation++，丢弃旧回调）
```

- `MapCanvas` 只负责“地图区域”；页面标题、结果、曲线在它之外，所以地图失败不会挡住结果。
- 加载中：纸面骨架盖在原生视图上，避免白屏。
- 失败：切到 `SketchPlatform` + “重试底图”；不把原生白屏留在页面上。
- `empty`：显示“没有有效轨迹坐标”，不创建地图。
- `ready`：原生视图 + 右下角署名/审图号；首屏用 `IgnorePointer`，全屏页不包。

## 5. 平台视图契约（Android / iOS）

### 5.1 注册

`MainActivity.configureFlutterEngine`：

```kotlin
flutterEngine.platformViewsController.registry.registerViewFactory(
  "app.mileaf/amap",
  AmapViewFactory(this, flutterEngine.dartExecutor.binaryMessenger)
)
```

### 5.2 creation params

Dart → Kotlin，全部是 `StandardMessageCodec` 可编码的 map/list/num/bool：

```json
{
  "consent": true,
  "scene": {
    "segments": [[[31.23, 121.47], [31.231, 121.471]]],
    "start": [31.23, 121.47],
    "end": [31.235, 121.475],
    "selected": [31.233, 121.473],
    "interactive": false,
    "night": false,
    "padding": 36,
    "colors": {
      "line": 4282402648,
      "start": 4282402648,
      "end": 4279242769,
      "selected": 4284724019
    }
  }
}
```

- 坐标已经是 **GCJ-02**；Kotlin 不再做坐标转换。
- 没有 `authorization`、`token`、`session`、`url`、`apiClient` 字段；测试断言这一点。
- 颜色用 ARGB int，避免把 Flutter `Color` 传原生。

### 5.3 方法

| 方向 | method | 参数 | 说明 |
| --- | --- | --- | --- |
| Dart→native | `getStatus` | — | 握手：`{status: loading/loaded/failed, approvalNumber}`，解决 native 先发事件、Dart handler 尚未挂上的竞态 |
| Dart→native | `setScene` | `scene` | 更新折线/标记/相机 |
| Dart→native | `setSelected` | `[lat, lon]?` | 只更新选中标记 |
| Dart→native | `setNight` | `bool` | 普通/夜间地图 |
| Dart→native | `setInteractive` | `bool` | 首屏 false，全屏 true |
| Dart→native | `fitBounds` | `padding` | 适配轨迹 |
| Dart→native | `zoomIn` / `zoomOut` | — | 全屏控件 |
| native→Dart | `onMapLoaded` | `{approvalNumber}` | 地图可见，取审图号 |
| native→Dart | `onMapFailed` | `{code}` | `no_native_library` / `init_failed` |

`onMapLoaded`/`onMapFailed` 可能在 `onPlatformViewCreated` 之前从 native 发出；Dart 挂上 handler 后必须立刻调一次 `getStatus` 握手，不能只依赖事件，否则会丢“已加载/已失败”。

### 5.4 Kotlin 结构

```kotlin
class AmapViewFactory(
  private val lifecycleOwner: LifecycleOwner,
  private val messenger: BinaryMessenger,
) : PlatformViewFactory(StandardMessageCodec.INSTANCE) {
  override fun create(context: Context, viewId: Int, args: Any?): PlatformView =
    AmapPlatformView(context, viewId, messenger, lifecycleOwner, args as? Map<*, *> ?: emptyMap<String, Any>())
}

class AmapPlatformView(...) : PlatformView, MethodChannel.MethodCallHandler, DefaultLifecycleObserver {
  private val channel = MethodChannel(messenger, "mileaf/amap_$viewId")
  private var mapView: TextureMapView? = null
  private var amap: AMap? = null
  private var placeholder: View? = null

  init {
    channel.setMethodCallHandler(this)
    lifecycleOwner.lifecycle.addObserver(this)
    try {
      require(params["consent"] == true) { "consent required" }
      MapsInitializer.updatePrivacyShow(context, true, true)
      MapsInitializer.updatePrivacyAgree(context, true)
      mapView = TextureMapView(context).also { view ->
        view.onCreate(null)
        amap = view.map
        amap?.setOnMapLoadedListener {
          channel.invokeMethod("onMapLoaded", mapOf("approvalNumber" to amap?.mapContentApprovalNumber))
        }
        applyScene(params["scene"])
      }
    } catch (t: Throwable) {
      placeholder = View(context)
      channel.invokeMethod("onMapFailed", mapOf("code" to "init_failed"))
    }
  }

  override fun getView(): View = mapView ?: placeholder!!
  override fun dispose() { /* remove observer, channel null, mapView.onDestroy() */ }
}
```

关键点：

- `MapsInitializer.updatePrivacyShow/Agree` 必须在 `TextureMapView` 构造前调用；不同意为空时直接失败，不创建 SDK。
- `TextureMapView` 而不是 `MapView`：Flutter 侧可以做圆角裁剪/叠加层；`MapView` 的 SurfaceView 更容易盖住 Flutter overlay。
- `setOnMapLoadedListener` 是唯一的“真的加载完了”信号；Dart 侧 15s 超时兜底。
- `getMapContentApprovalNumber()` 在加载后取，回传 Dart；不要硬编码审图号。
- 捕获 `Throwable`：x86_64 模拟器没有高德 `.so`，`TextureMapView` 会抛 `UnsatisfiedLinkError`；必须转成 `onMapFailed`，不能崩溃。
- 生命周期：`onCreate/onResume/onPause/onDestroy` 跟 Activity 走；`dispose` 移除 observer 并销毁 mapView。
- 首屏 `UiSettings` 关闭 scroll/zoom/rotate/tilt/compass/scale/location button；全屏打开 scroll/zoom，仍关闭定位蓝点和 POI 点击。
- 标记用 Canvas 生成小圆点位图（起点湖绿、终点深墨、选中琥珀），不引入图片资源。
- 地图背景设成纸面色，避免加载前黑屏。

### 5.5 Android 配置

```kotlin
android {
  defaultConfig {
    manifestPlaceholders["amapApiKey"] = System.getenv("MILEAF_AMAP_ANDROID_KEY") ?: ""
  }
}
dependencies {
  implementation("com.amap.api:3dmap-location-search:11.3.100_loc11.3.101_sea9.8.1")
}
```

```xml
<uses-permission android:name="android.permission.ACCESS_NETWORK_STATE" />
<application>
  <meta-data android:name="com.amap.api.v2.apikey" android:value="${amapApiKey}" />
</application>
```

- `INTERNET` 已有；**不加定位权限**，不初始化定位/搜索组件。
- 不加 `allowNativeHeapPointerTagging=false`，除非 Gate 0 真机复现返回闪退；不预先削弱安全缓解。
- R8 如开启，保留 `com.amap.api.maps.**`、`com.autonavi.**`、`com.amap.api.trace.**`。
- 11.3.100 只有 `armeabi-v7a`/`arm64-v8a`；x86_64 模拟器地图会失败兜底，不作为验收环境。

### 5.6 iOS 平台视图（对等适配器）

iOS 和 Android 共用同一套 Dart 外壳、同一套 `MethodChannel` 方法名和同一套 `scene` 结构；区别只在原生视图是 `UiKitView` + `MAMapView`。

**注册**：在 `AppDelegate`/`AmapIosPlugin` 里注册：

```swift
let registrar = self.registrar(forPlugin: "AmapIosPlugin")!
registrar.register(
  AmapIosViewFactory(messenger: registrar.messenger()),
  withId: "app.mileaf/amap_ios"
)
```

- `AmapIosViewFactory: NSObject, FlutterPlatformViewFactory`，`createArgsCodec` 用 `FlutterStandardMessageCodec.sharedInstance()`。
- 注册时使用 `FlutterPlatformViewGestureRecognizersBlockingPolicyWaitUntilTouchesEnded`，和 Android 的全屏手势行为对齐。
- 首屏仍由 Flutter `IgnorePointer` 包住，原生视图不接手势；全屏页才把手势交给 `MAMapView`。

**创建顺序**（顺序错了会白屏）：

```swift
// 1. 隐私合规，必须在 MAMapView 之前
MAMapView.updatePrivacyShow(true, privacyInfo: true)
MAMapView.updatePrivacyAgree(true)
// 2. key，必须在 MAMapView 之前
AMapServices.shared().apiKey = iosKey
// 3. 创建地图
let mapView = MAMapView(frame: .zero)
mapView.delegate = self
```

- iOS key 绑定的是 **Bundle ID**，不是 SHA1。当前 App 的 Runner Bundle ID 是 `app.mileaf.mileaf`；在同一个高德应用下新增 iOS Key，填这个 Bundle ID。
- iOS key 实施为 `ios/Flutter/AMap.local.xcconfig` → `Info.plist` → 原生 `AMapServices.apiKey`；不写仓库。
- 没有 iOS key 时不要创建 `MAMapView`，直接走 `MapKitPlatform` 或速写。

**加载与审图号**：

- `MAMapViewDelegate` 的 `mapViewDidFinishLoadingMap(_:)` 作为“瓦片可见”信号；`mapInitComplete(_:)` 只代表初始化完成，不能单独当成加载成功。
- 15 秒没有 `mapViewDidFinishLoadingMap` → Dart 侧失败兜底；不要只看 `mapInitComplete` 就显示“已加载”。
- `mapView.mapContentApprovalNumber` 取审图号，回传 Dart；为空只显示“© 高德地图”。
- 同样需要 `getStatus` 握手：native 可能先于 Dart handler 发出 loaded/failed。

**覆盖物**：

- `MAPolyline` + `MAPolylineRenderer`：分段折线，颜色/线宽从 creation params 取，缺失点断开。
- `MAPointAnnotation` + 自定义 `MAAnnotationView`：起点湖绿、终点深墨、选中琥珀；用小圆点，不用默认红色大头针。
- 视野：多点用 `setVisibleMapRect(_:edgePadding:animated:)`；单点用 `setCenter(_:animated:)` + `zoomLevel`。
- `mapType = .standardNight`（深色）/ `.standard`（浅色）。
- `scrollEnabled` / `zoomEnabled` / `rotateEnabled` / `rotateCameraEnabled`（仰角）按 `interactive` 开关；`showsCompass = false`、`showsScale = false`、`touchPOIEnabled = false`；不显示用户定位蓝点。
- 地图 logo 保留默认位置；Flutter 署名/审图号放右下角，不盖住 logo。

**iOS 依赖**：

```ruby
# ios/Podfile
pod 'AMap3DMap'        # 或 AMap3DMap-NO-IDFA，按上架合规要求选
pod 'AMapFoundation'
```

- 使用项目级 CocoaPods；`use_frameworks!` 下 `AMap3DMap` 是静态 framework，Gate 0b 先验证 `pod install` + `build ios --release --no-codesign`。
- 如果计划上架且不想带 IDFA，选 `AMap3DMap-NO-IDFA` 变体；在 Gate 0b 固定版本并记录。
- iOS 15+；不申请定位权限；不加 `NSLocationWhenInUseUsageDescription`，除非 Gate 证明 SDK 强制要求且只用于地图显示。
- App Store 的隐私清单/IDFA/第三方 SDK 声明是外部 gate，不在本次代码切片内假装完成。

### 5.7 无 iOS key 的 MapKit 过渡

如果 iOS key 短期拿不到，iOS 不能空白，也不应该把 Android 平台视图硬搬过去。用 `MapKitPlatform` 作为过渡：

- `UiKitView` + `MKMapView`；`MKPolyline` + `MKPointAnnotation`；`setVisibleMapRect`。
- 不需要 key；不申请定位权限；可在 iOS 15+ 真机/模拟器显示真实地图。
- **坐标规则单独校准**：MapKit 在中国境内的坐标处理不能复用高德 GCJ-02 假设；用固定起终点在 iOS Gate 验证，确认传 WGS84 还是 GCJ-02。这个差异只存在于 `MapKitPlatform`，不影响共享 `MapScene`。
- 样式无法和高德完全一致；地图隐私页明确写“iOS 过渡使用 Apple 地图”，不冒充高德。
- 拿到 iOS key 后，只把 `defaultMapPlatform()` 的 iOS 分支从 `MapKitPlatform()` 换成 `AmapIosPlatform()`；页面、状态、测试、C 版式不变。

## 6. 页面接入

以下 `TripMapHero` / `DriveMapPage` / `PlaceMap` **双端共用**；页面不出现 `AndroidView`/`UiKitView`/`MAMapView` 类型，平台差异只在 `MapPlatform` 实现。

### 6.1 行程详情：首屏静态 hero + 全屏地图

```dart
ListView(
  padding: EdgeInsets.zero,
  children: [
    TripMapHero(
      scene: driveScene(...),
      consent: widget.mapConsent,
      onOpenFullScreen: () => Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => DriveMapPage(scene: driveScene(interactive: true), consent: ...)),
      ),
      onRequestConsent: () => showMapConsentSheet(context, widget.mapConsent),
    ),
    Padding(
      padding: const EdgeInsets.all(12),
      child: Column(children: [/* 起终点、结果、SOC、曲线 */]),
    ),
  ],
)
```

`TripMapHero`：

- 高度 `(screenHeight * 0.36).clamp(240, 340)`；满幅、下缘 22px 圆角；纸面背景。
- `Stack`：`MapCanvas` → 点击层（`IgnorePointer` 包住地图，点击层负责打开全屏/同意/重试）→ 左上“地图”标签 → 右上展开 → 右下署名/审图号。
- 首屏地图**不可拖动/缩放**；点地图或展开进入全屏。
- 如果 `ClipRRect` 裁不住平台视图，用纸面四角遮罩/细边框实现同样的圆角；不要盖住高德 logo。

### 6.2 全屏 `DriveMapPage`

```dart
Scaffold(
  appBar: AppBar(title: const Text('行程地图')),
  body: MapCanvas(
    scene: scene,
    consent: consent,
    interactive: true,
    onOpenFullScreen: null,
  ),
)
```

- 全屏页不包 `IgnorePointer`；高德手势直接工作。
- 底部控件放在地图外的 `bottomNavigationBar`/底部栏，避免平台视图 z-order 盖住 Flutter 按钮。
- 控件：适配轨迹、放大、缩小；44px 点击区；署名/审图号保留；不是导航，不显示定位蓝点。
- 返回详情保持当前选中采样；详情图表选点变化时，首屏 `MapCanvas.setSelected` 同步。

### 6.3 充电详情：次级地点图

```text
地点名称
SOC 电池弧（hero）
充入能量/费用/时长
PlaceMap（180px，单点）   ← 次级
功率/电量曲线
```

- `MapScene(segments: [], start: location)`；有坐标才显示，无坐标显示“未记录充电地点”纸面 tile。
- 不抢 SOC/功率的首屏位置；地图失败不影响能量/费用/曲线。
- 可选：点击进全屏单点地图；不做导航/周边 POI。
- Android/iOS 共用同一个 `PlaceMap`，平台差异只在 `MapPlatform` 实现。

## 7. 状态、失败与并发

| 状态 | UI | 数据/网络 |
| --- | --- | --- |
| `consentRequired` | 路线速写 + “启用高德地图” | 不创建 SDK，不联网 |
| `unsupported` | 路线速写 + “底图未配置”/“此平台暂不支持” | 不联网 |
| `empty` | “没有有效轨迹坐标” | 不创建 SDK |
| `loading` | 纸面骨架，盖住原生视图 | SDK 加载；15s 计时 |
| `ready` | 底图 + 覆盖物 + 署名/审图号 | SDK 自请求 |
| `failed` | 路线速写 + “底图暂不可用 · 重试” | 不重试业务请求 |
| 切车/退出 | 销毁视图，generation++ | 旧回调丢弃 |

- 失败**只影响地图**；详情结果、SOC、曲线、文字照常。
- 不自动重试底图；用户点“重试”才重建视图。避免断网时反复请求。
- 地图请求不带站点 token：`MapScene`/creation params 没有 session 字段，结构上不可能。
- 不请求 GPS；不初始化定位/搜索组件；不显示定位蓝点。
- 高德 SDK 自己的网络请求在独立边界；不接管、不注入 `http.Client`、不记录坐标/URL/key。

## 8. 同意、隐私与主题

### 8.1 同意

```dart
class MapConsentController extends ChangeNotifier {
  MapConsentController(this._prefs);
  bool? _granted;              // null = 未加载
  bool? get granted => _granted;
  Future<void> load();
  Future<void> grant();
  Future<void> revoke();
}
```

- `SharedPreferences` key：`map.amap.consent.v1`；只存 bool，不存坐标/key。
- 首次进入详情不自动创建 SDK；显示速写 + “启用高德地图”。
- 底部 sheet：供应商、发送什么、不发送什么、隐私政策链接、允许/暂不。
- 同意后 `grant()`；`MapCanvas` 重建为 loading。
- “数据说明与更多 > 地图与隐私”可撤销；撤销后 `MapCanvas` 回到 `consentRequired`，原生视图销毁。高德 SDK 的内存状态可能持续到进程结束，文案写明“下次启动完全停止”，不假装热卸载。

### 8.2 主题

- `MapScene.brightness` 来自 `Theme.of(context).brightness`；`AmapAndroidPlatform`/`AmapIosPlatform` 映射为 `night` bool。
- 折线/标记颜色从 `ColorScheme` 取：primary/onSurface/tertiary；不把 C token 写死在 Kotlin/Swift。
- 深色用高德夜间图；浅色用普通图。地图自身颜色不替代 C 的湖畔 token。
- `RouteSketch` 用 `surfaceContainerLow`/`outlineVariant`/`onSurfaceVariant`，和 C 的纸面一致。
- 200% 字号：标签/署名允许换行；不用固定高度裁剪文字；地图高度可不变，覆盖层用 `Positioned` + `left/right`。

## 9. 测试

| 层 | 测什么 | 怎么测 |
| --- | --- | --- |
| 纯 Dart | WGS84→GCJ-02、境外不偏移、非法值、分段 | 固定点单测，误差阈值写明来源 |
| `MapScene` | 0/1/多点、缺失断开、start/end 独立、selected 有效 | 纯单测 |
| `MapCanvas` | 同意前不建引擎；同意后收到 GCJ-02；失败保留结果；重试；切车隔离；200%/浅深色 | `FakeMapPlatform`，不建平台视图 |
| App/HTTP | 详情数据到地图输入；地图参数无 token；地图失败不影响结果 | 现有最高 App+HTTP 缝 + FakeMapPlatform |
| 渲染 | 速写、同意、加载、失败、空态；360×800、100/200%、浅/深色 | 现有 opt-in Flutter 渲染入口（双端同一套） |
| 真机/模拟器 | Android：真实底图、路线对齐、缩放、深色、断网、无定位权限、署名/审图号 | ARM64 手机，单独记录 |
| iOS | `MAMapView` 真实底图、Bundle ID/key、路线/标记/夜间、`mapViewDidFinishLoadingMap`、审图号 | iOS 15 真机或模拟器；Gate 0b |
| iOS 过渡 | MapKit 真实底图、坐标固定点、C 外壳、无 key | 无 iOS key 时单独记录，标注“过渡” |
| 构建 | Android 11.3.100 `.so`、16KB、ABI、manifest key 存在但不在 git；iOS `pod install` + 无签名构建 | Gate 0a/0b + release 构建 |

`FakeMapPlatform` 形状：

```dart
class FakeMapPlatform implements MapPlatform {
  MapScene? scene;
  bool loaded = false;
  MapCallbacks? callbacks;

  @override
  bool get supported => true;

  @override
  Widget build(MapScene scene, MapCallbacks callbacks) {
    this.scene = scene;
    this.callbacks = callbacks;
    return const SizedBox.expand();
  }

  void completeLoad([String approval = 'GS(test)']) {
    loaded = true;
    callbacks!.onLoaded();
    callbacks!.onApprovalNumber(approval);
  }

  void fail(MapFailure failure) => callbacks!.onFailed(failure);
}
```

- 测试里 `pump(Duration(seconds: 15))` 验证超时兜底；`completeLoad()` 验证加载成功；`fail()` 验证失败。
- 断言 `fake.scene` 里的点是 GCJ-02；源 `MapScene` 仍是 WGS84。
- 断言 creation params 不含 `token`/`authorization`/`url`/`session`。

## 10. 文件与实施切片

### 新增/修改

| 文件 | 动作 |
| --- | --- |
| `lib/src/map/geo.dart` | 新增：坐标类型 + 转换 |
| `lib/src/map/map_scene.dart` | 新增：场景/分段 |
| `lib/src/map/map_consent.dart` | 新增：同意控制器 |
| `lib/src/map/map_platform.dart` | 新增：接口/回调/失败枚举 |
| `lib/src/map/amap_android_platform.dart` | 新增：AndroidView + channel |
| `lib/src/map/amap_ios_platform.dart` | 新增：UiKitView + channel |
| `lib/src/map/mapkit_platform.dart` | 新增：iOS 无 key 的 MapKit 过渡 |
| `lib/src/map/sketch_platform.dart` | 新增：路线速写 |
| `lib/src/map/map_canvas.dart` | 新增：状态机/外壳 |
| `lib/src/map/map_chrome.dart` | 新增：标签/展开/署名 |
| `lib/src/map/map_privacy_sheet.dart` | 新增：同意/隐私 |
| `lib/src/map/drive_map_page.dart` | 新增：全屏地图 |
| `lib/src/drive_detail_page.dart` | 改用 `TripMapHero`，移除旧 `CandidateMap` |
| `lib/src/charging_detail.dart` | 改用 `PlaceMap`，移到 SOC/能量之后 |
| `lib/src/workspace_page.dart` / `lib/main.dart` | 注入 `MapConsentController`；移除 `MapConfiguration` |
| `lib/src/map_candidate.dart` | 删除（迁移完成后） |
| `pubspec.yaml` | 移除 `flutter_map`/`latlong2`；可选加 `url_launcher` |
| `android/app/src/main/kotlin/.../map/` | 新增 `AmapViewFactory.kt`、`AmapPlatformView.kt`、`MapSceneCodec.kt` |
| `android/app/src/main/AndroidManifest.xml` | 加 `ACCESS_NETWORK_STATE`、AMap meta-data |
| `android/app/build.gradle.kts` | 加 AMap 11.3.100、manifest placeholder |
| `MainActivity.kt` | 注册 Android 平台视图 factory |
| `ios/Runner/Amap/` | 新增 `AmapIosPlugin.swift`、`AmapIosViewFactory.swift`、`AmapIosPlatformView.swift`、`MapSceneCodec.swift` |
| `ios/Podfile` | 加 `AMap3DMap` / `AMapFoundation`（或 NO-IDFA 变体） |
| `ios/Runner/AppDelegate.swift` | 注册 iOS 平台视图 factory |
| `test/map_candidate_test.dart` | 删除/替换 |
| `test/drive_map_test.dart` | 改用 FakeMapPlatform |

### 切片

| 切片 | 内容 | 通过条件 |
| --- | --- | --- |
| **F0a Android Gate** | Kotlin probe + AMap 依赖 + manifest key；Android release + ARM64 真机 | key 绑定正确、真实底图、16KB/ABI/AGP 9 通过；失败停止 |
| **F0b iOS Gate** | iOS Key（Bundle ID `app.mileaf.mileaf`）+ `AMap3DMap` pod + 最小 `MAMapView` probe；`pod install` + `build ios --release --no-codesign` | iOS key/Bundle ID 正确、pod/Xcode 构建通过、真实底图/审图号可读；失败先走 MapKit 过渡或停止 |
| **F1 Dart 外壳** | `geo`/`map_scene`/`map_consent`/`map_platform`/`sketch`/`map_canvas` + Fake 测试 | 纯 Dart/Widget 测试通过；无 SDK |
| **F2 Android 适配** | `AmapAndroidPlatform`、`TripMapHero`、`DriveMapPage`、详情接入 | 真实路线/起终点/选中、浅深色、200%、失败兜底 |
| **F3 iOS 适配** | `AmapIosPlatform`（或 `MapKitPlatform` 过渡）、同一套页面 | 真实底图、路线/标记/夜间、加载/失败、200%；与 F2 并行 |
| **F4 充电与隐私** | `PlaceMap` 移到 SOC/能量之后；持久化同意、撤销、隐私页、署名/审图号；删除旧地图/依赖 | 双端单点/无点/失败；无 token、无 GPS、无旧引用 |
| **F5 双端验证** | 全量测试、渲染、Android/iOS release、双端真机/模拟器、双轴审查、文档 | 见第 9 节；#4/#11 在双端证据齐全前保持 OPEN |

## 11. 风险与对策

| 风险 | 影响 | 对策 |
| --- | --- | --- |
| Android key 未绑定当前 Package/SHA1 | Android 地图空白 | Gate 0a 先核对；把项目 debug SHA1 加到控制台；不清理 `.cache/android/debug.keystore` |
| iOS key 未绑定 `app.mileaf.mileaf` | iOS 地图空白 | Gate 0b 先核对 Bundle ID；在同一个高德应用下新增 iOS Key；没有 key 时走 MapKit 过渡 |
| AGP 9 / Gradle 9 与 AMap 11.3.100 不兼容 | Android 无法构建 | Gate 0a 先用最小 probe 验证；失败则停或改用 `amap_map` 备选 |
| iOS pod/Xcode 26/静态 framework 不兼容 | iOS 无法构建 | Gate 0b 先 `pod install` + 无签名构建；固定 AMap3DMap 版本；失败先 MapKit |
| iOS IDFA/隐私清单 | 上架合规 | 选 `AMap3DMap-NO-IDFA`；App Store 隐私声明单独 gate |
| 平台视图圆角/叠加层不生效 | C 视觉破坏 | Android `TextureMapView` / iOS `MAMapView` + `ClipRRect`；不行用纸面四角遮罩；z-order 双端确认 |
| Android x86_64 模拟器无 `.so` | 地图崩溃/空白 | 捕获 `Throwable` → `onMapFailed`；Android 验收只用 ARM64 真机 |
| iOS 模拟器架构/SDK 限制 | 无法模拟器验收 | Gate 0b 先试 arm64 模拟器；不行用 iOS 15 真机 |
| APK/IPA 体积增加 | 安装包变大 | Gate 0a/0b 量测；Android release ABI split；不预加载列表地图 |
| 高德 SDK 采集/隐私 | 合规风险 | 双端同意后初始化；明示采集范围；隐私页/控制台链接；不申请定位权限 |
| 坐标偏移 | 路线不在路上 | 高德双端固定点校准；MapKit 单独校准；只在地图边界转换 |
| 地图失败被误当页面失败 | 用户丢失结果 | `MapCanvas` 只包地图；失败切速写；结果/曲线独立渲染 |
| 两套原生适配器维护成本 | 长期成本 | Dart 层/页面/测试完全共享；原生只保留 scene→覆盖物/相机的最小映射 |

## 12. 需要确认

1. **iOS key**：能否在[高德控制台](https://console.amap.com/dev/key)同一个应用下新增一个 **iOS 平台 Key**，Bundle ID 填 `app.mileaf.mileaf`？
   ➡️ 推荐：新增。没有 iOS key，iOS 端不可能显示高德底图；任何“一个 Android key 双端通用”的说法都是错的。
2. **iOS 过渡**：如果 iOS key 短期拿不到，接受 iOS 先用 **MapKit 真实地图**（Apple 地图，无需 key，样式与高德不同）过渡，还是先用路线速写？
   ➡️ 推荐：MapKit 过渡；拿到 key 后只替换 iOS 适配器，Dart 页面不变。
3. **架构**：接受 **共享 Dart 外壳 + Android/iOS 两个薄原生适配器**，而不是 `amap_map` 插件吗？
   ➡️ 推荐：接受。两端都能用最新高德 SDK；`amap_map` 仅作为 Gate 0 失败后的备选。
4. **页面**：接受双端都用“**首屏静态地图 + 全屏交互**、充电地图在 SOC/能量之后”吗？
   ➡️ 推荐：接受。两端共用同一套 `TripMapHero`/`DriveMapPage`/`PlaceMap`。
5. **依赖**：接受移除 `flutter_map`/`latlong2`，用纯 Flutter 路线速写兜底，并加 `url_launcher` 打开隐私政策吗？
   ➡️ 推荐：接受。
6. **Gate**：接受 **F0a Android + F0b iOS** 双 Gate 先行吗？
   ➡️ 推荐：接受。任一 Gate 失败，先解决构建/key，不先写产品 UI。

确认后按 **F0a/F0b → F1 → F2/F3（并行） → F4 → F5** 执行；两个 Gate 通过前不改产品代码。
