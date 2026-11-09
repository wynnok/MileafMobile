# 地图设置页视觉规格（Spec）

- 日期：2026-11-09
- 状态：confirmed（用户于 2026-11-09 确认，含 ADR 0010 D5 的框架事实修正）
- 依据：[ADR 0010](../adr/0010-map-settings-visual.md)、[ADR 0003](../adr/0003-visual-direction-a.md)、[ADR 0006](../adr/0006-appearance-and-accent.md)、[视觉系统 Spec](visual-system-a.md)、[外观 v2 Spec](appearance-v2.md)、[自备高德地图 Key Spec](user-amap-key.md)。
- 范围：只含 `MapPrivacyPage` 呈现层与三处 additive 共享改动；不改数据、状态机、原生通道、双端入口、全局主题。

## 0. 框架事实修正（已随本 Spec 确认）

当前 Flutter 的 `ExpansionTile` 只旋转它内置的默认箭头（`_buildIcon` / `RotationTransition`）；传入的自定义 `trailing` 不会被旋转（仓库锁定 SDK 内 `expansion_tile.dart` 的 `_buildIcon` 与 `_buildHeader` 已核对）。因此 [ADR 0010 D5](../adr/0010-map-settings-visual.md) 中「展开时由 `ExpansionTile` 翻 180°」修正为：

- 本页维护 `_helpExpanded` 与 `_privacyDetailsExpanded` 两个 `bool`；
- 用 `AnimatedRotation` 驱动 16px `MileafIcon(chevron)`：折叠 `turns = 0.25`（右向 chevron 顺时针 90° → 下指），展开 `turns = 0.75`（270° → 上指），差值恰为 180°；
- 时长 `MileafLayout.motion(context, MileafDurations.enter)`（180ms / `MileafCurves.enter`，reduce motion 归零）；
- `ExpansionTile` 本身只提供无边框 tile 与折叠容器，`onExpansionChanged` 同步 bool。

ADR 其余决策不变，落盘时已同步修正 D5 与 §9 变更记录。

## 1. 信息架构与阅读顺序

```
AppBar「地图」(title 18/22/600)
└─ MileafContent(maxWidth 560)
   └─ SingleChildScrollView + pagePadding(20/24, top 12, bottom 24)
      ├─ [眉标] 本机配置
      │   ├─ 状态结论行：mapPin + status + micro 说明
      │   ├─ Key 配置：编辑态表单 / 已保存态 MileafDataRow 摘要
      │   └─ 破坏操作行：清除已保存的 Key（destructive）
      ├─ 28px
      ├─ [眉标] 申请帮助
      │   └─ 折叠「如何申请 Key」（默认折叠）
      │       └─ 3 条步骤 → 绑定信息 MileafCopyRow(s) → 脚注 → 控制台链接 MileafCopyRow
      ├─ 28px
      └─ [眉标] 地图隐私
          ├─ 授权状态 MileafDataRow
          ├─ 授权动作 MileafDataRow
          └─ 折叠「数据使用说明」（默认折叠）
              └─ 数据说明 → SDK 内存说明 → 隐私政策 MileafCopyRow
```

三段各用 `Semantics(header: true) + Text(..., style: context.type.label)`，沿用 [settings_page.dart:85](../../lib/src/settings_page.dart#L85) 与 [connection_management.dart:125](../../lib/src/connection_management.dart#L125) 的既有分组语法。AppBar 仍是本页唯一 18px 标题；不新增 `SectionHeader`（避免四个同权标题）。

**改了什么**：删除 [map_privacy_page.dart:148](../../lib/src/map/map_privacy_page.dart#L148) 的 `crossAxisAlignment: stretch` 平铺与 [L294](../../lib/src/map/map_privacy_page.dart#L294) 后叠加的无语义 28px 大留白。
**为什么**：`stretch` 使每个 `TextButton` 变成全宽且文字居中，是截图中「失去秩序」的根因；三段眉标建立可读的层级。

## 2. 色板（零新增 primitive）

全部沿用 [semantic.dart](../../lib/src/design/semantic.dart)，浅色与深色由 [mileafTheme](../../lib/src/design/theme.dart) 提供：

| 语义 | 用途 |
| --- | --- |
| `canvas` | 页面底（浅 `#F4F5F7` / 深 `#0A0B0D`） |
| `text` / `textMuted` / `textFaint` | 主文 / 说明 / 眉标与序号 |
| `accent` | 状态 `mapPin` 图标（图形，≥3:1） |
| `accentStrong` | 文字链接、实心按钮（文字，≥4.5:1） |
| `accentSoft` / `pressOverlay` | 按压与选中高亮 |
| `line` / `lineStrong` / `focusRing` | 1px 分隔、1px 输入边、2px focus |
| `warning` / `error` | 待重启 / 读取失败 / 破坏操作（必带文字） |

- 新增 primitive 数 = 0；[design_tokens_test.dart](../../test/design_tokens_test.dart) 的对比度、明度阶、间距、圆角、时长断言零改动（仅图标计数 15 → 16）。
- **R2 强调色对象计数**：默认首屏最多 2 个（状态 `mapPin` + 仅编辑态的「保存 Key」）；已保存态与隐私折叠时只有状态图标 1 个；复制图标常态 `textMuted`，仅按压时 `accentSoft`。
- 不新增渐变、阴影、第二强调色；`tokens.dart` / `semantic.dart` / `theme.dart` 全局主题零改动。

## 3. 字号与字重（零新增）

| 级别 | size/line | weight | 用途 |
| --- | --- | --- | --- |
| `title` | 18/22 | 600 | AppBar、两个折叠区标题 |
| `body` | 13/19.5 | 600 | 状态结论、行标题、动作标题 |
| `body` | 13/19.5 | 400 | 说明、步骤文案、绑定值、URL |
| `label` | 10/13 | 500 +0.08em | 三段眉标、字段标签、步骤序号 |
| `micro` | 9/12 | 500 +0.12em | 状态副说明、行 meta、脚注 |
| `detail` | 12/17 | 400 | 输入错误（继承 `inputDecorationTheme.errorStyle`） |

所有值继承 [typography.dart](../../lib/src/design/typography.dart) 的 `FontFeature.tabularFigures()`；页面不写裸 `fontSize` / `fontFamily`。

## 4. 逐像素间距

| 位置 | 值 | token |
| --- | --- | --- |
| 页面左右 | 20（<390）/ 24（≥390） | `MileafLayout.pagePadding` |
| 页面顶 / 底 | 12 / 24 | `s12` / `s24` |
| 段与段 | 28 | `MileafSpace.section` |
| 眉标 → 首行 | 8 | `s8` |
| 状态 icon → 文字 | 12 | `s12` |
| 状态文字 → micro 副说明 | 4 | `s4` |
| 状态块 → Key 区 | 20 | `s20` |
| 字段标签 → 输入 | 8 | `s8` |
| 输入 → 保存按钮 | 12 | `s12` |
| 保存 → 取消更换 | 8 | `s8`（TextButton 左对齐、44 高，不再全宽居中） |
| Key 区 → 破坏行 | 12 | `s12` |
| 破坏行 → 下一段 | 28 | `section` |
| `MileafCopyRow` 上下 | 12 | `s12`，最小高 56 |
| `MileafCopyRow` label → value | 4 | `s4` |
| 值 → 右侧复制按钮 | 12 | `s12` |
| 行底分隔 | 1px | `colors.line` |
| 步骤序号列宽 / 序号→文案 / 行间 | 20 / 8 / 8 | `s20` / `s8` / `s8` |

折叠 tile 上下由 `ExpansionTile` 既有最小高承载；`childrenPadding` 沿用 [theme.dart:275](../../lib/src/design/theme.dart#L275) 的 `bottom: s8`；tile 上方不再叠加额外 28px。输入框内边距保持 16×12（[theme.dart:91](../../lib/src/design/theme.dart#L91)），不另设。

## 5. 圆角、描边、阴影、层级

- **零新增表面**：无底色容器、无 `BoxShadow`、无内容卡、无圆角分组框。
- 输入框 `MileafRadius.md = 12`；按钮 `MileafRadius.sm = 10`；dialog 继承 `dialogTheme` 的 12 圆角 + `MileafElevation.sheetLight/Dark`。
- 1px `colors.line` 只用于行分隔与 `MileafCopyRow` 底线；1px `lineStrong` 用于输入默认边；2px `focusRing` 仅 focus（唯一 2px accent 描边）。
- 层级：`canvas < 文本 < 1px 线 < 2px focus`；浅色下不叠 `surface` 白卡。

## 6. 组件状态矩阵

### 6.1 状态结论行（`_configuration` 顶部）

| 状态 | 视觉 | 行为 |
| --- | --- | --- |
| 默认 | 24px `mapPin` `accent` + `status` body/600 `text` + micro「保存在本机 · 所有车辆与站点共用」 | 只读 |
| 待重启 | 状态与短说明用 `warning`；一句「重新启动后生效 · 本次运行仍用原 Key」 | `restartRequired` 驱动 |
| 读取中 | `MileafProgressLine` 2px | 停用编辑 |
| 读取失败 | `error` 状态文字 + 「重试读取配置」 | `keys.restore()`，成功后恢复表单 |
| 保存 / 清除中 | busy 停用重复提交与返回 | `PopScope` 不变 |

`Semantics(liveRegion: true)` 保留在 status、notice、error 三处。

### 6.2 Key 配置

| 状态 | 结构 |
| --- | --- |
| 已保存 | 一条 `MileafDataRow`：`title = '${platformLabel} 地图 Key'`，`badge = 脱敏末四位`（body + `textMuted`），`showChevron: true`，`onTap` 进入编辑；最小高 56；press 用 `pressOverlay`；focus 2px `focusRing` |
| 编辑 / 未配置 | `TextField(InputDecoration.labelText = '${platformLabel} 地图 Key'`，`obscureText`，`显示/隐藏` TextButton ≥44 高）→ 唯一整宽 `FilledButton('保存 Key')` → 左对齐 `TextButton('取消更换')` |
| 校验失败 | `errorStyle` detail 12/17，最多 4 行，紧贴输入 |
| 保存失败 | 保留草稿与原配置，错误 liveRegion |

### 6.3 破坏操作行

`MileafDataRow(destructive: true)`：title 用 `colors.error` + 文字「清除已保存的 Key」，1px `line`，press `pressOverlay`；确认弹窗标题「清除地图 Key？」与按钮文案不变（[map_privacy_page.dart:72](../../lib/src/map/map_privacy_page.dart#L72)）。

### 6.4 新增 `MileafCopyRow`（`lib/src/design/components/copy_row.dart`）

| 参数 | 规格 |
| --- | --- |
| `label` | `type.label` / `textMuted` |
| `value` / `copyText` | `SelectableText(type.body)`；`copyText` 可不同于显示值（控制台链接显示短域名、复制完整 URL） |
| 复制按钮 | `MileafIconButton(MileafIconName.copy, tooltip: '复制$label')`，44×44，默认 `textMuted` / 按压 `accentSoft` / 2px focus |
| 底线 | 1px `colors.line`，透明底 |
| 状态 | 默认 / 按压 / 禁用（`enabled: false`）/ focus / 大字号堆叠 |
| 反馈 | `ScaffoldMessenger` SnackBar「$label已复制」，失败「复制失败，请重试或手动选择文字」（沿用 `_copy`） |

### 6.5 两个折叠区

| 状态 | 视觉 |
| --- | --- |
| 折叠 | 16px chevron `turns = 0.25` 下指、`textFaint`；tile 无边框、无阴影 |
| 展开 | `turns = 0.75` 上指；`AnimatedRotation` 180ms，reduce motion 静止 |
| 首次展开 | 才调用 `_readBinding()`（[map_privacy_page.dart:300](../../lib/src/map/map_privacy_page.dart#L300) 语义不变） |
| 绑定读取中 | `MileafProgressLine` 2px |
| 绑定读取失败 | `InlineBanner(tone: error, message: '安装包绑定信息读取失败', actionLabel: '重试读取绑定信息')` |
| 绑定成功 | 每个 `getBinding` 条目一条 `MileafCopyRow` |

### 6.6 地图隐私

- 授权状态行：`MileafDataRow('底图授权', meta: 当前已允许/未允许加载底图)`（只读，无 chevron）。
- 授权动作行：`MileafDataRow(granted ? '关闭底图' : '重新启用地图', showChevron: true)`；`showMapConsentSheet` / `consent.revoke` 调用与授权语义不变。
- 「数据使用说明」折叠区：IP/设备/网络说明、SDK 进程内存说明、`MileafCopyRow` 隐私政策链接（tooltip「复制隐私政策链接」）。

## 7. 文案表（精简，定位词保留）

| 现有文案（出处） | 新文案 | 层级 |
| --- | --- | --- |
| 「使用你自己的高德地图 Key 加载底图。配置保存在当前设备，所有车辆与站点共用。」（[map_privacy_page.dart:195](../../lib/src/map/map_privacy_page.dart#L195)） | 「保存在本机 · 所有车辆与站点共用」 | micro |
| 两条重启长句（[L201–204](../../lib/src/map/map_privacy_page.dart#L201-L204)） | 「重新启动后生效 · 本次运行仍用原 Key」 | body / `warning` |
| 三段连写步骤（[L309](../../lib/src/map/map_privacy_page.dart#L309)） | 三条独立 `_StepRow`，保留原义与平台名插值 | label 序号 + body |
| 「使用当前安装包的信息申请。重新签名或更换发行渠道后，请重新核对绑定信息。」 | 「按当前安装包信息申请；重签名或更换渠道后需重新核对」 | micro |
| 隐私两段长说明（[L372](../../lib/src/map/map_privacy_page.dart#L372)、[L394](../../lib/src/map/map_privacy_page.dart#L394)） | 首屏只留一行摘要，完整说明移入「数据使用说明」折叠 | body / `textMuted` |
| 「复制高德控制台链接」按钮 | 显示 `console.amap.com/dev/key/app`，复制完整 URL | `MileafCopyRow` |

**冻结的可见词**（测试与教程定位）：`如何申请 Key`、`保存 Key`、`取消更换`、`清除已保存的 Key`、`重新启用地图`、`关闭底图`、`重试读取配置`、`重试读取绑定信息`、`复制包名`、`复制签名 SHA-1`、`复制高德控制台链接`、`复制隐私政策链接`、`Android/iOS 地图 Key`。

**冻结的 tooltip 与 Semantics label**：`复制包名`、`复制签名 SHA-1`、`复制高德控制台链接`、`复制隐私政策链接`。测试统一用 `find.byTooltip(label)` 定位（[MileafIconButton](../../lib/src/design/components/icon_button.dart#L42) 同时提供 `Tooltip(message:)` 与 `Semantics(label:)`；仓库已有 `find.byTooltip` 用法见 [drives_test.dart:199](../../test/drives_test.dart#L199)）。

`MapKeyController.status`（[map_key.dart:46](../../lib/src/map/map_key.dart#L46)）与 [settings_page.dart:93](../../lib/src/settings_page.dart#L93) 的首页副文案**零改动**。

## 8. 图标与几何

新增 `MileafIconName.copy`，沿用 [icons.dart](../../lib/src/design/icons.dart) 的 24 网格、1.5 stroke、round cap/join：

- 后层圆角矩形 `(8.5, 8.5) → (17.5, 17.5)`，radius 2，先画；
- 前层圆角矩形 `(6.5, 6.5) → (15.5, 15.5)`，radius 2，后画；
- 只用 `MileafIconMetrics.inline(16)` / `nav(20)` / `header(24)` 三档；本页用 20。

`chevron` 仍用既有路径 `9.4/5.8 → 15.6/12 → 9.4/18.2`；`mapPin` 仍用既有路径。图标计数断言 15 → 16，其余 [design_tokens_test.dart](../../test/design_tokens_test.dart) 断言不变。

## 9. 响应式与断点

| 宽度 | 规则 |
| --- | --- |
| 320 / 360 | `pageInset = 20`，单列 |
| 390–559 | `pageInset = 24`，单列 |
| ≥600 | `MileafContent` 最大宽 560 居中，仍单列 |

- 大字号阈值 `MileafLayout.largeText`（约 150%）：`MileafCopyRow` 的 label/value 与 44×44 按钮堆叠（同 [data_row.dart:125](../../lib/src/design/components/data_row.dart#L125)）；步骤序号与文案保持同一行但允许文案多行；按钮文字不截断。
- 200% 字号：SHA-1 与 URL 自然换行，不横向滚动、不 `FittedBox`、不固定高度。
- 键盘 inset 300：「保存 Key」、错误文案与「取消更换」可滚动到达；`SingleChildScrollView` 不改为固定高度。

## 10. 动效

| 场景 | 规格 |
| --- | --- |
| 折叠 chevron | `AnimatedRotation`，`MileafLayout.motion(context, MileafDurations.enter)` = 180ms / `MileafCurves.enter`；reduce motion → `Duration.zero` |
| 页面路由 | 沿用 MaterialPageRoute |
| 按压 | 120ms `pressOverlay` / `accentSoft`（组件既有） |
| 状态变化 | `Semantics(liveRegion: true)`，无数字滚动 |
| 反馈 | SnackBar 沿用主题 |

不新增循环、视差、缩放、数字滚动或装饰性粒子。

## 11. 可达性

- 触控目标 ≥44×44；复制按钮 `byTooltip` + `Semantics(label:)` 双通道。
- 颜色不单独表意：`warning` / `error` 必带文字；破坏行同时有 `error` 色与「清除已保存的 Key」文字。
- 屏幕阅读器顺序 = 视觉顺序；三段眉标 `Semantics(header: true)`。
- focus 2px `focusRing`；浅深对比度沿用 [design_tokens_test.dart](../../test/design_tokens_test.dart)。
- `MileafDataRow.destructive` 不覆盖既有 `semanticLabel` 合成逻辑。

## 12. 文件落点：改了什么 / 为什么改

| 文件 / 组件 | 改动 | 理由 |
| --- | --- | --- |
| [map_privacy_page.dart](../../lib/src/map/map_privacy_page.dart) | 三段重排；持有两个折叠 bool 与 `AnimatedRotation` chevron；`MileafDataRow` 承载 Key 摘要 / 破坏行 / 授权行；`MileafCopyRow` 承载绑定值、控制台与隐私链接；删除 3 个整宽按钮与 5 个整宽文字按钮 | 本轮唯一业务呈现落点；`PopScope`、`_save/_clear/_readBinding/_copy`、`MapKeyController`、`MapConsentController` 契约不动 |
| [data_row.dart](../../lib/src/design/components/data_row.dart) | additive `bool destructive = false`；为 true 时 `title` 用 `colors.error` | 让破坏色留在组件内消费 token，页面不传裸色；既有调用方行为不变 |
| [icons.dart](../../lib/src/design/icons.dart) | additive `MileafIconName.copy` | 复制必须与既有图标同一网格、线宽、焦点态 |
| 新建 `copy_row.dart` + [components.dart](../../lib/src/design/components/components.dart) 导出 | 细线键值行 + 44×44 复制按钮，透明底 | 在零新增表面前提下承载可选择的技术值 |
| [design_tokens_test.dart](../../test/design_tokens_test.dart) | 图标计数 15 → 16 | 新增图标不引入新色值，计数断言需同步 |
| [map_key_page_test.dart](../../test/map_key_page_test.dart) | `find.text('复制包名')` → `find.byTooltip('复制包名')`；新增「已保存态无整宽『更换 Key』、清除为细线行、折叠默认收起」断言 | 覆盖重排后的可达性与语义 |
| [map_key_render_test.dart](../../test/map_key_render_test.dart) / [图册](../implementation/map-key-renders/README.md) | 浅深 × 6 态重生成，另补「隐私详情展开」态 | 正式 Flutter 渲染是本次视觉验收证据 |
| [设置教程](../tutorial/amap-key-settings.md) / [申请教程](../tutorial/amap-key-application.md) | 同步可见文案与「点击右侧复制按钮」「展开数据使用说明」等操作路径 | 逐字引用需保持一致 |
| [user-amap-key.md](user-amap-key.md) | 仅追加 §8 视觉增量指向本文；§1–§7 已冻结内容不改写 | 按已确认交付口径 |

**不改**：[map_key.dart](../../lib/src/map/map_key.dart)、[map_consent.dart](../../lib/src/map/map_consent.dart)、[map_panel.dart](../../lib/src/map/map_panel.dart)、[settings_page.dart](../../lib/src/settings_page.dart)、[tokens.dart](../../lib/src/design/tokens.dart)、[semantic.dart](../../lib/src/design/semantic.dart)、[theme.dart](../../lib/src/design/theme.dart)。

## 13. 验收矩阵

| 类别 | 标准 |
| --- | --- |
| 静态 | `tool/flutterw analyze --no-pub` 无诊断；`git diff --check` 通过；无裸 `Color(0x...)` / 裸 `fontSize` / 裸 `EdgeInsets` 视觉决策 |
| 单测 | `tool/flutterw test --no-pub test/map_key_page_test.dart` 先绿；`tool/flutterw test --no-pub` 全绿 |
| 渲染 | 浅色 / 深色 × 未配置、已保存、待重启、帮助展开、隐私展开、320 宽 200%、键盘 300；`takeException() == null`，无布局溢出与横向滚动 |
| 逐像素 | 4 / 8 / 12 / 20 / 28 / 56 / 44 / 1px / 2px 全部落在 `MileafSpace` 与 `MileafRadius` 既有档位 |
| 颜色 | R2 强调色对象 ≤2；`warning`/`error` 必带文字；对比度沿用既有断言 |
| 响应式 | 320 / 360 / 390 / ≥560 单列；200% 不裁切；键盘可达 |
| 流程 | 速写入口 → 设置页 → 保存 → 返回 → 地图创建；清除 → 速写；待重启提示；绑定延迟读取与复制；隐私授权开启 / 关闭 |
| 交付 | 双轴 `code-review`（Standards / Spec）+ 当前 `main` 本地提交，不推送 |

真机、真实 Key、真实底图、CRS、大陆网络与性能仍为独立外部 gate，不因本 Spec 通过而关闭。
