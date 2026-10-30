# C 用车节奏（#18）

2026-10-30，基于 C Spec 增量与 ADR 0001；复用 #14 章节卡与独立专题路由。主结果为服务端活跃日，驾驶记录时长/每活跃日里程作为辅助；纸面日历热图之后给 P50/P90、距离结构、星期里程与完整证据入口。200% 字号主辅 tile 纵向排列。日历、摘要、证据过滤/完整匹配数/分页和原截止时间沿用原契约，不新增 API。

经协调一并修正 #14 专题头：主路径只显示当地短日期范围，原始 UTC 端点与时区可展开「数据说明」查看。统计导航测试同步验证折叠前后及返回总览。

## 验证

- App＋可控 HTTP seam。先添加可见主结果说明断言，确认红灯后实现；随后 21 项 statistics_usage_test / statistics_insights_test 通过，覆盖按需读取、同车同期间时区、独立页返回、完整匹配证据分页、冻结截止与200%布局。
- 旧 usageClient 的不完整 meta 改为冻结契约 fixture，避免误走旧能力降级导航。中文返回按钮通过 BackButton 操作，避免 tester.pageBack 的英文 Back tooltip 假设。
- 五个变更 Dart 文件静态分析通过；git diff --check 通过。
- 正式 App 渲染入口 test/collage_rhythm_render_test.dart 通过；图册 collage-renders/rhythm 共16张：normal/empty/missing × light/dark × 100/200 共12张，加正常星期分布4张。人工查看主结果、空态、缺失与200%分布；无 overflow 异常，缺失显示 —，空态不制造活动日。正常100%首屏包含实际日历格及分位读数，200%可滚动到日历与结构图。

复现：MILEAF_FLUTTER_SDK 指向原项目 .tooling/flutter，以 tool/flutterw test --no-pub 运行上述测试；渲染传 MILEAF_RENDER_OUTPUT=docs/implementation/collage-renders/rhythm 与 MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf 的 dart-define。

保留 managed worktree c-18、项目 .cache/.dart_tool/build（依赖与测试产物）及图册供整体验证；没有一次性脚本、服务或全局安装。未改后端/配置/依赖；未推送或关闭票。用户最终视觉评审、真机/真实站点/Grafana与性能继续待验。
