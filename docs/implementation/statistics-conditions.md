# 统计扩展：温度条件与能耗关联（#19）

2026-10-29，基于本地集成基线 `82d1e07`，冻结契约为 `docs/contracts/openapi-statistics-0.3.0.json`。

统计「能耗」按当前冻结日期范围请求 `driving-analysis?view=conditions`；使用生成的 DrivingAnalysisConditions 闭包校验响应。接入嵌套 summary、distance_bins、temperature_bins、unknown_temperature_drives、独立 coverage/sample_status。分类点图的横轴为服务端温度区间，保留负温度和半开区间；点选、拖动与前后组按钮提供精确读数。所有点均不连线，小样本明确标注仅供点读。展示服务端配对总能量、总里程及电耗原值，不平均逐趟比率；显示单程中位数、平均记录速度、配对样本数与覆盖，阈值/方法版本从响应读取。条件分析只观察关联，不作因果或排名判断。

温度组 evidence_filter 原样复用 #18 完整证据入口，保留原始截止、筛选和方法版本；分页显示完整匹配数，行程点击沿既有 workspace record 进入详情。请求通过既有缓存层处理 ETag/TTL/429；失败可独立重试并保留快照，车辆/会话/时区/范围作用域和请求序号阻止迟到覆盖。

生成器仅新增实际契约的任意 JSON 对象和恒 null 类型支持（不改旧 DTO）。旧认证、0.1 驾驶统计、0.1 充电统计、0.2 充电体验六 root 闭包重新生成后逐字节 cmp 均通过。

验证：

- 新 App＋可控 HTTP 测试 4 项：负温度/服务端原值/证据分页完整查询；360×800 深色 200% 字号温度选组、零与缺失；资源失败重试/快照；切车迟到隔离。
- 条件、节奏、旧统计与洞察入口限定回归共 26 项通过。
- `tool/flutterw analyze --no-pub` 无问题；变更 Dart 格式检查与 `git diff --check` 通过。
- 运行日志在工作树 `.cache/conditions-*.log`（不提交）。测试 SDK 只读复用主项目 `.tooling/flutter`，pub 缓存与测试输出在本工作树内。

正式 Flutter 图册、双端隔离构建及双轴审查由集成任务统一执行，本记录不宣称这些验证已通过。真实站点、真机、地图与 Grafana 对照继续待验，不推送、不部署、不关闭 Ticket。
