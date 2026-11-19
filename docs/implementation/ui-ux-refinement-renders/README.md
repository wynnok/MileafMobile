# 历史图册（图像已归档）

本目录的渲染图片、`index.html` 与 manifest 清单已于 **2026-11-19** 移除，以控制仓库体积；图片完整保存在提交 `9f4e0b1` 及更早的历史中，可按需恢复。本目录属于 2026-11-12 至 11-14 的 U00–U12「整体 UI/UX 优化」（[ADR 0011](../../adr/0011-ui-ux-refinement.md)），已被 [ADR 0012](../../adr/0012-apple-design-renewal.md)、[ADR 0014](../../adr/0014-apple-polish.md)、[ADR 0016](../../adr/0016-chromatic-language.md) 相继取代。

当时的口径（保留作检索线索，图片本身不在此目录）：

- 唯一渲染根即本目录，子目录为 `gallery/`、`flows/`、`states/`、`reading/`、`components/` 与各票目录（`u04`–`u11`），命名见 [交付手册](../../specs/ui-ux-refinement-delivery.md)。
- 逐票证据与几何测量在 [U00–U12 记录](../ui-ux-refinement/README.md)；U08 的 120 张与 U09a–e 的清单在各自记录的 manifest 段。

恢复单张：

```sh
git show 9f4e0b1:docs/implementation/ui-ux-refinement-renders/gallery/u08-statistics-normal-light-360-100-top.png > /tmp/u08.png
```

恢复整个目录：

```sh
git worktree add /tmp/mileaf-renders 9f4e0b1
```

清理范围与理由见 [render-archive.md](../render-archive.md)。当前在用的图册见 [实施索引](../README.md#7-图册)。
