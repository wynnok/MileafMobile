import 'charging_experience_contract.g.dart' as expanded;
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
        : (totals.acEnergyKwh + totals.dcEnergyKwh + totals.unknownEnergyKwh) <= 0
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
    String duration(num minutes) =>
        durationMissing ? '—' : '${decimal(minutes)} 分钟';

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
      ChargingMethodState.normal => _conclusion(acShare, dcShare, unknown),
    };
    final shareText = known > 0 ? '${decimal(dcShare * 100)}%' : '—';
    final unknownClause = recorded && unknown > 0 ? '未知不计入构成 · ' : '';
    return ChargingMethodReading(
      state: state,
      acShare: acShare,
      dcShare: dcShare,
      // 圆心是标题数字：取整，精确值留给图例（Spec §5.3）。
      centerValue: known > 0 ? '${(dominantShare * 100).round()}' : null,
      centerLabel: known > 0 ? (dominantAc ? 'AC' : 'DC') : null,
      conclusion: conclusion,
      categories: categories,
      note: state == ChargingMethodState.empty
          ? ''
          : 'DC 占已知分类能量 $shareText · $unknownClause'
                '分类已知 ${totals.classificationKnownSessions}/$sessions 次',
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
  final List<ChargingMethodCategory> categories;

  /// One-line denominator caveat; empty in the empty state.
  final String note;
  final bool showLegend;

  /// Thresholds from Spec §12. Structure only — never a verdict on good/bad.
  static String _conclusion(double acShare, double dcShare, double unknown) {
    final known = acShare + dcShare;
    if (known <= 0) return '补能类型未知';
    final String sentence;
    if (acShare >= .9) {
      sentence = '以 AC 为主';
    } else if (acShare <= .1) {
      sentence = '以 DC 为主';
    } else if (acShare >= .4 && acShare <= .6) {
      sentence = 'AC 与 DC 接近';
    } else if (acShare > .6) {
      sentence = 'AC 更多，DC 占 ${decimal(dcShare * 100)}%';
    } else {
      sentence = 'DC 更多，AC 占 ${decimal(acShare * 100)}%';
    }
    if (unknown <= 0) return sentence;
    return '$sentence · 类型未知 ${decimal(unknown)} kWh';
  }
}
