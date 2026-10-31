# 地图双端接入实现（Android AMap / iOS MapKit 过渡）

日期：2026-10-31。状态：本地实现与自动化/构建验证完成；真实 key、真机和 iOS AMap key 仍待外部验证。
本文件记录代码事实，不替代 #4/#11 的外部验收。

## 已实现

- 共享 `MapPanel`：同意、加载/失败、15 秒超时、路线速写、署名/审图号、首屏静态 + 全屏入口。
- `MapScene`：WGS84 分段、起终点、选中点；缺失点断开；`gcj02Segments` 只在地图边界转换。
- Android：`AndroidView` + Kotlin `TextureMapView`；高德 11.3.100；`OnMapLoadedListener`、`getStatus` 握手、审图号、生命周期、x86 缺失 `.so` 失败兜底。
- iOS：`UiKitView` + `MKMapView`；MapKit 过渡，不冒充高德；`providerName` 明确显示“Apple 地图”。
- 行程详情：满幅 300px hero，点按进入 `DriveMapPage` 全屏缩放；路线 caption 在底图上。
- 充电详情：地图移到功率曲线之后，180px 次级；无坐标显示“没有有效轨迹坐标”。
- 同意：`SharedPreferences` 持久化且按供应商隔离；`MapConsentController` 可撤销；设置与服务页新增“地图与隐私”，可查看供应商/链接并关闭底图。
- 删除 `map_candidate.dart`、`flutter_map`、`latlong2`。

## 验证

- `tool/flutterw analyze`：0 issues。
- `tool/flutterw test`：268 passed，19 skipped（opt-in render）。
- `test/map_platform_test.dart`：GCJ-02、分段、同意前不建图、加载、失败重试、15s 超时、空场景。
- Android `:app:compileDebugKotlin` 通过；`:app:assembleDebug`、`:app:assembleRelease` 通过。
- APK 内含 `lib/arm64-v8a/libAMapSDK_MAP_v11_3_100.so`、`lib/armeabi-v7a/...`；`zipalign -c -P 16` 通过；release 124MB（universal，含两套 ABI），R8 保留 AMap 反射类。
- iOS `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -derivedDataPath build/ios-derived CODE_SIGNING_ALLOWED=NO` 通过。
- 未运行真机地图、未用真实 key 出图、未跑 iOS MapKit 运行时截图；这些属于外部 gate。

## 构建命令与 key

```sh
# 不要把 key 写进仓库或命令输出
cp config/amap.local.env.example config/amap.local.env
# 编辑 config/amap.local.env，填入 MILEAF_AMAP_ANDROID_KEY
set -a; . config/amap.local.env; set +a
MILEAF_HOST_ANDROID_SDK=/path/to/host/sdk tool/flutterw android assembleRelease
```

- Android key 绑定 Package `app.mileaf.mileaf` + `.cache/android/debug.keystore` SHA1；不要清理该 keystore。
- 当前未配置 key 时构建仍成功；地图加载超时后走路线速写。
- 本次环境 `sandbox-exec` 不可用，Android 验证使用项目内 Gradle 直接编译；没有修改全局 SDK。正式隔离构建仍需在可用沙箱环境复跑。

## 剩余外部 gate

- Android 真实 key 绑定 + 真机真实行程底图/缩放/断网/无定位/审图号。
- iOS 高德 iOS key（Bundle ID `app.mileaf.mileaf`）+ `AmapIosPlatform` 适配；当前 iOS 为 MapKit 过渡，不能算高德双端完成。
- iOS MapKit 真机/模拟器坐标固定点校准与运行时截图。
- 高德配额/许可/隐私政策链接、App Store IDFA/隐私清单。
- iOS 高德适配器尚未实现；当前只有 MapKit 过渡。
