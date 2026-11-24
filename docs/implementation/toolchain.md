# T01 双端启动与服务健康检查

## 当前构建门槛

2026-10-23 用户批准进程沙箱验证，并进一步批准仅本项目 iOS 改用已安装 CocoaPods。Android `assembleDebug` 与 iOS release 无签名构建均已在 outer 沙箱中完整退出0，输入 hash 不变且 SDK 路径始终项目内。Gradle 不复用沙箱外 daemon；CocoaPods home/cache/spec repo 和 RubyGems spec cache 均位于项目。入口需明确受保护的主机 SDK 路径；命令、失败根因与证据见[构建隔离记录](build-isolation.md)。

SwiftPM 嵌套沙箱失败与 Xcode 局部参数被拒的证据仍保留；项目级 CocoaPods 配置避免该嵌套，不修改 HOME、全局配置或原版 SDK。`run/install/drive` 等设备执行入口尚未验收，继续退出78。双端真机、安全存储、实际网络和地图等外部验收仍待完成，不能用构建结果代替。

## 固定工具链与边界

- Flutter stable **3.47.7**，revision `abaf9c523780a608bd46686fd5e53740a07077f8`；Dart **3.13.5**。工程 `.metadata` 和 `pubspec.lock` 纳入版本管理。
- Android 最低 API **24**，compile/target **36**，使用项目 SDK platform 36、build-tools 36.0.0；JDK 取**环境变量 `JAVA_HOME` 的值**（不写死绝对版本路径；2026-11-20 起本机为 Temurin **25.0.5.1**，此前验证记录用的是 Zulu **21.0.10**）、Gradle **9.3.1**、AGP **9.1.0**（Flutter 锁定版本模板）。Flutter/AGP 构建要求 NDK **28.2.13676358**，固定该版本及 CMake **3.22.1** 并仅允许安装于项目 SDK。
- iOS deployment target **15.0**，本机验证 Xcode **27.1 (27A9275)**、CocoaPods **1.17.0**。仅项目级停用 SwiftPM；不提高最低系统版本。
- `tool/flutterw` 从工程根执行并将 Pub、Gradle、Android user、XDG、编译模块缓存放入本工程。默认 SDK 位于 `.tooling/flutter`、`.tooling/android-sdk`；既有项目内 SDK 可通过 `MILEAF_FLUTTER_SDK` / `MILEAF_ANDROID_SDK` 指定。不安装全局工具。
- 首次准备 Flutter 使用对应 revision 的项目内 checkout；Android 使用已许可、兼容的项目内 SDK，不改全局 SDK。签名材料不纳入版本控制；debug keystore 位于 `.cache/android`。当前 Android release 使用开发签名，仅用于研发验证，不是商店交付。

## 常用命令

在本工程运行 `tool/flutterw pub get` 后，使用以下命令。原生构建还需设置 `MILEAF_HOST_ANDROID_SDK=/path/to/existing/host/sdk`（或继承原先指向主机 SDK 的 ANDROID_HOME），沙箱明确保护该路径；项目 SDK 自定义仍使用 MILEAF_ANDROID_SDK：

- `tool/flutterw dart format --output=none --set-exit-if-changed lib test`
- `tool/flutterw analyze`
- `tool/flutterw test`
- `tool/flutterw android assembleDebug`（研发 APK）；`tool/flutterw android assembleRelease`（开发签名 release）。JDK 由**调用方环境里的 `JAVA_HOME`** 提供，入口不改写它；先确认 `"$JAVA_HOME/bin/java" -version` 可执行。切换 JDK 后，在当前构建进程中核对 `JAVA_HOME` 指向所选安装。Flutter `build apk` 会优先发现 IDE 的 JBR，因此不将该入口作为既定 JDK 的验证命令。
- `tool/flutterw build ios --release --no-codesign`

工具链和缓存均被忽略；只提交源码、契约及依赖锁文件。工程入口 `MileafApp(client: ...)` 接受系统边界 HTTP client；生产默认使用正常证书校验的 Dart IO client，连接超时 5 秒。统一 API 入口使用 15 秒总时限（含响应头与响应体），超时中止 HTTP 请求，无自动重试或自动重定向。

## 后端契约

固定后端 `146cb3b9a16af3d632b04ed8d197d0f2243d9b71`。该提交晚于 Spec 阅读快照，实际导出的 OpenAPI 与来源元数据一并保存到契约目录。导出只创建 FastAPI 应用并读取 schema，没有启动 lifespan、访问数据库或改动外部仓库。

- health 为匿名 `GET /v1/health`。OpenAPI 声明 `object<string,string>`，实际运行时成功为 `status=ok` 和包版本 `version`；客户端验证这两个字段，额外字段兼容。错误不能解码成成功。
- 业务接口使用 Bearer；health 与 auth 匿名。登录与携带凭据请求须禁重定向；此切片所有请求已禁重定向。
- OpenAPI 3.1 用 null 联合类型表达可空；序列未请求字段可省略，已请求字段可为 null。不能把缺失指标转为 0。
- 运行时错误结构为 `error.code` / `error.message`，并提供 `X-Request-ID`；OpenAPI 未完整列出所有运行时错误。需兼容非 JSON 反代错误，状态码与稳定错误码为主要依据。
- 业务 GET 支持 ETag/304；304 无响应体。后续缓存切片必须按完整站点/会话/车辆/查询键关联已授权响应；无体缓存不能将304当作空成功。
- stats 的 driving / charging 响应为联合结构，必须按 kind 分支读取 totals/buckets；不能平均桶比率。本文记录下游约束，不预先实现这些端点。

## 本切片验证结果与待验

2026-10-22：12 个 HTTP 驱动完整 App 操作测试通过，覆盖反代端口/路径、已有 v1 前缀、无效地址不发请求、HTTPS 限定、健康成功/503恢复、网络与证书错误、15 秒总时限、360逻辑像素/200%字体和系统浅深色。Dart 格式和静态分析通过。iOS release 无签名构建成功（Runner.app 16.2MB）。Android SDK36 的 `assembleDebug` 成功（55 tasks，1m9s），SDK/NDK/CMake/Gradle缓存及开发签名均在项目内。

未取得真实用户站点或双端设备；App 操作测试使用可控 HTTP 契约响应；iOS 构建不等于已安装或实际网络栈验收。受控真实 HTTPS 联通已补验：实际 FastAPI 服务 + 隔离 PostgreSQL 16 夹具 + 独立测试 CA，生产 Dart `MileafApi`/`IOClient` 经正常证书链及主机名校验返回 `HEALTH_OK version=0.1.0`。测试 CA 仅在测试客户端上下文信任，未改变生产信任；首次自签 leaf 被正确拒绝。容器和证书已清理。该证据不是双端真机或真实用户站点验收，设备正常证书链/无效证书拒绝及最低系统运行仍待外部条件。这些是历史切片证据；当前双端构建隔离门槛以本页开头及构建隔离记录为准，不据此关闭待验 Ticket。全 Spec 的真机网络/最低系统/安全存储等仍由对应后续验收承担。

T01 基线拒绝 HTTP；后续安全网络切片的逐站点授权、局域网指引与验收门槛见 [安全网络记录](network-security.md)，不依赖 debug 明文放行。不请求手机定位权限，也不记录地址输入、口令或完整 HTTP 响应。

### Android SDK 隔离修正

Flutter 源码优先读取存在的旧式 home 配置；只设置 `XDG_CONFIG_HOME` 不能保证隔离。初次 `flutter build apk` 实际准备向主机 SDK 安装 NDK，但当时未记录旧配置存在性，不断言其为唯一原因；立即停止后仅产生 `.installer/.installData`。已核验并可逆迁回项目 `.cache/host-recovery/ndk-28.2.13676358`，主机版本目录已不存在，没有修改其他 SDK 或全局配置。

候选 Android 构建入口曾为 `tool/flutterw android <Gradle task>`，显式写入项目局部 `local.properties` 后直接执行纳入版本控制的 Gradle wrapper。后续验证已证明 Flutter 子进程仍能重写此路径，当时因此停用入口；该方式自身没有解决隔离问题。当前双端构建入口增加了已验证进程沙箱，iOS 仅按用户新增批准使用项目级 CocoaPods。不覆盖 HOME 或调用全局 `flutter config`。首次诊断曾用 `-Pandroid.builder.sdkDownload=false` 核实 NDK 为必要构建依赖，然后才允许在项目 SDK 下载。

SDK37 曾用于首轮编译探测，但 AGP9.1 官方已测最高36.1，最终收敛到 Flutter 模板的 compile/target36，不压制兼容性警告；所需 platform36 仅安装于项目 SDK。

### 当前集成候选的回归结果

合入 `4450a76` 的站点认证与安全存储后，35 个 App 行为测试、静态分析与格式检查通过；在相同冻结的外层保护下，顺序完成 iOS release 无签名（17.2MB）和 Android release 研发签名（约50MB）构建，完整 wrapper 均退出0，SDK 路径不变。具体证据和未覆盖的真机边界见[构建隔离记录](build-isolation.md)。

首版最后产品代码 `11cdd040` 的 135 项回归、两轴独立复核及双端 release 构建证据见[最终验证](final-verification.md)。外部验收仍按[验收矩阵](acceptance.md)保持待验。
