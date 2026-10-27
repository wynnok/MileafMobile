import 'dart:math' as math;

import 'package:flutter/material.dart';

class DataCard extends StatelessWidget {
  const DataCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color,
  });
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? color;
  @override
  Widget build(BuildContext context) => Card(
    color: color,
    margin: const EdgeInsets.only(bottom: 12),
    child: Padding(padding: padding, child: child),
  );
}

class MetricTile extends StatelessWidget {
  const MetricTile({
    super.key,
    required this.label,
    required this.value,
    this.note,
    this.emphasize = false,
  });
  final String label, value;
  final String? note;
  final bool emphasize;
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final parts = RegExp(r'^(-?[0-9][0-9.,]*)(.*)$').firstMatch(value);
    return Semantics(
      container: true,
      label: '$label $value${note == null ? '' : '，$note'}',
      excludeSemantics: true,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 7),
          Text.rich(
            TextSpan(
              text: parts?.group(1) ?? value,
              children: [
                if (parts != null)
                  TextSpan(
                    text: parts.group(2),
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: theme.colorScheme.onSurfaceVariant,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
              ],
            ),
            style:
                (emphasize
                        ? Theme.of(context).textTheme.headlineMedium
                        : Theme.of(context).textTheme.titleLarge)
                    ?.copyWith(fontWeight: FontWeight.w600),
          ),
          if (note != null) ...[
            const SizedBox(height: 5),
            Text(note!, style: Theme.of(context).textTheme.bodySmall),
          ],
        ],
      ),
    );
  }
}

class BatteryLevelIndicator extends StatelessWidget {
  const BatteryLevelIndicator({super.key, required this.level, this.size = 96});
  final num? level;
  final double size;
  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    label: '电池电量 ${level == null ? '未知' : '$level %'}',
    excludeSemantics: true,
    child: SizedBox.square(
      dimension: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox.expand(
            child: CircularProgressIndicator(
              value: level == null ? 0 : (level! / 100).clamp(0, 1),
              strokeWidth: 6,
              strokeCap: StrokeCap.round,
              backgroundColor: Theme.of(context).colorScheme.surface,
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(10),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    level == null ? '—' : '${level!.toStringAsFixed(0)} %',
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '电池电量',
                    style: Theme.of(context).textTheme.labelSmall,
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    ),
  );
}

class SocInterval extends StatelessWidget {
  const SocInterval({super.key, required this.start, required this.end});
  final num? start, end;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Semantics(
        container: true,
        label:
            '电量区间 ${start == null ? '起始未知' : '$start %'} 至 ${end == null ? '结束未知' : '$end %'}，尺度0至100%',
        child: LayoutBuilder(
          builder: (context, constraints) => Container(
            height: 7,
            margin: const EdgeInsets.symmetric(vertical: 9),
            decoration: BoxDecoration(
              color: Theme.of(context).colorScheme.outlineVariant,
              borderRadius: BorderRadius.circular(8),
            ),
            child: start == null || end == null
                ? null
                : Stack(
                    children: [
                      Positioned(
                        left:
                            constraints.maxWidth *
                            (math.min(start!, end!) / 100).clamp(0, 1),
                        width:
                            constraints.maxWidth *
                            ((end! - start!).abs() / 100).clamp(0, 1),
                        top: 0,
                        bottom: 0,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.primary,
                            borderRadius: BorderRadius.circular(8),
                          ),
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
      Wrap(
        alignment: WrapAlignment.spaceBetween,
        spacing: 18,
        runSpacing: 4,
        children: [
          Text(
            '起始 ${start == null ? '—' : '${start!.toStringAsFixed(0)} %'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          Text(
            '结束 ${end == null ? '—' : '${end!.toStringAsFixed(0)} %'}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    ],
  );
}

class EnergyComparison extends StatelessWidget {
  const EnergyComparison({
    super.key,
    required this.values,
    this.unit = 'kWh',
    this.decimals = 2,
    this.note,
  });
  final List<(String, num?)> values;
  final String unit;
  final int decimals;
  final String? note;
  @override
  Widget build(BuildContext context) {
    final maximum = values.fold<num>(
      0,
      (m, entry) => math.max(m, entry.$2 ?? 0),
    );
    final minimum = values.fold<num>(
      0,
      (m, entry) => math.min(m, entry.$2 ?? 0),
    );
    final range = maximum - minimum;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (var i = 0; i < values.length; i++)
          Semantics(
            container: true,
            excludeSemantics: true,
            label:
                '${values[i].$1} ${values[i].$2 == null ? '—（缺失）' : '${values[i].$2!.toStringAsFixed(decimals)} $unit'}',
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 8),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Wrap(
                    alignment: WrapAlignment.spaceBetween,
                    spacing: 12,
                    runSpacing: 4,
                    children: [
                      Text(values[i].$1),
                      Text(
                        values[i].$2 == null
                            ? '—（缺失）'
                            : '${values[i].$2!.toStringAsFixed(decimals)} $unit',
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                  const SizedBox(height: 7),
                  SizedBox(
                    height: 7,
                    child: LayoutBuilder(
                      builder: (context, constraints) {
                        final value = values[i].$2;
                        final zero = range == 0
                            ? 0.0
                            : constraints.maxWidth * -minimum / range;
                        return DecoratedBox(
                          decoration: BoxDecoration(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Stack(
                            children: [
                              if (value != null && range > 0)
                                Positioned(
                                  left:
                                      constraints.maxWidth *
                                      (math.min(0, value) - minimum) /
                                      range,
                                  width:
                                      constraints.maxWidth *
                                      value.abs() /
                                      range,
                                  top: 0,
                                  bottom: 0,
                                  child: DecoratedBox(
                                    decoration: BoxDecoration(
                                      color: i.isEven
                                          ? Theme.of(context)
                                                .colorScheme
                                                .primary
                                          : Theme.of(context)
                                                .colorScheme
                                                .tertiary,
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                  ),
                                ),
                              Positioned(
                                left: zero.clamp(
                                  0,
                                  math.max(0, constraints.maxWidth - 1),
                                ),
                                width: 1,
                                top: 0,
                                bottom: 0,
                                child: ColoredBox(
                                  color: Theme.of(context)
                                      .colorScheme
                                      .onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        if (note != null)
          Text(note!, style: Theme.of(context).textTheme.bodySmall),
      ],
    );
  }
}
