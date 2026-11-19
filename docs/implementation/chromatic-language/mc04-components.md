# MC04 记录：组件层 hue 参数

## 做了什么

| 组件 | 文件 | 新增 | 缺省行为 |
| --- | --- | --- | --- |
| SectionHeader | components/section.dart | MileafHue? hue、MileafIconName? icon | icon 为 null 时树结构与改造前一致；有 icon 时 16 图标取 hue.strong，标题仍中性 |
| MetricBlock | components/metric.dart | MileafHue? hue | hue 为 null 时不传 MileafNumber.color（走原默认） |
| MileafModuleCard | components/module.dart | MileafHue? hue | hue 为 null 时 color: colors.surface |
| MileafGroupRow | components/module.dart | MileafHue? hue | 行首图标仍 textSecondary（禁用态 textFaint） |
| TimeSeriesChart | components/charts.dart | MileafHue? hue | painter 与图例仍取 accent（hero 内 accentHero） |

## 三处刻意的取舍

1. **色相不做成 MileafColors 字段**。做成 ThemeExtension 字段会把 copyWith / lerp / 构造参数各撑开 6–30 个位置；而色相解析只需要 isDark 与既有前景，做成 extension on MileafHue 更窄。
2. **MetricBlock 只染读数，不染标签**。三列网格里彩色标签会与相邻格互抢注意力；彩色落在数字上（strong，浅 5.90:1）既够亮又守住正文门槛。
3. **TimeSeriesChart 一图一色相，不给 ChartSeries 加色**。既有图例规则明写「多测量（净/毛电耗、AC/DC）的线同色」——单色是刻意的（多测量只列名字不画色块）。给每条线一个色相会同时推翻图例语义与其测试，属于另一轮设计决定。

## 卡片层次：为什么用 8% tint 而不是阴影

改造前 canvas ↔ surface 只有 1.09:1，hero 与普通卡同色，静态卡又没有阴影——卡片之间没有任何台阶。hue.tint（8%）让焦点卡/章节卡带上一层可辨识的数据身份色，同时：

- 正文压 tint 合成底实测 ≥4.5:1（chromatic_contrast_guard_test.dart 的 CL06 组）；
- 8% 远低于「看出来的彩色」阈值 C>0.04，因此不违反 CL06 的高彩度预算。

## 验证

- ./tool/flutterw analyze --no-pub lib test：无新增诊断（lib test 口径，排除 creator/）。
- test/design_components_test.dart（175 用例）、test/design_tokens_test.dart、两个新守卫测试全绿。