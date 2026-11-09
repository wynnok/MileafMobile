# 地图设置页按「细线列表 + 留白」重排

- 日期：2026-11-09
- 状态：accepted（用户于 2026-11-09 确认 ADR 后授权落盘并继续 Spec；D5 按同日确认的 Spec §0 框架事实修正）
- 关系：继承 [ADR 0003](0003-visual-direction-a.md)（版面范式）、[ADR 0006](0006-appearance-and-accent.md)（外观 v2 / R1–R3）、[ADR 0008](0008-user-amap-key.md)（功能边界）、[ADR 0009](0009-settings-navigation.md)（入口）；作为 [自备高德地图 Key Spec](../specs/user-amap-key.md) 的呈现层增量，不回溯改写其已冻结色板、字号与页面顺序。
- 范围：`MapPrivacyPage` 呈现层与少量 additive 共享组件；不碰数据、状态机、原生通道、双端入口。

## 1. 截图与代码的对应关系（现状事实）

| 代码事实 | 出处 | 设计判断 |
| --- | --- | --- |
| 截图里橙红色圆角框是评注标注，不是产品元素 | [theme.dart:267](../../lib/src/design/theme.dart#L267) 的 `expansionTileTheme` 设 `shape: Border()`、`tilePadding: EdgeInsets.zero` | 不实现任何边框或容器；要重排的是框内部的内容 |
| 整页是 `stretch` 的 Column 平铺，三段由 `_configuration / _help / _privacy` 拼出 | [map_privacy_page.dart:148](../../lib/src/map/map_privacy_page.dart#L148)、[:154](../../lib/src/map/map_privacy_page.dart#L154) | `stretch` 让每个 `TextButton` 都变成全宽且文字居中，是失去秩序的根因 |
| 配置区六个元素几乎是同一字号与权重：状态、整段说明、字段标签、脱敏值、整宽按钮、整宽文字按钮 | [map_privacy_page.dart:171–295](../../lib/src/map/map_privacy_page.dart#L171-L295) | 没有「结论 → 配置 → 操作」的主次，违反 ADR 0003 §1「结论先行」 |
| 帮助区步骤是写在一个 `Text` 里的 `1. 2. 3.` 长句；绑定值是「标签 → 值 → 整宽复制按钮」三段式；控制台链接是孤立的居中蓝字 | [map_privacy_page.dart:298–359](../../lib/src/map/map_privacy_page.dart#L298-L359) | 技术信息与操作没有键值关系；三个蓝色复制动作与多个操作超出外观 v2 R2「同屏最多 2 个强调色对象」 |
| 隐私区重复「行标题 + 长说明 + 状态 + 整宽按钮 + 长说明 + URL + 整宽按钮」 | [map_privacy_page.dart:361–413](../../lib/src/map/map_privacy_page.dart#L361-L413) | 与配置区同构的堆砌，整页共 3 个整宽按钮与 5 个整宽文字按钮 |
| 配置区末尾 `SizedBox(section=28)` 后紧接 `ExpansionTile`（自身 56 tile） | [map_privacy_page.dart:294](../../lib/src/map/map_privacy_page.dart#L294)、[:298](../../lib/src/map/map_privacy_page.dart#L298) | 截图中无语义大留白的来源 |
| 状态字串由 `MapKeyController.status` 提供，同时被设置首页复用 | [map_key.dart:46](../../lib/src/map/map_key.dart#L46)、[settings_page.dart:93](../../lib/src/settings_page.dart#L93) | 状态字串冻结，本次只改它的承载方式 |
| 两份教程与页面测试逐字依赖 `复制包名` / `保存 Key` / `清除已保存的 Key` / `如何申请 Key` | [map_key_page_test.dart](../../test/map_key_page_test.dart)、[amap-key-settings.md](../tutorial/amap-key-settings.md)、[amap-key-application.md](../tutorial/amap-key-application.md) | 精简文案时，这些词必须保留在可见标题或 Semantics label 中 |

## 2. 本轮已确认的边界

1. 整页三段统一重排。
2. 细线列表 + 留白，零新增表面。
3. 单页、默认折叠、展开后重排。
4. 允许精简重写文案并同步教程与测试。
5. 动作行内化，破坏操作独立 `error` 行。
6. 新建 ADR 0010、新 Spec 与 Ticket；旧 Spec 只追加增量。

代码已回答、不再重新假定的项：品牌色为电光蓝；浅色与深色双模式由 `mileafTheme` 与跟随系统提供，两种都要验收；三层 token 已存在，本次不新增 primitive；地图 Key 是设备级配置，与车型、多车、站点无关；不新增后端或原生能力。

## 3. 决策

### D1 三段各一个 `label` 眉标，AppBar 仍是本页唯一 18px 标题

沿用 [settings_page.dart:85](../../lib/src/settings_page.dart#L85) 与 [connection_management.dart:125](../../lib/src/connection_management.dart#L125) 已有的分组语法：`Text(..., style: context.type.label)` + `Semantics(header: true)`，段间 `MileafSpace.section(28)`。

**改了什么**：配置区前的空白与「状态 / 说明 / 表单」混排，改为「本机配置 / 申请帮助 / 地图隐私」三个可读段。

**为什么**：一页里再叠三个 `SectionHeader`（18/22/600，见 [section.dart:36](../../lib/src/design/components/section.dart#L36)）会与 AppBar 的 `type.title` 形成四个同权标题；`label` 眉标是 Apple grouped list 的层级语言，且已在仓库里成立。

### D2 零新增表面：分组只用 1px 细线与留白

复用 [MileafDataRow](../../lib/src/design/components/data_row.dart) 的 `topLine/bottomLine`（`colors.line`，1px）、[MileafSpace](../../lib/src/design/tokens.dart) 既有档位与 [MileafLayout.pagePadding](../../lib/src/design/layout.dart) 的 20/24。

**改了什么**：不新增任何 `Container` 背景、`BoxDecoration` 圆角、`BoxShadow`、原始色值、字号、圆角档位或动效时长；`tokens.dart`、`semantic.dart`、`theme.dart` 的全局主题零改动。

**为什么**：[ADR 0003](0003-visual-direction-a.md) §6「内容区不使用卡片阴影 / 不再有全站卡片」、[视觉系统 Spec](../specs/visual-system-a.md) §1「留白是结构」、[外观 v2 Spec](../specs/appearance-v2.md) R1「中性底不染色」。精致感来自节奏，不来自再包一层卡片。

### D3 状态结论化，Key 行内化

- 顶部：24px `MileafIcon(mapPin, color: accent)` + `MapKeyController.status`（`type.body` / 600）+ 一句 `type.micro` 的「保存在本机 · 所有车辆与站点共用」；`restartRequired` 时状态与短说明才用 `colors.warning`，`readFailed` 用 `colors.error`。
- 已保存态：`${platformLabel} 地图 Key` 收进一条 `MileafDataRow`：`title` 为平台标签，`badge` 为脱敏末四位（`type.body` + `textMuted`），`showChevron: true`，`onTap` 进入编辑；替换现有「标签 + 脱敏值 + 整宽更换按钮」三行。
- 编辑与未配置态：保留 `TextField`（`InputDecoration.labelText` 承载平台标签，沿用 [theme.dart:88](../../lib/src/design/theme.dart#L88) 的 12 圆角、16×12 与 focusRing）→ 唯一一个整宽 `FilledButton('保存 Key')` → 左对齐 `TextButton('取消更换')`。

**改了什么**：[map_privacy_page.dart:176–207](../../lib/src/map/map_privacy_page.dart#L176-L207) 的 `Wrap`、整段 13px 说明与独立字段标签；[L260–281](../../lib/src/map/map_privacy_page.dart#L260-L281) 的脱敏值与两个整宽按钮。

**为什么**：状态是这一页的结论，应第一眼可读；Key 是配置对象，不是一段说明。编辑态保留一个整宽主按钮符合 [ADR 0003 §7.6](../specs/visual-system-a.md)「主按钮一屏最多一个」；被取消的是已保存态的整宽按钮，不是表单提交。

### D4 动作层级：一屏一个主按钮、复制图标化、破坏操作独立 error 行

- 新增 `MileafIconName.copy`（24 网格、1.5 描边、双圆角矩形），用 [MileafIconButton](../../lib/src/design/components/icon_button.dart) 提供 44×44、按压 `accentSoft`、2px focus ring 与 `Semantics(label: '复制包名')`。
- 新增细线组件 `MileafCopyRow`（`lib/src/design/components/copy_row.dart`，经 [components.dart](../../lib/src/design/components/components.dart) 导出）：左侧 `label(10)` + `SelectableText(body 13/19.5)`，右侧 44×44 复制图标，透明底、仅 1px 底线；大字号时 label/value 与按钮堆叠，与 [data_row.dart:125](../../lib/src/design/components/data_row.dart#L125) 同规则。
- [MileafDataRow](../../lib/src/design/components/data_row.dart) 增加 additive 的 `bool destructive = false`：为 true 时 `title` 用既有 `colors.error`，仍带文字，不靠颜色单独表意（[外观 v2 Spec](../specs/appearance-v2.md) §3.4）。「清除已保存的 Key」成为独立细线行，确认弹窗 [map_privacy_page.dart:72](../../lib/src/map/map_privacy_page.dart#L72) 保留。

**改了什么**：三个「复制」文字按钮、整宽「更换 Key」、居中「清除已保存的 Key」。

**为什么**：把「可点 / 当前 / 数据」之外的蓝色全部收回，全屏强调色对象收敛为「状态图标」与仅编辑态出现的「保存按钮」两个，满足 R2；破坏操作用 Apple 的 destructive red 且沿用现成语义 token。

### D5 申请帮助：有序步骤、键值复制行、单行控制台链接

沿用 [theme.dart:267](../../lib/src/design/theme.dart#L267) 已主题化的 `ExpansionTile`（`tilePadding: 0`、无边框），默认折叠，首次展开仍触发 `_readBinding()`。**2026-11-09 框架事实修正（随 Spec 确认）**：当前 Flutter 的 `ExpansionTile` 只旋转内置默认箭头，传入的自定义 `trailing` 不会被旋转（已以仓库锁定 Flutter SDK 内 `expansion_tile.dart` 的 `_buildIcon` / `_buildHeader` 核对），因此本页维护 `_helpExpanded` 与 `_privacyDetailsExpanded` 两个 `bool`，用 `AnimatedRotation` 驱动 16px `MileafIcon(chevron)`：折叠 `turns = 0.25`（下指）、展开 `turns = 0.75`（上指），差值 180°；时长 `MileafLayout.motion(context, MileafDurations.enter)`（180ms / `MileafCurves.enter`，reduce motion 归零），`onExpansionChanged` 同步 bool。颜色 `textFaint`，避免 Material 实心 caret 破坏 [icons.dart](../../lib/src/design/icons.dart) 的 1.5 描边语言。children 重排为：

1. 三条 `_StepRow`（`label` 序号 `textFaint` + `body` 文案，8px 行距），以当前代码与 [申请教程](../tutorial/amap-key-application.md) 的三步为准。
2. 每个 `getBinding` 条目一条 `MileafCopyRow`。
3. 读取中改用 [MileafProgressLine](../../lib/src/design/layout.dart#L83)（2px），失败改用 [InlineBanner](../../lib/src/design/components/state_view.dart#L106)（`tone: error` 与重试）。
4. 一句 `type.micro` 重签名脚注；控制台链接从居中蓝色文字按钮改成一条 `MileafCopyRow`（显示 `console.amap.com/dev/key/app`，`copyText` 仍为完整 URL）。

**改了什么**：[map_privacy_page.dart:298–359](../../lib/src/map/map_privacy_page.dart#L298-L359) 的整段长句、两段式绑定值、孤立的居中链接。

**为什么**：技术标识需要「标签 / 值 / 复制」的键值关系与可选择正文（[自备高德地图 Key Spec](../specs/user-amap-key.md) §6），SHA-1 换行后不再打断节奏；控制台链接不再是一个悬空的强调色对象。

### D6 地图隐私：摘要与可展开详情

眉标「地图隐私」下：`MileafDataRow('底图授权', meta: 已允许/未允许加载底图)` 一条状态行 → `MileafDataRow(granted ? '关闭底图' : '重新启用地图', showChevron: true)` 一条动作行 → 第二个 `ExpansionTile('数据使用说明')` 收纳原两段长说明与隐私政策链接（同样用 `MileafCopyRow`）。`MapConsentController.revoke` 与 [showMapConsentSheet](../../lib/src/map/map_consent_sheet.dart) 调用及授权语义不变。

**改了什么**：[map_privacy_page.dart:361–413](../../lib/src/map/map_privacy_page.dart#L361-L413) 的七个平铺元素。

**为什么**：与 D1/D3 同一套「结论 → 操作 → 口径」层级；默认首屏不再出现整宽「重新启用地图」按钮与长隐私说明，达成详略得当。

### D7 文案可精简，但语义定位词与状态字串不失效

`MapKeyController.status`、`保存 Key`、`清除已保存的 Key`、`重新启用地图`、`如何申请 Key` 保持可见；三个复制动作改为图标后，`tooltip` 与 `Semantics.label` 保留原中文词组「复制包名」「复制签名 SHA-1」「复制高德控制台链接」。

**改了什么**：[map_key_page_test.dart](../../test/map_key_page_test.dart) 中 `find.text('复制包名')` 改为 `find.bySemanticsLabel(...)`；[设置教程](../tutorial/amap-key-settings.md) 与 [申请教程](../tutorial/amap-key-application.md) 改为「点击右侧复制按钮」。

**为什么**：既允许精简可见文案，又不让既有验收与教程失效；`MapKeyController` 与 [settings_page.dart](../../lib/src/settings_page.dart) 零改动。

## 4. 逐文件变更映射

| 文件或组件 | 改动 | 理由 |
| --- | --- | --- |
| [map_privacy_page.dart](../../lib/src/map/map_privacy_page.dart) | 三段重排：眉标、状态行、Key 行 `MileafDataRow`、`MileafCopyRow`、error 破坏行、两个折叠区；删除 3 个整宽按钮与 5 个整宽文字按钮 | 本轮唯一业务呈现落点；`PopScope`、`_save/_clear/_readBinding/_copy`、控制器契约不动 |
| [data_row.dart](../../lib/src/design/components/data_row.dart) | additive `destructive` 参数，默认 false，既有调用方行为不变 | 让破坏色留在组件内部消费 token，页面不传裸色 |
| [icons.dart](../../lib/src/design/icons.dart) | additive `MileafIconName.copy` | 复制必须与既有关键图标同一网格、线宽与焦点态 |
| 新建 `copy_row.dart` 并在 [components.dart](../../lib/src/design/components/components.dart) 导出 | 细线键值行与 44×44 复制按钮，透明底 | 在零新增表面的前提下承载可选择的技术值 |
| [design_tokens_test.dart](../../test/design_tokens_test.dart) | 图标计数 15 → 16；其余色板、间距、圆角、对比度断言不变 | 新增图标不引入新色值，但计数断言必须同步 |
| [map_key_page_test.dart](../../test/map_key_page_test.dart) | 复制定位改 bySemanticsLabel；新增「已保存态不出现整宽更换按钮、清除行为细线行」断言 | 覆盖重排后的可达性与语义 |
| [map_key_render_test.dart](../../test/map_key_render_test.dart) 与 [图册](../implementation/map-key-renders/README.md) | 浅深 × 6 态重生成，另补「隐私详情展开」态 | 正式 Flutter 渲染是本次视觉验收证据 |
| [user-amap-key.md](../specs/user-amap-key.md) | 仅追加一条 2026-11-09 视觉增量并指向新 Spec；不改写已冻结色板与状态表 | 按已确认的第 6 项决策 |
| 两份 [教程](../tutorial/amap-key-settings.md) | 同步可见文案与操作路径 | 逐字引用需保持一致 |

## 5. 取舍与被否方案

| 被否方案 | 原因 |
| --- | --- |
| iOS grouped-list 白色圆角容器 | 会新增第二套表面语言，与 ADR 0003 §6「内容区不用卡片 / 统一 18px 卡片退役」冲突，且需扩充 token 与 `design_tokens_test.dart` |
| 拆「申请 Key / 地图隐私」二级子页 | 导航结构变化，超出「只改 MapPrivacyPage」的确认边界；`map_panel.dart` 速写入口与两份教程都要改路径 |
| 保留按钮，只统一对齐 | 无法把强调色对象降到 2 个，也解决不了 `stretch` 造成的居中文字按钮 |
| 新增 `surface` 底的技术信息卡 | 与 D2 冲突，且浅色 `surface=#FFFFFF` 与 `canvas=#F4F5F7` 的 ΔL*3.5 已在 hero 体系里有明确用途 |
| 改 `MapKeyController.status` 让状态更短 | 该字串同时是 [settings_page.dart:93](../../lib/src/settings_page.dart#L93) 的首页副文案与「待重启 / 未配置」语义载体，改它等于扩大范围 |

## 6. 影响、风险、不做什么

- **风险**：`MileafDataRow` 是多个页面共用的组件，本次只加默认关闭的参数；`ExpansionTile` 的 `trailing` 覆盖只在本页，不动 `expansionTileTheme`，避免影响其他页面。
- **已知代价**：三个「复制」可见文字消失，用户需靠 44×44 图标与 tooltip 识别；以 `Semantics.label` 与教程同步兜住。
- **不做什么**：不改 [map_key.dart](../../lib/src/map/map_key.dart)、[map_consent.dart](../../lib/src/map/map_consent.dart)、`MapBinding`、[map_panel.dart](../../lib/src/map/map_panel.dart)、[settings_page.dart](../../lib/src/settings_page.dart)；不改 `tokens.dart`、`semantic.dart`、`theme.dart` 全局主题；不新增色值、字号、圆角、阴影、动效；不新增导航层级；不推送、不提前关闭外部 gate。

## 7. 验收口径

- `tool/flutterw analyze --no-pub` 无诊断；`tool/flutterw test --no-pub` 全绿；`test/map_key_page_test.dart` 单文件先跑。
- 正式 Flutter 渲染：浅色与深色 × 未配置、已保存、待重启、帮助展开、隐私展开、320 宽 200%、键盘 300；无布局溢出、无横向滚动。
- 逐像素检查：三段 28px 段距、眉标 10/13、行最小 56、1px `line`、44×44 触达、2px focusRing、状态与保存为仅有的强调色对象。
- 双轴 `code-review`（Standards 与 Spec）以及当前 `main` 本地提交，不推送。

## 8. 下游产物

1. 本文：`docs/adr/0010-map-settings-visual.md`。
2. Spec：`docs/specs/map-settings-visual.md`，含逐像素规格与状态矩阵。
3. Ticket：`docs/specs/map-settings-visual-tickets.md`，含验收标准。
4. 三份产物都确认后才动代码。

## 9. 变更记录

- **2026-11-09（落盘时）**：D5 按 Spec §0 的框架事实修正——当前 Flutter 的 `ExpansionTile` 只旋转内置默认箭头，传入的自定义 `trailing` 不会被旋转；折叠箭头改由本页两个 `bool` + `AnimatedRotation` 驱动，其余决策不变。
- **2026-11-09（实施期，用户逐项确认）**：① `MileafIconName.copy` 后层偏移 2 → 4（`(10.5, 10.5) → (19.5, 19.5)`），原坐标在 20px 下两层几乎重合、读作单框重影；② 待重启短说明收紧为「本次运行仍用原 Key」，不再与冻结的 `status`「已保存 · 重新启动后生效」重复；③ 该短说明层级以 Spec §3 为准取 `micro`，Spec §7 原表标 `body` 的字面同步更正。三项均不新增色值、字号、圆角、阴影或动效时长，不改冻结定位词与 tooltip，详见 [视觉 Spec §14](../specs/map-settings-visual.md)。
