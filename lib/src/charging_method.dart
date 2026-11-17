import 'charging_experience_contract.g.dart' as expanded;
import 'copy/durations.dart' as copy;
import 'number_format.dart' show decimal;

/// Which shell the charging-method block renders (Spec §11).
enum ChargingMethodState {
  /// No completed session in the range.
  empty,

  /// Sessions exist but none recorded energy.
  missing,

  /// Energy was recorded, but every category is zero.
  zero,

  /// At least one category carries energy.
  normal,
}

/// One absolute reading under the ring: name, energy, duration.
class ChargingMethodCategory {
  const ChargingMethodCategory({
    required this.label,
    required this.value,
    this.unit,
    required this.note,
  });

  final String label;

  /// Already formatted; `—` when the field was never recorded.
  final String value;
  final String? unit;
  final String note;
}

/// Everything the charging-method block needs, computed once and testable
/// without a widget tree.
///
/// The ring answers "how is my charging made up" and therefore shares the exact
/// denominator of `dc_energy_share`: AC + DC known energy. Unknown energy stays
/// out of the ring and is declared in the note, so one screen never shows two
/// different DC percentages (Spec `charging-method-share-ring` §5.1).
class ChargingMethodReading {
  const ChargingMethodReading({
    required this.state,
    required this.acShare,
    required this.dcShare,
    required this.centerValue,
    required this.centerLabel,
    required this.conclusion,
    this.unknownLine = '',
    required this.categories,
    required this.note,
    required this.showLegend,
  });

  factory ChargingMethodReading.from(expanded.ChargingMetrics totals) {
    final sessions = totals.sessions;
    final state = sessions == 0
        ? ChargingMethodState.empty
        : totals.energyKnownSessions == 0
        ? ChargingMethodState.missing
        : (totals.acEnergyKwh + totals.dcEnergyKwh + totals.unknownEnergyKwh) <=
              0
        ? ChargingMethodState.zero
        : ChargingMethodState.normal;
    // 没有一条记录带电量时，分类能量在语义上并不存在；即使字段里残留数字也
    // 不画进环，否则环和三列的 `—` 会互相矛盾。
    final ac = state == ChargingMethodState.missing
        ? 0.0
        : totals.acEnergyKwh.toDouble();
    final dc = state == ChargingMethodState.missing
        ? 0.0
        : totals.dcEnergyKwh.toDouble();
    final unknown = state == ChargingMethodState.missing
        ? 0.0
        : totals.unknownEnergyKwh.toDouble();
    final known = ac + dc;
    final acShare = known > 0 ? ac / known : 0.0;
    final dcShare = known > 0 ? dc / known : 0.0;
    final showUnknown =
        unknown > 0 || totals.classificationKnownSessions < sessions;
    final recorded = state == ChargingMethodState.normal;
    final durationMissing = totals.durationKnownSessions == 0;

    String energy(double value) =>
        state == ChargingMethodState.missing ? '—' : decimal(value);
    // CP03：分类时长走共享分级（90 分钟 → 1 小时 30 分钟），不再写「90.0 分钟」。
    String duration(num minutes) => durationMissing
        ? '—'
        : copy.duration(Duration(minutes: minutes.round()));

    final categories = <ChargingMethodCategory>[];
    if (state != ChargingMethodState.empty) {
      categories.add(
        ChargingMethodCategory(
          label: 'AC',
          value: energy(ac),
          unit: state == ChargingMethodState.missing ? null : 'kWh',
          note: duration(totals.acDurationMin),
        ),
      );
      categories.add(
        ChargingMethodCategory(
          label: 'DC',
          value: energy(dc),
          unit: state == ChargingMethodState.missing ? null : 'kWh',
          note: duration(totals.dcDurationMin),
        ),
      );
      if (showUnknown) {
        categories.add(
          ChargingMethodCategory(
            label: '未知',
            value: energy(unknown),
            unit: state == ChargingMethodState.missing ? null : 'kWh',
            note: duration(totals.unknownDurationMin),
          ),
        );
      }
    }

    final dominantAc = ac >= dc;
    final dominantShare = dominantAc ? acShare : dcShare;
    final conclusion = switch (state) {
      ChargingMethodState.empty => '还没有充电记录',
      ChargingMethodState.missing => '分类能量未记录',
      ChargingMethodState.zero => '还没有分类能量',
      ChargingMethodState.normal => _conclusion(acShare, dcShare),
    };
    // CP09 对照表：结论与「类型未知 X kWh」分行，不用「·」拼接；精确占比由
    // 图例给出，脚注只声明分母口径（CP08：改名不丢口径）。
    final unknownClause = recorded && unknown > 0
        ? '类型未知 ${decimal(unknown)} kWh'
        : '';
    final classified = totals.classificationKnownSessions;
    final note = state == ChargingMethodState.empty
        ? ''
        : classified >= sessions
        ? '只计已知类型的充电，$sessions 次类型都已知'
        : '只计已知类型的充电，$sessions 次中 $classified 次类型已知';
    return ChargingMethodReading(
      state: state,
      acShare: acShare,
      dcShare: dcShare,
      // 圆心是标题数字：取整，精确值留给图例（Spec §5.3）。
      centerValue: known > 0 ? '${(dominantShare * 100).round()}' : null,
      centerLabel: known > 0 ? (dominantAc ? 'AC' : 'DC') : null,
      conclusion: conclusion,
      unknownLine: unknownClause,
      categories: categories,
      note: note,
      // 环上没有弧时（分母为空）不显示图例，否则「AC 0% / DC 0%」会被
      // 读成「真的是 0%」。
      showLegend: state == ChargingMethodState.normal && known > 0,
    );
  }

  final ChargingMethodState state;

  /// Share of known classification energy (AC + DC); 0 when nothing is known.
  final double acShare;
  final double dcShare;

  /// Dominant share without the unit, e.g. `100`; `null` when unknown.
  final String? centerValue;
  final String? centerLabel;
  final String conclusion;

  /// CP09：类型未知的能量单独一行（「类型未知 20.7 kWh」），不拼进结论句；
  /// 没有未知能量时为空。
  final String unknownLine;
  final List<ChargingMethodCategory> categories;

  /// One-line denominator caveat; empty in the empty state.
  final String note;
  final bool showLegend;

  /// Thresholds from Spec §12. Structure only — never a verdict on good/bad.
  /// CP02/CP09：未知类型不再拼进结论句（unknownLine 单独一行）。
  static String _conclusion(double acShare, double dcShare) {
    final known = acShare + dcShare;
    if (known <= 0) return '充电类型未知';
    if (acShare >= .9) {
      return '以 AC 为主';
    } else if (acShare <= .1) {
      return '以 DC 为主';
    } else if (acShare >= .4 && acShare <= .6) {
      return 'AC 与 DC 接近';
    } else if (acShare > .6) {
      return 'AC 更多，DC 占 ${decimal(dcShare * 100)}%';
    }
    return 'DC 更多，AC 占 ${decimal(acShare * 100)}%';
  }
}
