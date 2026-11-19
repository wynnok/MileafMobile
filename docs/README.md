# docs 索引

行笺（Mileaf Mobile）Flutter 客户端的设计与实施文档。**先读本页，再跳到子目录。** 目录职责、命名规则与清理口径见 [agents/repo-layout.md](agents/repo-layout.md)。

## 1 按角色选入口

| 你想做什么 | 从哪开始 |
| --- | --- |
| 了解产品做什么、给谁 | [product/product-brief.md](product/product-brief.md) → [product/mobile-experience.md](product/mobile-experience.md) |
| 知道某个决定为什么这么定 | [adr/README.md](adr/README.md)（ADR 0001–0016） |
| 查验收条款（R/P/S/G、CL、MG、L…） | [specs/](specs/)（下表按主题分组） |
| 看某个切片改了什么、怎么验的 | [implementation/README.md](implementation/README.md) |
| 跑构建、跑测试、装真机包 | [implementation/toolchain.md](implementation/toolchain.md)、[implementation/build-directory.md](implementation/build-directory.md) |
| 贡献代码前的规则 | [../AGENTS.md](../AGENTS.md)、[agents/repo-layout.md](agents/repo-layout.md) |
| 查 2026-10/11 的决定与授权原文 | [agents/history.md](agents/history.md) |

## 2 子目录

| 目录 | 职责 | 索引 |
| --- | --- | --- |
| `adr/` | 架构与设计决定（一项决定一份，4 位序号只追加） | [adr/README.md](adr/README.md) |
| `specs/` | 可验收条款、实施 tickets、交付手册 | 本页 §3 |
| `implementation/` | 实施与验证记录、双轴审查、渲染图册、分包记录 | [implementation/README.md](implementation/README.md) |
| `product/` | 产品范围、体验基线、可视化需求、扩展提案、方向评审 | 本页 §4 |
| `contracts/` | 冻结的 OpenAPI 与来源元数据（DTO 由它生成） | — |
| `tutorial/` | 高德 Key 申请与设置教程 | — |
| `agents/` | issue tracker、triage 标签、领域文档规则、仓库结构、历史日志 | [agents/repo-layout.md](agents/repo-layout.md) |
| `prototypes/` | 设计原型与自带评审图（被 ADR/Spec 引用的设计原文） | [prototypes/](prototypes/) |

## 3 规格（specs）

| 主题 | 规格 | 实施 tickets | 交付手册 |
| --- | --- | --- | --- |
| v1 主体（Spec #1 增量） | [mobile-v1.md](specs/mobile-v1.md) | — | — |
| 视觉系统 A「夜航」（历史） | [visual-system-a.md](specs/visual-system-a.md) | [tickets](specs/visual-system-a-tickets.md) | — |
| 外观 v2（强调色与默认外观） | [appearance-v2.md](specs/appearance-v2.md) | [tickets](specs/appearance-v2-tickets.md) | — |
| UI/UX 精修（R/P/S/G） | [ui-ux-refinement.md](specs/ui-ux-refinement.md) | [tickets](specs/ui-ux-refinement-tickets.md) | [delivery](specs/ui-ux-refinement-delivery.md) |
| Apple 风格焕新 | [apple-design-renewal.md](specs/apple-design-renewal.md) | [tickets](specs/apple-design-renewal-tickets.md) | [delivery](specs/apple-design-renewal-delivery.md) |
| Apple 质感精修 + 文案规范 | [apple-polish.md](specs/apple-polish.md)、[copy](specs/apple-polish-copy.md) | [tickets](specs/apple-polish-tickets.md) | [delivery](specs/apple-polish-delivery.md) |
| 理念迁移（Days Matter → 行笺） | [days-matter-migration.md](specs/days-matter-migration.md) | [tickets](specs/days-matter-migration-tickets.md) | — |
| **色彩与图标秩序（当前）** | [chromatic-language.md](specs/chromatic-language.md) | [tickets](specs/chromatic-language-tickets.md) | — |
| 液态玻璃底栏（L01–L12） | [liquid-glass-navigation.md](specs/liquid-glass-navigation.md) | — | — |
| 充电「我的补能方式」构成环 | [charging-method-share-ring.md](specs/charging-method-share-ring.md) | [tickets](specs/charging-method-share-ring-tickets.md) | — |
| 缺失充电费用补录 | [missing-charging-cost-entry.md](specs/missing-charging-cost-entry.md) | [tickets](specs/missing-charging-cost-entry-tickets.md) | — |
| 设置层级重整 | [settings-navigation.md](specs/settings-navigation.md) | [tickets](specs/settings-navigation-tickets.md) | — |
| 地图设置页视觉 | [map-settings-visual.md](specs/map-settings-visual.md) | [tickets](specs/map-settings-visual-tickets.md) | — |
| 自备高德 Key | [user-amap-key.md](specs/user-amap-key.md) | [tickets](specs/user-amap-key-tickets.md) | — |

## 4 产品文档（product）

| 文档 | 回答的问题 |
| --- | --- |
| [product-brief.md](product/product-brief.md) | 为谁解决什么问题、首版做什么 |
| [mobile-experience.md](product/mobile-experience.md) | 手机端如何组织信息与处理状态 |
| [visualization-requirements.md](product/visualization-requirements.md) | 各指标画什么、数据从哪来、视觉完成条件 |
| [api-capabilities.md](product/api-capabilities.md) | 当前后端实际支撑什么、哪些不能假设 |
| [to-spec-readiness.md](product/to-spec-readiness.md) | 需求如何进入 Spec / 工单 |
| [visual-refresh-proposal.md](product/visual-refresh-proposal.md)、[direction-review-v2.md](product/direction-review-v2.md) | 视觉方向提案与三方向评审（历史输入） |
| [overview-expansion-proposal.md](product/overview-expansion-proposal.md)、[drives-expansion-proposal.md](product/drives-expansion-proposal.md)、[charging-expansion-proposal.md](product/charging-expansion-proposal.md)、[statistics-expansion-proposal.md](product/statistics-expansion-proposal.md) | 四次页面扩展的提案 |
| [charging-api-requirements.md](product/charging-api-requirements.md)、[statistics-api-requirements.md](product/statistics-api-requirements.md)、[owner-api-requirements.md](product/owner-api-requirements.md) | 后端能力需求 |
| [ui-ux-refinement-audit.md](product/ui-ux-refinement-audit.md)、[owner-experience-review.md](product/owner-experience-review.md) | 体验审计 |
| [lake-visual-design.md](product/lake-visual-design.md)、[map-integration-proposal.md](product/map-integration-proposal.md)、[map-flutter-tech-plan.md](product/map-flutter-tech-plan.md) | 历史视觉与地图技术方案 |

## 5 现状与验收口径

- **当前一代视觉**：ADR 0016 色彩与图标秩序（`lib/src/design/`），上一轮 ADR 0015 理念迁移。
- **图册**：当前一代与上一代的取舍见 [implementation/render-archive.md](implementation/render-archive.md)；各切片的图册入口在 [implementation/README.md](implementation/README.md)。
- **外部 gate 未关闭**：真机与真实站点（#17）、真实底图（#11）、设备性能（#16）。构建成功、本地渲染、自动化通过都不替代这些证据。

## 6 维护规则

1. 新增文档先定目录（[repo-layout.md](agents/repo-layout.md) §6），再写内容。
2. 决定进 `adr/`，条款进 `specs/`，过程与证据进 `implementation/`；同一内容不重复写两处，用链接。
3. 新增后同步三处索引：本页、[adr/README.md](adr/README.md)、[implementation/README.md](implementation/README.md)。
4. 历史记录不回溯改写；与现状冲突时在文首加「接续说明」并指向最新 ADR/Spec。
5. 文档里引用 `.dsh-tmp/` 路径只作「当时工作稿」，不保证文件存在。
