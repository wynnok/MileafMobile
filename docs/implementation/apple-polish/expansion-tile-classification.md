# ExpansionTile 分类（R30.3）

2026-11-16，AP00 生成。现有 25 处 ExpansionTile（widget 用法；另有 disclosure.dart 注释、theme.dart 的 ExpansionTileThemeData、map_privacy_page.dart:194 注释共 3 处非 widget 引用，不计入）。按规格 R30.3 分为说明类与内容类。说明类迁入「关于这些数据」（内容不删、标题按 CP02 改名），内容类保留原位。两类都改用 MileafDisclosure，不再直接使用 ExpansionTile。

## 说明类（16 处，迁入「关于这些数据」）

| 文件:行 | 标题 | 目标分组（五类之一） |
| --- | --- | --- |
| overview_page.dart:1712 | 比较区间与口径 | 口径与估算 |
| overview_page.dart:1786 | 车辆与数据时间 | 时间与时区 |
| overview_page.dart:1814 | 数据说明与更多 | 口径与估算 |
| charging_detail.dart:615 | 过程数据说明 | 口径与估算 |
| charging_detail.dart:1041 | 曲线数据说明 | 口径与估算 |
| charging_detail.dart:1397 | 曲线数据说明 | 口径与估算 |
| drives_page.dart:828 | 数据说明 | 口径与估算 |
| charging_page.dart:2019 | 数据说明 | 口径与估算 |
| statistics_page.dart:586 | 统计口径 | 口径与估算 |
| statistics_page.dart:833 | 统计口径 | 口径与估算 |
| statistics_insights_page.dart:1232 | 数据说明与更多 | 口径与估算 |
| statistics_insights_page.dart:1296 | 参照原值与质量 | 记录与缺失 |
| statistics_insights_page.dart:1317 | 数据说明 | 口径与估算 |
| statistics_insights_page.dart:1495 | 数据说明 | 口径与估算 |
| statistics_parking_page.dart:541 | 数据说明 | 口径与估算 |
| statistics_conditions_page.dart:526 | 距离组数据覆盖 | 记录与缺失 |

## 内容类（9 处，保留原位）

| 文件:行 | 标题 | 保留理由 |
| --- | --- | --- |
| charging_detail.dart:717 | 更多充电信息 | 记录行内明细 |
| charging_detail.dart:1053 | 电池加热状态变化 | 电池加热重叠事件 |
| charging_detail.dart:1140 | 状态变化明细 | 记录行内明细 |
| statistics_usage_page.dart:158 | （helper，title 参数） | 专题内展开，由 AP12a 按内容定性 |
| map/map_privacy_page.dart:218 | （动态 title） | 地图设置的申请帮助与隐私说明，保留原位 |
| statistics_page.dart:948 | （日期+数值 bucket 行） | 记录行内明细 |
| statistics_page.dart:983 | （日期+数值 bucket 行） | 记录行内明细 |
| statistics_insights_page.dart:252 | （长期索引展开） | 长期索引两入口，保留原位 |
| statistics_parking_page.dart:510 | （window_id+有效/未计入+质量） | 停车记录逐行明细，保留原位 |

统计：说明类 16、内容类 9，合计 25。
