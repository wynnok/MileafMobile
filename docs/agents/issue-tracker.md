# Issue tracker: GitHub

本仓库的 issue 和正式 spec 存放于 wynnok/MileafMobile 的 GitHub Issues。
使用 gh CLI；操作时显式指定 --repo wynnok/MileafMobile，
避免误写符号链接指向的后端仓库。

## 操作约定

- 读取：gh issue view <number> --repo wynnok/MileafMobile
  --json number,title,body,labels,comments
- 列表：gh issue list --repo wynnok/MileafMobile --state open
  --json number,title,body,labels
- 创建：gh issue create --repo wynnok/MileafMobile
  --title "<title>" --body-file <body.md>
- 评论：gh issue comment <number> --repo wynnok/MileafMobile
  --body-file <comment.md>
- 标签：gh issue edit <number> --repo wynnok/MileafMobile
  --add-label "<label>" / --remove-label "<label>"
- 关闭：gh issue close <number> --repo wynnok/MileafMobile
- 多行正文使用 UTF-8 文件和 --body-file，保留真实换行。
- 子任务优先使用 GitHub sub-issues；不可用时以 Part of #<parent>
  和父 issue 的任务列表关联。依赖优先使用原生 issue dependencies，
  不可用时明确记录 Blocked by: #<number>。

## Pull requests as a triage surface

PRs as a request surface: no.

## 技能约定

- “publish to the issue tracker”：创建 GitHub issue。
- “fetch the relevant ticket”：读取对应 GitHub issue。
- wayfinder 的 map 和 child ticket 均使用 issue；
  map 使用 wayfinder:map，child 使用 wayfinder:<type>。
  认领时分配执行者，解决后记录结论并关闭。
- docs/product/ 保存需求准备材料，不替代正式 spec。
  本轮不发布 spec、不创建实施工单；等待用户确认后调用 to-spec。
