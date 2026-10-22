# 行笺 / Mileaf Mobile

用 Flutter 为 Android 和 iOS 提供适合手机阅读的 TeslaMate 数据展示体验。
通过独立部署的 Mileaf Server API 读取数据，帮助用户快速查看车况记录、行程、充电和统计。

**当前状态：按已发布的 [Spec #1](https://github.com/wynnok/MileafMobile/issues/1) 分片实施；首个切片提供双端工程与 HTTPS 服务健康检查。完整业务功能尚在后续 Ticket 中。**

## 阅读顺序

| 文档 | 回答的问题 |
| --- | --- |
| [产品范围](docs/product/product-brief.md) | 为谁解决什么问题，首版做什么 |
| [页面与交互](docs/product/mobile-experience.md) | 手机端如何组织信息和处理各种状态 |
| [API 能力与差异](docs/product/api-capabilities.md) | 当前后端实际能支撑什么，哪些不能假设 |
| [to-spec 交接清单](docs/product/to-spec-readiness.md) | 已确认什么，下一步还需确认什么，如何验证 |

以上是正式 spec 的输入材料；页面方案、默认值和验收目标中的建议尚未视为用户确认。
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
当前 App 可输入 HTTPS 根地址并检查健康状态；真实站点联通及双端设备验收条件尚待提供，不能把构建或假响应测试当成真机通过。
