# 历史图册（图像已归档）

本目录的渲染图片与清单已于 **2026-11-19** 移除，以控制仓库体积；图片完整保存在提交 `34eb042` 及更早的历史中，可按需恢复。本目录属于 2026-10-31 至 11-02 的「A 夜航」（[ADR 0003](../../adr/0003-visual-direction-a.md)），配色与默认外观由 [ADR 0006](../../adr/0006-appearance-and-accent.md) 修订，版式随后被 [ADR 0011](../../adr/0011-ui-ux-refinement.md) 起的增量取代。

当时的口径（保留作检索线索，图片本身不在此目录）：分 `overview/`、`gallery/`、`charging-method/` 三组，是外观 v2 的同机位对照来源。

恢复单张：

```sh
git show 34eb042:<本目录下的原路径> > /tmp/render.png
```

恢复整个目录：

```sh
git worktree add /tmp/mileaf-renders 34eb042
```

清理范围与理由见 [render-archive.md](../render-archive.md)。当前在用的图册见 [实施索引](../README.md#7-图册)。
