# 读数头第三行（同期对比句）单行实施记录

2026-11-18 在 `main` 工作区完成（未提交、未推送）。用户指出「概览」里程读数头的同期对比句「上月同期 10月1日–18日 0 km，多 92 km」在手机卡宽下折成两行（红框），明确裁定：**文字小一号，一行显示**。条款依据 [Apple 焕新规格](../specs/apple-polish.md)「完整读数头」表第 3 行（本次随裁定同步把该行样式从 `subheadline` 改为 `footnote`）；未新增颜色、字号、圆角或动效 token。

## 1 问题

AP05 把参照与差值合并成一句放在读数头第三行，样式沿用日期行的 `subheadline` 15。长参照名（含真实区间「10月1日–18日」）加上带单位的参照值与差值后，在 ≈439pt 屏（可用行宽 ≈287：439 − 24 页边距 − 40 卡内边距 − 88 步进命中）下排不下，折成两行，且折行点落在「0 / km」中间，把单位从数值上撕开。

## 2 做法

- `TimeSeriesChart` 读数头第三行的 `contextStyle` 不再借用日期行的 `subheadline`，改用 `footnote` 13/18，颜色角色不变（`textSecondary`，hero 上 `heroMuted`）。
- 两处直接构造 `MileafChartReadout` 的专题页（统计区间、停放）同步改为 `footnote`，保持第三行同角色同档字号。
- 日期行、数值行、紧凑读数行、`readoutBuilder` 版式均不动；朗读句（live region）不受影响。
- 大字（200%）下长句仍自然折行，读数头最小高度机制照旧兜底。

## 3 验证

- 新增 `test/chart_context_row_test.dart`：以 Inter 实字宽 + Ahem CJK（与 AP14 同法，单独成文件以免字体重载干扰 AP05 像素探针）断言截图原句与更长的电耗对比句在等价卡宽（harness 宽 375 = 287 + 88 步进）内一行放下。
- `test/apple_polish_ap05_test.dart`「根页数值用 metricMd…」的第三行字号断言由 `subheadlineSize` 改为 `footnoteSize`（用户裁定的规格变化，非回归）。
- 「小一号」的档位解释：`subheadline` 15 与 `footnote` 13 之间虽有 `label` 14，但 R22 里 `label` 是控件档（分段、次按钮、小胶囊，500 字重），不是阅读文字档；对一句限定语，下一个阅读档就是 `footnote`，故取 13。
- `tool/flutterw analyze` 无本切片新增诊断（其余 8 条属工作区其他在途切片）。
- 2026-11-18 全量 `tool/flutterw test`（含工作区另一在途充电切片）：+1063 / ~49 跳过 / 5 失败。失败中 1 例是本切片一度放在 `apple_polish_ap05_test.dart` 的重复用例（Ahem 方宽下必然折行，已移除，由 `chart_context_row_test.dart` 以实字宽承载）；其余 4 例（`charging_method_section`、`collage_charging`、`charging_rows_render`、`overview_statistics_reading`）断言的是文案条目数量与夹具路径，与本切片的纯样式改动无关，属另一在途切片的红灯。本切片直接相关文件单跑全绿（`apple_polish_ap05` 32 通过、`chart_context_row` 2 通过）。

## 4 边界

仅本地实施（提交 `8a6d012`），未推送；真机字体（PingFang SC 实宽）、读屏与性能仍归 #16/#17。