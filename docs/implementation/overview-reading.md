# 概览读数区重排实施记录

2026-11-16 在 `main` 工作区完成（基线 `5c7683f` 之上的本地改动，未推送）。条款依据 [焕新规格](../specs/ui-ux-refinement.md) R06.3（主图分区）、R06.6（读值语义结构）、R06.8（覆盖限制在图旁）、R07（微动效）与 §1.4 间距档位；配色与字号沿用 [ADR 0012](../adr/0012-apple-design-renewal.md) 落地的 token（`label` 14、`micro` 12、`body` 17、`metricMd` 24），未新增颜色、字号或圆角。

## 1 问题

改动前，图表下方是 `_auxReadout()`：一个 `Text`，把 7–10 行用 `\n` 拼成一段——3 行选中点读数、7 行本期指标、2 行口径，全部同一字号同一颜色。后果：

- **没有层级**。选中日的读数与本期总量是两种数据身份，却并排成同一段文字；读者只能逐行扫描。
- **没有秩序**。每一行都是「名字 + 值 + 单位 + 说明」的完整句子，9 行左边缘对齐但内部节奏各不相同，形成锯齿。
- **读数混入账目**。图表读值属于「某个点」，本期指标属于「整个区间」，混排后切换指标时整段文字一起变，看不出哪一部分跟着变。
- **窄屏与大字退化**。320 宽和 200% 字号下，长行折行后行数翻倍，读数被埋在中间。

## 2 变更

| 文件 | 变更 |
| --- | --- |
| `lib/src/overview_page.dart` | `mainChart()` 内新增 `_PointReading`/`_ChartReading`：把选中点拆成日期、值、参照、差值、备注五个角色，经 `readoutBuilder` 交给图表；删除 `_auxReadout()`，新增 `_readingCell()` 与 `_readingPlate()`（1px 分隔线 + 本期标题 + `MetricGrid` 四格 + 单段口径脚注）；`_chartSection()` 在 `driving != null \|\| charging != null` 时接上读数表 |
| `lib/src/design/components/charts.dart` | `TimeSeriesChart` 新增可选 `readoutBuilder`；读值块抽成 `_readingBlock()`。给了 builder 时 `readout` 句子改为 live region 的 `Semantics(label: …)` + `excludeSemantics`，可见排版与朗读句子不会分叉；下钻按钮移到 live region 之外，保留「看当天」可达；绘图区到读值同为 §1.4 的 8（原 6）。未给 builder 的调用方（行程、充电、统计）行为不变 |
| `test/overview_reading_test.dart` | 新增 4 条合同测试：分组与脚注、读值的日期/参照/差值、换指标后同步、200% 单列 |
| `test/overview_reading_render_test.dart` | 新增图证生成器：浅/深 × 390·100、390·200、320·100，另加 200% 滚动到读数表的裁切帧 |
| `test/a_overview_test.dart`、`overview_a_regression_test.dart`、`overview_briefing_test.dart`、`overview_statistics_reading_test.dart`、`ui_ux_u04_test.dart`、`owner_experience_test.dart` | 断言从「整段文字包含某行」改为按读数格键（`overview-plate-net` 等）与图表读值键断言；缺失值断言收紧到净电耗格内的 `—`，参照行仍断言「区间与取值成对」 |

页面其余部分（月份里程、图表本体、最近记录、继续行程、数据说明）与路由、API、配色均未改动。

## 3 版式

图表下方分成两件东西，而不是一段文字。

**读值**（属于图表，跟着选中的点走）

| 行 | 内容 | 角色 |
| --- | --- | --- |
| 1 | `10/26` · 右侧 `点按读值` | `label` 14 `textMuted` · `micro` 12 `textFaint` |
| 2 | `60.0` + `km` | `metricMd` 24 |
| 3 | `上月同期 09.01 — 09.26，55.4 km` | `micro` 12 `textMuted` |
| 4 | `差 +4.6 km` | `label` 14 `text` 500 |
| 5（仅不可比时） | `口径或覆盖待核验，仅展示原值` | `micro` 12 `textMuted` |

R06.6 的顺序在这里是字面顺序：日期 → 值+单位 → 参照 → 差值。参照与差值各占一行而不是并排：并排时 320 宽会把 `55.4 km` 拆成孤字，分行使 24 → 12 → 14 的节奏在每个宽度都成立，大字下无需另一套布局。参照保留真实区间名与区间值，不写百分比；不可比时只降级为「仅展示原值」，不伪造差值。

**本期读数表**（属于区间，跟着期间走）——度量值取 `metricMd`，与读值同一档，两者是同级结果而非标题：

```
────────────────────────────────
本期
净电耗  158 Wh/km      已知费用  ¥186.4
                                 8/9 次已记录
补能   234.70 kWh      驾驶      46 趟
缺失的费用不表示免费。净电耗与驾驶消耗为估算。
```

- 四格用共享 `MetricGrid`：两列等宽、间距 16（与 `MetricGrid` 默认一致），大字下同组件自动单列，不再手写两套 Row/Column。
- 标签 14 `textFaint`，单位随值，缺失一律 `—` 且不带单位；`净电耗`、`已知费用` 等键名稳定，供测试定位。
- 费用覆盖（`8/9 次已记录`）从表尾句子里搬进费用格的 `note`：它是这个数字的限制，属于数字旁边（R06.8），不是页面脚注。币种未记录时与覆盖用「，」并列。
- 口径收成一段 12 号脚注：`缺失的费用不表示免费。净电耗与驾驶消耗为估算。`
- 不再在表头重复区间（`本期 10.01 — 10.26`）：同一屏的章节标题已给出当前区间，重复既啰嗦，又会在切到费用时与图表副标题的窗口口径不一致。

## 4 动效与语义

- **只在换指标时淡入**：`AnimatedSwitcher` 的 key 取指标名而不是「指标+选点」，所以横向拖动取点时读值原地更新、数字不闪（R06.6「不随手指滚动数字动画」、R07「局部快照更新」），换指标才 120ms 淡入；减动效下为 0ms。
- **只布局进场子项**（`layoutBuilder: (current, _) => current`）：块在首帧就取最终高度，参照行消失的指标（费用）不会在切换结束后把下方读数表顶上去。
- **朗读单一来源**：图表的 `readout` 句子仍是 live region 文本（含值、参照、差值），组合视图 `excludeSemantics`；下钻按钮留在 live region 之外，将来页面同时传 builder 与 `onActivateSelected` 时「看当天」不会连同语义一起被吞掉。
- **读数表**：每格 `MetricBlock` 的 `semanticLabel` 读成「净电耗 158 Wh/km」「已知费用 ¥186.4，8/9 次已记录」，不缺单位、不漏限制。

## 5 设计迭代（保留判断过程）

1. **先试「压成两列但仍是一块文字」**。把 7 行按两列排版、字号不变，行数减半但层级没变——读者仍不知道先看哪一行。结论：问题不是行数，而是没有角色区分，于是拆成「读值」与「读数表」两件东西。
2. **单位和值的重复**。第一版 `MileafNumber` 的 unit 与读值文本各自带单位，渲染出 `60.0 km km`。改为 `text()`（只出数字）与 `amount()`（数字+单位）两个帮手，金额走 `amountValue`，缺值时 unit 传 null，避免 `— Wh/km`。
3. **320 宽 + 200% 标题行溢出**。`本期` 与区间名挤在一行触发 `RenderFlex overflowed`；后来直接去掉表头区间，这条路径消失，大字标题也不再需要堆叠分支。
4. **换了指标页面往下跳**。费用没有参照行，`AnimatedSwitcher` 默认把进出两份布局叠高，淡出结束时高度骤降。改用只布局进场子项的 `layoutBuilder`。
5. **没有驾驶也没有充电时出现空表**。四格全是 `—`，等于给读者一张空表；改为 `driving != null || charging != null` 才渲染。
6. **参照与差值并排会把单位挤成孤字**。第一版把 `差 +4.6 km` 放在值行右侧、参照在下一行；320 宽下参照折行只剩 `km`。改为参照、差值各占一行后，任何宽度都不再挤压。
7. **「点按读值」写了两遍**。页面 `trailing` 与读值块各有一处；现在只在读值块里写一次。

## 6 对照度

浅色下 `textMuted` = `mist500` `#9AA5B1`，`textFaint` = `mist600` `#7E8A96`，在白底分别约 **2.50:1** 与 **3.52:1**；深色下 `graphite600` / `graphite500` 在 `#0A0B0D` 上约 **3.35:1** / **3.88:1**。也就是说这套调色板里 `textFaint` 在两种模式下都比 `textMuted` 更实，且都低于 4.5:1——这是外观 v2 遗留的全局问题，逐页修不在本次范围；本次沿用既有安静层级（标签 `textFaint`、口径 `textMuted`），不新造色值，避免与其余页面不一致。要真正达标需在调色板层统一提升这两档，属于独立事项。

## 7 图证

`docs/implementation/overview-reading-renders/`：`before-*`（改动前同一读数区）、`overview-reading-{light,dark}-390-100`、`-320-100`、`-390-200`、`-plate-*-390-200`（200% 下滚动到读数表）。生成命令见该目录 `README.md`。

图证证明本地 Flutter 合成与排版（Arial Unicode 中文回退、Inter 项目字体、DPR 2），不替代真机字体回退、读屏与性能验收。

## 8 验证

- `./tool/flutterw analyze`：No issues found。
- `./tool/flutterw test --no-pub`：734 通过 / 32 跳过 / 0 失败（跳过项为需外部环境的既有用例）。
- 定向：`overview_reading_test.dart` 4 通过；`a_overview_test.dart`、`overview_a_regression_test.dart`、`overview_briefing_test.dart`、`overview_statistics_reading_test.dart`、`ui_ux_u04_test.dart`、`owner_experience_test.dart` 共 76 通过 / 3 跳过。
- 图证矩阵覆盖浅/深、390/320 宽、100%/200% 字号；绘图区高度、Y tick 数与轴布局未改动，仍满足 R06.3–R06.5。

## 9 未验证

- 真机字体回退（PingFang / Noto）下的读数换行与读数表列宽（#17）。
- TalkBack / VoiceOver 对 live region 与四格 `semanticLabel` 的实际朗读顺序（#17）。
- 概览图表本身没有「看当天」目的地（概览不下钻单日），因此 R06.6 的下钻在本页仍由「点按读值」承担；若将来要给概览加单日目的地，接 `onActivateSelected` 即可，语义位置已预留。
- 冷启动与滚动时的合成成本（#16）。
- 本次仅本地提交，未推送、未部署；外部 gate #11 / #16 / #17 状态不变。

## 10 回滚

读值区改动集中在 `overview_page.dart` 的 `_PointReading`、`_ChartReading`、`_readingCell`、`_readingPlate` 与 `_chartSection()` 的一行挂载；恢复旧的单段文字需同时移除 `charts.dart` 的 `readoutBuilder`（其余调用方不传该参数，移除不影响它们）。配色、字号、间距 token 未改动，无需回滚设计系统。
