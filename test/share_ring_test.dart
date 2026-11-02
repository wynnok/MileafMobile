import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/components/components.dart';

import 'design_components_test.dart' show pumpComponent;

const _ac = Color(0xFF74DDA8);
const _dc = Color(0xFF3A7F63);

void main() {
  group('shareRingArcs', () {
    test('两段按能量占比切分，缺口对称扣除', () {
      final arcs = shareRingArcs(fractions: const [.7, .3], radius: 46);
      expect(arcs.map((arc) => arc.$1), [0, 1]);
      final pad = (3 / 46) / 2;
      for (final (index, _, sweep) in arcs) {
        final share = (sweep + pad * 2) / (math.pi * 2);
        expect(share, closeTo(index == 0 ? .7 : .3, .005));
      }
    });

    test('占比为 0 的段不画，单段时不留缺口', () {
      final arcs = shareRingArcs(fractions: const [1, 0], radius: 46);
      expect(arcs, hasLength(1));
      expect(arcs.single.$3, closeTo(math.pi * 2, .0001));
    });

    test('总和为 0 时只留轨道', () {
      expect(shareRingArcs(fractions: const [0, 0], radius: 46), isEmpty);
    });

    test('扫出进度只影响已画长度，不移动起点', () {
      final full = shareRingArcs(fractions: const [.5, .5], radius: 46);
      final half = shareRingArcs(
        fractions: const [.5, .5],
        radius: 46,
        progress: .5,
      );
      expect(half.first.$2, full.first.$2);
      expect(half.first.$3, closeTo(math.pi - (3 / 46), .01));
      expect(half, hasLength(1));
    });
  });

  group('MileafShareRing', () {
    testWidgets('环是纯图形，不额外进入语义树', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const MileafShareRing(
          segments: [
            ShareRingSegment(label: 'AC', value: 70, color: _ac),
            ShareRingSegment(label: 'DC', value: 30, color: _dc),
          ],
          centerValue: '70',
          centerLabel: 'AC',
        ),
      );
      expect(find.bySemanticsLabel('补能构成：AC 70%，DC 30%'), findsNothing);
      expect(find.textContaining('70'), findsWidgets);
      semantics.dispose();
    });

    testWidgets('分类能量全为 0 时圆心为 — 且不抛错', (tester) async {
      await pumpComponent(
        tester,
        const MileafShareRing(
          segments: [
            ShareRingSegment(label: 'AC', value: 0, color: _ac),
            ShareRingSegment(label: 'DC', value: 0, color: _dc),
          ],
        ),
      );
      expect(find.text('—'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('200% 下圆心放不下就隐藏，不缩小数字', (tester) async {
      await pumpComponent(
        tester,
        const MileafShareRing(
          segments: [
            ShareRingSegment(label: 'AC', value: 1, color: _ac),
            ShareRingSegment(label: 'DC', value: 0, color: _dc),
          ],
          centerValue: '100',
          centerLabel: 'AC',
          size: 64,
        ),
        scale: 2,
      );
      expect(find.textContaining('100'), findsNothing);
      expect(find.text('AC'), findsNothing, reason: '圆心整体隐藏');
      expect(tester.takeException(), isNull);
    });

    testWidgets('reduce motion 下首帧即完整，不再排帧', (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpComponent(
        tester,
        const MileafShareRing(
          segments: [
            ShareRingSegment(label: 'AC', value: 60, color: _ac),
            ShareRingSegment(label: 'DC', value: 40, color: _dc),
          ],
          centerValue: '60',
        ),
      );
      expect(tester.binding.hasScheduledFrame, isFalse);
    });
  });

  group('ShareRingLegendRow', () {
    testWidgets('44 高、可点、报按钮', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpComponent(
        tester,
        ShareRingLegendRow(
          color: _ac,
          label: 'AC',
          share: '100%',
          onTap: () => taps++,
        ),
      );
      expect(
        tester.getSize(find.byType(ShareRingLegendRow)).height,
        greaterThanOrEqualTo(44),
      );
      expect(find.bySemanticsLabel('AC 100%'), findsOneWidget);
      await tester.tap(find.text('AC'));
      expect(taps, 1);
      semantics.dispose();
    });

    testWidgets('无 onTap 时不带按钮语义', (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpComponent(
        tester,
        const ShareRingLegendRow(color: _ac, label: 'DC', share: '0%'),
      );
      final data = tester.getSemantics(find.text('DC')).getSemanticsData();
      expect(data.hasAction(SemanticsAction.tap), isFalse);
      semantics.dispose();
    });
  });
}
