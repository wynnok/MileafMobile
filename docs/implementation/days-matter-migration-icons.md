# DM02 图标家族参数登记与统一出口（MG04）

> 2026-11-19，包 DM02（[days-matter-migration-tickets.md](../specs/days-matter-migration-tickets.md) DM02）。
> 条款依据：[days-matter-migration.md MG04](../specs/days-matter-migration.md)、[apple-polish.md R32](../specs/apple-polish.md)（24 网格、1.5 描边）。
> 硬边界执行情况：本次未 git 提交；只创建 `lib/src/design/components/icons.dart`（新）、`test/icon_family_test.dart`（新）与本文件；**未编辑** components.dart barrel、page_bar.dart、overview_page.dart、charging_page.dart 等在途/页面包文件。

## 1. 图标盘点（grep 全库结论）

### 1.1 家族参数（实测登记，单一来源 `tokens.dart` `MileafIconMetrics`）

| 参数 | 值 | 实测出处 |
| --- | --- | --- |
| 网格 | 24×24 逻辑像素，按 `size / 24` 等比缩放 | design/icons.dart:74、tokens.dart:483 |
| 描边线宽 | 1.5（R32） | design/icons.dart:78、tokens.dart:484 |
| 端点 | `StrokeCap.round`（圆头） | design/icons.dart:79 |
| 拐角 | `StrokeJoin.round`（圆角连接） | design/icons.dart:80 |
| 视觉盒 | 正方形，档位 inline 16 / nav 20 / header 24 | tokens.dart:492–494 |
| 命中区 | 行 72、触控 iOS 44 / Android 48（`MileafLayout.touchTarget`），由 `MileafIconButton` 保证，图标箱本身不做命中区 | layout.dart:28–31、icon_button.dart |
| 特例 | `back` 字形可见笔画前缘 `backGlyphLead = 8.65`（页头返回键光学对齐用，R26） | tokens.dart:486–491 |
| 实心点 | `dots`（车轮 r1.1）与逐图标 `filled` 圆点，见 §1.2 | design/icons.dart:349–354 |

### 1.2 全部自绘图标（25 个，全部已在 `lib/src/design/icons.dart` 单一 painter 内）

绘制方式统一为：`_MileafIconPainter`（design/icons.dart:67–360）在 24 网格上以 1.5 描边 Path 落形；「圆点」列标注额外实心圆（半径为 24 网格格数）。

| 图标 | case 行号 | 圆点 | 造型说明（语义选义走 CP02/CP04） |
| --- | --- | --- | --- |
| home | 89–101 | — | 屋顶 + 房身 + 门 |
| car | 102–120 | 2 × r1.1（车轮） | 车身轮廓 + 前后保险杠 + 车轮点 |
| bolt | 121–129 | — | 闪电闭合多边形 |
| chart | 130–139 | — | 基线 + 三根柱 |
| route | 140–145 | 2 × r1.2（起终点） | S 曲线 + 实心端点 |
| mapPin | 146–157 | — | 水滴外框 + 圆孔（`addOval`） |
| battery | 158–173 | — | 圆角电池体 + 正极耳 + 三格刻度 |
| clock | 174–179 | — | 圆盘 + 时分针 |
| settings | 180–198 | — | 16 边齿轮（8 齿）+ 圆轴孔 |
| chevron | 199–203 | — | 右向 chevron |
| refresh | 204–214 | — | 开口圆弧 + 箭头头部 |
| wallet | 215–225 | 1 × r1（卡扣） | 圆角钱包体 + 横线 + 实心点 |
| info | 226–231 | 1 × r0.9 | 圆盘 + 竖线 + 实心点 |
| close | 232–237 | — | 两段斜线 |
| check | 238–242 | — | 对勾折线 |
| copy | 243–259 | — | 两张错位圆角片（4 格错位，防粘连） |
| calendar | 260–277 | 3 × r0.9 | 圆角日历体 + 两挂耳 + 三日点 |
| more | 278–280 | 3 × r1.4 | 横向三点省略号 |
| expand | 281–295 | — | 四角外向括号 |
| chevronDown | 296–300 | — | 下向 chevron |
| back | 301–306 | — | 左向 chevron（chevron 镜像，同字重） |
| plus | 307–312 | — | 十字两段线 |
| minus | 313–316 | — | 单段横线 |
| moon | 317–330 | — | 月牙：两段圆弧（外弧顺 / 内弧逆时针） |
| offline | 331–345 | — | 双层上弧 + 斜线（离线/无网络） |

### 1.3 非图标 CustomPainter（登记为「不纳入家族」，保持原位）

| Painter | 位置 | 分类 |
| --- | --- | --- |
| `_BrandMarkPainter` | lib/src/design/brand_mark.dart:36 | 品牌符号（同 24 网格 / 1.5 描边 / 圆头圆角，但属品牌层，不进图标枚举） |
| `_BatteryArcPainter` | lib/src/design/components/battery_arc.dart:233 | 电量环仪表（数据图形） |
| `_ShareRingPainter` | lib/src/design/components/share_ring.dart:280 | 占比环仪表（数据图形） |
| `_SparkPainter` / `_ChartPainter` | lib/src/design/components/charts.dart:1445/1535 | 图表（数据图形） |
| `LiquidGlassShadowPainter` / `LiquidGlassPainter` | lib/src/design/components/glass_surface.dart:121/164 | 材质（ADR0013，MG07 登记范围） |
| `_TemperaturePlot` / `_ParkingPainter` / `_StateSegmentPainter` / `_RangePainter` / `_UsagePatternPainter` | lib/src/statistics_{conditions,parking,range,usage}_page.dart | 统计专题数据图形（DM07 页面包范围） |
| `_SketchPainter` | lib/src/map/sketch_platform.dart:87 | 地图草图调试层 |

### 1.4 页面直绘图标结论

- **页面直绘图标 = 0，Material Icons = 0**（`grep "Icons\." lib` 无结果）。R32/AP01 要求补齐的 calendar / more / expand / chevronDown / back / plus / minus / moon / offline 已全部在 `design/icons.dart` 内（MG04 条款「现状」描述的 hero 状态图形直绘已被 AP01 迁走：`vehicleStatusIcon`（design/components/hero.dart:39–43）把充电中/休眠/离线映射到家族 `bolt`/`moon`/`offline`，overview_page.dart:621–623、charging_page.dart:1716–1718 经 `MileafIcon` 消费）。
- 因此本包**无需为页面直绘图标登记占位常量**；DM05–DM07 页面包如发现新的自绘图标，必须改走统一出口并满足 §1.1 参数表。
- 图标配色沿用调用方语义色（`MileafIcon` 默认 `textMuted`，可传 `color`），家族本身不定义颜色——符合 MG04「不另起高饱和色」。

## 2. 统一出口 `lib/src/design/components/icons.dart`（新）

- `export '../icons.dart';`：把既有 `MileafIcon` / `MileafIconName`（25 图标）桥接为统一出口，原实现原位保留，**视觉与 API 零变化**；组件与页面自本包起按 `import 'design/components/icons.dart'` 消费。
- `MileafIconFamily`：家族参数表常量类——`grid = 24`、`strokeWidth = 1.5`、`strokeCap = round`、`strokeJoin = round`、视觉盒 `boxInline/boxNav/boxHeader = 16/20/24`，全部引用 `MileafIconMetrics`（不复制数值，守卫测试钉住同源）；`semanticLabels` 给每个图标一句话读屏语义（CP02/CP04/CP10/CP11 选义，页面可给更完整 CP11 句式）。
- **TODO(DM08/MG04 迁移票)**：`_MileafIconPainter` 实现体仍在 `design/icons.dart`。把它迁入 `components/icons.dart` 需改写 18 个 `import 'design/icons.dart'` 的既有 importer 并处理 barrel（`components.dart` 当前有他人在途改动，本包被明令禁止编辑），故按授权边界改为桥接 + TODO 注释，留给 DM08 集成包执行。
- 不接 barrel：按本包指令，消费方直接 import icons.dart，barrel 导出留给 barrel 在途改动收口后。

## 3. 测试 `test/icon_family_test.dart`（新）

| 组 | 内容 |
| --- | --- |
| 家族参数 | `grid == 24`、`strokeWidth == 1.5`、圆头圆角；家族常量与 `MileafIconMetrics` 同源；视觉盒档位一致 |
| 语义标签 | `semanticLabels` 覆盖全部 25 个导出图标、非空、不重名 |
| 逐图标渲染 | 每个图标 pump 不抛错；`ensureSemantics` 下语义标签存在（`find.bySemanticsLabel`） |
| 像素探针 | 复用 `test/support/pixel_probe.dart`：每个图标 24px 实际画出笔画（黑色像素 > 0），笔画 bounding box 不越出视觉盒（0.5–23.5） |
| opt-in 渲染 | 沿 `test/period_header_render_test.dart` 的 skip 机制（`MILEAF_RENDER_OUTPUT` / `MILEAF_RENDER_FONT` 未设置整组跳过）：浅深两模式图标图板经 `saveRenderPng` 出 PNG（`DM02-icons-normal-{mode}-390x844-100.png`） |

## 4. 验证

- `tool/flutterw analyze`：本包三个文件（components/icons.dart、icon_family_test.dart、本文档）**0 诊断**。全库残余 3 条均在包外：`creator/video/`（不入库的视频工作区捕获文件）2 条、`test/apple_polish_ap10_test.dart` 既有 info 1 条；另有并行包在途文件的诊断随其提交收口，与本包无关。
- `tool/flutterw test test/icon_family_test.dart`：**4 通过 / 1 跳过 / 0 失败**（跳过为默认关闭的 opt-in 渲染组）。
- opt-in 渲染实测通过：`--dart-define=MILEAF_RENDER_OUTPUT=… --dart-define='MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'` 出 `DM02-icons-normal-{light,dark}-390x844-100.png` 两张（390 逻辑宽、2x 导出，25 图标 3 列图板 + 语义标签）。
- 被桥接组件既有测试不破：`design_components_test.dart` + `apple_polish_ap01_test.dart` + `design_tokens_test.dart` 共 **101 用例全过**。
- 测试实现备注：像素探针按 RGB 匹配（不比 alpha），白底必须画在 RepaintBoundary 子树内；1.5 斜向笔画可能没有全覆盖像素，探针按「深于中灰」（tolerance 127）计笔画与外沿。
