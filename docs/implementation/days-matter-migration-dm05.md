# DM05 页面包：概览 + 行程（MG05/MG05b/MG09/MG01）实施记录

2026-11-19。分支 `main`（工作区含 period-header / Apple 焕新 / 底栏等他人在途改动，本次未提交、未推送）。
条款依据：[days-matter-migration](../specs/days-matter-migration.md) §4（MG05 记录行句法统一、MG05b 分组标题 inset、MG09 状态诚实三要素、MG01 彩色面积登记）、[charging-rows](charging-rows.md)（记录行同构模板，充电页不改）、[settings-order](settings-order.md)（GroupHeader inset 用法）、[days-matter-migration-state](days-matter-migration-state.md)（DM04 组件新参数）。未新增颜色/字号/圆角/动效 token；冻结文案 CP12 未动。

## 1. 改动文件

| 文件 | 变化 |
| --- | --- |
| `lib/src/drives_page.dart` | MG05：`_routeRow` 由 `MileafDataRow` meta 串改为「标题行 + 三格 metricSm 读值网格」（§2）；MG09：统计失败现状句与时间要素拆分 + 空态接 `StateView` compact；MG05b：按天分组 `MileafGroupHeader` 传 `inset` |
| `lib/src/overview_page.dart` | MG09：三条失败状态条接 `statusLine`（数据截至 HH:mm）；MG05b：服务信息（`MetaPage`，同文件）分组标题传 `inset` |
| `test/drives_test.dart` | 记录行断言随结构映射更新（R10，业务断言未放宽）+ 新增网格定位、三要素行为、360/200% 三个用例 |
| `test/overview_test.dart` | 新增「刷新失败有缓存数据」三要素用例 |
| `test/apple_polish_ap07_test.dart` | P02 记录卡两用例随结构映射更新（记录行探针从 `MileafDataRow` 改行 key；结构断言改网格语法），起始线/分隔线/首屏预算断言原样保留 |
| `test/a_drives_test.dart` | 焦点卡「电耗」标签计数随记录行网格映射（1→3，含每行一格） |
| `test/support/copy_guard_baseline/drives_page.dart.txt` | 基线 45 → 46（§5） |
| `test/days_migration_dm05_render_test.dart` | 新增 opt-in 渲染入口（skip 机制沿 AP07），样张出 `build/` 不入库 |
| `docs/implementation/days-matter-migration-color.md` | 只追加概览/行程两行登记（§4） |
| `docs/implementation/days-matter-migration-dm05.md` | 本记录 |

未改：components/ 任何组件、charging/statistics/settings/connection/map 页面、tokens.dart、semantic.dart；充电页按任务边界只作同构参照未动。

## 2. MG05 行程记录行句法统一

**Before**（`MileafDataRow` meta 串）：

```
松岚小区 → 云栖中心                    32.9 km ›
16:05–16:51，46 分钟
电耗 154 Wh/km
```

标题 body 600、meta 两行 footnote 混排（时间+时长逗号拼行 / 电耗另起一行）、尾值 metricMd 独立；`semanticLabel` 自拼一整句。

**After**（与充电 `_recordRow` 同构，见样张 `build/dm05-renders/dm05-drives-records-*.png`）：

```
16:05–16:51
松岚小区 → 云栖中心
里程 32.9 km        时长 46 分钟
电耗 154 Wh/km
```

- **标题行（headline）**：起讫时刻（日期由分组头「今天 / 昨天 / M月D日 周X」承担，不逐行重复，R21.4）；「进行中」徽标留在标题行尾（warning，条件彩色）。跨日结束时刻沿用 `_recordTime` 的原格式。
- **路线一行**：subheadline textSecondary（行内保留 `_route` 信息，充电行标题是地点，行程行的路线同名角色）；100% 最多两行省略号，大字不截断。
- **三格 metricSm 读值网格**：`MetricGrid(spacing: s8)` + `MetricBlock`（与充电记录行同参：默认两列，第三格放不下换行；`MetricGrid.minCellWidth` 100 先量后画，200% 自动单列）。里程（缺失显示 —，不给假 0）/ 时长（数值+分钟，与原 meta 同串）/ 电耗（`terms.energyPerKm`，缺失 —）。标签在上、数值同基线成列。
- **整行可点**：行内 `InkWell`（key 仍为 `drive-N`）+ 垂直 s12，横向内边由分组卡的 `_recentSection` 卡内 16 提供（两条起始线不变）。
- **读屏**：不再合成单句标签，沿元素顺序朗读——起讫时刻、路线，再逐格「里程 32.9 km」「时长 46 分钟」「电耗 154 Wh/km」（与充电记录行一致）；缺失里程朗读「里程未记录」。
- 移除 `_recordDate`/`_duration`/`_net`（并入网格）；原 `ConstrainedBox` 最小行高随结构取消（网格行天然高于行最小值）。
- 360 宽 100%：里程/时长同排、电耗换行（与充电行同布局）；200% 单列堆叠（新用例断言）。行高增加后 360×800 首屏预算用例（drive-16 起始 ≥24 可见）实测仍通过（ap07 与 drives_test 各一份）。

## 3. MG05b / MG09 接线清单

**MG05b GroupHeader inset（页面边距 + 16 对齐卡内起始线）**：

- `drives_page.dart`：按天分组标题（今天/昨天/M月D日 周X）→ `inset: MileafSpace.cardPad`。
- `overview_page.dart`：服务信息（`MetaPage`，位于同文件）「当前连接」→ `inset: MileafSpace.cardPad`。
- 概览页画布层标题本走 `SectionHeader`（非 `MileafGroupHeader`），不在此列；全库其余调用点属 DM07。

**MG09 状态诚实三要素**：

| 场景 | 现状句 | 时间要素 | 动作 |
| --- | --- | --- | --- |
| 概览车况刷新失败有缓存 | 原句不变（CP07「…，显示的是上次的数据」，ap08/business_recovery 断言保持） | **新增** `statusLine` = `feedback.dataAsOfLine(result.checkedAt)`「数据截至 HH:mm」 | 重试（原样） |
| 概览驾驶/充电统计刷新失败有缓存 | 原句不变（…显示的是上次的数据） | **新增** `statusLine` = `dataAsOfLine(results[kind].checkedAt)` | 重试（原样） |
| 行程统计刷新失败有缓存 | 改为原因句（`readFailedMessage('行程统计')` / ApiFailure message / 版本不兼容句），不再用 `staleMessage` 把时间拼进现状句 | `statusLine` = `dataAsOfLine(statsCheckedAt)`（仅 `driving != null` 即屏幕上仍是缓存统计时出现） | 重试行程统计（原样） |
| 行程列表刷新失败有缓存 | **不变**（`staleMessage` 本身含时间要素；ap09 对该句有断言、该文件不在本包范围，且时间已在现状句内，重复排一行反而冗余） | 现状句内（DF 相对/绝对时刻） | 重试行程（原样） |
| 行程列表空态（无筛选） | `emptyStateCopy(noData, object: '行程')`（= 原共享空态句「这段时间没有行程」，字面不变） | —（无数据场景时间要素不适用） | **新增** `StateView` compact `textActionLabel`「刷新」→ `_refresh` |
| 行程列表空态（选了日期） | 「所选日期没有行程」保持，下方既有「返回完整区间」即下一步动作，不另造第二个入口（避免同屏两个等义动作） | — | 返回完整区间（原样） |
| 概览图表空态/失败、hero 空态 | 原样（失败原因按 R21.4 只在上方状态条出现一次；空态句走 `emptyMessage` 构造已合 CP） | — | 原样 |

空态分档对照：本包两页的空态句均由 CP 构造给出（`emptyMessage` / `emptyStateCopy`），「筛选无结果」档保留原「所选日期没有行程」（页内既有动作已构成三要素），未换用 `filterNoMatch` 句以免与「返回完整区间」重复。

**InlineBanner tone 参数**：DM04 落地的组件参数仍是受限四档枚举 `BannerTone { neutral, warning, error, accent }`（取色转发 `MileafStatusTone`）；实施记录原计划的「调用点迁到 `MileafStatusTone`」需要先改组件签名（components/ 为本包禁区），且全库调用点已无 `info` 旧值——本包调用点维持四档枚举字面量，零改动、零视觉变化。枚举删除留待 DM07/DM08 组件层收口。

## 4. MG01 彩色面积登记

机位：`build/dm05-renders/`（opt-in 入口 `test/days_migration_dm05_render_test.dart`，浅/深 390×844 100%，概览上/下半 + 行程首屏/记录分组，共 8 图；本包出图不入库，图册由 DM08 统一入库）。结论已按模板登记进 [days-matter-migration-color.md](days-matter-migration-color.md)：两页非图表彩色面积 ≈1.5%（概览，电池弧为主）/ ≈0%（行程，常态无彩色位），均 ≤20%；图表主数据系列（每日里程柱、充电/费用柱线、参照虚线）豁免，选中标记与图例样本计入。彩色位清单见登记行。

## 5. copy guard 基线变化

- `drives_page.dart`：45 → **46**。新网格语法带来「里程」「里程未记录」「时长」三个新字面量行，同时删除 `_duration`/`_net`/`_recordDate` 的 5 行旧字面量行（含整行注释豁免的口径），净 +1 行；无旧文案放行（R10 映射：结构性新增字面量随登记升基线）。
- `overview_page.dart`：141 → **141**（接线只调用 `state_feedback` 构造，无新字面量行）。
- 内容检查（CP09 1–4 与精确旧串）无违规。

## 6. 测试结果

- `tool/flutterw analyze`（本包 6 个改动/新增文件）：**No issues found**。
- 本包页测试：`drives_test`（44 用例，含新增 3）、`overview_test`（9 用例，含新增 1）全过。
- 相邻面回归：`apple_polish_ap07/ap08/ap09`、`a_drives`、`a_overview`、`days_migration_state/color_guard/motion`、`apple_polish_copy_guard/copy_test`、`business_recovery`、`owner_experience`、`overview_briefing/visualization/verification/reading/statistics_reading`、`apple_polish_ap10/ap13/ap14`、`apple_polish_raw_value_guard`、`charging_reading`、`navigation_bar` 全过（唯一例外见 §7）。
- 断言映射明细（R10，无放宽）：记录行 `电耗 188 Wh/km`/`10:00–10:30，30 分钟` 整串断言 → 网格语法（标签 Text + MileafNumber 数值串）；`MileafDataRow` 行探针 → `drive-N` 行 key 探针（起始线/分隔线几何断言逐条保留）；统计失败句断言 → 三要素断言（数据截至 + 重试入口）；「查看当天」点按前补 `ensureVisible`（行高变化后的命中区修正，非放宽）。

## 7. 遗留与边界

- **既有非本包缺口**：`apple_polish_raw_value_guard_test` 的「基线覆盖」用例失败——DM04 提交（`c2af0c6`）的 `lib/src/copy/state_feedback.dart` 缺 `test/support/raw_value_baseline/lib/src/copy/state_feedback.dart.txt`。该文件不在本包 write scope，未代登；与 DM02 `icons.dart` 的 copy 基线缺口同类，属组件包收口项。本包页面裸值计数两文件均未升。
- **首屏预算**：记录行改网格后行高增加（每行约 +16–24），360×800 两条首屏预算断言（drives_test / ap07）实测仍通过，未动版面；若 DM08 全量复测临界，退让候选是行内路线行与网格间距（s8→s4），属页面包内回收。
- **MG06（s12）**：概览/行程焦点卡头→主值间距已由 DM03 在途改动落为 s12（PD12），本包未触碰。
- **行程列表失败条的时间要素**：现状句 `staleMessage` 内已含时刻（ap09 断言锁定该句），未再排 `statusLine`，避免同屏两次报时；若后续统一为「原因句 + statusLine」结构，需连 ap09 一起迁移（组件层 DM07/DM08 收口时一并处理）。
- 真机字体（PingFang 与测试字体的宽度差异）、读屏与性能仍属 #16/#17 外部 gate，本次不关闭。
- 本次不 git 提交、不推送；全部 flutter 命令经共享锁（/tmp/mileaf-flutter-lock）串行执行。
