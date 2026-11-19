# 行笺 / Mileaf Mobile

用 Flutter 为 Android 和 iOS 提供美观、直观、体验良好的 TeslaMate 数据可视化。
通过独立部署的 Mileaf Server API，以图表、地图和关键数字尽可能展示车况记录、行程、充电和统计。
Grafana 是指标参考，不要求逐项一致或迁移桌面布局。

**当前状态（2026-11-19）：版本 `0.1.3+4`，`main` 为唯一开发主线。** 首版功能已全部落地并通过自动化验证：连接与初始化、登录与会话、车辆切换、概览、行程列表与详情、充电列表与详情、统计（总览 + 六个专题）、设置（外观 / 地图 / 站点 / 币种）、缺失充电费用补录、双端地图。视觉上当前一代是 [ADR 0016 色彩与图标秩序](docs/adr/0016-chromatic-language.md)（一动作色 + 六个数据身份色相），此前依次叠加 [ADR 0015 理念迁移](docs/adr/0015-days-matter-language-migration.md)、[0014 Apple 质感](docs/adr/0014-apple-polish.md)、[0013 液态玻璃底栏](docs/adr/0013-liquid-glass-navigation.md)、[0012 Apple 焕新](docs/adr/0012-apple-design-renewal.md)、[0011 UI/UX 精修](docs/adr/0011-ui-ux-refinement.md)、[0006 外观 v2](docs/adr/0006-appearance-and-accent.md)。更早的方向（C「数据拼贴」、A「湖畔」、A「夜航」配色）只作历史证据。

功能票按「代码与自动化完成即结项」口径关闭（2026-11-04）。仍待外部条件的验收集中在三张票：[#11](https://github.com/wynnok/MileafMobile/issues/11) 真实底图与轨迹、[#16](https://github.com/wynnok/MileafMobile/issues/16) 设备性能、[#17](https://github.com/wynnok/MileafMobile/issues/17) 整机与真实站点 / Grafana 复核。**构建、本地渲染与自动化通过都不替代这些证据。**

## 阅读顺序

从 [docs/README.md](docs/README.md) 进入：它是全部文档的索引，按「产品 → 决定 → 条款 → 实施」组织。

| 文档 | 回答的问题 |
| --- | --- |
| [产品范围](docs/product/product-brief.md) | 为谁解决什么问题，首版做什么 |
| [页面与交互](docs/product/mobile-experience.md) | 手机端如何组织信息和处理各种状态 |
| [数据可视化需求基线](docs/product/visualization-requirements.md) | 各指标画什么、数据从哪里来、Grafana 能力缺口及视觉完成条件 |
| [API 能力与差异](docs/product/api-capabilities.md) | 当前后端实际能支撑什么，哪些不能假设 |
| [ADR 索引](docs/adr/README.md) | 每个设计决定为什么这么定、谁取代了谁 |
| [规格索引](docs/README.md#3-规格specs) | 可验收条款（R/P/S/G、CL、MG、L…） |
| [实施记录索引](docs/implementation/README.md) | 每个切片改了什么、怎么验证、还剩什么 |

正式需求与依赖关系以 [GitHub Spec #1](https://github.com/wynnok/MileafMobile/issues/1) 及其子任务为准。

## 工作约定

- [Agent 指引](AGENTS.md)
- [仓库结构与文档约定](docs/agents/repo-layout.md)
- [决策与授权日志（历史）](docs/agents/history.md)
- [Issue tracker](docs/agents/issue-tracker.md)
- [Triage 标签](docs/agents/triage-labels.md)
- [领域文档规则](docs/agents/domain.md)

`MileafServer/` 和 `teslamate/` 是本机外部仓库的符号链接，用于只读核验，
不是移动端依赖，也不保证其他机器克隆后存在。后续实现应使用固定版本的 API 契约，
不通过这些路径耦合运行。固定 OpenAPI 与来源元数据见 `docs/contracts/`。
`creator/` 是私有创作工作区，不纳入版本库。

## 开发与验证

工具链版本、项目内 SDK/缓存入口与命令见[工具链记录](docs/implementation/toolchain.md)；构建入口、探针与 `build/` 清理口径见[构建隔离](docs/implementation/build-isolation.md)与 [build 目录记录](docs/implementation/build-directory.md)。Android release 安装包：

```sh
MILEAF_HOST_ANDROID_SDK=<host sdk> tool/flutterw android assembleRelease \
  -Ptarget-platform=android-arm64 -Psplit-per-abi=true -Pforce-version-code-ignoring-abi=true
# 产物：build/app/outputs/apk/release/app-arm64-v8a-release.apk（开发签名，仅供研发验证）
```

完整 App/HTTP 自动化覆盖连接到退出的闭环、分页、日期/时区、条件缓存、限流和迟到响应隔离。既有受控真实 HTTPS 联通已验证；真实后端样本可按[验收记录](docs/implementation/acceptance.md)复验，当前 Docker 服务未运行的复验尝试没有记为通过。
双端真机网络、已许可地图服务与真实坐标校准仍缺，不能把构建或合成数据测试当成通过。当前自动化基线见 [实施记录索引](docs/implementation/README.md)。

- [最终验证与本地产物](docs/implementation/final-verification.md)
- [两轴审查与修复](docs/implementation/code-review.md)
- [完整验收矩阵与响应复验](docs/implementation/acceptance.md)
- [地图接入与外部验收](docs/implementation/amap-map.md)
- [渲染图册归档政策](docs/implementation/render-archive.md)
- [地图 Key 申请教程](docs/tutorial/amap-key-application.md)、[设置教程](docs/tutorial/amap-key-settings.md)

源码已推送到 [GitHub `wynnok/MileafMobile`](https://github.com/wynnok/MileafMobile) 的 `main`；未部署、未上架，也未修改外部后端仓库（`MileafServer/`、`teslamate/` 仅作只读参考）。

## 许可证

本项目以 **GNU Affero General Public License v3.0（AGPL-3.0）** 发布，许可证全文见 [LICENSE](LICENSE)。

Copyright (c) 2026 wynnok

选择 AGPL-3.0 是为了与同生态的 Mileaf Server 及上游 TeslaMate 保持一致：分发修改版、或修改后通过网络向他人提供服务时，同样需要提供对应源码。

分发前需自行确认两件事：

- 中国大陆底图由高德地图 SDK 提供，其使用条款独立于本项目许可证。
- AGPL/GPL 与 iOS App Store 的分发条款长期存在争议；若要上架 App Store，需要单独处理这一冲突。
