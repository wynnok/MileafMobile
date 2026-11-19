import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'semantic.dart';
import 'tokens.dart';

/// Key icons drawn on a 24 grid with a 1.5px stroke.
///
/// No SVG dependency; non-key icons may still fall back to Material outlined
/// glyphs as long as they keep the same visual weight.
enum MileafIconName {
  home,
  car,
  bolt,
  chart,
  route,
  mapPin,
  battery,
  clock,
  settings,
  chevron,
  refresh,
  wallet,
  info,
  close,
  check,
  copy,
  calendar,
  more,
  expand,
  chevronDown,
  back,
  plus,
  minus,
  moon,
  offline,
  leaf,
  thermometer,
  speed,
  share,
}

class MileafIcon extends StatelessWidget {
  const MileafIcon(
    this.name, {
    super.key,
    this.size = MileafIconMetrics.header,
    this.color,
    this.semanticLabel,
  });

  final MileafIconName name;
  final double size;
  final Color? color;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final resolved = color ?? context.colors.textMuted;
    final icon = CustomPaint(
      size: Size.square(size),
      painter: _MileafIconPainter(name, resolved),
      isComplex: false,
    );
    if (semanticLabel == null) return icon;
    return Semantics(label: semanticLabel, image: true, child: icon);
  }
}

class _MileafIconPainter extends CustomPainter {
  const _MileafIconPainter(this.name, this.color);
  final MileafIconName name;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final scale = size.shortestSide / MileafIconMetrics.grid;
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = MileafIconMetrics.stroke * scale
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final dots = <Offset>[];
    final filled = <(Offset, double)>[];
    final path = Path();
    double x(double v) => v * scale;
    double y(double v) => v * scale;
    Offset at(double a, double b) => Offset(x(a), y(b));

    switch (name) {
      case MileafIconName.home:
        path
          ..moveTo(x(3.5), y(10.1))
          ..lineTo(x(12), y(3.4))
          ..lineTo(x(20.5), y(10.1))
          ..moveTo(x(5.7), y(8.7))
          ..lineTo(x(5.7), y(20))
          ..lineTo(x(18.3), y(20))
          ..lineTo(x(18.3), y(8.7))
          ..moveTo(x(9.9), y(20))
          ..lineTo(x(9.9), y(14.4))
          ..lineTo(x(14.1), y(14.4))
          ..lineTo(x(14.1), y(20));
      case MileafIconName.car:
        path
          ..moveTo(x(3.8), y(15.6))
          ..lineTo(x(20.2), y(15.6))
          ..moveTo(x(5.5), y(15.6))
          ..lineTo(x(6.8), y(11.3))
          ..quadraticBezierTo(x(7.1), y(10.2), x(8.3), y(10.2))
          ..lineTo(x(15.7), y(10.2))
          ..quadraticBezierTo(x(16.9), y(10.2), x(17.2), y(11.3))
          ..lineTo(x(18.5), y(15.6))
          ..moveTo(x(4.2), y(15.6))
          ..lineTo(x(4.2), y(18.2))
          ..lineTo(x(6.6), y(18.2))
          ..lineTo(x(6.6), y(16.3))
          ..moveTo(x(19.8), y(15.6))
          ..lineTo(x(19.8), y(18.2))
          ..lineTo(x(17.4), y(18.2))
          ..lineTo(x(17.4), y(16.3));
        dots.addAll([at(7.5, 15.6), at(16.5, 15.6)]);
      case MileafIconName.bolt:
        path
          ..moveTo(x(13.4), y(2.9))
          ..lineTo(x(5.6), y(13.4))
          ..lineTo(x(10.6), y(13.4))
          ..lineTo(x(10.4), y(21.1))
          ..lineTo(x(18.4), y(10.6))
          ..lineTo(x(13.2), y(10.6))
          ..close();
      case MileafIconName.chart:
        path
          ..moveTo(x(3.6), y(20.3))
          ..lineTo(x(20.4), y(20.3))
          ..moveTo(x(7), y(20.3))
          ..lineTo(x(7), y(12.2))
          ..moveTo(x(12), y(20.3))
          ..lineTo(x(12), y(4.8))
          ..moveTo(x(17), y(20.3))
          ..lineTo(x(17), y(8.9));
      case MileafIconName.route:
        path
          ..moveTo(x(5.7), y(19.2))
          ..cubicTo(x(5.7), y(15.1), x(9.3), y(15.5), x(11.5), y(12.4))
          ..cubicTo(x(13.7), y(9.3), x(15.7), y(9.2), x(17.9), y(5.8));
        filled.addAll([(at(5.7, 19.2), 1.2), (at(17.9, 5.8), 1.2)]);
      case MileafIconName.mapPin:
        path
          ..moveTo(x(12), y(21.2))
          ..cubicTo(x(8.2), y(16.4), x(5.6), y(13.3), x(5.6), y(9.6))
          ..arcToPoint(
            at(18.4, 9.6),
            radius: Radius.circular(x(6.4)),
            clockwise: true,
          )
          ..cubicTo(x(18.4), y(13.3), x(15.8), y(16.4), x(12), y(21.2))
          ..close()
          ..addOval(Rect.fromCircle(center: at(12, 9.6), radius: x(2.2)));
      case MileafIconName.battery:
        path
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x(3), y(7.4), x(16.4), y(9.2)),
              Radius.circular(x(2)),
            ),
          )
          ..moveTo(x(19.4), y(10.6))
          ..lineTo(x(19.4), y(13.4))
          ..moveTo(x(6.6), y(11))
          ..lineTo(x(6.6), y(13))
          ..moveTo(x(9.6), y(11))
          ..lineTo(x(9.6), y(13))
          ..moveTo(x(12.6), y(11))
          ..lineTo(x(12.6), y(13));
      case MileafIconName.clock:
        path
          ..addOval(Rect.fromCircle(center: at(12, 12), radius: x(8.4)))
          ..moveTo(x(12), y(6.9))
          ..lineTo(x(12), y(12))
          ..lineTo(x(15.3), y(14.1));
      case MileafIconName.settings:
        // Eight-tooth gear outline with a round hub.
        final center = at(12, 12);
        for (var i = 0; i < 16; i++) {
          final angle = -math.pi / 2 + i * math.pi / 8;
          final radius = i.isEven ? 7.4 : 5.9;
          final point = Offset(
            center.dx + math.cos(angle) * x(radius),
            center.dy + math.sin(angle) * y(radius),
          );
          if (i == 0) {
            path.moveTo(point.dx, point.dy);
          } else {
            path.lineTo(point.dx, point.dy);
          }
        }
        path
          ..close()
          ..addOval(Rect.fromCircle(center: center, radius: x(2.8)));
      case MileafIconName.chevron:
        path
          ..moveTo(x(9.4), y(5.8))
          ..lineTo(x(15.6), y(12))
          ..lineTo(x(9.4), y(18.2));
      case MileafIconName.refresh:
        path.addArc(
          Rect.fromCircle(center: at(12, 12), radius: x(7.2)),
          -1.1,
          5.4,
        );
        // Arrow head at the gap, suggesting clockwise motion.
        path
          ..moveTo(x(11.4), y(3.0))
          ..lineTo(x(15.6), y(5.3))
          ..lineTo(x(11.8), y(8.3));
      case MileafIconName.wallet:
        path
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x(3.2), y(6.8), x(17.6), y(11.4)),
              Radius.circular(x(2)),
            ),
          )
          ..moveTo(x(3.2), y(10.8))
          ..lineTo(x(20.8), y(10.8));
        filled.add((at(16.4, 14.6), 1));
      case MileafIconName.info:
        path
          ..addOval(Rect.fromCircle(center: at(12, 12), radius: x(8.4)))
          ..moveTo(x(12), y(10.9))
          ..lineTo(x(12), y(16.5));
        filled.add((at(12, 8.3), .9));
      case MileafIconName.close:
        path
          ..moveTo(x(6.2), y(6.2))
          ..lineTo(x(17.8), y(17.8))
          ..moveTo(x(17.8), y(6.2))
          ..lineTo(x(6.2), y(17.8));
      case MileafIconName.check:
        path
          ..moveTo(x(4.6), y(12.4))
          ..lineTo(x(9.6), y(17.4))
          ..lineTo(x(19.4), y(6.6));
      case MileafIconName.copy:
        // Two offset sheets on the 24 grid. The 4-unit offset keeps them
        // readable as two sheets at 20px; a 2-unit offset merges into one box
        // with a doubled edge (Spec §8 / §14).
        path
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x(10.5), y(10.5), x(9), y(9)),
              Radius.circular(x(2)),
            ),
          )
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x(6.5), y(6.5), x(9), y(9)),
              Radius.circular(x(2)),
            ),
          );
      case MileafIconName.calendar:
        // 日历：圆角 body + 两个顶部挂耳 + 三个日点。
        path
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x(4.5), y(5.5), x(15), y(14)),
              Radius.circular(x(2.5)),
            ),
          )
          ..moveTo(x(8), y(5.5))
          ..lineTo(x(8), y(3.5))
          ..moveTo(x(16), y(5.5))
          ..lineTo(x(16), y(3.5));
        filled.addAll([
          (at(8, 11.5), .9),
          (at(12, 11.5), .9),
          (at(16, 11.5), .9),
        ]);
      case MileafIconName.more:
        // 三点横向省略号。
        filled.addAll([(at(6, 12), 1.4), (at(12, 12), 1.4), (at(18, 12), 1.4)]);
      case MileafIconName.expand:
        // 四角外向括号：展开。
        path
          ..moveTo(x(8.5), y(4.5))
          ..lineTo(x(4.5), y(4.5))
          ..lineTo(x(4.5), y(8.5))
          ..moveTo(x(15.5), y(4.5))
          ..lineTo(x(19.5), y(4.5))
          ..lineTo(x(19.5), y(8.5))
          ..moveTo(x(4.5), y(15.5))
          ..lineTo(x(4.5), y(19.5))
          ..lineTo(x(8.5), y(19.5))
          ..moveTo(x(19.5), y(15.5))
          ..lineTo(x(19.5), y(19.5))
          ..lineTo(x(15.5), y(19.5));
      case MileafIconName.chevronDown:
        path
          ..moveTo(x(5.8), y(9.4))
          ..lineTo(x(12), y(15.6))
          ..lineTo(x(18.2), y(9.4));
      case MileafIconName.back:
        // 左向返回 chevron（与既有 chevron 同字重镜像）。
        path
          ..moveTo(x(15.6), y(5.8))
          ..lineTo(x(9.4), y(12))
          ..lineTo(x(15.6), y(18.2));
      case MileafIconName.plus:
        path
          ..moveTo(x(12), y(5))
          ..lineTo(x(12), y(19))
          ..moveTo(x(5), y(12))
          ..lineTo(x(19), y(12));
      case MileafIconName.minus:
        path
          ..moveTo(x(5), y(12))
          ..lineTo(x(19), y(12));
      case MileafIconName.moon:
        // 月牙：外弧圆心 (13.5,12) r6.8 顺时针过右侧，内弧圆心 (9.5,12)
        // r6.8 逆时针过右侧；两端为两圆交点 (±2, ±6.5)。
        // atan(6.5/2) ≈ 1.2793 rad。
        path.addArc(
          Rect.fromCircle(center: at(13.5, 12), radius: x(6.8)),
          -1.8623,
          3.7246,
        );
        path.addArc(
          Rect.fromCircle(center: at(9.5, 12), radius: x(6.8)),
          1.2793,
          -2.5586,
        );
      case MileafIconName.offline:
        // 双层上弧 + 斜线：离线/无网络。
        path.addArc(
          Rect.fromCircle(center: at(12, 14), radius: x(7)),
          math.pi,
          math.pi,
        );
        path.addArc(
          Rect.fromCircle(center: at(12, 15.5), radius: x(3.5)),
          math.pi,
          math.pi,
        );
        path
          ..moveTo(x(4.5), y(4.5))
          ..lineTo(x(19.5), y(19.5));
      case MileafIconName.leaf:
        // 叶片（CL11：效率/续航）：两条对称三次贝塞尔围出轮廓——叶柄端
        // (12,20.2) 向左上扫到叶尖 (12,4.2)，再镜像扫回；加一条中脉与一截
        // 叶柄。不加密集叶脉，保证 16px 下仍读成叶子而不是网格。
        path
          ..moveTo(x(12), y(20.2))
          ..cubicTo(x(5.5), y(17.0), x(5.5), y(7.4), x(12), y(4.2))
          ..cubicTo(x(18.5), y(7.4), x(18.5), y(17.0), x(12), y(20.2))
          ..moveTo(x(12), y(20.2))
          ..lineTo(x(12), y(6.4))
          ..moveTo(x(12), y(20.2))
          ..lineTo(x(12), y(21.6));
      case MileafIconName.thermometer:
        // 温度（CL11：环境）：竖向药丸球管 + 底部圆球 + 三条刻度横线。
        // 球管底 14.6 与圆球顶 14.5 相接，合成一支温度计。
        path
          ..addRRect(
            RRect.fromRectAndRadius(
              Rect.fromLTWH(x(9.9), y(3.4), x(4.2), y(11.2)),
              Radius.circular(x(2.1)),
            ),
          )
          ..addOval(Rect.fromCircle(center: at(12, 17.6), radius: x(3.1)))
          ..moveTo(x(6.6), y(8.4))
          ..lineTo(x(8.6), y(8.4))
          ..moveTo(x(6.6), y(11.6))
          ..lineTo(x(8.6), y(11.6))
          ..moveTo(x(6.6), y(14.8))
          ..lineTo(x(8.6), y(14.8));
      case MileafIconName.speed:
        // 速度（CL11）：半圆表盘（圆心 12,14.6、r7.4，自左侧 π 扫 π）+
        // 自圆心指向 10 点钟的指针 + 中心实心点 1.15。
        path
          ..addArc(
            Rect.fromCircle(center: at(12, 14.6), radius: x(7.4)),
            math.pi,
            math.pi,
          )
          ..moveTo(x(12), y(14.6))
          ..lineTo(x(8.9), y(10.4));
        filled.add((at(12, 14.6), 1.15));
      case MileafIconName.share:
        // 分享（CL11）：三个节点（右上 / 左中 / 右下）+ 两条连线；
        // 连线起止落在左中圆与两个右侧圆的切点附近，读成「从一个点分发」。
        path
          ..addOval(Rect.fromCircle(center: at(18, 5.8), radius: x(2.1)))
          ..addOval(Rect.fromCircle(center: at(6, 12), radius: x(2.1)))
          ..addOval(Rect.fromCircle(center: at(18, 18.2), radius: x(2.1)))
          ..moveTo(x(7.9), y(11.0))
          ..lineTo(x(16.1), y(6.9))
          ..moveTo(x(7.9), y(13.0))
          ..lineTo(x(16.1), y(17.1));
    }
    canvas.drawPath(path, paint);
    final fill = Paint()..color = color;
    for (final dot in dots) {
      canvas.drawCircle(dot, 1.1 * scale, fill);
    }
    for (final (center, radius) in filled) {
      canvas.drawCircle(center, radius * scale, fill);
    }
  }

  @override
  bool shouldRepaint(covariant _MileafIconPainter old) =>
      old.name != name || old.color != color;
}
