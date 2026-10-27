# Mileaf Mobile（行笺移动端）

- 默认使用中文沟通。产品中文名「行笺」，英文名「Mileaf」。
- Android / iOS 客户端使用 Flutter；通过 Mileaf Server 展示 TeslaMate 的结果数据。
- 当前阶段：实施已发布的 Spec #1 与子任务 #2–#17。以 GitHub 最新 Spec、Ticket 和原生阻塞关系为准，按 `implement-spec` 在集成分支开发。
- 2026-10-23 用户已批准：先完成代码和自动化，真机/真实站点/地图外部验收保持待验、相关 Ticket 不关闭；允许验证构建进程沙箱。代码切片可按已合入的代码依赖推进，GitHub 原生验收阻塞边保留。
- 双端隔离构建已验证：使用 `tool/flutterw` 的进程沙箱及项目级 CocoaPods，不绕过探针、不改 HOME、全局配置或原版 SDK；设备 run/install/drive 入口仍受保护，构建不等于真机验收。
- 2026-10-23 用户已明确授权本次 implement-spec 在各 codex 分支暂存、创建本地提交并合入 `codex/mileaf-v1`；不包含推送或改写共享历史。
- 2026-10-25 测试/seed/性能准备只使用新建的本地隔离测试库；禁止读取或继承现有生产连接配置，禁止向生产库装载数据、执行 DDL 或清理。此边界不影响 App 用户正常通过只读 API 展示业务数据。
- 已确认首版范围：单站点、多车辆；车辆切换、概览、行程列表与详情、充电列表与详情、统计，以及连接与登录。
- 2026-10-25 用户重申核心展示目标：以移动端体验为中心，美观、直观地尽可能展示 TeslaMate 数据；参考 Grafana 指标，不要求逐项相同或迁移桌面布局。图表/地图/关键数字是概览、详情和统计的主要内容，不以字段清单或逐桶文字替代。实施前先交付代表页面可视方案，按 `docs/product/visualization-requirements.md` V01–V08、A01–A06 及修订 Spec T17–T18 验收；当前数据闭环、测试及构建通过不代表新展示要求通过。
- 不实现车辆控制、Tesla 凭据接入、多车对比或秒级刷新。业务数据只读，站点认证除外。
- 2026-10-26 用户已选择 A「湖畔」并要求完成实施；当前正式 Flutter 页面、图表及验证见 `docs/implementation/lake-visualization.md`，视觉决定见 `docs/product/lake-visual-design.md`。不要再次按“尚待选择原型”停止；外部待验和未推送边界继续有效。
- 2026-10-27 用户已确认概览扩展 A「用车简报」，仅实施现有 API 支持范围；增量同步 Spec #1/#8，不重复建票。方案见 `docs/product/overview-expansion-proposal.md`，正式实施和验证见 `docs/implementation/overview-briefing.md`；电量历史/停放变化/费用覆盖/长期续航及动态排序仍为后续候选，不修改后端。授权按 implement 完成测试、审查和当前分支本地提交，不推送或提前关闭外部待验。
- 2026-10-27 用户已确认行程扩展 A「出行回顾」及方案顺序1，并批准紧凑节奏区/真实滚动调整；正式实现与本地测试、图册、双端隔离构建及审查见 `docs/implementation/drives-expansion.md`。Spec #1/#9/#10/#11 已增量同步；顺序2–4及新后端能力保持候选，不重复建票、不推送或提前关闭外部待验。授权当前 `codex/mileaf-v1` 本地提交，不再停在等待选择原型。
- `MileafServer/` 与 `teslamate/` 是外部仓库的符号链接，只读参考，不在本任务中修改。
- 依赖、缓存与构建产物保持项目内；不修改全局工具或系统设置。不擅自提交、推送、部署或删除既有文件。
- 修改前阅读相关文件；保持最小改动，验证后报告。区分代码事实、已确认决定和未确认建议。

## Agent skills

### Issue tracker

GitHub Issues in `wynnok/MileafMobile`, via the `gh` CLI.
See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five default triage labels.
See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: root `GLOSSARY.md` plus `docs/adr/`.
See `docs/agents/domain.md`.
