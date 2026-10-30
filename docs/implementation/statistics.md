# Ticket #14：驾驶统计与日历区间

2026-10-25 修订说明：本文记录既有数据/逐桶条形实现，不能作为新增[可视化 V06–V08](../product/visualization-requirements.md)的完成证据。#14 还须完整里程/次数/能量/最高速度时间图与净毛电耗比较，#15 还须能量/次数/费用/均价时间图及 AC/DC 比较，补实际图形、切指标/选点和视觉验收；逐桶文字及进度条不能替代。

驾驶统计经统一 BusinessCache / SessionController 发出授权 GET，固定 OpenAPI 的 DrivingStats 闭包生成 DTO。总计直接显示 totals，趋势按 buckets 的日期展示横向里程柱形与可展开指标读数，不再平均桶比率，也不添加观测零点；零与 null 分开。驾驶按已完成行程 started_at 归期；可见说明区分行程估算净能耗与按结束时间归期的充入电池能量毛电耗。

## 统计共享接口

StatisticsPage 是统计入口的当前唯一承载页，驾驶和充电入口明确分开；#15 已在此接入独立充电视图，复用同一区间计算。StatisticsSelection 保存 period 与含首尾的 start/end 日历日期（UTC DateTime 仅作为年/月/日容器）；resolve(calendar, now) 返回 StatisticsWindow，其 query(kind, calendar) 生成完整查询。StatisticsPeriodControls 接受 selection/calendar/now/onChanged，完成周/月/年/自定义选择和合法性提示。不同 kind 应各持有自己的加载、错误和响应快照，失败不能清掉另一视图成功结果。

自定义日期输入格式 YYYY-MM-DD，严格检查真实日期。结束为今天时截止 now，否则转换到次日零点；周一开始。本周/月 day、本年 month；自定义≤31日 day、32–180日 week、其余 month。日历天数用于选桶，UTC 时差用于 0<duration≤730×24小时验证，两者不能互换。CalendarContext 负责 IANA/DST，禁止固定24小时模拟次日。前台重读设备时区/日历日期，清旧查询数据，自定义仍保留原日历字段重算。

WorkspacePage 的统计页 identity 只包含车辆 ID，不能加 workspace.revision，否则前台换时区会丢失自定义日期。车辆变更仍创建新页面并阻止迟到响应。页内请求 sequence 与 captured session、vehicle、timezone 同时检查；条件刷新/失败快照沿用共享缓存；仅可见页响应前台，无后台轮询。

## 自动化证据

采用用户已确认的 App 操作 + 可控 HTTP 边界。先验证未接入统计时没有请求的红灯；实现后通过。再用前台时区变更的红灯证明旧快照错误保留，修正为先清旧归期数据再查询。测试覆盖默认本月、周一/年起点、固定当前截止、31/32/180/181日分桶、纽约2026-03-08的23小时日与2026-11-01的25小时日、UTC730/731日与零跨度、前台时区变化保留自定义、迟到切车、304、失败快照、360宽200%字体深色和逐桶文字读数、真实零和null。

固定驾驶响应来自 Server 146cb3b9a16af3d632b04ed8d197d0f2243d9b71 的真实认证 HTTP ASGI + 隔离 PostgreSQL 合成数据。源样本查询：车辆1，kind=driving，bucket=month，from=2026-01-01T00:00:00Z，to=2026-04-01T00:00:00Z，tz=Asia/Shanghai。该样本用于 DTO 解码与 totals 对照，不宣称每条日期行为测试的模拟请求都等同此源查询。源 totals：49次、960km、180kWh、净188Wh/km、毛167Wh/km、最高90km/h；桶毛电耗32/286/500/缺失，不能将其平均当总计。

## 保留待验

尚未连接真实站点做 Grafana 同车同区间对账，也未在 Android/iPhone 实测屏幕阅读器、设备 IANA/DST切换；平台构建由集成协调完成。自动化不替代这些外部证据，Ticket 保持开放，原生验收阻塞关系不变。

# Ticket #15：充电统计与费用／能量口径

统计入口现已接入驾驶/充电两种视图。各自保留独立日历选择、加载、错误和结果；只有当前 kind 激活或恢复前台时读取。两页共用 StatisticsSelection/StatisticsPeriodControls 和统一授权缓存；切车重建整个统计上下文，旧响应不能混入新车。充电使用固定 OpenAPI 的 ChargingStats 引用闭包生成 DTO，无新端点，无客户端业务补算。

充电显示 totals 的会话数、充入电池能量、已知费用合计、已知费用均价、AC/DC 充入能量与 DC 占比；趋势保留每桶能量和可展开文字读数。AC/DC 为独立值，不归一为全部能量，不反推未知能量。未知分类不算 AC；DC 占比分母是已知分类能量。当前契约没有电网侧 energy_used 或效率字段，统计不自行推导这些指标。费用 null 与真实0分开，均价只代表费用已知记录；不能声称合计覆盖全部费用。完成会话按 ended_at 归期，与列表 started_at 跨边界可能不同，进行中不计入。

币种直接订阅 WorkspacePage 所拥有的 CurrencySettings，仅更改展示标签和最多两位的显示舍入；未配置明确未知、无人民币符号、不换汇。站点身份与普通偏好仍由既有 CurrencySettings 负责，统计不另建设置副本。统计错误保留 ApiFailure 的现有分类提示，有旧数据时补充保留快照说明；共享429节流由统一业务缓存处理，不在本页另建重试调度。

新增6条 App/HTTP 行为测试，从尚无充电入口的红灯开始，验证真实合成样本 totals、费用和比例不再平均、两种区间独立、同kind条件304、一个失败不抹掉另一成功结果、驾驶/充电迟到响应与切车、站点币种共享、未知费用/真实0、可展开桶读数、360宽200%深色、DST23小时日、730天限制复用与前台只请求当前kind。大字体列表滚动验收等待每次可见性滚动的布局帧，避免对尚未构建的惰性项误判。

固定充电样本来源与驾驶一致：Server 146cb3b9a16af3d632b04ed8d197d0f2243d9b71，真实授权HTTP ASGI + 隔离合成PostgreSQL。源查询车辆1，kind=charging，bucket=month，from=2026-01-01T00:00:00Z，to=2026-04-01T00:00:00Z，tz=Asia/Shanghai。源 totals：8次、充入160kWh、已知费用72、均价0.5142857142857142、AC120kWh、DC20kWh、DC占比0.14285714285714285；桶均价0.6/0.6/0.48/缺失，独立total不能以桶均价再平均。源总能量与AC+DC不相等是已存在未知分类数据，客户端既不归入AC也不构造新unknown_energy。

保留外部待验：真实站点与Grafana相同车辆/区间/时区的充电归期、费用和能量对账，Android/iPhone原生币种偏好恢复与屏幕阅读器、最终双端发布构建。代码及自动化不替代这些证据，相关Ticket仍保持开放，原生阻塞边不改。
