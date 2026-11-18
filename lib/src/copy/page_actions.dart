/// 页面状态动作的读屏对象名（D-AP08-03）。
///
/// 可见按钮文字仍由各页面传入（多为「重试」）；这里的完整对象名让读屏
/// 听到动作的对象，例如「重试读取概览」。按页归组，命名与所属数据一致。
library;

/// 概览页。
const retryOverview = '重试读取概览';
const retryVehicleStatus = '重试读取车况';
const retryComparison = '重试读取比较';
const retryCapabilities = '重试读取能力';
const retryDrivingData = '重试读取驾驶数据';
const retryChargingData = '重试读取充电数据';

/// 服务信息（MetaPage）。
const retryServiceInfo = '重试读取服务信息';

/// 充电页。
const retryChargingStats = '重试读取充电统计';
const retryChargingActive = '重试读取充电中状态';
const retryChargingLocations = '重试读取充电地点';
const retryChargingRecords = '重试读取充电记录';
