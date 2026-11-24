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

## 5 第二次修正（2026-11-19：字号不是病因，行宽才是）

用户第二次截图（「上月同期 10月1日–19日 0 km，多 92 km」，红框 ① 仍折成两行，红框 ② 圈住读数头尾部的 ‹ › 步进）。复核结论：**第一版只改了字号，行宽算式算错了**。

【代码事实】

- 第三行可用宽 = 屏宽 − `MileafLayout.pageInset`×2 − 卡内边距×2 − `2 × MileafChartGrammar.stepHit`（88）。两处分档常被漏算：`pageInset` 在 `MileafBreakpoints.wide`（390）以上取 24、以下取 20；概览焦点卡走 §6 退让阶梯第 2 步的 `MileafSpace.s12`（12），专题卡才是默认 16。第 7 行的算式只减了一侧页边距与一侧卡内边距（439 − 24 − 40 − 88 = 287），真实值：**375 屏焦点卡 223**（专题卡 215）、393 屏 233、430 屏 270；卡内宽（不扣步进）分别是 **311 / 303 / 321 / 358**。
- 13pt 下这句的 PingFang SC 实宽 **248**（`10月1日–19日` 稳定复现），电耗那句 **302**。也就是说 13pt 只在 ≥408pt 的屏上成立，375/393 屏必然折行——上一版测试的 harness 宽度（375 − 88 = 287）比真机宽 72，所以测试绿、真机红。
- 折行点与用户截图一致：215 宽下断在「多」之后，「92 km」整段掉到第二行。

【已落地改动】

- `MileafChartReadout`（`lib/src/design/components/charts.dart`）：步进只在第 1–2 行（日期 + 数值）右侧占位，第三行移出步进所在的 `Row`，改由 `MileafChartGrammar.contextRowKey` 标记的 `SizedBox` 承载并跨满整卡内宽；第三行高度预留改按整卡宽测行数（仍按全序列最长句预留，切换选点不跳高度）。
- 第三行可见文字放在 `ExcludeSemantics` 里——朗读仍只由 live region 的 `sentence` 发一次，与上一版 `excludeSemantics: true` 等价。
- 紧凑读数行（`compact`）仍只有「日期 + 数值 + 行尾下钻」一行，第三行只在完整读数头里渲染（与上一版一致，代码用 `!compact` 守住）；日期行、数值行、`readoutBuilder` 版式、步进位置与命中区（44）均未动；`MileafChartReadout` 的三处调用方（概览、统计区间、停放）自动同享。
- 新增公开符号：`MileafChartGrammar.contextRowKey`（测试用的行盒接缝，与 `readoutLiveKey` / `identityFadeKey` 同类；AP05 §2.3 的公开符号清单由那个切片维护，这里只登记）。

【验证】

- `test/chart_context_row_test.dart` 重写：按真实几何换算出卡内宽（375 焦点卡 311、375 专题卡 303、393 焦点卡 321、430 焦点卡 358）断言一句一行，并断言第三行行盒宽度等于整卡宽、左缘与日期/数值同线（旧布局这里只有卡宽 − 88，是这次的真回归点）。字宽用 Inter 实字 + Ahem 方块：CJK 与真字等宽（各 1em）、拉丁略宽，属保守估计（真字渲染的解释性验证见下条）。
- 真字渲染：`build/context-row-renders/context-row-393.png`（393 屏、PingFang SC 实宽、里程 92 km / 参照 0 km）确认「上月同期 10月1日–19日 0 km，多 92 km」一行，`‹ ›` 与句子不重叠。渲染脚本为临时文件，跑完即删（生成物入 `build/`，不入库）。
- `tool/flutterw analyze --no-pub lib test`：仅既有 1 条 info（`test/apple_polish_ap10_test.dart:342`）。
- 全量 `tool/flutterw test --no-pub`：**1356 通过 / 57 跳过 / 0 失败**（同轮工作区另有在途切片的 `chip_row.dart`、`statistics_conditions_page.dart` 与其新用例，未被本次改动卷入）。
- `test/overview_reading_test.dart` 两条第三行断言改为「图表框内可见句 + live region 朗读句包含参照与差值」，并补 `ensureSemantics`（第三行不再位于 live 节点内，但仍由朗读句一次说全）。

【未确认建议】

- 红框 ② 的读法是把 ‹ › 理解为「只该占它所在那一行」：步进仍在原位（第 1–2 行右端）、命中区仍 44，只是不再从第三行抠 88。若用户想的是「步进移进日期行内」或「干脆删掉」，属另一次布局裁定，当前没做。
- 375 屏焦点卡的电耗句（PingFang SC 实宽 302）对卡内宽 311 余 **9pt**；换一款更宽的 CJK 字（如 Hiragino Sans GB 实测 314）就会折行，且 320 屏（可用 256）必然折行。若真机仍折行，两条路都要用户裁定：把差值里重复的单位省掉（「多 92 km」→「多 92」）属文案改动，或再收卡内边距属间距改动。当前不动。
- 200% 大字下第三行仍自然折行（预留机制兜底），未按「强制一行」处理。