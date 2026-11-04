# 缺失充电费用补录 · 双轴审查

2026-11-04；按 code-review 技能使用两个独立、只读子代理分别审查 Standards 与 Spec，再各自复核修复。

- 实现前固定基线：`209d056c285809a8a745f50927be78e9cf0dfb84`。
- 初审实现提交：`80c0662 feat: add limited missing charging cost entry`。
- 初审差异：`git diff 209d056c285809a8a745f50927be78e9cf0dfb84...80c0662`；本次文件与新增图册/契约/文档均在提交中。
- 修复复核：相对 `80c0662` 的本次工作区差异，及新增 [延迟地点回归](../../test/charging_cost_refresh_test.dart)。复核后的修复与本记录另建本地提交，不改写历史、不推送。
- 来源：仓库AGENTS、domain规则、ADR 0003/0006/0007、视觉系统Spec、analysis_options，以及用户已确认的[费用补录Spec](../specs/missing-charging-cost-entry.md)和[Ticket](../specs/missing-charging-cost-entry-tickets.md)。
- 排除：原有.gitignore修改、creator与既有未跟踪产品/原型文件；未评审或修改外部后端仓库。

## Standards

初审发现 **1项P2**：补能专题的费用刷新仅等待 `load()`，而地点汇总通过 `unawaited(loadLocations(...))` 发起；统计先完成、地点稍后失败时会提前报告完整刷新，遗漏“部分汇总暂未更新”。依据 ADR 0007 D5 的刷新地点摘要与失败反馈约定。

其余检查未发现可操作的文档标准违反或值得报告的代码异味。工具能直接检查的样式问题由analyze/format处理，不重复列为人工发现。

修复：[statistics_charging_page.dart](../../lib/src/statistics_charging_page.dart) 的 `refreshCost()` 调用 `load(waitForLocations: true)`；同一次地点请求与统计读取并行，最终等待地点完成再汇总错误。普通进入/刷新行为继续按原异步方式工作。新增回归沿实际App导航：统计→补能→地点账本→补录，地点请求延迟返回503。

复核结论：原P2已解决；回归符合可控HTTP边界；404刷新及隐藏失效入口的修改未发现新问题。复核代理只读检查代码/测试，未重复运行测试，实际执行结果由主代理记录。

## Spec

初审发现 **2项P2**，未发现越界功能或后端改动：

1. **404未刷新列表**：Spec§9要求“关闭并使列表刷新”。GET/PATCH404原先仅设置终态，关闭后已失效记录及入口可能仍留在列表。
2. **地点汇总提前报告完整成功**：Spec§9/CE12要求失败时提示“部分汇总暂未更新，请刷新”；地点读取未等待会漏掉稍后出现的错误。此项与Standards轴涉及同一处实现，分别保留两轴判断，不合并为一个轴的发现。

修复：GET/PATCH404均调用当前授权范围的费用缓存失效和读取回调；详情 `unavailable` 或身份不匹配时不保留旧补录入口。新增 [404关闭后列表移除记录回归](../../test/charging_cost_test.dart)。地点等待修复与Standards轴所述一致。

复核结论：两项P2均已解决，未发现修复引入新的规格问题；新的App/HTTP回归覆盖原404和延迟地点503场景。代理未自行重跑测试，不将主代理提供的34项通过描述为代理执行。

## 验证与边界

修复对应回归先验证失败，再实施修复。费用行为、延迟地点回归及既有补能专题定向测试共 **34通过**。初审前全量 **453通过、6跳过**；修复后最终全量 **455通过、6跳过**，analyze无问题，14个修改Dart文件format无变化；完整结果见[实施记录](charging-cost-entry.md)。6个跳过项为5个opt-in图册与1个性能trace，本次费用图册已另行opt-in执行。

最终视觉结论、真实站点写入/PostgreSQL、真机键盘/字体/读屏、真实地图/性能及本次隔离双端构建均保持待验，不属于未修复代码发现。

审查汇总：Standards初审1项P2，已修复1、未解决0；Spec初审2项P2，已修复2、未解决0。两轴复核均未发现新增问题。
