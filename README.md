# 行笺 / Mileaf Mobile

用 Flutter 为 Android 和 iOS 提供美观、直观、体验良好的 TeslaMate 数据可视化。
通过独立部署的 Mileaf Server API，以图表、地图和关键数字尽可能展示车况记录、行程、充电和统计。
Grafana 是指标参考，不要求逐项一致或迁移桌面布局。

**当前状态：2026-10-26 已按用户选定的 A「湖畔」方案完成正式 Flutter 图表与页面实现；代码、自动化和构建已验证，外部验收仍待完成。** 正式范围以 [Spec #1](https://github.com/wynnok/MileafMobile/issues/1) 为准。见[实施记录](docs/implementation/lake-visualization.md)与[实际 Flutter 图册](docs/implementation/lake-renders/index.html)。

本地集成分支为 `codex/mileaf-v1`：连接与显式初始化、登录/会话、车辆切换、概览、行程和充电列表/详情/采样曲线、驾驶与充电统计、站点币种及连接管理。业务数据只读，使用固定 Mileaf Server OpenAPI 生成客户端 DTO。

双端构建已通过进程沙箱验证，iOS 使用用户批准的项目级 CocoaPods。
原生构建必须使用带探针的 `tool/flutterw`，不要绕过保护直接调用全局 Flutter 或 Gradle。
设备 run/install/drive 仍返回 78；构建证据见[隔离记录](docs/implementation/build-isolation.md)。
真机等外部验收未齐的 Ticket 保持开放，候选合入不等于整票验收通过。

用户同时批准先推进后续代码和自动化测试，外部验收保持待验且不提前关闭相关 Ticket。

## 阅读顺序

| 文档 | 回答的问题 |
| --- | --- |
| [产品范围](docs/product/product-brief.md) | 为谁解决什么问题，首版做什么 |
| [页面与交互](docs/product/mobile-experience.md) | 手机端如何组织信息和处理各种状态 |
| [数据可视化需求基线](docs/product/visualization-requirements.md) | 各指标画什么、数据从哪里来、Grafana 能力缺口及视觉完成条件 |
| [API 能力与差异](docs/product/api-capabilities.md) | 当前后端实际能支撑什么，哪些不能假设 |
| [需求澄清与实施交接](docs/product/to-spec-readiness.md) | 本轮纠偏如何进入既有 Spec/工单，下一阶段应交付什么 |

以上为与正式 Spec 配套的产品与体验基线；A原型已获用户选定，正式页面已保存浅深色/大字体实际渲染，最终双端体验仍需相应外部证据。
正式需求与依赖关系以 [GitHub Spec #1](https://github.com/wynnok/MileafMobile/issues/1) 及其子任务为准。

## 工作约定

- [Agent 指引](AGENTS.md)
- [Issue tracker](docs/agents/issue-tracker.md)
- [Triage 标签](docs/agents/triage-labels.md)
- [领域文档规则](docs/agents/domain.md)

`MileafServer/` 和 `teslamate/` 是本机外部仓库的符号链接，用于本轮只读核验，
不是移动端依赖，也不保证其他机器克隆后存在。后续实现应使用固定版本的 API 契约，
不通过这些路径耦合运行。固定 OpenAPI 与来源元数据见 `docs/contracts/`。

## 开发与验证

工具链版本、项目内 SDK/缓存入口、测试与双端构建命令见[实施说明](docs/implementation/toolchain.md)。
完整 App/HTTP 自动化覆盖连接到退出的闭环、分页、日期/时区、条件缓存、限流和迟到响应隔离。既有受控真实 HTTPS 联通已验证；真实后端样本可按[验收记录](docs/implementation/acceptance.md)复验，当前 Docker 服务未运行的复验尝试没有记为通过。
双端真机网络、已许可地图服务与真实坐标校准仍缺，不能把构建或合成数据测试当成通过。

- [最终验证与本地产物](docs/implementation/final-verification.md)
- [性能合成数据准备与未测状态](docs/implementation/performance.md)
- [两轴审查与修复](docs/implementation/code-review.md)
- [完整验收矩阵与响应复验](docs/implementation/acceptance.md)
- [行程详情和采样](docs/implementation/drive-detail.md)
- [充电详情和采样](docs/implementation/charging-detail.md)
- [驾驶与充电统计](docs/implementation/statistics.md)
- [安全网络候选与待验项](docs/implementation/network-security.md)
- [地图候选与未满足条件](docs/implementation/map-candidate.md)

源码只在本地分支提交，未推送、部署或上架，也未修改外部后端仓库。
