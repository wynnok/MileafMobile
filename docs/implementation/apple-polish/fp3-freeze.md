# FP3 冻结清单（AP07 视觉裁定通过）

2026-11-17 16:39 用户对 AP07 代表页给出「通过」，按[交付手册](../../specs/apple-polish-delivery.md) §8.4 冻结 FP3：token 表、组件 API、动效参数、首屏预算、共享符号签名。裁定全文见 [AP07.md](AP07.md) §12 与附录 A。

- 冻结点：**FP3 = `eeefe83`**（AP07 合入集成分支的代码态；登记提交在其上）。
- 权威来源永远是代码：`lib/src/design/tokens.dart`、`semantic.dart`、`typography.dart`、`motion.dart`、`layout.dart`、`components/*.dart`。本文件是「冻结了什么 + 数值快照」，两者冲突时以代码为准并以本文件记录偏差。
- W4 起的规则（交付手册 §3.3）：以上文件**只读**。页面票不得改 token、组件、动效与首屏预算；需要改动时提交最小 diff 与理由给总控，由总控在集成窗口修改并通知所有受影响票复验。页面票只写自己持有的页面文件、自己源文件的守卫基线与自己新建的 `test/apple_polish_apXX_*.dart`。

## 1 Token 表

### 1.1 调色板（`MileafPalette`，页面只消费 `semantic.dart` 的角色）

| 角色 | 浅色 | 深色 | 用途 |
| --- | --- | --- | --- |
| accent（图形） | `azure500` #2688F5 | `azure300` #64A8FF | 图形、选中、图表主系列 |
| accentStrong（文字） | `azure600` #0B62C4 | `azure300` #64A8FF | 可读文字与实心填充 |
| accentSoft | #DCEBFD | #64A8FF · 16% | 次按钮底、按压覆盖层 |
| canvas | `paper50` #F4F5F7 | `slate950` #0A0B0D | 页面底 |
| surface | #FFFFFF | `slate900` #12161C | 卡片底 |
| surfaceRaised | #FFFFFF | `slate850` #191E25 | 弹层与浮起元素 |
| hero（锚点） | `heroLight` #070B11 | `slate1000` #06090E | 概览 hero |
| line / lineStrong | #0E1319 · 10% / 16% | #F2F4F7 · 9% / 14% | 分隔线与描边 |
| text / textSecondary / textMuted / textFaint | graphite900 #0E1319 / graphite600 #5A6672 / graphite500 #63707C / mist600 #7E8A96 | mist0 #F2F4F7 / mist400 #A7B4C2 / mist500 #9AA5B1 / mist550 #8A96A4 | 四级文字 |
| controlBorder | #7A8390 | #677179 | 输入与控件边框（最近取色，相邻底色 ≥3:1） |
| segmentTrack / segmentSelected | #E6E9ED / #FFFFFF | #343C46 / #343C46 | 分段与期间胶囊 |
| error / warning | `red600` #CE271B / `amber500` #B45309 | `red400` #FF7A70 / `amber400` #FFB020 | 状态与校验 |
| 玻璃（ADR0013） | 白 40–56% 叠色 + 55% 受光边 | 近黑 48–63% + 白 14% | 底栏与顶栏材质 |

### 1.2 字体角色（`MileafType`，R22/PD04）

| 角色 | 字号 / 行高 / 字距 | 用途 |
| --- | --- | --- |
| display | 40 / 46 / −0.02 | 每视口最多一个（hero 主值、车况卡） |
| metricLg | 32 / 38 / −0.02 | 每视口最多一个；期间卡主值 |
| metricMd | 24 / 30 / −0.02 | 读数头数值（root 尺度） |
| metricSm | 20 / 26 / −0.01 | 三列网格、记录尾值、详情读数头 |
| largeTitle | 34 / 41 / 0 | 根页大标题 |
| title2 | 22 / 28 / 0 | 卡外区块标题、详情身份、整页空态 |
| headline | 17 / 24 / 0 | 卡片/记录行标题、收起顶栏标题、二级导航、弹层标题、主按钮 |
| subheadline | 15 / 21 / 0 | 字段名、元信息、图例、单位（分组标题用 500） |
| control | 15 / 21 / 0 | 分段、次按钮、小胶囊、下拉（选中 600） |
| footnote | 13 / 18 / 0 | 限定语、脚注、更新时间、页尾 |
| caption | 12 / 16 / 0 | 图轴刻度、紧凑标注 |

### 1.3 间距与结构尺寸（`MileafSpace`）

- 规范档位：**2 / 4 / 8 / 12 / 16 / 20 / 24 / 32**（2 只用于基线微调并注释原因）。
- 弃用待删（AP14）：`inline6`、`inline10`、`s18`、`s40`、`s56`——W4 页面不得新增使用。
- 结构：`rowMin` 72、`inputMinHeight` 52、`touch` 44（Android 48）、`navHeight` 64、`primaryButtonHeight` 48、`rhythmHeight` 88、`chartHeight` 160（详情 200）、`cardInset` 12、`cardPad` 16、`heroTop` 16、`heroBottom` 18。

### 1.4 圆角与断点

- `MileafRadius`：xs 4、sm 10、md 12、lg 20（卡片）、surface 24、sheet 28、full 999。
- `MileafBreakpoints`：compact 320、base 360、wide 390、`maxContent` 560、`sheetMax` 520；大字阈值 ≈150%（`scale(14) ≥ 21`）。

### 1.5 布局（`MileafLayout`）

| 量 | 值 |
| --- | --- |
| `pageInset` | 宽 ≥390 → 24，否则 20 |
| `rootTopBarHeight` | 安全区上沿 + 8 + 内容行 + 8；大字时内容行 = 44 + 4 + 大标题行 |
| `rootTopBarCollapsedHeight` | 安全区上沿 + max(44, headline × 1.35) |
| `rootTopClearance` | 展开态高度 + 8（页面顶部留白，外壳收起时页面不跟着动） |
| `rootNavigationHeight` | max(64, 64 + 封顶标签的 leading 增量)；200% 下 69.6 |
| `rootNavigationClearance` | 导航高 + `viewPadding.bottom` + 8 + 16 |
| `rootChromeLabelMaxScale` | 1.35（底栏标签、收起标题、顶栏胶囊文字） |
| `chartHeight` | 宽 ≥390 → 160，否则 160；详情 200 |

## 2 组件 API（唯一来源：`components.dart` 导出的 30 个文件）

FP2 已登记新增与变更的公开符号（见 [README](README.md) 「FP2 共享 API 唯一清单」）。FP3 冻结的额外事实：

- AP07 未新增任何公开符号，也未修改任何冻结组件；W4 页面只能用既有 API。
- 页面消费的组件与构造参数保持 FP2 形态：`MileafModuleCard`/`MileafGroupCard`/`MileafGroupHeader`/`MileafGroupRow`、`MileafDataRow`、`MileafDataNotes`、`MileafNumber`、`MetricGrid`、`MileafHero`、`SectionHeader`、`MileafPeriodRow`、`MileafSelectionList`、`MileafPullDown`、`showMileafDateRangeSheet`、`TimeSeriesChart`/`StemChart`/`BatteryArc`/`SampleChart`、`MileafNavBar`/`MileafTopBar`/`mileafPageBar`/`MileafLargeContentViewer`。
- 已知组件约束（W4 必须绕行，不得改组件）：`MileafNumber` 内部是 `LayoutBuilder`，不支持 `IntrinsicHeight`（D-AP07-06/22）；`ChipRow`/`MileafPeriodRow` 在 200% 下折成 3 行（D-AP07-21）；图表下钻可见串仍由 `charts.dart` 硬编码「看当天」（D-AP07-04，AP14 统一）。

## 3 动效参数（规格 §4 M01–M12，token 见 `MileafDurations`/`MileafCurves`/`MileafMotion`）

| 条目 | 冻结值 | 触发处 |
| --- | --- | --- |
| M01 按压 | 覆盖层即时出现、松手 120ms easeOut 消退；胶囊按钮与可点卡片缩放 0.97，行不缩放 | `MileafPressOverlay`、`MileafButton` |
| M02 互斥选中 | 180ms easeOutCubic 平移；底栏镜片起步拉伸 1.06、分段 1.04 后回落 | `MileafNavBar`、`ChipRow` |
| M03 根页标题收起 | 滚动位置 0–16 驱动（非时间动画）；叠色 120ms | `MileafTopBar` |
| M04 进入详情/设置/证据 | 平台默认路由转场 | 页面 `Navigator` |
| M05 弹层 | 进入 280ms、退出 220ms easeOutCubic；浮动弹层同参数 | `showMileafSheet` |
| M06 折叠 | chevron 160ms；内容高度 200ms easeOutCubic；内容透明度 120ms | `MileafDisclosure` |
| M07 图表 | 竖线、点、读数头直接跟随；选中索引变化时一次 `HapticFeedback.selectionClick`；程序恢复选点不触发 | `TimeSeriesChart` |
| M08 刷新替换 | 120ms 透明度交接，数值首帧即正确 | 页面局部快照 |
| M09 切换指标/期间 | 读数头与图 120ms 淡入；拖动选点不淡入 | `TimeSeriesChart` |
| M10 大内容查看器 | 出现 150ms 淡入并由 0.96 放大到 1，消失 120ms | `MileafLargeContentViewerHost` |
| M11 行内状态条 | 高度 200ms + 透明度 160ms，不推动上方锚点 | `MileafNoticeBanner`/`StateView` |
| M12 切换底栏目的地 | 内容即时切换，不做页面转场（`IndexedStack` 保活） | `workspace_page.dart` |

减少动效：除 M03 的直接切换外，所有时长经 `MileafLayout.motion()` 归零；`MileafProgressLine` 用 55% 静态条。

## 4 首屏预算（基准 360×800、safeArea 上下各 24、100% 字号）

| 页面 | 预算 | AP07 实测 |
| --- | --- | --- |
| P01 概览 | 车况卡完整、主值（960.0）与读数头完整、绘图区首 **80** 可见 | 通过（`360x800 首屏：车况卡完整、主值与读数头完整、绘图区首 80 可见`） |
| P02 行程 | 第一条记录完整、第二条起始 **≥24** 可见 | 第二条可见 **183** |
| P03 充电 | 期间行一行（390/360 三个胶囊同一 `top`）、最近充电区可见 | 通过 |
| P05 充电详情 | 功率绘图区首 **120** 可见 | 800 − plot.top ≥ 120 |
| P06 统计首页 | 用车专题第一行两张卡完整可见（底边 ≤ 导航上沿） | 底边 **703.0** vs 导航上沿 **704.0** |
| P12 设置 | 分组行可达、200% 不溢出 | 通过 |

W4 页面票必须沿用同一基准与测量方式（真带 safeArea），只能持平或更好；任何退让按规格 §6 阶梯处理并在交接登记。

## 5 共享符号签名

- [shared-symbols.md](shared-symbols.md) 的 W4 签名表随 FP3 一起冻结：`statistics_insights_page.dart`、`statistics_period.dart`、`statistics_usage_page.dart`（含 `StatisticsTopicNotes`）、五个专题页、`charging_page.dart`/`charging_detail.dart`、`charging_cost.dart`、`map/map_consent_sheet.dart`/`map/map_privacy_page.dart`、各页面与 `workspace_page.dart` 外壳的调用关系。
- 被调用方能改内部呈现，不能改签名；确实需要改签名时交总控，由总控在集成窗口改并通知全部调用方。
- AP07 的代表页（`overview_page.dart`、`drives_page.dart`、`charging_page.dart`、`charging_detail.dart`、`statistics_insights_page.dart`、`settings_page.dart`、`workspace_page.dart`）在 W4 交回 AP08/AP09/AP10/AP11/AP13；其中 `charging_page.dart` 由 AP07 临时持有，交接给 AP10。

## 6 随冻结带入 W4 的未决项（不阻塞开工）

| ID | 事实 | 建议归属 |
| --- | --- | --- |
| D-AP07-14 | P05 不再提供「按电量」横轴视图（自绘曲线 660 行下线） | 需用户裁定是否补回；AP10 记录 |
| D-AP07-17 | 概览同页两套电耗口径（配对值 vs 服务端净电耗） | 数据口径变更，需用户确认；AP08 |
| D-AP07-18 | 统计卡内边 8（低于 R24 默认 16），为守首屏预算 | AP11 复核，必要时按 §6 阶梯回收 |
| D-AP07-20 | 充电页「自定义」与统计页「自定义日期」用词未统一 | AP14 统一 |
| D-AP07-21 | 200% 下期间行占 3 行 | 组件层（AP03 冻结），AP14 评估 |
| D-AP07-24 | 统计首屏仅 1 像素余量 | AP11 任何加高都会越预算 |
| AU-AP01 / AU-AP01-1 | controlBorder 采纳值与深色次级文字在 segmentSelected 上 4.461:1 | 调色板层，AP14 |

## 7 冻结时的集成状态

- `analyze` 无诊断；全量 `tool/flutterw test --no-pub` **961 通过 / 40 跳过 / 0 失败**（FP2 基线 932/39；+29 通过、+1 跳过 = AP07 新增用例与其渲染入口未 opt-in）。
- `dart format` 0 changed；`git diff --check` 无输出。
- 图证：`docs/implementation/apple-polish-renders/review/` 41 张 PNG + manifest（`input_sha` `1f3c721`、FP2）。
