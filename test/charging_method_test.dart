import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/charging_experience_contract.g.dart' as expanded;
import 'package:mileaf/src/charging_method.dart';

expanded.ChargingMetrics metrics({
  int sessions = 2,
  int energyKnown = 2,
  int durationKnown = 2,
  int classificationKnown = 2,
  double ac = 40.18,
  double dc = 0,
  double unknown = 0,
  double acDuration = 1614,
  double dcDuration = 0,
  double unknownDuration = 0,
}) {
  final known = ac + dc;
  return expanded.ChargingMetrics.fromJson({
    'sessions': sessions,
    'energy_added_kwh': known + unknown,
    'cost': null,
    'cost_per_kwh': null,
    'ac_energy_kwh': ac,
    'dc_energy_kwh': dc,
    'dc_energy_share': known > 0 ? dc / known : null,
    'energy_known_sessions': energyKnown,
    'cost_known_sessions': 0,
    'cost_known_energy_kwh': 0,
    'duration_min_total': acDuration + dcDuration + unknownDuration,
    'duration_known_sessions': durationKnown,
    'classification_known_sessions': classificationKnown,
    'unknown_energy_kwh': unknown,
    'ac_duration_min': acDuration,
    'dc_duration_min': dcDuration,
    'unknown_duration_min': unknownDuration,
    'unit_cost_added': {
      'value': null,
      'numerator_cost': 0,
      'denominator_kwh': 0,
      'eligible_sessions': 0,
      'excluded_cost_sessions': 0,
    },
    'unit_cost_grid': {
      'value': null,
      'numerator_cost': 0,
      'denominator_kwh': 0,
      'eligible_sessions': 0,
      'excluded_cost_sessions': 0,
    },
  });
}

void main() {
  group('结论句', () {
    test('全 AC：以 AC 为主，圆心 100% AC', () {
      final reading = ChargingMethodReading.from(metrics());
      expect(reading.conclusion, '以 AC 为主');
      expect(reading.centerValue, '100');
      expect(reading.centerLabel, 'AC');
      expect(reading.state, ChargingMethodState.normal);
    });

    test('70/30：AC 更多，DC 占 30%', () {
      final reading = ChargingMethodReading.from(metrics(ac: 70, dc: 30));
      expect(reading.conclusion, 'AC 更多，DC 占 30%');
      expect(reading.dcShare, closeTo(.3, .0001));
    });

    test('50/50：AC 与 DC 接近', () {
      expect(
        ChargingMethodReading.from(metrics(ac: 50, dc: 50)).conclusion,
        'AC 与 DC 接近',
      );
    });

    test('全 DC：以 DC 为主，圆心 100% DC', () {
      final reading = ChargingMethodReading.from(metrics(ac: 0, dc: 12));
      expect(reading.conclusion, '以 DC 为主');
      expect(reading.centerLabel, 'DC');
      expect(reading.centerValue, '100');
    });

    test('阈值边界：90% 仍算为主，89.9% 降为更多', () {
      expect(
        ChargingMethodReading.from(metrics(ac: 90, dc: 10)).conclusion,
        '以 AC 为主',
      );
      expect(
        ChargingMethodReading.from(metrics(ac: 89.9, dc: 10.1)).conclusion,
        'AC 更多，DC 占 10.1%',
      );
    });

    test('未知能量只进从句，不改分母', () {
      final reading = ChargingMethodReading.from(
        metrics(ac: 30, dc: 10, unknown: 20),
      );
      expect(reading.conclusion, 'AC 更多，DC 占 25% · 类型未知 20 kWh');
      expect(reading.dcShare, closeTo(.25, .0001));
    });

    test('只有未知能量：补能类型未知，圆心留空', () {
      final reading = ChargingMethodReading.from(
        metrics(ac: 0, dc: 0, unknown: 9),
      );
      expect(reading.conclusion, '补能类型未知');
      expect(reading.centerValue, isNull);
      expect(reading.centerLabel, isNull);
    });

    test('百分比去尾零', () {
      final reading = ChargingMethodReading.from(metrics(ac: 10, dc: 1));
      expect(reading.note, contains('DC 占已知分类能量 9.09%'));
    });
  });

  group('三列与短注', () {
    test('未知为 0 且分类完整时不出现第三列', () {
      final reading = ChargingMethodReading.from(metrics());
      expect(reading.categories.map((c) => c.label), ['AC', 'DC']);
      expect(reading.note, 'DC 占已知分类能量 0% · 分类已知 2/2 次');
    });

    test('未知能量大于 0 时出现第三列并声明不计入构成', () {
      final reading = ChargingMethodReading.from(metrics(unknown: 5));
      expect(reading.categories.map((c) => c.label), ['AC', 'DC', '未知']);
      expect(reading.note, contains('未知不计入构成'));
      expect(reading.categories.last.value, '5');
    });

    test('分类不完整时即使未知能量为 0 也出现第三列', () {
      final reading = ChargingMethodReading.from(
        metrics(classificationKnown: 1),
      );
      expect(reading.categories.map((c) => c.label), ['AC', 'DC', '未知']);
      expect(reading.note, contains('分类已知 1/2 次'));
    });

    test('时长缺失显示 —，不补 0', () {
      final reading = ChargingMethodReading.from(metrics(durationKnown: 0));
      expect(reading.categories.first.note, '—');
    });

    test('时长按分类累计并分组千位', () {
      final reading = ChargingMethodReading.from(metrics());
      expect(reading.categories.first.note, '1,614 分钟');
      expect(reading.categories[1].note, '0 分钟');
    });
  });

  group('状态', () {
    test('无记录：空态，无三列、无短注', () {
      final reading = ChargingMethodReading.from(
        metrics(sessions: 0, energyKnown: 0),
      );
      expect(reading.state, ChargingMethodState.empty);
      expect(reading.conclusion, '还没有充电记录');
      expect(reading.categories, isEmpty);
      expect(reading.note, isEmpty);
      expect(reading.showLegend, isFalse);
    });

    test('有记录但无能量：缺失态，三列全 —', () {
      // 能量未知时后端不可能同时给出分类能量，夹具按实际返回零。
      final reading = ChargingMethodReading.from(
        metrics(energyKnown: 0, ac: 0, dc: 0),
      );
      expect(reading.state, ChargingMethodState.missing);
      expect(reading.conclusion, '分类能量未记录');
      expect(reading.categories.map((c) => c.value), everyElement('—'));
      expect(reading.categories.first.unit, isNull);
      expect(reading.note, contains('DC 占已知分类能量 —'));
    });

    test('能量未知时字段残留也不画进环', () {
      final reading = ChargingMethodReading.from(
        metrics(energyKnown: 0, ac: 118, dc: 96),
      );
      expect(reading.state, ChargingMethodState.missing);
      expect(reading.acShare, 0);
      expect(reading.centerValue, isNull);
      expect(reading.categories.map((c) => c.value), everyElement('—'));
    });

    test('能量全为 0：零能量态，三列为 0', () {
      final reading = ChargingMethodReading.from(
        metrics(ac: 0, dc: 0, unknown: 0),
      );
      expect(reading.state, ChargingMethodState.zero);
      expect(reading.conclusion, '还没有分类能量');
      expect(reading.categories.map((c) => c.value), everyElement('0'));
    });
  });
}
