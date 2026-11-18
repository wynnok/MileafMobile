import 'package:flutter_test/flutter_test.dart';
import 'package:timezone/data/latest_all.dart' as database;
import 'package:timezone/timezone.dart' as tz;
import 'package:mileaf/src/copy/dates.dart';
import 'package:mileaf/src/copy/durations.dart';
import 'package:mileaf/src/copy/labels.dart';
import 'package:mileaf/src/copy/messages.dart';
import 'package:mileaf/src/copy/terms.dart';
import 'package:mileaf/src/copy/units.dart';
import 'package:mileaf/src/number_format.dart';

/// CP04 DF1–DF9、CP03 时长与单位、CP02 术语与比较名称、CP10 枚举标签、
/// CP07 状态句的单元测试。参照「今天」固定为 2026-10-26 16:05（周一）。

final today = DateTime.utc(2026, 10, 26, 16, 5);

void main() {
  group('CP04 日期（DF1–DF9，纯墙钟格式化，不含时区逻辑）', () {
    test('DF1 单日：今年不带年，非今年带年', () {
      expect(formatDay(DateTime.utc(2026, 10, 26), today), '10月26日');
      expect(formatDay(DateTime.utc(2026, 10, 1), today), '10月1日');
      expect(formatDay(DateTime.utc(2025, 12, 28), today), '2025年12月28日');
    });

    test('DF2 记录分组标题：今天 / 昨天 / M月D日 周X', () {
      expect(formatDayGroup(today, today), '今天');
      expect(
        formatDayGroup(today.subtract(const Duration(days: 1)), today),
        '昨天',
      );
      expect(formatDayGroup(DateTime.utc(2026, 10, 24), today), '10月24日 周六');
      expect(formatDayGroup(DateTime.utc(2026, 10, 20), today), '10月20日 周二');
    });

    test('DF3 日期区间：连接号 –，同月省日首，跨月跨年规则', () {
      expect(
        formatRange(DateTime.utc(2026, 10, 1), DateTime.utc(2026, 10, 26)),
        '10月1日–26日',
      );
      expect(
        formatRange(DateTime.utc(2026, 9, 27), DateTime.utc(2026, 10, 26)),
        '9月27日–10月26日',
      );
      expect(
        formatRange(DateTime.utc(2025, 12, 28), DateTime.utc(2026, 1, 3)),
        '2025年12月28日–2026年1月3日',
      );
    });

    test('DF4 时间：HH:mm、同日段、跨日写全', () {
      expect(formatTime(DateTime.utc(2026, 10, 26, 16, 5)), '16:05');
      expect(formatTime(DateTime.utc(2026, 10, 26, 9, 7)), '09:07');
      expect(
        formatTimeRange(
          DateTime.utc(2026, 10, 26, 16, 5),
          DateTime.utc(2026, 10, 26, 16, 51),
          today: today,
        ),
        '16:05–16:51',
      );
      expect(
        formatTimeRange(
          DateTime.utc(2026, 10, 26, 23, 40),
          DateTime.utc(2026, 10, 27, 0, 15),
          today: today,
        ),
        '10月26日 23:40–10月27日 00:15',
      );
    });

    test('DF5 日期加时间', () {
      expect(
        formatDayTime(DateTime.utc(2026, 10, 26, 16, 5), today),
        '10月26日 16:05',
      );
    });

    test('DF6 月份与月区间', () {
      expect(formatMonth(DateTime.utc(2026, 10), today), '10月');
      expect(formatMonth(DateTime.utc(2025, 10), today), '2025年10月');
      expect(
        formatMonthRange(DateTime.utc(2026, 5), DateTime.utc(2026, 10), today),
        '5月–10月',
      );
      expect(
        formatMonthRange(DateTime.utc(2025, 12), DateTime.utc(2026, 2), today),
        '2025年12月–2026年2月',
      );
    });

    test('DF7 相对时间：刚刚 / N 分钟前 / 今天 / 昨天 / 其余 DF5', () {
      expect(
        formatRelative(today.subtract(const Duration(seconds: 30)), today),
        '刚刚',
      );
      expect(
        formatRelative(today.subtract(const Duration(minutes: 2)), today),
        '2 分钟前',
      );
      expect(
        formatRelative(today.subtract(const Duration(minutes: 59)), today),
        '59 分钟前',
      );
      expect(
        formatRelative(DateTime.utc(2026, 10, 26, 10, 2), today),
        '今天 10:02',
      );
      expect(
        formatRelative(DateTime.utc(2026, 10, 25, 10, 2), today),
        '昨天 10:02',
      );
      expect(
        formatRelative(DateTime.utc(2026, 10, 23, 8, 0), today),
        '10月23日 08:00',
      );
    });

    test('DF8 精确时间（技术详情用）', () {
      expect(
        formatPrecise(DateTime.utc(2026, 10, 26, 16, 5, 0)),
        '2026-10-26 16:05:00',
      );
    });

    test('DF9 图轴：日级首刻度与跨月、周级桶首日、月级、时间级', () {
      expect(
        formatAxisDayTicks([
          DateTime.utc(2026, 10, 1),
          DateTime.utc(2026, 10, 14),
          DateTime.utc(2026, 10, 26),
        ], today),
        ['10月1日', '14日', '26日'],
      );
      expect(
        formatAxisDayTicks([
          DateTime.utc(2026, 9, 27),
          DateTime.utc(2026, 10, 10),
        ], today),
        ['9月27日', '10月10日'],
      );
      expect(formatAxisWeekBucket(DateTime.utc(2026, 10, 5), today), '10月5日');
      expect(formatAxisMonth(DateTime.utc(2026, 10), today), '10月');
      expect(formatAxisMonth(DateTime.utc(2025, 10), today), '2025年10月');
      expect(formatAxisTime(DateTime.utc(2026, 10, 26, 6, 10)), '06:10');
    });

    test('CP04 读屏读法：区间用「至」', () {
      expect(
        formatRangeReading(
          DateTime.utc(2026, 10, 1),
          DateTime.utc(2026, 10, 26),
        ),
        '10月1日至26日',
      );
      expect(
        formatRangeReading(
          DateTime.utc(2026, 9, 27),
          DateTime.utc(2026, 10, 26),
        ),
        '9月27日至10月26日',
      );
      expect(
        formatRangeReading(
          DateTime.utc(2025, 12, 28),
          DateTime.utc(2026, 1, 3),
        ),
        '2025年12月28日至2026年1月3日',
      );
    });

    test('2025/2026 跨年与 DST 日界（墙钟输入约定）', () {
      database.initializeTimeZones();
      // 输入约定与页面一致：墙钟 DateTime（朴素 UTC 或 tz.TZDateTime），
      // 格式化只读墙钟字段，不依赖机器时区。
      final ny = tz.getLocation('America/New_York');
      final sh = tz.getLocation('Asia/Shanghai');
      // 春进缺口日 2026-03-08：01:30 为有效 EST，04:30 为有效 EDT。
      expect(formatTime(tz.TZDateTime(ny, 2026, 3, 8, 1, 30)), '01:30');
      expect(formatTime(tz.TZDateTime(ny, 2026, 3, 8, 4, 30)), '04:30');
      expect(formatDay(tz.TZDateTime(ny, 2026, 3, 8, 4, 30), today), '3月8日');
      // 缺口内 02:30 不存在：时区库归一到有效墙钟，格式化跟随该读数。
      final gap = tz.TZDateTime(ny, 2026, 3, 8, 2, 30);
      expect(
        formatTime(gap),
        "${gap.hour.toString().padLeft(2, '0')}:${gap.minute.toString().padLeft(2, '0')}",
      );
      // 秋退重叠日 2026-11-01 02:30 出现两次，格式化跟随位置读数。
      final ambiguous = tz.TZDateTime(ny, 2026, 11, 1, 2, 30);
      expect(
        formatTime(ambiguous),
        "${ambiguous.hour.toString().padLeft(2, '0')}:${ambiguous.minute.toString().padLeft(2, '0')}",
      );
      // DST 不适用时区。
      expect(formatTime(tz.TZDateTime(sh, 2026, 3, 8, 10, 30)), '10:30');
      // 跨年：去年 12 月带年，今年 1 月不带年。
      expect(formatDay(DateTime.utc(2025, 12, 31), today), '2025年12月31日');
      expect(formatDay(DateTime.utc(2026, 1, 5), today), '1月5日');
    });
  });

  group('CP03 时长与单位', () {
    test('时长分级：分钟 / 小时 / 天，整点省略', () {
      expect(duration(const Duration(minutes: 46)), '46 分钟');
      expect(duration(const Duration(minutes: 72)), '1 小时 12 分钟');
      expect(duration(const Duration(hours: 2)), '2 小时');
      expect(duration(const Duration(hours: 51)), '2 天 3 小时');
      expect(duration(const Duration(hours: 24, minutes: 10)), '1 天 10 分钟');
      expect(
        duration(const Duration(hours: 51, minutes: 15)),
        '2 天 3 小时 15 分钟',
      );
      expect(duration(Duration.zero), '0 分钟');
    });

    test('负时长用真负号 −（U+2212）', () {
      expect(duration(const Duration(minutes: -46)), '−46 分钟');
      expect(applyMinusSign('-1,234.5'), '−1,234.5');
      expect(applyMinusSign('12'), '12');
      expect(minusSign, '−');
    });

    test('数值与单位：一般单位一个空格，% 与 °C 紧贴', () {
      expect(valueUnit(60.0, 'km', decimals: 1), '60.0 km');
      expect(valueUnit(1198.6, 'km', decimals: 1), '1,198.6 km');
      expect(valueUnit(154, 'Wh/km'), '154 Wh/km');
      expect(valueUnit(68, '%'), '68%');
      expect(valueUnit(-5, '°C'), '−5°C');
      expect(valueUnit(52, '趟'), '52 趟');
    });

    test('semanticsUnit 中文朗读单位', () {
      expect(semanticsUnit('km'), '公里');
      expect(semanticsUnit('kWh'), '千瓦时');
      expect(semanticsUnit('Wh/km'), '瓦时每公里');
      expect(semanticsUnit('kW'), '千瓦');
      expect(semanticsUnit('%'), '百分之');
      expect(semanticsUnit('趟'), '趟');
      expect(semanticsUnit('次'), '次');
      expect(semanticsUnit('分钟'), '分钟');
    });
  });

  group('CP02 术语常量与比较对象名称', () {
    test('比较对象名称与真实窗口一致', () {
      expect(compareNameFor('month'), '上月同期');
      expect(compareNameFor('recent'), '前 7 天');
      expect(compareNameFor('week'), '上周同期');
      expect(compareNameFor('year'), '去年同期');
      expect(compareNameFor('custom'), isNull);
      expect(compareNameFor('unknown'), isNull);
    });

    test('主界面术语常量', () {
      expect(trip, '行程');
      expect(tripCount, '趟');
      expect(charging, '充电');
      expect(chargeCount, '次');
      expect(chargedEnergy, '充入电量');
      expect(gridEnergy, '电网用电');
      expect(energyPerKm, '电耗');
      expect(energyPerKmEstimated, '电耗（估算）');
      expect(estimatedConsumption, '估算耗电');
      expect(validTrip, '有效行程');
      expect(recordedCost, '已记录费用');
      expect(averagePrice, '充入均价');
      expect(vehicleDays, '用车天数');
      expect(dataPoint, '数据点');
      expect(detail, '明细');
      expect(parkingSocChange, '停车电量变化');
      expect(percentagePoint, '个百分点');
      expect(parkingRecord, '停车记录');
      expect(ratedRange, '满电额定续航（估算）');
      expect(place, '地点');
      expect(unsupportedPrefix, '当前站点暂不支持');
    });
  });

  group('CP10 枚举人话标签（依据 *_contract.g.dart 与 MileafServer 只读文档核实）', () {
    test('停车记录状态 quality', () {
      expect(parkingQualityLabel('complete'), '完整');
      expect(parkingQualityLabel('partial_state_coverage'), '状态记录不完整（仍计入）');
      expect(parkingQualityLabel('open_window'), '尚未结束');
      expect(parkingQualityLabel('open'), '尚未结束');
      expect(parkingQualityLabel('excluded'), '未计入');
      expect(parkingQualityLabel('nonsense'), '其他原因');
    });

    test('未计入原因 exclusion_reason（8 项公开值）', () {
      expect(exclusionReasonLabel('missing_soc'), '缺少电量数据');
      expect(exclusionReasonLabel('missing_odometer'), '缺少里程表数据');
      expect(exclusionReasonLabel('insufficient_duration'), '停车时间太短');
      expect(exclusionReasonLabel('invalid_time_order'), '时间顺序异常');
      expect(exclusionReasonLabel('negative_odometer_change'), '里程表读数回退');
      expect(exclusionReasonLabel('odometer_change'), '停车期间里程变化过大');
      expect(exclusionReasonLabel('odometer_change_bound'), '停车期间里程变化过大');
      expect(exclusionReasonLabel('ambiguous_states'), '车辆状态无法确定');
      expect(exclusionReasonLabel('event_overlap'), '与其他记录时间重叠');
      expect(exclusionReasonLabel('same_moment_gap'), '相同时刻间隔');
      expect(exclusionReasonLabel('nonsense'), '其他原因');
    });

    test('样本状态 sample_status', () {
      expect(sampleStatusLabel('adequate'), '样本充足');
      expect(sampleStatusLabel('insufficient_data'), '样本较少');
      expect(sampleStatusLabel('unsupported'), '功能不支持');
      expect(sampleStatusLabel('provisional'), '临时结果');
      expect(sampleStatusLabel('nonsense'), '其他原因');
    });

    test('续航口径 range_kind', () {
      expect(rangeKindLabel('rated'), '额定');
      expect(rangeKindLabel('ideal'), '理想');
      expect(rangeKindLabel(null), '—');
      expect(rangeKindLabel('nonsense'), '其他原因');
    });
  });

  group('CP07 状态与错误构造函数', () {
    test('空与首次空', () {
      expect(emptyMessage('行程'), '这段时间没有行程');
      expect(firstEmptyMessage('充电记录'), '还没有充电记录');
    });

    test('加载', () {
      expect(loadingMessage('行程'), '正在读取行程');
    });

    test('刷新失败有旧数据（DF7 时间）', () {
      expect(
        staleMessage(DateTime.utc(2026, 10, 26, 10, 2), today),
        '没能更新，显示的是 10:02 的数据',
      );
    });

    test('读取失败与分页失败', () {
      expect(readFailedMessage('充电统计'), '没能读取充电统计');
      expect(paginationFailedMessage('行程'), '没能加载更多行程，已保留当前列表');
    });

    test('能力不支持 / 版本不兼容 / 时区不可读', () {
      expect(unsupportedMessage('停放观察'), '当前站点暂不支持停放观察');
      expect(
        versionIncompatibleMessage(),
        '服务器返回的数据格式不受支持，请确认 Mileaf Server 版本',
      );
      expect(timezoneUnreadableMessage(), '无法读取手机时区，暂按 UTC 显示和统计');
    });
  });
}
