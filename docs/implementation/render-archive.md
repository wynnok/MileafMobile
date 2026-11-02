# 历史渲染图册归档说明（2026-11-02）

## 为什么归档

`docs/` 在 2026-11-02 前累计了 1108 张 PNG（约 165 MiB），覆盖湖畔、C 数据拼贴、A 夜航、owner 复验、三次扩展等五轮已结束的视觉证据。这些图片都是后续视觉方向的中间态，不再作为验收依据，却随每次 clone 落到工作区并持续抬高仓库体积。

本轮以最新规范（[外观 v2 Spec](../specs/appearance-v2.md)、[ADR 0006](../adr/0006-appearance-and-accent.md)）为基准，删除已被取代的历史图册，只保留当前一代（外观 v2）与上一代（A 夜航，供同机位对照）。删除的是图片、`index.html` 浏览页和 `provenance/manifest` 清单；各时期的文字实施记录、审查结论与 Spec 增量全部保留。

删除**不缩小** `.git` 历史体积（旧对象仍在），效果是工作区变小、后续增长受控。若确实需要回收历史体积，只能重写共享历史，属于需要单独授权的破坏性操作。

## 已归档的目录

| 目录 | 时期 | 删除文件 | 体积 |
| --- | --- | --- | --- |
| `docs/implementation/collage-renders/` | C「数据拼贴」（2026-10-30 至 10-31） | 293 | 39 MiB |
| `docs/implementation/collage-audit/` 内的图 | C10 视觉验收审计（2026-10-31） | 31 | 4.7 MiB |
| `docs/implementation/lake-renders/` | A「湖畔」（2026-10-26） | 34 | 4.2 MiB |
| `docs/implementation/owner-overview-verification-renders/` | 概览分票矩阵复验（2026-10-29） | 74 | 11 MiB |
| `docs/implementation/owner-statistics-renders/` | 统计分票矩阵复验（2026-10-29） | 118 | 16 MiB |
| `docs/implementation/owner-experience-renders/` | owner 体验核对（2026-10-29） | 42 | 6.2 MiB |
| `docs/implementation/owner-integration-renders/` | owner 集成复验（2026-10-29） | 38 | 5.2 MiB |
| `docs/implementation/overview-briefing-renders/` | 概览「用车简报」扩展（2026-10-27） | 15 | 2.1 MiB |
| `docs/implementation/drives-expansion-renders/` | 行程「出行回顾」扩展（2026-10-27） | 26 | 3.5 MiB |
| `docs/implementation/charging-briefing-renders/` | 充电「补能账本」扩展（2026-10-28） | 30 | 4.6 MiB |
| 合计 | | 701 | 96.4 MiB |

每个被清理的目录保留一份 `README.md` 说明归档事实与恢复方式；`docs/implementation/collage-audit/c-fidelity-report.md` 等文字材料原样保留。实施记录中指向这些图片的链接已就地改为「（已归档）」文字，路径本身保留以便追溯。

## 保留的图册

- [appearance-v2-renders/](appearance-v2-renders/README.md)：当前一代，电光蓝 + 中性底，含 132 张整册与 24 张同机位新旧对比。
- [a-renders/](a-renders/gallery/README.md)：上一代 A 夜航（玉绿），仅作外观 v2 的对照与历史证据，不再更新。
- `docs/prototypes/*/renders/`：设计原型自带的评审图，是被 ADR 与 Spec 直接引用的设计 primary source，不属于实施快照，保留。

## 一并删除的过时渲染入口

图册归档后，这些 opt-in 渲染测试只能把当前页面重新写进已经不存在的目录，且其中一个（`owner_statistics_render_test.dart`）仍在点击早已移除的五个 ChoiceChip，属于既知失效代码。本轮删除 17 个文件：

- `test/collage_*_render_test.dart`（11 个）：C 时期各章节渲染入口
- `test/c_gallery_render_test.dart`、`test/lake_render_test.dart`、`test/owner_render_test.dart`、`test/owner_statistics_render_test.dart`、`test/overview_state_render_test.dart`、`test/charging_expansion_render_test.dart`

被其他测试复用的夹具没有一起删除，而是搬到共享位置：

- `cGalleryClient` → `test/support/c_gallery_client.dart`（`a_overview_test`、`overview_a_regression_test` 仍在使用）
- `stateDriving` → `test/support/overview_state_fixture.dart`（`overview_verification_test` 仍在使用）

保留的渲染入口：`a_gallery_render_test.dart`（当前图册）、`a_overview_render_test.dart`、`a_charging_method_render_test.dart`、`design_gallery_render_test.dart`（组件状态画廊）。

## 恢复方式

图片全部保存在归档前的提交 `725ceda` 中。恢复单张：

```sh
git show 725ceda:docs/implementation/collage-renders/overview/overview-normal-light-100.png > /tmp/overview.png
```

恢复整个目录（只读检出，不影响当前工作区）：

```sh
git worktree add /tmp/mileaf-renders 725ceda
ls /tmp/mileaf-renders/docs/implementation/
```

## 后续策略

1. 视觉方向换代时，新图册直接取代旧图册；只保留当前一代与上一代对照，更早的图册按本文方式归档。
2. 同一代的渲染不重复写入新目录；需要重跑时覆盖原目录，避免出现 `-final`、`-v2` 之类的平行图册。
3. 票面或验收证据需要长期引用单张图片时，把它复制进当前一代图册并写明用途，不要为一次性核对新增整套图册。
