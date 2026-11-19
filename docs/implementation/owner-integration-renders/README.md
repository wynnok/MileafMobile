# 历史图册（图像已归档）

本目录的渲染图片、`index.html`与清单文件已于 2026-11-02 移除，以控制仓库体积；这些图片仍完整保存在提交 `725ceda` 中，可按需恢复。本目录此前属于owner 集成复验（2026-10-29），已被后续视觉方向取代。

恢复单张：

```sh
git show 725ceda:docs/implementation/owner-integration-renders/charging/detail-dark-100.png
```

恢复整个目录：

```sh
git worktree add /tmp/mileaf-renders 725ceda
```

清理范围与理由见 [render-archive.md](../render-archive.md)。当前在用的图册是 [appearance-v2-renders](../appearance-v2-renders/README.md)（外观 v2）与 [a-renders](../a-renders/README.md)（A 夜航）。
