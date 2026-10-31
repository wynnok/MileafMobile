import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;

import 'overview_visualization_test.dart';
import 'overview_state_render_test.dart' show stateDriving;
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
      await tester.scrollUntilVisible(find.text('数据说明与更多').hitTestable(), 150);
      await tester.tap(find.text('数据说明与更多'));
      await tester.pumpAndSettle();
      await tester.scrollUntilVisible(find.text('配对净电耗与覆盖'), 150);
      if (scenario == 'charging-failure') {
        expect(find.textContaining('配对净电耗较参照差 0.0 Wh/km'), findsOneWidget);
        expect(find.text('配对估算净电耗'), findsOneWidget);
      } else {
        expect(find.textContaining('配对净电耗较参照差'), findsNothing);
        expect(find.text('参照质量或口径不满足时，仅展示原值'), findsOneWidget);
      }
      expect(tester.takeException(), isNull);
    });
  }
}
