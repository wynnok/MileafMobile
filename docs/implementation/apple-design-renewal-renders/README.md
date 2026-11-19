# 历史图册（图像已归档）

本目录的渲染图片、`index.html` 与 manifest 清单已于 **2026-11-19** 移除，以控制仓库体积；图片完整保存在提交 `9f4e0b1` 及更早的历史中，可按需恢复。本目录属于 2026-11-14 的 F00–F12「Apple 风格界面焕新」（[ADR 0012](../../adr/0012-apple-design-renewal.md)），已被 [ADR 0014](../../adr/0014-apple-polish.md) 与 [ADR 0016](../../adr/0016-chromatic-language.md) 取代。

当时的口径（保留作检索线索，图片本身不在此目录）：

- 内容分 `before/`、`components/`、`pages/`、`flows/`、`motion/`，参数与命名见 [交付手册](../../specs/apple-design-renewal-delivery.md)。
- 逐票证据在 [F00–F12 记录](../apple-design-renewal/README.md)。

恢复单张：

```sh
git show 9f4e0b1:docs/implementation/apple-design-renewal-renders/pages/overview-normal-light-360-100-top.png > /tmp/f-overview.png
```

恢复整个目录：

```sh
git worktree add /tmp/mileaf-renders 9f4e0b1
```

清理范围与理由见 [render-archive.md](../render-archive.md)。当前在用的图册见 [实施索引](../README.md#7-图册)。
