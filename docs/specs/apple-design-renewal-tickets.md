# Apple 风格界面焕新实施 Tickets

2026-11-14，状态为 **accepted，已实施，GitHub 待发布**。本地任务 ID 为 F00–F12，实际实施输入为 `main@5c7683f`。设计依据为[ADR0012](../adr/0012-apple-design-renewal.md)与[焕新规格](apple-design-renewal.md)，验证规则集中在[交付手册](apple-design-renewal-delivery.md)。

## 1. 任务图与接续

| ID | 标题 | 直接前置 | 所属阶段 |
| --- | --- | --- | --- |
| F00 | 当前基线与能力清单接续 | 已完成用户确认与实施授权 | 基线 |
| F01 | 排版、内容表面、磨砂材质与显示偏好基础 | F00 | 共享系统 |
| F02 | 统一导航、弹层和路由反馈 | F01 | 共享系统 |
| F03 | 图表、状态与操作反馈 | F01 | 共享系统 |
| F04 | 五个代表页面与设计冻结 | F02、F03 | 参考冻结 |
| F05 | 概览与行程阅读 | F04 | 页面并行 |
| F06 | 充电账本、双详情与地图呈现 | F04 | 页面并行 |
| F07 | 统计首页、长期索引与旧版回退 | F04 | 页面并行 |
| F08 | 五个统计专题与证据 | F04 | 页面并行 |
| F09 | 连接、认证、设置和通用选择 | F04 | 页面并行 |
| F10 | 费用补录表单 | F04 | 页面并行 |
| F11 | 跨页行为、无障碍与动态复核 | F05–F10 | 集成 |
| F12 | 完整验证、双轴审查与交付 | F11 | 收口 |

F02 与 F03 可在隔离 checkout 同时推进，F05–F10 可并行。F04 将代表候选直接形成于正式组件，随后把页面文件交还各页面包。输入为冻结提交、规格版本、token 差异和证据清单，全部接收后才进入并行阶段。

## 2. 每票通用合同

每票的输入包括 AGENTS.md、完整新规格、旧 S01–S08、前置交接、相关源码与测试。开工记录 `pwd`、HEAD、Git 状态和文件租约，退出时提交规则到符号、用例、渲染或录像的映射。测试使用现有可控 HTTP 与合成数据。渲染按交付手册的统一目录和命名组织。

单票完成条件为相关规则有证据、能力行有原新入口、验证失败已经归因并修正、共享接口变更已经接收。P0/P1/P2 与视觉阻断全部解决后才接收为完成。外部待验按 Q09 单列。每张票的测试文件均为当前已存在入口，新回归仅为捕获本包具体风险新增。

下文文件均相对于仓库根。`test/support/`、通用图册入口、能力表和共享导出归总控，页面包通过补丁请求接入，保持单一写入者。各票“验证”是运行清单，写入权按交付手册 §2 的测试租约执行。允许文件中的业务部分仍按 R20 保护。

### F00 当前基线与能力清单接续

- **输入**为 `5409783` 之后实际开工提交、U12 和当前 capability-map。
- **文件**为未来 `docs/implementation/apple-design-renewal/README.md`、`F00.md`、`capability-map.md` 与 before manifest。
- **动作**为核实后续修改，接续原 104 项及后续新增能力，记录实际路由、嵌入页、触发控件、数据与能力条件、当前/目标归宿、关联测试。逐页重新采集 before，记录源码与字体身份。
- **验证**为 analyze、现有 `reading_integration_test.dart` 与 `full_flow_test.dart`。基线失败与后续差异分开登记。
- **完成**为全部当前能力可追踪，五个代表页面与状态证据可复现，输出供 F01–F04 使用。映射 Q00、旧 S01–S08。

### F01 排版、内容表面、磨砂材质与显示偏好基础

- **文件**为 `lib/src/design/{tokens,semantic,typography,theme,layout}.dart`，基础组件 `{hero,metric,section,button,icon_button,data_row,copy_row,battery_arc,share_ring,soc_interval,focus_ring,map_frame}.dart`，新增建议为 `design/components/navigation_material.dart`、`design/display_preferences.dart`、`ios/Runner/DisplayPreferencesPlugin.swift`，以及 `lib/main.dart` 与 `ios/Runner/AppDelegate.swift` 的显示偏好注入/注册接缝。`ios/Runner.xcodeproj/project.pbxproj` 允许增加该 Swift 文件的 Runner Sources 归属。F01 提交共享导出补丁，由总控串行接收。
- **动作**为实现 R11–R14/R18，旧角色映射到 R12，完成 solid/磨砂双路径、系统偏好读取/变化/失败策略。R16/R17 的共享时长和图形常量也在本包集中声明，`MileafLayout.motion` 维持现有调用合同。iOS 桥接逻辑放专用源文件，AppDelegate 只注册，原生地图部分沿原输入。
- **验证**为 `design_tokens_test.dart`、`design_components_test.dart`、`appearance_shell_test.dart`、`share_ring_test.dart`，补显示偏好初始未知/失败/变更/恢复前台/销毁测试和材质对比测试。编译验证桥接文件的 target membership。
- **完成**为角色和基础组件图册、所有 token 值与新旧映射、两种材质对照、布尔桥接协议及失败行为均可复用。输出固定 API 给 F02/F03，映射 Q01/Q02/Q03/Q06。

### F02 统一导航、弹层和路由反馈

- **文件**为 `workspace_page.dart` 的壳层呈现，`design/components/{nav_bar,top_bar,page_bar,sheet,chip,chip_row}.dart`、`design/motion.dart`。F01 结束后接管 `theme.dart` 的 route transition 接缝，其余共享字段交原所有者修改。
- **动作**为 R15/R16 的 M01–M06，根导航、浮栏、实际遮挡测量、单一选中底、焦点 reveal、键盘/模态覆盖/地图 solid 策略。根顶栏沿已有 `topBar` 注入，固定布局适配接口供页面包接入，统计 overview 与嵌入专题的互斥顶栏规则一并冻结。保留 IndexedStack、ReadingScope、TickerMode 和导航目的地。
- **验证**为 `navigation_bar_test.dart`、`settings_navigation_test.dart`、`design_components_test.dart`、`appearance_shell_test.dart`、`reading_continuity_test.dart`，补连续点击/动画中减动效/安全区/底部末条记录可达/遮挡后焦点定位。
- **完成**为根页、二级页、弹层的统一几何及逐帧反馈证据，iOS/Android route 合同保持。输出测量与导航 API，映射 Q01/Q02/Q03/Q05/Q06。

### F03 图表、状态与操作反馈

- **文件**为 `design/components/{charts,category_bars,composition_bar,state_view}.dart`、`sample_chart.dart`。输入为 F01 冻结的 tokens 与现有 `MileafLayout.motion` 调用合同，独立于 F02 新增的导航和路由接口。F02 若提出共享 API 变化，由总控在两个包均接收后升级冻结版本。
- **动作**为 R16 的 M07/M08、R17/R19，轴测量、读值与证据关系、真实零与缺失、静态骨架、刷新快照反馈和手势仲裁。专题自绘由 F08 消费同一规则。
- **验证**为 `chart_marks_test.dart`、`a_micro_spark_test.dart`、`data_visualization_app_test.dart`、`readability_render_test.dart`、`ui_ux_u03_test.dart`，补首末点/极值/长轴标与动画中打断用例。
- **完成**为正负/零/null/单点/全空/稀疏/极值图板，普通刷新选点保留和减动效首帧完整证据。输出组件接缝给 F04/F08，映射 Q02–Q06。

### F04 五个代表页面与设计冻结

- **文件**为 `overview_page.dart`、`drives_page.dart`、`statistics_insights_page.dart`、`charging_detail.dart`、`charging_cost.dart` 的呈现，以及专属代表测试和参考记录。共享修改由 F01/F02/F03 原所有者串行接收。
- **动作**为正式组件上的五页完整布局，覆盖概览、行程、统计首页、充电详情和费用表单。展示浅深、长字段、键盘、错误、材质与 solid。采集 M01–M08 的组件/导航逐帧或录像证据，登记首屏预算。
- **验证**为相应现有页面测试、`a_gallery_render_test.dart`、`charging_cost_render_test.dart`，新增精确遮挡和首屏测量。候选与规格逐项目视，包含数据不规则场景。
- **完成**为总控按用户确认的规格冻结具名参考、token 表、组件 API、动效表与偏差账本。方向性修改或预算修订先获得用户裁定。页面包继承本提交，映射 Q00–Q06。

### F05 概览与行程阅读

- **文件**为 `overview_page.dart`、`drives_page.dart` 的呈现和对应专属测试。
- **动作**为完整迁移 P01/P02，统一根页上下文、同调车况、主图与记录层级，所有摘要、最近、继续、日历与说明均有能力归宿。
- **验证**为 `overview_briefing_test.dart`、`overview_statistics_reading_test.dart`、`overview_visualization_test.dart`、`drives_test.dart`、`ui_ux_u04_test.dart`、`ui_ux_u05_test.dart`、`reading_continuity_test.dart`。
- **完成**为两页全部状态、普通首屏预算、跨 Tab/详情返回和分页保留证据，映射 P01/P02、S01–S05、Q02/Q04/Q05。

### F06 充电账本、双详情与地图呈现

- **文件**为 `charging_page.dart`、`charging_method.dart` 的呈现、`charging_detail.dart`、`drive_detail_page.dart`、`map/{map_panel,drive_map_page}.dart` 的呈现及对应测试。费用补录组件作为 F10 只读接口。
- **动作**为 P03–P05/P15，完整账本、费用覆盖、构成环、SOC摘要、曲线、地图与所有降级状态，导航 solid 与原生地图边界一致。
- **验证**为 `charging_test.dart`、`charging_expansion_test.dart`、`charging_reading_test.dart`、`charging_cost_refresh_test.dart`、`charging_method_section_test.dart`、`drive_detail_test.dart`、`charging_detail_test.dart`、`map_platform_test.dart`、`ui_ux_u06_test.dart`、`ui_ux_u07_test.dart`。
- **完成**为正常/进行中/费用缺失/免费/未知币种/能力回退/地图各状态渲染与实际点击证据。采样、全图和返回可用，映射 S01/S04–S08、Q02/Q04/Q05/Q06。

### F07 统计首页、长期索引与旧版回退

- **文件**为 `statistics_insights_page.dart`、`statistics_page.dart` 的呈现及对应测试。专题调用参数与 `topicContext` 接口沿 F04 冻结版本。
- **动作**为 P06/P15，主结论、依据、图表、四专题、长期索引和完整指标页面，覆盖新旧能力组合。
- **验证**为 `statistics_insights_test.dart`、`statistics_test.dart`、`overview_statistics_reading_test.dart`、`ui_ux_u08_test.dart`。
- **完成**为四专题首行预算、全部指标/续航/停放可达、选择恢复和证据下钻原参数证据，映射 S01–S05、Q02/Q04/Q05。

### F08 五个统计专题与证据

- **文件**为 `statistics_{usage,conditions,charging,range,parking}_page.dart` 及其对应测试，各页中的证据呈现归本包。按 usage→conditions→charging→range→parking 顺序分段接收。
- **动作**为 P07–P11/P15、专题自绘轴与选点反馈，沿 F03 组件和 F04 接口。窗口、分母、观察限定与全部样本信息保持原口径。
- **验证**为 `statistics_{usage,conditions,charging,range,parking}_test.dart`、`ui_ux_u09{a,b,c,d,e}_test.dart` 和相关 reading 用例。
- **完成**为每专题普通/空/缺失/能力不足/错误及读值证据机位，S01–S05 与长期独立窗口通过，映射 Q02–Q06。

### F09 连接、认证、设置和通用选择

- **文件**为 `connection_page.dart`、`connection_management.dart`、`session_pages.dart`、`setup_page.dart`、`settings_page.dart`、`appearance_sheet.dart`、`map/{map_privacy_page,map_consent_sheet}.dart`。地图 Key 的输入与分组呈现在 `map_privacy_page.dart`，`map_key.dart` 的存储和控制器沿原合同只读。`workspace_page.dart` 的 `_VehicleSheet` 在 F02 完成交接后仅由本包修改。
- **动作**为 P12/P13/P16，分组行、输入层级、键盘、车辆选择与通用弹层。原状态机、存储和安全文字沿输入。
- **验证**为 `settings_navigation_test.dart`、`connection_management_test.dart`、`setup_test.dart`、`session_test.dart`、`map_key_page_test.dart`、`map_key_test.dart`、`ui_ux_u10_test.dart` 与设置/地图渲染入口。
- **完成**为加载/空车/错误/认证失效/隐私各状态、长URL与键盘大字，复制/清除/换站/退出语义证据，映射 S01/S08、Q02–Q06。

### F10 费用补录表单

- **文件**为 `charging_cost.dart` 的 Widget 呈现与对应费用测试，接续 F04 候选，保留自管路由与请求状态机。
- **动作**为 P14、R12/R15/R16，标题、输入、预览、状态、主动作以及键盘单一滚动。两入口消费同一表单。
- **验证**为 `charging_cost_test.dart`、`charging_cost_refresh_test.dart`、`charging_cost_render_test.dart`、`ui_ux_u11_test.dart`。
- **完成**为 0 元保护/403/409/401/超时/5xx/待确认/未知币种/成功局部刷新全覆盖，320 宽 200% 且键盘 300 的提交与关闭可达证据，映射 S06/S07、Q02/Q03/Q04/Q05。

### F11 跨页行为、无障碍与动态复核

- **文件**为能力迁移表、统一图册入口与 `test/support/`、跨页测试和验收证据。具体产品修正由原文件所有者接回，统一集成。
- **动作**为全路径阅读、认证/车辆隔离、费用刷新、地图授权、焦点、系统偏好变化和连续导航。比对所有 before/after，记录旧版做得更好的地方并处理。
- **验证**为 `full_flow_test.dart`、`reading_integration_test.dart`、`reading_continuity_test.dart`、`overview_statistics_reading_test.dart`、`charging_reading_test.dart`、`charging_cost_refresh_test.dart`、`map_platform_test.dart`，以及新布局命中/语义/动效测试。
- **完成**为全部能力有可达证据、R/P/S/Q 对照无悬空项，动态录像或采样与图像来源准确，映射 Q00–Q07。

### F12 完整验证、双轴审查与交付

- **文件**为最终实施记录、验收矩阵、图册 README/manifest 及经复核的最小修正。
- **动作**为完整工程验证、Android/iOS 隔离构建、Standards/Spec 独立审查，汇总本地完成和 Q09 待验。
- **验证**为全量 analyze/test、所改 Dart 格式、diff 检查、字体/图像 manifest 与双端构建。性能采样遵循 Q08/Q09，无设备时明确具体待验。
- **完成**为可追溯输入/结果提交、0 未解决 P0/P1/P2、全部实际结果与未验证项、资源处理。Git 操作沿当次授权。

## 3. GitHub 映射草案

既有 #27–#40 的 U 批次与本地实施记录继续保留。本方案拟作为 #1 下新的设计增量父票，F00–F12 为其子票，依赖采用上表的原生 blocked_by。父子与依赖分开核验。发布时正文沿本文件各节与新规格版本生成，回填实际编号与回读结果。

当前方案已获用户确认，本地实施已启动。GitHub 发布仍等待单独的外部写入授权。相关旧票如何结项由既有实施证据和当次追踪操作授权处理。#11/#16/#17 仍承载地图、设备性能和整机外部条件。票状态、视觉决定、本地工程结果在完成记录中分别列出。
