# 构建进程隔离验证（2026-10-23）

## 当前结论

Android 的 `tool/flutterw android assembleDebug` 已在 macOS 进程沙箱下完成验证，完整 wrapper 退出 0，生成研发 APK。iOS 仍退出 78：Xcode 的 SwiftPM manifest 沙箱无法嵌套，当前没有通过验证的进程局部解决方式。既往双端编译成功不等于当前双端隔离验证通过；相关 Ticket 保留待验。

用户已批准此轮验证，不修改 HOME、全局 defaults、shell 配置或原版 Flutter 源码，不切换 SwiftPM/CocoaPods。SDK、依赖、缓存、日志和产物均沿用项目位置。

## 两次旧方案失效的原因与证据边界

1. Flutter 原生入口曾将 `local.properties` 的 `sdk.dir` 写成主机 SDK，并准备安装 NDK。只设置 `ANDROID_HOME` / `XDG_CONFIG_HOME` 未构成进程隔离。Flutter 源码确实优先读取**存在**的旧式 home 配置，但当时没有保留配置文件存在性证据，不能把它断言为唯一原因；本轮实际检查 `~/.flutter_settings` 不存在。误写的 NDK 安装临时元数据已由此前恢复流程可逆迁入项目，未修改其他既有 SDK。
2. 直接 Gradle、预写 `local.properties` 和按顺序构建仍不能约束后续 Flutter 子进程的重新选址或写入；共享文件的正确初值不能约束后写者。此外，已有 Gradle daemon 可能不属于新进程树，必须避免复用。这些是旧入口未提供的约束，不能用一次编译成功替代隔离证明。

## 实际保护与可复验入口

`tool/build-sandbox.sb` 使用系统 `sandbox-exec`，拒绝旧式 `.flutter_*` 路径的 stat/read/write，以及明确指定主机 Android SDK 的写入。保护继承给 shell、Ruby、Flutter、Gradle 及其新子进程。Gradle 项目配置关闭常驻 daemon，直接入口也使用 `--no-daemon`；实际日志确认启动 single-use daemon。

原生入口需要 `MILEAF_HOST_ANDROID_SDK`，或继承调用前指向主机 SDK 的 `ANDROID_HOME` / `ANDROID_SDK_ROOT`。它与项目 `MILEAF_ANDROID_SDK` 必须不同；路径先规范化。未知主机 SDK、缺少系统沙箱、沙箱初始化/探针失败等均退出 78，不回退到裸命令。此 profile 是明确 SDK 路径与旧式配置的进程保护，不是声称限制所有主机目录的通用沙箱。

每次受保护的 Android 命令先运行真实 I/O 探针：

- 项目内存在的 `.flutter_settings` 非敏感夹具：stat 和 read 均被拒绝。使用夹具是因为实际旧文件当前不存在。
- 主机 SDK **已有** `platform-tools/source.properties`：仅以 `O_WRONLY` 打开，不带 `O_TRUNC` / `O_CREAT`，不写任何字节；系统拒绝该权限请求。
- 项目临时文件可以写入、读回和清理。
- 探针经 `sandbox-exec → sh → Ruby` 执行，证明至少两级子进程继承，不只检验 launcher。

探针通过后才启动实际构建；结束时再次核对 `sdk.dir` 必须仍为项目 SDK，否则即使编译返回 0 也拒绝验收。不能用环境标志跳过探针或解除 profile。

常规开发仍使用 `tool/flutterw pub get / test / analyze / dart ...`。Android 示例：

```sh
MILEAF_HOST_ANDROID_SDK=/path/to/existing/host/sdk \
  tool/flutterw android assembleDebug
```

SDK 自定义路径沿用 `MILEAF_FLUTTER_SDK` / `MILEAF_ANDROID_SDK`；Pub cache 可沿用项目内共享 `PUB_CACHE`。iOS、run、install、drive 等尚未验证的入口保持 78，不尝试绕过保护。

## Android 已取得的证据

- 沙箱 preflight：`LEGACY_STAT=DENIED`、`LEGACY_READ=DENIED`、`HOST_WRITE_OPEN=DENIED`、`PROJECT_READ_WRITE=ALLOWED`。
- 固定最终脚本并运行 `bash -n` 后，`assembleDebug` 完整返回 **0**：`BUILD SUCCESSFUL in 13s`，153 tasks（21 executed / 132 up-to-date）。初次沙箱编译另有 53s 的编译成功记录。
- wrapper、profile、probe 三份文件前后 SHA-256 一致；日志确认新建 single-use daemon。
- `local.properties` 前后均为项目 Android SDK；主机 probe 文件 SHA-256 前后均为 `2dccd788c0234d8cf7f7457377e57f57527a86a629c6ed54feb8af0f549dac38`。
- 开发 APK 存于 `build/app/outputs/flutter-apk/app-debug.apk`；这不代表真机安装、设备网络策略或最低系统验收。

首次 Android 编译结束后曾因实施期间编辑了仍在执行的 shell 脚本，导致 shell 按旧偏移继续读新内容并退出 2。该次完整命令未标通过；确认根因后冻结三份输入，再复验完整退出 0。此后没有在构建期间修改执行脚本。

## iOS 的两项有界验证

1. 真实 `flutter build ios --config-only --no-codesign`：外层探针通过且项目 SDK 路径不变，但 SwiftPM 解析 manifest 时调用内层 `sandbox-exec`，被系统以 `sandbox_apply: Operation not permitted` 拒绝。该命令退出 1。
2. 锁定 Xcode 27.1 的官方二进制含 `IDEPackageSupportDisableManifestSandbox` 字符串。经批准，保留 outer profile，向直接 `xcodebuild` 传递该进程局部参数做一次验证；CLI 明确拒绝为 `invalid option`，退出 64。**二进制中的 preference 键不等于受支持的 CLI 选项。**没有改全局 defaults，没有继续猜测其他拼法，也没有使用内部 XBS 标志。

[SwiftPM 的 ManifestLoader 源码](https://github.com/swiftlang/swift-package-manager/blob/main/Sources/PackageLoading/ManifestLoader.swift) 表明 manifest 沙箱启用时会调用 Sandbox.apply；[Sandbox 源码](https://github.com/swiftlang/swift-package-manager/blob/main/Sources/Basics/Sandbox.swift) 实际包装 `/usr/bin/sandbox-exec`。[SwiftPM CLI](https://github.com/swiftlang/swift-package-manager/blob/main/Sources/PackageManagerDocs/Documentation.docc/Package/PackageInit.md) 提供 `--disable-sandbox`，但本机 `xcodebuild -help` 未提供等价开关，原版 Flutter 也没有可靠的注入入口。本轮不据此换包管理器、改 SDK、脱离外层沙箱或恢复通用 iOS 构建。

完整日志与验证 hash 留在忽略的项目 `.cache/isolation/`；没有把响应、口令、token 或用户配置值写入版本控制。iOS 双端构建隔离仍是明确待解决的门槛。
