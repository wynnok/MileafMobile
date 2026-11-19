import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout.dart';
import '../semantic.dart';
import '../tokens.dart';
import '../typography.dart';

/// Same length and same values within a tenth of a point.
bool _sameFractions(List<double> a, List<double> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if ((a[i] - b[i]).abs() > .0001) return false;
  }
  return true;
}

/// One arc of a [MileafShareRing]: a label, its weight and its colour.
///
/// The caller owns the colour (from `context.colors`), so the ring never
/// hard-codes a palette entry and stays honest to Spec §2.4: one accent plus a
/// 50 % step, never a second accent.
@immutable
class ShareRingSegment {
  const ShareRingSegment({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final num value;
  final Color color;
}

/// 100 % donut for a two-part composition (AC / DC known energy).
///
/// The ring is the primary visual of the charging-method block
/// (`docs/specs/charging-method-share-ring.md` §5): 12 px stroke, 3 px gaps,
/// butt caps and a centre that disappears rather than shrinking any number.
/// The first frame draws the full real geometry (R07: 图表首次 0，无绘制生长);
/// a data update keeps the values instant and eases the arc fractions over
/// 160 ms (R07 局部快照更新), collapsing to zero under disableAnimations.
class MileafShareRing extends StatefulWidget {
  const MileafShareRing({
    super.key,
    required this.segments,
    this.centerValue,
    this.centerUnit = '%',
    this.centerLabel,
    this.size,
    this.hue,
  });

  /// Drawn in order from 12 o'clock, clockwise. Values ≤ 0 are dropped.
  final List<ShareRingSegment> segments;

  /// Dominant share without the unit, e.g. `100`; `null` renders `—`.
  final String? centerValue;
  final String? centerUnit;

  /// Dominant category name, e.g. `AC`; `null` keeps the centre number-only.
  final String? centerLabel;
  final double? size;

  /// CL01/CL02：分段色相。传了就按段序取**同色相两档**——第一段
  /// `hue.solid`、第二段 `hue.strong`（CL02 明写的多段用法），第三段
  ///（「未知」）仍用调用方给的 [ShareRingSegment.color]，即中性色。
  ///
  /// 缺省时完全沿用 [ShareRingSegment.color]，与改造前像素等价。
  final MileafHue? hue;

  @override
  State<MileafShareRing> createState() => _MileafShareRingState();
}

class _MileafShareRingState extends State<MileafShareRing>
    with TickerProviderStateMixin {
  late final AnimationController _change = AnimationController(
    vsync: this,
    duration: MileafDurations.value,
  );

  late List<double> _from = _fractions(widget.segments);
  late List<double> _to = _fractions(widget.segments);

  static List<double> _fractions(List<ShareRingSegment> segments) {
    final values = [
      for (final segment in segments)
        segment.value > 0 ? segment.value.toDouble() : 0.0,
    ];
    final total = values.fold<double>(0, (sum, value) => sum + value);
    if (total <= 0) return List<double>.filled(values.length, 0);
    return [for (final value in values) value / total];
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MileafLayout.reduceMotion(context)) {
      _change.value = 1;
    }
  }

  @override
  void didUpdateWidget(covariant MileafShareRing oldWidget) {
    super.didUpdateWidget(oldWidget);
    final next = _fractions(widget.segments);
    if (_sameFractions(next, _to)) return;
    _from = _currentFractions();
    _to = next;
    if (MileafLayout.reduceMotion(context)) {
      _change.value = 1;
    } else {
      _change.forward(from: 0);
    }
  }

  List<double> _currentFractions() {
    if (_change.value >= 1) return _to;
    final t = Curves.easeOut.transform(_change.value);
    List<double> align(List<double> values) => values.length == _to.length
        ? values
        : List<double>.generate(
            _to.length,
            (i) => i < values.length ? values[i] : 0,
          );
    final from = align(_from);
    return [
      for (var i = 0; i < _to.length; i++) from[i] + (_to[i] - from[i]) * t,
    ];
  }

  @override
  void dispose() {
    _change.dispose();
    super.dispose();
  }

  double _resolveSize(BuildContext context) {
    if (widget.size != null) return widget.size!;
    if (MileafLayout.largeText(context)) {
      return MileafShareRingMetrics.diameterLargeText;
    }
    final width = MediaQuery.sizeOf(context).width;
    if (width < MileafBreakpoints.base) {
      return MileafShareRingMetrics.diameterNarrow;
    }
    if (width >= MileafBreakpoints.wide) {
      return MileafShareRingMetrics.diameterWide;
    }
    return MileafShareRingMetrics.diameter;
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final size = _resolveSize(context);
    final available =
        size -
        MileafShareRingMetrics.stroke * 2 -
        MileafShareRingMetrics.centerPad;
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: size,
        child: AnimatedBuilder(
          animation: _change,
          builder: (context, _) => CustomPaint(
            painter: _ShareRingPainter(
              fractions: _currentFractions(),
              colors: [
                for (final (index, segment) in widget.segments.indexed)
                  _segmentColor(colors, index, segment),
              ],
              track: colors.line,
              stroke: MileafShareRingMetrics.stroke,
            ),
            child: Center(child: _center(context, available)),
          ),
        ),
      ),
    );
  }

  /// 环的取色出口：一个色相两档，剩下的一段（未知）交回调用方。
  ///
  /// 未知 / 未记录**永不**用语义色相（CL08），所以第三段保持调用方给的中性
  /// 色，环不替调用方决定「未知该长什么样」。
  Color _segmentColor(
    MileafColors colors,
    int index,
    ShareRingSegment segment,
  ) {
    final hue = widget.hue;
    if (hue == null) return segment.color;
    return switch (index) {
      0 => hue.solid(colors),
      1 => hue.strong(colors),
      _ => segment.color,
    };
  }

  Widget _center(BuildContext context, double available) {
    final colors = context.colors;
    final type = context.type;
    final value = widget.centerValue ?? '—';
    final unit = widget.centerValue == null ? null : widget.centerUnit;
    final valueStyle = type.metricMd.copyWith(color: colors.text);
    final unitStyle = type.footnote.copyWith(color: colors.textFaint);
    final (valueWidth, valueHeight) = _measure(context, value, valueStyle);
    final (unitWidth, unitHeight) = unit == null
        ? (0.0, 0.0)
        : _measure(context, ' $unit', unitStyle);
    final (labelWidth, labelHeight) = widget.centerLabel == null
        ? (0.0, 0.0)
        : _measure(context, widget.centerLabel!, unitStyle);
    // Never shrink a number: when even the bare value does not fit, the centre
    // is dropped and the legend carries the share (Spec §5.3). The unit and
    // label move under the value only while the whole column still fits the
    // ring; otherwise they are omitted — the centre must never overflow.
    if (valueWidth > available || valueHeight > available) {
      return const SizedBox.shrink();
    }
    final inlineUnit =
        unit != null &&
        valueWidth + unitWidth <= available &&
        unitHeight <= available;
    var height = valueHeight;
    var unitBelow = false;
    if (!inlineUnit && unit != null && height + 2 + unitHeight <= available) {
      unitBelow = true;
      height += 2 + unitHeight;
    }
    final showLabel =
        widget.centerLabel != null &&
        labelWidth <= available &&
        height + 2 + labelHeight <= available;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text.rich(
          TextSpan(
            text: value,
            style: valueStyle,
            children: [
              if (inlineUnit) TextSpan(text: ' $unit', style: unitStyle),
            ],
          ),
          textAlign: TextAlign.center,
        ),
        if (unitBelow)
          Text(unit!, textAlign: TextAlign.center, style: unitStyle),
        if (showLabel) ...[
          const SizedBox(height: MileafSpace.inline2),
          Text(
            widget.centerLabel!,
            textAlign: TextAlign.center,
            style: unitStyle,
          ),
        ],
      ],
    );
  }

  (double, double) _measure(
    BuildContext context,
    String text,
    TextStyle style,
  ) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final result = (painter.width, painter.height);
    painter.dispose();
    return result;
  }
}

/// Arc geometry for [MileafShareRing], exposed for tests.
///
/// Returns `(segmentIndex, startAngle, sweepAngle)` from 12 o'clock clockwise.
/// Values ≤ 0 are skipped, neighbouring segments lose half a gap each, and a
/// single 100 % arc stays unbroken (R07: 首帧即完整几何).
List<(int, double, double)> shareRingArcs({
  required List<double> fractions,
  required double radius,
  double gap = MileafShareRingMetrics.gap,
}) {
  final visible = fractions.where((fraction) => fraction > 0).length;
  if (radius <= 0 || visible == 0) return const [];
  // Only a real boundary gets a gap; a single 100 % arc stays unbroken.
  final pad = visible > 1 ? (gap / radius) / 2 : 0.0;
  final arcs = <(int, double, double)>[];
  var cursor = -math.pi / 2;
  for (var i = 0; i < fractions.length; i++) {
    final sweep = fractions[i] * math.pi * 2;
    if (sweep > 0) {
      arcs.add((i, cursor + pad, sweep - pad * 2));
    }
    cursor += sweep;
  }
  return arcs;
}

class _ShareRingPainter extends CustomPainter {
  const _ShareRingPainter({
    required this.fractions,
    required this.colors,
    required this.track,
    required this.stroke,
  });

  final List<double> fractions;
  final List<Color> colors;
  final Color track;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    final radius = (size.shortestSide - stroke) / 2;
    if (radius <= 0) return;
    final center = size.center(Offset.zero);
    final rect = Rect.fromCircle(center: center, radius: radius);
    canvas.drawCircle(
      center,
      radius,
      Paint()
        ..color = track
        ..style = PaintingStyle.stroke
        ..strokeWidth = stroke,
    );
    final arcs = shareRingArcs(fractions: fractions, radius: radius);
    for (final (index, start, sweep) in arcs) {
      canvas.drawArc(
        rect,
        start,
        sweep,
        false,
        Paint()
          ..color = colors[index]
          ..style = PaintingStyle.stroke
          ..strokeWidth = stroke
          ..strokeCap = StrokeCap.butt,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _ShareRingPainter old) =>
      old.track != track ||
      old.stroke != stroke ||
      !_sameFractions(old.fractions, fractions) ||
      !_sameColor(old.colors, colors);

  static bool _sameColor(List<Color> a, List<Color> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// One legend line: colour dot, category name and its share of known energy.
///
/// 44 high so the row is a real touch target when it navigates to the filtered
/// record list (Spec §9).
class ShareRingLegendRow extends StatefulWidget {
  const ShareRingLegendRow({
    super.key,
    required this.color,
    required this.label,
    required this.share,
    this.onTap,
    this.semanticsLabel,
  });

  final Color color;
  final String label;
  final String share;
  final VoidCallback? onTap;
  final String? semanticsLabel;

  @override
  State<ShareRingLegendRow> createState() => _ShareRingLegendRowState();
}

class _ShareRingLegendRowState extends State<ShareRingLegendRow> {
  bool _focused = false;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    final row = SizedBox(
      height: MileafShareRingMetrics.legendRow,
      child: Row(
        children: [
          Container(
            width: MileafShareRingMetrics.dot,
            height: MileafShareRingMetrics.dot,
            decoration: BoxDecoration(
              color: widget.color,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: MileafSpace.s8),
          // 200% 大字下标签自然宽可超过图例行宽（D-AP10-05，充电方式卡实测
          // 溢出 2px）；标签可收，占比仍靠右。
          Flexible(
            child: Text(
              widget.label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: type.body.copyWith(color: colors.textMuted),
            ),
          ),
          const Spacer(),
          Text(
            widget.share,
            style: type.body.copyWith(
              color: colors.text,
              fontWeight: MileafType.weightMedium,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: widget.onTap != null,
      enabled: widget.onTap != null,
      label: widget.semanticsLabel ?? '${widget.label} ${widget.share}',
      excludeSemantics: true,
      onTap: widget.onTap,
      child: Focus(
        canRequestFocus: widget.onTap != null,
        onFocusChange: (value) => setState(() => _focused = value),
        child: Material(
          color: Colors.transparent,
          borderRadius: MileafRadius.smAll,
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: widget.onTap,
            borderRadius: MileafRadius.smAll,
            highlightColor: colors.accentSoft,
            splashColor: Colors.transparent,
            child: Container(
              foregroundDecoration: _focused
                  ? BoxDecoration(
                      borderRadius: MileafRadius.smAll,
                      border: Border.all(color: colors.focusRing, width: 2),
                    )
                  : null,
              child: row,
            ),
          ),
        ),
      ),
    );
  }
}
