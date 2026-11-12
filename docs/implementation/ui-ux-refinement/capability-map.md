# U00 能力迁移基线

2026-11-12，输入 `main / 80e33848e6bd8a31c25aed40e6355cc1af218919`。产品源码与 `2f8755c` 一致。核验和交接见 [U00.md](U00.md)。

## 阅读约定与数据来源

下表目标为confirmed规格P01–P16中的主要归宿，当前迁移状态均为待实施。多个页面复用同一数据的情况分别记录其原入口。源码路径相对 `lib/src/`，测试列为 `test/` 中的具名测试文件。每行的symbol可用 `rg -n` 精确定位，测试文件覆盖范围应结合测试正文理解，文件存在与通过不能独立证明某个字段的视觉质量。

| 来源 | 当前接口与口径 |
| --- | --- |
| Summary | `vehicles/{id}/summary`，`overview_contract.g.dart`。状态/电量/续航为非实时采样，today由服务端返回 |
| Driving | `vehicles/{id}/stats?kind=driving`，`driving_statistics_contract.g.dart`。totals/buckets分别使用原值，净消耗按续航差和车辆效率估算，毛电耗沿服务端定义 |
| Charging | 同stats的 `kind=charging`，`charging_statistics_contract.g.dart`。仅已结束、按结束时刻归期，费用null有别于0，DC占比以AC+DC已知分类为分母 |
| Expanded | `charging_experience_contract.g.dart`、`statistics_insights_contract.g.dart`等0.2/0.3扩展。以meta能力、字段声明与实际解码分支为准，不跨身份继承 |
| Records | `vehicles/{id}/drives`、`vehicles/{id}/charging-sessions`，游标分页只用于查记录，不重算统计 |
| Detail/Series | `drives/{id}`及其series、`charging-sessions/{id}`及其series。图按原始时间定位、空值断开；原始过程汇总与抽样series分开 |
| Analysis | `vehicles/{id}/driving-analysis?view=usage/conditions`及`vehicles/{id}/drives`证据筛选，`driving_analysis`能力；站点日历和服务端有效集 |
| Long | `vehicles/{id}/range-observations`与`vehicles/{id}/parking-observations`独立能力，`range_observations_contract.g.dart`、`parking_observations_contract.g.dart` |
| Config | SessionController、AppearanceController、CurrencySettings、MapKeyController、MapConsentController及现有安全存储，展示保持其状态与生命周期 |

## V01 概览及用车简报

| ID/能力 | 原页面/入口 | 源码symbol | 数据/口径 | 可见条件 | 目标主要入口 | 现有测试 |
| --- | --- | --- | --- | --- | --- | --- |
| V01-01 状态/开始时刻/更新时间/充电功率 | 概览车况 | `overview_page.dart::_hero/_stateLabel/_vehicleNote` | Summary.state/freshness/chargingPowerKw | summary成功，功率仅充电态且非null | P01车况 | overview_test.dart |
| V01-02 当前SOC | 概览电池弧 | `overview_page.dart::_hero` | Summary.battery.level | 可空，未知不补0 | P01车况电池弧 | a_overview_test.dart |
| V01-03 续航与rated/ideal/未知 | 概览主数 | `overview_page.dart::_hero` | battery.rangeKm/rangeKind，非实时 | 可空 | P01唯一display | overview_a_regression_test.dart |
| V01-04 今日里程 | 概览今日 | `overview_page.dart::_hero/_todayStat` | period.today.distanceKm | summary存在 | P01今日 | overview_briefing_test.dart |
| V01-05 今日次数 | 概览今日 | 同上 | period.today.drives | summary存在，真0保留 | P01今日 | overview_briefing_test.dart |
| V01-06 今日估算消耗 | 概览今日 | 同上 | period.today.energyKwh | 可空，估算限定 | P01今日 | overview_briefing_test.dart |
| V01-07 本月/近7天里程 | 周期主数/里程图 | `overview_page.dart::_monthSection/mainChart` | Driving.totals/buckets.distanceKm | driving资源独立成功 | P01周期摘要+里程图 | overview_visualization_test.dart |
| V01-08 估算净电耗 | 电耗切换/驾驶消耗 | `overview_page.dart::_metricTabs/mainChart/_drivingNote` | Driving.consumptionWhKmNet | 可空，负值保留 | P01电耗图 | overview_visualization_test.dart |
| V01-09 估算驾驶能量 | 驾驶消耗 | `overview_page.dart::_drivingNote` | Driving.totals.energyKwh | driving存在 | P01驾驶与补能明细 | overview_briefing_test.dart |
| V01-10 毛电耗 | 驾驶消耗 | `overview_page.dart::_drivingNote` | Driving.totals.consumptionWhKmGross，非停车损耗 | driving存在 | P01驾驶与补能明细 | overview_briefing_test.dart |
| V01-11 入电量 | 补能切换 | `overview_page.dart::mainChart/_auxReadout` | Charging.energyAddedKwh | charging独立成功 | P01补能图/读值 | overview_visualization_test.dart |
| V01-12 充电次数 | 补能账本 | `overview_page.dart::_chargingNote` | Charging.totals.sessions | charging存在 | P01驾驶与补能明细 | overview_briefing_test.dart |
| V01-13 已知费用 | 费用切换 | `overview_page.dart::mainChart/_auxReadout` | Charging.cost + CurrencySettings | null不作免费 | P01费用图/读值 | overview_verification_test.dart |
| V01-14 入电均价/旧均价 | 补能账本 | `overview_page.dart::_chargingNote` | Expanded.unitCostAdded.value或旧costPerKwh | coverageAvailable分支，缺字段说明 | P01补能账本 | overview_verification_test.dart |
| V01-15 AC/DC绝对电量 | 补能账本分类条 | `overview_page.dart::_shareBar` | Charging.acEnergyKwh/dcEnergyKwh | charging存在 | P01补能账本 | overview_briefing_test.dart |
| V01-16 未知电量/DC已知占比 | 补能账本分类条 | `overview_page.dart::_shareBar` | Expanded.unknownEnergyKwh、Charging.dcEnergyShare | 未知只用服务端扩展，旧版显示— | P01补能账本 | overview_verification_test.dart |
| V01-17 费用覆盖/对应入电 | 已知费用覆盖 | `overview_page.dart::_coverageNote` | costKnownSessions/sessions/costKnownEnergyKwh | coverageAvailable且charging存在 | P01费用覆盖明细 | overview_verification_test.dart |
| V01-18 净电耗比较/依据 | 变化与配对覆盖 | `overview_page.dart::_legacyComparisonNote/_pairedComparisonNote/_showComparisonBasis` | 当前与基期stats，配对值及coverage；不可比只原值 | pairedAvailable决定分支，比较独立加载 | P01比较/依据 | overview_verification_test.dart |
| V01-19 最近行程 | 最近→行程详情 | `overview_page.dart::_recentSection` | Summary.lastDrive.id/startedAt/distanceKm/consumptionWhKm | lastDrive非null才可点 | P01最近行程→P04 | a_overview_test.dart |
| V01-20 最近充电 | 最近→充电详情 | 同上 | Summary.lastCharge.id/startedAt/energyKwh/endSoc | lastCharge非null才可点 | P01最近充电→P05 | a_overview_test.dart |
| V01-21 车辆资料/里程表/固件/校验时间 | 车辆与数据时间 | `overview_page.dart::_vehicleNote`、`workspace_page.dart::_VehicleSheet` | Summary.odometerKm/firmware/freshness，session车辆标识 | 可空字段保留未知 | P01车辆说明 | overview_test.dart |
| V01-22 期间下钻 | 继续/驾驶统计/充电统计 | `overview_page.dart::_continueSection/_drivingNote/_chargingNote` | 当前range.selection原样传递 | callback及range可用 | P01继续探索→P06专题 | overview_statistics_reading_test.dart |

`_Metric.energy`目前存在源码分支，`_metricTabs`仅显示里程/电耗/补能/费用四项。V01-09主要落点为驾驶消耗，后续按P01保留四项控制器。

## V02–V05 记录与详情

| ID/能力 | 原页面/入口 | 源码symbol | 数据/口径 | 可见条件 | 目标主要入口 | 现有测试 |
| --- | --- | --- | --- | --- | --- | --- |
| V02-01 时间/起终点/距离 | 行程记录行 | `drives_page.dart::_featuredRoute/_routeRow` | Records Drive.startedAt/start/end/distanceKm | 列表有记录 | P02记录行 | drives_test.dart |
| V02-02 时长/净电耗/进行中 | 行程记录辅助行 | `drives_page.dart::_duration/_net/_routeRow` | durationMin/consumptionWhKm/endedAt | 缺失/进行中独立呈现 | P02记录行 | a_drives_test.dart |
| V02-03 总里程/次数/能量/净电耗 | 行程汇总 | `drives_page.dart::_summary` | Driving.totals，非分页聚合 | stats独立成功 | P02紧凑汇总 | collage_drives_test.dart |
| V02-04 日节奏/看当天 | 行程图→看当天 | `drives_page.dart::_rhythm/filterDay` | Driving日桶及站点日界 | stats有日桶，选日可过滤 | P02节奏读值→记录 | reading_continuity_test.dart |
| V02-05 日期/分页/重试 | 行程期间与列表底部 | `drives_page.dart::chooseDates/load/retryLoad` | 半开from/to、next_cursor | more按当前可见性和游标 | P02期间/分页 | reading_integration_test.dart |
| V03-01 路线/展开地图 | 行程详情地图→完整地图 | `drive_detail_page.dart::_openFullMap`、`map/drive_map_page.dart::DriveMapPage` | series坐标，地图边界CRS转换 | 有坐标可速写，配置/同意决定真图 | P04地图→P15全图 | map_platform_test.dart |
| V03-02 速度/电量/海拔 | 行程过程图 | `drive_detail_page.dart::build`、`sample_chart.dart::SampleChart` | Detail series fields=speed,battery,elevation | series独立加载，null断线 | P04过程图 | drive_detail_test.dart |
| V03-03 距离/时长/净电耗 | 行程结果区 | `drive_detail_page.dart::_results` | Detail.distanceKm/durationMin/consumptionWhKm | detail可用 | P04主指标 | a_drive_detail_test.dart |
| V03-04 能量/平均及最高速度/最大功率 | 驾驶与环境/更多指标 | `drive_detail_page.dart::_techSection` | energyKwh/speedAvgKmh/speedMaxKmh/powerMaxKw | 字段可空，不客户端重算 | P04其他指标 | drive_detail_test.dart |
| V03-05 内外均温 | 驾驶与环境 | 同上 | insideTempCAvg/outsideTempCAvg，非历史曲线 | detail成功 | P04环境指标 | drive_detail_test.dart |
| V03-06 起终SOC/续航口径 | 电量区间/更多指标 | `drive_detail_page.dart::_batterySection/_techSection` | start/end.batteryLevel、rangeKind | 缺值保留— | P04电量/说明 | a_drive_detail_test.dart |
| V03-07 地点/围栏/地址/精确时间/ID | 路线摘要/更多指标/AppBar | `drive_detail_page.dart::build/_techSection` | Detail.id/start/end/startedAt/endedAt | 地点按displayName后备，精确值可查 | P04摘要+数据说明 | drive_detail_test.dart |
| V03-08 行程参照/覆盖/恢复 | 参照脚注/重试 | `drive_detail_page.dart::_consumptionFootnote/_coverageBand/loadReference` | 同身份stats，配对/旧口径分支 | meta能力与质量控制比较 | P04限定与依据 | overview_verification_test.dart |
| V04-01 地点/日期/时长/入电/费用 | 充电记录行 | `charging_page.dart::_recordRow` | Records charging session原值 | 缺费用显示—，0保留 | P03最近记录 | charging_test.dart |
| V04-02 起止SOC区间 | 充电记录SOC条 | `charging_page.dart::_recordRow`、`design/components/soc_interval.dart` | startSoc/endSoc固定0–100 | 缺端点不补0/100 | P03记录行SOC | a_charging_test.dart |
| V04-03 AC/DC/未知/进行中 | 正在充电/记录分类 | `charging_page.dart::_activeRow/loadActive/activeConfirmed` | summary确认charging + session.active | 活跃记录与完成统计隔离 | P03正在充电/记录 | charging_expansion_test.dart |
| V04-04 全部记录/筛选/搜索/排序/分页 | 充电→全部记录 | `charging_page.dart::filterControls/applyFilters/load` | Records全匹配查询，旧版限制提示 | expandedAvailable分支 | P03全部记录→P15 | charging_reading_test.dart |
| V04-05 费用/覆盖/入电/次数/时长/均价 | 充电首页 | `charging_page.dart::_hero/_readings/_legacySummary/trend` | Expanded.totals/buckets；旧Charging回退 | stats及能力分支，字段覆盖独立 | P03紧凑摘要/每日图 | charging_expansion_test.dart |
| V04-06 地点账目/地点记录 | 充电地点行→记录 | `charging_page.dart::_locationRow/loadLocations` | 服务端稳定location键、匹配全集 | 地点能力可用，独立分页/错误 | P03地点账目→P15 | charging_expansion_test.dart |
| V05-01 默认功率/SOC曲线 | 充电详情页内曲线 | `charging_detail.dart::ExpandedChargingCurve/ChargingCurve` | series power/soc，原时间和采样限制 | expandedSeries或旧series | P05曲线（独立完整曲线路由见B02） | charging_detail_test.dart |
| V05-02 起止SOC/结束状态 | 电池弧 | `charging_detail.dart::build` | Detail.startSoc/endSoc/isActive | 可空，active说明非最终 | P05横向SOC摘要 | a_charging_detail_test.dart |
| V05-03 充入/电网能量 | 两类能量 | `charging_detail.dart::_results/build` | energyAddedKwh/energyUsedKwh，分别列出不相加 | detail可用 | P05结果+其他指标 | charging_detail_test.dart |
| V05-04 费用/时长/分类/相数/温度 | 结果/更多信息 | `charging_detail.dart::_results/build` | cost/durationMin/isDc/chargerPhasesMode/outsideTempCAvg | 旧详情同样可展示 | P05结果/说明 | charging_detail_test.dart |
| V05-05 原始峰值/平均功率/覆盖/SOC窗口 | 过程数据说明 | `charging_detail.dart::build` | expandedDetail.processMetrics，原始汇总独立于抽样 | 扩展processMetrics存在，active窗口限定 | P05曲线限定/说明 | charging_expansion_test.dart |
| V05-06 入电/网侧均价 | 这一次的账 | `charging_detail.dart::build` | extra.unitCostAdded/unitCostGrid | expandedDetail存在，null非免费 | P05账目说明 | charging_expansion_test.dart |
| V05-07 额定/理想续航/充电器资料 | 车辆与环境 | `charging_detail.dart::build` | start/endRatedRangeKm、Ideal、charger及sourceSampleAt | fields逐项支持声明 | P05其他指标 | charging_expansion_test.dart |
| V05-08 地点地图/精确时间/地址/ID | 充电地点/更多信息/AppBar | `charging_detail.dart::build`、`map/map_panel.dart::MapPanel` | Detail.location/startedAt/endedAt/id | 坐标可空，授权与Key独立 | P05地图/数据说明 | collage_charging_detail_test.dart |

## V06–V08 统计与0.3专题增量

| ID/能力 | 原页面/入口 | 源码symbol | 数据/口径 | 可见条件 | 目标主要入口 | 现有测试 |
| --- | --- | --- | --- | --- | --- | --- |
| V06-01 里程totals/buckets | 统计首页主图/旧驾驶结果 | `statistics_insights_page.dart::_conclusionTile/_mileageChartTile`、`statistics_page.dart::_driving` | Driving.distanceKm | insights可用走首页，否则legacy | P06主结论/主图 | statistics_insights_test.dart |
| V06-02 行程数/能量/最高速度桶图 | 旧驾驶结果四选项 | `statistics_page.dart::_driving` | Driving.drives/energyKwh/speedMaxKmh | legacy分支；增强入口缺口见B01 | P06完整指标入口（U08核对） | statistics_test.dart |
| V06-03 净/毛电耗同单位图 | 旧驾驶结果 | `statistics_page.dart::_consumption` | consumptionWhKmNet/Gross，各桶原值 | legacy分支；增强入口缺口见B01 | P06完整指标入口（U08核对） | statistics_test.dart |
| V06-04 全部总计与逐桶读数 | 旧驾驶结果区间指标/时间桶 | `statistics_page.dart::_driving/_bucket` | totals/buckets，负值和null保持 | legacy分支；增强入口缺口见B01 | P06完整指标索引 | statistics_test.dart |
| V06-05 配对净电耗/参照/依据 | 统计结论→依据 | `statistics_insights_page.dart::canCompare/_insightRow/_moreSection` | Expanded.netConsumptionPaired/comparisonQuality/reference | 样本/区间/口径可比才差值 | P06结论/依据 | statistics_insights_test.dart |
| V06-06 时长/完成及进行中/有效里程/能量 | 统计数据说明与更多 | `statistics_insights_page.dart::_moreSection` | drivingCoverage/netEnergyKnownDistanceKm | 扩展成功，进行中分开 | P06更多指标 | statistics_insights_test.dart |
| V07-01 入电量/会话数图 | 补能专题/旧充电结果 | `statistics_charging_page.dart::_trend`、`statistics_page.dart::_charging` | Charging energyAddedKwh/sessions totals/buckets | 扩展/legacy分别保留 | P09主图 | statistics_charging_test.dart |
| V07-02 已知费用/均价图 | 补能专题指标切换 | `statistics_charging_page.dart::_trend/_conclusion` | cost、unitCostAdded或旧costPerKwh | 均价/费用null留空，币种独立 | P09费用/均价图 | charging_statistics_test.dart |
| V07-03 覆盖/对应入电/时长/网侧均价 | 补能证据 | `statistics_charging_page.dart::_facts`、`statistics_page.dart::_charging` | Expanded costKnownSessions/Energy、duration、unitCostGrid | 扩展存在，旧版不可伪造 | P09证据 | statistics_charging_test.dart |
| V07-04 查看期间/桶/地点记录 | 补能专题动作 | `statistics_charging_page.dart::openRecords/openBucket/_locationSection` | 服务端区间/地点稳定键 | 当前选择，按结束归期 | P09→P15记录 | charging_reading_test.dart |
| V08-01 AC/DC区间绝对值 | 旧统计分类条/补能专题 | `statistics_page.dart::_charging`、`statistics_charging_page.dart::_composition` | acEnergyKwh/dcEnergyKwh | 分类未知独立 | P09补能结构 | charging_statistics_test.dart |
| V08-02 AC/DC逐桶/已知DC占比 | 旧统计分类趋势 | `statistics_page.dart::_classification` | bucket AC/DC、dcEnergyShare | legacy，增强入口缺口见B01 | P06完整指标→补能结构 | statistics_test.dart |
| V08-03 补能方式环/绝对值/时长 | 充电→我的补能方式 | `charging_page.dart::_composition/_supplyRing/_categoryColumns`、`charging_method.dart::ChargingMethodReading` | Expanded AC/DC/unknown能量与时长；环分母为AC+DC已知分类能量，未知独立列出 | empty/missing/zero/normal状态分开 | P03记录后构成环 | charging_method_test.dart、share_ring_test.dart |
| X03-01 活跃日/每日均值/总里程/驾驶时长 | 节奏 | `statistics_usage_page.dart::_conclusion/_factsSection` | Analysis active_days/distance_per_active_day_km/driving_distance_km/driving_duration_min | driving_analysis | P07结果/证据 | statistics_usage_test.dart |
| X03-02 单程中位/P90/平均速度 | 节奏证据 | `statistics_usage_page.dart::_factsSection` | distance_p50_km/distance_p90_km/mean_speed_kmh | 有效集独立，服务端结果 | P07证据 | statistics_usage_test.dart |
| X03-03 每日/星期/距离分组 | 节奏日历及分组 | `statistics_usage_page.dart::_calendarSection/_weekdaySection/_distanceSection` | Driving日桶、Analysis weekday_bins/distance_bins | 0与未来分别处理，分组附evidence_filter | P07主图/分组 | statistics_usage_test.dart |
| X03-04 日/组证据分页→详情 | 节奏选日/分组、统计依据 | `statistics_usage_page.dart::_openDay/openDrivingEvidence/DrivingEvidencePage` | 服务端过滤、matched_drives/next_cursor | 筛选可用，身份变化退出 | P15行程证据 | statistics_usage_test.dart |
| X03-05 温度组电耗/采样/覆盖/距离组 | 能耗专题 | `statistics_conditions_page.dart::build/coverage/_distanceSection/_TemperaturePlot` | Analysis temperature_bins、coverage、distance_bins | driving_analysis，sample_status限定，相关非因果 | P08点图/证据 | statistics_conditions_test.dart |
| X03-06 长期6/12月/中位/P10–P90/样本 | 长期→续航 | `statistics_range_page.dart::RangeObservationPage/_RangePainter` | Long range observations，独立本地月窗口，缺月不补 | range_observations | P10趋势/读值 | statistics_range_test.dart |
| X03-07 续航证据与限制 | 长期续航下方证据 | `statistics_range_page.dart::build` | 服务端有效/排除/覆盖、月状态与记录 | expanded控制完整证据，非健康检测 | P10证据/说明 | statistics_range_test.dart |
| X03-08 SOC变化/24h率/正负日桶 | 长期→停放 | `statistics_parking_page.dart::build/_ParkingPainter` | Long soc_change_pp/soc_change_pp_per_24h/observed_hours | parking_observations，有效闭合窗口，非预测 | P11主图 | statistics_parking_test.dart |
| X03-09 状态时长/分母/排除原因 | 停放状态分布 | `statistics_parking_page.dart::states/build` | 有效窗口观测小时同一分母，candidate/excluded/open | 局部缺失不补全天 | P11分布/证据 | statistics_parking_test.dart |
| X03-10 停放窗口记录/分页/选择 | 停放证据列表 | `statistics_parking_page.dart::load/build` | Long items、matched_windows/next_cursor | 匹配数有别有效数，分页不改桶 | P11证据 | statistics_parking_test.dart |

## 费用、地图、接入、设置与通用入口增量

| ID/能力 | 原页面/入口 | 源码symbol | 数据/口径 | 可见条件 | 目标主要入口 | 现有测试 |
| --- | --- | --- | --- | --- | --- | --- |
| CE-01 双入口补录 | 充电行/详情结果 | `charging_cost.dart::ChargingCostAction/canFillChargingCost/supportsChargingCost` | meta稳定版本≥0.4.0，已结束、cost=null、有效能量 | 费用0不可覆盖，无开关探测接口 | P03/P05入口→P14共用表单 | charging_cost_test.dart |
| CE-02 强制预检/身份校验 | 补录弹层 | `charging_cost.dart::showChargingCostSheet/_ChargingCostSheetState.read/current` | 强制GET详情，站点/代次/车辆/记录冻结 | 预检通过前不可输入/提交 | P14预检 | charging_cost_test.dart |
| CE-03 单价/币种/计费电量/预估 | 补录输入 | `charging_cost.dart::_Decimal/_priceError/build` | 0–999999、≤6小数，计费取有效能量较大值，half-up，单价不保存 | 未知币种保留原账本说明 | P14表单 | charging_cost_test.dart、number_format_test.dart |
| CE-04 提交/关闭锁定/最终金额 | 确认补录 | `charging_cost.dart::submit` | PATCH仅unit_price，响应严格校验 | 合法输入、当前身份、非saving/uncertain | P14动作/发起页成功反馈 | charging_cost_test.dart |
| CE-05 403/409/待确认/401恢复 | 补录状态动作 | `charging_cost.dart::read/submit/identityChanged` | 403保留输入，409先读，超时5xx先查询，401销毁 | 按状态允许查询/关闭/显式再提交 | P14就近状态 | charging_cost_test.dart |
| CE-06 跨页费用刷新 | 补录成功/查询已有费用后 | `workspace.dart::VehicleWorkspace`费用revision、页面`refreshCost` | 可见页刷新、隐藏页延迟，旧在途拒绝写回 | 成功/已存在费用 | P03/P05与其他费用视图 | charging_cost_refresh_test.dart、overview_statistics_reading_test.dart |
| MAP-01 Key编辑/保存/掩码/更换/取消/清除 | 设置→地图、详情配置地图 | `map/map_privacy_page.dart::_keyForm/_save/_clear/_statusLine` | 设备级MapKeyController，32位ASCII字母数字 | loaded/readFailed/busy/saved/restart状态 | P12本机配置 | map_key_page_test.dart、map_key_test.dart |
| MAP-02 帮助/绑定信息/完整复制/教程 | 地图→如何申请Key | `map/map_privacy_page.dart::_help/_readBinding/_copy` | getBinding包名/签名SHA-1或BundleID，首次展开读取 | 帮助默认折叠，失败可重试 | P12申请帮助 | map_key_page_test.dart |
| MAP-03 隐私同意/撤销/待重启/政策复制 | 地图→地图隐私/详情授权 | `map/map_privacy_page.dart::build`、`map/map_consent_sheet.dart` | MapConsentController与原生进程Key状态 | 同意独立于Key，撤销卸载，重启边界可见 | P12地图隐私 | map_platform_test.dart、map_key_page_test.dart |
| MAP-04 真图/速写/空轨迹/失败/重试 | 行程及充电地图 | `map/map_panel.dart::_initialStatus/build` | MapScene真实坐标，设备Key与同意先决 | configuration/consent/unsupported/empty/loading/ready/failed | P04/P05/P15地图 | map_platform_test.dart、collage_charging_detail_test.dart |
| CFG-01 设置分组/无车辆入口 | 顶栏设置→偏好/站点 | `settings_page.dart::SettingsPage`、`workspace_page.dart::openSettings` | 当前session/config状态 | 有车/无车均可进入 | P12设置 | settings_navigation_test.dart |
| CFG-02 外观跟随系统/浅/深 | 设置→外观弹层 | `appearance_sheet.dart::showAppearanceSheet` | AppearanceController.mode持久化 | 保存真实成功才反映 | P12外观 | appearance_shell_test.dart |
| CFG-03 币种/未知/手动配置 | 设置→币种 | `currency.dart::CurrencyPage/CurrencySettings` | 站点维度币种，未知非默认CNY | 未识别显示未配置说明 | P12币种 | charging_test.dart、settings_navigation_test.dart |
| CFG-04 服务版本/schema/兼容/单位 | 设置→服务信息 | `overview_page.dart::MetaPage` | meta真实字段，完整技术值 | meta失败独立重试 | P12服务信息 | overview_test.dart、settings_navigation_test.dart |
| AUTH-01 首次服务地址/检查/可信HTTP | 首次连接 | `connection_page.dart::_check/_setTrust/build` | health，正常TLS与显式HTTP可信确认 | 恢复/加载/验证状态 | P13连接 | widget_test.dart、setup_test.dart |
| AUTH-02 口令登录/清理/失效 | 登录页 | `session_pages.dart::LoginPage` | SessionController登录、token代次 | 需认证/401，busy禁重 | P13登录 | session_test.dart |
| AUTH-03 站点初始化 | 初始化页 | `setup_page.dart::SetupPage/_initialize` | 既有auth初始化流程 | 服务需setup | P13初始化 | setup_test.dart |
| AUTH-04 连接摘要/更换/取消/重新登录/退出 | 设置→站点连接 | `connection_management.dart::_replace/_edit/_cancelEdit/_logout` | 候选验证成功后原子替换，退出影响说明 | 默认折叠编辑，失败留原连接 | P13连接管理 | connection_management_test.dart |
| VEH-01 初次车辆选择/空/刷新 | 登录后车辆页 | `session_pages.dart::VehiclePage` | session车辆列表 | 未选车/无车 | P16车辆流程 | session_test.dart、full_flow_test.dart |
| VEH-02 车辆弹层/完整名称/选中/刷新 | 顶栏车辆名 | `workspace_page.dart::openVehicleSheet/_VehicleSheet` | VehicleWorkspace.select与session车辆 | 同车不清状态、换车清旧身份 | P16车辆弹层 | reading_continuity_test.dart |
| NAV-01 四Tab独立阅读 | 外壳底栏/返回 | `workspace_page.dart::build/pages/openStatistics`、`reading_scope.dart` | 懒挂载、可见/覆盖、独立期间/点/分页/滚动 | 初访无预取，显式下钻携新期间 | P01/P02/P03/P06外壳 | reading_continuity_test.dart、reading_integration_test.dart |
| NAV-02 日期选择/取消/确认 | 期间旁日期 | `statistics_period.dart::StatisticsPeriodControls`、`drives_page.dart::chooseDates`、`charging_page.dart::filterDates` | 站点日历/DST/半开区间 | 取消保持，确认独立查询 | P01/P02/P03/P06/P16 | overview_statistics_reading_test.dart |
| STATE-01 局部加载/空/缺失/过期/错/重试 | 各页资源区 | `design/components/state_view.dart`及各页load/build | resource快照归属、TTL/ETag/304/429 | 按资源与能力，换身份拒绝旧快照 | P01–P16原资源位置 | business_recovery_test.dart、overview_verification_test.dart |

## 主要路由与能力回退

| 路径/内嵌页 | 当前入口与返回 | 分支/后续所有者 |
| --- | --- | --- |
| 连接→初始化/登录→车辆→工作区 | app会话状态入口，成功进入四Tab | U10，HTTP信任和认证代次保持 |
| 四Tab→设置→地图/外观/币种/站点连接/服务信息 | `openSettings`；外观为底部sheet，其余现有Navigator页 | U10；无车场景仍可设置 |
| 概览→最近行程/充电详情 | `workspace_page.dart::record` | U04/U07；返回原Tab与阅读位置 |
| 概览→驾驶/充电统计或节奏/能耗/长期 | `openStatistics`，entry计数显式覆盖目标selection | U04/U08；普通Tab返回保留原selection |
| 行程→详情→完整地图 | `_routeRow`→`DriveDetailPage`→`DriveMapPage` | U05/U07；速度/SOC/海拔仍独立于地图 |
| 充电→全部记录/地点/分类/选日记录→详情 | recordsOnly、filters、稳定地点键 | U06；旧能力保留可用记录与说明 |
| 充电记录/详情→费用表单 | 同一`showChargingCostSheet` | U11；版本/资格门槛不放宽 |
| 充电详情页内过程曲线 | `ExpandedChargingCurve`或旧`ChargingCurve` | U07，保留样本前后/选择；独立完整曲线路由见B02 |
| 统计→全部指标与口径 | `_AllMetricsPage`四专题索引 | U08；B01应补齐完整指标可达性验证 |
| 统计→节奏/能耗/补能 | `selectTopic(usage/energy/charging)` | U09a/b/c；当前窗口继承 |
| 统计→长期→续航/停放 | `longTopics`内嵌compact预览与展开动作 | U08/U09d/e；目标P15为两条索引行，6/12月独立 |
| 节奏/条件/依据→行程证据→详情 | `openDrivingEvidence`/`DrivingEvidencePage` | U09a/b；matched数与已加载数区分 |
| 长期续航/停放→证据与更多说明 | 页内完整证据、停放分页 | U09d/e；返回不清主图阅读 |
| 无insights能力 | `StatisticsInsightsPage.build`→legacyBuilder→`_LegacyStatisticsPage` | U08；保留驾驶/充电全部旧图表 |
| 无driving_analysis/range/parking能力 | 专题说明或legacy可用内容 | U09；未支持不重复请求 |
| 无充电扩展/expandedDetail | `_legacySummary`、旧stats/detail/series | U06/U07/U09c；不能强依赖新DTO |
| 地图无Key/未同意/失败/无轨迹 | MapPanel状态与速写/配置/隐私入口 | U07/U10；真实底图由#11验收 |

## 共享规则影响清单

| 规则 | 共享源码与调用点 | 影响页面/后续所有者 | 当前基线差异与现有验证 |
| --- | --- | --- | --- |
| R01 布局 | `design/layout.dart::MileafLayout/MileafContent`、`tokens.dart::MileafSpace`；各页padding | P01–P16，U01候选→U02→页面包 | 560、20/24已存在；contentBottom=84、section=28与新预算待迁移。design_components_test.dart |
| R02 字体 | `tokens.dart::MileafType`、`typography.dart`、`metric.dart`、battery_arc/share_ring、各自绘Painter | 全页文字及P04/P05/P07–P11图形，U02/U03/U09 | display60、metricLg44、body13、label10、micro9及tracking待新角色；字体链沿用。design_tokens_test.dart、render_fonts_test.dart |
| R03 大字 | `MileafLayout.largeText`、MetricGrid、data_row、sheet与各专题布局 | 全页，U02及页面包 | 已用完整TextScaler判大字，图轴仍有封顶，布局不能仅靠主题解决。design_components_test.dart、readability_render_test.dart |
| R04 色面 | `semantic.dart`、hero.dart、nav_bar.dart、theme.dart | 概览车况/统计/充电/停放/设置，U02及页面包 | 当前多Hero与光晕、底栏透明模糊待替代；输入边界需最终背景合成验证。design_tokens_test.dart、appearance_shell_test.dart |
| R05 控件 | button/icon_button/chip/chip_row/top_bar/nav_bar/data_row/copy_row/sheet及theme输入 | P01–P16，U02/U10/U11 | 实际44命中与focus即时可见需后续坐标测试，chipHeight34外约束不能证明命中。design_components_test.dart |
| R06 图表 | charts/category_bars/composition_bar/sample_chart；usage/conditions/range/parking Painter | P01–P11，U03/U09及页面调用方 | 主轴/零基线/null/量级纹理按新规复验，旧热图和睡眠条对比缺口已登记。chart_marks_test.dart、share_ring_test.dart |
| R07 动效 | motion.dart、MileafDurations、MileafLayout.motion、图形/折叠/路由调用 | 全页，U03/U10/U11 | press120、enter180、value220、chart500待新时长，几何即时和禁动效待逐帧。a_micro_spark_test.dart |
| R08 状态 | state_view.dart及各页分资源load/build，MapPanel状态呈现 | 全页，U03及各包 | 空态留白、地图覆盖提示待收缩；业务重试/过期身份保留。business_recovery_test.dart |
| R09 披露 | 页面标题、数据说明、比较标签与图读值 | P01–P16，各页面包 | ID/精确时间迁说明，参照显示实际区间；HTTP/授权/费用后果原义冻结。charging_cost_test.dart、map_key_page_test.dart |
| R10 工程 | primitive→semantic→component消费链与共享接口 | U01–U12 | api/session/workspace/reading_scope/生成DTO/原生桥/依赖冻结；workspace_page仅U10车辆弹层。全量回归 |

## S01–S08 回归合同与 A01–A06 证据归宿

| ID | 源码/入口 | 现有测试或证据 | 后续验收 |
| --- | --- | --- | --- |
| S01 | session/workspace、页面owner/revision/sequence | reading_continuity_test.dart「快速切车丢弃迟到响应，切回旧车重新建立默认阅读」 | U12换站点/认证/车/时区 |
| S02 | workspace_page pages、页面selectedAt/scroll/query | overview_statistics_reading_test.dart「概览显式进入统计时入口期间优先于保留状态」 | U04–U12普通返回与显式下钻 |
| S03 | ReadingScope/route遮挡、各页foreground/load | reading_continuity_test.dart「未访问的主入口不预加载，重复点击当前入口不滚顶也不发请求」 | U12可见/覆盖/TTL/ETag/429 |
| S04 | statistics_period/overview_period及服务端query | statistics_insights_test.dart的月末/DST/半小时DST拒绝强行对齐；statistics_range_test.dart | U08/U09/U12日期能力 |
| S05 | DTO可空、totals/buckets/paired/coverage | overview_verification_test.dart、charging_method_test.dart、chart_marks_test.dart | U03–U09图值真实性 |
| S06 | charging_cost资格/预检/submit | charging_cost_test.dart | U11双入口单次PATCH |
| S07 | charging_cost read/recovery、workspace费用revision | charging_cost_refresh_test.dart「专题地点刷新延迟失败时，补录提示部分汇总暂未更新」；overview_statistics_reading_test.dart隐藏费用回归 | U11/U12保输入/查询/身份销毁 |
| S08 | MapKey/Consent/MapPanel、连接验证与替换 | map_key_test.dart、map_platform_test.dart、connection_management_test.dart | U07/U10/U12本地，G09外部 |
| A01 指标覆盖 | 本表逐项V01–V08/X03/CE/MAP/CFG/AUTH/NAV | 源码及具名测试只读盘点，B01明确列出 | U04–U11逐项回填结果，U12闭合 |
| A02 首屏 | P01–P11正式图册before | U00仅抽样目视，尚无新布局测量 | U01预算及各页新截图 |
| A03 图形正确 | stats/series时间/零/null/单位 | chart_marks_test.dart、data_visualization_app_test.dart、statistics_test.dart | U03共享、U09自绘、U12综合 |
| A04 状态/可达性 | 原图册和语义/手势测试 | design_components_test.dart、reading_integration_test.dart | G03/G04自动化及G09设备读屏 |
| A05 视觉评审 | 既有readability图册只作before | U00四张目视记录见U00.md | U01用户评审、U12同条件对照 |
| A06 口径/性能 | 服务端对账边界/PerformanceTrace | collage_trace_test.dart默认opt-in跳过 | #16正式每平台每指标≥30样本；#17真实对账 |

## 当前缺口及未支持能力

### B01 增强统计下完整旧指标的入口缺口

静态调用链表明 `StatisticsInsightsPage._AllMetricsPage` 只列usage/energy/charging/long。增强正常态的 `_moreSection`未挂载 `_LegacyStatisticsPage`，旧版 `_driving/_consumption/_classification`中的行程数/能量/最高速度桶图、净毛同图和AC/DC时间图没有在该索引提供直接入口。旧能力回退源码仍存在；概览“驾驶统计”仅传initialKind=0，在支持insights的站点仍进入overview。

既有 `statistics_insights_test.dart`「全部原指标沿用当前统计选择的周区间」只断言四专题、没有驾驶统计文字及期间查询，未断言这些图形可达。因此583项通过不能证明增强路径具备全部V06/V08。当前登记为既有静态入口缺口，交U08与总控确认最小呈现接口，U09c负责补能侧消费。受控HTTP实际点击复现与最终方案验收待后续对应包，U00产品输入保持稳定。涉及V06-02/03/04、V08-02，不能在迁移收尾时直接标完成。

### B02 充电完整曲线入口的规格措辞

`charging_detail.dart::ExpandedChargingCurve`表示扩展契约的页内Widget。当前文件除打开详情及返回外没有Navigator曲线展开路由，AppBar图表图标tooltip为‘刷新充电曲线’。P05所称‘完整曲线目的地’与当前源码入口存在措辞差异。U07先按实际代码保留两种页内曲线和全部采样读值，独立目的地需求交总控按规格确认。U00没有把类名中的Expanded认定为已存在独立路由。

### G01–G08 历史缺口的当前核对

| 历史ID | 当前已承接 | 仍未支持/范围 | 后续归属 |
| --- | --- | --- | --- |
| G01 总览/详情 | V01–V05及扩展过程汇总 | 胎压、电压/电流过程、能量回收独立指标无当前入口/冻结呈现契约 | 后端能力候选，本轮无新增目标 |
| G02 里程/效率 | 0.3已提供单程中位/P90、温度条件、距离分组与证据 | 速度直方图、目的地排行、里程预测 | U09a/b保留已有；其余候选 |
| G03 充电 | 0.2已提供地点账目、分类时长、费用覆盖、单次过程；AC/DC环已确认 | 跨会话DC曲线比较、空间聚合、CH06后续能力 | U06/U09c保留已有；其余候选 |
| G04 电量/续航/健康 | 当前SOC、单次过程、0.3月额定续航中位/P10–P90 | 连续跨记录SOC/续航历史、容量/健康/衰减诊断 | U09d保留观察，健康无目标 |
| G05 停放/状态 | 0.3闭合停放SOC窗口、有效窗口状态时长 | 完整连续全天状态时间线、基于净毛差推导损耗 | U09e保留观察，非未来预测 |
| G06 温度/更新 | 当前固件、详情均温、温度条件分组 | 车内外温度历史曲线、固件更新历史与间隔 | U07/U09b已有；其余候选 |
| G07 地点/旅程 | 单次轨迹、地点账目/记录、日期证据 | 全历史访问地图/空间排行、跨记录旅程组合、围栏编辑/导航 | 保留既有，后端/范围候选 |
| G08 数据库/税务 | 当前无入口 | 数据库运维、专项税务报表 | 首版范围外 |

本表没有把历史2026-10-25的“未提供”沿用为0.3现状，也没有把候选写成已支持。真实地图/真实字体/键盘/读屏/真实性能/站点与Grafana口径对账均仍待G09和#11/#16/#17证据。
