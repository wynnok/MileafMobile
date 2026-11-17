import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../copy/dates.dart';
import '../icons.dart';
import '../layout.dart';
import '../motion.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';
import 'button.dart';
import 'sheet.dart';

/// 由调用方注入的区间校验：返回错误文案即拒绝应用，返回 null 表示通过。
///
/// 各页自己的业务规则（不晚于今天、开始不晚于结束、最长 730 天、原归期口径）
/// 都留在页面，组件不内置任何业务校验（R27、PD10）。
typedef MileafDateRangeValidator = String? Function(
  DateTime start,
  DateTime end,
);

/// R27 共享日期区间弹层：两行「开始」「结束」，点按行在下方展开平台日期选择器
/// （iOS Cupertino 日期模式，Android CalendarDatePicker），并提供「改为输入」
/// 切换到日期文本输入以保留键盘路径；底部主按钮「应用」；脚注「包含结束当天」。
///
/// 默认区间、可选范围、校验与回调由调用方注入；返回 null 表示放弃。
Future<DateTimeRange?> showMileafDateRangeSheet({
  required BuildContext context,
  required DateTimeRange initialRange,
  required DateTime firstDate,
  required DateTime lastDate,
  DateTime? today,
  MileafDateRangeValidator? validator,
  String title = '选择日期',
  String confirmLabel = '应用',
  String footnote = '包含结束当天',
}) => showMileafSheet<DateTimeRange>(
  context: context,
  title: title,
  style: MileafSheetStyle.edge,
  builder: (_) => MileafDateRangeSheet(
    initialRange: initialRange,
    firstDate: firstDate,
    lastDate: lastDate,
    today: today,
    validator: validator,
    confirmLabel: confirmLabel,
    footnote: footnote,
  ),
);

enum _Field { start, end }

class MileafDateRangeSheet extends StatefulWidget {
  const MileafDateRangeSheet({
    super.key,
    required this.initialRange,
    required this.firstDate,
    required this.lastDate,
    this.today,
    this.validator,
    this.confirmLabel = '应用',
    this.footnote = '包含结束当天',
  });

  final DateTimeRange initialRange;
  final DateTime firstDate;
  final DateTime lastDate;

  /// DF1 的年份参照（跨年时两端都带年）；缺省用 [lastDate]。
  final DateTime? today;
  final MileafDateRangeValidator? validator;
  final String confirmLabel;
  final String footnote;

  /// 日期文本校验的本地错误（格式问题不是业务规则）。
  static const invalidDateText = '请输入有效日期';

  @override
  State<MileafDateRangeSheet> createState() => _MileafDateRangeSheetState();
}

class _MileafDateRangeSheetState extends State<MileafDateRangeSheet> {
  late DateTime _start = _dateOnly(widget.initialRange.start);
  late DateTime _end = _dateOnly(widget.initialRange.end);
  late final TextEditingController _startText = TextEditingController(
    text: _iso(_start),
  );
  late final TextEditingController _endText = TextEditingController(
    text: _iso(_end),
  );
  _Field? _editing;
  bool _manual = false;
  String? _error;

  static DateTime _dateOnly(DateTime value) =>
      DateTime(value.year, value.month, value.day);

  static String _iso(DateTime value) {
    final year = value.year;
    final month = value.month.toString().padLeft(2, '0');
    final day = value.day.toString().padLeft(2, '0');
    return '$year-$month-$day';
  }

  static DateTime? _parse(String text) {
    final match = RegExp(r'^(\d{4})-(\d{1,2})-(\d{1,2})$')
        .firstMatch(text.trim());
    if (match == null) return null;
    final year = int.parse(match.group(1)!);
    final month = int.parse(match.group(2)!);
    final day = int.parse(match.group(3)!);
    if (month < 1 || month > 12 || day < 1 || day > 31) return null;
    final value = DateTime(year, month, day);
    // 拒绝 2026-02-31 这类被 DateTime 静默进位的日期。
    if (value.year != year || value.month != month || value.day != day) {
      return null;
    }
    return value;
  }

  @override
  void dispose() {
    _startText.dispose();
    _endText.dispose();
    super.dispose();
  }

  void _setDate(_Field field, DateTime value) {
    setState(() {
      final date = _dateOnly(value);
      if (field == _Field.start) {
        _start = date;
        _startText.text = _iso(date);
      } else {
        _end = date;
        _endText.text = _iso(date);
      }
      _error = null;
    });
  }

  void _apply() {
    var start = _start;
    var end = _end;
    if (_manual) {
      final from = _parse(_startText.text);
      final to = _parse(_endText.text);
      if (from == null || to == null) {
        setState(() => _error = MileafDateRangeSheet.invalidDateText);
        return;
      }
      start = from;
      end = to;
    }
    final message = widget.validator?.call(start, end);
    if (message != null) {
      setState(() => _error = message);
      return;
    }
    Navigator.pop(context, DateTimeRange(start: start, end: end));
  }

  String _display(DateTime value) {
    return formatDay(value, widget.today ?? widget.lastDate);
  }

  Widget _row(String label, DateTime value, _Field field) {
    final colors = context.colors;
    final type = context.type;
    final expanded = !_manual && _editing == field;
    return Semantics(
      button: true,
      expanded: expanded,
      label: label,
      value: _display(value),
      excludeSemantics: true,
      child: InkWell(
        onTap: _manual
            ? null
            : () => setState(() {
                _editing = expanded ? null : field;
                _error = null;
              }),
        highlightColor: colors.pressOverlay,
        splashColor: Colors.transparent,
        child: Container(
          constraints: const BoxConstraints(minHeight: 52),
          padding: const EdgeInsets.symmetric(vertical: MileafSpace.s8),
          child: Row(
            children: [
              Text(label, style: type.subheadline),
              const Spacer(),
              Flexible(
                child: Text(
                  _display(value),
                  style: type.body.copyWith(color: colors.text),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.end,
                ),
              ),
              const SizedBox(width: MileafSpace.s8),
              AnimatedRotation(
                turns: expanded ? .5 : 0,
                duration: MileafLayout.motion(context, MileafDurations.chevron),
                curve: MileafCurves.fold,
                child: MileafIcon(
                  MileafIconName.chevronDown,
                  size: MileafIconMetrics.nav,
                  color: _manual ? colors.textFaint : colors.textSecondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _picker(_Field field) {
    final value = field == _Field.start ? _start : _end;
    void update(DateTime date) => _setDate(field, date);
    final platform = Theme.of(context).platform;
    final minimum = _dateOnly(widget.firstDate);
    final maximum = _dateOnly(widget.lastDate);
    if (platform == TargetPlatform.iOS || platform == TargetPlatform.macOS) {
      final initial = value.isBefore(minimum)
          ? minimum
          : value.isAfter(maximum)
          ? maximum
          : value;
      return SizedBox(
        height: 216,
        child: CupertinoDatePicker(
          mode: CupertinoDatePickerMode.date,
          initialDateTime: initial,
          minimumDate: minimum,
          maximumDate: maximum,
          onDateTimeChanged: update,
        ),
      );
    }
    return SizedBox(
      height: MileafLayout.largeText(context) ? 420 : 340,
      child: CalendarDatePicker(
        initialDate: value,
        firstDate: minimum,
        lastDate: maximum,
        onDateChanged: update,
      ),
    );
  }

  Widget _textFields() => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      TextField(
        key: const ValueKey('date-range-start-input'),
        controller: _startText,
        keyboardType: TextInputType.datetime,
        decoration: const InputDecoration(labelText: '开始'),
        onChanged: (_) => setState(() => _error = null),
      ),
      const SizedBox(height: MileafSpace.s12),
      TextField(
        key: const ValueKey('date-range-end-input'),
        controller: _endText,
        keyboardType: TextInputType.datetime,
        decoration: const InputDecoration(labelText: '结束'),
        onChanged: (_) => setState(() => _error = null),
      ),
    ],
  );

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final error = _error;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (_manual)
          _textFields()
        else ...[
          _row('开始', _start, _Field.start),
          if (_editing == _Field.start) _picker(_Field.start),
          // R24：两行之间一物理像素分隔线。
          const Divider(
            height: MileafStroke.hairline,
            thickness: MileafStroke.hairline,
          ),
          _row('结束', _end, _Field.end),
          if (_editing == _Field.end) _picker(_Field.end),
        ],
        if (error != null) ...[
          const SizedBox(height: MileafSpace.s12),
          Text(error, style: type.footnote.copyWith(color: colors.error)),
        ],
        const SizedBox(height: MileafSpace.s16),
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: MileafButton(
            label: _manual ? '改为选择' : '改为输入',
            kind: MileafButtonKind.ghost,
            onPressed: () => setState(() {
              _manual = !_manual;
              _editing = null;
              _error = null;
            }),
          ),
        ),
        const SizedBox(height: MileafSpace.s16),
        MileafButton(
          label: widget.confirmLabel,
          expand: true,
          onPressed: _apply,
        ),
        const SizedBox(height: MileafSpace.s8),
        Text(widget.footnote, style: type.footnote),
      ],
    );
  }
}
