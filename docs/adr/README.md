# ADR 索引

架构与设计决定（Architecture/Design Decision Record）。**一份决定一份文件，只追加、不改序号**；后续变化用新 ADR 的「关系」行或本文件旧的「接续说明」表达，历史正文不回溯改写。

约定：文件名 `NNNN-kebab-title.md`（4 位序号）；正文首部写「状态」「日期」「关系」三行；状态取 accepted / proposed / superseded。

| 编号 | 决定 | 状态 | 关系与接续 |
| --- | --- | --- | --- |
| [0001](0001-visual-direction-c.md) | 采用 C「数据拼贴」作为主视觉方向 | accepted（已被取代） | 版面与视觉验收被 [0003](0003-visual-direction-a.md) 取代；湖畔配色保留 |
| [0002](0002-map-provider.md) | 地图双端接入：Android 高德 + iOS 高德 | accepted | 取代同日的 MapKit 过渡方案；只改供应商边界 |
| [0003](0003-visual-direction-a.md) | 采用 A「夜航」作为视觉系统 | accepted（部分被修订） | 取代 [0001](0001-visual-direction-c.md) 的版面；配色与默认外观被 [0006](0006-appearance-and-accent.md) 修订 |
| [0004](0004-charging-method-visual.md) | 充电页「我的补能方式」改为构成环 | accepted | 实现 [0003](0003-visual-direction-a.md) §9.5；D2 部分被 Spec R1 取代 |
| [0005](0005-active-charging-evidence.md) | 「正在充电」只能由车辆状态证明 | accepted | 修正 Spec §7 第 184 条口径 |
| [0006](0006-appearance-and-accent.md) | 外观默认跟随系统、浅色一体化、强调色改电光蓝 | accepted（强调色纪律被取代） | 修订 [0003](0003-visual-direction-a.md)；单强调色纪律与 20% 彩色口径被 [0016](0016-chromatic-language.md) 取代 |
| [0007](0007-missing-charging-cost-entry.md) | 缺失充电费用补录：双入口、单表单、有限写入 | accepted，已实施 | 在既有只读边界上开唯一写入例外 |
| [0008](0008-user-amap-key.md) | 自备高德地图 Key 与本机地图设置 | accepted，已实施 | — |
| [0009](0009-settings-navigation.md) | 设置首页按「使用偏好 / 当前站点」分组 | accepted，已实施 | 呈现层增量由 [0010](0010-map-settings-visual.md) 承接 |
| [0010](0010-map-settings-visual.md) | 地图设置页按「细线列表 + 留白」重排 | accepted，已实施 | 继承 [0003](0003-visual-direction-a.md)/[0006](0006-appearance-and-accent.md)/[0008](0008-user-amap-key.md)/[0009](0009-settings-navigation.md) |
| [0011](0011-ui-ux-refinement.md) | 以统一排版与任务层级推进整体 UI/UX 精修 | accepted，已实施 | 下一轮由 [0012](0012-apple-design-renewal.md) 接续 |
| [0012](0012-apple-design-renewal.md) | 以内容层级、导航材质和连续反馈焕新界面 | accepted，已实施 | 接续 [0011](0011-ui-ux-refinement.md) |
| [0013](0013-liquid-glass-navigation.md) | 以液态玻璃重塑悬浮底栏 | accepted，已实施 | 2026-11-18 修订 L03/L04 并新增 L10–L12 |
| [0014](0014-apple-polish.md) | 以单一重心、统一语法和清晰文案精修 Apple 质感 | accepted，已实施 | 接续 [0012](0012-apple-design-renewal.md) |
| [0015](0015-days-matter-language-migration.md) | 以参考应用的设计理念校准行笺（理念层迁移） | accepted，已实施 | 净增益为 MG01–MG09 六个收尾点 |
| [0016](0016-chromatic-language.md) | 语义色相与图标秩序：一动作色 + 六数据身份色 | accepted，已实施（当前） | 取代 [0006](0006-appearance-and-accent.md) 的单强调色纪律；[0015](0015-days-matter-language-migration.md) 其余条款继续有效 |

## 阅读建议

- 想理解**现在的视觉为什么长这样**：从 [0016](0016-chromatic-language.md) 往回读 [0015](0015-days-matter-language-migration.md) → [0014](0014-apple-polish.md) → [0012](0012-apple-design-renewal.md) → [0011](0011-ui-ux-refinement.md) → [0006](0006-appearance-and-accent.md) → [0003](0003-visual-direction-a.md)。
- 想理解**数据边界与写入例外**：[0005](0005-active-charging-evidence.md)、[0007](0007-missing-charging-cost-entry.md)。
- 想理解**地图与设置**：[0002](0002-map-provider.md)、[0008](0008-user-amap-key.md)、[0009](0009-settings-navigation.md)、[0010](0010-map-settings-visual.md)。

## 新增 ADR

1. 取下一个序号（当前最大 0016），文件名 kebab-case。
2. 首部写「日期 / 状态 / 关系」，正文写决定、取舍与被拒方案。
3. 更新本索引表；若改变了长期规则，同步 [AGENTS.md](../../AGENTS.md) 与 [docs/README.md](../README.md)。
