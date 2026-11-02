# 行笺视觉系统 Spec v1：A「夜航」

- 日期：2026-11-01
- 状态：accepted（2026-11-01 用户确认）
- 关系：实现 [ADR 0003](../adr/0003-visual-direction-a.md)；取代 C「数据拼贴」的版面与视觉规范；数据口径、API、只读边界和外部待验范围不变。
- 交付对象：Flutter 实现、设计评审、render test 与代码评审。
- 证据：方向评审 [direction-review-v2.md](../product/direction-review-v2.md)、[并排图](../prototypes/directions-v2/renders/compare-dark.png)、[锁定标识](../prototypes/directions-v2/renders/chosen-brand.png)。

## 0. 一句话

深色只出现在每页一个“现在/主结果”位置；其余内容退成近黑纸面，用留白、字号和 1px 细线分组；所有数字 tabular，所有视觉值来自 token。

## 1. 设计原则

1. **一个深色锚点**：概览是车况 hero，充电是费用 hero，统计是主图带，详情是地图/电池弧。同一屏不得出现第二个深色块。
2. **结论先行**：先给结果和变化，再给趋势，最后给记录与口径。首屏不解释采样方式。
3. **图表优先于表格，趋势优先于原始值**：表格只用于地点账目、技术明细和记录列表。
4. **留白是结构**：不用“再加一张卡”分组；用 28px 段间距、1px 细线和字号差。
5. **数字是主角**：数字大、单位小、标签更小；所有数字等宽对齐；没有单位的数字不算完成。
6. **状态必须被设计**：正常、加载、空、部分缺失、过期、失败、进行中都有明确视觉，不靠临时文案。

## 2. 颜色

### 2.1 primitive

只允许在 `tokens.dart` 出现原始色值；页面禁止裸 `Color(0x...)`。

| ramp | 值 | 用途 |
| --- | --- | --- |
| jade.300 | `#74DDA8` | 深色主强调、hero 数据 |
| jade.500 | `#1C6B4F` | 浅色主强调 |
| jade.700 | `#0C3326` | 深色 hero 渐变端 |
| jade.900 | `#050806` | 深色 hero 底 |
| canvas.dark | `#070908` | 深色页面底 |
| stone.0 | `#FAF9F5` | 浅色 sheet/浮层 |
| stone.50 | `#F1F0EB` | 浅色页面底 |
| stone.100 | `#E9E7E0` | 浅色骨架/分区 |
| ink.0 | `#F2F5F0` | 深色主文本 |
| ink.500 | `#8C978E` | 深色次级文本 |
| ink.600 | `#78837B` | 深色标签/单位 |
| ink.700 | `#5F6A62` | 浅色次级文本 |
| ink.750 | `#646F67` | 浅色标签/单位 |
| ink.900 | `#121613` | 浅色主文本 |
| sand.300 | `#D8B27C` | 深色参照/比较 |
| sand.500 | `#8A5A1F` | 浅色参照/比较 |
| sand.700 | `#7A4A12` | 浅色警告/过期 |
| amber.400 | `#E0A45E` | 深色警告/过期 |
| clay.400 | `#D98C7A` | 深色错误 |
| clay.600 | `#9E4E3D` | 浅色错误 |

### 2.2 semantic（深色）

| token | 值 | 用途 |
| --- | --- | --- |
| canvas | `#070908` | 页面底 |
| hero | `#050806` | 车况/费用主屏 |
| surface | `#0E120F` | 浮层、输入、sheet |
| surfaceRaised | `#131814` | tooltip、菜单 |
| text | `#F2F5F0` | 主文本 |
| textMuted | `#8C978E` | 次级文本 |
| textFaint | `#78837B` | 标签、单位、脚注 |
| textOnAccent | `#071009` | 强调色上的文字 |
| accent | `#74DDA8` | 主系列、active、正向变化 |
| accentPressed | `#5BC792` | 按压态 |
| accentSoft | `rgba(116,221,168,.12)` | 选中底、按钮按压 |
| reference | `#D8B27C` | 参照数据、比较虚线 |
| warning | `#E0A45E` | 过期、覆盖不足 |
| error | `#D98C7A` | 失败、不可用 |
| line | `rgba(242,245,240,.09)` | 细线 |
| lineStrong | `rgba(242,245,240,.14)` | 输入框、选中边界 |
| heroText | `#F2F5F0` | hero 主文本 |
| heroMuted | `#9FB9AA` | hero 次级文本 |
| heroFaint | `#6F8A7A` | hero 标签/单位 |
| nav | `rgba(8,11,9,.90)` | 底部导航 |
| scrim | `rgba(0,0,0,.50)` | 遮罩 |
| skeleton | `rgba(242,245,240,.07)` | 骨架 |

### 2.3 semantic（浅色）

| token | 值 | 用途 |
| --- | --- | --- |
| canvas | `#F1F0EB` | 页面底 |
| surface | `#FAF9F5` | 浮层、sheet |
| surfaceRaised | `#FFFFFF` | tooltip、菜单 |
| text | `#121613` | 主文本 |
| textMuted | `#5F6A62` | 次级文本 |
| textFaint | `#646F67` | 标签、单位、脚注 |
| textOnAccent | `#FAF9F5` | 强调色上的文字 |
| accent | `#1C6B4F` | 主系列、active |
| accentPressed | `#14503B` | 按压态 |
| accentSoft | `#DCEBE2` | 选中底 |
| reference | `#8A5A1F` | 参照数据、比较虚线 |
| warning | `#7A4A12` | 过期、覆盖不足 |
| error | `#9E4E3D` | 失败、不可用 |
| line | `rgba(18,22,19,.11)` | 细线 |
| lineStrong | `rgba(18,22,19,.18)` | 输入框、选中边界 |
| hero | `#081B14` | 浅色模式下的深色 hero |
| heroText | `#F2F5F0` | hero 主文本 |
| heroMuted | `#9FB9AA` | hero 次级文本 |
| heroFaint | `#6F8A7A` | hero 标签/单位 |
| nav | `rgba(250,249,245,.94)` | 底部导航 |
| scrim | `rgba(18,22,19,.35)` | 遮罩 |
| skeleton | `rgba(18,22,19,.06)` | 骨架 |

### 2.4 对比度

实测（WCAG 2.1）：

| 组合 | 对比度 | 结论 |
| --- | --- | --- |
| 深色 text / canvas | 18.16 | AA/AAA |
| 深色 muted / canvas | 6.59 | AA |
| 深色 faint / canvas | 5.07 | AA |
| 深色 accent / canvas | 12.03 | AA |
| 深色 reference / canvas | 10.06 | AA |
| 深色 warning / canvas | 9.17 | AA |
| 深色 error / canvas | 7.59 | AA |
| textOnAccent / accent | 11.64 | AA |
| 浅色 text / canvas | 16.00 | AA/AAA |
| 浅色 muted / canvas | 4.94 | AA |
| 浅色 faint / canvas | 4.59 | AA |
| 浅色 accent / canvas | 5.64 | AA |
| 浅色 reference / canvas | 5.17 | AA |
| 浅色 warning / canvas | 6.54 | AA |
| 浅色 error / canvas | 5.10 | AA |
| 浅色 textOnAccent / accent | 6.10 | AA |
| heroText / hero（浅色 hero） | 16.22 | AA/AAA |
| heroMuted / hero | 8.49–9.57 | AA |
| heroFaint / hero | 5.36 | AA |

规则：

- 低于 4.5:1 的颜色只能用于非文本装饰（1px 线、面积填充、禁用态），不得承载信息。
- 比较不靠红绿判断好坏；正向用 accent，参照用砂色虚线 + 文字。
- 充电 AC/DC/未知：主色、主色 50% 透明、中性灰；不新增第二强调色。
- 状态色只用于状态，不用于数据系列。

## 3. 字体

### 3.1 字体资产

- 内置 **Inter**：`Inter-Regular.ttf`（400）、`Inter-Medium.ttf`（500）、`Inter-SemiBold.ttf`（600）；OFL 许可随包。
- 中文：系统 `PingFang SC`（iOS）/ `Noto Sans CJK SC`（Android）；`fontFamilyFallback` 明确。
- 不使用中文衬线、全等宽正文或第二套展示字体。
- `pubspec.yaml`：

```yaml
flutter:
  fonts:
    - family: Inter
      fonts:
        - asset: assets/fonts/Inter-Regular.ttf
          weight: 400
        - asset: assets/fonts/Inter-Medium.ttf
          weight: 500
        - asset: assets/fonts/Inter-SemiBold.ttf
          weight: 600
```

### 3.2 字号/字重

| token | size/line | weight | tracking | 用途 |
| --- | --- | --- | --- | --- |
| display | 60/60 | 500 | -0.04em | hero 续航；统计总里程 |
| metric-lg | 44/44 | 500 | -0.035em | 本月里程、已知费用 |
| metric-md | 24/26 | 500 | -0.03em | 章节主数、结果读数 |
| title | 18/22 | 600 | -0.01em | 页面标题、区块标题 |
| body | 13/19.5 | 400 | 0 | 默认正文 |
| label | 10/13 | 500 | 0.08em | 单位、导航、元数据 |
| micro | 9/12 | 500 | 0.12em | 图表刻度、脚注 |

- 五级 family：display / metric / title / body / label；`metric-md` 与 `micro` 是尺寸变体，不是新层级。
- 大数字紧字距；正文 0；全大写只用于拉丁 micro 标签，中文不转大写。
- 数字一律 `FontFeature.tabularFigures()`；金额、百分比、里程、时长、温度都走同一 helper。
- 单位比数字小 1–2 级，颜色 `textFaint`/`heroFaint`；单位不换行到数字上一行。
- 中文行高 1.5；数字行高 1.0–1.1。
- 大字号下不人为缩小到不可读；用换行/堆叠解决宽度（见 §10）。

### 3.3 数字排版

- 主数 + 单位用 `Text.rich`，数字一个 `TextSpan`，单位一个 `TextSpan`；不要用字符串拼接后整体同字号。
- 千位分隔：`groupedText`（现有 `number_format.dart`）保留；不足 1000 不补 `.0`。
- 负数用 `−`（U+2212），不要 hyphen；正负变化用 `↑/↓` + 数值 + 参照文字。
- 未知用 `—`；真实 0 显示 `0`，不显示 `—`。
- 金额未知不写“（币种未知）”；有币种时 `¥72` + `币种未记录` 的 `label`，无币种时只显示 `72` + `币种未记录`；不默认 CNY、不补汇率。
- 相对时间：<1 分钟“刚刚”；<60 分钟“N 分钟前”；<24 小时“N 小时前”；≥24 小时“10/25”；禁止“326880 分钟前”。

## 4. 间距与栅格

- 4px 基准；只允许 `4/8/12/16/20/24/32/40/56`。
- 页面左右：320–359 用 20；360–389 用 20；≥390 用 24；≥600 内容最大 560 居中。
- 段间距：28；段内：16–20；行间距：12–14；行内：6/8/10。
- 列表行最小高度 56；可点区域 ≥44；底部导航 64，内容底部留 84。
- hero：左右 20；上 16；下 18；车况主数到状态行 14；hero 到下一段 28。
- 图表：高度 104–160；图头到绘图区 8；绘图区到读数 6。
- 不使用 6px/10px 等不在 token 内的值。

## 5. 圆角、描边、阴影、层级

| token | 值 | 用途 |
| --- | --- | --- |
| radius.none | 0 | hero、图版、内容区 |
| radius.xs | 4 | 条形图端点、微标签 |
| radius.sm | 10 | 按钮、地图浮层 |
| radius.md | 12 | 输入框、tooltip |
| radius.lg | 20 | bottom sheet |
| radius.full | 999 | chip、胶囊、筛选 |

- 描边：1px `line`；输入/选中 1px `lineStrong`；focus 2px accent 60%。
- 阴影：内容区无阴影；sheet `0 12 40 rgba(0,0,0,.35)`（浅色 `rgba(20,22,20,.14)`）；toast `0 6 20 rgba(0,0,0,.25)`。只有这两级。
- 模糊：只用于底部导航（backdrop blur 18）和地图浮层（blur 8）；内容不 blur。
- 深色 hero 用径向光晕，不用阴影；光晕只允许一个，位于 hero 右上，透明度 ≤20%。

## 6. 图标与品牌

### 6.1 图标

- 24×24 网格，1.5px 描边，round cap/join；尺寸 16（行内）/20（导航）/24（页头）。
- 关键图标用自绘 `MileafIcon`（CustomPainter），不新增 SVG 依赖：home、car、bolt、chart、route、map-pin、battery、clock、settings、chevron、refresh、wallet、info、close、check。
- 非关键图标允许 Material Outlined 兜底，但线宽/尺寸必须落在同一视觉重量。
- 填充只用于状态点、选中标记；导航 active 用 accent + 2px 顶部标记，不用实心图标。

### 6.2 品牌

- 符号：03 M 径；24 网格，1.5px 单色，M 折线 + 右腿路线 + 实心终点；终点圆点直径 2.7（在 24 网格内）。
- 深色 `#74DDA8`，浅色 `#1C6B4F`；单色，无渐变/阴影/第二色。
- 字标：`行笺` 14–15px，字距 0.3em；`MILEAF` 7px，字距 0.24em；与符号间距 8–10。
- App 内 `BrandMark` CustomPainter；启动图标/商店素材不在本 Spec 范围。
- 最小尺寸：18px；18px 下终点圆点不得消失（用实心，不用描边圆）。
- 顶栏：`BrandMark` 19 + 行笺 + 车辆选择 + 设置；不再用 `Icons.spa_outlined`。

## 7. 组件与状态

### 7.1 Hero

结构：可选顶部光晕 + appbar/状态行 + 主数 + 电池弧/地图 + 底部 3 列读数。

| 状态 | 视觉 |
| --- | --- |
| 正常 | hero 底、heroText；状态点 accent；数据完整 |
| 充电中 | accent 状态点 + “充电中 · 11.0 kW”；不脉冲 |
| 休眠/离线 | muted 状态点 + 状态文字；不改变 hero 层级 |
| 过期 | warning 状态点 + “非实时 · 数据截至 18:40”；主数仍显示 |
| 加载 | hero 骨架（3 块），不做旋转 loading |
| 错误 | 保留最后数据 + 行内错误条 + 重试；无数据时用空态 |

### 7.2 Section header

- 标题 `title`；右侧范围/单位用 `label` + `textFaint`；可选 text button（全部/看当天）。
- 不使用下划线装饰；下方 8–10px 才接内容。
- 200% 时标题与右侧动作分两行，动作不截断。

### 7.3 Metric block

- 结构：label（10）→ value（24/44）+ unit（10）→ note（9）。
- delta：箭头 + 数值 + “较参照”分开；不把“好/坏”写进颜色。
- 未知：value 显示 `—`，note 保留解释；不补 0。
- 200%：label 与 value 上下排列；value 不缩到 24 以下。

### 7.4 Data row（细线列表）

- 高度 ≥56；左侧可选 28–30px 圆线图标；标题 body/title；meta label；右侧 value metric-md + unit。
- 1px `line` 分隔；首行可有 top line，末行有 bottom line；不使用卡片。
- 状态：默认 / 按压（surface 4%）/ 选中（accentSoft）/ 禁用（faint 38%）/ focus（2px accent）。
- 可导航行才加 chevron；不可导航行不加。

### 7.5 Chip / Period

- 高 34，radius full，1px line，label 10；默认 textMuted。
- 选中：accentSoft 底 + accent 文本 + accent 1px 边。
- 按压：accentSoft 70%；禁用：faint；focus：2px accent 60%。
- 200% 自动换行，不横向滚动。

### 7.6 Button / Icon button

| 类型 | Default | Pressed | Disabled | Loading |
| --- | --- | --- | --- | --- |
| Primary | accent 底 / onAccent 文 | accentPressed | line 底 / faint 文 | 16px spinner + 文 |
| Secondary | 透明 / 1px line / text | surface | faint | 同上 |
| Ghost | 透明 / accent 文 | accentSoft | faint | 同上 |
| Icon | 44×44 / 20 icon / muted | accentSoft 圆底 | faint | 17px spinner |

- 最小 44×44；圆角 10；无阴影；focus 2px accent 60%。
- 主按钮一屏最多一个；多数场景用 text button / row。

### 7.7 Bottom navigation

- 高 64；4 项；图标 20，label 9；背景 nav + blur 18 + 1px top line。
- Active：accent + 2px 顶部标记（宽 18，居中）；Inactive：faint。
- 按压：accentSoft 20%；不缩放。
- 详情页隐藏导航；返回用页头 44 图标。

### 7.8 Sheet / Tooltip

- Sheet：顶部 radius 20，scrim，handle 36×4，标题 18，关闭 44，SafeArea 底部。
- Tooltip：surfaceRaised，radius 12，1px line，padding 10/12，标 11、值 11 tabular；最大宽 220；不遮住当前点。
- 图表 tooltip 不出现长口径；口径进“数据说明/更多”。

### 7.9 空、加载、错误、过期

| 状态 | 规则 |
| --- | --- |
| 空 | 24 线图标 + 16 标题 + 12 说明 + 可选 text action；居中 40px 留白；不画全零图 |
| 加载 | 骨架块 1.2s opacity 0.5–1 循环；reduce motion 静态；页面级 2px 进度条 |
| 错误 | 有缓存：行内 banner + 重试，保留数据；无缓存：整页空态 + 重试；不弹 toast |
| 部分缺失 | 缺失项 `—`；不补零；图 null 断线；note 说明覆盖 |
| 过期 | warning 点 + “非实时 · 数据截至 …”；不 modal |
| 进行中 | accent 点 + “进行中”；结束时替换为结果，不保留动画 |

### 7.10 表格（仅详情/地点/技术）

- 行高 40–44；左 label 10 muted，右 value 12 tabular；1px line。
- 不交替底色；不使用竖线；数字右对齐。
- 200% 时 label/value 两行，不截断。

## 8. 图表

### 8.1 通用

- 主色 accent；参照 reference 虚线；未知中性；不引入第二强调色。
- 单位、范围、当前值、参照标签必须有；图例只在多系列出现。
- null 断线，不补零、不位移；孤立已知点画点。
- 零基线 1px line；柱图必须从 0 起；不做双轴、3D、彩虹。
- 点按目标 ≥44；选点有 4px 点 + 8px halo；读数浮层见 §7.8。
- 语义摘要：`Semantics(label: '10月1日至26日每日里程，当前10月26日60公里')`。

### 8.2 类型

| 类型 | 规格 | 用途 |
| --- | --- | --- |
| 折线/面积 | 线 1.5；面积 0.16→0；圆角连接；当前点 4 + halo 8 | 每日里程、速度、功率、长期续航 |
| Stem | 竖线 1.5；非当前 35%；当前 100%；端点 2.5 | 每日补能（离散量） |
| 微折线 | 线 1.2；面积 0.12；无轴无标签；高 28–32 | 章节、月块 |
| 柱 | 零基线；宽 ≤60% 槽；radius 1；非当前 30% | 仅需要离散比较时 |
| 电池弧 | 88px；2.5 stroke；track 10%；round cap；中心 22/9 | 车况/充电 SOC |
| 地图 | 路线 1.8 + halo 9/18%；起终点 3.5 + halo 8；只标起点 | 行程/充电详情 |
| 日历热图 | 单元格 8–10；radius 2；缺失留空 | 节奏专题 |

### 8.3 轴与标签

- X 轴只显示首/中/末三个标签，9px faint；Y 轴最多 3 个刻度。
- 网格只在需要读数时出现（1px line，透明度 60%）；A 的主图优先无网格。
- 图表内允许一句短标注（如“参照 55.4”），长口径进说明层。
- 200% 时隐藏 Y 轴刻度与部分 X 标签，保留当前读数和单位。

## 9. 页面规格

### 9.1 概览

首屏顺序（360×800）：

1. 深色 hero：品牌/车辆/设置；状态行；`320 km` display + 电池弧 68%；今日 60.0 km / 3 次 / 11.25 kWh。
2. 本月：kicker + `1,198.6 km` metric-lg + `↑ 8.2% 较上月同期`；不放净电耗/费用块。
3. 主图：每日里程折线 + 参照虚线 + 当前点 + 读数 + “点按读值”；主图后接一行辅助读数（净电耗 · 已知费用 · 覆盖）。
4. 最近：最近行程/充电两行。
5. 继续：节奏/能耗/长期三行。
6. 数据说明与更多（折叠）。

规则：

- 删除 `_monthBento()` 的 `stretch` 等高；本月块不再与右侧辅助块强制同高。
- 净电耗与费用合并为一条 `辅助读数` 行（净电耗 158 Wh/km · 已知费用 ¥186.4 · 8/9 次），位于主图之后；不显示空块。
- 费用未知：有币种时 `¥72` + `币种未记录`，无币种时 `72` + `币种未记录`；不换行括号、不默认 CNY。
- 状态“N 分钟前”按 §3.3 人性化；≥24h 显示日期。
- 刷新：AppBar 只保留品牌/车辆/设置，去掉刷新；页面内唯一刷新在区间行右侧；下拉刷新保留；车辆刷新移入车辆 sheet。
- 空：hero 保留骨架/空态，主图显示“还没有采样点”，不画全零；缺失 `—`。
- 200%：hero 单列（续航在上、弧在下），今日 3 项 2×2，最近行两行。

### 9.2 统计

首屏：

1. 页头：统计 · 十月 + 本月选择。
2. 结论：`1,198.6` display + `↑ 91.3 km · +8.2%`。
3. 深色主图带：折线 + 参照虚线 + 读数。
4. 一条洞察 + 依据。
5. 2×2 章节：节奏/能耗/补能/长期；无彩色卡片。
6. 全部指标。

规则：

- 章节不再用 CollageTile；用 1px 细线分隔的 2 列区块；数字 metric-md。
- 章节与里程读数统一由 `MetricGrid` 承载（2 列、间距 16；文字 ≥150% 时自动单列），数值用 `MetricBlock`/`MileafNumber`，页面不再手写 `Wrap` + `SizedBox(width:)`。
- 里程章节（总里程 / 本月里程 / 日均）走同一 `MetricGrid`：总值 `metric-lg`，说明 `label`；空态 `—`，不补 0。
- 章节 spark 用微折线（能耗/补能），节奏用 26 个活动点/细条；长期在 range observations 未加载时不画 spark。
- “长期”主数：已加载 range observations 时显示最新值/P50；未加载时显示 `—` + “进专题”，不得为了填数新增请求或硬编码 316（原型中的 316 是合成样例）。
- 200%：章节单列；主图 Y 轴隐藏；读数保留。

### 9.3 行程

首屏：

1. 页头：行程 · 近 30 天 + 日期。
2. 期间主数 1,280.6 km + 52 趟 + 197.47 kWh + 154 Wh/km。
3. 出行节奏（26 条，当前日高亮）+ 首末标签。
4. 最近的路：首条 featured，其余行；加载更多。
5. 详情入口。

规则：

- 记录以起终点为主标题、距离为主数；时间/时长/净电耗为 meta。
- 首条可 featured（字号 +1 级、值 21），其余安静。
- 日期筛选保留；C 的“看当天”保留为 text action。
- 空：期间 0/— + “这段时间还没有行程”；不画全零节奏。
- 200%：期间数堆叠；节奏条保持 26 条但标签只留首末；记录行两行。

### 9.4 行程详情

首屏：

1. 地图 hero 300–356（失败用路线速写 + “地图暂不可用”）。
2. 覆盖说明带：日期/最近行程、起终点、距离 + 时长。
3. 三结果：时长/净电耗/能量。
4. 速度过程图（无当前 0 标签）。
5. 电量区间（68–76 段，不画成 0–76 进度）。
6. 技术 rows / 脚注。

规则：

- 地图说明带在地图内时用底部渐变；无地图时说明带落在地图下方，不遮挡结果。
- 电量区间用 0–100 轨 + 68–76 段；标签“出发 76% / 到达 68%”（2026-11-01 用户裁定按行程顺序“出发”在前，覆盖本节旧句的“到达 / 出发”）。
- 速度图当前点不标 0；峰值/平均放图脚。
- 200%：地图高度 240；说明带下移；三结果 2×2。

### 9.5 充电

首屏：

1. 深色费用 hero：`¥186.4` display + 8/9 覆盖条 + 0.87 ¥/kWh。
2. 三读数：234.7 kWh / 9 次 / 5h10。
3. 每日补能 stem 图（0 值留空，不连线）。
4. 构成：AC/DC 已知分类构成环 + 图例 + 三列绝对量；DC 占已知 44.9%，未知单列（2026-11-01 起以 [ADR 0004](../adr/0004-charging-method-visual.md) 为准，取代此前的分段条）。
5. 地点账目 + 最近一次。

规则：

- 费用未知：有币种时 `¥72`，无币种时 `72`；都带 `币种未记录`。覆盖 2/8 时 bar 25%；不把未知计入均价。
- 地点不排名、不写“最划算”；显示次数/能量/已知费用/覆盖。
- 空：费用 `—` + “还没有充电记录”；不画全零图。
- 200%：三读数 2×2；构成标签换行。

### 9.6 充电详情

首屏：SOC 电池弧（18→82）→ 充入/费用/时长三结果 → 功率曲线 → 能量/温度/相数 → 口径。

- 电池弧是主视觉；功率曲线在结果后；技术信息最后。
- 失败：保留结果与文字，地图/曲线用空态。
- 200%：弧 72；三结果 2×2；曲线标签隐藏。

### 9.7 专题（节奏/能耗/补能/长期/停放）

- 结构固定：结论一句 + 主数 + 主图 + 3–5 条证据 + 数据说明。
- 一个主图；不堆同权卡片；不出现五个等权 tab。
- 200% 单列。

### 9.8 连接 / 登录 / 设置

- 用同一 token；表单输入 radius 12，label 10，错误 12 + error 色；主按钮一屏一个。
- 设置行用 DataRow；外观设置：深色/浅色/跟随系统，默认深色。
- 启动/登录页可以有品牌 Mark + 字标，但不使用 hero 光晕堆叠。

## 10. 响应式与 200%

### 10.1 宽度

| 宽度 | 规则 |
| --- | --- |
| 320–359 | 左右 20；hero display 56；三读数允许 2×2 |
| 360–389 | 主设计基准；左右 20 |
| 390–599 | 左右 24；hero display 64；图表高度 +8 |
| ≥600 | 内容最大 560 居中；不做多列桌面布局；sheet 最大 520 |

### 10.2 字号

- 断点：`MediaQuery.textScalerOf(context).scale(14) >= 21`（约 150%）为 large text。
- large text：
  - hero 纵向堆叠；续航与弧不并排。
  - 今日 3 项 → 2×2。
  - 章节 2×2 → 单列。
  - 记录行 title/meta/value 分行。
  - 底部导航 label 仍显示，不截断。
- 200%：
  - 主数允许换行/单位下移；不得用固定高度裁切。
  - 图表隐藏 Y 轴与部分 X 标签；保留当前读数。
  - 不横向滚动；不使用 `FittedBox` 把文字缩回原大小。
- 所有页面必须通过 360×800 × 100/200% × 浅/深 × normal/empty/missing 的 render matrix。

## 11. 动效

| 场景 | 时长 | 曲线 | 说明 |
| --- | --- | --- | --- |
| 页面进入 | 180ms | easeOutCubic | opacity 0→1 + translateY 4→0 |
| 图表绘制 | 500ms | easeOutCubic | 线从左到右；reduce motion 直接显示 |
| 数值变化 | 220ms | easeOut | 数字/条形过渡；不滚动数字 |
| 按压 | 120ms | easeOut | 颜色/透明度，不缩放 |
| sheet | 240ms | easeOutCubic | 底部上移 + scrim |
| tab 切换 | 160ms | easeInOut | 内容淡入；不做滑动分页 |

- 不做视差、循环呼吸、粒子、数字滚动轮。
- `MediaQuery.disableAnimations` 或系统 reduce motion：关闭位移/绘制，仅保留 opacity。
- 触觉：tab/图表选点/保存设置轻反馈；不作为信息通道。

## 12. 可达性

- 触控目标 ≥44×44；相邻目标间距 ≥8。
- 图表有语义摘要；每个可点数据点有 label。
- 颜色不是唯一编码：比较用虚线 + 文本；状态用点 + 文本；充电类型用文字。
- 动态字号 200% 不裁切、不横向滚动；主数/单位/操作仍可达。
- 屏幕阅读器顺序 = 视觉顺序；hero 先读“额定续航 320 公里，电量 68%，充电中”。
- 对比度按 §2.4；新颜色必须过同一张表。
- 减少动态效果；不自动播放视频/动画。

## 13. 代码落点与迁移

### 13.1 新增

| 文件 | 内容 |
| --- | --- |
| `lib/src/design/tokens.dart` | primitive 色、字号、间距、圆角、时长 |
| `lib/src/design/semantic.dart` | `MileafColors` ThemeExtension |
| `lib/src/design/theme.dart` | light/dark ThemeData、组件主题 |
| `lib/src/design/typography.dart` | TextTheme / 数字样式 |
| `lib/src/design/motion.dart` | durations/curves |
| `lib/src/design/icons.dart` | `MileafIcon` CustomPainter |
| `lib/src/design/brand_mark.dart` | M 径 CustomPainter |
| `lib/src/design/components/*` | Hero、Section、Metric（`MetricBlock`/`MileafNumber`/**`MetricGrid`**）、DataRow、Chip、`ChipRow`、Button、Nav、Sheet、StateView、Chart、BatteryArc、SocIntervalBar、MapFrame、`MileafCompositionBar`、`MileafCategoryBars` |

### 13.2 修改

| 文件 | 改动 |
| --- | --- |
| `lib/main.dart` | 默认 `ThemeMode.dark`；外观设置；系统栏颜色 |
| `lib/src/workspace_page.dart` | AppBar 只留品牌/车辆/设置，去掉刷新；页内单一刷新；nav token 化 |
| `lib/src/overview_page.dart` | hero/本月/主图/最近/继续重排；删 `_monthBento` stretch；时间人性化；费用未知拆分；辅助读数合并 |
| `lib/src/drives_page.dart` | 期间主数、节奏、最近的路；删除卡片与日期分组标题 |
| `lib/src/charging_page.dart` | 费用 hero、覆盖、stem、构成、地点 |
| `lib/src/statistics_page.dart` | 结论 + 深色主图 + 2×2 章节（`MetricGrid`）；四张图的采样选择由 `_Sampling` 统一；AC/DC 构成条用 `MileafCategoryBars`（分段构成条 `MileafCompositionBar` 由概览/补能专题共用；账本页 2026-11-01 起改用构成环，见 ADR 0004）；长期主数按已加载数据处理，不新增请求 |
| `lib/src/drive_detail_page.dart` | 地图 hero、三结果、速度、电量区间 |
| `lib/src/charging_detail.dart` | 电池弧、结果、功率曲线 |
| `lib/src/statistics_*_page.dart` | 五个专题统一结论 + 主图 + 证据 |
| `lib/src/data_chart.dart` | 消费 token；新增 stem；tooltip/读数统一样式 |
| `lib/src/period_chips.dart` | chip token/状态 |
| `lib/src/connection_page.dart` / `session_pages.dart` / `setup_page.dart` | 表单/按钮/状态 token 化 |
| `lib/src/number_format.dart` | 保留 grouped；新增相对时间/币种说明 helper |
| `pubspec.yaml` | Inter 三字重 asset |

### 13.3 删除/退役

- `lib/src/visual_theme.dart`：被 `design/theme.dart` 取代。
- `lib/src/collage.dart`：`CollageTile`/`CollageBento`/`Sparkline` 退役；微趋势由 `MicroSpark` 组件承接。
- `lib/src/data_cards.dart` 中只服务 A/C 旧版面的卡片组件：迁移完成后删除；仍有数据语义的保留。
- 页面中所有 `Color(0x...)`、裸 `fontSize`、裸 `EdgeInsets`、裸 `BorderRadius` 作为视觉决策的写法。

### 13.4 测试与图册

- `test/design_tokens_test.dart`：语义色对比度、字号/间距 token 完整性。
- `test/design_components_test.dart`：按钮/chip/row/state/chart 的状态矩阵。
- 现有 `test/*_render_test.dart` 更新 token 与新布局；`test/c_gallery_render_test.dart` 改为新图册。
- 新图册矩阵：四主 Tab + 两类详情 + 五专题 × 浅/深 × 100/200% × normal/empty/missing；每个页面至少 1 张首屏。
- 不把浏览器原型图当作 Flutter 渲染证据；真机/真实站点/地图/性能仍是外部 gate。

## 14. 验收清单

- [ ] 深色默认；设置可切浅色/跟随系统；浅色仍保留深色 hero。
- [ ] 每页最多一个深色锚点；没有彩色 tile 网格。
- [ ] 页面文件无裸色/裸字号/裸圆角；全部走 token。
- [ ] Inter 三字重随包；中文 fallback 在双端可读；所有数字 tabular。
- [ ] 概览首屏 = hero + 本月主数 + 主图起点；净电耗/费用合并为辅助读数。
- [ ] 状态时间人性化；费用未知不再括号换行；不再出现“N 万分钟前”。
- [ ] AppBar 与页内不重复刷新；车辆刷新在车辆 sheet。
- [ ] 离散补能用 stem；null 断线；真实 0 保留；比较不靠红绿；长期未加载时显示 `—`，不伪造 316。
- [ ] 所有组件有 default/pressed/selected/disabled/loading/error/focus 定义。
- [ ] 空/加载/错误/过期/缺失/进行中均有实际渲染。
- [ ] 360×800 × 浅/深 × 100/200% × normal/empty/missing 全部无横向溢出；主数/单位/操作可见。
- [ ] 对比度按 §2.4；触控 ≥44；图表有语义；reduce motion 生效。
- [ ] M 径在 18px 可辨；字标/图标锁定；没有渐变/阴影/第二色。
- [ ] 现有 API/数据口径不变；未新增请求；未改外部仓库。

## 15. 未决

- Inter 静态字重的最终文件（子集化/许可证）与 Android 字体回退实测。
- M 径 18px 的路径微调；启动图标/商店素材。
- 浅色 hero 与 `accent-hero` 在 200% 下的对比度实测。
- 外观设置的存储/迁移；是否提供“始终深色车况”开关（当前不做）。
- 200% 下图表读数与章节的最终降级阈值。
- 地图底图/CRS/许可仍按外部 gate 验收，不由本 Spec 通过。

## 16. 变更记录

- 2026-11-01：首版；基于 ADR 0003、方向 A、P1 玉绿、03 M 径；对比度修正浅色 muted/faint。
