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
- docs/product/ 保存正式 Spec 配套的产品/体验基线，不另建相互冲突的规格。
  Spec #1 和 #2–#17 已发布；2026-10-25 用户要求澄清核心展示方式，本轮修订 Spec #1 正文及相关既有工单的展示验收，不创建重复工单、不关闭未验收条目、不改原生依赖边。后续按修订基线设计和实施，不再按历史“等待 to-spec”停止。
