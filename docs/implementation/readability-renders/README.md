# 历史图册（图像已归档）

本目录的渲染图片与清单已于 **2026-11-19** 移除，以控制仓库体积；图片完整保存在提交 `34eb042` 及更早的历史中，可按需恢复。本目录属于 2026-11-15 至 11-16 的「阅读体验与图形可读性」（[ADR 0011](../../adr/0011-ui-ux-refinement.md)），已被后续 [ADR 0014](../../adr/0014-apple-polish.md) 与 [ADR 0016](../../adr/0016-chromatic-language.md) 取代。

当时的口径（保留作检索线索，图片本身不在此目录）：分 `gallery/`、`design/`、`cost/`、`map/`、`charging-method/` 五组，逐页记录分散在概览/行程/充电/统计各实施记录。

恢复单张：

```sh
git show 34eb042:<本目录下的原路径> > /tmp/render.png
```

恢复整个目录：

```sh
git worktree add /tmp/mileaf-renders 34eb042
```

清理范围与理由见 [render-archive.md](../render-archive.md)。当前在用的图册见 [实施索引](../README.md#7-图册)。
