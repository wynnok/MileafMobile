# 0004 充电页「我的补能方式」改为构成环

- 日期：2026-11-01
- 状态：accepted（2026-11-01 用户确认）
- 关系：实现 [ADR 0003](0003-visual-direction-a.md)「夜航」的 §9.5 充电增量；不改数据口径、不改 API、不改只读边界。
- 影响文件：`lib/src/charging_page.dart`、`lib/src/design/components/share_ring.dart`（新增）、`lib/src/design/tokens.dart`、`lib/src/design/components/components.dart`、`test/charging_test.dart`、`test/a_gallery_render_test.dart`。

## 1. 背景

**现状是五段等权文字。** `_composition()`（[charging_page.dart:1100–1166](../../lib/src/charging_page.dart#L1100-L1166)）依次渲染：8px 构成条 → 一行 `AC/DC/未知` legend → `DC占已知分类能量 …%` 句 → 分类时长句 → `分类已知 2/2 次` 句；`统计校验时间` 在 `build` 里另起一段 micro 文字（[:1788–1800](../../lib/src/charging_page.dart#L1788-L1800)）。六行文字字号相同（micro 9px / body 13px）、颜色相近（textMuted / textFaint），没有主次，读者必须逐行读完才知道"我到底怎么补能的"。

**同屏对比失衡。** 紧邻上方 `trend()`（[:985–1097](../../lib/src/charging_page.dart#L985-L1097)）已是「标题 + chip 切换 + stem 图 + 读数 + 动作」的完整图表段落；下方 `地点账目` / `最近的充电` 也都是结构化列表。只有补能方式是纯文本，在截图里成为整页最"干"的一段。

**数据边界决定了能做到什么。** 来自 `ChargingMetrics`（[charging_experience_contract.g.dart:498](../../lib/src/charging_experience_contract.g.dart#L498)）与 `ChargingBucket`（同文件 :310）：

| 可用 | 不可用 |
| --- | --- |
| 每类能量 `ac/dc/unknown_energy_kwh` | 每类次数 |
| 每类时长 `ac/dc/unknown_duration_min` | 每类费用 |
| `dc_energy_share`（分母仅 AC+DC） | 每类地点 |
| `classification_known_sessions` / `sessions` | 逐日每类次数 |
| 逐日每类能量（buckets） | — |

即：能画"构成比例"和"分类绝对量"，不能画"按类次数/按类花费"。任何设计都必须在这些边界内成立，不得用推导数字补位。

**用户诉求。**「现在全是文字，太干巴了，换成图表的表达方式。」并已确认：主视觉用构成环、能量为主时长作脚注、不做按类次数、区块内留一句口径、点击分类可跳到记录列表。

## 2. 决策

### D1 主视觉 = 100% 构成环（新组件 `MileafShareRing`）

用一整圈表示"已记录的分类能量"，按 AC / DC / 未知 分段，圆心给主类占比。

- 为什么是环，不是条：8px 条（`MileafCompositionBar`）在概览/补能专题里是"行内摘要"密度，放在本页这种**专题段落**里仍然像一条分隔线，撑不起主视觉。环与充电详情的电池弧（[battery_arc.dart](../../lib/src/design/components/battery_arc.dart)）同族，一个充电模块里出现同一种弧语言，是有意的视觉一致性。
- 为什么不做成第二块深色卡：ADR 0003 规定每页只允许一个深色锚点，本页已被费用 hero 占用（[:805–910](../../lib/src/charging_page.dart#L805-L910)）。本区块必须是"纸面"层级，用留白 + 1px 细线分组，不加卡片、不加阴影。
- 新组件而不是改 `BatteryArc`：电池弧的语义是"0–100 电量"，把分段构成塞进去会让两者互相污染（语义、轨迹色、中心标签规则都不同）。新组件只共享几何 token。

### D2 版式 = 结论 → 环 + 图例 → 三列绝对量 → 一句口径

```
我的补能方式
以 AC 为主                                  ← 结论（body 13 / text）
   ◜◝         ● AC    100%
  ◟◞ 100% AC  ● DC      0%
               ○ 未知    —
  ──────────────────────────────────────── 1px line
  AC           DC           未知           ← 分类名（label 10 / textMuted）
  40.18 kWh    0 kWh        —              ← 主数（metric-md 24）+ 单位（micro）
  1,614 分钟   0 分钟       0 分钟          ← 脚注（micro / textFaint）
  DC 占已知分类能量 0% · 分类已知 2/2 次        ← 短注（micro / textFaint）
```

- 图例给**比例**，三列给**绝对量**，两者不重复。当前版本把 `40.18 kWh` 与 `0%` 挤在同一行文本里，读者要自己做除法；现在这两件事各归其位。
- 结论句是新增的"结论先行"（Spec §1 第 2 条），一行、13px、不加重不加色，不做感叹、不判断好坏。
- `未知` 在有值时显示；为 0 且分类完整时隐藏（图例与三列同时隐藏），避免每天出现的 `未知 0 kWh` 噪声。`AC`/`DC` 永远显示——"从没用过快充"本身就是结论。

### D3 次要维度：能量为主，时长作每列脚注

不做"能量/时长"切换。理由：同屏上方 stem 已有 4 个 chip 控制，再引入一组切换会让"这一块到底在看什么"变得含糊；时长在每列脚注里始终可见，成本一行 9px 文字，收益是保住"慢充占时间、快充占能量"这个真实信号。

时长口径保持原样：`记录时长` 不是等待时间，且 `duration_known_sessions == 0` 时显示 `—`。

### D4 不做按类次数

`ChargingMetrics` 没有按类次数。用已加载记录推导会得到"分页到哪算哪"的数字，与统计页口径冲突，且需要额外的覆盖标注。本期只保留 `分类已知 N / M 次` 这一句，进短注。

### D5 口径分层：区块一句 + 数据说明

- 区块内只留一句：`DC 占已知分类能量 X% · 分类已知 N / M 次`。这句必须留，因为 DC 占比的分母是 AC+DC、不含未知，收起来会被误读成"DC 占全部能量"。
- 移出区块、进页尾 `数据说明`（现存 `_notes()`，[:1603–1625](../../lib/src/charging_page.dart#L1603-L1625)）：`各分类只含已记录电量，未知不并入 AC`、`统计校验时间`、`记录时长不是等待时间`。
- 现状把校验时间直接印在正文中间（[:1788–1800](../../lib/src/charging_page.dart#L1788-L1800)），一句 ISO 时间戳打断阅读节奏，是这一块"像看板"的直接来源之一。

### D6 交互：点分类 → 已按类型筛选的记录列表

图例每一行可点（≥44 高），点击后复用现有筛选链路：`chargeType = 'ac' | 'dc' | 'unknown'` → `recordsOnly = true` → `applyFilters()` → `scrollToTop()`。这条路径已在 `_locationRow` 里验证过（[:1445–1451](../../lib/src/charging_page.dart#L1445-L1451)），不新增接口、不新增状态。

- 为什么值得做：用户看到 `DC 0 kWh` 的第一反应是"真的吗"，需要一个能落地的核对入口；纯展示会把疑问留在原地。
- 不加 chevron：三个分类都加箭头会变成一排"待点按钮"，破坏阅读。可点性靠按压态（`accentSoft` 20%）与语义标签表达。

### D7 颜色：零新增

| 用途 | token | 说明 |
| --- | --- | --- |
| AC（主段） | `colors.accent` | 主系列 |
| DC | `colors.accent` @ 50% | 与现有 `seriesSecondary` 同值 |
| 未知 | `colors.textFaint` | 中性，不参与强调 |
| 轨道 | `colors.line` | 1px 视觉重量 |
| 结论 / 分类名 | `colors.text` / `colors.textMuted` | — |
| 主数 / 单位 / 脚注 | `colors.text` / `colors.textFaint` | — |

沿用 Spec §2.4 的既有规则：单个强调色 + 50% 台阶 + 中性，不引入第二强调色；状态色不用于数据系列。浅色模式直接取 `accent = #1C6B4F`，已验证 5.64:1。

## 3. 备选方案与放弃理由

| 方案 | 放弃理由 |
| --- | --- |
| B. 加粗到 12–14px 的 100% 构成条 + 三列读数 | 改动最小，但一块 14px 的横条仍不足以成为段落的视觉锚点；本区块需要的不是"更粗的线"，而是"一个能一眼读完的形状"。 |
| C. 逐日 AC/DC 堆叠柱 | 与上方 `每日补能` stem 共用时间轴，形成"两张时间图"；且本产品数据稀疏（近 30 天 2 次充电），逐日堆叠几乎全是空白列，读不出结构。 |
| D. 环 + 微堆叠趋势组合 | 一个段落两个主图，违反 Spec §9.7「一个主图」；首屏下移、页面变重。趋势需求已由上方 stem 的 chip 满足。 |
| 保留文字，只做排版分层（字号/颜色分级） | 解决不了"要读六行才知道结论"的根本问题；用户明确要求图表化。 |

## 4. 后果

**新增**

- `lib/src/design/components/share_ring.dart`：`MileafShareRing`，100% 分段环（轨道 + 2–3 段 + 圆心数字），动画 500ms 绘制、reduce motion 直出、语义摘要全覆盖。
- `MileafChartMetrics` 增补环几何常量（直径 104 / 大字号 88 / 描边 12 / 段间距 3），沿用 [tokens.dart](../../lib/src/design/tokens.dart) 现有分区（§8 图表几何）。

**修改**

- `_composition()` 重写为 D2 版式；`统计校验时间` 从正文移到 `_notes()`。
- `MileafCompositionBar` 保留：概览（[overview_page.dart:1313](../../lib/src/overview_page.dart#L1313)）与补能专题（[statistics_charging_page.dart:562](../../lib/src/statistics_charging_page.dart#L562)）仍是行内摘要语境，密度正确。是否统一为环，记入未决。

**测试影响**

- [charging_test.dart:544–556](../../test/charging_test.dart#L544-L556) 断言 `AC —` / `DC —` / `未知 —` / `分类记录时长缺失` 等文本，随版式改写；空态改为"环只剩轨道 + 圆心 `—` + 结论句 `还没有充电记录`"，仍需断言"不出现 `0.00 kWh`"。
- 图册（[a_gallery_render_test.dart](../../test/a_gallery_render_test.dart)）需新增本区块的滚动位渲染：360×800 × 浅/深 × 100/200% × normal/empty/missing。

**不改变**

- 数据口径、请求数量、分页、只读边界；hero、stem、地点账目；`MileafServer` 与 `teslamate` 仍只读参考。
- 记录列表唯一的改动：空区间时那行"此区间无已完成充电记录"补上页边距（原先贴屏幕左边，`_recentSection()` 复用了不带内边距的 `_recordsSection()`）。四行，属于同屏可见缺陷，记在此处而不是单独开票。

## 5. 已定数值（2026-11-01 用户确认）

1. **结论阈值**：`≥90%` → 「以 AC/DC 为主」；`60–90%` → 「AC 更多，DC 占 X%」（或反向）；`40–60%` → 「AC 与 DC 接近」；`≤10%` → 「以 DC/AC 为主」（同一规则的另一侧）。边界含等号按"为主/接近"优先。
2. **未知的显示条件**：`未知能量 = 0` 且 `classification_known_sessions == sessions` 时，图例与三列都不出现未知；其余情况出现。
3. **圆心读数**：主类占比 + 主类名（`100` + `%` + `AC`）。主类按能量取 AC / DC / 未知 的最大者。

## 6. 后续

- Spec 交付物：[`docs/specs/charging-method-share-ring.md`](../specs/charging-method-share-ring.md)（accepted）。
- 实施任务拆分：[`docs/specs/charging-method-share-ring-tickets.md`](../specs/charging-method-share-ring-tickets.md)。

## 7. 修订

- **2026-11-01 · D2 部分被 Spec R1 取代**：环不画"未知"段，只画 AC/DC 已知分类，与 `dc_energy_share` 同分母；未知改为第三列 + 短注声明"不计入构成"。原因：三段环会让同一屏出现两个不同分母的 DC 百分比。D2 的其余部分（结论 → 环 + 图例 → 三列 → 短注的版式）不变。
