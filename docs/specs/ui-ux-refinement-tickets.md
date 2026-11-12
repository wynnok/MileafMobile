# 整体 UI/UX 优化实施 Tickets

2026-11-12，状态为confirmed。用户确认文档正式化与GitHub发布。U00–U12共13个产品任务待开始。设计规则见[规格](ui-ux-refinement.md)，执行步骤与测试文件见[交付手册](ui-ux-refinement-delivery.md)，取舍见[ADR0011](../adr/0011-ui-ux-refinement.md)。

## 任务及依赖

| ID | 任务 | 原生阻塞前置 | GitHub |
| --- | --- | --- | --- |
| U00 | 基线、路径与不可丢能力清单 | 无 | [#28](https://github.com/wynnok/MileafMobile/issues/28) |
| U01 | 代表页面、数值校准和规范冻结 | U00 | [#29](https://github.com/wynnok/MileafMobile/issues/29) |
| U02 | 共享排版、布局、控件与表面 | U01 | [#30](https://github.com/wynnok/MileafMobile/issues/30) |
| U03 | 图表、状态和动效基础 | U02 | [#31](https://github.com/wynnok/MileafMobile/issues/31) |
| U04 | 概览 | U03 | [#32](https://github.com/wynnok/MileafMobile/issues/32) |
| U05 | 行程 | U03 | [#33](https://github.com/wynnok/MileafMobile/issues/33) |
| U06 | 充电 | U03 | [#34](https://github.com/wynnok/MileafMobile/issues/34) |
| U07 | 行程和充电详情、地图降级 | U03 | [#35](https://github.com/wynnok/MileafMobile/issues/35) |
| U08 | 统计首页及回退 | U03 | [#36](https://github.com/wynnok/MileafMobile/issues/36) |
| U09 | 五专题与证据 | U03 | [#37](https://github.com/wynnok/MileafMobile/issues/37) |
| U10 | 接入、设置和通用弹层 | U03 | [#38](https://github.com/wynnok/MileafMobile/issues/38) |
| U11 | 费用补录表单 | U03 | [#39](https://github.com/wynnok/MileafMobile/issues/39) |
| U12 | 集成、复核与交付 | U04、U05、U06、U07、U08、U09、U10、U11 | [#40](https://github.com/wynnok/MileafMobile/issues/40) |

## 实施与验收合同

每个ID的完整任务正文以交付手册同名U节为准，包含输入、文件、动作、测试、完成条件及A/R/P/S/G映射。GitHub子票发布该任务正文并链接包含完整规格与交付手册的增量Spec。新增规则集中维护于规格，任务细节集中维护于交付手册，修改时同步对应线上正文。

U01候选直接使用正式tokens和组件，记录候选diff及token变化表，U02和U03接续同一成果。U00基线完成后开展U01，用户确认代表参考或明确授权继续后再全面迁移。U04–U11默认按顺序执行，依赖边表达必要前置。U09按a节奏、b条件、c补能、d长期、e停放顺序分包验收。

完成证据逐项覆盖规格、可控HTTP行为、正式Flutter渲染、工程检查和两轴审查。开发期性能回归使用三次前后对照及10%调查阈值，正式性能遵循#16的至少30样本与既有p95预算。地图条件由#11、整机及真实站点由#17承载，产品任务的本地工作按其可控边界完成。

## GitHub关系

本批建立独立增量Spec作为#1的sub-issue，U00–U12作为增量Spec的sub-issues。依赖采用原生blocked_by关系，父子关系与阻塞关系分别核验。#22–#26作为已合入阅读成果和回归来源引用，票状态由后续结项事项处理。#1及#17追加本批验收入口。

ready-for-agent表示规格与任务已确认。执行者同时检查原生前置状态和U01视觉决定。发布和文档本地提交在本轮授权范围，产品实施按后续用户指令开展。

## 发布记录

独立增量Spec已发布为[#27](https://github.com/wynnok/MileafMobile/issues/27)，实施票为#28–#40。发布回读已核验13张子票、19条原生blocked_by和14组父子关系。Spec及子票、#1/#17追加后的16份正文逐一对照发布输入，结果一致。#22–#26继续OPEN，外部#11→#16→#17关系已核对。
