# 地图双端接入：Android AMap + iOS MapKit 过渡

- 日期：2026-10-31
- 状态：accepted
- 关系：补充 [ADR 0001](0001-visual-direction-c.md)；只改变地图供应商边界，不改变 C 的版面、配色和层级。

## 决策

地图采用**共享 Dart 外壳 + 平台适配器**：

- Flutter 页面只依赖 `MapPanel` / `MapPlatform`，负责场景、同意、加载/失败、C 版式、全屏和兜底。
- Android 使用 `AndroidView` + Kotlin `TextureMapView` + 高德 Android SDK 11.3.100；key 绑定 Package + SHA1。
- iOS 当前使用 `UiKitView` + MapKit（Apple 地图）作为**过渡**；高德 iOS 需要单独的 iOS key（Bundle ID `app.mileaf.mileaf`），拿到 key 后新增 `AmapIosPlatform`，页面与测试不变。
- 坐标只在地图边界做 WGS84→GCJ-02；源头 `MapScene` 保持 WGS84，不修改 DTO/原数组。
- 首屏地图是静态预览，点按进入全屏交互；充电详情地图放在功率曲线之后，作为次级视觉。
- 底图不可用、未同意、无坐标时使用路线速写；不显示空白或研发占位。
- 不新增供应商切换 UI；不向地图发送站点 token；不申请 GPS/定位权限。

## 考虑过的选项

- **`amap_map` 插件**：一套 Dart API 双端，接入最快；但 Android 固定 10.1.200（4KB 对齐），AGP 9 兼容未知，插件约 19 个月未更新，iOS 会引入未验证的 AMap pod。
- **Android-only 平台视图 + iOS 速写**：实现最快，但不是双端地图，iOS 用户永久看不到真实底图。
- **WebView + AMap JS**：需要 JS key，不是 Android/iOS key；手势、性能和隐私更差。
- **MapKit 过渡**：无需 iOS key，能保持双端真实地图；样式与高德不同，但 Dart 页面完全共享。

## 影响

- 新增 `lib/src/map/`：`geo`、`map_scene`、`map_consent`、`map_platform`、`map_panel`、`amap_android_platform`、`mapkit_platform`、`sketch_platform`、`drive_map_page`。
- 删除 `lib/src/map_candidate.dart`、`flutter_map`、`latlong2`。
- Android 新增 `TextureMapView` 平台视图与 AMap 11.3.100；iOS 新增 MapKit 平台视图。
- 首屏地图/充电地图的位置与 C 验收按实现更新；真实底图、真机、iOS AMap key 仍是外部 gate。
- `map_candidate.md` 保留为历史，不再作为当前实现。
