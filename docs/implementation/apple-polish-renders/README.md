# 历史图册（图像已归档）

本目录的渲染图片与清单已于 **2026-11-19** 移除，以控制仓库体积；图片完整保存在提交 `34eb042` 及更早的历史中，可按需恢复。本目录属于 2026-11-16 至 11-18 的「Apple 质感精修」（[ADR 0014](../../adr/0014-apple-polish.md)），已被 [ADR 0015](../../adr/0015-days-matter-language-migration.md) 与 [ADR 0016](../../adr/0016-chromatic-language.md) 取代。

当时的口径（保留作检索线索，图片本身不在此目录）：按 AP01–AP15 分票出图，参数与命名见 [交付手册](../../specs/apple-polish-delivery.md)；逐票证据在 [apple-polish/](../apple-polish/README.md)。

恢复单张：

```sh
git show 34eb042:<本目录下的原路径> > /tmp/render.png
```

恢复整个目录：

```sh
git worktree add /tmp/mileaf-renders 34eb042
```

清理范围与理由见 [render-archive.md](../render-archive.md)。当前在用的图册见 [实施索引](../README.md#7-图册)。
