# 色彩与图标秩序实施票据（MC00–MC12）

- 依据：[配色与图标秩序规格](./chromatic-language.md)（CL01–CL48）、[ADR 0016](../adr/0016-chromatic-language.md)。
- 本文件同时是**多 Agent / 多会话分包说明**：每票给 write scopes（互不重叠）、前置、动作（挂条款号）、测试、交接文件，以及可直接粘进新会话的提示词（§4）。
- 波次：W0 基线 → W1 三个可并行币 → W2 组件层 → W3 五个可并行页面 → W4 归一 → W5 收口。

---

## 1. 任务图

| ID | 标题 | 前置 | 波次 / 并行组 | 建议模型档 | write scopes |
| --- | --- | --- | --- | --- | --- |
| MC00 | 基线登记与文档 | — | W0 | 标准 | `docs/adr/0016-*`、`docs/specs/chromatic-language*.md`、`AGENTS.md` |
| MC01 | 语义色相 token 与解析出口 | MC00 | W1-A | 强 | `lib/src/design/tokens.dart`、`lib/src/design/semantic.dart`、`test/chromatic_hue_token_test.dart` |
| MC02 | 六色相对比度守卫 | MC01 | W1-A（同 holder，串行于 MC01） | 强 | `test/chromatic_contrast_guard_test.dart` |
| MC03 | 图标家族扩充 4 字形 | MC00 | W1-B | 强 | `lib/src/design/icons.dart`、`lib/src/design/components/icons.dart`、`test/icon_family_test.dart` |
| MC04 | 组件层 hue 参数与图表取色 | MC01 | W2 | 强 | `lib/src/design/components/{metric,section,module,charts}.dart` |
| MC05 | 按钮图标映射表与浮层玻璃 | MC00 | W2 | 标准+ | `lib/src/design/components/{button,pull_down,icon_button,chip}.dart`、`lib/src/map/map_panel.dart` |
| MC06 | 概览页接线 | MC01–MC05 | W3-A | 强 | `lib/src/overview_page.dart`、`test/a_overview_test.dart` 等本页测试 |
| MC07 | 行程页 + 行程详情接线 | MC01–MC05 | W3-B | 强 | `lib/src/drives_page.dart`、`lib/src/drive_detail_page.dart` + 本页测试 |
| MC08 | 充电页 + 充电详情接线 | MC01–MC05 | W3-C | 强 | `lib/src/charging_page.dart`、`lib/src/charging_detail.dart`、`lib/src/charging_cost.dart` + 本页测试 |
| MC09 | 统计根 + 五个专题页接线 | MC01–MC05 | W3-D | 强 | `lib/src/statistics*.dart`（6 文件）+ 本页测试 |
| MC10 | 工作区 / 设置 / 连接 / 地图接线 | MC01–MC05 | W3-E | 标准+ | `lib/src/workspace_page.dart`、`lib/src/session_pages.dart`、`lib/src/connection_page.dart`、`lib/src/map/map_privacy_page.dart` |
| MC11 | 间距归一与裸数字守卫 | MC06–MC10 | W4 | 标准+ | `test/chromatic_scale_guard_test.dart`、各页豁免注释（与 W3 交接） |
| MC12 | 图册、跨页一致性与验收 | MC06–MC11 | W5 | 强 | `docs/implementation/chromatic-language.md`、`docs/implementation/chromatic-language-renders/` |

W1-A / W1-B 与 W3-A…E 可以真并行：write scopes 不相交。W2 必须等 MC01 落地（组件要 import `MileafHue`）。

---

## 2. 通用合同（每票都适用）

1. **先读条款**：动作逐条挂 CL 号；与条款冲突时停下，不要自创。
2. **不改字号阶梯、不改版面结构、不改文案、不改数据口径**——本增量只改颜色、图标、间距层级、材质与那一条动效。
3. **不新增颜色 token 之外的色值**；页面不得出现十六进制。
4. **验证顺序**：`./tool/flutterw analyze --no-pub` → 本页相关 `./tool/flutterw test --no-pub test/<slice>_test.dart` → 收口时全量。
5. **copy guard**：新增中文文案（含 `semanticLabel`）会让基线失败，必须在 `test/support/copy_guard_baseline/<源文件>.txt` 上调并写理由；**不得**为了让守卫通过而删已有文案。
6. **停下交总控的六种情形**：① 条款之间冲突；② 需要改既有对比度守卫的色值；③ 需要改底栏；④ 需要改数据契约/后端；⑤ 页面结构需要重排（超出「上色 + 图标 + 间距归一」）；⑥ 测试失败原因指向他人的 write scope。
7. **完成即交接**：在 `docs/implementation/chromatic-language.md` 追加本票的小节（做了什么 / 证据 / 登记表一行 / 遗留），不要互相改写对方的小节。

---

## 3. 逐票动作

### MC00 基线登记
- 持有点：`docs/adr/0016-chromatic-language.md`、`docs/specs/chromatic-language.md`、`docs/specs/chromatic-language-tickets.md`、`AGENTS.md` 一条目。
- 动作：登记条款 CL01–CL48 与取色表；把「取代 ADR 0006 单强调色 / MG01 20% 口径」写进 ADR 0016；在 `docs/specs/days-matter-migration.md` 的 PD 登记表追加「MG01 被 CL06 取代」一行（只追加，不改原文）。
- 测试：无（文档）。
- 交接：ADR 0016 状态 accepted。

### MC01 语义色相 token 与解析出口
- 持有文件：`lib/src/design/tokens.dart`、`lib/src/design/semantic.dart`。
- 动作：
  - `tokens.dart` 追加 `MileafHueRamp`（六色相 × 浅 solid/strong/深 三值，十六进制+S 注记）与 `MileafHueWash`（soft 16%、tint 8% 的 alpha 常量）。**不改动任何现有常量的值。**
  - `semantic.dart` 追加 `enum MileafHue` 与 `extension MileafHueTone on MileafHue`：`solid/strong/soft/tint/onStrong`（CL09）；`soft`/`tint` 用 `Color.withValues(alpha:)` 基于当前模式的 solid；`onStrong` = 浅 `textOnAccent` / 深 `#0A0B0D`。
  - **不新增 `MileafColors` 字段**（避免 copyWith/lerp/ThemeExtension 面爆开）；hue 解析只读 `isDark` 与既有字段。
- 不做：不改 `accent*`；不给 hue 加 alpha 变体的 premultiplied 值。
- 测试：`test/chromatic_hue_token_test.dart`（六色相解析出预期十六进制、soft alpha=16%、tint alpha=8%、onStrong 双模）。
- 交接：`MileafHue` 可被组件 import。

### MC02 六色相对比度守卫
- 持有：`test/chromatic_contrast_guard_test.dart`。
- 动作（CL02/CL03）：对 6 色相 × 2 模式断言：
  - `solid` 对 `surface`/`canvas` ≥ 3.0（图形底线），实测应 ≥3.2；
  - `strong` 对 `canvas`/`surface` ≥ 4.5；
  - `strong` 对 `soft` 合成底（over canvas 与 over surface 两条） ≥ 4.5；
  - `onStrong` 对 `strong` 实心底 ≥ 4.5；
  - `text` 对 `tint` 合成底 ≥ 4.5（tint 是卡背板，正文会压在上面）。
- 不做：不改 `test/days_migration_color_guard_test.dart`（MG03 的口径与豁免不动）。
- 交接：守卫全绿，登记实测表到实施记录。

### MC03 图标家族扩充
- 持有：`lib/src/design/icons.dart`、`lib/src/design/components/icons.dart`、`test/icon_family_test.dart`。
- 动作：按 CL11 新增 `leaf` / `thermometer` / `speed` / `share` 四个字形（24 网格、1.5 线宽、圆头圆角、无填充）；在 `MileafIconFamily.semanticLabels` 补四句话义；家族测试扩到 29 个。
- 不做：不动既有 25 个字形；不引第二套库。
- 交接：`MileafIconName` 新值可用。

### MC04 组件层 hue 参数
- 持有：`components/metric.dart`、`components/section.dart`、`components/module.dart`、`components/charts.dart`。
- 动作（CL12/CL13 + §9.1）：
  - `SectionHeader`：加 `MileafHue? hue`、`MileafIconName? icon`（16 inline，取 hue.strong，间距 s8）。
  - `MetricBlock`：加 `MileafHue? hue` —— 值取 `hue.strong`（`MileafNumber.color`），label 前可选 16 身份图标。
  - `MileafModuleCard`：加 `MileafHue? hue` —— 背板叠 `hue.tint`（8%），描边不变。
  - `ChartSeries`：加 `MileafHue? hue`；painter 按索引取 `hue.solid` / `hue.strong` / `reference`；**null 时行为与今日完全一致**。
  - `MileafGroupRow`：`leading` 图标可按 hue 取 strong。
- 不做：不改任何缺省值；不改图表几何；不改动效。
- 测试：扩展 `test/design_components_test.dart` 的最小断言（hue 传入后取色正确、null 时像素等价），新增 `test/chromatic_components_test.dart` 更安全（避免与在途改动冲突）。
- 交接：页面可传 hue。

### MC05 按钮图标与浮层玻璃
- 持有：`components/button.dart`、`components/pull_down.dart`、`components/icon_button.dart`、`components/chip.dart`、`map/map_panel.dart`。
- 动作：
  - CL14：写入「图标在左、间距 s8、视觉居中、复述词义」的断言；补一张 `MileafActionIcon` 映射表（动作 → 图标），供页面引用。
  - CL30/CL31：`MileafPullDown` 背板改玻璃（复用 `MileafMaterialMetrics.glassBlur`/`glassSaturation` 与 `MileafColors.glass*`），地图浮控同参数；两者都必须保留 1px 描边兜底。
- 不做：不动底栏与顶栏；不给 sheet 加玻璃（CL30.1）。
- 测试：扩展 `apple_polish_ap03_test.dart`? 否——新增 `test/chromatic_material_test.dart` 断言玻璃参数引用单一来源、弹层无 BackdropFilter。
- 交接：浮层材质统一。

### MC06 概览页
- 动作（§9.2）：焦点卡 journey（焦点值 strong + 8% tint + `route` 图标）；每日里程图 `hue: journey`；电耗对比 `net: efficiency` / `gross: efficiency.strong`；本期账目网格四格分域 + 身份图标（里程 journey / 时长 dwell / 费用 cost / 电耗 efficiency）；最近记录行 leading 图标（行程 journey / 充电 energy）；用车专题三卡（节奏 dwell / 能耗 efficiency / 长期 efficiency）；按钮补图标（刷新 refresh、对比明细 chart）。
- 不做：不改版面顺序、不改读数头语法（R29）、不改文案。
- 测试：`a_overview_test.dart`、`apple_polish_ap07_test.dart` 等本页断言随结构映射更新；新增 `chromatic_overview_test.dart` 断言色相接线。
- 交接：登记表一行（色相数 3 / 彩色面积估算）。

### MC07 行程 + 行程详情
- 动作：行程页焦点卡 journey、每日里程图 journey、记录行 leading、里程/时长读值分域；详情页行驶过程 journey、电量过程 energy、驾驶与环境（速度 journey + `speed` 图标、温度 climate + `thermometer`、功率 energy + `bolt`）。
- 不做：不改 C 渲染裁定过的顺序（Spec #1 第 363 条措辞）。
- 测试：`a_drives_test.dart`、`a_drive_detail_test.dart` + 新增接线断言。

### MC08 充电 + 充电详情
- 动作：账目卡 energy + cost；每日充电图 energy；AC/DC 分环 energy 双档（solid / strong）；记录行 energy；地点行 energy；补录胶囊 wallet 用**动作色**（不是 cost 色）。
- 不做：不改费用补录流程与文案（CET01–CET07 冻结）。
- 测试：`a_charging_test.dart`、`a_charging_detail_test.dart`、`charging_cost_test.dart`。

### MC09 统计根 + 五专题
- 动作：根页 2×2 章节卡分域（洞察 journey / 充电 energy / 续航 efficiency / 停放 dwell）+ 条件下钻 climate；各专题的主图与网格按域接线；结论句下的主图按所选指标域。
- 不做：不改「结论 + 主图 + 章节卡」的版面范式（ADR 0001 / 2026-10-30 决定）；不改技术口径的收纳方式。
- 测试：`a_statistics_test.dart` + 各专题测试。

### MC10 工作区 / 设置 / 连接 / 地图
- 动作：**不引入数据身份色**（CL05）；车行 leading `car`；刷新按钮 refresh 图标；间距按 CL20 归一；玻璃浮控按 MC05 的组件自动生效。
- 测试：`design_components_test.dart` 中相关断言、`settings_order` 相关测试。

### MC11 间距归一与裸数字守卫
- 动作（CL20–CL22）：新增 `test/chromatic_scale_guard_test.dart`，扫描 `lib/src/**`（排除 `design/tokens.dart`、`MileafElevation`）中的裸间距/裸半径字面量；首轮允许 `// CL22-exempt: 理由`，全部豁免登记到实施记录 §9.4。
- 不做：不为过守卫而改版面视觉效果（只把 10/13/15 这类越级值迁到最近的有名档位）。

### MC12 图册与收口
- 动作：按 `MILEAF_RENDER_OUTPUT` 采浅/深 × 360/390 × 200% 字号；跨页一致性核对（同一指标在同一页组的色相相同）；填登记表全表；写验收自检结果；更新 `AGENTS.md`。
- 不做：不改代码（发现问题开新票）。

---

## 4. 多会话提示词

把 `<票号>` 与对应段落替换即可。每个提示词都是自包含的——新会话没有本轮上下文。

### 4.1 通用开场（所有会话都用）

```
你在 MileafMobile 仓库（/Users/milkyway/Public/DevHub/Codes/Personal/Mileaf/MileafMobile）执行「色彩与图标秩序」增量的一个切片。

先读（按顺序，只读这三份）：
1. AGENTS.md（仓库规矩）
2. docs/adr/0016-chromatic-language.md（本轮决定 D1–D7）
3. docs/specs/chromatic-language.md（条款 CL01–CL48，你的动作必须挂条款号）

硬边界：不改字号阶梯 / 不改版面结构 / 不改文案 / 不改数据口径 / 不碰底栏（ADR 0013 冻结）/ 页面不出现十六进制。
遇到以下情形立即停下并汇报，不要自行决定：条款冲突、要改既有对比度守卫的色值、要改底栏、要改数据契约、要重排页面结构、测试失败指向别人的 write scope。

验证：./tool/flutterw analyze --no-pub → ./tool/flutterw test --no-pub test/<你的切片>_test.dart → 收口前跑全量（今天基线 1176 过 / 55 跳过 / 0 失败）。
copy guard：新增中文（含 semanticLabel）会让 test/support/copy_guard_baseline/<源文件>.txt 失败，上调需写理由；不得删已有文案。
完成时在 docs/implementation/chromatic-language.md 追加你那一票的小节（做了什么/证据/登记表一行/遗留），不要动别人的小节。
不要提交、不要推送（由总控统一收口）。
```

### 4.2 W1-A：MC01 + MC02（token 与对比度）

```
<通用开场>
你的票：MC01 + MC02（tokens + semantic 的 MileafHue，以及六色相对比度守卫）。

持有文件（只有这些）：lib/src/design/tokens.dart、lib/src/design/semantic.dart、test/chromatic_hue_token_test.dart、test/chromatic_contrast_guard_test.dart。

做法：
- 在 tokens.dart 追加 MileafHueRamp：六色相 × {浅 solid、浅 strong、深 solid}，值严格照 docs/specs/chromatic-language.md §4 CL01 的表，一字不改；另加 soft=16%、tint=8% 的 alpha 常量。
- 在 semantic.dart 追加 enum MileafHue 与 extension MileafHueTone：solid/strong/soft/tint/onStrong（CL09）。soft/tint 用 Color.withValues(alpha:) 基于当前模式的 solid；onStrong 浅色 = textOnAccent、深色 = #0A0B0D。不要新增 MileafColors 字段。
- 不要改动任何现有常量（accent/accentSoft/azure500/600/300 必须逐字节不变）。
- 守卫测试覆盖 CL02/CL03 的五组断言（solid vs surface/canvas ≥3.0；strong vs canvas/surface ≥4.5；strong vs soft 合成底 ≥4.5 两条口径；onStrong vs strong ≥4.5；text vs tint 合成底 ≥4.5），双模各跑一遍。不要改 test/days_migration_color_guard_test.dart。

自检：analyze 无诊断；两个新测试文件全绿；全量测试数量只增不减、无新增失败。
```

### 4.3 W1-B：MC03（图标）

```
<通用开场>
你的票：MC03（图标家族扩充 4 个字形）。

持有文件：lib/src/design/icons.dart、lib/src/design/components/icons.dart、test/icon_family_test.dart。

做法：按 CL11 新增 leaf / thermometer / speed / share。全部 24×24 网格、1.5 线宽、StrokeCap.round、StrokeJoin.round、无填充（只用 path.moveTo/lineTo/cubicTo/addArc/addOval 与既有 dots/filled 列表）。
- leaf：叶片轮廓 = 两条对称三次贝塞尔 + 中脉直线 + 叶柄短线。
- thermometer：竖向药丸球管（round rect，宽 3.6）+ 底部圆球（r 2.6）+ 三条刻度横线。
- speed：半圆表盘弧（圆心 12,14，r 7.6，从 π 到 2π）+ 指针（12,14 → 9.2,9.6）+ 中心实心点 1.2。
- share：三个节点圆 + 两条连线（右上→左、左下→右下）。
在 MileafIconFamily.semanticLabels 补四句话义（「续航与效率」「温度」「速度」「分享」）。家族测试由 25 扩到 29，并断言新名字在 semanticLabels 里。

自检：analyze 无诊断；test/icon_family_test.dart 全绿；不准动既有 25 个字形。
```

### 4.4 W2：MC04（组件层）

```
<通用开场>
你的票：MC04（组件层 hue 参数）。前置：MC01 已落地（MileafHue 与 MileafHueTone 可用）。

持有文件：lib/src/design/components/metric.dart、section.dart、module.dart、charts.dart、test/chromatic_components_test.dart（新建）。

做法（CL12/CL13，规格 §9.1）：
- SectionHeader 加 MileafHue? hue、MileafIconName? icon（16 inline 图标在标题前，取 hue.strong，间距 s8）。
- MetricBlock 加 MileafHue? hue（值走 MileafNumber.color = hue.strong；可选 16 身份图标在 label 前）。
- MileafModuleCard 加 MileafHue? hue（背板叠 hue.tint，描边不变）。
- ChartSeries 加 MileafHue? hue；painter 按序列索引取 hue.solid / hue.strong / reference；hue 为 null 时取色与今天完全一致（这条要有断言）。
- MileafGroupRow 的 leading 图标支持按 hue 取 strong。

不做：不改任何缺省行为、不改图表几何、不改动效时长、不改图表语义句。
自检：analyze 无诊断；新增测试全绿；**全量测试必须零新增失败**（这条最重要——组件被全 App 复用）。
```

### 4.5 W2：MC05（按钮图标 + 浮层玻璃）

```
<通用开场>
你的票：MC05（按钮图标纪律与浮层玻璃）。

持有文件：lib/src/design/components/button.dart、icon_button.dart、chip.dart、pull_down.dart、lib/src/map/map_panel.dart、test/chromatic_material_test.dart（新建）。

做法：
- CL14：在 button.dart 固化「图标在左、间距 s8、视觉居中」；新增 MileafActionIcon 映射表（动作语义 → MileafIconName），供页面按动作取图标，避免页面各自挑图标。
- CL30/CL31：MileafPullDown 背板改玻璃（复用 MileafMaterialMetrics.glassBlur=22、glassSaturation=1.5、MileafColors.glass* 叠色与受光边），保留 1px 描边兜底；地图浮控同参数。
- CL30.1：不给任何 bottom sheet / dialog 加 BackdropFilter。

测试：断言玻璃参数来自单一来源（不出现裸 22/1.5）、断言 sheet 路径无 BackdropFilter、断言按钮图标在左且间距 s8。
自检：analyze 无诊断；全量零新增失败。
```

### 4.6 W3：页面票（MC06–MC10 各一份）

```
<通用开场>
你的票：MC<0X>（<页面名>页接线）。前置：MC01–MC05 已落地。

持有文件（只有你这一票列出的页面文件与其专属测试；不要碰 components/ 与 design/）：
<该票的 write scopes，见 §1 表格>

做法：严格按 docs/specs/chromatic-language.md §9.2 里你这一行的域绑定表接线，并完成 §9.3 的三件小事（补按钮图标、间距归一、彩色面积登记）。
- 色相只通过 MileafHue / MileafHueTone 传，页面不出现十六进制、不出现 Color(0x...)。
- 身份图标取所属域；动作图标取按钮前景色；同一指标在同一页组必须是同一个色相。
- 一页首屏可见数据色相 ≤3（CL07）。超了就把最不重要的那组换成中性，并在交接里说明。

不做：不改版面顺序、不改文案、不改读数头/图表语法（R29）、不改数据契约、不动底栏与顶栏。

测试：本页既有测试若因取色变化失败，按「结构→取色」的映射规则更新断言（不要放宽断言强度）；新增一条接线断言（至少覆盖：主图序列色、焦点/主值颜色、一个身份图标存在）。
自检：analyze 无诊断；本页测试全绿；全量零新增失败；copy guard 基线若变化写理由。

交接：在 docs/implementation/chromatic-language.md 追加你的小节 + 登记表一行（可见色相数 / 非图表彩色面积估算 / 高彩度面积估算 / 新增图标数 / 遗留）。
```

### 4.7 W4：MC11（间距归一）

```
<通用开场>
你的票：MC11（间距归一与裸数字守卫）。前置：五个页面票已落地。

动作：新建 test/chromatic_scale_guard_test.dart，扫描 lib/src/**（排除 lib/src/design/tokens.dart）里的裸间距/裸半径字面量（SizedBox/EdgeInsets/BorderRadius.circular/margin/padding 的数字），命中即失败；给首轮确实要保留的行加 // CL22-exempt: 理由，并把全部豁免登记进实施记录 §9.4。
同时把 grep 出来的越级值（10/13/15/18 这类不在 {4,8,12,16,20,24,32} 的间距）迁到最近的有名档位——只调数字，不改版面结构。

自检：守卫全绿；analyze 无诊断；全量零新增失败；把迁移清单（文件 → 旧值 → 新值）写进交接。
```

### 4.8 W5：MC12（收口）

```
<通用开场>
你的票：MC12（图册 + 跨页一致性 + 验收）。前置：MC06–MC11 全部完成。

动作：
1. 采图册：./tool/flutterw test --no-pub test/<切片>_render_test.dart --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/chromatic-language-renders/<包> --dart-define=MILEAF_RENDER_FONT='/System/Library/Fonts/Supplemental/Arial Unicode.ttf'（DPR 1 + pixelRatio 2；浅深成对 × 360/390 × 200%）。
2. 跨页一致性核对：把六个域的色相 × 出现页面列成矩阵，确认同一指标在所有页面同色；发现不一致直接列出文件:行号。
3. 填登记表全表；写验收自检（对照规格 §10 的八行）。
4. 更新 AGENTS.md 一条目。

不做：不改代码。发现问题开新票并说明。
自检：图册可打开、每包 ≥4 张、深浅各一；全量测试与 analyze 结果抄进交接。
```

---

## 5. 并行度说明

| 波次 | 可并行会话数 | 依据 |
| --- | --- | --- |
| W0 | 1 | 文档单写 |
| W1 | 2（A：MC01+02；B：MC03） | `design/tokens.dart+semantic.dart` 与 `design/icons.dart` 不重叠 |
| W2 | 2（MC04；MC05） | 组件文件不重叠 |
| W3 | 5（MC06–MC10） | 页面文件不重叠（统计票内部串行，因 6 个文件互相 import） |
| W4 | 1 | 全库扫描，必须收口后做 |
| W5 | 1 | 需要全部结果 |

单会话上下文建议：一个页面票 ≈ 一页 1000–2500 行 + 其测试，正好用完一个会话的精度预算。不要把两页塞进一个会话。
