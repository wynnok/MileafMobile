/// CP10 枚举人话标签：主界面显示人话标签，原值进「技术详情」。
///
/// 原值依据 *_contract.g.dart 与 MileafServer/docs/api/v1-surface.md 核实：
/// - 停车窗口 quality：complete / partial_state_coverage / open_window / excluded
/// - exclusion_reason 8 项公开值（含 odometer_change，阈值键 odometer_change_bound）
/// - sample_status：adequate / insufficient_data / unsupported（validation=provisional 为临时结果）
/// - range_kind：rated / ideal
/// 未知值兜底「其他原因」，原值进技术详情。
library;

String parkingQualityLabel(String quality) => switch (quality) {
  'complete' => '完整',
  'partial_state_coverage' => '状态记录不完整（仍计入）',
  // open 为 open_window 的兼容别名（CP10 表写法）。
  'open_window' || 'open' => '尚未结束',
  'excluded' => '未计入',
  _ => '其他原因',
};

String exclusionReasonLabel(String reason) => switch (reason) {
  'same_moment_gap' => '相同时刻间隔',
  'invalid_time_order' => '时间顺序异常',
  'event_overlap' => '与其他记录时间重叠',
  'ambiguous_states' => '车辆状态无法确定',
  'missing_soc' => '缺少电量数据',
  'missing_odometer' => '缺少里程表数据',
  // 原值 odometer_change（v1-surface.md:663）；odometer_change_bound 为
  // thresholds 键，作为别名接受。
  'odometer_change' || 'odometer_change_bound' => '停车期间里程变化过大',
  'insufficient_duration' => '停车时间太短',
  'negative_odometer_change' => '里程表读数回退',
  _ => '其他原因',
};

String sampleStatusLabel(String status) => switch (status) {
  'adequate' => '样本充足',
  'insufficient_data' => '样本较少',
  'unsupported' => '功能不支持',
  'provisional' => '临时结果',
  _ => '其他原因',
};

String rangeKindLabel(String? kind) => switch (kind) {
  null => '—',
  'rated' => '额定',
  'ideal' => '理想',
  _ => '其他原因',
};
