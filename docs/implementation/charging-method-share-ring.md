# 充电「我的补能方式」构成环：实施记录

- 日期：2026-11-01
- 依据：[ADR 0004](../adr/0004-charging-method-visual.md)、[设计规格](../specs/charging-method-share-ring.md)、[Ticket CM01–CM06](../specs/charging-method-share-ring-tickets.md)
- 结论：CM01–CM06 完成，`tool/flutterw analyze --no-pub` 与 `tool/flutterw test --no-pub` 全绿（390 通过 / 23 跳过——跳过的都是 opt-in 渲染入口）。

## 改了什么

| 文件 | 改动 |
| --- | --- |
| `lib/src/design/tokens.dart` | 新增 `MileafShareRingMetrics`：直径 96/104/116/120、描边 12、缺口 3、图例行高 44、圆点 8、`unitWrapWidth` 88 |
| `lib/src/design/components/share_ring.dart`（新） | `ShareRingSegment`、`MileafShareRing`（轨道 + 分段 + 圆心 + 500ms 扫出）、`ShareRingLegendRow`（44 高、可点、pressed/focus）、`shareRingArcs`（弧长数学，供测试直接断言） |
| `lib/src/design/components/components.dart` | 导出 `share_ring.dart` |
| `lib/src/charging_method.dart`（新） | `ChargingMethodReading`：状态机（empty/missing/zero/normal）、AC/DC 占比、结论句阈值、三列数据、短注；纯 Dart，无 widget |
| `lib/src/charging_page.dart` | `_composition()` 重写为「结论 → 环 + 图例 → 细线 → 三列 → 短注」；新增 `_supplyRing` / `_categoryColumns` / `_categoryColumn` / `_compositionSkeleton` / `openType`；`统计校验时间` 从正文移入 `_notes()`；`_recentSection()` 空列表补页边距 |
| `test/charging_method_test.dart`（新） | 17 条：阈值、除零、尾零、未知从句、三列显示条件、四种状态、字段残留防御 |
| `test/share_ring_test.dart`（新） | 10 条：弧长占比、0 段、空环、扫出进度、语义、200% 圆心隐藏、reduce motion、图例状态 |
| `test/charging_method_section_test.dart`（新） | 9 条：结构顺序、图例跳转（`charging_type=dc`）、口径迁移、200% 单列、320 单位下移、360 同行、390 环 116、缺失态 |
| `test/a_charging_method_render_test.dart`（新） | 12 张渲染 + 状态断言 |
| `test/charging_test.dart` | 空态断言改为「空环 + 结论，不画全零」 |
| `docs/` | ADR 0004、Spec、Ticket、`mobile-v1.md` 增量、渲染索引与图册 |

## 与原计划的三处偏差

1. **环只画 AC/DC**（Spec R1，用户已确认）：三段同环会让一屏出现两个不同分母的 DC 百分比。未知改为第三列 + 短注声明。
2. **圆心取整**（`55` 而不是 `55.14`）：`55.14 %` 在 104px 环里放不下，会出现 "55.14 / % / AC" 三行堆叠（第一版渲染已经暴露）。取整后 100% 与 200% 都能放下，精确值留在图例。已按 Spec §5.3 的 `round` 实现。
3. **缺失态防御**：`energy_known_sessions == 0` 时即使 DTO 里残留分类能量也不画进环，否则环有弧、三列却是 `—`。

## 设计层面的取舍（落地后确认）

- 图例百分比右对齐成一列，与左上的环形成"形状 + 数字列"的读序；三列绝对量在细线之下，避免与图例的百分比互相抢读。
- 结论句用 13px 正文字色、不加粗，符合 Spec §1「结论先行」但不喧宾夺主；定性只描述结构，不评价好坏。
- 空态保留空轨环而不是整块消失：页面高度稳定，用户能看出"这里本该有构成"，但没有任何假数据。

## 双轴代码审查后的修正

Standards 轴 6 条硬违规、Spec 轴 10 条（含重复报告）已全部处理，其中 3 条是真 bug：

1. **页面自己算颜色**：`colors.accent.withValues(alpha: .5)` → `colors.seriesPrimary` / `seriesSecondary`（`semantic.dart` 已有语义 token，`composition_bar.dart` 就是这么用的）。
2. **圆心可用宽算错**：`直径 − 2×描边 − 2×8` 变成 `− 8`；修正后 200% 下圆心不再提前消失（现渲染为 `55 % AC`）。
3. **扫出是匀速**：`_sweep.value` 直接换算角度，缺 `easeOutCubic`；已补 `Curves.easeOutCubic.transform`。
4. **分母为空仍印 `AC 0% / DC 0%`**：只有未知能量时改为整组图例不出现——环上也没有弧，`0%` 会被读成"真的各占 0%"。
5. **环不该有语义标签**：改为 `ExcludeSemantics`（纯图形），占比由图例与三列承担，读屏不再重复。
6. **单位换行用固定阈值**：先改成 `TextPainter` 预估，发现测试字体每个字形都是方块、预估值随字体漂移，最终改为**同一段 `Text.rich` 由文本引擎在空格处换行**——不缩放、不隐藏、不依赖度量。
7. **`_same` 重复**：`_sameFractions` 提为文件级，painter 复用。
8. **分层泄漏**：`decimal` 从 `currency.dart` 移到纯文件 `number_format.dart`，`currency.dart` 保留 `export`；`charging_method.dart` 不再依赖带 Flutter 的文件。
9. **图例按压/焦点口径漂移**：统一到 `accentSoft` 与行内 2px `focusRing`（与 `StatusChip` 同法），Spec §6 同步。
10. **文档互斥**：`visual-system-a.md` §9.5 与 §13.2 已改为指向构成环；新 Spec §14.1 的组件签名改为 `StatefulWidget`（有动效）。

未采纳的两条判断项：「整块一个语义容器」（图例是可点按钮，合并会吞掉可点节点，已在 Spec §13 写明理由）、`ShareRingLegendRow.onTap` 可空（组件 API 保留无交互形态，测试覆盖两种）。

## 已知问题（不在本票范围）

- **320 宽**下「每日补能」`TimeSeriesChart` 图头 Row 横向溢出 12px（`Row ← Column ← TimeSeriesChart ← StemChart`）。既有问题，本次未修，已在 `test/charging_method_section_test.dart` 的 320 用例里显式注释并清空该异常；本区块自身在 320 下不溢出。
- 360×800 的全量渲染矩阵（四主 Tab + 两类详情 + 五专题）未整体重跑，只重跑了本区块 12 张；改动未触及其它页面。

## 证据

- 图册：[`docs/implementation/a-renders/charging-method/`](a-renders/charging-method/README.md)（12 张）。
- 命令：`tool/flutterw analyze --no-pub`、`tool/flutterw test --no-pub`。
- 真机、真实站点、性能、双端隔离构建仍是独立外部 gate，未因此次改动关闭。
