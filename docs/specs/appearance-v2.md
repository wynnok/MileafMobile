# 外观 v2 设计规格（Spec）

- 日期：2026-11-02
- 状态：待确认（确认后产出 Ticket 并进入实施）
- 上游：[ADR 0006](../adr/0006-appearance-and-accent.md)（已 accepted）
- 替代范围：`docs/specs/visual-system-a.md` 的 §2（配色）、§4（hero 形态）、§9.8（外观设置）、§14 第 1 条验收。**其余章节（版面范式、字号阶梯、间距档位、圆角、动效、图标、图表几何、四 Tab 分工、状态语义）继续有效。**
- 不涉及：接口、数据语义、地图 provider、原生依赖、真机/外部待验 gate。

## 1. 三条可执行规则

| 规则 | 内容 | 判定方式 |
| --- | --- | --- |
| R1 中性底不染色 | 画布、表面、hero 一律中性色（HSL 饱和度 ≤ 8%），品牌色只以"信号"形式出现 | 取 token 值算 HSL 饱和度 |
| R2 颜色只做信号 | 强调色只允许出现在三类位置：**可点**（链接、按钮、选中项）、**当前**（指示条、当前点）、**数据**（图表系列）。同一屏最多 2 个强调色对象 | 截图点数 |
| R3 一个 tint 两种强度 | `accent` 供图形（≥3:1），`accentStrong` 供文字与实心填充（≥4.5:1）；深色两者合并 | 对比度测试 |

## 2. Token 结构

### 2.1 三层，不跳层

```
MileafPalette（primitive，只有 raw hex）
  → MileafColors（semantic，组件唯一可用的颜色入口）
    → ThemeData 扩展（theme.dart）与组件
```

页面**禁止**引用 `MileafPalette`；`theme.dart` 与 `components/*` 只可引用 `MileafColors`。这条在现有代码里已经成立（`lib/` 内除 `tokens.dart`/`semantic.dart` 外零 `Color(0x...)`），本次不放松。

### 2.2 primitive 命名

| 家族 | 用途 | 值 |
| --- | --- | --- |
| `azure300/500/600` | 强调色图形 / 文字与实心 / hero 图形 | `#64A8FF` / `#2688F5` / `#0B62C4` |
| `slate1000/950/900/850` | hero / canvas / surface / surfaceRaised（深色） | `#06090E` / `#0A0B0D` / `#12161C` / `#191E25` |
| `paper50/0` | canvas / surface（浅色） | `#F4F5F7` / `#FFFFFF` |
| `mist0/400/500/550/600` | 深色正文/muted/faint 与 hero 文本 | `#F2F4F7` / `#A7B4C2` / `#9AA5B1` / `#8A96A4` / `#7E8A96` |
| `graphite900/600/500` | 浅色正文/muted/faint | `#0E1319` / `#5A6672` / `#63707C` |
| `steel500/300` | 参照（浅 / 深） | `#5F6B78` / `#8E99A6` |
| `amber500/400` | warning（浅 / 深） | `#B45309` / `#FFB020` |
| `red600/400` | error（浅 / 深） | `#CE271B` / `#FF7A70` |

**删除**：`jade300/350/500/550/700/800/900`、`stone0/50/100/Raised/Soft`、`sand300/500/700`、`clay400/600`、`ink0/500/600/700/750/900`、`heroOnLight`。引用它们的断言（[design_tokens_test.dart:177-187](../../test/design_tokens_test.dart#L177-L187)、[:81](../../test/design_tokens_test.dart#L81)）同步改写。

### 2.3 semantic 层改动

| 动作 | token |
| --- | --- |
| 新增 | `accentStrong`（浅 `#0B62C4` / 深 `#64A8FF`，替换原 `accentText` 概念） |
| 改值 | `canvas`、`hero`、`surface`、`surfaceRaised`、`text`、`textMuted`、`textFaint`、`accent`、`accentSoft`、`accentHero`、`reference`、`warning`、`error`、`line`、`lineStrong`、`scrim`、`skeleton`、`sheetShadow`、`heroText`、`heroMuted`、`heroFaint` |
| 不变 | `isDark`、`pressOverlay` 的语义、`focusRing` 的语义（accent 60%）、`seriesPrimary/seriesSecondary/seriesNeutral` |
| 必须补进 `lerp` | `accentStrong`（否则主题切换时文字色不会过渡） |

## 3. 色板

### 3.1 深色

| 语义 | 值 | 对 canvas | 用途 |
| --- | --- | --- | --- |
| canvas | `#0A0B0D` | — | 页面底 |
| hero | `#06090E` | L\* 2.4（Δ0.6） | 车况/费用/主图带 |
| surface | `#12161C` | ΔL\* 4.1 | 通知条、输入框、sheet |
| surfaceRaised | `#191E25` | ΔL\* 8.1 | snackbar、tooltip |
| nav | `#0A0B0D` 88%（`0xE00A0B0D`） | — | 底部导航 |
| text | `#F2F4F7` | 17.87 | 正文与标题 |
| textMuted | `#9AA5B1` | 7.87 | 次级标签 |
| textFaint | `#7E8A96` | 5.59 | 辅助/单位/未选中 |
| accent | `#64A8FF` | 8.05 | 图形：线、点、指示条、图标、开关 |
| accentStrong | `#64A8FF` | 8.05 | 文字链接、选中标签、实心按钮底 |
| textOnAccent | `#0A0B0D` | 8.05（在 accent 上） | 实心按钮文字 |
| accentSoft | `#64A8FF` 16%（`0x2964A8FF`） | — | 选中 chip 底、按压高亮 |
| accentHero | `#64A8FF` | 8.06（在 hero 上） | hero 上的图形与光晕 |
| reference | `#8E99A6` | 6.80 | 参照/基线（虚线、对比系列） |
| warning | `#FFB020` | 10.77 | 过期、注意、进行中 |
| error | `#FF7A70` | 7.75 | 错误、校验 |
| heroText / heroMuted / heroFaint | `#F2F4F7` / `#A7B4C2` / `#8A96A4` | 18.10 / 9.45 / 6.63 | hero 内三级文字 |
| line / lineStrong | `#F2F4F7` 9%（`0x17F2F4F7`）/ 14%（`0x24F2F4F7`） | — | 分隔线、描边（装饰，不承载信息） |
| scrim | `#000000` 50% | — | sheet 遮罩 |
| skeleton | `#F2F4F7` 7% | — | 骨架 |
| pressOverlay | `#F2F4F7` 4% | — | 行按压 |

### 3.2 浅色

| 语义 | 值 | 对 canvas | 用途 |
| --- | --- | --- | --- |
| canvas | `#F4F5F7`（L\*96.5） | — | 页面底 |
| hero | `#070B11`（L\*2.9） | Δ93.6 | 车况/费用/主图带（卡片形态，见 §6） |
| surface | `#FFFFFF`（L\*100） | ΔL\* 3.5 | 通知条、输入框、sheet、导航 |
| surfaceRaised | `#FFFFFF` | — | snackbar、tooltip（靠 §5.2 阴影分层） |
| nav | `#FFFFFF` 92%（`0xEBFFFFFF`） | — | 底部导航 |
| text | `#0E1319` | 17.10 | 正文与标题 |
| textMuted | `#5A6672` | 5.38 | 次级标签 |
| textFaint | `#63707C` | 4.65 | 辅助/单位/未选中 |
| accent | `#2688F5` | 3.25（图形） | 图形：线、点、指示条、图标、开关 |
| accentStrong | `#0B62C4` | 5.41 | 文字链接、选中标签、实心按钮底 |
| textOnAccent | `#FFFFFF` | 5.90（在 accentStrong 上） | 实心按钮文字 |
| accentSoft | `#DCEBFD` | ΔL\* 4.1 | 选中 chip 底、按压高亮 |
| accentHero | `#64A8FF` | 8.06（在 hero 上） | hero 上的图形与光晕 |
| reference | `#5F6B78` | 4.99 | 参照/基线 |
| warning | `#B45309` | 4.60 | 过期、注意、进行中 |
| error | `#CE271B` | 4.90 | 错误、校验 |
| heroText / heroMuted / heroFaint | `#F2F4F7` / `#A7B4C2` / `#8A96A4` | 17.90 / 9.34 / 6.55 | hero 内三级文字 |
| line / lineStrong | `#0E1319` 10%（`0x1A0E1319`）/ 16%（`0x290E1319`） | — | 分隔线、描边 |
| scrim | `#0E1319` 35%（`0x590E1319`） | — | sheet 遮罩 |
| skeleton | `#0E1319` 6% | — | 骨架 |
| pressOverlay | `#0E1319` 6% | — | 行按压 |

在白色卡片上，浅色 `text / muted / faint / accentStrong / reference / warning / error` 分别为 18.65 / 5.87 / 5.07 / 5.90 / 5.44 / 5.02 / 5.34，全部 ≥4.5。深色在 `surface` 上分别为 16.47 / 7.25 / 5.15 / 7.42 / 6.27 / 9.92 / 7.15。

### 3.3 用哪一层：决策树

```
这个颜色是"文字/可读标签"吗？
├─ 是 → accentStrong（浅色 #0B62C4 / 深色 #64A8FF）
│        例：链接"全部指标"、chip 选中标签、导航标签、外观 sheet 选中行、snackbar action
└─ 否 → 它是"面积/线/点/图标/指示"吗？
   ├─ 是，且在 hero 深色底上 → accentHero
   ├─ 是，且需要压在 accentStrong 之上（实心按钮底） → accentStrong + textOnAccent
   └─ 是，其它 → accent
            例：折线、面积、当前点、电池弧、进度条、stem、开关轨道、导航 2px 指示条、品牌 Mark
```

已知的"文字类"调用点（实施时逐一改）：[chip.dart:43,50](../../lib/src/design/components/chip.dart#L43-L50)（选中标签与描边：标签 → `accentStrong`，描边 → `accentStrong`）、[nav_bar.dart:97,113](../../lib/src/design/components/nav_bar.dart#L97)（标签 → `accentStrong`，指示条 → `accent`）、[appearance_sheet.dart:128,139](../../lib/src/appearance_sheet.dart#L128)、[workspace_page.dart:389,408](../../lib/src/workspace_page.dart#L389)、[theme.dart:145,209,261](../../lib/src/design/theme.dart#L145)（snackbar action / TextButton / chip secondaryLabel）、[button.dart:60](../../lib/src/design/components/button.dart#L60)（ghost 文字）；`primary` 按钮底 [button.dart:49](../../lib/src/design/components/button.dart#L49) → `accentStrong`。

### 3.4 禁止

- 不用 `accent` 做整块背景或大面积填充（只允许 `accentSoft` 与 `accentStrong` 的实心按钮）。
- 不出现第二个强调色；`reference` 是中性，不视为强调色。
- 不用纯黑 `#000000` 做画布；不用纯白 `#FFFFFF` 做深色文字。
- 浅色下不用 `accent` 写文字（3.25:1 不达 AA）；深色下两者等价但仍按语义选 token。
- 不新增渐变（唯一例外：hero 的径向光晕，见 §6.3）。
- 不用颜色单独表意：`warning`/`error` 必伴随文字或图标。

## 4. 排版（继承，不改）

| 级别 | 字号/行高/字重 | 用途 |
| --- | --- | --- |
| display | 60 / 60 / w600 / -0.04 | hero 主数（390 宽 64） |
| metricLg | 44 / 44 / w600 / -0.035 | 页面主数 |
| metricMd | 24 / 26 / w600 / -0.03 | hero 三读数 |
| title | 18 / 22 / w600 / -0.01 | 区块标题 |
| body | 13 / 19.5 / w400 | 正文 |
| label | 10 / 13 / w500 / +0.08 | 标签、chip |
| micro | 9 / 12 / w400 / +0.12 | 口径、时间 |
| detail | 12 / 17 / w400 | 技术表值 |

- 字体 Inter + 系统中文 fallback；所有级别 `tnum` 不变。
- **只改颜色**：`textMuted` 在浅色从 4.94 提到 5.38，`textFaint` 从 4.59 提到 4.65；深色 muted 6.59→7.87、faint 5.07→5.59。不调整任何字号、字重、行高、tracking。
- hero 内三级文字仍用 `heroText / heroMuted / heroFaint`，不再用 `text.withValues(alpha:)` 临时混色。

## 5. 间距 / 圆角 / 阴影

### 5.1 新增两个几何 token

| token | 值 | 用途 |
| --- | --- | --- |
| `MileafSpace.cardInset` | 12 | hero 卡片的左右外边距（所有宽度一致） |
| `MileafSpace.cardPad` | 16 | 卡片内横向 padding（固定，不随 `pageInset` 变化） |
| `MileafRadius.lg` | 20（复用） | hero 卡片圆角 |

卡片形态下内容距屏幕边 = 12 + 16 = 28，卡片留白 12；**不沿用 `pageInset`**，否则 390 宽下卡片内留白会从 12 变成 20，卡片看起来"变胖"且内容整体右移。

间距档位（4/8/12/16/20/24/28/32/40/56）、`pageInset`（20/24）、触控 44、导航 64、内容底 84、chip 34、图表 140/148 全部不变。

### 5.2 阴影：仍只有两级，浅色改中性

| 级别 | 深色 | 浅色 | 用途 |
| --- | --- | --- | --- |
| sheet | `rgba(0,0,0,.35) 0 12 40`（不变） | `rgba(14,19,25,.10) 0 12 40`（原 `rgba(20,22,20,.14)`，去绿调、降一档） | 底部 sheet、对话框 |
| toast | `rgba(0,0,0,.25) 0 6 20`（不变） | 同 | snackbar |
| 内容区 | 无阴影 | 无阴影 | 卡片分层只靠底色阶差与 `line` |

### 5.3 层级顺序

`canvas < surface < surfaceRaised < sheet（+遮罩+阴影）`。hero 不属于该序列：它是"内容"，不是"面"。

## 6. hero 规格

### 6.1 形态判定（唯一判据）

```
Δ L*(hero, canvas) > 20  →  卡片形态（card）
Δ L*(hero, canvas) ≤ 20  →  满幅形态（full-bleed）
```

当前取值：深色 0.6 → full-bleed；浅色 93.6 → card。形态由 `MileafColors` 推导，不由调用方逐个指定，避免同一页面两种形态。

### 6.2 满幅形态（深色）

- 无圆角、无外边距、贴屏幕左右与顶部；`SystemUiOverlayStyle.light`。
- 径向光晕：右上角圆心 `(w×1.02, -h×0.15)`，半径 ≈ `w×0.95`，`accentHero` 峰值 18%，二次衰减到 0。
- 顶部 inset：`MediaQuery.paddingOf.top + heroTop(16)`。
- 底部 padding：`heroBottom(18)`。

### 6.3 卡片形态（浅色）

- 外框：左右 `cardInset(12)`，上下各 12（概览在 top bar 之下 12；其它页与相邻区块 12）。
- 圆角 `lg(20)`，四角一致；**无描边、无阴影**（深色卡片自带体量，不需要边）。
- 光晕同上（`accentHero` 18%），因卡片变窄，峰值保持不变、半径按卡片宽度计算。
- **不再声明 `SystemUiOverlayStyle`**：状态栏上方是纸面，前景由页面按 canvas 亮度决定（浅色 → 深色图标）。这是 [hero.dart:52-56](../../lib/src/design/components/hero.dart#L52-L56) 必须改的一处。
- 内部横向 padding 固定 `cardPad(16)`，纵向 20；内容距屏幕边 28，卡片留白 12（所有宽度一致）。
- 该横向 padding 由新增的 `MileafLayout.heroInset(context)` 统一给出（卡片形态 → `cardPad`，满幅 → `pageInset`）；7 处 hero 调用点把 `MileafLayout.pageInset(context)` 换成它，不各自判断形态。

### 6.4 顶部归属

| 模式 | 概览 top bar | 其它 Tab |
| --- | --- | --- |
| 深色（满幅） | 在 hero 内（`onHero: true`），hero 吞掉头部 | 在纸面 |
| 浅色（卡片） | 在纸面，`includeTopInset: true`；hero 不再加顶部 inset | 在纸面 |

`overview_page.dart` 的 `_topInset()` 只在满幅形态返回状态栏高度，否则返回 0。

### 6.5 内容与尺寸

| 场景 | 规则 |
| --- | --- |
| 360 宽卡片 | 内容宽 360−12×2−16×2 = 304（满幅时为 320）；display 60 |
| 390 宽卡片 | 内容宽 390−12×2−16×2 = 334（满幅时为 342）；display 64 |
| 320 宽卡片 | 内容宽 320−12×2−16×2 = 264（满幅时为 280）；display 56，三读数允许 2×2 |
| 高度 | 自适应内容，不设固定高；卡片内不出现 `Spacer`/`Expanded` 拉高 |
| 200% 字号 | 外边距 12 不变；沿用既有 large-text 分支（先数字、后电池弧、三读数 2×2）；卡片高度随内容增长，不允许内部横向溢出 |

## 7. 组件状态矩阵

所有组件保持现有交互与语义，**只换颜色映射**。

### 7.1 StatusChip

| 状态 | 底 | 描边 | 文字 |
| --- | --- | --- | --- |
| 未选 | 透明 | `line` | `textMuted` |
| 选中 | `accentSoft` | `accentStrong` | `accentStrong` |
| 未选（onHero） | `heroText` 4% | `heroText` 16% | `heroMuted` |
| 选中（onHero） | `heroText` 12% | `accentHero` | `heroText` |
| 禁用 | 透明 | `line` | `textFaint` 38% |
| 焦点 | 同上 + 2px `focusRing` | | |

### 7.2 按钮

| 类型 | 常态 | 按压 | 焦点 | 禁用 | loading |
| --- | --- | --- | --- | --- | --- |
| primary | 底 `accentStrong` / 字 `textOnAccent` | 高亮 `accentSoft` | 2px `focusRing` | 底 `line` / 字 `textFaint` | 保留标签 + 16px 指示器（`textOnAccent`） |
| secondary | 透明 / 字 `text` / 描边 `lineStrong` | 高亮 `pressOverlay` | 2px `focusRing` | 字 `textFaint` | 同上 |
| ghost / 文本按钮 | 透明 / 字 `accentStrong` | 高亮 `accentSoft` | 2px `focusRing` | 字 `textFaint` | — |

### 7.3 底部导航

| 状态 | 图标 | 标签 | 指示条 |
| --- | --- | --- | --- |
| 选中 | `accent` | `accentStrong` | `accent`，18×2 |
| 未选 | `textFaint` | `textFaint` | 无 |

导航条底色 `nav`，顶部 1px `line`；不加深色/浅色特殊处理。

### 7.4 外观设置 sheet

| 项 | 文字 | 勾选图标 | 高亮 |
| --- | --- | --- | --- |
| 选中 | `accentStrong` + w600 | `accent` | — |
| 未选 | `text` | — | `accentSoft`（InkWell） |
| 顺序 | 跟随系统 / 浅色 / 深色（固定，默认项置顶） | | |

说明文案：「默认跟随系统。切换后立即生效，并保存在本机。」

### 7.5 图表读数与 tooltip

| 元素 | token |
| --- | --- |
| 读数主值 | `text` + tabular |
| 读数单位/日期 | `textFaint` |
| tooltip 底/边 | `surfaceRaised` / `line` |
| hero 内读数 | `heroText` / `heroFaint` |

### 7.6 空 / 缺失 / 加载 / 错误

| 状态 | 规则（继承，仅换色） |
| --- | --- |
| 加载 | 骨架用 `skeleton`，1.2s 呼吸；不开新动画 |
| 空 | 标题 `text`，说明 `textMuted`，单一 ghost 按钮（`accentStrong`） |
| 缺失（null） | 图表断线 + `textFaint` 的 `—`，不用 0 代替 |
| 错误 | 文案 `error`，图标 `error`，重试按钮 ghost |

## 8. 图表

| 元素 | 深色 | 浅色 |
| --- | --- | --- |
| 系列主色 | `accent` | `accent` |
| 系列次色 | `accent` 50% | `accent` 50% |
| 中性/未知 | `textFaint` | `textFaint` |
| 参照虚线 | `reference`，`[4,4]` | 同 |
| 网格/坐标基线 | `line` | `line` |
| 轴标签 | `textFaint` 9px | 同 |
| 当前点 | `accent` 实心 4 + 8 光晕 | 同 |
| 面积渐变 | `accent` 16% → 0 | 同 |
| hero 内系列 | `accentHero` | 同 |
| hero 内网格 | `heroText` 12% | 同 |

线的粗细、面积透明度、柱宽、stem、y 轴 3 刻度等几何全部沿用 `MileafChartMetrics`，本次不改。

## 9. 响应式

| 宽度 | 卡片 hero | 其它 |
| --- | --- | --- |
| 320–359 | 外边距 12，内边距 16，display 56 | 不变 |
| 360–389 | 外边距 12，内边距 16，display 60 | 不变 |
| 390–559 | 外边距 12，内边距 16，display 64 | 图表 +8 |
| ≥560 | 内容限宽 560，卡片在限宽内左右各 12，内边距 16 | 不变 |
| 大字号（≥150%） | 外边距不变；三读数 2×2；hero 内不裁剪、不省略 | 不变 |

## 10. 无障碍

- 全部文本对 ≥4.5:1、全部图形对 ≥3:1（见 §3 与 ADR §3 的实测表）。
- 焦点环仍是唯一的 2px 强调色描边（`focusRing` = accent 60%）。
- 触控目标 ≥44；chip 34 视觉 + 44 触控保持不变。
- 状态不靠颜色单一通道：`warning`/`error` 必伴随文字；比较方向用 ↑↓ + 文字，不用红绿。
- reduce motion 行为不变（图表静态、骨架停止）。
- 语义标签、语序、朗读内容不变；本次不改任何 `Semantics`。

## 11. 动效

| 场景 | 时长 | 说明 |
| --- | --- | --- |
| 主题切换 | 200ms（`MaterialApp.themeAnimationDuration`） | 颜色经 `MileafColors.lerp` 过渡，需补 `accentStrong` |
| hero 卡片出现 | **无**进入动画 | 卡片是静态材质，不加缩放/淡入 |
| 其余 | 沿用 120/160/180/220/240/500 | 不变 |

## 12. 落地文件清单

| 文件 | 改什么 |
| --- | --- |
| [tokens.dart](../../lib/src/design/tokens.dart) | 整块 palette 替换为 §2.2；`ELEVATION.sheetLight` 改中性；新增 `MileafSpace.cardInset` 与 `MileafSpace.cardPad` |
| [semantic.dart](../../lib/src/design/semantic.dart) | 两张构造全量改值；新增 `accentStrong`；`lerp`/`copyWith` 补齐 |
| [theme.dart](../../lib/src/design/theme.dart) | `ColorScheme.primary` → `accent`、`onPrimary` → `textOnAccent`、`primaryContainer` → `accentSoft`；TextButton/FilledButton/chip/snackbar/floatingLabel 走 `accentStrong`；`scaffoldBackgroundColor` 跟随 canvas |
| [hero.dart](../../lib/src/design/components/hero.dart) | 增加卡片形态（外边距/圆角/光晕按宽度）、卡片形态下不覆盖系统栏 |
| [layout.dart](../../lib/src/design/layout.dart) | 新增 `heroInset(context)`：卡片 → `cardPad`，满幅 → `pageInset` |
| [overview_page.dart](../../lib/src/overview_page.dart) | `onHero` 按形态取值；`_topInset()` 按形态归零 |
| [workspace_page.dart](../../lib/src/workspace_page.dart) | `topBar(onHero: …)` 依据形态；通知条底色随 `surface` |
| [appearance.dart](../../lib/src/appearance.dart) | 默认 `system`；`restore()` 回退 system |
| [appearance_sheet.dart](../../lib/src/appearance_sheet.dart) | 文案、选项顺序、选中态颜色 |
| 其余组件（chip/button/nav_bar/battery_arc/charts/…） | 只改 `accent` → `accentStrong` 的文字类用法 |
| [design_tokens_test.dart](../../test/design_tokens_test.dart) | 对比度与明度阶断言按 §3 重写 |
| [appearance_shell_test.dart](../../test/appearance_shell_test.dart) | 默认 system、system 解析、已存偏好优先 |
| `visual-system-a.md` | §2.4 表、§4 hero、§9.8、§14 第 1 条 |

## 13. 验收清单

- [ ] 首启（无保存值）为跟随系统；系统深色 → 深色、系统浅色 → 浅色；已存偏好优先。
- [ ] 冷启动无"先深后浅"闪色。
- [ ] 外观 sheet 顺序为 跟随系统 / 浅色 / 深色，文案为「默认跟随系统…」。
- [ ] 浅色 hero 为 12 外边距 + 20 圆角卡片；深色 hero 仍满幅；同一页面不混用两种形态。
- [ ] 浅色概览的 top bar 在纸面，状态栏图标为深色且清晰；深色概览的 top bar 在 hero 内、图标为浅色。
- [ ] 浅色画布 `#F4F5F7`、卡片 `#FFFFFF`；浅色截图里不再出现暖米底与土黄线条。
- [ ] 所有强调色文字用 `accentStrong`；浅色下不存在 3.25:1 的蓝色文字。
- [ ] 对比度测试全绿：文本 ≥4.5、图形 ≥3.0、明度阶满足 §3.3（ADR）。
- [ ] 7 处 hero 调用在浅色下均为卡片，无横向溢出（含 320 宽与 200%）。
- [ ] 主题切换有 200ms 颜色过渡，`accentStrong` 也参与过渡。
- [ ] 图表系列、参照、当前点、hero 内图表在两种模式下都可读。
- [ ] `lib/` 内除 tokens/semantic 外仍零 `Color(0x...)`。
- [ ] 四主 Tab + 两类详情 × 浅/深 × 100/200% 正式 Flutter 渲染全部重出并归档。
