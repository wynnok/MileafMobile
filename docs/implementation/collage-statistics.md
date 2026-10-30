# C 统计首页（#14）

2026-10-30。以 Spec #1 C 增量、#14 与 ADR 0001 及 C 原型为依据。

统计入口为期间控件 → 期间里程主 tile / 比较结论 → 本期参照主图 / 相邻原值 → 2×2 节奏、能耗、补能、长期章节。200% 章节单列，技术时间戳收进数据说明。图表切换、完整指标与口径入口、服务端 totals、比较质量与缓存规则不变。

章节用独立 Scaffold 路由；StatisticsInsightsContext 的 workspace/currency/selection/features/window 接缝保持不变，后续 #15/#18–#21 继续在原 builder 专题内细化。窗口在进入时冻结，车辆/会话/时区 revision 变更即移除旧路由内容并退出。旧 initialTopic 路径保留并可返回总览；默认统计入口继续恢复总览。

## 验证

- TDD：先新增首页不含总览专题 ChoiceChip 断言，看到旧导航失败，再完成 C 首页。App＋可控 HTTP 操作覆盖章节往返、时区、期间及原读取规则。
- statistics_insights_test、statistics_usage_test、owner_experience_test、statistics_test、charging_statistics_test 共 49 项通过。
- statistics_insights_page 与专有渲染入口静态分析通过；git diff --check 通过。
- test/collage_statistics_render_test.dart 实际 Flutter 渲染通过；collage-renders/statistics 下 normal/empty/missing × light/dark × 100/200 共 12 张。360×800 正常首屏已人工查看结论、实际绘图区、双方读数与第一排章节；空态无伪零趋势、缺失电耗为 —；200% 主数和单位换行、章节单列。
- 扩大运行旧 conditions/range/parking 测试发现旧固定 tab 点击路径失效，已通知对应专题 worker 适配；这些后续测试不标为通过。历史 owner_*render 保持原样，C 首页证据使用专有新入口。

重现：MILEAF_FLUTTER_SDK 指向原仓库 .tooling/flutter，使用 tool/flutterw test --no-pub test/collage_statistics_render_test.dart，传入 MILEAF_RENDER_OUTPUT=docs/implementation/collage-renders/statistics 和 MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf 的 dart-define。

无 API、后端、依赖或全局配置变化。真实站点/真机/性能、用户最终视觉验收保持待验；不推送或关闭票。项目依赖与图册为保留资源，本次 /private/tmp/c14-edit.py 与被替代的 edge/failure 截图已精确删除。
