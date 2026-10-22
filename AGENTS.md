# Mileaf Mobile（行笺移动端）

- 默认使用中文沟通。产品中文名「行笺」，英文名「Mileaf」。
- Android / iOS 客户端使用 Flutter；通过 Mileaf Server 展示 TeslaMate 的结果数据。
- 当前阶段：实施已发布的 Spec #1 与子任务 #2–#17。以 GitHub 最新 Spec、Ticket 和原生阻塞关系为准，按 `implement-spec` 在集成分支开发。
- 已确认首版范围：单站点、多车辆；车辆切换、概览、行程列表与详情、充电列表与详情、统计，以及连接与登录。
- 不实现车辆控制、Tesla 凭据接入、多车对比或秒级刷新。业务数据只读，站点认证除外。
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
