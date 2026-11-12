# 行笺 UI/UX 多 Agent 执行提示词

2026-11-12交付。提示词依据已确认的ADR0011、Spec #27及U00–U12整理，文档基准为286cd55，业务行为基准为2f8755c。产品实施从U00开始，U01代表视觉需按既有规格完成用户评审。

## 使用方式

每个文件包含一个完整text代码块。把所选文件中的整个代码块发给该Agent即可，任务身份、工单、必读文件、标准、边界、测试和交付已写入。任务交接记录在实施时创建，不能用本目录的提示词充当完成证据。

- 使用多个独立会话时，先把总控提示词交给负责汇总的人或Agent，由其登记实际输入版本并分派。
- 单一模型也可按同样顺序依次执行，保留交接记录后换模型继续。各模型使用同一验收，当前未对这些模型进行能力排序。
- 当前checkout含已提交的规格。若执行Agent只有GitHub访问能力，可读取#27完整正文及本任务票，再由总控提供包含实际源码和本地规格提交的checkout。文档基准尚未推送时不要假定origin/main已含这些文件。

## 调度图

U00 → U01 → U02 → U03 为串行基础。U01的候选提交、token变化和用户决定交给U02/U03继续，四个候选页由对应页面任务补齐。

| 执行线 | 任务顺序 | 交接重点 |
| --- | --- | --- |
| A | U04 → U05 | 概览下钻与列表阅读上下文 |
| B | U06 → U07 → U11 | 充电列表/详情的费用入口及共享地图呈现 |
| C | U08 → U09a → U09b → U09c → U09d → U09e → U10 | 专题共用接口、五专题证据和设置/车辆弹层 |
| 集成 | 三线完成 → U12 | 全量矩阵、跨页回归、隔离构建和两轴复核 |

三线是本次交付建议的调度安排，原生必要依赖继续沿13张工单的19条边。用户已要求多Agent执行方案，可在具备隔离checkout和单一文件所有者时并行。实际并行度取决于可用Agent和工具资源。

同一checkout中的写入、测试和Git操作串行安排。真正并行优先使用可复用的隔离checkout，按项目工具创建所需worktree。每线从U03已集成版本出发，线内接收前一任务的实际提交。读屏、真实地图、设备性能等待验项按原G09与#11/#16/#17承载。

## 提示词索引

| 文件 | Agent任务 | GitHub |
| --- | --- | --- |
| [coordinator.md](coordinator.md) | 总控、调度、共享修复与集成 | [Spec #27](https://github.com/wynnok/MileafMobile/issues/27) |
| [U00.md](U00.md) | U00 基线和能力清单 | [#28](https://github.com/wynnok/MileafMobile/issues/28) |
| [U01.md](U01.md) | U01 正式代表页和参考 | [#29](https://github.com/wynnok/MileafMobile/issues/29) |
| [U02.md](U02.md) | U02 共享系统 | [#30](https://github.com/wynnok/MileafMobile/issues/30) |
| [U03.md](U03.md) | U03 图表状态和动效 | [#31](https://github.com/wynnok/MileafMobile/issues/31) |
| [U04.md](U04.md) | U04 概览 | [#32](https://github.com/wynnok/MileafMobile/issues/32) |
| [U05.md](U05.md) | U05 行程 | [#33](https://github.com/wynnok/MileafMobile/issues/33) |
| [U06.md](U06.md) | U06 充电 | [#34](https://github.com/wynnok/MileafMobile/issues/34) |
| [U07.md](U07.md) | U07 两类详情与地图 | [#35](https://github.com/wynnok/MileafMobile/issues/35) |
| [U08.md](U08.md) | U08 统计首页 | [#36](https://github.com/wynnok/MileafMobile/issues/36) |
| [U09a.md](U09a.md) | U09a 节奏与证据 | [#37](https://github.com/wynnok/MileafMobile/issues/37) |
| [U09b.md](U09b.md) | U09b 温度与能耗条件 | [#37](https://github.com/wynnok/MileafMobile/issues/37) |
| [U09c.md](U09c.md) | U09c 补能统计 | [#37](https://github.com/wynnok/MileafMobile/issues/37) |
| [U09d.md](U09d.md) | U09d 长期续航 | [#37](https://github.com/wynnok/MileafMobile/issues/37) |
| [U09e.md](U09e.md) | U09e 停放观察 | [#37](https://github.com/wynnok/MileafMobile/issues/37) |
| [U10.md](U10.md) | U10 接入设置和弹层 | [#38](https://github.com/wynnok/MileafMobile/issues/38) |
| [U11.md](U11.md) | U11 费用表单 | [#39](https://github.com/wynnok/MileafMobile/issues/39) |
| [U12.md](U12.md) | U12 集成与最终验收 | [#40](https://github.com/wynnok/MileafMobile/issues/40) |
| [standards-review.md](standards-review.md) | 仓库规范和工程约束审查 | 当前任务范围 |
| [spec-review.md](spec-review.md) | 规格、能力和用户行为审查 | 当前任务范围 |

U09a–e仍归#37，逐包记录及测试后汇总为U09结果，沿现有工单追踪。

## 文件和测试所有者

- U01串行阶段持有正式共享候选及行程/统计/充电详情/费用表单的候选修改。后续页面Agent首先核对这些成果，补齐完整页面与状态。
- U02负责tokens/semantic/typography/theme/layout及其列明组件，U03接续图表/状态/动效及必要几何。页面并行阶段由总控协调共享修复，确认后由原负责人串行产出补丁。
- U04仅overview_page，U05仅drives_page，U06仅charging_page及charging_method纯呈现，U07仅两详情和内嵌/展开地图呈现，U08仅统计首页和回退。
- U09a负责usage及共享Facts/Notes/Evidence接口，U09b/c/d/e分别负责conditions/charging/range/parking专题。各子包按顺序接收共用接口。
- U10负责已列接入/设置/外观/币种/车辆弹层，workspace_page仅车辆弹层，currency仅呈现。U11负责charging_cost表单呈现。业务客户端、controller和生成DTO按规格只读。
- 普通专属测试跟随被测主模块。map_key_page_test由U10维护，charging_cost_test由U11维护，U07可运行这两文件但只提交自身专属用例或修改请求。
- 以下共享测试及全部test/support由总控统一安排写入。其他Agent可只读运行或提交明确用例。基础串行阶段总控可把具体文件独占授予当前包并记录，页面并行阶段由总控集中修改。

- `test/a_gallery_render_test.dart`
- `test/a_overview_render_test.dart`
- `test/a_charging_method_render_test.dart`
- `test/design_gallery_render_test.dart`
- `test/reading_restore_render_test.dart`
- `test/readability_render_test.dart`
- `test/settings_render_test.dart`
- `test/map_key_render_test.dart`
- `test/charging_cost_render_test.dart`
- `test/overview_statistics_reading_test.dart`
- `test/reading_continuity_test.dart`
- `test/reading_integration_test.dart`
- `test/charging_cost_refresh_test.dart`

测试列表既包含可修改的本包测试，也包含需只读运行的跨包回归。归属以本节为准，读取整个原任务所列测试以理解行为。确需新增测试时，说明旧测试漏掉的具体回退，优先扩展已有专属文件。

## 渲染、审查与Git

正式图册根为 docs/implementation/ui-ux-refinement-renders/，总控分配每包图像文件名，README集中维护。现有入口批量输出多页时使用串行发布窗口或任务专用临时输出，仅保留本包已分配的交付图。共享render入口改动由总控收敛。

各包在自身记录中写实际输入源码、规则映射、命令/退出码/通过失败跳过、图片及目视清单、偏差、待验、共享请求和结果提交。每包审查使用实际baseCommit与结果，U12在最终集成版本复核。原生工单状态和代码集成事实分别检查，已满足代码前置可在既有授权内接续，线上状态差异列给总控处理。

本地实施和本地提交由实际分派的提示词界定，GitHub写入、Git推送、部署和设备安装依据用户当次明确授权。不同模型可使用等价测试/审查工作流，缺工具时报告实际阻断和仍可完成的工作，任何通过声明必须有实际证据。

完整规则与验证矩阵来自 [规格](../../specs/ui-ux-refinement.md) 和 [交付手册](../../specs/ui-ux-refinement-delivery.md)，旧条款关系见规格§1.4。
