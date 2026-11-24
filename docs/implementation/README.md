# 实施记录索引

本目录放**过程与证据**：每个切片改了什么、怎么验证的、审查发现了什么、还剩什么。条款在 [specs/](../specs/)，决定在 [adr/](../adr/)；这里不重复写条款。总入口见 [docs/README.md](../README.md)。

当前状态：80 个顶层 Markdown（79 份记录 + 本索引）+ 36 个子目录（分包记录与图册）。最近一次结构核对见 [repo-structure.md](repo-structure.md)。

## 1 交付总账

| 记录 | 内容 |
| --- | --- |
| [final-verification.md](final-verification.md) | v1 本地交付与最终验证（门禁表、产物摘要、未通过的外部验收） |
| [acceptance.md](acceptance.md) | 验收矩阵与响应复验 |
| [code-review.md](code-review.md) | implement-spec 两轴审查与修复记录 |
| [a-final-verification.md](a-final-verification.md) | A「夜航」VA01–VA14 最终验证与验收清单 |
| [a-review.md](a-review.md) | A「夜航」双轴 code review |
| [a-accessibility.md](a-accessibility.md) | A「夜航」可达性与对比度审计（VA13） |

## 2 工程边界

| 记录 | 内容 |
| --- | --- |
| [toolchain.md](toolchain.md) | T01 工具链、SDK/缓存入口与常用命令 |
| [build-isolation.md](build-isolation.md) | 构建进程隔离：沙箱 profile、探针与证据 |
| [build-directory.md](build-directory.md) | `build/` 内容、清理口径与重建入口（含 APK 构建命令） |
| [repo-structure.md](repo-structure.md) | 2026-11-19 仓库结构梳理记录 |
| [render-archive.md](render-archive.md) | 历史渲染图册归档政策与恢复方式 |
| [performance.md](performance.md) | 性能采集准备与未测状态（#16） |
| [session-merge-check.md](session-merge-check.md) | 两会话合并检查与 arm64 安装包 |

## 3 v1 功能切片

| 记录 | 对应票 | 内容 |
| --- | --- | --- |
| [network-security.md](network-security.md) | #3 | 安全网络候选实现（逐站点授权、局域网指引） |
| [map-candidate.md](map-candidate.md) | #4 | 地图接入候选与前置验收未通过的事实 |
| [session.md](session.md) | #5 | 已有站点登录与会话交接 |
| [initialization.md](initialization.md) | #6 | 显式初始化站点 |
| [connection-management.md](connection-management.md) | #7 | 安全替换连接与本地退出 |
| [overview.md](overview.md) | #8 | 选车与概览代码切片 |
| [drives.md](drives.md) | #9 | 行程筛选与游标分页 |
| [drive-detail.md](drive-detail.md) | #10 | 行程详情与采样曲线 |
| [amap-map.md](amap-map.md) | #4/#11 | 地图双端接入（Android + iOS 高德） |
| [charging-history.md](charging-history.md) | #12 | 充电历史与站点币种 |
| [charging-detail.md](charging-detail.md) | #13 | 充电详情与采样曲线 |
| [statistics.md](statistics.md) | #14 | 驾驶统计与日历区间 |
| [business-recovery.md](business-recovery.md) | — | 业务请求恢复与并发缓存 |

## 4 页面扩展与视觉增量（按 ADR 顺序）

| 记录 | 来源 | 内容 |
| --- | --- | --- |
| [lake-visualization.md](lake-visualization.md) | ADR 0001 前身 | A「湖畔」实施与验证（历史） |
| [charging-method-share-ring.md](charging-method-share-ring.md) | ADR 0004 | 充电「我的补能方式」构成环 |
| [charging-active-state.md](charging-active-state.md) | ADR 0005 | 「正在充电」误报修正 |
| [appearance-v2.md](appearance-v2.md)、[appearance-v2-review.md](appearance-v2-review.md) | ADR 0006 | 外观 v2 实施与双轴审查 |
| [charging-cost-entry.md](charging-cost-entry.md)、[charging-cost-review.md](charging-cost-review.md) | ADR 0007 | 缺失费用补录实施与审查 |
| [user-amap-key.md](user-amap-key.md) | ADR 0008 | 自备高德 Key 实施 |
| [settings-navigation.md](settings-navigation.md) | ADR 0009 | 设置层级与视觉重整 |
| [map-settings-visual.md](map-settings-visual.md)、[map-settings-visual-handoff.md](map-settings-visual-handoff.md) | ADR 0010 | 地图设置页视觉重排 |
| [overview-briefing.md](overview-briefing.md) | 扩展提案 | 概览「用车简报」 |
| [drives-expansion.md](drives-expansion.md) | 扩展提案 | 行程「出行回顾」 |
| [charging-briefing.md](charging-briefing.md) | 扩展提案 | 充电「补能账本」（CH01–CH05） |
| [statistics-insights-overview.md](statistics-insights-overview.md)、[statistics-conditions.md](statistics-conditions.md) | 扩展提案 | 统计洞察总览与温度条件 |
| [overview-reading.md](overview-reading.md)、[overview-chart-header.md](overview-chart-header.md)、[readout-context-row.md](readout-context-row.md) | ADR 0011/0014 | 概览读数区、图表头、读值第三行（含 2026-11-19 行宽修正） |
| [period-header.md](period-header.md) | ADR 0014 | 焦点卡卡头（期间名 + 区间） |
| [charging-rows.md](charging-rows.md) | ADR 0014 | 充电记录行与地点行重排 |
| [settings-order.md](settings-order.md) | ADR 0014 | 设置页秩序重排 |
| [drive-detail-reading.md](drive-detail-reading.md) | ADR 0011/0014 | 行程详情「对照电量」与「驾驶与环境」 |
| [liquid-glass-nav.md](liquid-glass-nav.md) | ADR 0013 | 液态玻璃底栏实施（含参数修订） |
| [days-matter-migration.md](days-matter-migration.md) + [-color](days-matter-migration-color.md) / [-icons](days-matter-migration-icons.md) / [-state](days-matter-migration-state.md) / [-dm05](days-matter-migration-dm05.md) / [-dm06](days-matter-migration-dm06.md) / [-dm07](days-matter-migration-dm07.md) / [-review](days-matter-migration-review.md) | ADR 0015 | 理念迁移实施、分包记录与审查 |
| [chromatic-language.md](chromatic-language.md) | ADR 0016 | 色彩与图标秩序实施（含分包记录子目录） |
| [chromatic-intensity.md](chromatic-intensity.md) | ADR 0017 | 鲜明度 v2：亮面档、洗色重定与逐像素前后对照 |
| [visual-hierarchy-plan.md](visual-hierarchy-plan.md#天蓝与薄荷实施) | ADR 0018–0021 | 焦点、玻璃与现行天蓝薄荷配色实施核验 |
| [statistics-conditions-layout.md](statistics-conditions-layout.md) | 缺陷修复（R24/R03/CP03/CP06） | 能耗专题（P08）读数浮点、卡间距、点图标签、分段轨道与下钻行对齐 |
| [statistics-all-metrics-layout.md](statistics-all-metrics-layout.md) | 缺陷修复（R24/R30.2/PD08/CP05） | 全部指标索引页（P15）页首/页尾 0 间距、页尾改「关于这些数据」分组卡、行尾箭头同线 |

## 5 历史记录（图册已按归档政策处理）

| 记录 | 说明 |
| --- | --- |
| [collage-overview.md](collage-overview.md)、[collage-drives.md](collage-drives.md)、[collage-drive-detail.md](collage-drive-detail.md)、[collage-charging.md](collage-charging.md)、[collage-charging-detail.md](collage-charging-detail.md)、[collage-charging-statistics.md](collage-charging-statistics.md)、[collage-statistics.md](collage-statistics.md)、[collage-conditions.md](collage-conditions.md)、[collage-parking.md](collage-parking.md)、[collage-range.md](collage-range.md)、[collage-rhythm.md](collage-rhythm.md)、[collage-integration.md](collage-integration.md) | C「数据拼贴」时期的逐页实施记录（被 A「夜航」取代） |
| [collage-audit/c-fidelity-report.md](collage-audit/c-fidelity-report.md) | C10 视觉验收证据 |
| [owner-experience.md](owner-experience.md)、[owner-overview-verification.md](owner-overview-verification.md)、[owner-statistics-verification.md](owner-statistics-verification.md)、[owner-integration-verification.md](owner-integration-verification.md) | 2026-10-29/30 车主体验复核与复验 |

## 6 分包记录与提示词

| 目录 | 内容 |
| --- | --- |
| [apple-polish/](apple-polish/README.md) | AP00–AP15 逐票记录（22 份） |
| [ui-ux-refinement/](ui-ux-refinement/README.md) | U00–U12 逐票记录（21 份） |
| [apple-design-renewal/](apple-design-renewal/README.md) | F00–F12 逐票记录（15 份） |
| [chromatic-language/](chromatic-language/) | MC01–MC12 分包记录（7 份） |
| [ui-ux-agent-prompts/](ui-ux-agent-prompts/) | 多会话提示词（21 份） |

## 7 图册

图册政策见 [render-archive.md](render-archive.md)：**保留切片证据图册；整册一旦被后续 ADR 取代即归档，目录只留 README**（2026-11-19 起执行）。张数为归档前统计。

| 目录 | 张数 | 状态 |
| --- | --- | --- |
| [chromatic-intensity-renders/](chromatic-intensity-renders/) | 8 | 切片证据（ADR 0017：四页 × 浅深，390×844 / 2x） |
| [statistics-conditions-renders/](statistics-conditions-renders/) | 8 | 切片证据（P08 版式修复：高精度合成浮点、窄屏温区标签和 13 组密集形态） |
| [statistics-all-metrics-renders/](statistics-all-metrics-renders/) | 5 | 切片证据（P15 版式修复：页首/页尾节奏 + R30.2 页尾形式，3 机位 + 深色 + 200%） |
| [days-matter-migration-renders/](days-matter-migration-renders/) | 26 | 上一代（ADR 0015 迁移样张） |
| [charging-rows-renders/](charging-rows-renders/) | 18 | 切片证据（ADR 0014） |
| [liquid-glass-nav-renders/](liquid-glass-nav-renders/) | 17 | 切片证据（ADR 0013） |
| [settings-order-renders/](settings-order-renders/) | 28 | 切片证据（ADR 0014） |
| [period-header-renders/](period-header-renders/) | 4 | 切片证据（ADR 0014） |
| [overview-reading-renders/](overview-reading-renders/) | 10 | 切片证据（ADR 0011/0014） |
| [overview-chart-header-renders/](overview-chart-header-renders/) | 9 | 切片证据（ADR 0014） |
| [reading-restore-renders/](reading-restore-renders/) | 8 | 切片证据（阅读体验增量） |
| [drive-detail-reading-renders/](drive-detail-reading-renders/) | 28 | 切片证据（ADP 重排） |
| [settings-renders/](settings-renders/) | 14 | 切片证据（ADR 0009/0010） |
| [map-key-renders/](map-key-renders/) | 14 | 切片证据（ADR 0008） |
| [charging-cost-renders/](charging-cost-renders/) | 112 | 切片证据（ADR 0007） |
| [apple-polish-renders/](apple-polish-renders/README.md) | 0 | 已归档（ADR 0014，2026-11-19 删 442 张 / 60 MB） |
| [apple-design-renewal-renders/](apple-design-renewal-renders/README.md) | 0 | 已归档（ADR 0012，2026-11-19 删 1057 张 / 125 MiB，仅留 README） |
| [ui-ux-refinement-renders/](ui-ux-refinement-renders/README.md) | 0 | 已归档（ADR 0011，2026-11-19 删 1850 张 / 214 MiB，仅留 README） |
| [readability-renders/](readability-renders/README.md) | 0 | 已归档（2026-11-19 删 320 张 / 46 MB） |
| [appearance-v2-renders/](appearance-v2-renders/README.md) | 0 | 已归档（ADR 0006，2026-11-19 删 156 张 / 28 MB） |
| [a-renders/](a-renders/README.md) | 0 | 已归档（ADR 0003，2026-11-19 删 156 张 / 25 MB） |
| [collage-renders/](collage-renders/)、[lake-renders/](lake-renders/)、[owner-*-renders/](owner-experience-renders/)、[overview-briefing-renders/](overview-briefing-renders/)、[drives-expansion-renders/](drives-expansion-renders/)、[charging-briefing-renders/](charging-briefing-renders/) | 0 | 已按 render-archive 归档，仅留 README |

## 8 维护规则

1. 一个切片一份记录，文件名即切片名；分包记录放同名子目录。
2. 记录必须写：基线提交、改了什么、取像素/测试实测值、双轴审查发现与修复、遗留与未关闭的外部条件。
3. 已知偏差不隐藏：审查改过的条款要在「双轴审查与修订」一节逐条写明。
4. 新增记录后更新本索引，并在 [docs/agents/history.md](../agents/history.md) 追加一条。
