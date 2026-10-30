# C 补能统计专题（#15）

2026-10-30，基于 #14 已合入的章节承载，沿用 Spec #1 C 增量、ADR 0001 与原型 C。只修改补能专题，不修改承载接口、API 或数据公式。

补能章节进入独立专题；一个深绿主 tile 展示已知支出和费用有记录次数/对应入电，纸面主图保留入电、已知费用、有效入电均价、会话数四指标。下层保留能量/均价/记录时长证据、AC/DC/未知绝对值和同尺度时间图、地点账目及同条件记录下钻。DC 占比明确以 AC+DC 已知分类能量为分母。完整结束日/开始日边界及配对费用分子分母、校验时间移入数据说明；错误/快照提示保持可见。

验证：

- 已确认 App＋可控 HTTP 接缝。先修正旧 tab 测试为实际滚动章节入口；分类时间图新增断言先失败，再补实现，6 项统计补能回归通过，包含有效均价、地点结束日下钻、局部失败快照、全缺时长、选桶边界、深色200%切图。
- 合入集成基线 83f9c12 后，statistics_charging_test、charging_statistics_test、charging_expansion_test 共30项通过；修正下钻按钮滚动为实际可点击位置，git diff --check 通过。
- flutter analyze --no-pub 无问题；新增 opt-in 正式 Flutter 渲染入口 test/collage_charging_statistics_render_test.dart。
- collage-renders/charging-statistics 共24张：normal/empty/missing × light/dark × 100/200，分别保存主结果/主图及结构。360×800，实际渲染无布局异常；人工检查主图轴/单位/选点原值、深色大字、缺失分类。修复了主 tile 标题显式旧主题色导致的低对比。
- 公共专题顶部完整时间戳仍来自 #14 承载，由其他专题切片统一调整；本切片不修改 statistics_insights_page.dart。

复现：原仓库 .tooling/flutter 作为 MILEAF_FLUTTER_SDK，tool/flutterw test --no-pub test/collage_charging_statistics_render_test.dart，传入 MILEAF_RENDER_OUTPUT=docs/implementation/collage-renders/charging-statistics 和 MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf 的 dart-define。

图册、测试、工作区本地依赖保留。无服务、依赖版本、后端、全局配置、推送、部署或工单更改。真机/真实站点/Grafana、用户视觉和性能验收仍待验，票保持开放。
