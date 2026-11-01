# 充电页「我的补能方式」构成环：实施 Ticket 计划

- 日期：2026-11-01
- 状态：proposed（待用户确认）
- 依据：[Spec](charging-method-share-ring.md)（accepted）、[ADR 0004](../adr/0004-charging-method-visual.md)（accepted）
- 本地 ID：`CM01–CM06`。确认后按 `docs/agents/issue-tracker.md` 映射到 GitHub；**本轮不直接创建或关闭 issue**。
- 实施边界：不新增 API、不改数据口径、不改 `MileafServer/`、`teslamate/`、不做车辆控制；真机与真实站点仍是外部 gate。

## 全局完成定义（DoD）

每张票都必须满足：

- `tool/flutterw analyze --no-pub` 通过。
- `tool/flutterw test --no-pub` 通过；新增用例走同一 seam（App + 可控 HTTP）。
- 页面与组件不出现裸 `Color(0x...)`、裸 `fontSize`、裸 `BorderRadius`；只消费 `lib/src/design/` 的 token/组件。
- 360×800 × 浅/深 × 100/200% 无横向溢出；结论、主数、单位、图例可见。
- 正常 / 空 / 缺失 / 零能量 / 加载 五种状态有实际渲染，不只是文案占位。

## 依赖图

```text
CM01 ── CM02 ──┬── CM03
               ├── CM04
               └── CM05
CM02 + CM03 + CM04 + CM05 ── CM06
```

---

## CM01 · 图表基座：构成环、图例与几何 token

**目标**：环是可复用图表原语，几何值可查可测；页面只负责算数。

**改动**
- `lib/src/design/tokens.dart`：新增 `MileafShareRingMetrics`（直径 104/116/96/120、描边 12、缺口 3、图例行高 44、圆点 8、`unitWrapWidth` 88），位置在 `MileafChartMetrics` 之后。
- 新增 `lib/src/design/components/share_ring.dart`：
  - `ShareRingSegment {label, value, color}`（颜色由调用方给，组件不硬编码）。
  - `MileafShareRing`：轨道 + 顺时针分段 + 缺口 + 圆心（值 / `%` / 分类名），`excludeSemantics`。
  - `ShareRingLegendRow`：圆点 + 名称 + 百分比，行高 44，可点，含 pressed/focus 态。
  - 首绘 500ms 扫出、数值变化 220ms 插值、reduce motion 直出（Spec §5.4）。
- `lib/src/design/components/components.dart`：追加 `export 'share_ring.dart';`。

**验收**
- `MileafShareRing` 单测（golden 或 painter 探针）：AC 70 / DC 30 → AC 段弧长占比 70%±0.5%；`value ≤ 0` 的段不画；和为 0 时只有轨道。
- 圆心 fit-check：给一个 6 位数与 200% 字号，圆心隐藏而不是缩小（`takeException()` 为 null）。
- reduce motion 下首帧即完整弧，无中间帧。
- `ShareRingLegendRow`：Default / Pressed（accentSoft 20%）/ Focus（2px accentFocus）；`onTap` 为空时不显示按压态。
- 组件内无裸色/裸字号/裸圆角；`test/design_components_test.dart` 增加环形状语义断言。

**不做**：不接入页面；不改 `MileafCompositionBar` 与 `BatteryArc`。

---

## CM02 · 读法逻辑与页面装配

**目标**：把六行文字换成「结论 → 环 + 图例 → 三列 → 短注」，口径判定从 widget 里拆出来可单测。

**改动**
- 新增 `lib/src/charging_method.dart`（纯逻辑，无 Flutter 依赖）：
  - `ChargingMethodReading.from(ChargingMetrics totals)` → `{ acShare, dcShare, dominant, centerValue, centerLabel, conclusion, categories, note, showUnknown, state }`。
  - 状态枚举：`empty`（sessions == 0）/ `missing`（energyKnownSessions == 0）/ `zero`（三类和为 0）/ `normal`。
  - 结论阈值与文案严格按 Spec §12；百分比用现有 `decimal()`。
- `lib/src/charging_page.dart`：
  - `_composition()` 重写：`SectionHeader` → 结论 → 环 + 图例（右）→ 1px 细线 → 三列 → 短注；纵向间距 8/16/20/16/12（Spec §2.1）。
  - `_CategoryColumn` 私有组件（列名 label 10 textMuted、主数 metricMd、单位 micro、脚注 micro textFaint）。
  - 环 104 / 图例行高 44；三列等宽间距 16。
  - 加载态：结论条 + 环 + 三列骨架（`SkeletonBlock`）。
- 删除旧的 legend 文本行、`DC占已知分类…` 段落、分类时长句、`分类已知` 句（[:1132–1162](../../lib/src/charging_page.dart#L1132-L1162)）。

**验收**
- 四组 fixture（100/0、70/30、50/50、0/100）输出 Spec §12 对应文案，无感叹号、无"好/坏/划算"。
- `未知 = 0 且 classification_known_sessions == sessions` 时不出现"未知"列；`unknown > 0` 时出现且短注含"未知不计入构成"。
- 空区间：只有空轨环 + 圆心 `—` + 「还没有充电记录」，不出现 `0.00 kWh`、不出现三列。
- 缺失（`energy_known_sessions == 0`）：三列全 `—`、短注占比 `—`、结论「分类能量未记录」。
- 卡片零新增：无底色、无阴影、无 `Card`。
- `charging_method_test.dart` 覆盖 8 组边界（含除零）。

**不做**：不动 hero / 三读数 / stem / 地点账目 / 记录列表。

---

## CM03 · 口径迁移到「数据说明」

**目标**：正文只说结论，口径集中成组。

**改动**
- `lib/src/charging_page.dart` build：删除 `统计校验时间` 独立段（[:1788–1800](../../lib/src/charging_page.dart#L1788-L1800)）。
- `_notes()`（[:1603](../../lib/src/charging_page.dart#L1603)）新增：
  - `构成环只含 AC / DC 已知分类能量；类型未知的能量单列显示，不并入任何一类。`
  - `记录时长按分类累计，不等于等待时间。`
  - `统计校验时间 …`（仅在有值时）

**验收**
- 正文（首屏至「最近的充电」）不再出现"统计校验时间"字样；`数据说明` 展开后存在。
- `charging_test.dart` 中对"统计校验时间"的断言改到展开后。
- 短注仍保留 `DC 占已知分类能量 X%` 与 `分类已知 N/M 次`。

**不做**：不合并"地点校验时间"（位置不变）。

---

## CM04 · 图例跳转到已筛选的记录列表

**目标**：`DC 0 kWh` 这类读数有地方可核对。

**改动**
- `ShareRingLegendRow.onTap` → `chargeType = 'ac' | 'dc'` → `recordsOnly = true` → `applyFilters()` → `scrollToTop()`（与 `_locationRow` 同链路，[:1445–1451](../../lib/src/charging_page.dart#L1445-L1451)）。
- 语义标签：`查看 AC 充电记录` / `查看 DC 充电记录`。

**验收**
- 点 DC 图例行：进入记录列表，最后一次 `/charging-sessions` 请求含 `charging_type=dc`；筛选提示条显示「类型：DC」。
- 点 AC 同理；「清除筛选」可回到全部。
- 触控高度 ≥44；读屏报"按钮"。
- 返回账本后本区块不受影响。

**不做**：不给"未知"列加跳转（本期）。

---

## CM05 · 响应式与 200%

**目标**：320 到 ≥600、100% 到 200% 都不塌、不裁、不缩字。

**改动**
- 环直径：320–359 → 96；360–389 → 104；390–599 → 116；≥600 → 116（内容 560 居中）。
- 单位换行：列宽 < `unitWrapWidth`(88) 时单位另起一行，`LayoutBuilder` + `TextPainter` 实测。
- 大字号：环居中 + 图例下移，三列 → 单列（块间距 16），圆心放不下则隐藏（Spec §10.2）。

**验收**
- 320/360/390/600 四档 × 100%：无溢出；单位在窄档下移且不缩小。
- 200%：三列单列；圆心按 fit-check 结果隐藏或完整；短注最多三行；`takeException()` 为 null。
- 图例行高 44 在 200% 下仍 ≥44。

**不做**：不做平板多列布局。

---

## CM06 · 测试与图册

**目标**：新结构在自动化里可见、可回归。

**改动**
- `test/charging_test.dart`：改写 [:544–556](../../test/charging_test.dart#L544-L556) 的文本断言；新增阈值矩阵、未知显示条件、图例跳转、200% 用例。
- 新增 `test/charging_method_test.dart`：纯逻辑边界（除零、四舍五入、dominated by unknown、`decimal` 尾零）。
- `test/design_components_test.dart`：环与图例的状态矩阵。
- `test/a_gallery_render_test.dart`：新增本区块滚动位渲染，360×800 × 浅/深 × 100/200% × normal/empty/missing（12 张）；更新 `docs/implementation/a-renders/` 索引。

**验收**
- `tool/flutterw analyze --no-pub`、`tool/flutterw test --no-pub` 全绿。
- 12 张新图渲染成功且无溢出；图册 README 注明"合成 fixture，不代表真机/真实站点"。
- 覆盖率上不强制阈值，但 `charging_method.dart` 的分支需全覆盖。

**不做**：不以浏览器原型图替代 Flutter 渲染证据。

---

## 交付顺序

CM01 → CM02 →（CM03、CM04、CM05 可并行）→ CM06。每张票独立本地提交；不推送、不关闭外部待验票。
