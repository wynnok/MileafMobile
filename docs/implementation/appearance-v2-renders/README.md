# 历史图册（图像已归档）

本目录的渲染图片与清单已于 **2026-11-19** 移除，以控制仓库体积；图片完整保存在提交 `34eb042` 及更早的历史中，可按需恢复。本目录属于 2026-11-02 的「外观 v2」（[ADR 0006](../../adr/0006-appearance-and-accent.md)），此后被 [ADR 0011](../../adr/0011-ui-ux-refinement.md) 起的五轮增量相继取代；同一套版式的玉绿版见 [a-renders](../a-renders/README.md)（同样已归档）。

当时的口径（保留作检索线索，图片本身不在此目录）：含 `gallery/` 整册与 `compare/` 新旧同机位对照。

恢复单张：

```sh
git show 34eb042:<本目录下的原路径> > /tmp/render.png
```

恢复整个目录：

```sh
git worktree add /tmp/mileaf-renders 34eb042
```

清理范围与理由见 [render-archive.md](../render-archive.md)。当前在用的图册见 [实施索引](../README.md#7-图册)。
