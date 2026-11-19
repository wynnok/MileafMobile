# Days Matter 迁移 · DM01 色彩纪律实施记录

> 2026-11-19，DM01（MG01–MG03 色彩条款）实施记录。规格见 [days-matter-migration.md](../specs/days-matter-migration.md) §4「色彩体系」，决定见 ADR0015。本包只对 `lib/src/design/semantic.dart` 做 **additive** 追加（状态取色映射枚举），**不改任何色值**；`tokens.dart` / `components.dart` / `overview_page.dart` / `drives_page.dart` 有他人在途改动，本包未触碰。按任务边界不做 git 提交，由主会话统一提交。

## 1 对比度守卫结论（MG03）

守卫测试 `test/days_migration_color_guard_test.dart`：复用 `test/support/color_math.dart` 的 WCAG `contrastRatio`，遍历「语义前景 × 声明背景」登记表（登记在测试内 `_registry`，每条注明声明用途与门槛），浅色 / 深色 `MileafColors.light()` / `MileafColors.dark()` 各跑一遍。口径：

- 正文类 ≥4.5:1：`text` / `textSecondary` / `textFaint` / `accentStrong` 作文字 / `textOnAccent`，声明底为 canvas、surface、hero（hero 三档另列）、segmentTrack、accentSoft。
- 图形与边框类 ≥3.0:1：`accent` / `controlBorder` / `reference` / `warning` / `error`（`accentStrong` 作图形），声明底为 canvas、surface。
- 深色 `accentSoft` 是 16% azure 半透明（`0x2964A8FF`），先按 `compositeOver` 合成再算对比度，over canvas 与 over surface 各记一条。浅色 `accentSoft` 不透明 `#DCEBFD`。
- `surfaceRaised`：浅色 = surface、深色 = segmentTrack（slate850），不单列。

### 1.1 结论表（实测摘要）

| 前景 | 声明底 | 门槛 | 浅色实测 | 深色实测 | 结论 |
| --- | --- | --- | --- | --- | --- |
| text | canvas / surface / segmentTrack / accentSoft / hero | 4.5 | 17.10 / 18.65 / 15.32 / 15.41 / 18.65 | 17.87 / 16.47 / 15.20 / 14.21 / 16.47 | 全部达标 |
| textSecondary | canvas / surface / segmentTrack / accentSoft / hero | 4.5 | 5.38 / 5.87 / 4.82 / 4.85 / 5.87 | 7.87 / 7.25 / 6.69 / 6.26 / 7.25 | 全部达标 |
| textFaint | canvas / surface / hero | 4.5 | 4.65 / 5.07 / 5.07 | 5.59 / 5.15 / 5.15 | 达标（保留现值） |
| textFaint | segmentTrack / accentSoft | 4.5 | **4.17 / 4.19** | 4.76 / **4.45**（over surface **3.96**） | 浅两条与深合成两条不达标 → §1.2 豁免 |
| accent（图形） | canvas / surface | 3.0 | 3.25 / 3.55 | 8.05 / 7.42 | 达标 |
| accentStrong（图形） | canvas / surface | 3.0 | 5.41 / 5.90 | 8.05 / 7.42 | 达标 |
| accentStrong（作文字） | canvas / surface | 4.5 | 5.41 / 5.90 | 8.05 / 7.42 | 达标 |
| controlBorder | canvas / surface | 3.0 | 3.51 / 3.83 | 3.95 / 3.64 | 达标 |
| reference | canvas / surface | 3.0 | 4.99 / 5.44 | 6.80 / 6.27 | 达标 |
| warning | canvas / surface | 3.0 | 4.60 / 5.02 | 10.77 / 9.92 | 达标 |
| error | canvas / surface | 3.0 | 4.90 / 5.34 | 7.75 / 7.15 | 达标 |
| textOnAccent | accentStrong 实色填充 | 4.5 | 5.90 | 8.05 | 达标 |
| heroText / heroMuted / heroFaint | hero | 4.5 | 18.65 / 5.87 / 5.07 | 16.47 / 7.25 / 5.15 | 达标 |

### textFaint 裁决

以 [overview-chart-header.md:79](overview-chart-header.md) 的 WCAG 复测口径为准：浅 `#63707C` 在 canvas `#F4F5F7` 上 4.65:1、surface `#FFFFFF` 上 5.07:1；深 `#7E8A96` 在 canvas `#0A0B0D` 上 5.59:1、surface `#12161C` 上 5.15:1，均在 AA 4.5:1 以上。**textFaint 现值 #63707C / #7E8A96 保留不变**；本次守卫自动化了该口径（调色板触碰下限即测试失败）。[overview-reading.md](overview-reading.md) §6 的旧结论与复测矛盾，已按 MG03 以文末追加批注方式订正，未改写原文。

### 1.2 低于门槛组合（自动断言豁免，待用户裁定）

| 组合 | 实测 | 说明 |
| --- | --- | --- |
| textFaint × segmentTrack（浅） | 4.17 | textFaint 声明用途是占位符 / 禁用态 / 非文字装饰（semantic.dart:42-43）；segmentTrack 是分段控件中性轨道底。同底 textSecondary 实测 4.82 ≥4.5，出现该用法时应换 textSecondary |
| textFaint × accentSoft（浅，#DCEBFD） | 4.19 | 同上；textSecondary 同底 4.85 ≥4.5 |
| textFaint × accentSoft 合成底 over canvas（深，#182434） | 4.45 | 深色 accentSoft 为 16% 半透明，按合成口径实测；仅差 0.05 |
| textFaint × accentSoft 合成底 over surface（深，#1F2D40） | 3.96 | 同上 |

四条均为 textFaint 压中性 / 弱彩色装饰底的组合，属外观 v2 调色板层遗留；按 MG03「不改色值」裁决，把它们从自动断言降级为记录性测试（实测值打印并在测试注释登记），**待用户裁定**：若未来出现 faint 文字压这两类底的用法，需在调色板层独立抬档或在页面层换 textSecondary。图形与边框类未发现低于 3.0 的组合；其余全部组合达标。

## 2 状态取色映射表（MG02）

实现：`semantic.dart` 文末 additive 追加 `enum MileafStatusTone { neutral, accent, warning, error }` 与扩展 `MileafStatusToneColorResolver`（`resolveColor(MileafColors)`）。这是 DM04 StateView / InlineBanner 色彩参数的数据源，签名冻结（tone + MileafColors → Color）。

| 状态 | tone | 解析色 | 说明 |
| --- | --- | --- | --- |
| 进行中 / 加载 | `accent` | `accentStrong` | 文字级强度；进行中胶囊底维持中性 segmentTrack，不随状态变彩 |
| 警示（数据异常、Key 失效） | `warning` | `warning` | |
| 失败 / 破坏 | `error` | `error` | |
| 缺失 / 未知 / 未记录 | `neutral` | `textSecondary` | **禁止任何彩色**；守卫测试在 token 级钉住：neutral 解析结果 ≠ accent / warning / error（「缺失数据永不彩色」） |
| 参照 / 基线 | （不入枚举） | `reference` | reference 是图表读值的对比角色而非状态角色，由图表 / 读值组件直接使用 `MileafColors.reference`，不经状态枚举转发 |

## 3 彩色面积登记表模板（MG01）

逐页登记非图表彩色面积占比，目标 ≤20%；图表绘图区的主数据系列（accent / seriesSecondary / reference）不计入预算，图例、轴文字、选中标记计入。超标页在所属页面包内整改（彩色从装饰位挪到功能位或降为中性），不得靠压饱和度凑数。

| 页面 | 浅色彩色面积估算 | 深色彩色面积估算 | 是否 ≤20% | 豁免 / 整改记录 |
| --- | --- | --- | --- | --- |
| 概览（根页） | 待补齐 | 待补齐 | — | |
| 行程（根页） | 待补齐 | 待补齐 | — | |
| 充电（根页） | 待补齐 | 待补齐 | — | |
| 统计（根页） | 待补齐 | 待补齐 | — | |
| 行程详情 | 待补齐 | 待补齐 | — | |
| 充电详情 | 待补齐 | 待补齐 | — | |
| 连接 | 待补齐 | 待补齐 | — | |
| 设置 | 待补齐 | 待补齐 | — | |

> 量化采集由页面包渲染图册补齐（DM05–DM07 各页面包，图册入库 `docs/implementation/days-matter-migration-renders/`）；本包只交付模板与口径。

## 4 验证

- `tool/flutterw analyze`：0 诊断。
- `tool/flutterw test test/days_migration_color_guard_test.dart`：自动断言与记录性组合、MG02 映射 / neutral 永不彩色全部通过。
- 改动文件：`lib/src/design/semantic.dart`（additive 追加）、`test/days_migration_color_guard_test.dart`（新）、本文件（新）、`docs/implementation/overview-reading.md`（仅文末追加批注）。
- 本次不 git 提交（按 DM01 边界由主会话统一提交）；不推送。