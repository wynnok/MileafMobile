# 理念迁移实施 Tickets（DM00–DM08）

> 2026-11-19，状态 **accepted 并已实施**（用户当日确认 D1–D4 按推荐执行并授权 /implement；实施与验证事实见 [days-matter-migration](../implementation/days-matter-migration.md)）。DM00–DM08 完成，且 overview/drives 两页改动与在途切片已随落地提交（`8bbdd7b`/`8a66a3c`）清零——**HEAD 提交树自洽**，全量终验在 HEAD 复跑（见实施记录「工作区状态」与「验证」节）。MG07 原计划无认领包（审查发现），已由 DM08 补做（`test/days_migration_material_guard_test.dart`）。遗留与待裁定清单见实施记录。设计规则见[迁移规格](days-matter-migration.md)（MG01–MG09）。分包原则沿 ADR0014 过程条款：共享系统先行、公开符号在并行期冻结签名、页面包在隔离工作树并行、各包只改声明范围内的文件（write scopes 为提示性，不构成锁）。

## 任务及依赖

| ID | 任务 | 前置 | 并行分组 | 主要 write scopes |
| --- | --- | --- | --- | --- |
| DM00 | 基线登记与守卫脚手架 | ADR0015 accepted（D1–D4 裁决落档） | 先行 | docs/adr/0015（确认记录）、docs/specs/apple-polish.md（PD12/PD13 登记）、docs/specs/ui-ux-refinement.md（R07 扩展）、test/support/（守卫脚手架） |
| DM01 | 色彩纪律：彩色面积审计 + 状态取色映射 + 对比度守卫 | DM00 | 并行组 A | lib/src/design/{tokens,semantic}.dart、test/（对比度与状态取色守卫）、docs/implementation/ |
| DM02 | 图标家族参数登记与统一出口 | DM00 | 并行组 A | lib/src/design/components/icons.dart（新）、lib/src/design/components/components.dart（barrel）、test/（图标 golden） |
| DM03 | 焦点值统一淡化（MG08）+ 卡头间距裁决落地（MG06） | DM00 | 并行组 B | lib/src/design/components/{metric,charts,period_header}.dart、lib/src/overview_page.dart（焦点卡）、lib/src/drives_page.dart（焦点卡）、test/ |
| DM04 | 状态诚实三要素组件（MG09） | DM00 | 并行组 B | lib/src/design/components/state_view.dart、lib/src/copy/、test/ |
| DM05 | 页面包：概览 + 行程 | DM01、DM03、DM04 | 并行组 C | lib/src/overview_page.dart、lib/src/drives_page.dart、test/、docs/implementation/days-matter-migration-renders/（本包图册） |
| DM06 | 页面包：充电 | DM01、DM03、DM04 | 并行组 C | lib/src/charging_page.dart、lib/src/charging_detail.dart、test/、图册（本包） |
| DM07 | 页面包：统计 + 设置 + 详情 + 连接 | DM01、DM03、DM04 | 并行组 C | lib/src/statistics_*.dart、lib/src/settings_page.dart、lib/src/map/、lib/src/connection_page.dart、lib/src/copy/dates.dart 只读、test/、图册（本包） |
| DM08 | 集成、全量图册、文档收口与交付 | DM05、DM06、DM07 | 收尾 | docs/implementation/days-matter-migration.md、AGENTS.md 追加条目、全库回归 |

## 逐页面、逐组件改造清单

### 组件级（DM02–DM04）

| 组件 | 改造 | 条款 |
| --- | --- | --- |
| `lib/src/design/tokens.dart` | 不新增档位；仅在测试中登记「前景×背景声明表」 | MG03 |
| `semantic.dart` | 增加状态色声明常量（映射表数据源），不改现值 | MG02 |
| `components/icons.dart`（新） | 自绘图标统一出口 + 家族参数表（实测登记后冻结） | MG04 |
| `components/metric.dart` | `MileafNumber`/`MetricBlock` 值变更接入 120ms 交叉淡化（AnimatedSwitcher 语义，减动效 0ms） | MG08 |
| `components/charts.dart` | 读值区换指标/数据刷新走统一淡化；拖动取点维持原地即时 | MG08 |
| `components/period_header.dart` | 卡头→焦点值间距改由调用方 `s12`（D1）；组件本身签名不变 | MG06 |
| `components/state_view.dart` | compact 态新增文字动作槽；三要素结构（现状/时间原因/动作）；色彩参数收受限枚举 | MG09、MG02 |
| `components/module.dart`（InlineBanner） | 同三要素结构 + 受限枚举 | MG09、MG02 |
| `components/components.dart` | barrel 导出 icons.dart | MG04 |

### 页面级（DM05–DM07）

| 页面 | 改造点 | 条款 |
| --- | --- | --- |
| 概览 `overview_page.dart` | 焦点卡头→主值 s12；hero 状态图形迁入 icons.dart；GroupHeader inset 迁移；刷新失败/数据截至接三要素 | MG06/04/05b/09 |
| 行程 `drives_page.dart` | 焦点卡头→主值 s12；记录行改「标题行 + 三格 metricSm 读值网格」（里程/时长/能耗）；GroupHeader inset；空态分档 | MG06/05/09 |
| 充电 `charging_page.dart` | 记录行/地点行核对起始线（已修，守卫钉住）；进行中胶囊与筛选态接受限枚举；空态分档 | MG02/09 |
| 充电详情 `charging_detail.dart` | 状态行接三要素（失败/重试）；费用未记录口径旁注核对中性色 | MG09/02 |
| 行程详情 `drive_detail_page.dart` | 状态接线三要素；参照卡取色核对映射表 | MG09/02 |
| 统计首页 + 五专题 | 空态/无数据分档；图形取色（在线实色/睡眠斜线/离线点纹维持中性）核对映射表；彩色面积登记 | MG09/02/01 |
| 设置 `settings_page.dart` + 地图设置 | GroupHeader inset 迁移；错误破坏行核对 error 语义；彩色面积登记 | MG05b/02/01 |
| 连接 `connection_page.dart` / `connection_management.dart` | 离线/失败三要素（含「显示至 HH:mm 的缓存数据」场景）；重试动作 | MG09 |
| 费用补录 `charging_cost.dart` | 双入口底部表单不动；仅错误/成功反馈接三要素句式 | MG09 |
| 地图 `lib/src/map/` | 只接图标出口与状态三要素；地图底图、导航实色路径不动 | MG04/09 |

## 会话执行提示词（多 Agent、多会话）

每包一个独立会话；提示词可直接粘贴。通用前置（每条提示词开头自动包含）：「仓库 /Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile，产品行笺 Mileaf。先读 AGENTS.md 与 docs/specs/days-matter-migration.md 相关条款。边界：不推送、不改 MileafServer/ 与 teslamate/、不动底栏玻璃（ADR0013）、不改字阶 R22 与冻结文案 CP12；改动前读文件、最小改动、按包内 write scopes 行动；完成跑 `tool/flutterw analyze` 与相关测试文件，本地提交只含本包文件（按路径选择性暂存，工作树可能有他人在途改动）。」

- **DM00**：「完成迁移基线登记：按 ADR0015 确认记录落 D1–D4 裁决；在 apple-polish.md 登记 PD12（D1 间距）与 PD13（M08 扩展）、ui-ux-refinement.md R07 白名单追加『数据刷新焦点值淡入』；在 test/support/ 建守卫脚手架（前景×背景声明表数据结构 + WCAG 对比度计算函数，含浅深两模式断言入口）。产出：登记 diff + 脚手架测试通过证据。」
- **DM01**：「实施 MG01–MG03：① 逐页彩色面积登记表 + 每页浅/深渲染图册（入库 docs/implementation/days-matter-migration-renders/），超标页列整改项不动手改页；② 状态取色映射表落 semantic.dart 声明常量，StateView/InlineBanner 参数收受限枚举（neutral/warning/error/accent），加『缺失数据渲染不含彩色信号』白盒测试；③ 用 DM00 脚手架跑全量对比度守卫，裁决 textFaint（保留现值），在 overview-reading.md 追加批注订正旧结论。产出：登记表、守卫测试、实施记录 docs/implementation/days-matter-migration-color.md。」
- **DM02**：「实施 MG04：实测全部自绘图标（hero 状态图形、导航返回、刷新、复制、勾选等），登记家族参数表（线宽/端点/网格 24/视觉盒/命中区），建 lib/src/design/components/icons.dart 统一出口并接 barrel；逐图标浅/深 golden；页面直绘图标迁移到出口。不新增图标造型，不改语义。产出：参数表、icons.dart、golden 通过证据。」
- **DM03**：「实施 MG08 与 MG06：① MileafNumber/MetricBlock/charts 读值接入 120ms 交叉淡化（AnimatedSwitcher 语义，减动效 0ms），拖动取点保持原地即时；新增守卫测试『焦点值变更动画时长 ∈ {0,120}』；② 概览与行程焦点卡头→主值间距 s4→s12（D1），实测 360×800 首屏截图 before/after，超预算按六步退让阶梯第 1–4 步回收并记录。产出：实施记录 docs/implementation/days-matter-migration-motion.md + 截图册。」
- **DM04**：「实施 MG09：StateView compact 态新增文字动作槽；StateView/InlineBanner 增三要素结构（现状句/时间或原因行/下一步动作槽）；空态按原因分档（离线/加载失败/无数据/筛选无结果）文案走 CP 系列并登记 copy guard 基线；组件测试覆盖三要素与减动效。产出：组件测试 + copy guard 登记。」
- **DM05**：「概览 + 行程页面包：按清单（s12、hero 图标迁出口、GroupHeader inset、行程记录行改三格 metricSm 读值网格、空态分档、刷新失败三要素）实施；行程记录行文案变更登记 copy guard；产出包内图册（浅/深、360 宽、200%）与实施记录 docs/implementation/days-matter-migration-dm05.md。」
- **DM06**：「充电页面包：记录行/地点行起始线守卫钉住；进行中与筛选态接受限枚举；空态分档；充电详情状态行接三要素；费用未记录旁注核对中性色；产出包内图册与 docs/implementation/days-matter-migration-dm06.md。」
- **DM07**：「统计 + 设置 + 详情 + 连接页面包：统计首页与五专题空态分档、图形取色核对映射表、彩色面积登记；设置与地图设置 GroupHeader inset 与 error 语义核对；行程详情三要素接线；连接页离线/失败三要素与重试（含缓存截至时间场景用例）；费用补录仅反馈句式；产出包内图册与 docs/implementation/days-matter-migration-dm07.md。」
- **DM08**：「集成收尾：跑 `tool/flutterw analyze` 与全量 `tool/flutterw test`（0 失败）；重采全库图册（外观 v2 基准，归档规则沿 render-archive.md：当前一代 + 上一代对照）；汇总彩色面积登记表终稿；写 docs/implementation/days-matter-migration.md（实施与验证事实）与 docs/implementation/days-matter-migration-review.md（双轴审查）；AGENTS.md 追加本增量条目。不推送；外部 gate（#11/#16/#17）不因本地实施关闭。」

## 验收合同

- 完成证据逐项覆盖规格条款、正式 Flutter 渲染（opt-in 入口，skip 机制沿 AP07）、工程检查（analyze 0 诊断）与双轴审查（standards/spec）。
- 性能：开发期三次前后对照 + 10% 调查阈值；正式性能沿 #16（每平台每指标 ≥30 样本与既有 p95 预算），地图/整机外部条件沿 #11/#17。
- 文案守卫：按源文件行数计数只降不升；结构性新增字面量随登记升基线。
- 发布：确认后本表随增量 Spec 发布 GitHub sub-issues 的方式沿 ui-ux-refinement-tickets 先例（独立增量 Spec + 子票 + 原生 blocked_by）；发布与文档本地提交须按当次用户指令授权。