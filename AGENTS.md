# Mileaf Mobile（行笺移动端）

- 默认使用中文沟通。产品中文名「行笺」，英文名「Mileaf」。
- Flutter（Android + iOS）客户端，经自建 Mileaf Server 只读展示 TeslaMate 数据；Grafana 只是指标参考，不要求逐项一致或迁移桌面布局。

## 当前状态（2026-11-24）

- 版本 `0.1.3+4`；`main` 是唯一开发主线。
- 已交付（代码 + 自动化）：连接与显式初始化、登录与会话、车辆切换、概览、行程列表与详情、充电列表与详情、统计（总览 + 六个专题）、设置（外观 / 地图 / 站点 / 币种 / 服务信息）、缺失充电费用补录、双端地图。
- 设计增量按序叠加：ADR 0003 A「夜航」→ 0006 外观 v2 → 0011 UI/UX 精修 → 0012 Apple 焕新 → 0014 Apple 质感 → 0015 理念迁移 → 0016 色彩与图标秩序 → 0017 鲜明度 v2 → 0018 焦点配色与控件玻璃 → 0019 统一内容色面 → 0020 青绿五色体系 → **0021 天蓝与薄荷（现行）**。取色以 0021 为准，色面层级与玻璃沿用 0019。
- 自动化基线：`tool/flutterw analyze --no-pub lib test` 仅 1 条既有 info（`test/apple_polish_ap10_test.dart:342`）；全量测试记录见 `docs/agents/history.md`。
- 仍未完成：真机、真实站点、真实底图（#11）、设备性能（#16）、整机与 Grafana 复核（#17）；ADR 0016 的 MC12 图册尚未采集（0017 的四页样张已在 `docs/implementation/chromatic-intensity-renders/`）。
- GitHub 跟踪：#1（首版 Spec）、#11 / #16 / #17（外部验收）、#27（早期代表页具名视觉验收）。阅读体验 #22–#26 与 UI/UX #28–#40 已有代码和验证记录，历史验收依据见 `docs/implementation/ui-ux-refinement/U12.md`。

## 硬约束

- 首版范围：单站点、多车辆；车辆切换、概览、行程列表与详情、充电列表与详情、统计、连接与登录。
- 不实现：车辆控制、Tesla 凭据接入、多车对比、秒级刷新。业务数据默认只读；唯一写入例外是显式启用后的缺失充电费用补录（ADR 0007）。
- 外部 gate 不因构建、自动化或本地渲染通过而关闭：真机、真实站点、真实底图、设备性能、商店上架各自独立。
- 原生构建只走 `tool/flutterw`（进程沙箱 + 项目内 SDK 与缓存），不绕过探针、不改 HOME / 全局配置 / 原版 SDK；设备 `run/install/drive` 入口仍返回 78，装包用 `adb install` 且不构成验收。
- 依赖、缓存与构建产物留在项目内；不修改全局工具或系统设置。
- 不擅自提交、推送、部署或删除既有文件；每次都需要当次授权。
- `MileafServer/`、`teslamate/` 是外部仓库的只读符号链接，不在本任务中修改；`creator/` 是用户私有创作工作区，永不入库、不改动。
- 修改前阅读相关文件，保持最小改动，验证后报告；区分【代码事实】【已确认决定】【未确认建议】。

## 仓库结构

- 顶层允许项、忽略项与各目录职责见 [docs/agents/repo-layout.md](docs/agents/repo-layout.md)。
- 文档落位：决定 → `docs/adr/`（4 位序号，只追加）；规格 → `docs/specs/`；实施与验证记录 → `docs/implementation/`；产品与体验基线 → `docs/product/`；契约快照 → `docs/contracts/`；教程 → `docs/tutorial/`；代理约定 → `docs/agents/`。
- 三份索引必须随新增文档同步更新：[docs/README.md](docs/README.md)、[docs/adr/README.md](docs/adr/README.md)、[docs/implementation/README.md](docs/implementation/README.md)。
- 生成物一律不入库：`build/`（可整目录删）、`.cache/`、`.tooling/`、`.dart_tool/`、`.dsh-tmp/`。渲染临时出图写 `build/<切片>-renders/`，图册入库与归档政策见 [docs/implementation/render-archive.md](docs/implementation/render-archive.md)。

## 工作流

- 命令入口：`tool/flutterw analyze|test|pub get|dart format`；Android release 构建：

  ```sh
  MILEAF_HOST_ANDROID_SDK=<host sdk> tool/flutterw android assembleRelease \
    -Ptarget-platform=android-arm64 -Psplit-per-abi=true -Pforce-version-code-ignoring-abi=true
  ```

  产物 `build/app/outputs/apk/release/app-arm64-v8a-release.apk`；入口、探针与 JDK 说明见 [docs/implementation/build-directory.md](docs/implementation/build-directory.md) 与 [build-isolation.md](docs/implementation/build-isolation.md)。
- 设计改动顺序：ADR → spec（条款编号）→ tickets（分包与多会话提示词）→ 实施记录（逐页登记 + 双轴审查）→ 索引。
- 每次收口：`analyze` 无新增诊断、全量 `test` 0 失败、`dart format` 无变更、文案守卫基线只许下降，并在 [docs/agents/history.md](docs/agents/history.md) 追加一条记录。

## Agent skills

### Issue tracker

GitHub Issues in `wynnok/MileafMobile`, via the `gh` CLI.
See `docs/agents/issue-tracker.md`.

### Triage labels

Use the five default triage labels.
See `docs/agents/triage-labels.md`.

### Domain docs

Single-context: 根目录 `GLOSSARY.md`（尚未建立，按需创建）+ `docs/adr/`。
See `docs/agents/domain.md`.

## 历史

- 2026-10-23 至 2026-11-19 的逐条决策、授权、证据与已知偏差已归档到 [docs/agents/history.md](docs/agents/history.md)。本文件只保留**仍然生效**的约束，不承载历史叙述。
