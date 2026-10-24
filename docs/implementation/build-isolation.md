# 构建进程隔离验证（2026-10-23）

## 当前结论

Android 的 `tool/flutterw android assembleDebug` 与项目级 CocoaPods 的 `tool/flutterw build ios --release --no-codesign` 均已在 macOS 进程沙箱下完成，完整 wrapper 退出 0，SDK 路径保持项目内。双端真机网络、安全存储与地图等外部验收仍待验，不据编译结果关闭这些 Ticket。

用户已批准此轮验证，不修改 HOME、全局 defaults、shell 配置或原版 Flutter 源码，随后用户另行明确批准仅本项目 iOS 依赖管理改用已安装 CocoaPods；该变更不涉及 Flutter/Dart 或全局设置。SDK、依赖、缓存、日志和产物均沿用项目位置。

## 两次旧方案失效的原因与证据边界

1. Flutter 原生入口曾将 `local.properties` 的 `sdk.dir` 写成主机 SDK，并准备安装 NDK。只设置 `ANDROID_HOME` / `XDG_CONFIG_HOME` 未构成进程隔离。Flutter 源码确实优先读取**存在**的旧式 home 配置，但当时没有保留配置文件存在性证据，不能把它断言为唯一原因；本轮实际检查 `~/.flutter_settings` 不存在。误写的 NDK 安装临时元数据已由此前恢复流程可逆迁入项目，未修改其他既有 SDK。
2. 直接 Gradle、预写 `local.properties` 和按顺序构建仍不能约束后续 Flutter 子进程的重新选址或写入；共享文件的正确初值不能约束后写者。此外，已有 Gradle daemon 可能不属于新进程树，必须避免复用。这些是旧入口未提供的约束，不能用一次编译成功替代隔离证明。

## 实际保护与可复验入口

`tool/build-sandbox.sb` 使用系统 `sandbox-exec`，拒绝锁定 Flutter 源码实际读取的三个 home 文件（`.flutter_settings`、`.flutter_tool_state`、`.flutter_custom_devices.json`）的 stat/read/write，以及明确指定主机 Android SDK 的写入。保护继承给 shell、Ruby、Flutter、Gradle 及其新子进程。Gradle 项目配置关闭常驻 daemon，直接入口也使用 `--no-daemon`；实际日志确认启动 single-use daemon。

原生入口需要 `MILEAF_HOST_ANDROID_SDK`，或继承调用前指向主机 SDK 的 `ANDROID_HOME` / `ANDROID_SDK_ROOT`。它与项目 `MILEAF_ANDROID_SDK` 必须不同；路径先规范化。未知主机 SDK、缺少系统沙箱、沙箱初始化/探针失败等均退出 78，不回退到裸命令。此 profile 是明确 SDK 路径与旧式配置的进程保护，不是声称限制所有主机目录的通用沙箱。

每次受保护的 Android 命令先运行真实 I/O 探针：

- 项目内存在的 `.flutter_settings` 非敏感夹具：将同一 literal 路径参数映射到该夹具时，stat 和 read 均被拒绝；实际构建映射到真实 home 文件。使用夹具是因为实际旧文件当前不存在。
- 主机 SDK **已有** `platform-tools/source.properties`：仅以 `O_WRONLY` 打开，不带 `O_TRUNC` / `O_CREAT`，不写任何字节；系统拒绝该权限请求。
- 项目临时文件可以写入、读回和清理。
- 探针经 `sandbox-exec → sh → Ruby` 执行，证明至少两级子进程继承，不只检验 launcher。

探针通过后才启动实际构建；结束时再次核对 `sdk.dir` 必须仍为项目 SDK，否则即使编译返回 0 也拒绝验收。不能用环境标志跳过探针或解除 profile。

常规开发仍使用 `tool/flutterw pub get / test / analyze / dart ...`。Android 示例：

```sh
MILEAF_HOST_ANDROID_SDK=/path/to/existing/host/sdk \
  tool/flutterw android assembleDebug
```

SDK 自定义路径沿用 `MILEAF_FLUTTER_SDK` / `MILEAF_ANDROID_SDK`；Pub cache 已在最终审查修复中固定为当前 checkout 的 `.cache/pub`，不再继承外部 `PUB_CACHE`。iOS 使用同样的环境执行 `tool/flutterw build ios --release --no-codesign`。run/install/drive 等设备执行入口仍保持 78，另待设备验收，不尝试绕过保护。

## Android 已取得的证据

- 沙箱 preflight：`LEGACY_STAT=DENIED`、`LEGACY_READ=DENIED`、`HOST_WRITE_OPEN=DENIED`、`PROJECT_READ_WRITE=ALLOWED`。
- 固定最终脚本并运行 `bash -n` 后，`assembleDebug` 完整返回 **0**：`BUILD SUCCESSFUL in 13s`，153 tasks（21 executed / 132 up-to-date）。初次沙箱编译另有 53s 的编译成功记录。
- wrapper、profile、probe 三份文件前后 SHA-256 一致；日志确认新建 single-use daemon。
- `local.properties` 前后均为项目 Android SDK；主机 probe 文件 SHA-256 前后均为 `2dccd788c0234d8cf7f7457377e57f57527a86a629c6ed54feb8af0f549dac38`。
- 开发 APK 存于 `build/app/outputs/flutter-apk/app-debug.apk`；这不代表真机安装、设备网络策略或最低系统验收。

首次 Android 编译结束后曾因实施期间编辑了仍在执行的 shell 脚本，导致 shell 按旧偏移继续读新内容并退出 2。该次完整命令未标通过；确认根因后冻结三份输入，再复验完整退出 0。此后没有在构建期间修改执行脚本。

## SwiftPM 路径的两项失败证据

1. 真实 `flutter build ios --config-only --no-codesign`：外层探针通过且项目 SDK 路径不变，但 SwiftPM 解析 manifest 时调用内层 `sandbox-exec`，被系统以 `sandbox_apply: Operation not permitted` 拒绝。该命令退出 1。
2. 锁定 Xcode 27.1 的官方二进制含 `IDEPackageSupportDisableManifestSandbox` 字符串。经批准，保留 outer profile，向直接 `xcodebuild` 传递该进程局部参数做一次验证；CLI 明确拒绝为 `invalid option`，退出 64。**二进制中的 preference 键不等于受支持的 CLI 选项。**没有改全局 defaults，没有继续猜测其他拼法，也没有使用内部 XBS 标志。

[SwiftPM 的 ManifestLoader 源码](https://github.com/swiftlang/swift-package-manager/blob/main/Sources/PackageLoading/ManifestLoader.swift) 表明 manifest 沙箱启用时会调用 Sandbox.apply；[Sandbox 源码](https://github.com/swiftlang/swift-package-manager/blob/main/Sources/Basics/Sandbox.swift) 实际包装 `/usr/bin/sandbox-exec`。[SwiftPM CLI](https://github.com/swiftlang/swift-package-manager/blob/main/Sources/PackageManagerDocs/Documentation.docc/Package/PackageInit.md) 提供 `--disable-sandbox`，但本机 `xcodebuild -help` 未提供等价开关，原版 Flutter 也没有可靠的注入入口。该阶段没有改 SDK、脱离外层沙箱或恢复 iOS 入口；后来仅在用户新增授权后验证以下 CocoaPods 路径。

完整日志与验证 hash 留在忽略的项目 `.cache/isolation/`；没有把响应、口令、token 或用户配置值写入版本控制。完整的双端设备验收仍未执行，不能用构建成功替代。

## 用户批准后的项目级 CocoaPods 方案

依据 [Flutter 官方项目级开关与移除 SwiftPM 集成步骤](https://docs.flutter.dev/packages-and-plugins/swift-package-manager/for-app-developers#turn-off-swiftpm-for-a-single-project)，只在 `pubspec.yaml` 的 Flutter config 设置 `enable-swift-package-manager: false`，移除 Xcode 工程中的生成 Swift 包依赖及其 prepare pre-action。使用锁定 Flutter 的官方 Podfile 模板，最低 iOS15；工程加入 CocoaPods xcconfig、workspace 和脚本 phase，`Podfile.lock` 纳入版本管理。未运行全局 `flutter config` 或 `defaults`，未改原版 SDK，也未安装全局 gem。

使用现有 CocoaPods **1.17.0**。本机已安装 `cocoapods/config.rb` 明确支持 `CP_HOME_DIR`、`CP_CACHE_DIR`、`CP_REPOS_DIR`；通过实际 `Pod::Config.instance` 再核对，三者均解析到工程 `.cache/cocoapods/{home,cache,repos}`。RubyGems specs cache 也设为项目 `.cache/gem/specs`，关闭 CocoaPods stats/update message。outer profile 另拒绝写入用户级 `~/.cocoapods`、`~/Library/Caches/CocoaPods`、`~/.gem`。

首轮 CocoaPods 已成功安装并进入 Xcode 编译，但旧 profile 的全路径 `.flutter_*` 通配误伤了 rsync 合法临时图片 `.flutter_map_logo.png.<suffix>`。依据已核对的 Flutter 三个配置文件名改为 **home 绝对路径 literal 参数**，不扩大主机 SDK 或全局 pod/gem 写权限，不忽略错误。修复后的实际构建已验证该图片正常复制：

- iOS release 无签名：完整 wrapper **退出0**，Xcode 6.7s，`Runner.app` 16.7MB。
- 随后顺序 Android SDK36 `assembleDebug`：完整 wrapper **退出0**，16s，153 tasks（21 executed / 132 up-to-date）。
- 两次均记录 preflight 四项通过、wrapper/profile/probe SHA-256 与冻结输入一致、`sdk.dir` 始终项目 SDK。

该项目级变更可连同 Podfile/lock、Xcode 工程和 wrapper 一起回退到之前的 Android-only 基线；回退不会使原 SwiftPM 嵌套问题自动消失。没有向用户设备安装、签名或上架。

## 合入认证候选后的最终验收

同步集成分支 `4450a76`（含站点会话与平台安全存储候选）后，再次按顺序验证：

- 35 个 App 行为测试通过；静态分析无问题；11 个 Dart 文件格式检查无变化。
- iOS release 无签名构建完整退出0，Xcode 33.6s，`Runner.app` 17.2MB；Podfile.lock 增加实际安装的 `flutter_secure_storage_darwin`，保留 iOS15。
- Android `:app:assembleRelease` 完整退出0，1m27s，220 tasks（212 executed / 8 up-to-date），研发签名 APK 约50MB。
- 两次构建仍使用相同冻结的 wrapper/profile/probe；前后 SHA-256 校验均通过，`sdk.dir` 始终项目 SDK，主机 probe 文件摘要未变。
- 原版 Flutter SDK 的 tracked git status 为空。未改 SDK 源码、HOME 或全局配置，未签名 iOS、安装设备或推送发布。

这些证据只覆盖当前集成源码的自动化与构建边界；平台安全存储重启/退出、设备证书与 HTTP 授权、地图中国大陆网络等仍须各自的真实设备验收。

### 2026-10-24 最终首版复验

135 项 App 回归及审查修复后，iOS release 无签名与 Zulu21 下 Android release 均通过同一进程沙箱，探针和 SDK 路径核对通过。最终输入 hash、产物摘要、冷缓存复用与 IDE 自动选 JBR25 的中间尝试见[最终验证](final-verification.md)，不以中间版本替代最后固定工具链证据。
