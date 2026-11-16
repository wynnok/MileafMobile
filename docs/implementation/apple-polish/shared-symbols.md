# 跨票共享符号表（W4 签名冻结）

2026-11-16，AP00 生成。W4 页面包之间存在下列 import（文件级，交付手册 §3.4）。被调用的公开类、函数与构造参数在 W4 期间签名冻结；持有票只能改内部呈现，需要改签名时交总控。

## 被调用文件（持有票）与调用方（持有票）

| 被调用文件（持有票） | 关键公开符号 | 调用方（持有票） |
| --- | --- | --- |
| statistics_insights_page.dart（AP11） | StatisticsInsightsPage、canCompare()、referenceWindow() | overview_page.dart（AP08）、statistics_usage_page.dart、statistics_charging_page.dart、statistics_range_page.dart、statistics_parking_page.dart（AP12a/AP12b） |
| statistics_period.dart（AP11） | StatisticsPeriod、StatisticsSelection、StatisticsWindow、StatisticsPeriodControls、bucketIndexAt()、statisticsDate() | overview_page.dart（AP08）、charging_page.dart（AP10）、statistics_usage_page.dart、statistics_charging_page.dart（AP12a） |
| statistics_usage_page.dart（AP12a，含 StatisticsTopicNotes） | StatisticsTopicNotes、StatisticsTopicFact、StatisticsTopicFacts、usageValue()、usageMap()、usageItems() | statistics_conditions_page.dart、statistics_charging_page.dart（AP12a）、statistics_range_page.dart（AP12b） |
| 五个专题页（AP12a、AP12b） | StatisticsUsagePage、StatisticsConditionsPage、StatisticsChargingPage、StatisticsRangePage、StatisticsParkingPage | statistics_page.dart（AP11） |
| charging_page.dart、charging_detail.dart（AP10） | ChargingPage、ChargingFilter、ChargingEntry、ChargingDetailPage、openChargingDetail()、heatingLabel() | statistics_charging_page.dart（AP12a） |
| charging_cost.dart（AP13） | showChargingCostSheet()、supportsChargingCost()、canFillChargingCost()、ChargingCostAction | charging_page.dart、charging_detail.dart（AP10） |
| map/map_consent_sheet.dart、map/map_privacy_page.dart（AP13） | showMapConsentSheet()、mapPrivacyUrl()、MapPrivacyPage | map/map_panel.dart（AP09） |
| 各页面文件 | 页面 Widget | workspace_page.dart 外壳（AP02，W2 已冻结） |

## 冻结规则

- W4 期间上述公开符号签名不变；持有票只改内部呈现。
- 若改用 AP04 的「关于这些数据」组件，保留原符号作为签名不变的适配层，由 AP14 清理（如 StatisticsTopicNotes）。
- 需要改签名时，票会话提交最小补丁与理由给总控，由总控在集成窗口修改并通知所有受影响票复验。
