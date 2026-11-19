# MC05 按钮图标纪律与浮层玻璃

- 日期 2026-11-19，票 MC05；条款 CL14、CL30、CL30.1、CL31、CL31.1（ADR 0016 D4/D6）。
- 持有文件：`lib/src/design/components/button.dart`、`pull_down.dart`、`lib/src/map/map_panel.dart`；新建 `test/chromatic_material_test.dart`。
- 未改：底栏（ADR 0013 冻结）、顶栏、字号阶梯、版面结构、文案、数据口径；`design/components/{glass_surface,nav_bar}.dart` 只读参考。

## 做了什么

1. **CL14 按钮图标纪律**（`button.dart`）
   - `MileafControlMetrics.buttonIconGap = MileafSpace.s8` 与 `iconLeading(icon, color)`：主/次/文字按钮共用同一个图标槽，「图标在左、间距 s8、交叉轴居中」从隐式实现变成常量 + 可断言行为；无图标时槽不占位。
   - 新增 `MileafActionIcon`（abstract final class，doc 写明「图标只复述按钮词义，不得引入按钮文字里没有的概念」）：refresh / share / compare(chart) / addCost(wallet) / expand / map(mapPin) / retry(refresh) / filter(chevronDown) / copy / clear(close) / save(check) / dateRange(calendar)。retry 与 refresh 同字形——同一动作两种措辞不得换图标（CL14 第三条）。
2. **CL30/CL31 浮层菜单改玻璃**（`pull_down.dart`）
   - 菜单由 `showMenu`（surfaceRaised 实色 Material）改为自建浮层：`showGeneralDialog` + `MileafGlassSurface` 背板。R28 几何全部保留：半径 14、行高 44、左右 16、最小宽 224、锚点下方 s4、下方放不下翻到上方、选中项尾部勾选、菜单上下各留 s8。
   - 表面细节：无 scrim（barrierColor 透明，点外部只关闭不改值）；进出 180ms（`MileafDurations.selection`，减少动效归零）；行按压走 M01 `MileafPressOverlay`；行语义 button/selected/label。胶囊本身仍在画布上，保持 segmentTrack 实色——只有弹出的菜单是浮层。
   - 1px 描边兜底沿用 `MileafGlassSurface` 的 `glassEdge` 受光边（rimStroke = 1.2 物理像素）：浅色下半圈用石墨收暗而不是白线（tokens.dart 的 glassRim* 注释：白边线压在亮内容上等于没有边界），因此不额外叠第二条边框。
3. **CL30 地图浮控改玻璃**（`map_panel.dart`）
   - 适配轨迹 / 放大 / 缩小 / 查看完整地图四枚圆钮：`fill: track`（segmentTrack 实色）→ `fill: none`，直径 36 的 `MileafGlassSurface` 垫在圆钮下面；44/48 命中区保持透明，视觉几何不变（P15「地图控件不用玻璃」被 CL30 取代）。

## 玻璃参数引用来源（一个数值都没重写）

| 参数 | 唯一来源 |
| --- | --- |
| 模糊 σ / 过饱和 | `MileafMaterialMetrics.glassBlur`(22) / `glassSaturation`(1.5)，由 `MileafGlassSurface` 组进 `ImageFilter.compose` |
| 上下叠色 | `MileafColors.glassFillTop` / `glassFillBottom` |
| 受光边 + 1px 描边兜底 | `colors.glassEdge`（线宽 `glassRimStroke` 1.2 物理像素） |
| 阴影 | `colors.glassShadow`（`MileafElevation.glassNavigation*`） |

`pull_down.dart` 与 `map_panel.dart` 源码里没有 `ImageFilter` / `sigmaX` / `sigmaY`，也没有覆盖 `glassBlur`/`glassSaturation`——测试以源码断言钉住（CL31.1）。

## 证据

- 新增 `test/chromatic_material_test.dart`（10 用例）：① 按钮图标在左、间距 s8、槽宽 = inline16+s8、无图标不占位、十二个动作映射；② 下拉菜单背板是 `MileafGlassSurface`，菜单子树内恰一层 `BackdropFilter`，其 filter 文本含 `glassBlur` 与 `glassSaturation` 解出的矩阵项，painter 的 fillTop/fillBottom/edge/shadow 逐项等于 `MileafColors.light().glass*`，rimStroke×DPR ≥ 1；③ 点外部只关闭不改值；④ sheet 两种样式子树内无 `BackdropFilter`/`MileafGlassSurface`，仍是 `surfaceRaised` + `sheetShadow`（CL30.1）；⑤ 地图四枚浮控各垫一块玻璃、圆钮 fill=none；⑥ 两文件源码不含玻璃数值。
- 更新既有断言（浮层材质统一）：
  - `test/apple_polish_ap03_test.dart`：菜单用例由「surfaceRaised 实色 + PopupMenuItem 行高」改为「玻璃背板 + 半径 14 + 行高 44 + 一行 BackdropFilter」；「选择后关闭」改断言 `kPullDownMenuSurfaceKey` 消失。
  - `test/days_migration_material_guard_test.dart`：MG07 内容层玻璃禁令的 Chrome 允许集新增 `pull_down.dart`（CL30 把浮层菜单列入玻璃层）；`map/map_panel.dart` 不在该守卫扫描集内（守卫只扫 `design/components`）。
- 结果：`analyze --no-pub` 无新增诊断（仅 creator/ 既有 3 条与 `apple_polish_ap10` 既有 info，均非本切片文件）。全量跑过一次：**1295 通过 / 55 跳过 / 3 失败**，3 条失败都在并发切片的持有文件里——`apple_polish_ap01` 的图标计数 2 条属 `design/icons.dart`（MC03），`copy_guard` 的 drives/statistics 页中文字面量 3 行超基线属 W3 页面切片；本切片文件 0 失败（`chromatic_material_test` + ap03 + MG07 守卫 61 用例全过）。收口时由主记录在页面合并后再定一次全量基线。

## 遗留

1. 真机/真底图未验证：地图浮控压在真实底图（深色地物）上的图标对比度，以及 `BackdropFilter` 对平台视图（Android TextureMapView / iOS MAMapView）是否真的模糊，属外部 gate #11/#16/#17。
2. 地图浮控的挖孔阴影会被地图卡 `ClipRRect` 裁掉一部分（控件距卡片边 8），观感待真机裁定。
3. 浮层菜单改为自建路由后，方向键/回车这类桌面键盘导航不再由 Material 菜单提供；点按与读屏语义有测试，键盘路径待复核。
4. 浮层玻璃的浅/深对比度未逐像素采（口径与底栏同源），如需图册由 MC12 一并采。

## 收口（总控合并后）

合并全部切片后的终验：全量 **1334 通过 / 55 跳过 / 0 失败**（基线 1176，新增 158 个用例）；本票的 `chromatic_material_test` 10 用例、ap03 与 MG07 守卫在终验中全绿。审查后追加的两处修补也属本票范围：浮层菜单补 `Semantics(scopesRoute/namesRoute/explicitChildNodes)` 与限高滚动（自建路由丢掉的语义与兜底），以及 CL32 守卫从 `design/components/` 扩到 `lib/src/**` 全树。