# 行笺 UI/UX 优化：实施任务与验收手册

GitHub正式增量Spec为[#27](https://github.com/wynnok/MileafMobile/issues/27)，U00–U12映射见[实施Tickets](ui-ux-refinement-tickets.md)。

版本1.0，2026-11-12。状态为confirmed，产品实施U00–U12待开始。配套[规格](ui-ux-refinement.md)、[Tickets](ui-ux-refinement-tickets.md)及[审计](../product/ui-ux-refinement-audit.md)。

本手册面向任意实施Agent；不依赖原对话、模型名称或其审美自由发挥。GPT-6.1 Sol、DeepSeek v4.1 flash、GLM-5.3-flash等使用相同规则与验收，不按模型降低标准。未在本轮测试这些模型的实现能力。

## 1. 执行策略与授权

实施顺序：先锁定可见参考，再改共享系统，再逐页迁移，最后整体验证。每次只交一个能完整验证的任务包，不把“整体优化”直接作为无人复核的大任务。

用户于2026-11-12确认正式文档更新与GitHub发布，本轮按implement流程提交文档和发布映射。以下产品任务在用户后续要求实施后执行。执行时读取当前AGENTS、任务依赖和用户指令，并据当次授权处理提交与发布。

正常本地读、改、测试不重复询问许可；只有实际范围冲突、数据/安全行为改变、未获批准的设计偏差才提请裁决。代表页视觉检查沿项目既有“先交付可视方案”要求执行，不用skill另造新的审批层。

### 1.1 依赖

```text
U00 基线与能力清单
 └─ U01 代表页与规则校准（视觉基线确认）
     └─ U02 共享排版/控件/表面
         └─ U03 图表/状态/动效基础
             ├─ U04 概览
             ├─ U05 行程
             ├─ U06 充电
             ├─ U07 两类详情与地图降级
             ├─ U08 统计首页与回退
             ├─ U09 五专题与证据
             ├─ U10 接入/设置/弹层
             └─ U11 费用表单
                 全部完成 → U12 集成、审查与交付
```

默认顺序执行U04→U11。只有用户或适用技能明确允许并行Agent，才可把独立页面分派；共享tokens、charts、workspace不得多人同时编辑。共享文件由U02/U03负责人修改，页面Agent提交接口需求，不复制共享实现。并行时U08/U09的专题入口接口和U06/U11的费用动作接口也需单一所有者。

### 1.2 变更范围约定

下面源码路径相对 `lib/src/`，测试相对 `test/`。每包的“允许”不代表必须改所有文件。允许改对应渲染入口/夹具，但不能以篡改数据绕过缺陷。新增文件先在任务回报列出用途。所有包禁止改生成契约、后端链接仓库、安全存储、依赖版本、API计算口径；其他文件未列入时先检查是否只是共同组件需求。

## 2. U00–U12 任务包

### U00 基线、路径与不可丢能力清单

- 输入：三份方案、AGENTS、当前Git、`visualization-requirements.md` V01–V08/A01–A06、现有Spec与测试。
- 允许：实施记录和能力迁移表；不改产品。
- 动作：记录当前commit/branch/status、工具链；确认 `2f8755c` 后续差异；运行一次基线analyze/test；列所有用户可达路由/内嵌页、能力回退、操作入口。读取数据契约只读，不访问生产。
- **能力迁移表每行**：指标/操作ID、原页面/入口、源码symbol、数据来源/口径、当前可见条件、目标页面/入口、测试名。至少逐项覆盖V01–V08和费用/地图/设置增量；不以“数据说明里都有”代替逐项定位。
- 完成：表内每项有唯一主要归宿；未支持能力仍标未支持；基线失败与新增失败分清。原有教程两项修改单独记录并保留。
- 验收：G00；审计A15。缺基线通过证据不宣称已通过，但可完成不受阻的文档/局部工作。

### U01 代表页面、数值校准和规范冻结

- 输入为U00迁移表、规格全部R及P02/P06/P05/P14。U01先读取U02/U03的共享文件范围，候选所需token与图表改动由U01统一持有，U02/U03在同一工作成果上继续。
- 交付：使用正式Flutter组件的行程列表、统计首页、充电详情、费用表单代表渲染；优先行程+统计，随后验证详情和键盘。不要画HTML仿制截图、图片合成UI或仅展示设计组件样板。
- 允许在正式共享tokens和组件上做候选改动并渲染指定代表页。开工先列文件，形成单一候选diff和token变化表。U01只完成代表范围及可见参考，记录其余页面尚待迁移的影响。U02接续同一diff完成全局收敛，禁止维护候选专用主题、复制产品UI或回滚已确认参考后另做一套。
- 矩阵：四页×浅深×100/200%×360宽；行程/统计补320与390普通字；费用补320宽200%键盘300；至少一个真实不规则合成数据场景。
- 校准：逐项测量首屏预算、主次层级、字号、边距、长字段；无法同时满足时按规格§5报告精确冲突。用户确认后的图成为具名参考，附输入commit、数据夹具、字体路径/身份、viewport、scale；不得只有无来源PNG。
- 完成：代表视觉已确认，或用户明确授权按候选继续且保留待验；所有规则偏差已列出，没有“到时候再看”的自由项。未获得需要的确认不能把它标通过。
- 规范动作：实施记录追加“被采纳规则/旧条款替代”索引；必要时按仓库domain规则形成新ADR增量，不伪造历史accepted状态。
- 验收：G01/G02/G03；A01–A06/A16。参考确认后才全面推广，不要求用户逐页重选主题。

### U02 共享排版、布局、控件与表面

- 允许：`design/tokens.dart`、`semantic.dart`、`typography.dart`、`theme.dart`、`layout.dart`；`design/components/{hero,metric,section,button,icon_button,chip,chip_row,nav_bar,top_bar,data_row,copy_row,sheet,battery_arc,share_ring,soc_interval}.dart`；共享互斥组件与导出。
- 必须：R01–R05落地；旧字段映射新角色；自绘/环中心文字不遗漏；实际命中区44；输入controlBorder对比；移除光晕和底栏模糊；保持已有callback、Semantics、Key、route hook。
- 验证：`design_tokens_test.dart`、`design_components_test.dart`、`appearance_shell_test.dart`、`share_ring_test.dart`；新增实际坐标命中、200%布局、对比度断言。旧token精确值断言可以按本规格改，但写出对应R编号；不降低比例阈值。
- 完成：接收U01候选diff和token变化表，确认参考无回退。组件图册浅深/100/200、短长文本、焦点/禁用/处理中全覆盖，每种角色在组件图册可查。页面未迁移的布局问题清单交后续包。
- 验收：G02/G03/G04；A01/A04/A08/A12。

### U03 图表、状态和动效基础

- 允许：`design/components/{charts,category_bars,composition_bar,state_view}.dart`、`design/motion.dart`、`sample_chart.dart`；必要的共享几何token（单一所有者）；专题Painter改动留U09。
- 必须：R06–R08；主图自适应轴留白、完整文字放大、真实零/缺失、读值与比较区间、无绘图生长；静态骨架；保留键盘/横拖/语义增减；普通刷新不重置选点。
- 验证：`chart_marks_test.dart`、`a_micro_spark_test.dart`、`data_visualization_app_test.dart`、`readability_render_test.dart`；增加纵拖页面/横拖选点、首末点/极值不裁切、禁动效即时完整图形测试。
- 完成：展示正/负/0/null/单点/全空/极值/稀疏/长轴标；轴与读值一致，单位不同不共轴。未测读屏设备只报语义自动化。
- 验收：G03/G04/G05；A06/A07/A13/A14。

### U04 概览

- 允许：`overview_page.dart`的呈现、对应测试/render fixture。
- 必须：P01；迁移表逐项覆盖车况、今日、期间、比较、充电/驾驶、最近记录、继续探索、说明；资源独立错误恢复；不删V01指标。
- 验证：`a_overview_test.dart`、`overview_briefing_test.dart`、`overview_a_regression_test.dart`、`overview_statistics_reading_test.dart`、`overview_visualization_test.dart`、`overview_verification_test.dart`。
- 完成：首屏主图目标达标；未知续航、大字长车名不失序；返回保持期间/滚动/选点；费用变化不切Tab。
- 验收：P01、S01–S05、G02/G05/G06；A01/A04/A14/A15。

### U05 行程

- 允许：`drives_page.dart`呈现、对应测试。
- 必须：P02；记录提前但节奏仍在；全量指标、日期/看当天、分页、正在进行的行程语义保留。
- 验证：`drives_test.dart`、`a_drives_test.dart`、`collage_drives_test.dart`、`reading_continuity_test.dart`；新增首屏记录坐标断言和长起终点。
- 完成：同一夹具同一viewport对照可见记录增加；记录点击/日期下钻不改变原请求参数；返回保留已加载页。
- 验收：P02、S01–S05、G02/G06；A02/A05/A15。

### U06 充电

- 允许：`charging_page.dart`、必要的`charging_method.dart`纯呈现接缝；对应测试。不得改费用模块状态机。
- 必须：P03；紧凑费用与覆盖、补能图、记录、构成环、地点账目全可达；保持active判定、旧版能力、未知币种。
- 验证：`charging_test.dart`、`a_charging_test.dart`、`charging_expansion_test.dart`、`charging_method_test.dart`、`charging_method_section_test.dart`、`charging_reading_test.dart`、`charging_cost_refresh_test.dart`。
- 完成：普通/进行中/费用缺失/全免费/未知分类/分页失败/能力回退均有证据；补录局部按钮不导航。
- 验收：P03、S04–S07、G02/G06；A02/A04/A15。

### U07 行程和充电详情、地图降级

- 允许：`drive_detail_page.dart`、`charging_detail.dart`、`map/map_panel.dart`的呈现边界、`map/drive_map_page.dart`呈现、相关测试。地图controller、原生平台实现只读。
- 必须：P04/P05；主图优先、去重复摘要、SOC横排、地图状态与路线分区；保留真实地图授权顺序、所有过程字段和旧契约分支。
- 验证：`drive_detail_test.dart`、`a_drive_detail_test.dart`、`charging_detail_test.dart`、`a_charging_detail_test.dart`、`map_platform_test.dart`、`map_key_page_test.dart`、`charging_cost_test.dart`。
- 完成：已配置/无Key/未同意/待重启/失败/无轨迹；功率/SOC/速度/海拔全覆盖；全图返回不重置；不新增地图SDK加载或重复series下载。抽测记录ID在说明层可查。
- 验收：P04/P05/P15、S01/S05/S08、G02/G06；A05/A09。

### U08 统计首页及回退

- 允许：`statistics_insights_page.dart`、`statistics_page.dart`、相关测试；不要重写日期controller。
- 必须：P06；真实比较、同底主图、专题首行提前、全部指标保留；能力不支持时不掉空页面。
- 验证：`statistics_insights_test.dart`、`a_statistics_test.dart`、`statistics_test.dart`、`overview_statistics_reading_test.dart`；测试普通返回与显式概览下钻的期间差异。
- 完成：每个专题入口/全部指标/依据在新布局有稳定定位；不可比仅原值，无假差值；大字单列可达。
- 验收：P06、S02/S04/S05、G02/G06；A03/A06/A15。

### U09 五专题与证据

- 允许：`statistics_{usage,conditions,charging,range,parking}_page.dart`及对应测试；共享图表接口只调用不分叉。
- 子包顺序：U09a节奏与证据 → U09b能耗条件 → U09c补能 → U09d长期 → U09e停放。每包单独报告，不一次改五个大文件后才测试。
- 必须：P07–P11/P15、R06分档/纹理与大字；所有有效样本/覆盖/口径限制就近；日历44命中无法容纳时按规定换布局。
- 验证：`statistics_usage_test.dart`、`statistics_conditions_test.dart`、`statistics_charging_test.dart`、`statistics_range_test.dart`、`statistics_parking_test.dart`。每个子包运行其自身及共享图形测试，最后五组一起跑。
- 完成：零、未知、稀疏、极值、未结束月、低样本、正负变化、不同能力；每个新编码都有精确文字后备和单位；证据页返回语义不变。
- 验收：G02–G06；A07/A10/A11。

### U10 接入、设置和通用弹层

- 允许：`settings_page.dart`、`connection_management.dart`、`connection_page.dart`、`session_pages.dart`、`setup_page.dart`、`appearance_sheet.dart`、`currency.dart`呈现、`workspace_page.dart`车辆弹层呈现、`map/map_privacy_page.dart`；对应测试。
- 必须：P12/P13/P16；跟随新组件，不改外观持久化/币种推断/HTTP信任/Key授权；危险操作确认原样有效；长URL、长车辆名、键盘与复制完整值。
- 验证：`settings_navigation_test.dart`、`connection_management_test.dart`、`setup_test.dart`、`session_test.dart`、`map_key_page_test.dart`、`map_key_test.dart`、`appearance_shell_test.dart`。接入完整流程补正式render入口，不能只检查设置首页。
- 完成：所有入口可达、控件状态统一、初始接入到主界面完整演练；两份已修改教程不得覆盖，若可见词变化只做可审查增量。
- 验收：G03/G04/G06；A12/A17。

### U11 费用补录表单

- 允许：`charging_cost.dart`的Widget布局和文案排版、`charging_cost_render_test.dart`等相关测试。状态枚举、预检、请求和重试行为只读。
- 必须：P14/S06/S07；未知币种与0元、长地点/最大金额/小屏键盘；提交中锁定、401关闭、待确认先查询。
- 验证：`charging_cost_test.dart`、`charging_cost_refresh_test.dart`、`charging_cost_render_test.dart`、`reading_integration_test.dart`；真实坐标输入/滚动/提交，不能只调用回调。
- 完成：两个入口完全共用；输入机位和动作机位都完整；错误恢复保留输入；成功而汇总失败仍正确报告成功。
- 验收：G03/G06；A16。

### U12 集成、复核与交付

- 输入：U00–U11完成记录、参考图、差异账本。
- 动作：检查所有指标/入口迁移表闭合；analyze、全量test、正式新一代图册、语义和手势回归；按项目wrapper隔离构建；做Standards与Spec两轴独立复核。可以同Agent分两次复核，也可在被授权时使用独立审查Agent，不能虚构独立性。
- 完成：G00–G08状态逐项有证据；G09明确待验项和所需设备/权限；无未解释skip/失败；相关设计/教程引用同步；Git diff只含授权改动。
- 收尾：仅清理本任务确认拥有的临时资源，按cleanup skill；保留依赖和交付图册；不删除旧图册、不提交或推送除非另获授权。

## 3. 共同验收闸门

| ID | 检查 | 通过标准 | 证据 |
| --- | --- | --- | --- |
| G00 基线 | commit、工具链、既有修改、能力清单 | 来源明确，每项迁移有落点；既有失败单列 | 基线记录、迁移表 |
| G01 视觉方向 | 代表页参考 | 用户确认/明确授权继续的状态真实记录；无未裁决关键偏差 | 同条件参考图、决定记录 |
| G02 静态视觉 | 字号/间距/圆角/首屏/色彩 | 服从R01–R06及P目标；对齐锚点偏差≤1逻辑px；无截字、覆盖、无意孤行 | 尺寸断言、浅深截图及人工逐项记录 |
| G03 可访问性 | 字体、触控、对比、语义、键盘 | 320×200%可完成所有主要操作；命中≥44×44；图轴完整缩放；无失焦/重复朗读 | 坐标与Semantics测试、键盘机位；设备读屏另G09 |
| G04 状态 | normal/loading/empty/missing/stale/error/unsupported | 局部加载/错误，非假0、非假成功，旧数据归属可见 | 可控HTTP及截图 |
| G05 动效/图形 | 减少动效、数据和手势 | 禁动效即时终态；无重新画线；纵滚/横拖正确；参考和数据尺度真实 | widget逐帧、手势测试与录屏（可用时） |
| G06 行为 | S01–S08 | 既有安全/计算/阅读/费用/地图语义无回退；新增重排动作可达 | 既有回归+新增跨页用例 |
| G07 工程 | 分析、格式、测试、diff、隔离构建 | 新增诊断0、失败0；skip全部说明；构建输入与最终源码一致 | 命令/退出码/统计/输入commit或diff摘要 |
| G08 人工审查 | Standards和Spec、像素与任务流程 | 无阻断缺陷；所有规则有证据；未知明确标待验 | 两轴报告、修复与复测 |
| G09 外部条件 | 真机字体/键盘/读屏/性能/地图/真实站点 | 仅实测后可标通过，未具备条件记待验及原因 | 设备/系统/字体/站点范围、操作记录 |

G02的1px仅用于同一渲染环境中的几何锚点，不要求跨平台抗锯齿逐像素相同。禁止通过更换字体/降低DPR/调整夹具让golden变好看。小数值比较使用领域规则，不对所有浮点强行逐字相等。

### 3.1 阻断分级

- **Blocker**：数据/身份/费用/授权变化；任何不可达主动作；溢出、截断重要信息；缺能力入口；假零/假成功；关键对比或触控不达标；参考方向未经所需确认；新增测试失败。
- **Major**：首屏目标不符、页面角色/主次不符、未列明的token/动效偏差、图表编码误导。必须修复或用户明确接受规格变更；实施Agent不能自签豁免。
- **Minor**：不影响操作/含义的细节（如受平台字形影响的光学对齐）。记录修复或明确延期；不以“主观审美”掩盖硬规则。

只有文案/像素断言因批准设计确实需要改变时可更新测试；每项写“原期望→新期望→规格ID”。禁止删除断言、提高金图容差到看不见回退、增加skip或标记expectedFailure逃避问题。

## 4. 验证矩阵和图册

### 4.1 必测覆盖（不是全维度盲目笛卡尔积）

| 层 | 覆盖 |
| --- | --- |
| 核心视觉 | P01–P11共11页面，360×800，浅/深×100/200%；每页正常/空/字段缺失 =132主机位 |
| 边界布局 | 11页在320×568×200%、390×844×100%、768×1024×200%各一组；浅深交替，若出现颜色/布局耦合则补另一模式 |
| 中间字号 | P01/P02/P03/P06/P14在130%、150%，核验切布局边界；必要时用非线性TextScaler |
| 流程表单 | P12/P13/P14/P16所有表单/弹层在360×800×100%浅深正常态；320×568×200%浅深键盘inset300、长文本、字段错误、处理中、结果待确认（只对适用表单） |
| 地图 | 行程/充电详情与地图设置：无Key/未同意/已配置/失败/待重启/无轨迹；至少360浅100、320深200；真实底图单列G09 |
| 阅读恢复 | 四主Tab切换与返回；概览→统计显式下钻；日期选择取消/确认；详情覆盖/返回；费用写入期间隐藏页；换车/401/旧请求迟到 |
| 非理想数据 | 单点、全零、全缺失、零与缺失交错、极端长数字、负值、异常峰值、低样本、不可比、DST/跨年/未结束月、未知币种/分类、旧能力 |
| 完整滚动 | 每页至少浅100全滚动序列；200%至少到达最后一个内容和动作；不能只有首屏漂亮 |
| 控件 | 所有状态、选中/非选中、focus、禁用、长标签、减动效、触控边缘坐标 |

相同场景可复用一张截图满足多项，不盲目重复输出；README列出每项映射到哪个场景。没有对应语义的状态标N/A并写原因，不能制造不存在的后端状态。

数据夹具使用可重复的固定日期/固定站点时区/明确合成数据。新增不规则序列必须服务语义：例如`0、12、null、65、8、120、4`仅在该DTO允许null时使用；非空契约用独立场景表示缺失资源。总计、分母与图形数据需自洽，不能为首屏假造记录数量。

### 4.2 图册和视觉复核记录

新一代唯一输出根：`docs/implementation/ui-ux-refinement-renders/`（实施时创建，本轮不创建）。子目录按`gallery/、flows/、states/、reading/、components/`，命名`页面-场景-模式-宽度-字号-机位.png`。跨Agent复用同一根，不能再建模型名或批次名平行图册。

README记录：生成源码commit/未提交diff摘要、入口、实际命令、viewport/safeArea/DPR、字体文件身份、HTTP夹具、截图数、逐张目视列表、未检查列表、外部限制。当前readability图册只读作before；不能据历史README里“工作树未提交”判断当前Git状态。

每张关键图人工回答：首先看到什么？主操作是什么？有无重复数据/标签？单位/缺失/覆盖清楚吗？最小文字可读吗？左右锚点/数字基线一致吗？下方内容是否可发现？有无状态遮挡或难以点击？记录具体发现，禁止“整体不错”作为验收。

## 5. 命令与证据要求

### 5.1 必须实际走完的任务路径

这些是可控HTTP的端到端验收脚本，测试通过后仍需人工在参考渲染/可运行App核对。点击次数从指定起点算，不含测试启动；输入动作和滚动单列，不能靠测试直接调用内部方法省略操作。

| 场景 | 起点与动作 | 预期结果/限制 |
| --- | --- | --- |
| T01 找最近行程 | 行程Tab默认态 → 点第一条记录 | 一次点击进入正确ID详情；普通夹具首屏第一条完整；返回原位置 |
| T02 看某天出行 | 行程节奏选中日 → 看当天 → 记录 | 两个明确动作后到所选日记录，再一次进入详情；请求时区与日界正确 |
| T03 看用车能耗 | 统计首页 → 能耗 | 一次点击进原energy专题，期间继承；返回保持主图选点 |
| T04 查看长期与停放 | 统计首页 → 长期 → 续航/停放 | 两次点击分别可达；续航保持独立6/12月，不把主周期误传为窗口 |
| T05 补录费用 | 符合条件记录 → 补录 → 输入 → 提交 | 点击补录不打开详情；测试只出现一次PATCH；待确认时只有查询/显式后续操作，无自动重发 |
| T06 改日期后返回 | 概览近7天选点/滚动 → 切行程 → 返回 | 期间、选点和滚动保留；隐藏期间无新读；明确下钻统计才覆盖目标周期 |
| T07 地图恢复 | 详情无Key → 配置入口 → 保存/返回 | 不泄漏Key；未授权不加载底图；待重启准确提示；曲线仍可读 |
| T08 失败恢复 | 读取失败/旧快照 → 重试；费用成功后汇总失败 | 仅相关资源刷新；数据归属清楚；费用成功不反转为失败/可重提交 |
| T09 大字键盘 | 320×568/200%，费用或连接编辑 → 聚焦 → 滚到动作 → 操作 | 输入可编辑，动作实际命中，错误可见；不存在只能隐藏键盘才找到未知动作的死路 |
| T10 换车/失效 | 有旧数据且请求在途 → 换车或401 → 旧响应到达 | 新身份不显示旧数据，旧表单不能提交，旧请求不覆盖新状态 |

如果已有路径点击数与上述不符，先检查是否遗漏框架确认/既有安全步骤；安全确认不得删掉换取点击数，记录并修订该脚本的安全步骤例外。

### 5.2 工具与运行

命令必须先核对cwd，使用项目现有wrapper和本地依赖；以下是实施命令模板，不是本轮已运行结果。

```sh
pwd
git status --short
git rev-parse HEAD
./tool/flutterw analyze --no-pub
./tool/flutterw test --no-pub test/design_tokens_test.dart test/design_components_test.dart
# 页面任务按U包选择相关文件；完成后全量
./tool/flutterw test --no-pub
git diff --check
```

格式检查使用 `./tool/flutterw dart format --output=none --set-exit-if-changed` 加本任务明确文件列表，不对用户未相关修改全仓格式化。

渲染沿现有opt-in机制，启动前检查 `test/support/render_fonts.dart` 和图册README，确认本机中文字体路径存在；不把中文字体注册成Inter。例：

```sh
./tool/flutterw test --no-pub test/a_gallery_render_test.dart \
  --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/ui-ux-refinement-renders/gallery \
  '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'
```

上述字体路径仅为当前macOS可用示例，其他宿主使用经核验的本机字体，记录差异；不全局安装字体。新机位需扩展原测试入口或新增具名入口；未修改入口前不能声称已有测试支持全部新矩阵。P12设置沿 `MILEAF_SETTINGS_RENDER_OUTPUT`、地图沿 `MILEAF_MAP_RENDER_OUTPUT`；费用等沿 `MILEAF_RENDER_OUTPUT`，具体以入口源码为准。

Android/iOS构建：先读取 `docs/implementation/build-isolation.md`、`toolchain.md` 和当前 `tool/flutterw` 支持入口，沿冻结工具链/项目CocoaPods/进程沙箱执行，不复制历史过期环境变量，不绕探针。签名/设备run/install/drive与真实验收不包含在本地视觉任务中。无法构建时记录实际阻断，不把analyze通过写成构建通过。

开发期性能回归检查在同设备/profile模式同数据量下进行，前后各重复三次固定操作（四Tab切换、列表连续滚动、图表拖动、打开详情、打开费用表单）。记录UI/raster p95、慢帧数、峰值内存、请求数；相对基线持续退化>10%作为调查触发条件，记录并解释差异。正式性能验收执行GitHub #16原协议，每平台每指标至少30个独立样本，冷启动p95≤2s、热恢复p95≤800ms、详情含默认曲线p95≤1.5s，底图单列。设备、网络、规模、端点定义及全部失败样本按#16登记。60Hz的16.7ms/120Hz的8.3ms只作为刷新率对应帧预算，不是本轮未经测量的达标声明。无设备时仅能证明无新增请求/无限动画等自动化指标，设备性能保留G09。

## 6. Agent交接模板

### 6.1 实施提示词（替换任务ID即可）

```text
在当前MileafMobile工作区实施 Uxx。
已授权范围：按 docs/specs/ui-ux-refinement.md 和
docs/specs/ui-ux-refinement-delivery.md 的该任务包进行本地代码、测试和渲染工作。
开始先读 AGENTS.md、两份规格、审计里对应A编号、任务允许文件及相关测试。
检查当前commit与2f8755c差异、git status；保留所有既有修改，不清理别人资源。
继承已确认的U01参考和偏差账本；不重新选主题，不新增设计风格。
只实现本包，不提前修改后续包或未列的业务/状态/网络文件。
执行本包验证并报告实际结果；测试失败先诊断，不删测试或放宽业务断言。
完成时输出：规格映射、文件、行为保留、命令与结果、截图路径、未验证项、依赖给下包的接口。
除非用户在本次实施明确授权，否则不提交、不推送、不修改GitHub、不部署。
若当前任务依赖未完成，先指出具体缺项；可以完成不依赖它的准备，但不得自行假定已确认。
```

### 6.2 每包完成记录

```text
任务：Uxx；输入commit：…；实际改动摘要：…
规则：Rxx / Pxx / Sxx / Axx → 文件symbol → 测试名 → 截图
能力迁移：原入口 → 新入口；不可达项0或具体清单
行为/网络：是否改变请求、生命周期、费用、授权（预期均无）
校验：完整命令、退出码、通过/失败/跳过数量、skip理由
目视：逐张查看的路径和发现；未目视部分明确列出
偏差：规则ID、触发条件、证据、处理/裁定状态
资源：新增后台进程/临时目录/交付物；清理或保留原因
下包：接口变更、待办；不能留无编号的“再优化一下”
Git：本包文件、原有用户修改保持情况；提交/推送状态
```

### 6.3 审查提示词

```text
只审查，不修改。读取当前任务的基线diff、规格和真实测试/图册证据。
Standards轴：仓库约束、token/组件复用、无额外依赖、命中/语义/字体/减动效、用户修改保护。
Spec轴：逐条R/P/S/G，指标与入口完整、首屏目标、所有状态、费用/身份/地图安全语义。
先看图再看实现解释；对照同条件before/after，指出旧版做得更好的地方。
报告只写可定位可复现问题：严重度、文件/行或symbol、场景、影响、违反规则、最小修正。
没有执行/看过的内容不能标通过。测试通过不等于视觉通过，静态截图不等于动态/真机通过。
```

## 7. 最终交付清单

- 三份方案与已采纳增量索引，U00能力迁移表和U01参考决定。
- U00–U12逐包记录；R/P/S/G证据映射，无悬空项。
- 唯一新一代图册及准确可复现README，before/after同机位对照。
- analyze、全量测试、格式、diff、构建的真实结果与skip/阻断说明。
- Standards/Spec两轴问题及修复复核，剩余Minor与外部G09清单。
- 最终Git范围、用户修改保护、临时资源处理、未提交/推送/部署状态。

“代码通过”“视觉通过”“可控HTTP行为通过”“设备与真实站点通过”分别报告，绝不合并成一句“全部验收完成”。
