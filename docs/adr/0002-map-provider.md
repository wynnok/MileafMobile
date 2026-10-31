# 地图双端接入：Android AMap + iOS AMap

- 日期：2026-10-31
- 状态：accepted
- 关系：补充 [ADR 0001](0001-visual-direction-c.md)；只改变地图供应商边界，不改变 C 的版面、配色和层级。本文的 iOS AMap 段落取代同日“MapKit 过渡”方案。

## 决策

地图采用**共享 Dart 外壳 + 平台适配器**：

- Flutter 页面只依赖 `MapPanel` / `MapPlatform`，负责场景、同意、加载/失败、C 版式、全屏和兜底。
- Android 使用 `AndroidView` + Kotlin `TextureMapView` + 高德 Android SDK 11.3.100；key 绑定 Package + SHA1。
- iOS 使用 `UiKitView` + Swift `MAMapView` + 高德 iOS SDK `AMap3DMap-NO-IDFA` 11.2.100 / `AMapFoundation-NO-IDFA` 1.9.1；iOS key 绑定 Bundle ID `app.mileaf.mileaf`，通过非公开构建配置注入，不进入仓库。
- 高德地图需要用户同意后才创建 `MAMapView`；初始化前调用 `MAMapView.updatePrivacyShow` / `updatePrivacyAgree`。撤销同意后不再创建新地图；已加载的 SDK 内存状态可能持续到进程结束。
- 坐标只在地图边界做 WGS84→GCJ-02；源头 `MapScene` 保持 WGS84，不修改 DTO/原数组；两端适配器都消费同一份 `gcj02*`。
- 首屏地图是静态预览，点按进入全屏交互；充电详情地图放在功率曲线之后，作为次级视觉。
- 底图不可用、未同意、无坐标时使用路线速写；不显示空白或研发占位。生产 iOS 不再保留 MapKit 作为第二个底图源。
- 不新增供应商切换 UI；不向地图发送站点 token；不申请 GPS/定位权限；不集成定位/搜索组件。

## 考虑过的选项

- **`amap_map` 插件**：一套 Dart API 双端，接入最快；但 Android 固定 10.1.200（4KB 对齐），AGP 9 兼容未知，插件约 19 个月未更新，iOS 会引入未验证的 AMap pod。
- **Android-only 平台视图 + iOS 速写**：实现最快，但不是双端地图，iOS 用户永久看不到真实底图。
- **WebView + AMap JS**：需要 JS key，不是 Android/iOS key；手势、性能和隐私更差。
- **MapKit 过渡**：已被 iOS AMap 取代，只作为历史；不作为生产底图源，也不再保留 Apple 供应商切换。

## 影响

- 新增 `lib/src/map/`：`geo`、`map_scene`、`amap_scene_wire`、`map_consent`、`map_platform`、`map_panel`、`amap_android_platform`、`amap_ios_platform`、`sketch_platform`、`drive_map_page`。
- 删除 `lib/src/map_candidate.dart`、`flutter_map`、`latlong2`、`mapkit_platform.dart`。
- Android 新增 `TextureMapView` 平台视图与 AMap 11.3.100；iOS 新增 `MAMapView` 平台视图与 AMap 11.2.100 NO-IDFA；`AMapFoundation-NO-IDFA` 固定 1.9.1。
- 两个 Dart 适配器共用 `AmapSceneWire`，统一 GCJ-02 场景编码和变更签名，避免双端 wire 漂移。
- 高德 iOS key 通过 `ios/Flutter/AMap.local.xcconfig` 注入 `Info.plist`；仓库只保留 example。key 会进入 IPA，这是移动端 key 的固有形态，安全边界是 Bundle ID 绑定。
- `AMapFoundation-NO-IDFA` 排除 arm64 simulator；iOS 地图运行验证以 arm64 真机为准，模拟器不算有效地图运行环境。
- 首屏地图/充电地图的位置与 C 验收按实现更新；真机底图、CRS 校准、大陆双端网络、隐私清单/上架合规仍是外部 gate。
- `map_candidate.md` 保留为历史，不再作为当前实现。
