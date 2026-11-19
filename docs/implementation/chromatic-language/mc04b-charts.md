# MC04b 记录：图形组件 hue 参数

## 做了什么

给五个图形组件各加可选 `MileafHue? hue`（构造参数 + final 字段 + doc），只改**数据图形**的取色，次级元素（轨道、刻度、描边、文字）一律不动。照 `TimeSeriesChart.hue` 的模式：`hue?.solid(colors) ?? 原值`。

| 组件 | 文件 | 图形取色 | 次级元素（不变） |
| --- | --- | --- | --- |
| BatteryArc | battery_arc.dart | 弧前景 `hue?.solid ?? (onHero ? accentHero : accent)` | 轨道仍 `accent/accentHero × trackOpacity`，环内读数与标签字色不变 |
| MileafShareRing | share_ring.dart | 段 0 `hue.solid`、段 1 `hue.strong`、段 ≥2 仍用 `ShareRingSegment.color`（未知=中性） | `track: colors.line`、圆心与图例文字不变 |
| MileafCategoryBars | category_bars.dart | 柱 0 `hue?.solid ?? seriesPrimary`、柱 1 `hue?.strong ?? seriesSecondary`、柱 2 仍 `seriesNeutral` | 轨道 `colors.line`、标签/数值文字不变 |
| MileafCompositionBar | composition_bar.dart | 段 0 `hue?.solid ?? seriesPrimary`、段 1 `hue?.strong ?? seriesSecondary`、段 2 仍 `seriesNeutral` | `emptyMessage` 的 textFaint、高度 8、圆角不变 |
| SocIntervalBar | soc_interval.dart | 区间带 `hue?.solid ?? accent` | 轨道 `lineStrong`、填充不透明度（现状 100%）、端点标签字色不变 |

## 两处取舍

1. **category_bars 的第二柱取 `strong`，不是也取 `solid`**。它与 `MileafCompositionBar` 是一套三档映射（主/次/中性，appearance-v2 §AV06），若两柱同色就丢掉 AC/DC 的图形分辨；CL02 的两档用法正好对上。若收口要求严格按「柱色取 solid」字面，把 `_bar` 的 `1 =>` 分支改成 `hue?.solid(colors) ?? colors.seriesSecondary` 即可（一行）。
2. **未知段交回调用方**。CL08 规定未知/未记录永不用语义色相，所以 share_ring 的第 3 段与以两类 bar 的「未知」都保留原中性色，组件不替调用方决定「未知该长什么样」。

## 测试（test/chromatic_chart_hue_test.dart，16 用例全绿）

每个组件两组：hue 为 null（取 `colors.accent` / series 三档 / 调用方段色）与 hue 为某色相（取 `hue.solid(colors)`）；share_ring 另断言段 1 = `hue.strong(colors)`。另外三条钉「像素等价」：

- BatteryArc：null 时弧 = `accent`、轨道 = `accent × trackOpacity`；hue 时轨道逐值不变；
- MileafCategoryBars：`hue: MileafHue.azure` 与不传 hue 的取色逐值相同（浅色 azure.solid = accent、azure.strong = accentStrong = seriesSecondary）；
- MileafShareRing：null 时 painter 的 colors 逐段等于调用方传的 `segment.color`。

深色各一组，验证 `solid` 落深色档、share_ring 深色两档合并（CL02.1）。

## 验证

- `./tool/flutterw analyze --no-pub lib test`：无新增诊断（仅 test/apple_polish_ap10_test.dart:342 既有 info）。
- `./tool/flutterw test --no-pub test/chromatic_chart_hue_test.dart`：16 通过。
- `./tool/flutterw test --no-pub test/design_components_test.dart test/share_ring_test.dart`：71 通过，无回归。
- `./tool/flutterw test --no-pub test/apple_polish_copy_guard_test.dart`：2 通过（本次只加 doc 注释，不新增中文文案）。
- `dart format` 已过；未 git add / commit。

## 遗留

- 页面接线未做（MC06–MC09 各自消费 `hue`）；本切片只保证「传了就对、不传像素等价」。
- 真机字体/读屏与性能仍在 #16/#17；本切片不改几何、透明度常量、动效与字号。
