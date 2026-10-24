# Ticket #14：驾驶统计与日历区间

驾驶统计经统一 BusinessCache / SessionController 发出授权 GET，固定 OpenAPI 的 DrivingStats 闭包生成 DTO。总计直接显示 totals，趋势按 buckets 的日期展示横向里程柱形与可展开指标读数，不再平均桶比率，也不添加观测零点；零与 null 分开。驾驶按已完成行程 started_at 归期；可见说明区分行程估算净能耗与按结束时间归期的充入电池能量毛电耗。

## 给充电统计切片的接口

StatisticsPage 是统计入口的当前唯一承载页，驾驶和充电入口明确分开，后者当前提示待交付。后续 #15 在此接入充电视图；不要重新实现区间计算。StatisticsSelection 保存 period 与含首尾的 start/end 日历日期（UTC DateTime 仅作为年/月/日容器）；resolve(calendar, now) 返回 StatisticsWindow，其 query(kind, calendar) 生成完整查询。StatisticsPeriodControls 接受 selection/calendar/now/onChanged，完成周/月/年/自定义选择和合法性提示。不同 kind 应各持有自己的加载、错误和响应快照，失败不能清掉另一视图成功结果。

自定义日期输入格式 YYYY-MM-DD，严格检查真实日期。结束为今天时截止 now，否则转换到次日零点；周一开始。本周/月 day、本年 month；自定义≤31日 day、32–180日 week、其余 month。日历天数用于选桶，UTC 时差用于 0<duration≤730×24小时验证，两者不能互换。CalendarContext 负责 IANA/DST，禁止固定24小时模拟次日。前台重读设备时区/日历日期，清旧查询数据，自定义仍保留原日历字段重算。

WorkspacePage 的统计页 identity 只包含车辆 ID，不能加 workspace.revision，否则前台换时区会丢失自定义日期。车辆变更仍创建新页面并阻止迟到响应。页内请求 sequence 与 captured session、vehicle、timezone 同时检查；条件刷新/失败快照沿用共享缓存；仅可见页响应前台，无后台轮询。

## 自动化证据

采用用户已确认的 App 操作 + 可控 HTTP 边界。先验证未接入统计时没有请求的红灯；实现后通过。再用前台时区变更的红灯证明旧快照错误保留，修正为先清旧归期数据再查询。测试覆盖默认本月、周一/年起点、固定当前截止、31/32/180/181日分桶、纽约2026-03-08的23小时日与2026-11-01的25小时日、UTC730/731日与零跨度、前台时区变化保留自定义、迟到切车、304、失败快照、360宽200%字体深色和逐桶文字读数、真实零和null。

固定驾驶响应来自 Server 146cb3b9a16af3d632b04ed8d197d0f2243d9b71 的真实认证 HTTP ASGI + 隔离 PostgreSQL 合成数据。源样本查询：车辆1，kind=driving，bucket=month，from=2026-01-01T00:00:00Z，to=2026-04-01T00:00:00Z，tz=Asia/Shanghai。该样本用于 DTO 解码与 totals 对照，不宣称每条日期行为测试的模拟请求都等同此源查询。源 totals：49次、960km、180kWh、净188Wh/km、毛167Wh/km、最高90km/h；桶毛电耗32/286/500/缺失，不能将其平均当总计。

## 保留待验

尚未连接真实站点做 Grafana 同车同区间对账，也未在 Android/iPhone 实测屏幕阅读器、设备 IANA/DST切换；平台构建由集成协调完成。自动化不替代这些外部证据，Ticket 保持开放，原生验收阻塞关系不变。
