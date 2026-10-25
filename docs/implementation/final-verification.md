# v1 本地交付与最终验证

2026-10-25 展示方式澄清：本文保留旧基线下的代码、测试与构建证据；下文“已实现与已验证”不代表新增[可视化基线](../product/visualization-requirements.md)已通过。当前尚需代表页面可视方案、概览趋势和统计多指标等图表实现及 Spec T17–T18 视觉/交互验收；这些是实际展示交付缺口，不能统称为仅剩外部验收。性能终点也须计入概览主图后复验。

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
4. 性能：本地隔离测试库的 50,000 行程/500,000 位置实际装载已补验，见下文；仍需该规模运行站点的 API 核验、固定设备/网络、每平台每指标至少30次样本及 OS/raster/present 关联证据。当前 N=0，无 p50/p95 或达标结论，见[协议](performance.md)。
5. 真实后端样本刷新：2026-10-24 尝试时 Docker 服务未运行，脚本在数据库准备前停止；2026-10-25 本地 Docker 恢复后的规模数据装载不等于该脚本或 API 复验通过。既有真实认证 HTTP/合成 PostgreSQL 响应来源已保留，当前 API 复验不记为通过，见[验收矩阵](acceptance.md)。

固定 Server 为 `146cb3b9a16af3d632b04ed8d197d0f2243d9b71`；OpenAPI SHA-256 仍为 `f6219d5476c217fd6ced091d7e9c0b1a2f9849ece57f79c05daf7f0386d29f0e`。构建、桌面 App 测试和源码复核均不能替代以上证据。设备 run/install/drive 入口继续受保护。

## 2026-10-25 补充：#16 离线数据准备

上一轮把扩大数据生成器一并列为外部门槛不准确，现已补齐项目内独立的标准库CLI与冻结schema/migration：真实产物为50,000行程、500,000位置、5,000充电会话/100,000采样，并附seed/UTC anchor、SHA摘要和固定密集详情别名。公开产物测试覆盖完整规模、确定性、独立变seed/anchor、损坏拒绝和输出路径保护。新增6项公开CLI/完整产物测试全部通过；既有135项App/HTTP回归、Flutter静态分析及45个Dart文件格式检查通过。Python复用既有项目内只读ruff执行隔离配置的格式与E4/E7/E9/F/I/UP静态检查，无新增依赖。此切片不改App代码，不重复原生构建。详见[工具说明](../../tool/performance/README.md)及[测量协议](performance.md)。

本机Docker恢复后，仅使用人工已有的本地socket及缓存镜像，在本任务新建的无网络、无端口、无宿主挂载临时库实际装载。首次运行失败并定位到镜像初始化临时Unix服务被误判就绪；修正为容器内loopback TCP探针后，实施工作树的未加诊断原命令连续3次通过，完成事务约束检查、reader只读精确计数及自有容器清理。没有读取生产DSN、`.env`或Settings，没有访问现有数据库。API200点、实际翻页和设备计时尚未验证，#16保持待验；装载成功不等于性能达标。

主checkout在集成 `58e7567` 独立运行原公开load再次退出0。数据位于 `.cache/performance-20261025-local/`，anchor为 `2026-10-25T00:00:00Z`，manifest SHA-256为 `758fa1c25454cae013ae84e32a56e2c6a236d463c41e6d8d876b7abe34f65ca0`；实际PostgreSQL版本160015。报告 `.cache/performance-load-d3cbc62201974a1691e2254227d9ca9f.json` 的数据库计数与manifest逐项一致，容器清理标志为true；另对本次新UUID执行只读inspect确认对象不存在。独立核验摘要保存在 `.cache/performance-review-evidence/integration-load.json`，实施者的6项回归日志与3次装载/清理证据也已保存到同目录，不依赖待归档worktree。生产配置未读取，外部验收与原生依赖边不变。

单票证据与集成验收须区分：#10/#13自身要求固定真实后端详情/序列可解码；#14/#15要求真实统计可解码并保存对账输入，不能把缺Grafana直接等同这些单票还有业务代码缺口。真实站点同口径Grafana对账仍是#17/Spec T16的明确最终门槛。原生依赖边和未通过外部验收保持，不据此关闭相关票。

## 2026-10-25：核心展示方式文档澄清

本轮起点 `5dc7c28edd148e3b45b427bdeadc953f1fac98a5`。仅修改产品/Spec/验收及配套指引文档，未改 App、测试、依赖或外部仓库；按用户调用的 implement 技能在当前分支创建本地提交，不推送。

- 新增[可视化需求基线](../product/visualization-requirements.md)，明确 V01–V08 首版图表、G01–G08 能力缺口及 A01–A06 视觉验收；修订 Spec 增加故事 59–62 和 T17–T18，概览计时须包含主趋势。
- GitHub Spec #1 和 #8–#17 正文已同步，写入前核对无并发正文变更，写入后 11/11 正文与草稿一致，#1 与本地 Spec 镜像一致；标题/状态保持，#8–#17 均为 OPEN。只更新 body，未修改原生依赖边。
- 文档验证：16 份变更 Markdown 的相对链接、表格列数、代码围栏及 diff whitespace 检查通过，旧方向/旧交接状态的冲突表述已修订。
- 现有代码回归：`tool/flutterw analyze --no-pub` 无诊断，`tool/flutterw test --no-pub --reporter expanded` 135 项通过；纯文档变更不新增 TDD 用例或原生构建。上述结果不代表 V01–V08 或 T17–T18 已实施/通过。

### Standards

独立只读审查文档差异与 11 份 Issue 正文草稿，未发现明确规范违规或需修正的气味判断项。变更直接对应展示方式澄清，区分产品目标、数据能力、历史证据和新缺口，保留只读/隐私/依赖边界。

### Spec

独立只读审查用户本轮要求、冻结字段、文档和 Issue 草稿，无明确发现。图表主导、美观/体验已形成可验收规则，现有 API 未成为长期覆盖上限；正式 Spec 自包含 V/G/A 表格，不依赖未推送外链。

审查结果：Standards 0 项、Spec 0 项，各轴均无阻断项。独立审查覆盖草稿，远端写入结果由本轮另行回读核对；原型、页面实现与真实展示体验继续待交付。
