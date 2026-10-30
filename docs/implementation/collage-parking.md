# C「数据拼贴」停放观察

2026-10-30，#21 切片，基于集成 d16f0ab。沿用统计章节卡 → 长期 → 停放观察独立专题及当前车辆/期间/时区。没有修改统计 shell、API、缓存或分页边界。

深绿主 tile 以服务端有效窗口 SOC 变化为主数，标准化率、窗口数和观测小时为背景，紧邻提示「仅代表有效观测窗口」。随后保留正/负/零主图、选点读数和前后点按钮、四类状态比例、排除计数及可分页窗口证据。方法、阈值、归期与查询生成时间收进可展开的数据说明；不推断车辆功能耗能。零有效窗口显示破折号，分桶缺失不补零；并未用分页重新计算汇总。

验证结果：

- App＋可控 HTTP 红→绿：先适配既有长期章节导航，再确认旧页面缺少新主结果提示而失败；实施后4项行为通过，含200%完整页滚动、失败独立重试、服务端汇总/正负零选点/固定分页上下文/数据说明展开、无有效窗口不显示零损耗。
- 1项正式 Flutter 渲染通过：360×800，正常/无有效窗口且无桶/分桶变化缺失 × 浅深色 × 100%/200%，共32张 result/chart/evidence，位于 `collage-renders/parking/`。每次截图均检查 Flutter 异常；200%滚动到分页证据，无overflow。直接查看正常浅色100%结果、正常深色200%图、缺失深色200%图、空态浅色200%结果，主数、单位、图形与折行可读。
- 目标页面及两项测试文件 `flutter analyze --no-pub` 通过。

复现：使用既有项目 SDK 设置 `MILEAF_FLUTTER_SDK`，执行 `tool/flutterw test --no-pub test/statistics_parking_test.dart test/collage_parking_render_test.dart --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/collage-renders/parking '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'`。图册来源为测试内固定合成 HTTP 响应和正式 Flutter 页面；不是实际站点证据。字体仅渲染时读取系统字体，没有新增依赖。

完整 App、双端隔离构建和跨页双轴审查由 #17 集成复验承接，本切片没有重跑设备/真实站点。用户视觉评审、真机、真实站点/Grafana对账与规模性能保持待验；未推送、部署或修改/关闭工单。缓存和项目依赖留在任务工作树；未创建待清理临时环境或后台服务。
