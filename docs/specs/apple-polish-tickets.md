# Apple 质感精修实施 Tickets

2026-11-16，状态为 **accepted，待实施**（用户 2026-11-16 确认 ADR0014 与本任务图）。本地任务 ID 为 AP00–AP15（AP12 分 a、b 两张，共 17 张）。设计依据为 [ADR0014](../adr/0014-apple-polish.md)、[精修规格](apple-polish.md)与[文案规范](apple-polish-copy.md)；执行、并行、租约、命令与验收见[交付手册](apple-polish-delivery.md)。GitHub 映射为草案，发布需单独授权。

## 1. 任务图

| ID | 标题 | 直接前置 | 波次 | 建议模型档 |
| --- | --- | --- | --- | --- |
| AP00 | 基线冻结、能力清单、折叠分类、共享符号表与 before 图册 | 用户确认 ADR0014（可部分确认），并决定在途改动如何落地 | W0 | 强（总控） |
| AP01 | 设计基础：角色、文字层级、形状、描边、间距、动效参数、图标、按压、裸值守卫 | AP00 | W1 | 强 |
| AP06 | 文案基础：日期与数字格式化、术语、比较名称、枚举标签、状态句构造、文案守卫、非页面文件字符串 | AP00 | W1 | 标准，要求细致 |
| AP02 | 导航外壳：可收起大标题、顶部镜片控件、底栏封顶与大内容查看器、二级导航 | AP01 | W2 | 强 |
| AP03 | 控件与弹层：胶囊分段与按钮、图标按钮、下拉、选择列表、浮动弹层、日期区间弹层 | AP01 | W2 | 强 |
| AP04 | 内容语法：模块卡、分组卡与行、标题、数值与单位、事实表、折叠、状态、车况卡、关于这些数据、层级探针 | AP01 | W2 | 强 |
| AP05 | 图表语法：完整读数头与紧凑读数行、步进、右侧 Y 轴、参照刻度、选中标记、触觉 | AP01、AP06 | W2 | 强 |
| AP07 | 代表页与冻结，提交用户视觉裁定 | AP02、AP03、AP04、AP05、AP06 | W3 | 强（总控或指定） |
| AP08 | 概览全量与服务信息 | AP07 及用户裁定 | W4 | 标准+ |
| AP09 | 行程列表、行程详情与地图呈现 | AP07 及用户裁定 | W4 | 标准+ |
| AP10 | 充电账本、充电方式与充电详情 | AP07 及用户裁定 | W4 | 强 |
| AP11 | 统计首页、全部指标与期间选择 | AP07 及用户裁定 | W4 | 标准+ |
| AP12a | 专题：节奏、能耗、补能 | AP07 及用户裁定 | W4 | 标准+ |
| AP12b | 专题：长期续航、停放观察 | AP07 及用户裁定 | W4 | 标准+ |
| AP13 | 设置、接入、车辆与选择弹层、地图设置、费用补录 | AP07 及用户裁定 | W4 | 标准+，冻结文案只排版 |
| AP14 | 集成：跨页行为、无障碍、动效、开发期性能与守卫归零 | AP08–AP13 | W5 | 强（总控） |
| AP15 | 完整验证、双端构建、双轴审查与交付 | AP14 | W5 | 强（总控） |

「强」指适合跨文件设计决策与共享接口的高推理模型；「标准+」指能稳定执行明确规格、读懂既有测试的模型。同一波次内的票不互相等待，但页面之间存在只读的跨文件符号引用（例如概览调用统计首页的比较函数、长期专题调用节奏专题的说明组件）：这些公开符号在 W4 期间冻结签名，见交付手册 §3.4。同一 checkout 内只能串行（交付手册 §3.2）。

## 2. 每票通用合同

- **开工**：用交付手册 §8.2 的提示词启动，按 §8.5 的本票必读清单阅读，不必通读全部文档；记录 `pwd`、分支、HEAD、`git status --short` 与本票文件租约。
- **写入范围**：只写本票「持有文件」与本票新建的 `test/apple_polish_apXX_*.dart`、本票源文件对应的守卫基线文件。既有测试的修改权按交付手册 §3.3 的测试租约；非本票持有的测试若因本票共享组件变化而失败，提交最小等价补丁给总控，不直接修改。
- **不变**：S01–S08、全部路由、回调、Key、测试钩子、能力分支、数据算法、请求类型与参数、依赖与锁文件、生成契约；W4 冻结的跨票公开符号签名。
- **TDD 接缝**：公开 Widget、页面路由、App + 可控 HTTP、共享格式化器的公开函数。不读私有字段，不替代业务状态机。
- **验证**：本票列出的测试、`./tool/flutterw analyze --no-pub`、本票改动 Dart 文件的格式检查、`git diff --check`；需要正式渲染的票用本票自己的 `test/apple_polish_apXX_render_test.dart`，按交付手册 §5 输出。
- **完成**：本票规则逐条映射到符号、测试和图像；能力迁移表无悬空；文案前后对照完整；本票源文件中的 Material Icons 清零（R32）；P0/P1/P2 与视觉阻断为 0；外部待验单列；交接文件 `docs/implementation/apple-polish/APxx.md` 按交付手册 §7 格式写完。
- **遇到以下情况停下交总控**：需要改持有范围外的文件或冻结符号；文案含义变化或触及冻结文案；首屏预算走到退让阶梯第 5 步；需要新增依赖、路由或接口；与既有 ADR 冲突且规格 §1.4 未登记。

## 3. 逐票合同

### AP00 基线冻结、能力清单与 before 图册

- **前置**：已满足。用户 2026-11-16 确认 ADR0014 全部决定，并授权把在途改动（ADR0012 F00–F12 暂存内容、ADR0013 液态玻璃底栏、2026-11-16 概览图表头）与 ADR0014 文档落地为本地提交（交付手册 §1 P-2）。
- **持有文件**：`docs/implementation/apple-polish/{README,AP00,capability-map}.md`、`docs/implementation/apple-polish-renders/before/` 与 manifest、`test/apple_polish_render_test.dart`（before 机位）。
- **动作**：
  1. 记录基线 SHA、工具链、字体身份；全量 `analyze` 与 `test`，并带渲染 define 跑 U04–U11 正式矩阵，登记 skip 与失败。
  2. 复现并归因规格 §2 AU25 的两处 opt-in 失败：`ui_ux_u08_test.dart` 统计专题卡底边 708 超过底栏上沿 704（首屏预算）；`ui_ux_u06_test.dart` 130% 字号下充电四项分段未折成两行（分段重排）。若为回归，做最小修复：有 P-3 授权时单独提交，否则只在交接中列出修改；若为预算或重排规则冲突，登记给 AP07 按规格 §6 处理。不得改阈值或断言。
  3. 接续 [UI/UX capability map](../implementation/ui-ux-refinement/capability-map.md) 的 104 项与 [Apple 焕新能力迁移](../implementation/apple-design-renewal/capability-map.md) A11–A20，新增本轮呈现能力 A21 起（可收起大标题、读数头、紧凑读数行、关于这些数据、日期区间弹层、大内容查看器、文案守卫等），每行写当前入口、目标归宿、关联测试、持有票。
  4. 把现有 25 处 `ExpansionTile` 按规格 R30.3 分为说明类与内容类，逐处登记文件、行、标题、目标位置。
  5. 生成跨票共享符号表：按页面文件之间的 import 列出被其他票调用的公开类、函数与构造参数（交付手册 §3.4 给出文件级起点），写明持有票与调用票。
  6. 用现有渲染入口采集 before：每个页面至少 390 浅深 100%、360 浅 200%、320 浅 100% 的首屏与一屏下滚，含空、失败、进行中各一；写 manifest（输入 SHA、夹具、时区、字体路径与哈希、尺寸、DPR、材质模式、图像哈希）。
  7. 统计文案基线：用交付手册 §5 的抽取命令记录每个源文件含中文字符串的数量，交给 AP06 作为守卫基线输入。
- **测试**：全量；`reading_integration_test.dart`、`full_flow_test.dart` 单独记录。
- **完成**：基线可复现；能力表、折叠分类、共享符号表完整；before 图册与 manifest 可用；AU25 两处有结论；文件租约表写入 README；冻结点 FP0 登记。映射 AQ00。

### AP01 设计基础

- **持有文件**：`lib/src/design/{tokens,semantic,typography,motion,theme,icons,brand_mark}.dart`；`lib/src/design/layout.dart` 中除根外壳几何（`rootTopBarHeight`、`rootTopClearance`、`rootNavigationHeight`、`rootNavigationClearance`，归 AP02）以外的部分；`test/design_tokens_test.dart`；新建 `test/apple_polish_ap01_test.dart`、`test/apple_polish_raw_value_guard_test.dart`、`test/support/raw_value_baseline/`（每个源文件一个基线文件）。
- **动作**：
  1. R22：新增 `largeTitle`、`title2`、`headline`、`subheadline`（含分组标题 500 变体）、`control`、`footnote`、`caption`、`metricSm`；旧 `title`、`label`、`micro`、`pageTitle`、`navigationTitle`、`bodyStrong` 保留原值作为过渡别名并注释去向；Material `TextTheme` 映射本票不改。
  2. R23：新增 `textSecondary`（= `textMuted`）；按 R23.5 实测确定 `controlBorder` 新值。
  3. R24：使用既有 `MileafRadius.lg` 作为容器半径，新增胶囊与圆形形状常量、`MileafStroke.hairline`（宽 0）、规范间距集合；旧 `inline6/inline10/s18/s40/s56` 标注弃用，不删除。
  4. M01–M12 的时长、曲线、缩放与拉伸常量集中声明；`MileafLayout.motion` 调用合同不变。
  5. 主题：`splashFactory: NoSplash.splashFactory`，按压高亮色 `pressOverlay`；页面过渡保持平台默认。
  6. 图标：按 R32 补齐 9 个自绘图标，24 网格、1.5 描边，视觉重心与现有图标一致。
  7. 页面裸值守卫：扫描 `lib/src` 页面文件中的裸 `fontSize`、`Color(0x`、`Duration(milliseconds`、`Radius.circular(` 数字，按源文件计数并建立基线，只许下降。
- **允许的外观变化**：本票合入后，页面外观只允许两处变化：按压不再出现涟漪、输入框边框颜色变浅。其余外观必须与基线一致。
- **测试**：`design_tokens_test.dart`、`appearance_shell_test.dart`、`design_components_test.dart`（只运行）；新增角色表、两级文字对比矩阵（canvas、surface、segmentTrack、segmentSelected、surfaceRaised，浅深）、`controlBorder` ≥3:1、发丝线宽、图标绘制、NoSplash、裸值守卫。
- **证据**：角色图板与图标图板（浅深、100/200%）；`AP01.md` 含新旧 token 对照与对比实测表。
- **完成**：新 API 清单冻结给 W2；旧别名映射表交 AP14。映射 AQ01、AQ02。

### AP06 文案基础

- **持有文件**：`lib/src/number_format.dart`；新建 `lib/src/copy/{dates,durations,units,terms,labels,messages}.dart`；非页面文件中的用户可见字符串字面量（`api.dart`、`session.dart`、`workspace.dart`、`currency.dart`、`overview_period.dart`、`appearance.dart`、`map/map_key.dart`、`map/map_consent.dart`、`map/sketch_platform.dart`、`map/amap_ios_platform.dart`、`map/amap_android_platform.dart`，只改字面量）；`test/number_format_test.dart`；新建 `test/apple_polish_copy_test.dart`、`test/apple_polish_copy_guard_test.dart`、`test/support/copy_guard_baseline/`、`test/support/copy_probe.dart`。
- **动作**：
  1. CP04 DF1–DF9 格式化器：输入为已按站点日历本地化的时间与「今天」参照，纯函数，不引入时区逻辑；覆盖跨月、跨年、跨日、周级分桶、DST 日界、读屏读法。
  2. CP03 时长与单位：时长分级、真负号、`semanticsUnit` 中文朗读单位。
  3. CP02 术语常量与比较对象名称：逐页核对源码中的实际比较窗口，名称与窗口不一致的改写日期区间。
  4. CP10 枚举标签映射：依据 `*_contract.g.dart` 与 `MileafServer/` 只读文档核实全部枚举值；查不到的列入待确认，未知值兜底「其他原因」。
  5. CP07 状态句构造函数：空、首次空、加载、刷新失败、读取失败、分页失败、能力不支持、版本不兼容、时区不可读。
  6. 非页面文件字符串：只改字面量，不改逻辑与控制流；CP12 冻结范围原文不动；逐条列入交接。
  7. 文案守卫：按文案规范末节实现，每个源文件一个基线文件，基线来自 AP00。
- **不做**：不改页面文件的字符串（页面包负责替换）；不改业务精度与舍入。
- **测试**：新格式化器与构造函数单元测试（含 2025/2026 跨年、DST 适用与不适用时区各一）、守卫在基线上通过；`session_test.dart`、`connection_management_test.dart`（只运行，确认字面量修改未破坏行为）。
- **完成**：API 清单交 W2 与 W4；比较名称核对表与枚举核对表写入交接。映射 AQ08。

### AP02 导航外壳

- **持有文件**：`lib/src/design/components/{top_bar,page_bar,nav_bar,glass_surface,navigation_material}.dart`；新建 `lib/src/design/components/large_content_viewer.dart`；`layout.dart` 的根外壳几何函数；`lib/src/workspace_page.dart` 的外壳部分（`_VehicleSheet` 除外）；`test/navigation_bar_test.dart`、`test/liquid_glass_nav_test.dart`、`test/liquid_glass_nav_render_test.dart`；新建 `test/apple_polish_ap02_test.dart`。
- **动作**：R26 全部：展开与收起外壳、滚动驱动插值（0–16）与外壳高度变化（PD01）、外壳只重建自身、车辆胶囊与设置圆钮（镜片填充、实色路径）、大字布局、notice 横幅位置；底栏标签封顶 1.35× 与大内容查看器（长按出现、抬手切换、M10，双端一致）；二级导航标题 `headline`、自绘返回图标、尾部最多一个可见操作与「更多」菜单接口。L09 断言按 PD05 修订并引用 ADR0014。
- **不做**：不改 IndexedStack、ReadingScope、TickerMode、目的地与顺序、底栏材质参数（外阴影减弱为可选校准，需实测并登记）。
- **测试**：上列测试 + `appearance_shell_test.dart`、`settings_navigation_test.dart`、`reading_continuity_test.dart`（只运行）；新增滚动 0/8/16/100 外壳状态、减少动效阈值切换、320 与 768 宽、100/150/200% 字号、大内容查看器出现与选择、收起态标题封顶、读屏标签不变、外壳与底栏对末项与焦点的遮挡。
- **完成**：外壳 API（页面顶部留白高度、滚动接入方式）冻结给 AP07；四个根页在未改页面内容时外观一致。映射 AQ02、AQ04、AQ06、AQ07。

### AP03 控件与弹层

- **持有文件**：`lib/src/design/components/{chip_row,chip,button,icon_button,sheet,focus_ring}.dart`；新建 `lib/src/design/components/{date_range_sheet,pull_down,selection_list}.dart`；`test/design_components_test.dart`（W2 内唯一修改者，AP02、AP04 对它的修改以补丁交本票或总控）；新建 `test/apple_polish_ap03_test.dart`。
- **动作**：R27 与 R28：胶囊分段（删除下划线标记、选中底阴影、40/36 几何、命中扩展、M02 拉伸 1.04）、期间行折行规则与刷新圆钮、主次按钮胶囊 50、文字按钮、图标圆钮 36、小胶囊下拉与菜单、选择列表只勾选、浮动与贴边两种弹层、`MileafDateRangeSheet`（平台日期选择器 + 「改为输入」键盘路径，校验、默认值与回调由调用方注入，组件不内置业务规则）。
- **不做**：页面不在本票接入新组件（页面包接入）；`showMileafSheet` 现有调用的行为合同不变，新样式通过参数启用。
- **测试**：`design_components_test.dart`、`ui_ux_u02_test.dart`；`ui_ux_u03_test.dart` 只运行；新增八种状态、2×2 与单列重排、期间行折行、连续点击重定向、减少动效、弹层焦点返回、日期弹层校验回调、键盘输入路径。
- **完成**：控件 API 清单冻结。映射 AQ02、AQ04、AQ07。

### AP04 内容语法

- **持有文件**：`lib/src/design/components/{hero,section,metric,data_row,copy_row,fact_list,disclosure,state_view,map_frame,soc_interval}.dart`；新建 `lib/src/design/components/module.dart`（模块卡、分组卡、分组行、分组标题与脚注、关于这些数据分组）；`lib/src/design/components/components.dart` 的导出行（其他票新增导出时各加一行，冲突由总控合并）；`test/design_disclosure_fact_test.dart`；新建 `test/apple_polish_ap04_test.dart`、`test/support/hierarchy_probe.dart`。
- **动作**：R21、R24、R25、R30、R31 的组件部分：模块卡（`MileafRadius.lg`、内边 16、无阴影）、分组行（52/64、分隔线从文字起始处开始）、区块标题与分组标题、`MileafNumber` 去掉单位单独成行的回退并改为由网格重排、三列网格只用 `metricSm`、事实表、`MileafDisclosure` 高度动画（M06）、状态组件（模块内与整页两种）与行内状态条（M11）、车况卡半径 20 与状态图形、「关于这些数据」五类分组组件、层级探针（R21.7）。
- **不做**：不迁移页面里的 `ExpansionTile`（页面包按 AP00 分类迁移）。
- **测试**：`design_disclosure_fact_test.dart`；`design_components_test.dart` 中内容组件断言的等价修正以补丁交 AP03；新增单位不折行、网格重排、分隔线起止、折叠焦点与读屏、状态组件各态、M06 与 M11 时间采样、200% 布局、层级探针自测。
- **完成**：内容组件 API 清单冻结。映射 AQ02、AQ04、AQ07。

### AP05 图表语法

- **持有文件**：`lib/src/design/components/{charts,category_bars,composition_bar,battery_arc,share_ring}.dart`；`lib/src/sample_chart.dart`；`test/chart_marks_test.dart`、`test/data_visualization_app_test.dart`、`test/a_micro_spark_test.dart`、`test/share_ring_test.dart`、`test/readability_render_test.dart`、`test/ui_ux_u03_test.dart`；新建 `test/apple_polish_ap05_test.dart`。
- **动作**：R29 全部：完整读数头（三行、尾部步进、最小高度稳定、默认选点不变、`readout` 句子仍为唯一朗读源、`readoutBuilder` 兼容）、紧凑读数行、Y 轴在右、X 轴刻度用 AP06 格式化器、柱端圆角、条形图参照刻度、选中标记、图例在 X 轴下、无数据收起、M07 触觉、M09 切换淡入；电量环内只放数值。
- **兼容**：`TimeSeriesChart`、`StemChart`、`SampleChart` 现有参数保留，新增参数有默认值；调用方不改也能得到新布局。
- **不做**：不改页面文件；页面专属读值内容由页面包调整。
- **测试**：上列 + `overview_reading_test.dart`（只运行，因位置变化而失败的断言以补丁交总控，AP08 接收）；新增首末点、极值、真实 0、null、单点、全空、参照为 0、负值、键盘与语义步进、拖动与纵向滚动仲裁、触觉只在索引变化时触发、减少动效。
- **完成**：图表 API 清单冻结；图表图板（正负/零/null/单点/全空/稀疏/极值，浅深，100/200%）。映射 AQ02、AQ04、AQ06。

### AP07 代表页与冻结

- **持有文件**（冻结后交还）：`lib/src/overview_page.dart`、`lib/src/drives_page.dart`、`lib/src/statistics_insights_page.dart`、`lib/src/charging_detail.dart`、`lib/src/settings_page.dart`、`lib/src/workspace_page.dart` 的 `_VehicleSheet`；对应页面测试的最小等价修正；`test/apple_polish_render_test.dart`（代表机位）；`docs/implementation/apple-polish-renders/review/`。
- **动作**：在正式组件上完成 P01 概览、P02 行程、P06 统计首页、P05 充电详情、P12 设置与 P16 车辆弹层的主状态（正常、空、失败、刷新中、浅深、360 与 390、100% 与 200%、320 宽 100%），含文案对照表中这些页面的条目；实测规格 §6 首屏预算，按退让阶梯前四步自行处理，第 5 步准备候选；用层级探针检查 R21；采样 M01–M03、M06、M07。
- **用户视觉裁定**：输出 before/after 成对图（同机位）、首屏实测与候选、一页检查清单（重心、层级、秩序、文案、材质、动效），停下等待用户逐项裁定。用户要求修改的，在本票内修正后再次提交；用户否决某个 PD 项的，按规格 §1.4 回退并更新规格与 ADR0014。
- **冻结**：用户通过后，冻结 token 表、组件 API 清单、动效参数、首屏预算、偏差账本与跨票共享符号签名，形成冻结点 FP3，页面文件交回 AP08–AP13。
- **测试**：上列页面现有测试、`reading_continuity_test.dart`、`overview_statistics_reading_test.dart`、`a_gallery_render_test.dart` 与新代表机位。
- **完成**：用户裁定记录（日期、通过项、修改项）写入 `AP07.md`；是否同步到 AGENTS.md 由用户决定。映射 AQ02、AQ03、AQ04。

### AP08 概览全量与服务信息

- **持有文件**：`lib/src/overview_page.dart`（含 `MetaPage`）；`test/overview_test.dart`、`test/overview_briefing_test.dart`、`test/overview_visualization_test.dart`、`test/overview_reading_test.dart`、`test/overview_reading_render_test.dart`、`test/overview_verification_test.dart`、`test/overview_a_regression_test.dart`、`test/a_overview_test.dart`、`test/a_overview_render_test.dart`、`test/ui_ux_u04_test.dart`；新建 `test/apple_polish_ap08_test.dart`、`test/apple_polish_ap08_render_test.dart`。
- **只读依赖**：`statistics_insights_page.dart` 的比较函数、`statistics_period.dart`（AP11 持有，签名冻结）。
- **动作**：P01 全部状态（无车况、车况缺失、充电中、休眠、离线、扩展能力不支持、比较不可用、费用覆盖缺失、时区回退、刷新失败有旧数据、空期间）；「数据说明与更多」五组迁入关于这些数据；本页文案对照表全部条目；`MetaPage` 按 P12 分组卡与技术详情呈现；本文件守卫计数降到 0。
- **测试**：上列 + `reading_continuity_test.dart`、`overview_statistics_reading_test.dart`（只运行，失败交总控）。
- **完成**：P01 全状态矩阵图、首屏实测、Tab 往返与显式下钻保留证据、文案前后表。映射 AQ03、AQ05、AQ06、AQ08。

### AP09 行程列表、行程详情与地图呈现

- **持有文件**：`lib/src/drives_page.dart`、`lib/src/drive_detail_page.dart`、`lib/src/map/{map_panel,drive_map_page}.dart` 的呈现部分；`test/drives_test.dart`、`test/a_drives_test.dart`、`test/drive_detail_test.dart`、`test/a_drive_detail_test.dart`、`test/drive_detail_reading_test.dart`、`test/drive_detail_reading_render_test.dart`、`test/ui_ux_u05_test.dart`；新建 `test/apple_polish_ap09_test.dart`、`test/apple_polish_ap09_render_test.dart`。`test/ui_ux_u07_test.dart` 由总控持有，本票的修改以补丁提交。
- **只读依赖**：`map/map_consent_sheet.dart`、`map/map_privacy_page.dart`（AP13 持有）。
- **动作**：P02 与 P04：按天分组的分组卡、汇总卡与紧凑读数行、加载更多与结束提示、行程日期接入共享日期区间弹层（保留原含首尾与默认近 30 天语义）、详情身份块、地图卡与展开圆钮（地图上用实色控件）、两个刷新合一、行驶过程卡与完整读数头、「同时查看电量」沿现有折叠行只改名、电量变化卡、事实表、参考电耗卡、关于这些数据；本页文案条目；Material Icons 清零；两个页面文件守卫计数降到 0。
- **不做**：不改 `MapPanel` 授权、Key、原生生命周期与坐标转换。
- **测试**：上列 + `map_platform_test.dart`、`reading_continuity_test.dart`（只运行）。
- **完成**：P02/P04 全状态（含地图无 Key、未同意、待重启、失败、无轨迹、单点）矩阵图与首屏实测。映射 AQ03、AQ05、AQ06、AQ08。

### AP10 充电账本、充电方式与充电详情

- **持有文件**：`lib/src/charging_page.dart`、`lib/src/charging_method.dart`、`lib/src/charging_detail.dart`（AP07 交还后）；`test/charging_test.dart`、`test/charging_expansion_test.dart`、`test/charging_reading_test.dart`、`test/charging_method_section_test.dart`、`test/charging_method_test.dart`、`test/charging_detail_test.dart`、`test/a_charging_test.dart`、`test/a_charging_detail_test.dart`、`test/a_charging_method_render_test.dart`、`test/ui_ux_u06_test.dart`；新建 `test/apple_polish_ap10_test.dart`、`test/apple_polish_ap10_render_test.dart`。`test/ui_ux_u07_test.dart` 由总控持有，本票以补丁提交。
- **只读依赖**：`charging_cost.dart`（AP13 持有）、`statistics_period.dart`（AP11 持有）；本票持有的 `charging_page.dart`、`charging_detail.dart` 被 AP12a 调用，公开签名冻结。
- **动作**：P03 与 P05 全部状态：进行中卡、账目卡、每日充电卡（紧凑读数行、88 高的图）、最近充电与「查看全部」、全部记录模式（二级导航形态、胶囊下拉、匹配数）、地点卡、构成环卡、充电日期接入共享日期区间弹层（保留按结束日期归属、730 天限制与原回调）、详情电量卡与三格、补录入口位置、充电过程卡、电量计量、费用明细、电池加热、关于这些数据；本页文案条目；Material Icons 清零；三个文件守卫计数降到 0。
- **不做**：费用补录表单本身（AP13）；费用写入与刷新状态机。
- **测试**：上列 + `charging_cost_refresh_test.dart`、`charging_statistics_test.dart`（只运行）。
- **完成**：P03/P05 全状态（进行中、费用缺失、免费、未知币种、能力回退、旧契约、全部记录筛选与空）矩阵图与首屏实测。映射 AQ03、AQ05、AQ06、AQ08。

### AP11 统计首页、全部指标与期间选择

- **持有文件**：`lib/src/statistics_insights_page.dart`（AP07 交还后）、`lib/src/statistics_page.dart`、`lib/src/statistics_period.dart`；`test/statistics_insights_test.dart`、`test/statistics_test.dart`、`test/a_statistics_test.dart`、`test/ui_ux_u08_test.dart`；新建 `test/apple_polish_ap11_test.dart`、`test/apple_polish_ap11_render_test.dart`。
- **被调用的冻结符号**：`statistics_insights_page.dart` 与 `statistics_period.dart` 的公开符号被 AP08、AP10、AP12a、AP12b 调用，W4 期间签名不变。
- **动作**：P06 全部状态、期间行（本月、近7天、自定义 + 新增刷新圆钮）、专题卡片等高网格与单列、全部指标分组列表、长期索引两入口、统计期间接入共享日期区间弹层（保留 730×24 小时限制、本周与本年等预设、`topicContext`）；本页文案条目；Material Icons 清零；三个文件守卫计数降到 0。
- **测试**：上列 + `overview_statistics_reading_test.dart`、`reading_continuity_test.dart`（只运行）。
- **完成**：P06 与全部指标的矩阵图、专题首行预算实测、选点与下钻原参数证据。映射 AQ03、AQ05、AQ06、AQ08。

### AP12a 专题：节奏、能耗、补能

- **持有文件**：`lib/src/statistics_{usage,conditions,charging}_page.dart`；`test/statistics_{usage,conditions,charging}_test.dart`、`test/ui_ux_u09{a,b,c}_test.dart`；新建 `test/apple_polish_ap12a_test.dart`、`test/apple_polish_ap12a_render_test.dart`。
- **被调用的冻结符号**：`statistics_usage_page.dart` 的 `StatisticsTopicNotes` 等公开符号被 AP12b 与本票其他页调用；若改用 AP04 的关于这些数据组件，保留原符号作为签名不变的适配层，由 AP14 清理。
- **动作**：专题骨架（R25）、P07 日历重做、P08 点图与步进（温度组分段保留并胶囊化）、P09；样本明细；枚举人话标签与技术详情；本页文案条目；三个文件守卫计数降到 0。按 usage → conditions → charging 顺序分段提交（有提交授权时）。
- **测试**：上列；`copy_probe` 断言渲染树无 snake_case。
- **完成**：三专题普通、空、缺失、能力不足、错误及读数机位，DST 与长期独立窗口回归通过。映射 AQ03、AQ05、AQ08。

### AP12b 专题：长期续航、停放观察

- **持有文件**：`lib/src/statistics_{range,parking}_page.dart`；`test/statistics_{range,parking}_test.dart`、`test/ui_ux_u09{d,e}_test.dart`；新建 `test/apple_polish_ap12b_test.dart`、`test/apple_polish_ap12b_render_test.dart`。
- **只读依赖**：`statistics_insights_page.dart`（AP11）、`statistics_usage_page.dart` 的 `StatisticsTopicNotes`（AP12a），签名冻结。
- **动作**：P10、P11；停车记录状态、未计入原因、窗口统计的人话标签；停车记录逐行明细保留原位折叠；X 轴日期去重；技术详情；本页文案条目；两个文件守卫计数降到 0。
- **测试**：同 AP12a 方式。
- **完成**：两专题全部状态机位、月窗口独立、正负零未知区分、纹理占比条对比实测。映射 AQ03、AQ05、AQ08。

### AP13 设置、接入、车辆与选择弹层、地图设置、费用补录

- **持有文件**：`lib/src/{settings_page,connection_page,connection_management,session_pages,setup_page,appearance_sheet,charging_cost}.dart`、`lib/src/map/{map_privacy_page,map_consent_sheet}.dart`、`lib/src/workspace_page.dart` 的 `_VehicleSheet`（AP07 交还后）；`test/settings_navigation_test.dart`、`test/settings_render_test.dart`、`test/connection_management_test.dart`、`test/setup_test.dart`、`test/session_test.dart`、`test/map_key_page_test.dart`、`test/map_key_render_test.dart`、`test/charging_cost_test.dart`、`test/charging_cost_render_test.dart`、`test/ui_ux_u10_test.dart`、`test/ui_ux_u11_test.dart`；新建 `test/apple_polish_ap13_test.dart`、`test/apple_polish_ap13_render_test.dart`。
- **被调用的冻结符号**：`charging_cost.dart`（AP10 调用）、`map_consent_sheet.dart` 与 `map_privacy_page.dart`（AP09 调用）的公开签名不变。
- **动作**：P12、P13、P14、P16：分组卡与单行设置、外观浮动弹层、币种保持推入页面并改为分组选择列表、车辆区分信息、接入页单任务排版、地图设置三段分组（申请帮助与隐私说明折叠保留原位）、费用表单贴边弹层与单一滚动；冻结文案逐字不改（CP12）；其余文案条目；Material Icons 清零；文件守卫计数降到 0。
- **不做**：存储、控制器、HTTP 信任与原子替换、Key 存储、地图同意状态机、费用请求状态机。
- **测试**：上列 + `charging_cost_refresh_test.dart`、`map_key_test.dart`、`full_flow_test.dart`（只运行）。
- **完成**：加载、空车、错误、认证失效、隐私各态，长 URL、键盘与大字，复制、清除、换站、退出语义证据；费用 320×568、200%、键盘 300 下输入与提交两机位。映射 AQ03、AQ05、AQ07、AQ08。

### AP14 集成：跨页行为、无障碍、动效、开发期性能与守卫归零

- **持有文件**：能力迁移表、统一图册与 manifest、`test/support/`、跨页测试（`full_flow_test.dart`、`reading_integration_test.dart`、`reading_continuity_test.dart`、`overview_statistics_reading_test.dart`、`charging_reading_test.dart`、`charging_cost_refresh_test.dart`、`map_platform_test.dart`、`ui_ux_u07_test.dart`）、R22 旧别名清理与 Material `TextTheme` 映射更新（`typography.dart`、`tokens.dart`）、W4 适配层清理。具体产品修正交回原持有票，或由总控在集成窗口按符号修改并记录。
- **动作**：接收各票的测试补丁；全路径阅读、认证与车辆隔离、费用刷新、地图授权、焦点、系统偏好变化与连续导航；文案守卫与裸值守卫全局归零；沿 ADR0012 Q08 做开发期性能检查（每 route blur 区域数、外壳滚动只重建自身、ticker 隔离，具备设备时做前后 profile 对照）；before/after 全量对比，列出旧版做得更好的地方并处理；删除旧 token 别名与适配层并确认无调用。
- **完成**：全部能力有可达证据；R/P/M/CP/S 对照无悬空；动效、偏好与性能证据齐全。映射 AQ04–AQ09。

### AP15 完整验证、双端构建、双轴审查与交付

- **持有文件**：最终实施记录、验收矩阵、图册 README 与 manifest、经复核的最小修正。
- **动作**：全量 analyze、格式、测试、diff 检查；Android 与 iOS 隔离构建；Standards 与 Spec 双轴独立审查；Hallmark 收尾评审（独立上下文对照 before/after，回答「旧版哪里更好」）；汇总本地完成与 AQ10 外部待验；按当次授权处理 Git。
- **完成**：可追溯的输入与结果；P0/P1/P2 为 0；全部实际结果与未验证项；临时资源按 cleanup 规则处理。映射 AQ09、AQ10。

## 4. GitHub 映射草案

既有 #27–#40（U 批次）与本地 F00–F12 记录保留。本方案拟作为 #1 下新的设计增量父票「Spec 增量：Apple 质感精修（ADR0014）」，AP00–AP15（含 AP12a/b，共 17 张）为子票，依赖按 §1 建原生 blocked_by。用户已确认规格，发布时标签用 `ready-for-agent`。#11/#16/#17 继续承载地图、设备性能与整机外部条件。当前未发布，发布需单独授权。
