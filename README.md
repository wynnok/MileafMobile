# 行笺 / Mileaf Mobile

用 Flutter 为 Android 和 iOS 提供美观、直观、体验良好的 TeslaMate 数据可视化。
通过独立部署的 Mileaf Server API，以图表、地图和关键数字尽可能展示车况记录、行程、充电和统计。
Grafana 是指标参考，不要求逐项一致或迁移桌面布局。

**当前状态：版面与视觉已按 A「夜航」方向完成 VA01–VA14 实施，并于 2026-11-02 由外观 v2 更新配色与默认外观（现行外观）。代码、自动化与实际 Flutter 渲染已验证并集成到 `main`；真机、真实站点、地图底图与设备性能等外部验收仍未完成。** 正式范围以 [Spec #1](https://github.com/wynnok/MileafMobile/issues/1) 为准。见 [A 视觉系统 Spec](docs/specs/visual-system-a.md)、[A 视觉方向 ADR](docs/adr/0003-visual-direction-a.md)、[A 渲染索引](docs/implementation/a-renders/gallery/README.md) 与 [可达性审计](docs/implementation/a-accessibility.md)。C「数据拼贴」的页面、渲染与 C10 验收记录保留为历史证据，不再作为当前视觉依据。

已集成到 `main`（原 `codex/mileaf-v1` 已合并并推送）：连接与显式初始化、登录/会话、车辆切换、概览、行程和充电列表/详情/采样曲线、驾驶与充电统计、站点币种及连接管理。业务数据默认只读；Server 0.4.0 起，管理员显式启用后，可在 App 按本次单价补录已结束且费用缺失的充电，不覆盖已有费用、不保存默认单价。见[补录规格](docs/specs/missing-charging-cost-entry.md)与[实施证据](docs/implementation/charging-cost-entry.md)。使用固定 Mileaf Server OpenAPI 生成客户端 DTO。

双端构建已通过进程沙箱验证，iOS 使用用户批准的项目级 CocoaPods。
原生构建必须使用带探针的 `tool/flutterw`，不要绕过保护直接调用全局 Flutter 或 Gradle。
设备 run/install/drive 仍返回 78；构建证据见[隔离记录](docs/implementation/build-isolation.md)。
功能票按「代码与自动化完成即结项」口径关闭（2026-11-04）；仍待外部条件的验收集中在三张票：[#11](https://github.com/wynnok/MileafMobile/issues/11) 真实底图、[#16](https://github.com/wynnok/MileafMobile/issues/16) 设备性能、[#17](https://github.com/wynnok/MileafMobile/issues/17) 整机与真实站点/Grafana 复核。功能票关闭不等于外部验收通过。

## 阅读顺序

| 文档 | 回答的问题 |
| --- | --- |
| [产品范围](docs/product/product-brief.md) | 为谁解决什么问题，首版做什么 |
| [页面与交互](docs/product/mobile-experience.md) | 手机端如何组织信息和处理各种状态 |
| [数据可视化需求基线](docs/product/visualization-requirements.md) | 各指标画什么、数据从哪里来、Grafana 能力缺口及视觉完成条件 |
| [API 能力与差异](docs/product/api-capabilities.md) | 当前后端实际能支撑什么，哪些不能假设 |
| [需求澄清与实施交接](docs/product/to-spec-readiness.md) | 本轮纠偏如何进入既有 Spec/工单，下一阶段应交付什么 |

以上为与正式 Spec 配套的产品与体验基线；A「夜航」正式页面的浅深色/大字体实际渲染由 `test/a_gallery_render_test.dart` 生成。**2026-11-02 起现行图册是外观 v2 版**（电光蓝强调、中性底、默认跟随系统、浅色 hero 卡片），输出到 [docs/implementation/appearance-v2-renders/](docs/implementation/appearance-v2-renders/README.md)；`docs/implementation/a-renders/` 是玉绿版的同机位旧图，仅作对照与历史证据。C 的渲染与逐页对照同样仅作历史证据。更早五轮视觉证据的图片已于 2026-11-02 归档清理（保留在提交 `725ceda`），理由与恢复方式见 [render-archive.md](docs/implementation/render-archive.md)。最终双端体验仍需相应外部证据。
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
- [A 渲染索引](docs/implementation/a-renders/gallery/README.md)
- [A 可达性审计](docs/implementation/a-accessibility.md)
- [两轴审查与修复](docs/implementation/code-review.md)
- [完整验收矩阵与响应复验](docs/implementation/acceptance.md)
- [行程详情和采样](docs/implementation/drive-detail.md)
- [充电详情和采样](docs/implementation/charging-detail.md)
- [驾驶与充电统计](docs/implementation/statistics.md)
- [安全网络候选与待验项](docs/implementation/network-security.md)
- [地图候选与未满足条件](docs/implementation/map-candidate.md)

源码已推送到 [GitHub `wynnok/MileafMobile`](https://github.com/wynnok/MileafMobile) 的 `main`；未部署、未上架，也未修改外部后端仓库（`MileafServer/`、`teslamate/` 仅作只读参考）。

## 许可证

本项目以 **GNU Affero General Public License v3.0（AGPL-3.0）** 发布，许可证全文见 [LICENSE](LICENSE)。

Copyright (c) 2026 wynnok

选择 AGPL-3.0 是为了与同生态的 Mileaf Server 及上游 TeslaMate 保持一致：分发修改版、或修改后通过网络向他人提供服务时，同样需要提供对应源码。

分发前需自行确认两件事：

- 中国大陆底图由高德地图 SDK 提供，其使用条款独立于本项目许可证。
- AGPL/GPL 与 iOS App Store 的分发条款长期存在争议；若要上架 App Store，需要单独处理这一冲突。
