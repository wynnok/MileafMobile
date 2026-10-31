# 高德地图接入方案（双端：Android + iOS）

> 2026-10-30 提案，**等待确认**。本文只做方案，不修改 Spec、tickets、代码，不提交。
> 用户提供的 Android 平台 key 不在本文回显；只在实现时进入本地构建环境。
>
> **2026-10-31 实施结果**：Android 高德 `TextureMapView` 已落地；iOS 因尚无 iOS key，先落 MapKit 过渡；`AmapIosPlatform` 待 key。共享 Dart 外壳/页面/测试已双端共用。
>
> **2026-10-31 双端修正**：这是双端应用，“Android 先行”只是验证顺序，不是最终范围。最终方案是 **共享 Dart 外壳 + Android/iOS 两个薄原生适配器**；iOS 高德需要单独的 **iOS key（绑定 Bundle ID `app.mileaf.mileaf`）**。没有 iOS key 时 iOS 用 MapKit 过渡或路线速写，不能算高德双端完成。

## 先说结论

**可以接高德，但不能把 Android key 填进现有的 XYZ 瓦片模板；也不能只做一个 Android 平台视图就结束。**

当前地图是 `flutter_map` 的“候选渲染器”：只接受一个 HTTPS XYZ 模板；没有配置时直接显示“地图暂不可用：此版本尚未配置底图服务”。高德的 Android key 只对**高德 Android SDK** 有效，不是瓦片 URL；而且高德 SDK 使用 **GCJ-02**，TeslaMate 的经纬度按 **WGS84 假设**处理（固定点校准前不当作已核准）。直接把 WGS84 点画在高德底图上，路线会偏移几百米。

建议：

- **共享 Dart 外壳 + 双端适配器**：Android 用 `AndroidView` + `TextureMapView` + 高德 Android SDK 11.3.100；iOS 用 `UiKitView` + `MAMapView` + 高德 iOS SDK（AMap3DMap）。页面、状态、坐标转换、同意、C 版式完全共用。
- **iOS key 是硬前提**：在同一个高德应用下新增 iOS Key，Bundle ID 填 `app.mileaf.mileaf`；Android key 不能用于 iOS。
- **没有 iOS key 的过渡**：iOS 用 `MapKitPlatform`（Apple 地图，无需 key）保持真实地图；拿到 key 后只替换 iOS 适配器，Dart 页面不变。或者退到路线速写，但那不是“双端地图完成”。
- **行程详情**保持 C 的满幅地图第一视觉；首屏静态预览，点按进入全屏可缩放地图。
- **充电详情**把地图降为次级视觉，放在 SOC 电池弧 + 充入能量/费用之后。
- **兜底**：底图不可用、未授权、无坐标时用 C 风格的“路线速写”。
- **坐标**只在地图边界做 WGS84→GCJ-02，源数据不改；高德双端固定点校准；MapKit 过渡单独校准。
- 先做 **Gate 0a（Android）+ Gate 0b（iOS）**：key 绑定/构建/16KB/pod/真机；通过后再进入产品代码。

## 1. 当前代码事实

| 位置 | 现状 | 结果 |
| --- | --- | --- |
| `lib/main.dart:53` | `MapConfiguration.fromEnvironment()` | 只读取 4 个 `--dart-define` 地图配置 |
| `lib/src/map_candidate.dart:61` | `MILEAF_MAP_TILE_URL` / `ATTRIBUTION` / `CRS` / `SOURCE_CRS` | 没有 URL 就没有 provider |
| `lib/src/map_candidate.dart:224` | `provider == null` 时返回一句文字 | 这就是用户看到的“地图空缺” |
| `lib/src/map_candidate.dart:228` | 只接受 `EPSG:4326`，且要求 provider 的 CRS 与源 CRS 相同 | 高德 GCJ-02 会被直接拒绝 |
| `lib/src/map_candidate.dart:300` | `flutter_map` + `TileLayer` + 专用 `http.Client` | 原生高德 SDK 不经过这条链路 |
| `lib/src/map_candidate.dart:278` | 每个地图组件各自同意一次，展示第三方告知 | 没有持久化，也没有高德隐私声明 |
| C 分支 `drive_detail_page.dart:354` | 行程详情首屏是满幅 `CandidateMap` | C 的位置在，底图是空的 |
| C 分支 `charging_detail.dart:293` | 充电详情地图在 SOC 电池弧之前 | 与 C“电池弧/功率曲线首要”冲突 |
| `test/map_candidate_test.dart`、`test/drive_map_test.dart` | 用可控 HTTP 假瓦片验证缩放、选点、失败 | 只能证明 XYZ 渲染器，不能证明高德 |
| `docs/implementation/map-candidate.md:9` | 明确“未选定正式底图供应商” | #4/#11 外部验收一直待验 |

补充：当前 `main` 是 `7fcc120`，C 的实现不在 main 上；最新 C 代码在 `codex/collage-review-fixes`（`a1e7f60`，基于 `codex/c-visual-refresh` 的 `d4b9d9a`）。实现时应从 C 的最新集成分支起，而不是从 main 起。当前 main 工作区还有未提交的 C 文档，不能 reset/clean，需保留。

## 2. 为什么现有 key 接不上

1. **key 类型不对**：高德 Android 平台 key 绑定的是 Android SDK，不是 XYZ 瓦片服务。高德没有给第三方公开、可授权的 `webrd0x.is.autonavi.com` 瓦片接口；现有 `CandidateMapProvider` 也会拒绝未授权端点。不能把非公开瓦片地址写进 App。
2. **坐标系不对**：高德地图渲染 GCJ-02；TeslaMate 的 `drive_state.latitude/longitude` 是 GPS 坐标，按 WGS84 假设处理。不转换会偏移；转换必须只发生在渲染边界，源数组不变，并用固定校准点证明。
3. **key 绑定包名和签名**：高德 Android key 在控制台绑定 Package 和发布/调试 SHA1。当前包名 `app.mileaf.mileaf`；debug 和 release 都使用 `.cache/android/debug.keystore`。控制台如果登记的是另一份 SHA1，地图就会白屏/不加载。
4. **只有 Android key**：iOS 需要单独的高德 iOS key（Bundle ID 绑定）。没有 iOS key 时 iOS 用 MapKit 过渡或路线速写；这只算过渡，不能算高德双端完成。
5. **架构/ABI**：高德 11.3.100 只带 `armeabi-v7a` / `arm64-v8a`，没有 x86_64；x86_64 模拟器不能作为地图验收环境。11.3.100 的 arm64 `.so` 已核对为 16KB LOAD 对齐；旧的 10.0.600 / 10.1.200 是 4KB，不适合 targetSdk 36 的 16KB 设备。

## 3. 方案总览

```text
DriveDetail / ChargingDetail
        │  只传 WGS84 点、起终点、选中点；不传 session / token
        ▼
MapSurface（C 外壳：布局、状态、同意、署名、失败降级）
  ├─ MapConsent（一次性、可撤销、持久化）
  ├─ RouteSketch（纯 Flutter 路线速写，兜底）
  ├─ AmapView（仅 Android）
  │    └─ MethodChannel ── TextureMapView（GCJ-02）
  └─ MapChrome（标签、展开、署名/审图号、重试）
```

- **一个地图引擎，不做供应商切换 UI**。高德是正式供应商；没有配置/不支持时走兜底，不显示第二个地图源。
- **平台视图不碰业务网络**：`MapSurface` 的输入只有坐标、颜色、夜间模式和交互开关；没有任何 `SiteSession`、`Authorization`、API client 参数。底图请求由高德 SDK 自己发，结构上不可能夹带站点 Bearer。
- **Dart 侧删除 `flutter_map` / `latlong2`**（迁移完成后），换成纯 Flutter 的路线速写 + 原生视图。净效果是少两个 Dart 依赖，多一个 Android 原生 SDK。

### 坐标流

```text
TeslaMate lat/lon（WGS84）
  → MapCoordinate（保持源值，不修改）
  → Gcj02.fromWgs84（仅 AmapView 边界）
  → 高德 LatLng（GCJ-02）
```

- 中国大陆内按标准 WGS84→GCJ-02 转换；境外点不做偏移（高德境外覆盖有限，单独标注“境外不保证”）。
- 缺失、非有限、越界坐标不转换、不连线；分段逻辑沿用现有语义。
- 校准：固定 3 个真实起终点 + 1 段真实轨迹，对比高德官方转换/真机叠加结果，误差阈值和证据写入 #4；不靠“看起来在路上”。

## 4. 与 C「数据拼贴」的冲突和解决

| C 的条款 | 冲突 | 解决 |
| --- | --- | --- |
| “不新增地图供应商或切换 UI”（C 734）、“不新增地图供应商/坐标转换规则”（C 797） | 用户现在明确要接高德 | 新增 **ADR 0002**：高德 Android 作为首个正式底图供应商；只取代这两句的范围限制，C 的版面/配色/层级不变。仍然不做供应商切换 UI。 |
| “地图可缩放”（C 731） | 原生地图手势会和详情页纵向滚动冲突 | 详情首屏地图是**静态预览**（`IgnorePointer`），点按进入**全屏地图**；全屏里缩放/平移。C05 改写为“首屏地图可点开全屏缩放”。 |
| “充电详情以 SOC 电池弧/功率曲线为首要”（C 692） | 当前 C 分支把地图放在电池弧之前 | 把地图移到“充入能量/费用/时长”之后，高度约 180px，单点标记；电池弧和功率曲线仍是首屏主角。 |
| “技术口径进数据说明层”（C 749） | 高德要求可见署名/审图号 | 保留一条**极短的**地图署名/审图号（地图右下角），把“地图数据说明/隐私/供应商”收进“数据说明与更多 > 地图与隐私”。署名是法律要求，不算技术元数据堆首屏。 |
| “不新增设计系统依赖/字体/图表库”（C 798） | 要加高德原生 SDK | 这是地图能力依赖，不是设计系统依赖；C 的 token、字体、自绘图表不动。迁移后反而移除 `flutter_map`/`latlong2`。 |
| “双端”与 #11 的双端验收 | Android key 不能用于 iOS | 双端架构保留：Android/iOS 各一个薄适配器；iOS 需要单独 iOS key（Bundle ID `app.mileaf.mileaf`）。没有 key 时 iOS 用 MapKit 过渡或速写；**不关闭 #11**，不把 Android-only 当最终方案。 |
| “列表路线 tile”（C 641） | 列表如果每行都加载地图，会消耗配额、拖慢滚动 | 列表/概览/统计**不调用地图 SDK**；列表继续用静态路线速写/现有缩略表达。只有两类详情加载底图。 |
| “无 GPS / 不夹带站点 token”（Spec 241、#11） | 高德 SDK 自采集 | 不申请定位权限、不初始化定位/搜索组件；不传站点 token。隐私声明按 SDK 实际能力写，不写“无数据采集”。 |

## 5. 页面与交互

### 5.1 行程详情首屏

```text
┌──────────────────────────────────┐
│ [地图]                      [⤢]  │  ← 小标签 + 展开
│                                  │
│        高德底图 / 路线速写         │  ← 满幅，约屏高 36%，圆角 22
│                                  │
│    ● 起点 ─────────── ● 终点      │
│   © 高德地图  GS(...)号           │  ← 右下角，始终可见
├──────────────────────────────────┤
│ 家 → 公司                         │
│ 10-30 08:12 → 08:38               │
│ ┌────────┬────────┬────────┐     │
│ │12.4 km │26 分钟 │1.8 kWh │     │
│ └────────┴────────┴────────┘     │
│ 行程电量区间 / 个人参照 / 曲线 …   │
└──────────────────────────────────┘
```

- 地图满幅、无页面左右 padding；下缘 22px 圆角，和 C 的 tile 语言一致。
- 平台视图的圆角：优先 `ClipRRect`；若 Android 平台视图不被裁剪，用纸面四角遮罩/细边框实现同样的 C 圆角视觉，不改成方角卡片；遮罩不能盖住高德 logo。
- 地图上只保留：左上“地图”标签、右上展开、右下署名/审图号；**移除**当前首屏的“授权底图测试来源”“地图数据说明”展开条和缩放按钮，这些移到全屏或数据说明层。
- 首屏地图不支持拖动/缩放（避免滚动被抢）；点地图或展开进入全屏。
- 深色模式用高德夜间地图；浅色用普通地图。地图自身颜色不替代 C 的湖畔 token。

### 5.2 全屏地图

- 新页面 `DriveMapPage`：AppBar“行程地图”，全屏 `TextureMapView`，起点/终点/选中采样、轨迹分段、视野适配。
- 底部右下角：适配轨迹、放大、缩小；图标按钮 44px 点击区；署名/审图号保留。
- 平台视图 z-order：Flutter overlay 控件需在真机确认浮在地图之上；若被原生视图盖住，把控件移到地图外的底部栏，不改变 C 的阅读顺序。
- 只读，不是导航；不请求 GPS，不显示定位蓝点。
- 返回详情时保持当前选中采样；详情图表选点变化后，首屏地图的选中标记同步更新。

### 5.3 充电详情

```text
地点名称
SOC 电池弧（hero）
充入 32.4 kWh · ¥28.6 · 42 分钟
[ 充电地点地图 180px · 单点标记 ]   ← 次级，不是首屏主角
功率/电量曲线
电网侧 / 入电 / 环境 …
```

- 有坐标：单点地图，点击可进全屏地点图（可选）；无坐标：`未记录充电地点` 的纸面 tile，不画空地图。
- 地图失败不影响 SOC、能量、费用、曲线。

### 5.4 同意与隐私

首次进入任一带地图的详情，不直接创建原生地图；先显示路线速写 + “启用高德地图”按钮。点按弹出 C 风格底部 sheet：

```text
地图由高德地图提供
加载后会向高德发送 IP、设备/网络信息和当前地图范围。
不会发送行笺站点凭据，也不会读取手机定位。
[查看高德隐私政策]  [暂不]  [允许加载]
```

- 同意后持久化到 `SharedPreferences`（现有依赖），后续详情直接加载。
- “数据说明与更多 > 地图与隐私”提供：供应商、发送什么、不发送什么、撤销、隐私政策链接、审图号。
- 撤销后不再创建地图视图；高德 SDK 已加载的内存状态可能持续到进程结束，界面明确写“下次启动完全停止”。不假装能热卸载原生 SDK。
- 高德控制台要求上传 App 隐私政策链接；如果暂无公开链接，这是上架/合规的外部 gate，不阻塞个人本地验证。

### 5.5 兜底：路线速写

- 纯 Flutter `CustomPainter`，纸面/深色纸面 + 极淡网格；按点集归一化画分段线、起点/终点/选中点；不画假道路、假地名。
- 明确标注“路线示意 · 底图未启用”或“底图暂不可用 · 重试”。
- 0 点：显示“没有有效轨迹坐标”；1 点：单点标记；缺失点：断开，不跨缺口连线。
- 200% 字号：标签换行，不横向裁切；速写高度随容器，不挤压下方结果。

## 6. 技术设计

### 6.1 双端接入方式

**共享 Dart 外壳 + 两个平台适配器**，不把 `amap_map` 插件放进 `pubspec.yaml`：

| 方案 | 优点 | 风险 | 建议 |
| --- | --- | --- | --- |
| **自建双端平台视图（首选）** | 双端同一套 UI/状态/测试；Android 可用 11.3.100；iOS 可用最新 AMap3DMap；不依赖旧插件 | 需要 Kotlin + ObjC/Swift 两个薄适配器；平台视图裁剪/z-order 要双端确认 | 推荐 |
| `amap_map` 插件 | 一套 Dart API 双端；覆盖物/相机 API 全；接入快 | 固定 10.1.200（Android 4KB 对齐）；1.0.15 约 19 个月未更新；AGP 9 未知；`onMapCreated` 要等 `waitForMap`，dispose 有悬挂风险 | 仅当自建视图被 Gate 0 证明成本过高时备选 |
| Android 平台视图 + iOS 速写 | 实现最快 | **不是双端地图**；iOS 没有真实底图 | 仅 iOS key 未到位时过渡 |
| 现有 `flutter_map` + 高德非公开瓦片 | 改动最小 | 未授权、非公开端点，违反现有供应商边界 | 不采用 |

- Android 适配器：`AmapViewFactory` / `AmapView`，`TextureMapView`，`MapsInitializer.updatePrivacyShow/Agree` 后才创建；创建失败（含 x86_64 无 `.so`）捕获 `Throwable`，回传 `onMapFailed`。
- iOS 适配器：`AmapIosViewFactory` / `AmapIosView`，`MAMapView`，`MAMapView.updatePrivacyShow/Agree` + `AMapServices.shared().apiKey` 后才创建；`mapViewDidFinishLoadingMap` 作为加载信号，`mapContentApprovalNumber` 回传审图号。
- 两端共用同一个 `MethodChannel` 契约：`getStatus` / `setScene` / `setSelected` / `setNight` / `setInteractive` / `fitBounds` / `zoomIn` / `zoomOut`；native→Dart `onMapLoaded` / `onMapFailed`。
- 首屏 `UiSettings`/`MAMapView` 关闭 scroll/zoom/rotate/tilt/compass/scale/location button；全屏打开 scroll/zoom，仍关闭定位蓝点和 POI 点击。
- 标记用各自原生 Canvas 生成小圆点位图（起点湖绿、终点深墨、选中琥珀），不引入图片资源。
- 地图背景设成纸面色，避免加载前黑屏。

**iOS key**：同一个高德应用下新增 iOS Key，Bundle ID `app.mileaf.mileaf`；通过 `--dart-define=MILEAF_AMAP_IOS_KEY=...` 传入，不写仓库。没有 key 时 `defaultMapPlatform()` 选 `MapKitPlatform()` 或 `SketchPlatform()`，不创建 `MAMapView`。
- 已知问题：`amap_map` README 提到 targetSdk >= 30 地图页返回闪退，可用 `allowNativeHeapPointerTagging=false` 规避；本轮不预置这个削弱安全缓解的开关，Gate 0 真机复现后再评估。

### 6.2 key 配置

- **不写入仓库、Dart 源码、文档或提交信息**。
- Android：通过环境变量 `MILEAF_AMAP_ANDROID_KEY` 注入 Gradle `manifestPlaceholders`，落到：

```xml
<meta-data
    android:name="com.amap.api.v2.apikey"
    android:value="${amapApiKey}" />
```

- iOS：在同一个高德应用下新增 **iOS 平台 Key**，Bundle ID 填 `app.mileaf.mileaf`；通过 `--dart-define=MILEAF_AMAP_IOS_KEY=...` 传给 `AmapIosPlatform`，再由 creation params 交给原生 `AMapServices.shared().apiKey`。**Android key 不能用于 iOS。**
- 不能用 `android/local.properties`：`tool/flutterw` 每次构建都会重写该文件，只保留 sdk/flutter 版本字段。
- 缺省为空时构建仍应成功；地图加载超时后走路线速写，不崩溃。
- 本地把 `MILEAF_AMAP_ANDROID_KEY=...` / `MILEAF_AMAP_IOS_KEY=...` 放在未跟踪的 `config/amap.local.env`（chmod 600），构建前 `source`，不 `echo`；`.gitignore` 增加该路径。key 不进文档、仓库、提交或命令输出。
- 客户端 key 会进入 APK/IPA，这是高德移动端 key 的固有形态；安全边界是控制台的 Package + SHA1（Android）/ Bundle ID（iOS）绑定，不是“把 key 藏起来”。不要使用服务端 key。
- `.cache/android/debug.keystore` 是当前 debug/release 的签名来源；不要清理它。若必须更换签名，先在控制台补登新的 SHA1，否则地图会失效。

### 6.3 版本、ABI 与体积

- 高德 Android **11.3.100**（`com.amap.api:3dmap-location-search:11.3.100_loc11.3.101_sea9.8.1`）；iOS **AMap3DMap** 最新稳定版（Gate 0b 固定并记录版本）。
- Android 11.3.100 的 arm64 `.so` LOAD 对齐为 `0x4000`（16KB），满足 targetSdk 36 的 16KB 要求；10.0.600、10.1.200 为 `0x1000`，不采用。
- Android 只有 `armeabi-v7a` / `arm64-v8a`；没有 x86_64。x86_64 模拟器上地图会走失败兜底，真机验收必须用 ARM64 手机。
- iOS 支持 iOS 15+；`AMap3DMap` / `AMapFoundation` 走项目级 CocoaPods；模拟器架构和真机能力在 Gate 0b 验证。
- 体积：Android SDK jar 约 36MB，arm64 地图 `.so` 约 33MB；iOS framework 也会明显增大 IPA。release 用 Android ABI split（至少 arm64）；具体在 Gate 0a/0b 量测后决定。
- 混淆：Android 如 release 开启 R8，按高德官方要求保留 `com.amap.api.maps.**`、`com.autonavi.**`、`com.amap.api.trace.**`；iOS 按 framework 方式链接，不做额外混淆。

### 6.4 失败与超时

- Android `OnMapLoadedListener` / iOS `mapViewDidFinishLoadingMap` 触发后回传 `onMapLoaded`；Dart 侧 15 秒未收到则显示“底图加载较慢/暂不可用”，保留重试。
- iOS 的 `mapInitComplete` 只代表初始化完成，不能单独当成加载成功；必须等 `mapViewDidFinishLoadingMap` 或超时。
- 地图加载中：纸面骨架盖在原生视图上，避免白屏；下方结果照常可读。
- 失败：切到路线速写 + “重试底图”，不把原生白屏留在页面上；重试重建视图。
- 网络恢复后重试；切车/退出详情后旧回调按 generation 丢弃，不覆盖当前车。
- 网络安全：Gate 0a/0b 用抓包/日志确认高德 SDK 请求协议；若存在 cleartext，只对高德域名做白名单，不开全局 `usesCleartextTraffic`。

### 6.5 测试缝

C 的既有测试缝是 App + 可控 HTTP；高德原生网络无法由该缝驱动。新增一个**平台边界缝**，只用于地图：

- `MapCanvas` 接收一个 `MapPlatform` 接口；生产用 `AmapAndroidPlatform`/`AmapIosPlatform`，测试用 `FakeMapPlatform`，记录收到的 GCJ-02 点、夜间模式、交互开关，并可模拟 `loaded/failed`。
- `Gcj02.fromWgs84` 是纯函数，直接单测；不通过 widget。
- App/HTTP 测试继续验证：详情数据到达、地图输入正确、失败不遮结果、无 token 进入地图参数。
- 真实高德渲染只由 Android/iOS 真机或 iOS 模拟器截图证明；Flutter 渲染测试只证明地图外壳/兜底/同意/200%/浅深色，不能冒充真实底图。

这个例外要写进 Spec 的 Testing Decisions，并说明为什么它不是“私有 widget 测试缝”。

### 6.6 性能

- 现有 `mapRequest` / `mapFirstTileDecoded` / `mapFailed` 三个点保留语义：
  - `mapRequest`：创建原生视图；
  - `mapFirstTileDecoded`：`onMapLoaded`（Android `OnMapLoadedListener` / iOS `mapViewDidFinishLoadingMap`；注意：是“地图可见”，不是解码单张瓦片，协议要改名或注释）；
  - `mapFailed`：超时/创建失败。
- 详情帧就绪仍不等待底图（Spec 305：详情不计第三方底图）；地图首图单独计时。
- 不新增轮询、不预加载列表地图、不缓存业务坐标到磁盘。

## 7. 实施切片

| 切片 | 内容 | 通过条件 |
| --- | --- | --- |
| **S0a Android Gate（先做，不写产品 UI）** | 加高德 Android 依赖、manifest 占位、最小 probe；release 构建 + ARM64 真机打开一张真实行程 | key 绑定正确、地图真实显示、16KB/ABI/AGP 9 通过、无 x86 崩溃；失败则停止报告，不进入 S1 |
| **S0b iOS Gate（先做，不写产品 UI）** | 新增 iOS Key（Bundle ID `app.mileaf.mileaf`）+ `AMap3DMap` pod + 最小 `MAMapView` probe；`pod install` + `build ios --release --no-codesign` + iOS 15 模拟器/真机 | key/Bundle ID 正确、pod/Xcode 构建通过、真实底图/审图号可读；失败则先用 MapKit 过渡或停止 |
| **S1 共享地图外壳** | `geo`/`map_scene`/`map_consent`/`map_platform`/`sketch`/`map_canvas` + Fake 测试；行程 hero + 全屏地图页面 | 纯 Dart/Widget 测试通过；双端页面结构一致；无 SDK |
| **S2 Android 适配** | `AmapAndroidPlatform`、`TripMapHero`、`DriveMapPage`、详情接入 | 真实路线/起终点/选中、浅深色、200%、失败兜底 |
| **S3 iOS 适配** | `AmapIosPlatform`（或 `MapKitPlatform` 过渡）、同一套页面 | 真实底图、路线/标记/夜间、加载/失败、200%；与 S2 并行 |
| **S4 充电与隐私** | SOC/能量之后的 180px 地点图；持久化同意、撤销、地图与隐私页、署名/审图号；移除 `map_candidate.dart`、`flutter_map`、`latlong2` | 双端单点/无点/失败；无 token、无 GPS、无旧地图引用；同意/撤销可复验 |
| **S5 双端验证与收口** | 全量测试、渲染、Android/iOS release、双端真机/模拟器、双轴审查、文档 | 见第 8 节；#4/#11 在双端证据齐全前保持 OPEN |

实现分支：从 `codex/collage-review-fixes` 起新分支（例如 `codex/amap-map`），在独立 worktree 做；当前 main 工作区未提交的 C 文档保留，不 reset/clean，不把无关文档混进地图提交。

## 8. 验证与证据

**自动化**

- `Gcj02`：北京/上海/深圳固定点，境外点不偏移，非法值不转换；误差阈值 + 来源写入测试注释。
- `MapCanvas`：未同意不创建引擎；同意后引擎收到 GCJ-02；缺失点分段；失败保留结果；重试；切车 generation 隔离；200%/浅深色无溢出。
- App/HTTP：行程/充电详情数据与地图输入一致；地图参数不含 token/session；地图失败时结果/曲线仍可见。
- 渲染：360×800、100%/200%、浅/深色，覆盖同意、加载、正常（速写）、失败、无坐标；真实底图截图另存双端真机/模拟器证据。

**构建/设备**

- Android：`tool/flutterw android assembleRelease`（或既有等价入口）通过；APK 内含 arm64 `libAMapSDK_MAP_v11_3_100.so`，16KB 对齐。
- Android ARM64 真机：真实站点数据、真实行程、缩放/平移、深色、断网/飞行模式、无定位权限、返回/重进、切车、署名/审图号。
- iOS：`pod install` + `tool/flutterw build ios --release --no-codesign` 通过；iOS 15 模拟器/真机显示真实底图、路线/标记/夜间、审图号；Bundle ID/key 正确。
- iOS 过渡：如果暂时没有 iOS key，MapKit 真实底图 + 坐标固定点 + C 外壳单独记录，明确标注“过渡”，不能当作高德双端完成。
- 不从透明测试瓦片、纯速写截图或未配置 key 的构建宣称地图通过。

**外部 gate（保持 OPEN）**

- 高德控制台 Package/SHA1 绑定、配额/费用、服务条款、隐私政策链接上传。
- 中国大陆运营商网络、真实设备型号/OS、首图耗时/成功率。
- iOS key 与 iOS 地图。
- 用户视觉评审（C05 地图 hero + 充电层级）。

## 9. 文档与 ticket 影响

| 文档/票 | 要做什么 |
| --- | --- |
| `docs/adr/0002-amap-map-provider.md` | **新增**：高德 Android + iOS 作为正式底图；共享 Dart 外壳 + 两个薄原生适配器；WGS84→GCJ-02 边界转换；C 版面不变；不做供应商切换 UI |
| `docs/specs/mobile-v1.md` | **追加**“2026-10-30 地图接入增量”：Provider、双端适配器、iOS key、坐标、隐私、全屏交互、充电层级、失败兜底、测试缝例外、Out of Scope、ticket impact；同时明确取代 C 增量里“不新增地图供应商/坐标转换规则”的两句 |
| GitHub Spec #1 | 同步上述增量；保持 `ready-for-agent`，不新建产品 Spec |
| #4 底图与坐标技术验证 | 改为“高德 Android 11.3.100 + iOS AMap3DMap 技术验证”：双端 key 绑定、16KB/ABI、pod/构建、真机、坐标校准；保持 OPEN |
| #10 行程详情 | 首屏地图改为高德/速写 + 全屏地图；移除首屏测试来源/控件/说明条；双端同一套页面；保持 OPEN |
| #11 地图集成 | Android + iOS 高德实现、双端 key/隐私/署名/审图号/真机证据；iOS key 未到位时 MapKit 过渡不算完成；保持 OPEN |
| #13 充电详情 | 地图移到 SOC/能量之后，180px 次级；无坐标/失败兜底；保持 OPEN |
| #16 性能 | `mapRequest`/`mapLoaded`/`mapFailed` 语义；地图仍不计入详情帧；保持 OPEN |
| #17 集成验收 | C05/UX07/UX12 增加 Android + iOS 真实地图证据；iOS key 未到位时明确标注 MapKit 过渡；保持 OPEN |
| `docs/implementation/map-candidate.md` | 标注“已被高德双端方案取代，保留为历史”；不删除 |
| `docs/implementation/amap-map.md` | **新增**：双端实现、key 配置、构建/真机证据、剩余 gate |
| `docs/implementation/performance.md` | 更新地图计时点与“不计详情帧”的口径 |
| `AGENTS.md` | 追加当前地图决定（高德双端、iOS key、坐标/隐私/兜底） |
| `docs/implementation/final-verification.md`、`owner-integration-verification.md` | 地图 gate 从“供应商未选定”改为“Android 高德已验/待真机、iOS 高德或 MapKit 过渡分别记录” |

**0 张新票**：地图接入属于 #4/#11/#10/#13/#16/#17 的既有范围；不新建“地图重做”平行票。

## 10. 需要确认

1. **平台范围**：接受 **Android + iOS 共享 Dart 外壳、各一个薄原生适配器**吗？iOS 高德需要在[高德控制台](https://console.amap.com/dev/key)同一个应用下新增 **iOS Key**，Bundle ID 填 `app.mileaf.mileaf`。
   ➡️ 推荐：接受。没有 iOS key，iOS 端不可能显示高德底图；Android key 不能代替。
2. **iOS 过渡**：如果 iOS key 短期拿不到，接受 iOS 先用 **MapKit 真实地图**（Apple 地图，无需 key，样式与高德不同）过渡，还是先用路线速写？
   ➡️ 推荐：MapKit 过渡；拿到 key 后只替换 iOS 适配器，Dart 页面不变。
3. **Android key 绑定**：请在控制台确认这个 Android key 绑定的是：
   - Package：`app.mileaf.mileaf`
   - SHA1：`2E:F7:D4:1A:6A:29:91:25:D7:EB:DB:1E:2D:BC:2F:91:8C:C6:DD:6B`（当前项目 `.cache/android/debug.keystore`，debug/release 都用它）

   如果控制台登记的是另一份 SHA1，地图会白屏；需要把上面这个 SHA1 加到调试/发布两栏。
   ➡️ 这是 Gate 0a 的第一件事。
4. **交互**：接受“首屏静态地图 + 点按全屏缩放”吗？还是坚持首屏直接拖动/缩放（会与页面滚动冲突）？
   ➡️ 推荐：静态首屏 + 全屏交互，双端一致。
5. **充电顺序**：接受把充电地图移到 SOC/能量之后、高度约 180px 吗？
   ➡️ 推荐：是，SOC/功率仍是首屏主角。
6. **依赖/体积**：接受移除 `flutter_map`/`latlong2`、加 `url_launcher`，并接受高德 SDK 带来的 APK/IPA 增长；Android release 用 ABI split（至少 arm64），且不把 x86_64 模拟器当作地图验收环境吗？
   ➡️ 推荐：接受；Gate 0a/0b 量测后再定 split 细节。
7. **Gate**：接受 **Gate 0a（Android）+ Gate 0b（iOS）** 先行吗？
   ➡️ 推荐：接受。任一 Gate 失败，先解决 key/构建，不先写产品 UI。

确认后顺序：**Gate 0a/0b → ADR 0002 + Spec 增量 + tickets 映射 → S1 共享外壳 → S2/S3 双端适配（并行） → S4 充电/隐私 → S5 双端验证/审查**。

## 11. 参考

- [高德 Android 获取 Key（Package/SHA1 绑定）](https://developer.amap.com/api/android-sdk/guide/create-project/get-key)
- [高德 iOS 获取 Key（Bundle ID 绑定）](https://developer.amap.com/api/ios-sdk/guide/create-project/get-key)
- [高德 Android 开发注意事项（隐私接口、权限、混淆）](https://developer.amap.com/api/android-sdk/guide/create-project/dev-attention)
- [高德 SDK 合规使用方案](https://developer.amap.com/compliance-center/check-and-reference/sdkhgsy)
- [高德 Android 坐标转换](https://developer.amap.com/api/android-sdk/guide/computing-equipment/coordinate-transformation)
- [高德 iOS 地图 SDK](https://developer.amap.com/api/ios-sdk/summary)
- [高德 Maven 11.3.100](https://repo1.maven.org/maven2/com/amap/api/3dmap-location-search/)
- [Android 16KB 页面大小](https://developer.android.com/guide/practices/page-sizes)
- [amap_map（备选，不首选）](https://pub.dev/packages/amap_map)
- 现有实现：[map_candidate.dart](../../lib/src/map_candidate.dart)、[map-candidate.md](../implementation/map-candidate.md)
