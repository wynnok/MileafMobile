# 行笺 / Mileaf Mobile

用 Flutter 为 Android 和 iOS 提供适合手机阅读的 TeslaMate 数据展示体验。
通过独立部署的 Mileaf Server API 读取数据，帮助用户快速查看车况记录、行程、充电和统计。

**当前状态：需求准备材料已整理，等待确认后进入 `to-spec`。尚无 Flutter 工程。**

## 阅读顺序

| 文档 | 回答的问题 |
| --- | --- |
| [产品范围](docs/product/product-brief.md) | 为谁解决什么问题，首版做什么 |
| [页面与交互](docs/product/mobile-experience.md) | 手机端如何组织信息和处理各种状态 |
| [API 能力与差异](docs/product/api-capabilities.md) | 当前后端实际能支撑什么，哪些不能假设 |
| [to-spec 交接清单](docs/product/to-spec-readiness.md) | 已确认什么，下一步还需确认什么，如何验证 |

以上是正式 spec 的输入材料；页面方案、默认值和验收目标中的建议尚未视为用户确认。
正式 spec 后续发布至 [GitHub Issues](https://github.com/wynnok/MileafMobile/issues)。

## 工作约定

- [Agent 指引](AGENTS.md)
- [Issue tracker](docs/agents/issue-tracker.md)
- [Triage 标签](docs/agents/triage-labels.md)
- [领域文档规则](docs/agents/domain.md)

`MileafServer/` 和 `teslamate/` 是本机外部仓库的符号链接，用于本轮只读核验，
不是移动端依赖，也不保证其他机器克隆后存在。后续实现应使用固定版本的 API 契约，
不通过这些路径耦合运行；本轮不导出契约或添加依赖。

本轮没有初始化工程、修改后端、发布 issue、提交或推送代码。
