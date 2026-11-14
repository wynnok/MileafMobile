# Apple 风格界面焕新交付手册

2026-11-14，状态为 **proposed，待用户确认**。适用于[规格](apple-design-renewal.md)与[F00–F12](apple-design-renewal-tickets.md)确认后的实施。本轮文档的调研输入为 `5409783664850dc4de0e84151b31081646914085`。

## 1. 授权与启动

开工先读取 AGENTS.md、ADR0012、完整新规格、本手册、所属 Ticket 和实际前置交接。确认方案的用户决定、产品实施授权与任务范围必须在交接中可定位。发布 GitHub、推送、部署及设备操作按各自当次授权执行。

执行 `pwd`、`git status --short`、`git branch --show-current` 与 `git rev-parse HEAD`，记录既有修改。当前调研工作树的基线只有来源未确定的 `output/` 未跟踪目录，本次设计文档工作沿原状保留。后续会话从其实际输入重新核验。

F00 接续旧 capability-map，逐项核实当前入口和后续新增能力。既有 U12 的测试/构建结果在其输入范围引用，焕新成果使用自己的执行结果。所有测试沿现有工具链和 App＋可控 HTTP，合成数据使用现有夹具，场景名称明确标识。

## 2. 文件所有权与并行合同

### 2.1 所有者与接口

| 文件域 | 共享阶段所有者 | 冻结后的规则 |
| --- | --- | --- |
| tokens / semantic / typography / layout / 基础组件 / 显示偏好 | F01 | 页面引用语义角色，变更交 F01 所有者统一接收 |
| 导航 / chip / sheet / motion / theme route 接缝 | F02 | F01 完成后转交 theme route 接缝，几何和遮挡 API 冻结 |
| 共享图表 / 状态 / sample_chart | F03 | 专题使用相同轴与选择规则，公共修正交 F03 |
| 五代表页 | F04 暂时持有 | 冻结后分别交 F05/F06/F07/F10 |
| workspace_page | F02 持有壳层 | F09 只接 `_VehicleSheet` 呈现，壳层后续修改仍归 F02 |
| 页面及专属测试 | F05–F10 各自持有 | 每文件单一写入者，跨包调用接口沿 F04 冻结版本 |
| 共享夹具 / 图册入口 / capability-map / manifest | 总控 | 页面包提交具名补丁与所需机位，总控串行接入 |
| Git 索引、主 checkout 的 Flutter/构建进程 | 总控 | 同 checkout 串行，独立 checkout 的写入与资源路径分开 |

测试运行清单与写入租约分别管理。跨包共享的 `full_flow_test.dart`、`reading_integration_test.dart`、`reading_continuity_test.dart`、`overview_statistics_reading_test.dart`、`charging_reading_test.dart`、`charging_cost_refresh_test.dart`、`map_platform_test.dart` 全程由总控持有，最终归 F11 汇总。页面包可随时提交等价定位或具体回归补丁，总控串行接收并通知受影响包复验。

其余 Tickets 中的领域专属测试由对应包持有。F01 完成后将 `design_components_test.dart` 的导航/弹层断言租约交 F02。新跨包渲染入口和通用夹具由总控维护，每包新增回归可放 `test/apple_design_fxx_test.dart` 并由本包独占。F00 在开工清单列出实际租约，避免同一测试因出现在多张运行清单而被同时编辑。

建议共享 API 仅覆盖实际需要的接缝。材质组件接收角色、solid 策略和 child。显示偏好提供 reduceTransparency 的已知快照。导航遮挡通过实际布局尺寸供滚动余量及焦点 reveal 使用。图表继续使用现有选择数据结构、callback 和 keys。

F01–F04 的完成交接列出实际 public symbols、文件与测试，形成唯一 API 清单。后续包消费该清单，新增参数必须有现有调用场景和默认兼容行为。重复按钮、候选专用主题和第二套图表读取逻辑均计为共享系统缺陷。

### 2.2 并行与集成

产品阶段可复用已有适合的 checkout，启用同时写入时使用独立 worktree/分支和独立可写依赖、缓存、渲染输出。按工具提供的 worktree 生命周期操作。开始登记任务、输入 SHA、工作目录、允许文件、所有者与输出路径。各会话只维护所属记录，状态由总控接收后汇总。

每包从 F04 冻结提交或已接收祖先接续，提交前检查冻结契约差异。推荐接收顺序为 F05→F06→F07→F08→F09→F10，实际可按完成顺序接收无冲突的包。共享需求形成最小补丁，由所有者更新冻结版本并通知所有受影响包重新验证。

发生冲突时先核对双方规则和实际行为，在集成窗口按符号合并，跑相应业务与阅读测试。相同 checkout 里的暂存和提交由单一协调者执行，各隔离 worktree 的本地提交沿分派授权执行。

## 3. Q00–Q09 验收矩阵

| ID | 本地可验要求 | 必需证据 |
| --- | --- | --- |
| Q00 基线与能力 | 完整原新入口、能力分支、指标、动作均可追踪 | 输入 SHA、能力表、before 源与图像 manifest |
| Q01 设计系统 | R11–R15 tokens、字阶、几何、命中、材质白名单一致 | 新旧 token 表、组件图板、两端命中和合成对比测试 |
| Q02 全页视觉 | P01–P16 状态、浅深、大字、长字段、首屏与遮挡 | 正式 Flutter PNG、几何 JSON、逐张目视清单与差异处理 |
| Q03 动态与打断 | M01–M08 的开始/中间/终态、连续输入、取消、运行中减动效 | 可重复 widget 时间采样、逐帧图板，平台手势另列录像 |
| Q04 行为与真实性 | S01–S08、请求参数/次数、旧契约、写入恢复 | 现有核心用例及新增具体回归，HTTP 事件序列 |
| Q05 阅读与可达性 | 跨 Tab/详情/证据/费用/刷新恢复，末项与焦点可见 | 实际点击、滚动、已加载范围、selected ID 和遮挡断言 |
| Q06 无障碍与偏好 | 语义、焦点、字号、减动效、高对比、减少透明度 | 注入偏好测试、桥接测试、焦点/语义树及 solid 对照 |
| Q07 工程与构建 | analyze、格式、全量测试、Android/iOS 隔离构建 | 完整命令、退出码、数量、skip 与阻断、产物路径 |
| Q08 开发期性能 | 相同设备/数据/输入的前后对照，材质成本可归因 | profile traces、UI/raster p95、慢帧/内存/请求数及材质模式 |
| Q09 外部条件 | 真实系统字体/键盘/读屏、偏好映射、地图、性能及整机 | #11/#16/#17 上的实际设备、真实站点和采样证据 |

Q00–Q08 内可控部分和 Q09 外部部分分别记录。静态截图覆盖视觉机位，动画测试覆盖时序，设备录像覆盖真实手势及合成表现。

### 3.1 视觉与状态机位

- 五代表页均覆盖 360×800 的浅深×100/200%，320×568 与 390×844 的浅深×100%，768 宽的浅深×200%。全页面包至少补 430 宽、130/150%、非线性大字和 safeArea=0 的布局断言。
- 全部 P01–P16 至少有浅深×100/200% 正式机位，长内容包含完整滚动。页面中的独立子路由、五专题、长期索引、全部指标、证据与全图按各自场景列入 manifest。
- 每个数据区保留完整/空/首次加载/失败/已有数据刷新/局部失败/能力回退场景。补费用真实零、未知币种、缺失费用、未知分类，地图无Key/未同意/待重启/失败/无轨迹，认证失效与无车辆。
- 费用、连接、登录、初始化、地图Key覆盖键盘。费用必含 320×568、200%、bottom inset 300，输入与动作分别滚动捕获，提交坐标位于可见区域。
- 顶栏与底栏对黑/白/主蓝/交错文字背景、solid/磨砂、高对比、减少透明度、地图及模态覆盖分别采样。系统栏、缺口、底部手势区和横屏另做遮挡断言。
- 真实地图截图只在授权环境采集。本地 fake-map 与路线速写在 manifest 标明来源。产品截图使用正式 widgets，合成数据与演示状态在证据说明中标识。

### 3.2 动态检查

M01/M02/M03/M05/M06/M08 以触发后 0ms、中间时刻和终态采样，M02 再加反向和连续三次点击，M05 加关闭/打开竞争及提交中关闭锁定。检查中间帧没有跳位、双选中或错误命中区。

M04 在本地验证 route 栈与返回恢复，在设备上录 iOS 交互返回取消/完成、Android 系统或预测返回。M07 覆盖横拖选点、纵拖页面、首末点、键盘/语义步进与准确读值。全部动画覆盖启动时和中途开启 reduceMotion，隐藏 Tab 和覆盖 route 的反馈 ticker 停止。

iOS 桥接检查初始读取、通知、多次挂载、销毁、缺失插件、错误返回和前台恢复。模拟偏好只覆盖程序响应，设备端的真实设置映射单独进入 Q09。原生注册/构建是 Q07 必需项。

### 3.3 首屏和合成测量

记录窗口尺寸、DPR、SafeArea、键盘、实际导航矩形、有效视口、记录/图面 bounds、字号及字体身份。首屏目标使用规格 §5。末条记录、分页按钮、错误动作和键盘提交区必须可完整移出遮挡区域。读屏或键盘聚焦后同样验证。

合成对比以最终像素背景和前景 token 计算。blur 区域数、裁剪 bounds、材质 alpha 及 solid 策略记录在组件测试。材质保持静态参数，滚动与列表项构建不得创建额外 blur，地图 route 的 blur 数为 0。

## 4. 工程命令和图册

先核实 cwd 和 `tool/flutterw`，沿当前 SDK、项目依赖和进程沙箱执行。

```sh
pwd
git status --short
./tool/flutterw analyze --no-pub
./tool/flutterw test --no-pub test/design_tokens_test.dart test/design_components_test.dart
./tool/flutterw test --no-pub test/reading_integration_test.dart test/full_flow_test.dart
./tool/flutterw test --no-pub
git diff --check
```

格式使用 `./tool/flutterw dart format --output=none --set-exit-if-changed` 加本包实际修改的 Dart 文件。页面包选择 Tickets 指定测试，集成窗口运行全量。全量结果包含失败和 opt-in 跳过明细。

新图册根目录建议为 `docs/implementation/apple-design-renewal-renders/`，内容分 `before/`、`components/`、`pages/`、`flows/`、`motion/`。F00 先登记现有入口实际支持参数，所需扩展由总控接入，参数示例以源码为准。

```sh
./tool/flutterw test --no-pub test/a_gallery_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/apple-design-renewal-renders/pages \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

当前入口的默认矩阵提供起点。新增代表尺寸、状态和动效采样只有在入口已支持并实际执行后才能记为完成。字体路径先核验，Inter 与中文字体分别记录，沿现有 render_fonts.dart 的身份校验。

图名包含任务、页面、场景、材质模式、浅深、宽×高、字号和机位，例如 `F05-drives-normal-frosted-light-360x800-100-top.png`。manifest 记录输入 commit、夹具、时间/时区、字体路径/哈希、尺寸/安全区/键盘、DPR、材质/偏好、图像 hash 和采样时刻。完成时核验图像、源文件与最终 commit 对应。

Android/iOS 构建前读取 `docs/implementation/build-isolation.md`、`toolchain.md` 和 wrapper 实际支持入口，沿项目 CocoaPods 和进程沙箱。旧图册与原型保留归档历史，代际清理由既有归档政策和当次授权执行。

## 5. 性能与材质降级

Q08 在相同设备/profile、相同数据量与热冷状态下，before/after 各执行三轮固定操作，记录四 Tab 切换、长列表滚动、图表拖动、详情、费用弹层与地图路线。对照 UI/raster p95、慢帧数、峰值内存和请求数，记录实际 60/120Hz 刷新率与热状态。相对持续退化超过 10% 触发定位。

定位按同几何 solid 与磨砂 A/B、blur 区域/裁剪、重建次数、ticker、平台视图相交顺序开展。确认由材质引起且仍超预算时，相关角色全局采用 solid，并在偏差账本注明平台/机型/场景/证据。跨端默认材质或范围的方向性变化提交用户裁定，普通错误修复由所有者完成。

Q09 正式性能继承 #16，每平台每指标至少 30 独立样本，冷启动 p95≤2s、热恢复 p95≤800ms、详情含默认曲线 p95≤1.5s，地图单列。60Hz 的 16.7ms、120Hz 的 8.3ms 为帧预算，实测结果进入原协议。设备未具备时交付本地 blur 数、请求数、ticker、布局和动效自动化结果，并登记待采样平台与指标。

## 6. 可直接分派的提示词

```text
实施行笺 Apple 风格焕新的 Fxx，按本次用户已确认的范围工作。
读取 AGENTS.md、ADR0012、apple-design-renewal.md、Tickets、delivery、
前置交接、F04 冻结清单及本包源码/测试。
记录 cwd、HEAD、Git 状态和文件所有权，从实际冻结祖先接续。
只修改本票持有的文件与呈现接缝，复用冻结组件/API和旧 S01–S08。
共享变更交所有者接收，保留已有用户修改与不明资源。
逐条建立 R/P/S/Q 到 symbol、测试、正式渲染/动态证据的映射。
执行相关 analyze、测试、格式和 diff 检查，记录实际结果与 skip。
方向性偏差记录触发样例、测量、最小修订和影响，交总控按授权处理。
完成时交接输入/结果 SHA、文件、证据、已验证/外部待验及资源归属。
Git 提交和外部操作按本次分派授权执行。
```

每包记录至少包含规格版本、任务/所有者、输入 SHA、实际文件、API 差异、能力原新归宿、完整命令/结果、目视路径、动态证据、偏差处理与下一包输入。技术事实、用户决定和待确认项各有明确状态。

## 7. 完成与审查

Standards 与 Spec 两轴独立审查。前者检查组件复用、token、命中、焦点、桥接和资源边界，后者逐项核对 R/P/S/Q、完整能力和本次设计目标。审查必须对照同条件图像及动态证据，未观察的部分列为未验证。问题由原所有者修正并复验。

完成交付含全部任务记录、冻结参考与 token 表、能力迁移、Q00–Q09 矩阵、单一新图册 manifest、实际工程/构建/审查结果及外部清单。Git 最终状态与初始比对，交付物和项目依赖保留，临时资源按 cleanup-session-dev-resources 精确处理。报告使用“本地工程”“视觉”“可控 HTTP 行为”“设备及真实环境”各自的事实。

## 8. 本轮设计文档核验

2026-11-14 已完成当前源码抽样、五张历史正式渲染目视、Apple 与 Flutter 官方资料核验。Standards 与 Spec 两个独立审查已复核共享导出归属、F02/F03 并行输入和统计嵌入专题互斥顶栏的修正，剩余重要发现为 0。

本轮校验对象为八份 Markdown 的相对链接、表格结构、F00–F12 连续编号和现有测试入口引用。未来新增的 `apple_design_fxx_test.dart` 为命名模板。产品渲染、时序、桥接、构建和设备验证按 Q01–Q09 在实施阶段执行，当前状态为待验证。
