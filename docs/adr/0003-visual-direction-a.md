# 采用 A「夜航」作为行笺的视觉系统

- 日期：2026-11-01
- 状态：accepted（**配色与默认外观已被 [ADR 0006](0006-appearance-and-accent.md) 修订（2026-11-02）**：强调色由 P1 玉绿改为电光蓝、中性底去绿去暖、外观默认由深色改为跟随系统、浅色 hero 改为卡片形态。方向 A 的版面范式、字号阶梯、间距档位、圆角、动效、图标与图表几何继续有效；本文的 §2「明暗」、§3「配色」色值作历史记录。）
- 关系：取代 [ADR 0001](0001-visual-direction-c.md) 中 C「数据拼贴」的版面与视觉验收；保留 C 的数据语义、四 Tab、空/缺失/失败语义和外部待验边界。湖畔配色的“绿”保留，但深色基线、色阶、字体和品牌符号重做。

## 背景

C「数据拼贴」已于 2026-10-31 通过 C10。C 证明了“一页一个主角、结论先行、图表优先”的方向成立，但正式渲染暴露的是**工艺与系统**问题，不是数据或结构问题：

- 深色是 `ColorScheme.fromSeed` 补出来的；mint `#1E3B2C`、sand `#3B3120` 发浊，hero `#06140F` 与页面底 `#09140F` 几乎同色（[visual_theme.dart](../../lib/src/visual_theme.dart)、[collage.dart](../../lib/src/collage.dart)）。
- 没有 token 体系：9–48px 字号、8–22px 圆角、重复硬编码色散落在页面里；`collage.dart` 只抽象了 4 种表面。
- 可被截图放大的硬伤：[overview_page.dart:717](../../lib/src/overview_page.dart#L717) 输出“326880 分钟前”；`_monthBento()` 的 `stretch` 造成本月 tile 整块留白；费用“72（币种未知）”换行；AppBar 与页内两个刷新入口；tabular figures 只在少数数字上生效。

2026-11-01 用户要求重开方向评审，并确认：深色默认、浅色保留、允许重定品牌色、允许内置字体、概览首屏再减一层、浅色仍保留深色 hero、克制动效、重新设计品牌符号。

三套方向的实物评审见 [方向评审 v2](../product/direction-review-v2.md) 与[并排图](../prototypes/directions-v2/renders/compare-dark.png)。用户选择 **A「夜航」**，强调色 **P1 玉绿**，符号 **03 M 径**。

## 决策

### 1. 方向：A「夜航」取代 C 的彩色拼贴

以“深色车况主屏 + 纸面内容 + 细线列表”为唯一版面语言。**每页只允许一个深色锚点**：概览是车况 hero，充电是费用 hero，统计是主图带，行程/充电详情是地图或电池弧。其余内容不再用彩色卡片分组，改用留白、字号和 1px 细线。

保留 C 的“结论先行、证据随后、明细最后”，但**首页第一锚点从“本月”改为“车 now”**：先回答“车现在怎样”，再回答“这个月过得怎样”。C 的薄荷/沙色 tile、统一 18px 卡片圆角和 `stretch` 等高布局退役。

### 2. 明暗：深色默认，浅色等价

> **2026-11-02 修订**：本节「默认深色并持久化」已被 [ADR 0006](0006-appearance-and-accent.md) D1 取代——现行默认是**跟随系统**（顺序 跟随系统 / 浅色 / 深色，已存偏好优先）；「浅色底暖石 `#F1F0EB`」也已被 D3 的 `#F4F5F7` 取代。以下两条保留原文作为当时的决定记录。

- App 默认 `ThemeMode.dark`；设置中提供“深色 / 浅色 / 跟随系统”，默认深色并持久化。`main.dart` 不再只依赖系统亮度。
- 浅色不是反色：页面底色变暖石 `#F1F0EB`，但**车况 hero 仍保持深色**，使用独立的 `accent-hero`；这样浅色仍有一个深色锚点，而不是回到平铺。
- 深色 hero 只出现在“现在/主结果”位置；不把深色铺到整页，也不在统计页再放第二个深色 tile。

### 3. 配色：P1 玉绿，一套中性底 + 一个强调色

深色：

| 语义 | 值 | 用途 |
| --- | --- | --- |
| canvas | `#070908` | 页面底 |
| hero | `#050806` | 车况/费用主屏 |
| raised | `#0E120F` | sheet、浮层 |
| text | `#F2F5F0` | 主文本 |
| on-accent | `#071009` | 强调色上的文字 |
| muted | `#8C978E` | 次级文本 |
| faint | `#78837B` | 标签、单位 |
| line | `rgba(242,245,240,.09)` | 细线 |
| accent | `#74DDA8` | 主系列、状态、active |
| accent-hero | `#74DDA8` | 深色 hero 上的数据 |
| reference | `#D8B27C` | 参照/比较虚线 |
| warning | `#E0A45E` | 过期、覆盖不足 |
| error | `#D98C7A` | 失败，低饱和陶土色 |
| hero-muted | `#9FB9AA` | hero 次级文本 |
| hero-faint | `#6F8A7A` | hero 标签/单位 |

浅色：

| 语义 | 值 | 用途 |
| --- | --- | --- |
| canvas | `#F1F0EB` | 页面底 |
| surface | `#FAF9F5` | sheet、浮层 |
| text | `#121613` | 主文本 |
| muted | `#5F6A62` | 次级文本 |
| faint | `#646F67` | 标签、单位 |
| line | `rgba(18,22,19,.11)` | 细线 |
| accent | `#1C6B4F` | 主系列、active |
| on-accent | `#FAF9F5` | 强调色上的文字 |
| accent-hero | `#74DDA8` | 浅色页中的深色 hero |
| reference | `#8A5A1F` | 参照 |
| warning | `#7A4A12` | 过期、覆盖不足 |
| error | `#9E4E3D` | 失败，低饱和陶土色 |
| hero | `#081B14` | 浅色模式 hero 底 |

规则：

- 比较不靠红绿判断好坏；正向变化用 accent，参照用砂色虚线 + 标签，颜色不是唯一载体。
- 充电 AC/DC/未知只用“主色 + 主色降透明度 + 中性灰”，不引入第二强调色。
- 语义色（warning/error）只用于状态，不用于数据系列；数据系列最多“主色 + 参照砂 + 中性”。
- 所有文本对比度以 WCAG AA 为目标：正文 ≥ 4.5:1，大字号 ≥ 3:1；最终数值在 Spec 的对比度表中锁定。

### 4. 字体：Inter + 系统中文字体

- 内置 Inter（Latin + numerals；先落 400/500/600 三个静态字重，variable 只在双端验证通过后再合并），中文走系统 PingFang SC / Noto Sans CJK，fallback 明确。
- 五级字号：display、metric、title、body、label；粗体只用 400/500/600，不用 700 堆叠。
- 所有数字使用 tabular figures；单位比数字小 1–2 级、颜色降为 muted；大数字紧字距，正文正常字距。
- 不采用 C 的衬线中文，也不采用 B 的全等宽数字；理由是可读性、跨端一致性和包体成本。

### 5. 信息密度：首屏只留“一个结论 + 一个主图起点”

- 概览首屏：车况 hero（320 km / 68% / 今日摘要）→ 本月主数 + 同期变化 → 主图起点。净电耗/费用合并为一行辅助读数，移到主图之后；最近记录在首屏下半部。
- 统计首屏：结论大数 + 变化 + 主图；2×2 章节在下一层。
- 行程首屏：期间主数 + 节奏条带 + 第一条记录；充电首屏：费用 + 覆盖 + 主图。
- 详情首屏：地图（行程）或电池弧（充电）→ 三结果 → 过程曲线。
- 技术口径、完整采样、车辆资料留在“数据说明/更多”；主路径只保留“非实时、估算、已知费用、覆盖不足、进行中”短提示。

### 6. 表面、圆角、阴影

- hero/图版/内容区默认 0 圆角；chip 10px、输入 12px、sheet 20px、胶囊 999px。不再有“全站 18px 卡片”。
- 内容区不使用卡片阴影；只有 sheet/浮层允许一层阴影（`0 12px 40px rgba(0,0,0,.35)`）。深色 hero 用光晕而不用阴影。
- 1px 细线是主要分组手段；2px 只用于 focus/选中态。模糊只用于底部导航与地图浮层，不用于内容卡。

### 7. 图表语法

- 时间趋势用线/面积；**离散的每日补能用 stem（细竖线 + 端点），不能用连续折线跨过 0**。
- 柱图只用于需要零基线的比较；不做双轴、不做 3D、不做彩虹系列。
- 主图必须有：单位、范围、当前点、参照线/标签、点按读值；null 断开，不补零、不位移；孤立已知点可见。
- 当前值实色，参照虚线 + 文字；图例只在多系列时出现。
- 读数浮层用 raised surface + 12px 圆角，数值 tabular，时间与前后采样降级为小字。
- 图表不新增依赖；继续使用现有自绘 `data_chart.dart` 的能力边界，必要时抽出 `TimeSeriesChart`/`StemChart` 共享件。

### 8. 动效：克制、可关闭

- 页面进入 180ms 淡入 + 4px 上移；图表演绎 500ms；数值变化 220ms；按压 120ms。
- 不做视差、不做循环呼吸、不做装饰性粒子。
- 尊重 `MediaQuery.disableAnimations` / 系统 reduce motion：关闭位移与绘制动画，只保留 opacity。
- 触觉只在 tab 切换、图表选点、保存设置时使用轻反馈，不作为主要信息通道。

### 9. 品牌：03 M 径

- 符号：24×24 网格，1.5px 单色描边；M 由折线写成，右腿延伸为路线，终点是实心圆点。深色用 `#74DDA8`，浅色用 `#1C6B4F`；不允许渐变、阴影或第二色。
- 字标：中文「行笺」+ 拉丁描述 `MILEAF`；字距在 Spec 锁定。锁定图见 [chosen-brand.png](../prototypes/directions-v2/renders/chosen-brand.png)。
- App 内用 `BrandMark`（CustomPainter）绘制，避免为 SVG 引入新依赖；启动图标/商店素材另行生成。
- 顶栏：`BrandMark` + 行笺 + 车辆选择 + 设置；刷新只保留一个入口（下拉刷新 + 单个图标，二者不重复出现在同一屏）。

### 10. Token 分层

三层，页面只允许消费语义/组件 token：

1. **primitive**：原始色板、字号、字重、间距、圆角、时长、曲线；不含业务语义。
2. **semantic**：`canvas/hero/surface/text/muted/line/accent/reference/warning/error`、`display/metric/title/body/label`、`page/section/row/inline`、`hero/sheet/overlay`、`chart.stroke/grid/point/area`。
3. **component**：`MileafHero`、`MetricBlock`、`SectionHeader`、`DataRow`、`StatusChip`、`TimeSeriesChart`、`StemChart`、`StateView`、`SheetHeader`。

实现落点：

- `lib/src/design/tokens.dart`（primitive）
- `lib/src/design/semantic.dart`（ThemeExtension）
- `lib/src/design/theme.dart`（light/dark ThemeData）
- `lib/src/design/typography.dart`
- `lib/src/design/motion.dart`
- `lib/src/design/components/*`

现有 [visual_theme.dart](../../lib/src/visual_theme.dart) 与 [collage.dart](../../lib/src/collage.dart) 在新页面迁移完成后删除；页面文件不得再出现裸 `Color(0x...)`、裸 `fontSize`、裸 `EdgeInsets` 作为视觉决策。代码评审以“页面是否只消费 token/组件”为检查项。

### 11. 状态与可达性

- 正常、加载、空、部分缺失、过期、失败、进行中都是正式状态；缺失显示“—”，不补零；失败保留已有结果与重试入口。
- 200% 字号是验收矩阵的一等公民：hero 单列、四项读数 2×2、导航标签不截断、图表标签可降级但主数/单位/读值仍可见。
- 触控目标 ≥ 44×44；图表提供语义摘要；颜色不是唯一编码；浅/深两套都验证对比度。
- 页面不靠固定高度承载文本；只有图表/地图可有稳定高度，文本区必须能长高。

### 12. 范围

- 覆盖四主 Tab、两类详情、五个专题、连接/登录/设置；先做概览，再行程/充电，再统计/专题，最后接入与设置。
- 不新增 API、指标、车辆控制、多站点、Grafana 嵌入；数据口径与只读边界不变。
- C 的“数据说明/更多”层、空/缺失语义、四 Tab 和地图/电池弧能力保留；C 的彩色 tile 与统一卡片退役。

## 影响

- 正面：深色终于成为主设计；每页有唯一锚点；所有视觉决策可追溯到 token；数字与图表可读性提升；品牌符号可缩到 18px。
- 负面/成本：需要重写主题、页面布局、图表样式和大量 render test；C 的 68 张图册将被新矩阵取代；Inter 资源与中文 fallback 需要真机验证；浅色 hero 的对比度需要单独审计。
- 迁移顺序：tokens + shell → 概览 → 行程/充电列表 → 统计/专题 → 两类详情 → 连接/设置 → 浅深 × 100/200% 全矩阵。
- 外部 gate 不变：真机、真实站点、地图供应商/CRS/许可、性能、双端隔离构建仍单独验收；本文不把设计确认等同于这些通过。

## 考虑过的选项

- **C 夜读**：品牌最强，但中文衬线跨端不可靠、包体大、首屏车况降级；用户最终选择 A。保留其“大字/留白/账簿”的排版自信作为 A 的参考。
- **B 仪表**：精度最强，但 7–9px 微标签与等宽数字在 200% 下有重排风险，且最接近 Grafana 的仪表语言；不选。
- **保留 C 做精修**：能复用现有 68 张图册，但深色仍是补出来的，token 体系仍缺失；不满足本轮“消费级工艺”的目标。
- **A + C 混合**：考虑过用 A 的结构 + C 的衬线标题；因中文字体风险与两套语言冲突放弃。A 通过更大的结论字号和更少卡片吸收 C 的排版自信，但不使用衬线。

## 未决与后续

- Inter 的具体字重/可变字体文件、中文 fallback 的真机表现。
- M 径在 18px 的最终路径微调；启动图标/商店素材。
- 浅色 hero 的对比度实测；`accent-hero` 在浅色下的使用边界。
- 200% 下图表读数与章节卡的降级规则。
- 外观设置（深色/浅色/跟随系统）的存储与迁移。

这些在 Spec 与 Ticket 中锁定，不在 ADR 里替代验收。

## 证据

- 方向评审：[direction-review-v2.md](../product/direction-review-v2.md)
- 并排图：[compare-dark.png](../prototypes/directions-v2/renders/compare-dark.png)
- 三组强调色：[palettes.png](../prototypes/directions-v2/renders/palettes.png)
- 三个符号：[marks.png](../prototypes/directions-v2/renders/marks.png)
- 锁定标识：[chosen-brand.png](../prototypes/directions-v2/renders/chosen-brand.png)
- 当前 C 正式渲染：[collage-renders](../implementation/collage-renders/overview/overview-normal-light-100.png)
- 评审原型：[directions-v2](../prototypes/directions-v2/README.md)
