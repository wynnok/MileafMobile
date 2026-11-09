# 地图双端接入实现（Android AMap + iOS AMap）

> 2026-11-09 更新。地图 Key 已改为用户在 App 内填写并仅存本机，见 [ADR 0008](../adr/0008-user-amap-key.md) 与 [实施记录](user-amap-key.md)。下文构建期 Key 注入与命令保留为历史记录。当前操作见 [申请教程](../tutorial/amap-key-application.md) 和 [设置教程](../tutorial/amap-key-settings.md)。

日期：2026-10-31。状态：本地实现与自动化/构建验证完成；双端真实底图、真机与坐标校准仍待外部验证。
本文件记录代码事实，不替代 #4/#11 的外部验收。

## 已实现

- 共享 `MapPanel`：同意、加载/失败、15 秒超时、路线速写、署名/审图号、首屏静态 + 全屏入口。
- 共享 `AmapSceneWire`：两个 Dart 适配器共用同一份 GCJ-02 场景编码、选中签名与 creation params，避免双端 wire 漂移。
- `MapScene`：WGS84 分段、起终点、选中点；缺失点断开；`gcj02Segments` 只在地图边界转换。
- Android：`AndroidView` + Kotlin `TextureMapView`；高德 11.3.100；`OnMapLoadedListener`、`getStatus` 握手、审图号、生命周期、x86 缺失 `.so` 失败兜底。
- iOS：`UiKitView` + Swift `MAMapView`（`AMap3DMap-NO-IDFA` 11.2.100 + `AMapFoundation-NO-IDFA` 1.9.1）；MapKit 过渡已移除。同意后才创建 `MAMapView`；创建前 `AMapServices.enableHTTPS = true`、`apiKey` 注入、`MAMapView.updatePrivacyShow(.didShow, privacyInfo: .didContain)` 与 `updatePrivacyAgree(.didAgree)`。缺 key / 未同意立即 `initFailed`，回路线速写，不崩溃。
- iOS key 绑定 Bundle ID `app.mileaf.mileaf`；`ios/Flutter/AMap.local.xcconfig`（gitignored）→ `MILEAF_AMAP_IOS_KEY` → `Info.plist` 的 `MileafAMapIosKey` → `AMapServices.apiKey`。仓库只保留 example；无 key 时构建可编译，运行时地图走速写。
- 两端 `providerName` 同为「高德地图」；同意按供应商隔离（原 Apple 地图授权不会沿用，也不会复用路线示意授权）。
- 行程详情：整栏 300px hero（左右 12px 页面边距、20px 圆角），点按进入 `DriveMapPage` 全屏缩放；充电详情地图在功率曲线之后 180px 次级，同样 20px 圆角。本次接入把 C05 的地图说明并入 hero 叠加层，并一度把脚注缩短为「路线 · 非导航」；2026-11-01 已按 C05／原型回退为「路线示意 · 非导航」。≥150% 仍由 `if (!large)` 整行不绘制脚注，属待办（见 `collage-drive-detail.md`）。
- 同意：`SharedPreferences` 持久化；设置与服务 → 「地图与隐私」可撤销；撤销后不再创建新原生视图，已加载 SDK 内存状态可能持续到进程结束。
- 删除 `map_candidate.dart`、`flutter_map`、`latlong2`、`mapkit_platform.dart`。

## 验证

- `tool/flutterw analyze`：0 issues；`dart format --set-exit-if-changed`：0 changed。
- `tool/flutterw test`：271 passed，19 skipped（opt-in render；新增 AMap wire 与路线示意隐私测试）。
- `pod install`（项目本地 `CP_HOME_DIR=.cache/cocoapods`）：安装并固定 `AMap3DMap-NO-IDFA 11.2.100`、`AMapFoundation-NO-IDFA 1.9.1`；Podfile.lock 已更新。
- iOS `xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -derivedDataPath build/ios-derived CODE_SIGNING_ALLOWED=NO build` 通过；产物约 74MB；`Runner` 二进制含 `MAMapView`/`AMapServices` 符号，App 内含 `AMap.bundle`。
- iOS Profile 配置 `ios/Flutter/Profile.xcconfig` 也已通过无签名 `xcodebuild -configuration Profile`，避免 profile 构建缺少 AMap 链接。
- 无 key 构建 `Info.plist` 的 `MileafAMapIosKey` 为空字符串；原生侧判定缺 key，地图走路线速写。
- Android `:app:assembleRelease` 通过；APK 124MB，`aapt2` 确认 manifest 含 `com.amap.api.v2.apikey` 占位（本轮为空），`zipalign -c -P 16` 通过。
- 未运行真机底图、审图号读取、CRS 固定点校准、大陆网络与手势/读屏验证；这些属于外部 gate。

## 构建命令与 key

```sh
# 不要把 key 写进仓库或命令输出
cp config/amap.local.env.example config/amap.local.env
cp ios/Flutter/AMap.local.xcconfig.example ios/Flutter/AMap.local.xcconfig
# 分别填入 MILEAF_AMAP_ANDROID_KEY / MILEAF_AMAP_IOS_KEY，不要提交
set -a; . config/amap.local.env; set +a
tool/flutterw android assembleRelease
xcodebuild -workspace ios/Runner.xcworkspace -scheme Runner -configuration Release -sdk iphoneos -derivedDataPath build/ios-derived CODE_SIGNING_ALLOWED=NO build
```

- Android key 绑定 Package `app.mileaf.mileaf` + `.cache/android/debug.keystore` SHA1；iOS key 绑定 Bundle ID `app.mileaf.mileaf`；不要清理该 keystore。
- key 会进入 APK/IPA，这是移动端 key 的固有形态；安全边界是控制台 Package+SHA1 / Bundle ID 绑定，不是“藏 key”。
- `AMapFoundation-NO-IDFA` 排除 arm64 simulator（podspec 自带 `EXCLUDED_ARCHS`）；iOS 地图运行证据必须来自 arm64 真机，模拟器不算有效地图环境。
- 本次环境 `sandbox-exec` 不可用，Android/iOS 验证使用项目内 Gradle / xcodebuild 直接编译；没有修改全局 SDK。正式隔离构建仍需在可用沙箱环境复跑。

## 剩余外部 gate

- 双端真实 key 底图 + 真机真实行程：缩放、起终点、轨迹、断网降级、审图号。
- WGS84→GCJ-02 固定点校准（3 个真实起终点 + 1 段真实轨迹），并核对 AMap 迁移后的视觉对齐。
- 大陆双端验收网络、手势/返回/读屏真机证据。
- 高德控制台隐私政策链接上传、配额/费用确认；App Store 隐私清单与 IDFA 不使用声明。
- #4/#11 保持 OPEN；本文件不把构建成功当作地图验收通过。
