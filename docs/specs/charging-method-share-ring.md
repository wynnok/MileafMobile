# 充电页「我的补能方式」构成环 · 设计规格

- 日期：2026-11-01
- 状态：accepted（2026-11-01 用户确认，含 R1）
- 上游：[ADR 0004](../adr/0004-charging-method-visual.md)（accepted）
- 基线：[视觉系统 A「夜航」](visual-system-a.md) §2 颜色、§3 字体、§4 间距、§5 圆角、§8 图表、§9.5 充电
- 实现落点：`lib/src/charging_page.dart`、`lib/src/design/components/share_ring.dart`（新增）、`lib/src/design/tokens.dart`、`lib/src/design/components/components.dart`

## 0. 一句话

用"一圈环 + 一句结论 + 三列绝对量"替换六行等权文字；环只表达 AC/DC 已知分类的构成，其余信息分层下沉，口径离开正文。

## 1. 范围

**改**：`_composition()`（[charging_page.dart:1100–1166](../../lib/src/charging_page.dart#L1100-L1166)）整段重写；`统计校验时间` 从正文（[:1788–1800](../../lib/src/charging_page.dart#L1788-L1800)）迁入 `_notes()`（[:1603–1625](../../lib/src/charging_page.dart#L1603-L1625)）。

**不改**：费用 hero（[:805](../../lib/src/charging_page.dart#L805)）、三读数（[:912](../../lib/src/charging_page.dart#L912)）、每日补能 stem（[:985](../../lib/src/charging_page.dart#L985)）、地点账目、记录列表、筛选、分页、请求。数据口径与只读边界不变。

## 2. 结构

```
我的补能方式                                      ← SectionHeader（18/600，不变）
                                                      ↕ 8
以 AC 为主                                        ← 结论（body 13/400 · text）
                                                      ↕ 16
    ╭────╮          ● AC                    100%   ← 图例（行高 44）
   │ 100% │         ● DC                      0%
   │  AC  │
    ╰────╯          （环 104 · 描边 12）            （图例列宽 = 内容宽 − 128）
                                                      ↕ 20
──────────────────────────────────────────────   ← 1px line
                                                      ↕ 16
AC                    DC                    未知       ← 列名（label 10/500 · textMuted）
40.18 kWh             0 kWh                 —        ← 主数（metric-md 24/500）+ 单位（micro 9）
1,614 分钟            0 分钟                0 分钟     ← 脚注（micro 9 · textFaint）
                                                      ↕ 12
DC 占已知分类能量 0% · 分类已知 2/2 次                ← 短注（micro 9 · textFaint）
```

- 层级：结论（text）> 主数（text）> 图例百分比（text）> 列名（textMuted）> 脚注与短注（textFaint）。三档文字色，全页不新增颜色。
- 没有卡片、没有底色、没有阴影。区块边界只靠 28px 段间距（由调用方 `MileafSpace.section` 保证）与一条 1px 细线。
- 环与图例同一行；三列在该行之下，用细线隔开，形成"构成 → 绝对量"的读序。

### 2.1 纵向尺寸（100%，360 宽）

| 元素 | 高 |
| --- | --- |
| SectionHeader | 22（title 行高） |
| 结论 | 20（body 行高 19.5） |
| 环 / 图例块 | 104 |
| 三列 | 13 + 6 + 26 + 6 + 12 = 63 |
| 短注 | 12 |
| 间距合计 | 8 + 16 + 20 + 16 + 12 = 72 |
| **合计** | **≈ 293**（现状约 136） |

高度增加 157px 是这次改造的实际代价：换来的是一个能在 0.5 秒内读完的结论与形状，而不是六行待读文本。页面首屏仍由 hero 主导，本区块位于第二屏。

## 3. 排版

| 元素 | token | 字号/行高/字重 | 颜色 |
| --- | --- | --- | --- |
| 区块标题 | `type.title` | 18 / 22 / 600 / -0.01em | `colors.text` |
| 结论 | `type.body` | 13 / 19.5 / 400 | `colors.text` |
| 图例分类名 | `type.body` | 13 / 19.5 / 400 | `colors.textMuted` |
| 图例百分比 | `type.body` + tabular | 13 / 19.5 / 500 | `colors.text` |
| 圆心数值 | `type.metricMd` | 24 / 26 / 500 / -0.03em | `colors.text` |
| 圆心单位 `%` | `type.micro` | 9 / 12 / 500 | `colors.textFaint` |
| 圆心分类名 | `type.micro` | 9 / 12 / 500 / 0.12em | `colors.textFaint` |
| 列名 | `type.label` | 10 / 13 / 500 / 0.08em | `colors.textMuted` |
| 列主数 | `type.metricMd` | 24 / 26 / 500 / -0.03em | `colors.text` |
| 列单位 | `type.micro` | 9 / 12 / 500 | `colors.textFaint` |
| 列脚注 | `type.micro` | 9 / 12 / 500 | `colors.textFaint` |
| 短注 | `type.micro` | 9 / 12 / 500 | `colors.textFaint` |

规则：

- 所有数字 `FontFeature.tabularFigures()`，走 `MileafNumber` 或同一 helper；百分比与能量同一处理。
- 主数 + 单位用 `Text.rich`：数字一个 span，单位一个 span，单位比数字小 3 级。
- 单位不换行到数字**上一行**；列宽不足时单位下移到数字下方独立一行（不做缩小、不做 `FittedBox`），判定阈值见 §10.1。
- 中文不转大写、不加字距；`AC` / `DC` 保持大写。
- 未知一律 `—`（U+2014），真实 0 显示 `0`；负数 `−`，本区块不出现负数。

## 4. 颜色

| 用途 | 深色 | 浅色 | token |
| --- | --- | --- | --- |
| 环 AC 段 | `#74DDA8` | `#1C6B4F` | `colors.accent` |
| 环 DC 段 | accent @ 50% | accent @ 50% | `colors.accent.withValues(alpha: .5)` |
| 环轨道 | `rgba(242,245,240,.09)` | `rgba(18,22,19,.11)` | `colors.line` |
| 图例点 AC | `#74DDA8` | `#1C6B4F` | `colors.accent` |
| 图例点 DC | accent @ 50% | accent @ 50% | 同上 |
| 细线 | `colors.line` | `colors.line` | — |

- 只有一个强调色 + 一个 50% 台阶；**没有第二强调色**。状态色（warning / error）不进入本区块。
- 未知不参与环（见 §5.1），因此环最多两段，不存在"三色环"。
- 对比度沿用 [Spec §2.4](visual-system-a.md#24-对比度)：结论 `text/canvas` 18.16（深）/ 16.00（浅）；列名 `textMuted/canvas` 6.59 / 4.94；脚注 `textFaint/canvas` 5.07 / 4.59。全部 ≥ 4.5。
- 环段与轨道之间靠明度差区分，不靠描边；段与段之间靠 3px 缺口分隔，不靠白边。

## 5. 环 `MileafShareRing`

### 5.1 语义与分母

**环 = AC/DC 已知分类能量的构成**，与后端 `dc_energy_share` 完全同分母。

> 对 ADR 0004 D2「三段环（AC/DC/未知）」的修订 R1（见 §16）：若环含"未知"，则环上 DC 的视觉占比（占总量）与短注里的 `DC 占已知分类 0%`（占已知）会同时出现在一屏，两个不同分母的同一个百分比会被读成矛盾。因此环只画已知分类，未知单独成列并在短注里以文字声明"不计入构成"。这是本 Spec 相对 ADR 的唯一实质改动，需在确认时一并裁定。

- 段顺序固定：AC → DC，从 12 点方向顺时针。
- 段长 = 值 / (AC + DC)；AC + DC = 0 时不画段，只留轨道与圆心 `—`。
- 值 ≤ 0 的段不画（不画 0 宽细缝）；此时另一段占满整圈。

### 5.2 几何

| 参数 | 值 | token |
| --- | --- | --- |
| 直径 | 104（≥390 宽 116；大字号 120） | `MileafShareRingMetrics.diameter` / `diameterWide` / `diameterLarge` |
| 描边 | 12 | `stroke` |
| 段间缺口 | 3（弧长像素，换算为角度） | `gap` |
| 端点 | `StrokeCap.butt` | — |
| 圆心可用宽 | 直径 − 2×描边 − 8 | — |
| 圆心内容 | 数值（metric-md）+ `%`（micro）+ 分类名（micro） | — |

- 不用圆角端点：两段的圆头会在缺口处互相侵占，视觉上产生"叠色"。缺口 + 直角端点是构成环的标准画法（与 `BatteryArc` 的 round cap 区分开，两者语义不同）。
- 轨道始终绘制（含空态），保证"这是一个环"的结构可读。

### 5.3 圆心

- 主类 = AC / DC 中能量较大者（相等取 AC）。
- 圆心 = `round(主类占比 × 100)` + `%`，下方分类名。
- 已知分类能量为 0 时：圆心 `—`，无分类名、无 `%`。
- 大字号（≥150%）下若圆心内容放不下（实测宽 > 圆心可用宽）：隐藏圆心，**不缩小字号**。占比信息由图例承担，不丢失。

### 5.4 绘制动效

- 首次出现：从 12 点顺时针扫出，500ms `easeOutCubic`，两段连续扫出。
- 数值变化（切换区间/刷新）：220ms `easeOut` 对每段弧长插值。
- reduce motion（`MediaQuery.disableAnimations` 或系统设置）：直接呈现，无扫出、无插值。

## 6. 图例

每行 = 8px 圆点 + 10 间距 + 分类名 + 弹性间距 + 百分比，行高 44（触控目标）。

| 状态 | 视觉 |
| --- | --- |
| Default | 点 + `textMuted` 名称 + `text` 百分比 |
| Pressed | 整行 `accentSoft`（12%）底，圆角 `radius.sm`（10），文字不变，120ms |
| Focus（键盘/读屏） | 行内 2px `focusRing` 描边，圆角 10（与 `StatusChip` 同法，避免被相邻行裁切） |
| Disabled | 不出现（无禁用语义） |

- 百分比 = 该段值 / (AC + DC)，`decimal()` 两位小数去尾零（`100%`、`44.9%`、`0%`）。
- 分母为 0（只有未知能量）时**整组图例不出现**：环上也没有弧，`AC 0% / DC 0%` 会被读成"真的各占 0%"，而实际是"无法计算"。
- 行高 44 是触控要求，不是排版要求：名称与百分比在这一行内垂直居中，留白由行高提供。
- 点击行为见 §9。

## 7. 三列

| 槽位 | 内容 |
| --- | --- |
| 列名 | `AC` / `DC` / `未知` |
| 主数 | 该分类能量，`decimal()`，无单位后缀 |
| 单位 | `kWh`；缺失时为 null |
| 脚注 | 该分类记录时长 `decimal(x) 分钟`；缺失时 `—` |

- 三列等宽，间距 16（`MileafSpace.s16`）；左对齐。
- 数值与单位同一 `Text.rich`，单位以空格分隔；列宽不够时由文本引擎在空格处换到下一行，**不缩放、不 `FittedBox`、不隐藏单位**。
- 缺失（`energy_known_sessions == 0`）：主数 `—`、无单位。不补 0。
- 脚注按 `duration_known_sessions` 独立判定：该字段为 0 才显示 `—`；能量与时长是两个独立覆盖，不互相牵连。
- `未知` 列的显示条件：`unknown_energy_kwh > 0` **或** `classification_known_sessions < sessions`。其余情况整列不出现（两列等分）。
- 数值与单位同一行；列宽不足时单位下移一行（§10.1），行高变化由内容决定，不设固定高度。

## 8. 短注与口径层

**区块内短注（必须保留，就近解释分母）**

```
DC 占已知分类能量 {share}% · 分类已知 {known}/{sessions} 次
```

- 未知存在时插入中间一段：`DC 占已知分类能量 0% · 未知不计入构成 · 分类已知 2/2 次`。
- 已知分类能量为 0：`DC 占已知分类能量 — · 分类已知 2/2 次`。

**迁入页尾 `数据说明`（`_notes()`，[:1603](../../lib/src/charging_page.dart#L1603)）**

1. `构成环只含 AC / DC 已知分类能量；类型未知的能量单列显示，不并入任何一类。`
2. `记录时长按分类累计，不等于等待时间。`
3. `统计校验时间 2026-11-01 22:30:32`（原正文位置删除）

## 9. 交互

- 图例每一行可点：`chargeType = 'ac' | 'dc'` → `recordsOnly = true` → `applyFilters()` → `scrollToTop()`（与 `_locationRow` 同一链路，[:1445–1451](../../lib/src/charging_page.dart#L1445-L1451)）。
- `未知` 列不可点（它不在图例里，且类型未知的记录在现有筛选里叫 `unknown`；若后续需要，可在此列加同样的跳转，本期不做）。
- 三列数值不可点；环不可点。
- 返回后仍保留类型筛选，用户可用现有「清除筛选」退出。
- 不含长按、拖拽、悬浮提示。

## 10. 响应式

### 10.1 宽度

| 宽度 | 环直径 | 图例列宽 | 三列 |
| --- | --- | --- | --- |
| 320–359 | 96 | 内容宽 − 120 | 3 列，列宽 ≈82；单位可能换行 |
| 360–389 | 104 | 内容宽 − 128 | 3 列，列宽 ≈96 |
| 390–599 | 116 | 内容宽 − 140 | 3 列，列宽 ≈103 |
| ≥600 | 116，内容最大 560 居中 | 同 390 段 | 3 列 |

**单位换行**：不做阈值判断，也不在 Flutter 侧用 `TextPainter` 预估——预估值会随字体回退而漂移（测试字体每个字形都是方块）。数值与单位写成同一段 `Text.rich`，中间留一个空格，由文本引擎按真实字体度量换行：放得下就同行，放不下就在空格处换行。

### 10.2 大字号（`MileafLayout.largeText`：`scale(14) ≥ 21`）

```
我的补能方式
以 AC 为主
        ╭────╮
       │  —   │            ← 圆心在放不下时隐藏
        ╰────╯
● AC                100%
● DC                  0%
──────────────────────
AC
40.18 kWh
1,614 分钟
──────────────────────
DC
0 kWh
0 分钟
──────────────────────
未知
—
— 分钟
──────────────────────
DC 占已知分类能量 0% · 分类已知 2/2 次
```

- 环居中、图例在环下方（左对齐），行高 44 不变。
- 三列 → 单列堆叠，块间距 16，块间不加细线（靠间距分组）。
- 结论最多两行，不截断。
- 200%：短注最多三行；不横向滚动。

## 11. 状态

| 状态 | 条件 | 呈现 |
| --- | --- | --- |
| 正常 | `sessions > 0` 且 `energy_known_sessions > 0` 且已知能量 > 0 | 完整结构 |
| 空 | `sessions == 0` | 空轨环 + 圆心 `—` + 结论「还没有充电记录」；无图例、无三列、无短注 |
| 缺失 | `sessions > 0` 且 `energy_known_sessions == 0` | 空轨环 + 圆心 `—` + 结论「分类能量未记录」+ 三列（全 `—`）+ 短注（占比 `—`） |
| 零能量 | `sessions > 0` 且 `energy_known_sessions > 0` 但三类和为 0 | 空轨环 + 圆心 `—` + 结论「还没有分类能量」+ 三列 `0 kWh` + 短注 |
| 加载 | stats 请求中且无缓存 | 区块骨架：结论条 160×14、环 104×104 圆 + 两条图例条（120/96×12）、三列 3×`SkeletonBlock(64, 40)`；`SkeletonBlock` 1.2s 呼吸，reduce motion 静态 |
| 错误 | 请求失败且无缓存 | 区块不渲染（由既有 `InlineBanner` + 重试承担，[:1760–1766](../../lib/src/charging_page.dart#L1760-L1766)）；有缓存时保留上次数据，不置灰 |
| 进行中 | 存在未完成充电 | 不影响本区块（未完成记录本就不进统计） |

## 12. 结论文案规则

设 `ac`、`dc`、`unknown` 为三类能量，`known = ac + dc`，`acShare = ac / known`。

| 条件 | 文案 |
| --- | --- |
| `known == 0 && unknown > 0` | `补能类型未知` |
| `acShare ≥ 0.9` | `以 AC 为主` |
| `acShare ≤ 0.1` | `以 DC 为主` |
| `0.4 ≤ acShare ≤ 0.6` | `AC 与 DC 接近` |
| `0.6 < acShare < 0.9` | `AC 更多，DC 占 {dcShare}%` |
| `0.1 < acShare < 0.4` | `DC 更多，AC 占 {acShare}%` |

- `unknown > 0` 时追加 ` · 类型未知 {decimal(unknown)} kWh`。
- 百分比用 `decimal(share × 100)`（两位去尾零）。
- 不做感叹号、不做颜色判断、不出现"好/坏/划算"。定性只描述结构，不评价。

## 13. 可达性

- 不做"整块一个容器"：图例行是可交互按钮，合并容器会把它们吞进一个不可点的节点。改为逐部件语义，读序即视觉顺序。
- 环 `ExcludeSemantics`（纯图形）：占比已由图例与圆心文本承担，读屏不再重复播报"补能构成：AC 55%…"。
- 图例每行 `button: true` + `label: '查看 AC 充电记录'`（只报去处，占比已在视觉上重复，不再念一遍数字）。
- 每列一个 `Semantics`，标签 `AC 118 kWh，180 分钟`；空白/`—` 原样读出。
- 读序：结论 → 图例 AC → 图例 DC → 列 AC → 列 DC → 列 未知 → 短注。
- 触控目标：图例行 44 高；其余元素不可点。
- 颜色不是唯一编码：环段有分类名 + 百分比；未知有文字列名。
- 200% 不裁切、不横向滚动。

## 14. 组件与 token 增量

### 14.1 新增组件 `lib/src/design/components/share_ring.dart`

```dart
class ShareRingSegment {
  const ShareRingSegment({required this.label, required this.value, required this.color});
  final String label;
  final num value;   // kWh，已知分类
  final Color color; // 由调用方从 colors 取，组件内不硬编码
}

class MileafShareRing extends StatefulWidget {
  const MileafShareRing({
    super.key,
    required this.segments,
    this.centerValue,        // '55'；null → '—'
    this.centerUnit = '%',
    this.centerLabel,        // 'AC' / 'DC'；null → 不显示
    this.size,               // 缺省按宽度与字号取 token
  });
}

class ShareRingLegendRow extends StatelessWidget {
  const ShareRingLegendRow({
    super.key,
    required this.color,
    required this.label,
    required this.share,     // '100%' | '—'
    this.onTap,
    this.semanticsLabel,
  });
}
```

- 组件不读 `ChargingStats`，只吃已算好的值；口径判定留在 `ChargingMethodReading`。
- 组件是 `StatefulWidget`：500ms 扫出与 220ms 数值过渡需要两个 `AnimationController`。
- 组件内不出现裸色/裸字号/裸圆角；全部走 `context.colors` / `context.type` / `MileafSpace` / `MileafRadius`。

### 14.2 token 增量（`tokens.dart`，`MileafChartMetrics` 之后新增）

```dart
abstract final class MileafShareRingMetrics {
  static const diameter = 104.0;
  static const diameterWide = 116.0;
  static const diameterNarrow = 96.0;
  static const diameterLargeText = 120.0;
  static const stroke = 12.0;
  static const gap = 3.0;            // 弧长像素
  static const centerPad = 8.0;
  static const legendRow = 44.0;
  static const dot = 8.0;
}
```

### 14.3 导出

`lib/src/design/components/components.dart` 追加 `export 'share_ring.dart';`。

## 15. 改动清单与理由

| 文件 | 改动 | 为什么 |
| --- | --- | --- |
| `charging_page.dart` `_composition()` | 重写为 §2 结构；新增 `_conclusion()`、`_categoryColumns()`、`_note()` 私有方法 | 六行等权文字没有主次；三列与图例各承担一种读法 |
| `charging_page.dart` build | 删除 `统计校验时间` 独立段（[:1788–1800](../../lib/src/charging_page.dart#L1788-L1800)） | ISO 时间戳打断阅读，属口径层 |
| `charging_page.dart` `_notes()` | 增两条口径 | 口径成组出现，避免散落正文 |
| `share_ring.dart` | 新增组件 | 环是可复用图表原语，不应写在页面里；也避免与 `BatteryArc` 语义混用 |
| `tokens.dart` | 新增 `MileafShareRingMetrics` | 几何值必须可查、可测、可改 |
| `test/charging_test.dart` | 空态断言改为「空环 + 结论，不画全零」 | 旧断言绑定的是被删除的文案 |
| `test/charging_method_test.dart` / `test/charging_method_section_test.dart` | 新建：读法边界与页面级用例（阈值、跳转、口径迁移、200%、320/360/390/600） | 逻辑与页面各有 seam |
| `test/share_ring_test.dart` | 新建：弧长占比、空环、扫出、图例状态 | 环是可复用原语，独立验收 |
| `test/a_charging_method_render_test.dart` | 新建：12 张区块渲染 | 图册必须覆盖新结构 |

## 16. 已裁定（Spec 门，2026-11-01）

1. **R1 环的分母 —— 通过**。环只画 AC/DC 已知分类（与 `dc_energy_share` 同分母），未知单列并在短注声明"不计入构成"。ADR 0004 D2 的三段环由本节取代。
2. **结论措辞 —— 通过**。采用 `以 AC 为主` / `AC 更多，DC 占 45%` / `AC 与 DC 接近`。
3. **空态 —— 通过**。`sessions == 0` 时只留空环 + 一句结论，不显示三列。

## 17. 验收断言

1. 有 AC/DC 数据时渲染 2 段；AC 段弧长占比与 `ac/(ac+dc)` 误差 ≤ 0.5%。
2. 四组 fixture（100/0、70/30、50/50、0/100）分别输出 §12 对应文案，且无感叹号、无"好/坏"字样。
3. `unknown_energy == 0 && classification_known_sessions == sessions` 时页面不出现 `未知` 列。
4. `unknown_energy > 0` 时出现 `未知` 列与 `未知不计入构成`。
5. 空区间：环只有轨道、圆心 `—`、结论「还没有充电记录」，且不出现 `0.00 kWh`。
6. 点击 DC 图例行 → 进入记录列表，最后一次 `/charging-sessions` 请求含 `charging_type=dc`。
7. 200%：`tester.takeException()` 为 null；三列单列；圆心在放不下时隐藏而非缩小。
8. 深浅两套下 `结论` 与 `短注` 颜色取自 token；页面文件不出现 `Color(0x`、裸 `fontSize`、裸 `BorderRadius`。
9. `统计校验时间` 只出现在 `数据说明` 内，正文不出现。
10. 360×800 × 浅/深 × 100/200% × normal/empty/missing 六组渲染无溢出。

## 18. 不做

- 不做按类次数、按类费用、按类地点（接口无字段）。
- 不做"能量/时长"切换（ADR D3）。
- 不做逐日构成堆叠图（ADR 备选 C 已否决）。
- 不改 `MileafCompositionBar` 在概览/补能专题的用法。
- 不新增请求、不改 `MileafServer`。
