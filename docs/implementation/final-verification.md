# v1 本地交付与最终验证

2026-10-24；本地集成分支 `codex/mileaf-v1`。产品代码验证版本为 `11cdd04049af08b688c279df5bec2bf390ff9e37`；之后仅整理验证文档和 Issue 状态。未推送、部署或上架。

## 已实现与已验证

连接/健康检查、显式初始化、登录/会话、连接替换与退出、车辆切换、概览、行程和充电列表/详情/采样曲线、驾驶和充电统计、币种偏好均已接通。真实行程地图通过隔离边界接入，发布方配置、许可与源 CRS 不以默认假设替代。性能标记默认关闭且不发送遥测。

| 门禁 | 证据与结果 |
| --- | --- |
| 默认 App/HTTP 回归 | 135 项通过，含连接到退出的完整闭环 |
| 性能标记开启回归 | 135 项通过；不等于性能计时样本 |
| 静态分析、格式、diff | 无诊断，格式及 whitespace 检查通过 |
| DTO 复现 | 8 个生成闭包与冻结 OpenAPI 重生成逐字一致 |
| 独立审查 | 从用户确认的 `543b427` 审查首版；Standards 1、Spec 4 均修复并由原两名审查者独立只读复核，无新增明确问题，见[审查记录](code-review.md) |
| iOS release | `tool/flutterw build ios --release --no-codesign --no-pub` 完整退出 0，Xcode 25.6s，Runner.app 19.4MB，打包最低系统 15.0 |
| Android release | `tool/flutterw android assembleRelease` 完整退出 0，1m22s，271 tasks；实际 Launcher/Daemon 均为 Zulu 21.0.10，打包 minSdk24/target36 |
| Android 签名 | 项目 SDK apksigner verify 成功；源码指定研发 debug signing，不是商店发行签名 |

使用锁定 Flutter 3.47.7 / Dart 3.13.5、Gradle 9.3.1、AGP 9.1.0、项目 Android SDK 与项目级 CocoaPods。两次最终构建前探针均为：`LEGACY_STAT=DENIED`、`LEGACY_READ=DENIED`、`HOST_WRITE_OPEN=DENIED`、`PROJECT_READ_WRITE=ALLOWED`。构建后 sdk.dir 仍为主项目 `.tooling/android-sdk`，脚本 hash 未变化，外部参考仓库未修改。Pub cache 固定为当前 checkout `.cache/pub`。

构建入口 SHA-256：

```text
tool/flutterw                78ea2ef409b9e59c1f83957575c9e1f5db9ffa1d19c3500afe61d431594bdd26
tool/build-sandbox.sb        6f0088b53602be09d91e4d329b08136007463ca5b2cf45862f8f9c9b39466724
tool/build-sandbox-probe.rb  81ac6baecc579345901e8b7974dedcb75e4dec712c8f7a450158da6cc231daa3
```

## 本地产物

- Android：`build/app/outputs/flutter-apk/app-release.apk`，58,710,934 字节；与 Gradle release 输出逐字一致。SHA-256：`bd9389a75770f3d40f436c8457e04ae4b4afd89f5fb501f7238cb6fa82ed5b7d`。
- iOS：`build/ios/iphoneos/Runner.app`，无签名；其中 Runner 可执行文件 SHA-256：`a5b03d307272abbc7f371842964ded60db260f10e4a31c9a32d9bdc9687530aa`。
- 完整构建日志在本地忽略目录 `.cache/final-ios-build.log`、`.cache/final-android-build.log`，JVM 来源在 `.cache/final-gradle-version.log` 与项目 daemon 日志；它们不是性能样本。

Android 首次主 checkout 冷缓存下载 Gradle 时主动中止了任务自有下载子进程（退出143），随后 APFS 复用本次隔离工作树的项目缓存。复制前后 Gradle zip 均符合已锁定 SHA-256 `17f277867f6914d61b1aa02efab1ba7bb439ad652ca485cd8ca6842fccec6e43`，没有改变版本或使用全局缓存。第二次 Flutter APK 入口实际选中 IDE JBR25，虽编译成功但不作为既定 JDK21 验证；核实时其进程已结束，没有停止其他进程。最终采用已有受控 `android` 入口、保持现有 JAVA_HOME 不变，确认 Zulu21 后构建成功。上述中间记录保留于本地缓存，不隐去，也不混入性能统计。

## 尚未通过的外部验收

以下按用户已确认的“先完成代码/自动化，外部条件待验”规则保留，不关闭相关 Ticket、不解除原生依赖边：

1. 双端真机：最低系统启动、实际发布网络栈、正常/无效证书、可信 HTTP、局域网拒绝与恢复、Keychain/Keystore 跨进程行为，以及 TalkBack/VoiceOver 和系统返回行为。
2. 真实站点与 Grafana：同车、同区间、同归期和净/毛、费用及能量口径对账。
3. 地图：正式供应商许可、非公开发布方配置、真实源 CRS 校准、中国大陆验收网络、双端首图与失败恢复。未配置或未核准 CRS 时不联网；没有用透明测试瓦片宣称真实地图通过。
4. 性能：至少 50,000 行程/500,000 位置已装载的本地隔离测试库、固定设备/网络、每平台每指标至少30次样本及 OS/raster/present 关联证据。当前 N=0，无 p50/p95 或达标结论，见[协议](performance.md)。
5. 本次真实后端样本刷新：Docker 服务未运行，脚本在数据库准备前停止；既有真实认证 HTTP/合成 PostgreSQL 响应来源已保留，当前复验不记为通过，见[验收矩阵](acceptance.md)。

固定 Server 为 `146cb3b9a16af3d632b04ed8d197d0f2243d9b71`；OpenAPI SHA-256 仍为 `f6219d5476c217fd6ced091d7e9c0b1a2f9849ece57f79c05daf7f0386d29f0e`。构建、桌面 App 测试和源码复核均不能替代以上证据。设备 run/install/drive 入口继续受保护。

## 2026-10-25 补充：#16 离线数据准备

上一轮把扩大数据生成器一并列为外部门槛不准确，现已补齐项目内独立的标准库CLI与冻结schema/migration：真实产物为50,000行程、500,000位置、5,000充电会话/100,000采样，并附seed/UTC anchor、SHA摘要和固定密集详情别名。公开产物测试覆盖完整规模、确定性、独立变seed/anchor、损坏拒绝和输出路径保护。安全临时容器装载入口已提供，但Docker停运，尚未实际装载、核对数据库计数或验API200点；不启动全局服务，#16保持待验。此切片不改App代码，不重复原生构建。新增6项公开CLI/完整产物测试全部通过；既有135项App/HTTP回归、Flutter静态分析及45个Dart文件格式检查通过。Python复用既有项目内只读ruff执行隔离配置的格式与E4/E7/E9/F/I/UP静态检查，无新增依赖。详见[工具说明](../../tool/performance/README.md)及[测量协议](performance.md)。

单票证据与集成验收须区分：#10/#13自身要求固定真实后端详情/序列可解码；#14/#15要求真实统计可解码并保存对账输入，不能把缺Grafana直接等同这些单票还有业务代码缺口。真实站点同口径Grafana对账仍是#17/Spec T16的明确最终门槛。原生依赖边和未通过外部验收保持，不据此关闭相关票。
