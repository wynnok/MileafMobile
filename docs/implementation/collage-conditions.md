# C 能耗条件专题（#19）

2026-10-30：复用 #14 的章节卡→独立专题页和冻结车辆/期间上下文，能耗页改为选中温度组的深绿主结果 tile → 温度点图 → 样本背景与完整证据 → 距离分组。主数直接读取服务端配对电耗；湖畔配色、5°C 半开组、负温度、未知温度、短/中/长途服务端分组、独立有效集、配对原值及 evidence_filter 均保留。完整覆盖与暂定方法收进数据说明，关联/小样本提示紧邻结果；稀疏点仍为空心且不连趋势线。

已确认的 App＋可控 HTTP 边界按 TDD 执行：先增加 C 主结果断言，旧页因缺少主结果失败，再实施。5 项行为测试通过：负温度/服务端值/原 evidence_filter 分页，360×800 深色200%选组的0/null，失败重试和快照，章节按需进入且返回切期间保留车辆/tz，切车迟到结果隔离。静态分析无问题；git diff --check 通过。

正式 Flutter 渲染为 `collage-renders/conditions/` 的24张 PNG：正常/空/缺失 × 浅/深 ×100%/200%共12张首屏；正常温度点图、样本证据、距离分组各4张。布局视口360×800、导出倍率2。已人工检查代表浅色正常、深色200%主数与点图、空态、缺失态及样本/距离下层；无测试溢出异常，单位与温度读数可见，大字单列流式滚动。200%主数缩紧字号保留 Wh/km 整体；首屏后的图与样本通过滚动查看。截图里的数值为可控HTTP固定测试数据，非真实站点结果。

复现：MILEAF_FLUTTER_SDK 指向原项目 `.tooling/flutter`，执行 `tool/flutterw test --no-pub test/statistics_conditions_test.dart test/collage_conditions_render_test.dart --dart-define=MILEAF_RENDER_OUTPUT=docs/implementation/collage-renders/conditions '--dart-define=MILEAF_RENDER_FONT=/System/Library/Fonts/Supplemental/Arial Unicode.ttf'`。不传渲染参数时渲染测试跳过。

未修改 API/后端/缓存/共享 shell。整体验收交 #17 复验；用户视觉评审、真机、真实站点、Grafana/地图与外部性能保持待验，不关闭 Ticket、不推送。工作树及本地依赖为本次交付与复验保留，未创建临时后台进程或全局依赖。
