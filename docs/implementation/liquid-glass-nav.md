# 液态玻璃底栏实施记录

2026-11-16 在 `main` 工作区完成（基线 `5c7683f` 之上的本地改动，未推送）。决定见 [ADR 0013](../adr/0013-liquid-glass-navigation.md)，条款见[规格](../specs/liquid-glass-navigation.md)。

## 1 变更

| 文件 | 变更 |
| --- | --- |
| `lib/src/design/tokens.dart` | 新增玻璃色板（玻璃体、高光、弯月、受光边缘、内缘、镜片）、两组挖孔阴影、`glassBlur` 36 / `glassSaturation` 1.35 / 边缘笔宽 / 高光与弯月范围 / 内缘可达 / 投影余量与 sigma 换算 / `glassLensStretch` |
| `lib/src/design/semantic.dart` | 新增玻璃语义（按模式取中性叠色）、`GlassEdge` 值类型与 `glassEdge` / `glassLensEdge`、`navigationSelection`（实色镜片） |
| `lib/src/design/components/glass_surface.dart` | 新增：`MileafGlassSurface`、`MileafGlassLens`、`LiquidGlassPainter`（玻璃体 + 高光 + 弯月 + 双边缘）、`LiquidGlassShadowPainter`（挖孔投影）、`saturationMatrix` |
| `lib/src/design/components/navigation_material.dart` | 新增 `NavigationMaterialStyle`（`frosted` 默认 / `glass`）与 `resolvesSolid`；实色边线改画在 `foregroundDecoration`，不再把容器撑大 1px |
| `lib/src/design/components/nav_bar.dart` | 胶囊几何、玻璃材质、镜片改为第二层玻璃、180ms 位移 + `glassLensStretch` 回落（`_LensStretch`）、未选文字 `textMuted`、实色镜片用 `navigationSelection` |
| `lib/src/design/components/components.dart` | 导出 `glass_surface.dart` |
| `test/liquid_glass_nav_test.dart` | L01–L09 合同测试（含 768 宽封顶、实色同几何、挖孔阴影结构） |
| `test/liquid_glass_nav_render_test.dart` | 图证生成器：正式 App + 固定 HTTP 夹具，并在渲染像素上直接断言 L04，输出 `geometry.json` / `contrast.json` |
| `test/design_components_test.dart` | 未选导航标签的期望由 `textFaint` 改为 `textMuted`，并写明理由 |

顶栏、地图、页面内容、业务数据与路由未改动。`_NavItem` 的焦点环、`InkWell` 圆角与按压叠色沿用基线，不属于本次增量。

## 2 实测

由 `liquid_glass_nav_render_test.dart` 在同一次运行里量取：标签与图标的逻辑矩形换算到 DPR 2 像素，墨水取框内最暗（浅色）或最亮（深色）像素，背景取 90 / 12 分位，按 WCAG 求比并断言。原始值见 `docs/implementation/liquid-glass-nav-renders/contrast.json`。

| 机位 | 未选标签 | 选中标签 | 未选图标 | 选中图标 |
| --- | --- | --- | --- | --- |
| 浅色 · 首屏（蓝色图表透出） | 4.90–4.98 | 5.47 | 4.54–4.68 | 3.24 |
| 浅色 · 行程滚动（列表透出） | 5.52–5.69 | 5.32 | 5.43–5.57 | 3.40 |
| 深色 · 首屏 | 6.92–7.05 | 5.50 | 6.18–6.49 | 4.79 |
| 深色 · 行程滚动 | 6.11–7.87 | 7.60 | 5.64–7.44 | 7.44 |

下限：标签 4.5:1、图标 3:1，全部通过；最紧的一处是浅色首屏的选中图标（3.24，余量 8%）。

改动前的同一机位：未选标签在浅色蓝色透出时为 4.25–4.42（不足 4.5），这是把未选文字提升到 `textMuted` 的直接依据。

几何（`geometry.json`）：浮栏 358×64，left 16 / bottom 812，即外距 16、下距安全区 8；选中镜片 81.5×52，侧缩 4、上下缩 6，与实色路径完全一致。

## 3 设计迭代（保留判断过程）

1. **第一版是「白纱」。** 40%→60% 白叠色 + 18σ 模糊 + 1px 白边：在浅色页上几乎看不到边界，只剩一团白。修法不是加厚叠色，而是补上「边缘」与「弯曲」——受光顶边、下沿弯月、内缘暗线（浅色）三件套，形状才被读出来。
2. **阴影从玻璃里透出来。** `BoxShadow` 画在玻璃身下，薄玻璃把它透成栏内一条灰带，在栏的右下角形成一块「台面」。改为先 `clipPath` 挖掉自身形状再画阴影（`LiquidGlassShadowPainter`），镜片同样处理。
3. **实色路径的选中消失了。** 镜片原来取 `segmentSelected`，浅色等于 `surface`，与实色底栏同色——选中只剩蓝字，没有位置标记。新增 `navigationSelection`：浅色取分段轨道的中性档，深色取 `segmentSelectedDark`，并加一道细边。
4. **实色底栏比玻璃底栏大 1px。** 边线写在 `decoration` 里会被计入容器尺寸，实色路径因此高 65、镜片窄 0.2。改画在 `foregroundDecoration`，两条路径几何一致（L08）。
5. **过饱和从 1.8 降到 1.35。** 1.8 时品牌蓝的图表把整条栏染蓝，选中项的蓝失去信号性；1.35 保留内容走向，品牌色仍是栏上唯一的饱和色。
6. **镜片起步 1.06。** 只有位置移动会读成「滑块」；起步横向略宽再回落才读成「液体」。首帧不播、减动效归零。

## 4 图证

`docs/implementation/liquid-glass-nav-renders/`：`overview-*`（首屏，底栏压在每日里程图上）、`overview-scrolled-*`（正文经过栏下）、`drives-scrolled-*`（列表经过栏下）、`solid-*`（高对比实色回退）、`detail/`（底栏裁切特写）、`geometry.json`、`contrast.json`。

生成命令：

```
tool/flutterw test --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/liquid-glass-nav-renders \
  --dart-define='MILEAF_RENDER_FONT=/Library/Fonts/Arial Unicode.ttf' \
  test/liquid_glass_nav_render_test.dart
```

## 5 未验证

- 真机材质观感与滚动合成帧成本（#16 / #17）。
- iOS「减少透明度」与 Android「高对比」在设备上的真实映射；本地只用注入偏好覆盖了两条路径（#17）。
- 平台字体渲染差异：图证中文使用 Arial Unicode 回退，设备上是 PingFang / Noto。
- 旧图册（`docs/implementation/apple-design-renewal-renders/`）仍显示改版前的 28 圆角矩形底栏；本次未重生成，待该批基线提交后按同一入口重跑。

## 6 回滚

材质入口集中在 `lib/src/design/components/nav_bar.dart`：把 `NavigationMaterialStyle.glass` 改回 `frosted`、半径恢复 `BorderRadius.circular(MileafRadius.sheet)`，即回到焕新规格的磨砂矩形；`glass_surface.dart` 与其 token 可整体删除，无其他调用方。

## 7 2026-11-18 修订：再透一层

用户以截屏红框对照：「本 App 底部的 tab bar 再透明一点，透明到能够隐约看到 tab bar 后面的内容，再靠近 iOS 27 的液态玻璃一点……现在的设计还是差一点感觉，毛玻璃不像，液态玻璃也不像」。决定见 ADR 0013 §「2026-11-18 修订」，条款见规格 L03/L04/L10–L12。

### 7.1 变更

| 文件 | 变更 |
| --- | --- |
| `lib/src/design/tokens.dart` | 玻璃体叠色减半（浅 12%→20% 白、深 29%→45% 近黑）、顶部受光带与弯月下调并**接线**、新增 `glassLightLip`/`glassDarkLip` 与 `navigationLabelLight/Dark`、镜片受光带 `glassLensSheen`；`glassBlur` 36→22、`glassSaturation` 1.35→1.5、新增 `glassSheenCore`（16%）与 `glassLipReach`（8.5%）、`glassLensSheenReach`（50%） |
| `lib/src/design/semantic.dart` | 新增 `navigationLabel`（未选目的地）与 `glassLip`（端头增厚） |
| `lib/src/design/components/glass_surface.dart` | painter 新增 `sheenCore`/`lip`/`lipReach` 参数；受光边缘由左上→右下斜向渐变改为竖向着色；端头增厚画在填充之上、边缘之下；镜片接上自己的受光带 |
| `lib/src/design/components/nav_bar.dart` | 未选目的地图标与文字改用 `navigationLabel`；选中图形由 `accent` 改 `accentStrong`（两条合并为 `itemColor`） |
| `test/liquid_glass_nav_test.dart` | L03/L04 期望同步；新增 L10（透光率上限）、L11（受光带/弯月/端头接线）、L12（镜片是第二层玻璃、选中图形不弱于文字） |
| `test/design_components_test.dart` | 未选导航标签的期望由 `textMuted` 改为 `navigationLabel`，理由同步 |

顶栏（磨砂）、地图、页面内容、路由与几何未改。`MileafGlassLens` 是顶栏车辆胶囊与设置圆钮共用的那一层，受光带因此做成开关（`sheen`，默认关闭，只有底栏的选中镜片打开）：顶栏镜片的观感不变，`apple_polish_ap02_test` 新增「顶栏镜片不带底栏的受光带」钉住这条边界。

### 7.2 实测（同一次渲染运行，390×844 / DPR 2 / 100% / safe area 24）

由 `liquid_glass_nav_render_test.dart` 直接量取渲染像素并断言，原始值见 `docs/implementation/liquid-glass-nav-renders/contrast.json`。

| 机位 | 未选标签 | 选中标签 | 未选图标 | 选中图标 |
| --- | --- | --- | --- | --- |
| 浅色 · 首屏（蓝色图表透出） | 6.23–8.13 | 4.80 | 6.58–8.20 | 5.16 |
| 浅色 · 行程滚动（列表透出） | 5.66–9.59 | 8.76 | 5.75–9.75 | 8.70 |
| 深色 · 首屏 | 8.55–10.95 | 4.92 | 6.82–9.56 | 3.87 |
| 深色 · 行程滚动 | 7.05–12.90 | 12.46 | 6.04–12.17 | 11.18 |

下限：标签 4.5:1、图标 3:1，全部通过；最紧的两处是浅色首屏的选中标签（4.80，余量 7%）与深色首屏的选中图标（3.87，余量 29%）。数值随每次重采会有 ±0.05 的浮动（模糊采样），以 `contrast.json` 为准。

与首版同机位（4.90–7.87 / 5.32–7.60 / 4.54–7.44 / 3.24–7.44）相比：未选项因 `navigationLabel` 变实而上升到 5.66–10.95；选中项是**有升有降**——浅色首屏的选中标签从 5.47 掉到 4.80（余量从 22% 压到 7%，是本轮最紧的一处，来自「镜片透出蓝色图表 + 镜片同时被压薄」），浅色首屏的选中图标受 `accentStrong` 之助从 3.24 升到 5.16，深色两项基本持平。

口径说明：该渲染入口是 opt-in（要传 `MILEAF_RENDER_OUTPUT` 与 `MILEAF_RENDER_FONT`），全量测试里计作 skipped；墨水与背景各取对自己最有利的分位（浅色取最暗墨+90 分位背景，深色取最亮墨+12 分位背景），量到的是**上界估计**，不是最差情形。token 口径的检查（L04 前半）在标签带上叠「填充 + 弯月」，方向与像素口径一致。

### 7.3 迭代过程（保留判断）

1. **只改叠色不够。** 先把浅色叠色从 40%→56% 降到 12%→20%，渲染出来仍像「一层灰纱」：受光带与弯月其实从未画出来——painter 的默认值是 `sheenReach=0`、`meniscusStart=1`，两条带退化到不可见。补上接线后，胶囊才有「上亮下厚」的走向。
2. **斜向受光把光源放偏了。** 边缘原来用 `topLeft→bottomRight` 渐变，左侧总比右侧亮一档，读起来像「左上角有灯」。改成竖向着色后，顶边最亮、双侧等亮、底沿最暗，和实物玻璃一致。
3. **深色不能跟着浅色一起薄。** 深色首屏的选中标签（`azure300`）压在蓝色图表+镜片上，叠色从 29%→45% 才把合成压到 L≈0.05（4.92:1）；再薄 4pp 就掉到 4.24。规格 L10 因此给深色单独一档上限（52%）。
4. **未选文字必须换色。** `textMuted` 在薄玻璃+蓝色图表上按同一合成模型推算为 3.5–4.2:1（推算值：渲染入口只量当前 token，没有单独采一版 `textMuted` 的对照），低于文字下限。新增 `navigationLabel`（浅 #3A444E / 深 #C9D3DD）后回到 6.2/8.5 以上；同时发现选中图形用 `accent` 在亮镜片上只有 3.0:1（首版 3.24 的余量已耗尽），改为 `accentStrong`（5.16）。
5. **镜片在深色下要「更清」而不是「更白」。** 深色镜片从白 15%/10% 降到 8%/5%，把合成让给标签的蓝；作为补偿补上自己的受光带（白 10%），选中仍读得出来。
6. **模糊降到 22σ、过饱和升到 1.5。** 36σ 时栏内只剩平涂；22σ 仍读不出字，但块面的走向留下来；1.5 让透出来的品牌蓝仍是「颜色」而不是灰。1.8 会重新把整条栏染蓝，不采用。
7. **浅色的边线要收暗。** 白色边线在浅底上等于没有边界，下半圈改用石墨（侧 14% / 底 20%）+ 内缘 17%，胶囊轮廓才立得住；深色仍用白边（35% / 16% / 10%）。

一次失败的尝试记录在案：先按「深色也用 17%→30%」做过一版，深色首屏的选中标签掉到 4.24，被渲染断言挡下——这就是现在深浅不对称的来源。

### 7.4 图证与复跑

图证同上目录，2026-11-18 全部重采；`detail/` 仍是同一裁切（`(0, 1426, 780, 1688)`，DPR 2），只是内容更新。生成命令不变（见 §4）。`geometry.json` 未变：浮栏 358×64，left 16 / bottom 812；镜片 81.5×52 由 L02 的算式得出（358/4−8、64−12），`geometry.json` 只记录浮栏与材质两个矩形。

### 7.5 本次未做 / 未验证

- 顶栏车辆胶囊与设置圆钮用的是同一层 `MileafGlassLens`：受光带已做成开关，顶栏不打开（AP02 用例钉住），但顶栏图册（`apple-polish-*`、`apple-design-renewal-renders/`）里的**底栏本身**仍是 36σ / 40–56% 叠色的旧材质，未重采；真机观感仍在 #17。
- 端头增厚（石墨 6% / 白 10%，宽 8.5%）目前只有结构断言（L11）与图证，没有像素级判据，也没有人眼评估过「弯曲是否读得出来」。
- L10 是 token 求和模型，没有像素级的「背后内容透出量」量测；用户本轮的核心诉求只有图证（`detail/overview-light.png` 里蓝色柱的走向）支撑，没有数值断言。
- `LiquidGlassPainter` 的光学参数已到 13 个（3 条带 + 填充 + 边缘 + 笔宽）。双轴审查确认「再加深或再带宽一条带」要改 6 处，建议后续收成一个值类型（`GlassPaint` + `OpticalBand`，参照 `GlassEdge` 的既有写法）；本轮未重构，以免和视觉迭代交叉。
- 深色玻璃压在**明亮**内容（照片、地图底图）上时，选中项的蓝会低于 4.5:1：这是「高透」与「任意背景可读」的硬冲突，仍按 ADR 0013 的边界处理（地图 route 走实色），未作为本轮验收面。
- 原生 Liquid Glass 的折射/色散与系统材质联动仍在 ADR 0012 候选；本次只是在 Flutter 合成层里把「透、受光、端头厚度」做到位。
- 真机材质、减透明/高对比映射、滚动合成帧成本：沿 #11 / #16 / #17。

