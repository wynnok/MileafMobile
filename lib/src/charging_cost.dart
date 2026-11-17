import 'dart:convert';

import 'package:flutter/material.dart';

import 'api.dart';
import 'charging_detail_contract.g.dart' as dto;
import 'charging_cost_contract.g.dart' as cost_dto;
import 'copy/dates.dart' as copy;
import 'currency.dart';
import 'design/components/components.dart';
import 'design/layout.dart';
import 'design/motion.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'number_format.dart' show groupedText;
import 'workspace.dart';

bool supportsChargingCost(Object? version) {
  if (version is! String) return false;
  final match = RegExp(r'^(\d+)\.(\d+)\.(\d+)$').firstMatch(version);
  return match != null &&
      (int.parse(match[1]!) > 0 || int.parse(match[2]!) >= 4);
}

bool canFillChargingCost({
  required num? cost,
  required bool active,
  required DateTime? endedAt,
  required num? added,
  required num? used,
}) =>
    cost == null &&
    !active &&
    endedAt != null &&
    _billingEnergy(added, used) != null;

/// A compact, contextual action rather than a full-width list-row button.
class ChargingCostAction extends StatelessWidget {
  const ChargingCostAction({
    super.key,
    required this.onPressed,
    required this.identityLabel,
  });
  final VoidCallback onPressed;
  final String identityLabel;
  @override
  Widget build(BuildContext context) => Semantics(
    label: identityLabel,
    child: IntrinsicWidth(
      child: MileafButton(
        label: '补录费用',
        kind: MileafButtonKind.ghost,
        onPressed: onPressed,
      ),
    ),
  );
}

_Decimal? _billingEnergy(num? added, num? used) {
  final values = [added, used].whereType<num>().toList();
  if (values.isEmpty || values.any((v) => !v.isFinite)) return null;
  final value = values.reduce((a, b) => a > b ? a : b);
  if (value <= 0 || value >= 1000000) return null;
  return _Decimal.parse(value.toString());
}

/// Bounded base-ten arithmetic; amounts never travel through double products.
class _Decimal {
  _Decimal(this.units, this.scale);
  final BigInt units;
  final int scale;
  static BigInt power(int n) => BigInt.from(10).pow(n);
  static _Decimal? parse(String value) {
    if (value.length > 40 || !RegExp(r'^\d+(\.\d+)?$').hasMatch(value)) {
      return null;
    }
    final parts = value.split('.');
    return _Decimal(
      BigInt.parse(parts.join()),
      parts.length == 1 ? 0 : parts[1].length,
    );
  }

  int compare(_Decimal other) =>
      (units * power(other.scale)).compareTo(other.units * power(scale));
  String get canonical {
    final digits = units.toString().padLeft(scale + 1, '0');
    if (scale == 0) return digits;
    return '${digits.substring(0, digits.length - scale)}.${digits.substring(digits.length - scale)}'
        .replaceFirst(RegExp(r'\.?0+$'), '');
  }

  String money([_Decimal? multiplier]) {
    final product = units * (multiplier?.units ?? BigInt.one);
    final places = scale + (multiplier?.scale ?? 0);
    final BigInt cents;
    if (places <= 2) {
      cents = product * power(2 - places);
    } else {
      final divisor = power(places - 2);
      cents = (product + divisor ~/ BigInt.two) ~/ divisor;
    }
    final digits = cents.toString().padLeft(3, '0');
    return groupedText(
      '${digits.substring(0, digits.length - 2)}.${digits.substring(digits.length - 2)}',
    );
  }
}

String? _priceError(String input) {
  final text = input.trim();
  if (text.isEmpty) return '请输入本次充电单价';
  if (RegExp(r'^\d+\.$').hasMatch(text)) return '请补全小数部分';
  if (!RegExp(r'^(\d+|\d*\.\d+)$').hasMatch(text)) {
    return '请输入有效单价，使用小数点，不含币种或千位分隔符';
  }
  if (text.split('.').last.length > 6 && text.contains('.')) {
    return '单价最多支持 6 位小数';
  }
  final price = _Decimal.parse(text.startsWith('.') ? '0$text' : text);
  if (price == null || price.compare(_Decimal(BigInt.from(999999), 0)) > 0) {
    return '单价须在 0–999999 之间';
  }
  return null;
}

String _amount(String value, CurrencySettings currency) =>
    switch (currency.code) {
      'CNY' => '¥$value',
      final String code => '$value $code',
      null => value,
    };

/// Keep each thousands group intact when a large amount wraps at 200%.
/// P14：预估费用用 metricSm（R21.3 详情页读数口径）。
Widget _amountText(BuildContext context, String value) => Semantics(
  label: value,
  child: ExcludeSemantics(
    child: Wrap(
      children: [
        for (final match in RegExp(r'[^, ]+,?| ').allMatches(value))
          Text(match.group(0)!, style: context.type.metricSm),
      ],
    ),
  ),
);

Future<void> showChargingCostSheet(
  BuildContext context,
  VehicleWorkspace workspace,
  CurrencySettings currency,
  int id,
) async {
  final result = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: false,
    enableDrag: false,
    constraints: const BoxConstraints(maxWidth: MileafBreakpoints.sheetMax),
    sheetAnimationStyle: AnimationStyle(
      duration: MileafLayout.motion(context, MileafDurations.sheetIn),
      reverseDuration: MileafLayout.motion(context, MileafDurations.sheetOut),
      curve: MileafCurves.sheet,
      reverseCurve: MileafCurves.sheet,
    ),
    builder: (_) =>
        _ChargingCostSheet(workspace: workspace, currency: currency, id: id),
  );
  if (result != null && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
  }
}

class _ChargingCostSheet extends StatefulWidget {
  const _ChargingCostSheet({
    required this.workspace,
    required this.currency,
    required this.id,
  });
  final VehicleWorkspace workspace;
  final CurrencySettings currency;
  final int id;
  @override
  State<_ChargingCostSheet> createState() => _ChargingCostSheetState();
}

class _ChargingCostSheetState extends State<_ChargingCostSheet> {
  late final workspace = widget.workspace;
  late final owner = workspace.session.current!;
  late final vehicle = workspace.selectedId!;
  final input = TextEditingController();
  final focus = FocusNode();
  bool showValidation = false;
  dto.ChargingSessionDetail? detail;
  bool loading = true, saving = false, blocked = false;
  bool uncertain = false, terminal = false, leaving = false;
  bool existingNotified = false;
  double dragDistance = 0;
  String? error, fieldError;
  bool get eligible =>
      detail != null &&
      canFillChargingCost(
        cost: detail!.cost,
        active: detail!.isActive,
        endedAt: detail!.endedAt,
        added: detail!.energyAddedKwh,
        used: detail!.energyUsedKwh,
      );
  bool get current =>
      mounted &&
      workspace.session.isCurrent(owner) &&
      workspace.selectedId == vehicle;
  _Decimal? get price => _priceError(input.text) == null
      ? _Decimal.parse(
          input.text.trim().startsWith('.')
              ? '0${input.text.trim()}'
              : input.text.trim(),
        )
      : null;
  @override
  void initState() {
    super.initState();
    workspace.addListener(identityChanged);
    focus.addListener(() {
      if (!focus.hasFocus && mounted) setState(() => showValidation = true);
    });
    read();
  }

  @override
  void dispose() {
    input.dispose();
    focus.dispose();
    workspace.removeListener(identityChanged);
    super.dispose();
  }

  void identityChanged() {
    if (current || leaving) return;
    leaving = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final route = ModalRoute.of(context);
      if (route?.isActive == true) Navigator.of(context).removeRoute(route!);
    });
  }

  Future<void> read({bool recovery = false, bool conflict = false}) async {
    if (!current || saving) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final result = await workspace.cache.get(
        owner,
        'charging-sessions/${widget.id}',
        force: true,
      );
      final value = dto.ChargingSessionDetail.fromJson(result.body);
      if (!current) return;
      if (value.id != widget.id || value.vehicleId != vehicle) {
        throw const FormatException();
      }
      setState(() {
        detail = value;
        loading = false;
        blocked = false;
        terminal = !eligible;
        if (value.cost != null) {
          error =
              '该记录已有费用 ${_amount(_Decimal.parse(value.cost.toString())!.money(), widget.currency)}';
          uncertain = false;
        } else if (!eligible) {
          error = '该记录当前无法补录费用，请刷新后查看';
          uncertain = false;
        } else if (conflict) {
          error = '记录状态已变化，暂无法确认是否可补录';
          uncertain = true;
        } else {
          uncertain = false;
          error = recovery ? '最新读取仍无费用；查询可能有延迟，重新提交将由服务端校验。' : null;
        }
      });
      if (value.cost != null && !existingNotified) {
        existingNotified = true;
        await workspace.refreshChargingCosts(owner, vehicle);
      }
    } catch (failure) {
      if (current) {
        setState(() {
          loading = false;
          if (failure is BusinessFailure && failure.status == 404) {
            terminal = true;
            uncertain = false;
            error = '该充电记录已不可用';
            return;
          }
          error = recovery ? '仍无法确认补录结果，请稍后查询' : '暂时无法读取本次充电，请重试';
        });
        if (failure is BusinessFailure && failure.status == 404) {
          await workspace.refreshChargingCosts(owner, vehicle);
        }
      }
    }
  }

  Future<void> submit() async {
    if (!current ||
        saving ||
        loading ||
        blocked ||
        uncertain ||
        terminal ||
        price == null ||
        !eligible) {
      return;
    }
    final submitted = price!;
    setState(() {
      saving = true;
      error = null;
    });
    try {
      final response = await workspace.session.request(
        owner,
        'charging-sessions/${widget.id}/cost',
        method: 'PATCH',
        body: jsonEncode({'unit_price': submitted.canonical}),
        headers: {'content-type': 'application/json'},
      );
      if (!current) return;
      if (response.statusCode == 403) {
        setState(() {
          saving = false;
          blocked = true;
          error = '站点尚未开启费用补录，请联系管理员';
        });
        return;
      }
      if (response.statusCode == 400 || response.statusCode == 422) {
        setState(() {
          saving = false;
          fieldError = '单价未被服务接受，请检查范围和小数位后重试';
        });
        return;
      }
      if (response.statusCode == 404) {
        setState(() {
          saving = false;
          terminal = true;
          error = '该充电记录已不可用';
        });
        await workspace.refreshChargingCosts(owner, vehicle);
        return;
      }
      if (response.statusCode == 409) {
        setState(() {
          saving = false;
          uncertain = true;
        });
        await read(recovery: true, conflict: true);
        return;
      }
      if (response.statusCode != 200) {
        throw const ApiFailure('补录结果尚未确认，请先查询最新结果');
      }
      final result = cost_dto.ChargingCostResult.fromJson(
        cost_dto.object(jsonDecode(response.body)),
      );
      final cost = _Decimal.parse(result.cost);
      final unitPrice = _Decimal.parse(result.unitPrice);
      final billed = _Decimal.parse(result.billingEnergyKwh);
      if (result.sessionId != widget.id ||
          cost == null ||
          unitPrice == null ||
          unitPrice.compare(submitted) != 0 ||
          billed == null ||
          billed.units == BigInt.zero ||
          billed.compare(_Decimal(BigInt.from(1000000), 0)) >= 0) {
        throw const FormatException();
      }
      final refreshed = await workspace.refreshChargingCosts(owner, vehicle);
      if (!mounted || !current) return;
      Navigator.pop(
        context,
        '费用已补录 · ${_amount(cost.money(), widget.currency)}${refreshed ? '' : '；部分汇总暂未更新，请刷新'}',
      );
    } catch (_) {
      if (current) {
        setState(() {
          saving = false;
          uncertain = true;
          error = '补录结果尚未确认，请先查询最新结果';
        });
      }
    }
  }

  /// CP04：日期时间用共享格式化器输出（DF5 = DF1 + DF4）。
  String _recordWhen(dto.ChargingSessionDetail d) {
    final start = workspace.calendar!.local(d.startedAt);
    // 身份行要绝对日期：用早三天的参照日让 formatDay 走「M月D日」分支，
    // 不写成「今天/昨天」，且在同年内不带年。
    final day = copy.formatDay(start, start.subtract(const Duration(days: 3)));
    return '$day ${copy.formatTime(start)}';
  }

  @override
  Widget build(BuildContext context) {
    if (!current) return const SizedBox.shrink();
    final type = context.type;
    final colors = context.colors;
    final d = detail;
    final energy = d == null
        ? null
        : _billingEnergy(d.energyAddedKwh, d.energyUsedKwh);
    final p = price;
    final unit = '${widget.currency.code ?? '账本币种'}/kWh';
    final gap8 = const SizedBox(height: MileafSpace.s8);
    return PopScope(
      canPop: !saving,
      child: GestureDetector(
        onVerticalDragStart: (_) => dragDistance = 0,
        onVerticalDragUpdate: (event) => dragDistance += event.delta.dy,
        onVerticalDragEnd: (_) {
          if (!saving && dragDistance > MileafSpace.s40) Navigator.pop(context);
        },
        child: Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.viewInsetsOf(context).bottom,
          ),
          child: MileafSheetFrame(
            title: '补录费用',
            // P14/R28：费用表单属高内容弹层，用贴边样式（顶部 28、不透明）。
            style: MileafSheetStyle.edge,
            onClose: () {
              if (!saving) Navigator.pop(context);
            },
            closeEnabled: !saving,
            closeLabel: '关闭费用补录',
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                gap8,
                if (loading) Text('正在读取本次充电…', style: type.body),
                if (d != null) ...[
                  // P14 记录块：地点 headline、日期时间 subheadline（CP04 共享
                  // 格式化器）、记录编号进记录信息（CP09 不再用「充电 #N」）。
                  Text(d.location.displayName ?? '未知地点', style: type.headline),
                  const SizedBox(height: MileafSpace.s4),
                  Text(
                    _recordWhen(d),
                    style: type.subheadline.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: MileafSpace.s4),
                  Text(
                    '记录编号 ${d.id}',
                    style: type.subheadline.copyWith(
                      color: colors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: MileafSpace.s24),
                  Text('单价（$unit）', style: type.label),
                  gap8,
                  Semantics(
                    label: '单价（$unit）',
                    child: TextField(
                      controller: input,
                      focusNode: focus,
                      enabled: !saving && !loading && !terminal,
                      style: type.body,
                      keyboardType: const TextInputType.numberWithOptions(
                        decimal: true,
                      ),
                      autocorrect: false,
                      enableSuggestions: false,
                      textInputAction: TextInputAction.done,
                      onEditingComplete: () => focus.unfocus(),
                      onChanged: (_) => setState(() {
                        fieldError = null;
                      }),
                      decoration: InputDecoration(
                        hintText: '请输入单价',
                        constraints: const BoxConstraints(
                          minHeight: MileafSpace.inputMinHeight,
                        ),
                        errorText:
                            fieldError ??
                            (showValidation ? _priceError(input.text) : null),
                        errorStyle: type.micro.copyWith(color: colors.error),
                        errorMaxLines: 4,
                      ),
                    ),
                  ),
                  gap8,
                  Text(
                    widget.currency.code == null
                        ? '请按 TeslaMate 原账本币种填写；当前未配置币种标签。'
                        : '币种标签来自本机设置，请与 TeslaMate 原账本保持一致。',
                    style: type.micro.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: MileafSpace.section),
                  Text(
                    '计费电量 ${energy?.canonical ?? '—'} kWh',
                    style: type.body,
                  ),
                  const SizedBox(height: MileafSpace.s4),
                  Text(
                    '按两类电量的较大可用值计费，最终费用以服务端为准。',
                    style: type.micro.copyWith(color: colors.textMuted),
                  ),
                  const SizedBox(height: MileafSpace.s12),
                  Text(
                    '预估费用',
                    style: type.label.copyWith(color: colors.textMuted),
                  ),
                  gap8,
                  _amountText(
                    context,
                    p == null || energy == null
                        ? '—'
                        : _amount(energy.money(p), widget.currency),
                  ),
                  if (widget.currency.code == null) ...[
                    gap8,
                    Text(
                      '币种未记录',
                      style: type.body.copyWith(color: colors.textMuted),
                    ),
                  ],
                  if (p != null &&
                      energy != null &&
                      energy.money(p) == '0.00') ...[
                    gap8,
                    Text(
                      p.units == BigInt.zero ? '将记录为免费充电' : '费用按两位小数四舍五入',
                      style: type.body,
                    ),
                  ],
                  const SizedBox(height: MileafSpace.s24),
                  Text('仅补录本次充电。保存后无法在 App 中修改；单价不会设为默认值。', style: type.body),
                  const SizedBox(height: MileafSpace.s12),
                ],
                if (error != null)
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      error!,
                      style: type.body.copyWith(
                        color: uncertain || terminal
                            ? colors.textMuted
                            : colors.error,
                      ),
                    ),
                  ),
                if (saving)
                  Semantics(
                    liveRegion: true,
                    child: Text('正在补录费用…', style: type.body),
                  ),
                const SizedBox(height: MileafSpace.s12),
                if (terminal)
                  MileafButton(
                    label: '关闭',
                    expand: true,
                    onPressed: () => Navigator.pop(context),
                  )
                else if (uncertain)
                  MileafButton(
                    label: '查询最新结果',
                    expand: true,
                    loading:
                        loading && !MediaQuery.disableAnimationsOf(context),
                    onPressed: loading ? null : () => read(recovery: true),
                  )
                else if (blocked || d == null && !loading)
                  MileafButton(
                    label: blocked ? '重新检查' : '重试读取',
                    expand: true,
                    onPressed: read,
                  )
                else if (d != null)
                  MileafButton(
                    label: '确认补录',
                    expand: true,
                    loading: saving && !MediaQuery.disableAnimationsOf(context),
                    onPressed:
                        !saving &&
                            !loading &&
                            fieldError == null &&
                            p != null &&
                            eligible
                        ? submit
                        : null,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
