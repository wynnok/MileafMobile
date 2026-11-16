# 概览图表头重排实施记录

2026-11-16 在 `main` 工作区完成（基线 `7b1ca30`，未推送）。条款依据 [焕新规格](../specs/ui-ux-refinement.md) R01（对齐与间距档位：标题到所属内容 12、控件间 8）、R02（字阶）、R06.3（主图分区）、R06.5（主线 2 / 参照 1.5 虚线 4-4）、R07（微动效白名单）与 §1.4；头部与图例的先后顺序来自用户本次要求（一行只讲一件事），不是从 R06.6 借来的——R06.6 管的是图下读值结构，本切片未动。配色、字号、圆角一律沿用既有 token，未新增颜色、字号、圆角或动效 token。

## 1 问题

用户指出红框处「可读性有点差，排版和秩序感非常差」。改动前那张图表的头部由三块碎片挤在同一光学行上：

| 改动前 | 后果 |
| --- | --- |
| 标题 `每日里程`（20） | 唯一说得清的东西，但被两侧不断争夺 |
| 副标题 `11.01 — 11.16\nkm`（14 淡） | 单位被塞进区间字符串、用 `\n` 强制折行，`km` 孤零零挂在日期下面，读起来像第二个区间 |
| 图例 `— 里程  -- 上月同期`（12 淡） | 被 `Row` 顶到标题右侧，与副标题抢同一行；色块与文字基线不齐，右端参差 |

三件事是三种不同身份（名称 / 窗口 / 标记 key），却共享一行同一档字号，读者只能逐字分辨谁是谁。单位与区间折行还使这一行在 320 宽、200% 字号下高度不稳。

## 2 设计

一条阅读顺序取代一行碎片：**名称 → 度量 → 窗口 →（指标控件）→ key → 图形**。

```
每日里程  km                          10.01 — 10.26
[ 里程 ][ 电耗 ][ 补能 ][ 费用 ]
- - 上月同期
▁▂▃▄▅ 绘图区
```

| 行 | 内容 | 角色 |
| --- | --- | --- |
| 1 左 | `每日里程` | `type.title`（20/28/600）`text` |
| 1 中 | `km` | `type.micro` 12 `textFaint`，与标题间距 6（与 `MetricBlock` 的「标签→值」同一对节奏）；它是标题所命名坐标轴的度量，不是第二个标题 |
| 1 右 | `10.01 — 10.26` | `type.label` 14 500 `textFaint`，右端与绘图区右沿同一线；长区间可收窄换行，不顶破标题行 |
| 2 | 指标控件 | 既有 `ChipRow`；标题到所属内容 12（R01），控件之后回到 8 |
| 3 | 图例 | `type.micro` 12 `textMuted`，条目间距 16；样本取自 `MileafChartMetrics`（主线 2、参照 1.5 且 4/4 虚线、宽 = `barMaxWidth`），与绘图区同一套几何 |
| 4 | 绘图区 | 与图例间距 8 |

三条规则：

1. **一行只讲一件事。** 标题左固定、窗口右固定，读起来是「名称 … 窗口」，与页面里的 `SectionHeader`（标题左、日期右）同构——图表头和它上面的章节标题不再各说各话。
2. **单位跟着它标注的轴。** 单位不再是区间字符串的一部分，而是标题旁的度量；与轴刻度同用 `textFaint` 一档，因为它们同为「标尺文字」。
3. **图例只标注位置指认不出的标记。** 三条规则按顺序生效：单系列不出图例；单测量 + 参照、且这个测量已被指标控件点名时只列参照（实心系列的名字已经在标题和控件里出现过两次，再配色块就是第三次命名）；色块只在它能指认时才画——绘图区只拿得到一个主色，多测量（净/毛电耗、AC/DC）的线同色，给每条都画同色块等于宣称它们相同，所以只列名字，参照虚线因为形状不同永远带样本。

**大字与窄屏**：100% 时标题行单行容纳（390 与 320 实测）；200% 时窗口落到标题下一行、左缘与标题同一线（与 `SectionHeader` 的堆叠规则一致），不再出现两行锯齿。`headerTrailing`（充电页的指标控件）从「与标题同排」改为「标题之下一行」，控件不再被 17 号标题挤压。

## 3 变更

| 文件 | 变更 |
| --- | --- |
| `lib/src/design/components/charts.dart` | 新增 `_ChartHeading`（标题 + 度量 + 窗口，含大字堆叠与长区间的可收窄行）、`_ChartLegend` 与 `_LegendMark`（几何全部取自 `MileafChartMetrics`）；`_legendEntries()` 决定图例条目与是否画色块；删除旧 `_Legend`。图例从标题右侧移到绘图区之上（控件之后），头部/控件/图例由 `chrome` 列表串起（标题后 12，其余 8）；空采样分支复用同一 `chrome` |
| `lib/src/overview_page.dart` | `mainChart()` 的 `subtitle` 由 `'${_rangeText(evidence) ?? ''}\n$unit'` 改为 `_rangeText(evidence)`——单位不再混进区间字符串 |
| `lib/src/sample_chart.dart` | 删掉 `subtitle`（唯一用途是传「点按图形读值」这句提示语）与图表下方单独的 `unit` 行：提示语改为 `trailing` 落在读值旁，单位由头部承担，同一屏不再出现两次单位 |
| `lib/src/drive_detail_page.dart` | 两处 `SampleChart` 去掉 `subtitle: '点按图形读值'`，提示语跟着读值走，不再占窗口槽位 |
| `test/design_components_test.dart` | 图例断言改为新契约（有控件的单测量只列参照、多测量只列名字且不画同色块）；新增 5 条合同测试：标题/单位/区间同行且各归其位、200% 时区间落到下一行同左缘、`headerTrailing` 独占标题下一行、图例排在控件之下绘图区之上、320 宽 130% 长区间不横向溢出 |
| `test/statistics_test.dart` | 刷新动作的两次点击改为沿用文件已有的 `Scrollable.ensureVisible(…, alignment: .5)` 手法（抽成 `tapRefresh`）。改前的 `scrollUntilVisible(-300)` 会把按钮停在页头淡出区边缘，与「量到的位置」差 26px 就点不中——本次头部高度变化正好触动这个临界点，属于测试写法脆弱，不是产品回归 |

`TimeSeriesChart`/`StemChart` 的公共参数未变：`title`/`unit`/`subtitle`/`controls`/`headerTrailing` 语义与签名保持原样，行程、统计四图、充电专题、充电详情、洞察页自动继承新的头部排版。只有 `subtitle` 的用途被收窄为「窗口」——三处曾经拿它传提示语的调用点（行程详情的两处「点按图形读值」、统计补能专题的「按结束日」）随之审过：前两处改走 `SampleChart` 的 `trailing`（提示跟着读值），后者本身就是在说明窗口口径，留在窗口槽位成立。

## 4 动效

本切片**不新增动画**。R07 的白名单里没有「图例行出现/消失」这一项，而图例的出现与消失必然改变行高——用高度过渡去动画它是 R07 明确禁止的「宽度/高度过渡」。这一区已有的动作照旧：指标 chip 按压 100ms、互斥选中 180ms、换指标时读值 120ms 淡入（`MileafDurations.value`，减少动效归零）。拖动取点仍原地更新数字，头部与图例不动。

## 5 验证

| 项 | 结果 |
| --- | --- |
| `tool/flutterw analyze`（`charts.dart`、`overview_page.dart`、`design_components_test.dart`） | 无诊断 |
| `tool/flutterw test test/design_components_test.dart` | 56 通过（图表组含本次新增 5 条） |
| `tool/flutterw test test/overview_reading_test.dart` | 5 通过（含新增 1 条图表头合同） |
| `tool/flutterw analyze`（全项目） | 无诊断（12.2s） |
| `tool/flutterw test` 全量 | 754 通过 / 33 跳过 / 0 失败（opt-in 渲染入口在默认运行中跳过） |
| `tool/flutterw dart format --set-exit-if-changed`（本次改动的 Dart 文件） | 通过；`overview_page.dart` 的其余格式漂移来自基线 `7b1ca30`，未顺手整篇重排 |
| 图证 | [overview-chart-header-renders](overview-chart-header-renders/README.md)：改动前后 390 浅色、深色、320、200%，以及同一组件在行程/统计/充电详情页的连带效果 |

合成数据为既有 `cGalleryClient` 夹具，390×844 / DPR 2、`Asia/Shanghai`、Inter + 系统 CJK 回退，字体路径 `/System/Library/Fonts/Supplemental/Arial Unicode.ttf`。

## 6 遗留与边界

- **多测量仍无法用颜色对上线**：`_ChartPainter` 只接收 `primary` 与 `reference` 两个颜色，所以 `净电耗`/`毛电耗`、`AC`/`DC` 的线在图上同色。图例因此只列名字、不画色块（画了就是在宣称它们相同），但读者仍无法指着某条线说它是哪一条。语义层已经备好 `seriesPrimary`/`seriesSecondary`/`seriesNeutral` 三档（含实测对比度），图表尚未按序号取用——那是绘图区配色切片，会改动统计等页面的图形，本切片未擅自扩大范围。
- **`textFaint` 的对比度（本轮实测，WCAG 相对亮度公式）**：浅色 `#63707C` 在 canvas `#F4F5F7` 上 4.65:1、在 surface `#FFFFFF` 上 5.07:1；深色 `#7E8A96` 在 canvas `#0A0B0D` 上 5.59:1、在 surface `#12161C` 上 5.15:1；对应 `textMuted` 依次为 5.38 / 5.87 / 7.87 / 7.25。即 faint 处处比 muted 淡、但仍在 AA 线以上——上一轮记录里「比 muted 更实且低于 4.5:1」的说法与本轮实测不一致，可能是当时取的是 `heroFaint` 或玻璃底上的合成值。本轮未改调色板；若要统一抬档，应作为外观层的独立改动。
- **`test/readability_render_test.dart` 的 `overview-long-*-200` 场景在基线 `7b1ca30` 上就已失败**（缺 `本月 · 驾驶里程` / `1,198.6` 断言）：本次把 `charts.dart` 与 `overview_page.dart` 换回 HEAD 复跑，失败信息完全一致，与本切片无关；该入口默认运行中被跳过，未在本次修。
- 真机字体、读屏朗读顺序与性能仍在 #16/#17 的外部 gate 内；本轮只做 App＋可控 HTTP 的自动化与合成渲染。
- 本次仅本地实施，未推送、未部署。