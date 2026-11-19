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

> **2026-11-19 更新**：本节所列两册随后也已归档（见文末「第三轮归档」）；现在保留下来的都是**切片证据图册**（每个切片几到一百多张），不再保留整代整册。

- [appearance-v2-renders/](appearance-v2-renders/README.md)：当前一代，电光蓝 + 中性底，含 132 张整册与 24 张同机位新旧对比。
- [a-renders/](a-renders/README.md)：上一代 A 夜航（玉绿），仅作外观 v2 的对照与历史证据，不再更新。
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

## 2026-11-19 第二轮归档（用户授权）

用户确认「已经被替代的可以删除」后，按同一口径归档两代已结束的整册。删除的是图片、`index.html` 与 manifest 清单；两个目录各留一份 README 说明归档事实、恢复方式与检索线索，文字记录（ADR/Spec/逐票记录）全部保留。

| 目录 | 时期 | 来源决定 | 删除文件 | 体积 |
| --- | --- | --- | --- | --- |
| `ui-ux-refinement-renders/` | 2026-11-12 ~ 11-14 | [ADR 0011](../adr/0011-ui-ux-refinement.md)、[交付手册](../specs/ui-ux-refinement-delivery.md) | 1850 张 PNG + `index.html` + 各票 manifest | 214 MiB |
| `apple-design-renewal-renders/` | 2026-11-14 | [ADR 0012](../adr/0012-apple-design-renewal.md)、[交付手册](../specs/apple-design-renewal-delivery.md) | 1057 张 PNG + `index.html` + 各票 manifest | 125 MiB |
| 合计 | | | 2907 张 | 339 MiB |

恢复：图片仍在提交 `9f4e0b1` 及更早的历史里，单张 `git show 9f4e0b1:<路径>`，整目录 `git worktree add /tmp/mileaf-renders 9f4e0b1`。

文档处理：`docs/specs/apple-design-renewal.md` §2.2 的 5 处目视图像引用与 `U08.md` 的 manifest 链接改为「（图已归档）」文字，并指向本文件或图册 README；其余引用都是行内代码里的路径描述，作为历史陈述保留。

`.git` 历史体积不变（旧对象仍在）；本次收益是工作区体积与 clone 时间。归档后保留的整册：`apple-polish-renders/`（ADR 0014，上一代）、`readability-renders/`、`appearance-v2-renders/`、`a-renders/` 与各切片证据图册。

## 2026-11-19 第三轮归档（用户授权）

用户确认「剩四个也被取代的整册，一并对齐」后，把 2026-11-02 政策里保留的两册连同另两册整册一并归档。口径与第二轮一致：删图片与清单，各留一份 README（恢复提交 `34eb042`）。

| 目录 | 来源决定 | 删除 | 体积 |
| --- | --- | --- | --- |
| `apple-polish-renders/` | [ADR 0014](../adr/0014-apple-polish.md) | 442 张 PNG + 分票清单 | 60 MB |
| `readability-renders/` | ADR 0011 时期的阅读体验增量 | 320 张 PNG | 46 MB |
| `appearance-v2-renders/` | [ADR 0006](../adr/0006-appearance-and-accent.md) | 156 张 PNG（含 `compare/` 对照） | 28 MB |
| `a-renders/` | [ADR 0003](../adr/0003-visual-direction-a.md) | 156 张 PNG（含 `overview/`、`gallery/`、`charging-method/`） | 25 MB |
| 合计 | | 1074 张 | 159 MB |

同时删掉 `a-renders/overview/`、`a-renders/gallery/`、`a-renders/charging-method/` 三个子目录的 README，指向它们的 12 条文档链接统一改指 `a-renders/README.md`。

三轮合计归档 4682 张 PNG：`docs/` 由 558 MB 降到 60 MB，`docs/implementation/` 由 539 MB 降到约 40 MB。`.git` 历史体积不变，图片仍可从历史提交恢复（单张 `git show <提交>:<路径>`，整目录 `git worktree add`）。

**现行图册政策**：只保留切片证据图册（每个切片几到一百多张 PNG，供 ADR/Spec 逐条引用）；整代整册一旦被后续 ADR 取代即归档为 README 存根。
