/// CP02 术语表：一个概念在主界面只用一个词。
/// 页面包按本表替换字符串；旧词退出主界面（「关于这些数据」中解释时可出现一次）。
library;

const String trip = '行程';
const String tripCount = '趟';
const String charging = '充电';
const String chargeCount = '次';
const String chargedEnergy = '充入电量';
const String gridEnergy = '电网用电';
const String energyPerKm = '电耗';
const String energyPerKmEstimated = '电耗（估算）';
const String estimatedConsumption = '估算耗电';
const String validTrip = '有效行程';
const String recordedCost = '已记录费用';
const String averagePrice = '充入均价';
const String vehicleDays = '用车天数';
const String dataPoint = '数据点';
const String detail = '明细';
const String parkingSocChange = '停车电量变化';
const String percentagePoint = '个百分点';
const String parkingRecord = '停车记录';
const String ratedRange = '满电额定续航（估算）';
const String place = '地点';
const String unsupportedPrefix = '当前站点暂不支持';

/// CP02 比较对象名称：名称必须与源码中实际的比较窗口一致。
/// period 键与 StatisticsPeriod（statistics_period.dart）一致；自定义区间直接用日期（DF3）。
String? compareNameFor(String period) => switch (period) {
  'month' => '上月同期',
  'recent' => '前 7 天',
  'week' => '上周同期',
  'year' => '去年同期',
  _ => null,
};
