# 行笺 / Mileaf Mobile

用 Flutter 为 Android 和 iOS 提供适合手机阅读的 TeslaMate 数据展示体验。
通过独立部署的 Mileaf Server API 读取数据，帮助用户快速查看车况记录、行程、充电和统计。

**当前状态：按已发布的 [Spec #1](https://github.com/wynnok/MileafMobile/issues/1) 分片实施，尚未完成完整首版。**

本地集成分支为 `codex/mileaf-v1`，已有连接/健康检查、安全网络授权候选及独立地图候选。
认证闭环、车辆概览、行程、充电和统计尚未实施。

SDK 隔离仍未通过验证，`tool/flutterw` 暂停原生 build/run 等入口（退出码 78），
等待根因方案确认及验证；不要绕过保护直接调用全局 Flutter 或 Gradle。
测试、静态分析和格式检查仍可运行。相关 Ticket 保持开放，候选合入不等于验收通过。

## 阅读顺序

| 文档 | 回答的问题 |
| --- | --- |
| [产品范围](docs/product/product-brief.md) | 为谁解决什么问题，首版做什么 |
| [页面与交互](docs/product/mobile-experience.md) | 手机端如何组织信息和处理各种状态 |
| [API 能力与差异](docs/product/api-capabilities.md) | 当前后端实际能支撑什么，哪些不能假设 |
| [to-spec 交接清单](docs/product/to-spec-readiness.md) | 已确认什么，下一步还需确认什么，如何验证 |

以上保留为需求准备材料。
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
当前 App 可检测服务健康，并对确切站点授权可信 HTTP；受控真实 HTTPS 后端联通已验证。
双端真机网络、已许可地图服务与真实坐标校准仍缺，不能把构建或合成数据测试当成通过。

- [安全网络候选与待验项](docs/implementation/network-security.md)
- [地图候选与未满足条件](docs/implementation/map-candidate.md)

源码只在本地分支提交，未推送、部署或上架，也未修改外部后端仓库。
