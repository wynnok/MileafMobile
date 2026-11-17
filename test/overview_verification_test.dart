import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'overview_visualization_test.dart';
import 'support/overview_state_fixture.dart';
import 'support/statistics_insights_fixture.dart';

void main() {
  for (final scenario in [
    'empty',
    'missing',
    'sparse-reference',
    'charging-failure',
  ]) {
    testWidgets('概览配对口径独立恢复：$scenario', (tester) async {
      await openOverviewVisual(
        tester,
        (r) async {
          if (r.url.path.endsWith('/summary')) {
            return overviewResponse(overviewFixture('summary'));
          }
          if (r.url.path.endsWith('/meta')) {
            return overviewResponse(statisticsInsightsMeta());
          }
          if (r.url.queryParameters['kind'] == 'charging') {
            return scenario == 'charging-failure'
                ? http.Response('', 503)
                : overviewResponse(overviewFixture('charging-stats'));
          }
          return overviewResponse(stateDriving(r.url, scenario));
        },
        now: () => DateTime.utc(2026, 10, 28, 11),
        briefing: true,
        ownerCapabilities: true,
      );
      // P01：原「数据说明与更多」弹层改为页尾「关于这些数据」，配对口径的
      // 一句结论并入「电耗对比」卡；不再是「配对净电耗与覆盖」表格。
      await tester.scrollUntilVisible(find.text('电耗对比'), 150);
      await tester.pumpAndSettle();
      if (scenario == 'charging-failure') {
        // 补能失败不影响驾驶侧配对比较，配对值仍是本期账目的电耗格。
        expect(find.text('电耗与上月同期相同'), findsOneWidget);
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('overview-plate-net')),
            matching: find.text('188 Wh/km'),
          ),
          findsOneWidget,
        );
      } else {
        // R09/CP08：参照不可用或样本不足时不造句；参照质量或口径不满足时
        // 只说明暂不比较（原文案「参照质量或口径不满足时，仅展示原值」）。
        expect(find.textContaining('电耗与上月同期'), findsNothing);
        expect(find.textContaining('电耗比上月同期'), findsNothing);
        // 口径不可比与样本不足各有一句「暂不比较」说明（CP02）。
        expect(
          find.text(
            scenario == 'sparse-reference' ? '数据口径未确认，暂不比较' : '电耗样本不足，暂不作区间比较',
          ),
          findsOneWidget,
        );
      }
      expect(tester.takeException(), isNull);
    });
  }
}
