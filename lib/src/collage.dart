import 'dart:math' as math;

import 'package:flutter/material.dart';

/// C surfaces share lake colours. Data and chart semantics stay with callers.
enum CollageSurface { paper, hero, mint, sand }

class CollageTile extends StatelessWidget {
  const CollageTile({
    super.key,
    required this.child,
    this.surface = CollageSurface.paper,
    this.padding = const EdgeInsets.all(12),
  });
  final Widget child;
  final CollageSurface surface;
  final EdgeInsetsGeometry padding;
  @override
  Widget build(BuildContext context) {
    final dark = Theme.of(context).brightness == Brightness.dark;
    final color = switch (surface) {
      CollageSurface.hero =>
        dark ? const Color(0xFF06140F) : const Color(0xFF0B2A20),
      CollageSurface.mint =>
        dark ? const Color(0xFF1E3B2C) : const Color(0xFFD4F0DC),
      CollageSurface.sand =>
        dark ? const Color(0xFF3B3120) : const Color(0xFFF2E2C6),
      CollageSurface.paper =>
        dark ? const Color(0xFF12231A) : const Color(0xFFFBFDF9),
    };
    final theme = Theme.of(context);
    final heroScheme = theme.colorScheme.copyWith(
      onSurface: const Color(0xFFEEF7EF),
      onSurfaceVariant: const Color(0xFFB8D6C3),
      primary: const Color(0xFF8AD6AF),
    );
    return Theme(
      data: surface == CollageSurface.hero
          ? theme.copyWith(
              colorScheme: heroScheme,
              textTheme: theme.textTheme.apply(
                bodyColor: heroScheme.onSurface,
                displayColor: heroScheme.onSurface,
              ),
              iconTheme: IconThemeData(color: heroScheme.primary),
            )
          : theme,
      child: Card(
        color: color,
        margin: const EdgeInsets.only(bottom: 8),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(padding: padding, child: child),
      ),
    );
  }
}

/// C stacks to one column once body text reaches roughly 150% (200% setting).
bool largeText(BuildContext context) =>
    MediaQuery.textScalerOf(context).scale(14) >= 21;

/// A dominant result beside quieter evidence; large text always stacks.
class CollageBento extends StatelessWidget {
  const CollageBento({
    super.key,
    required this.lead,
    required this.evidence,
    this.stretch = false,
  });
  final Widget lead;
  final List<Widget> evidence;

  /// 两列等高：主 tile 与证据列顶底对齐，列内证据保持自然高度。
  ///
  /// `lead` 内可用 `Expanded`/`Flexible` 吸收多出的高度；这类 flex 子按自身
  /// 固有高度参与 intrinsic 计算，证据列不要放 flex 子，否则会被压缩。
  final bool stretch;
  @override
  Widget build(BuildContext context) {
    if (largeText(context)) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [lead, ...evidence],
      );
    }
    final row = Row(
      crossAxisAlignment: stretch
          ? CrossAxisAlignment.stretch
          : CrossAxisAlignment.start,
      children: [
        Expanded(flex: 6, child: lead),
        const SizedBox(width: 8),
        Expanded(
          flex: 5,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: stretch
                ? MainAxisAlignment.spaceBetween
                : MainAxisAlignment.start,
            children: evidence,
          ),
        ),
      ],
    );
    return stretch ? IntrinsicHeight(child: row) : row;
  }
}

/// Quiet line sparkline used by C preview tiles (`1,198.6` tile, 四个问题).
///
/// C 原型用「面积 + 折线」而非柱：缺失值（null）断线，不补零也不位移。
class Sparkline extends StatelessWidget {
  const Sparkline({super.key, required this.values, this.height = 34});
  final List<double?> values;
  final double height;
  @override
  Widget build(BuildContext context) {
    if (values.isEmpty) return SizedBox(height: height);
    final color = Theme.of(context).colorScheme.primary;
    return SizedBox(
      height: height,
      child: CustomPaint(
        painter: _SparklinePainter(values, color),
        size: Size.infinite,
      ),
    );
  }
}

class _SparklinePainter extends CustomPainter {
  _SparklinePainter(this.values, this.color);
  final List<double?> values;
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final known = values.whereType<double>();
    if (known.isEmpty) return;
    final lo = known.reduce(math.min), hi = known.reduce(math.max);
    final span = hi - lo;
    double x(int i) =>
        values.length == 1 ? size.width : i * size.width / (values.length - 1);
    double y(double v) =>
        size.height -
        1 -
        ((v - lo) / (span == 0 ? 1 : span)) * (size.height - 3);
    final line = Path();
    final area = Path();
    var started = false;
    for (var i = 0; i < values.length; i++) {
      final v = values[i];
      if (v == null) {
        started = false;
        continue;
      }
      final px = x(i), py = y(v);
      if (!started) {
        line.moveTo(px, py);
        area.moveTo(px, size.height);
        area.lineTo(px, py);
        started = true;
      } else {
        line.lineTo(px, py);
        area.lineTo(px, py);
      }
    }
    if (started) {
      area.lineTo(x(values.length - 1), size.height);
      area.close();
      canvas.drawPath(area, Paint()..color = color.withValues(alpha: .16));
      canvas.drawPath(
        line,
        Paint()
          ..color = color
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
      // C 也在每个已知点画小圆点，缺失日断线后仍能看出单点是数据。
      final dot = Paint()..color = color.withValues(alpha: .55);
      for (var i = 0; i < values.length; i++) {
        final v = values[i];
        if (v != null) canvas.drawCircle(Offset(x(i), y(v)), 1.3, dot);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SparklinePainter old) =>
      old.values != values || old.color != color;
}
