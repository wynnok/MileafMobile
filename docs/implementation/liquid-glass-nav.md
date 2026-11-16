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
