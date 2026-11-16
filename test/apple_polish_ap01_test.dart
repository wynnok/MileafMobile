// AP01 设计基础：R22 字体角色表、R23 两级文字与 controlBorder。
// 规格 docs/specs/apple-polish.md R22–R24 / PD04；输入冻结点 FP0（7cf8dd4）。
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/icons.dart';
import 'package:mileaf/src/design/layout.dart';
import 'package:mileaf/src/design/motion.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/design/typography.dart';

import 'support/color_math.dart';

void main() {
  group('R22 字体角色表', () {
    test('新角色字号、行高、字重、字距常量与规格一致', () {
      // R22 表：largeTitle 34/41 600；title2 22/28 600；headline 17/24 600；
      // metricSm 20/26 500（-0.01em）；subheadline/control 15/21（400/500）；
      // footnote 13/18 400；caption 12/16 400。
      expect(MileafType.largeTitleSize, 34);
      expect(MileafType.largeTitleHeight, 41);
      expect(MileafType.largeTitleTracking, 0);
      expect(MileafType.title2Size, 22);
      expect(MileafType.title2Height, 28);
      expect(MileafType.headlineSize, 17);
      expect(MileafType.headlineHeight, 24);
      expect(MileafType.metricSmSize, 20);
      expect(MileafType.metricSmHeight, 26);
      expect(MileafType.metricSmTracking, -.01);
      expect(MileafType.subheadlineSize, 15);
      expect(MileafType.subheadlineHeight, 21);
      expect(MileafType.controlSize, 15);
      expect(MileafType.controlHeight, 21);
      expect(MileafType.footnoteSize, 13);
      expect(MileafType.footnoteHeight, 18);
      expect(MileafType.captionSize, 12);
      expect(MileafType.captionHeight, 16);
      // 中文最大字重 600：新角色不得使用 700。
      for (final w in [
        MileafType.weightRegular,
        MileafType.weightMedium,
        MileafType.weightSemiBold,
      ]) {
        expect(w.value, lessThanOrEqualTo(600));
      }
    });

    test('新角色样式解析：字号/行高/字重/字距/颜色（深色）', () {
      final t = MileafTextStyles.resolve(const MileafColors.dark());
      // 主文字角色用 text。
      for (final (style, size, height, weight, tracking) in [
        (t.largeTitle, 34.0, 41.0, FontWeight.w600, 0.0),
        (t.title2, 22.0, 28.0, FontWeight.w600, 0.0),
        (t.headline, 17.0, 24.0, FontWeight.w600, 0.0),
        (t.metricSm, 20.0, 26.0, FontWeight.w500, -.01),
      ]) {
        expect(style.fontSize, size);
        expect(style.height, closeTo(height / size, 1e-9));
        expect(style.fontWeight, weight);
        expect(style.letterSpacing, closeTo(tracking * size, 1e-9));
        expect(style.color, const MileafColors.dark().text);
      }
      // 次级文字角色用 textSecondary。
      for (final (style, size, height, weight) in [
        (t.subheadline, 15.0, 21.0, FontWeight.w400),
        (t.control, 15.0, 21.0, FontWeight.w500),
        (t.footnote, 13.0, 18.0, FontWeight.w400),
        (t.caption, 12.0, 16.0, FontWeight.w400),
      ]) {
        expect(style.fontSize, size);
        expect(style.height, closeTo(height / size, 1e-9));
        expect(style.fontWeight, weight);
        expect(style.color, const MileafColors.dark().textSecondary);
      }
      // 所有数字角色带 tabular figures（沿用既有实现）。
      for (final style in [
        t.largeTitle,
        t.title2,
        t.headline,
        t.metricSm,
        t.subheadline,
        t.control,
        t.footnote,
        t.caption,
      ]) {
        expect(style.fontFeatures?.any((f) => f.feature == 'tnum'), isTrue);
      }
    });

    test('subheadline 分组标题 500 变体与 control 选中 600 变体', () {
      final t = MileafTextStyles.resolve(const MileafColors.dark());
      expect(t.groupTitle.fontWeight, FontWeight.w500);
      expect(t.groupTitle.fontSize, t.subheadline.fontSize);
      expect(t.groupTitle.color, t.subheadline.color);
      expect(t.controlSelected.fontWeight, FontWeight.w600);
      expect(t.controlSelected.fontSize, t.control.fontSize);
    });

    test('旧角色保留原值作为过渡别名', () {
      final t = MileafTextStyles.resolve(const MileafColors.dark());
      // title 20/28/600 → text（迁移去向：区块/身份/空状态 → title2）。
      expect(t.title.fontSize, 20);
      expect(t.title.height, closeTo(28 / 20, 1e-9));
      expect(t.title.fontWeight, FontWeight.w600);
      expect(t.title.color, const MileafColors.dark().text);
      // label 14/20/500 → textMuted（去向：subheadline/control）。
      expect(t.label.fontSize, 14);
      expect(t.label.height, closeTo(20 / 14, 1e-9));
      expect(t.label.fontWeight, FontWeight.w500);
      expect(t.label.color, const MileafColors.dark().textMuted);
      // micro 12/18/400 → textFaint（去向：footnote/caption）。
      expect(t.micro.fontSize, 12);
      expect(t.micro.height, closeTo(18 / 12, 1e-9));
      expect(t.micro.fontWeight, FontWeight.w400);
      expect(t.micro.color, const MileafColors.dark().textFaint);
      // pageTitle/navigationTitle/bodyStrong 原值不变。
      expect(t.pageTitle.fontSize, 28);
      expect(t.pageTitle.height, closeTo(34 / 28, 1e-9));
      expect(t.navigationTitle.fontSize, 18);
      expect(t.navigationTitle.height, closeTo(26 / 18, 1e-9));
      expect(t.bodyStrong.fontWeight, FontWeight.w500);
      expect(t.bodyStrong.fontSize, t.body.fontSize);
      // 未迁移角色原值不变。
      expect(t.display.fontSize, 40);
      expect(t.metricLg.fontSize, 32);
      expect(t.metricMd.fontSize, 24);
      expect(t.body.fontSize, 17);
      expect(t.navLabel.fontSize, 12);
    });
  });

  group('R23 文字层级与色彩职责', () {
    test('textSecondary 是 textMuted 的新语义名，两模式取值相同', () {
      for (final colors in const [MileafColors.dark(), MileafColors.light()]) {
        expect(colors.textSecondary, colors.textMuted);
        expect(colors.textSecondary, isNot(colors.text));
      }
    });

    test(
      '两级文字对比矩阵（canvas/surface/segmentTrack/segmentSelected/surfaceRaised）',
      () {
        for (final colors in const [
          MileafColors.dark(),
          MileafColors.light(),
        ]) {
          final mode = colors.isDark ? '深色' : '浅色';
          for (final (name, background) in [
            ('canvas', colors.canvas),
            ('surface', colors.surface),
            ('segmentTrack', colors.segmentTrack),
            ('segmentSelected', colors.segmentSelected),
            ('surfaceRaised', colors.surfaceRaised),
          ]) {
            expect(
              contrastRatio(colors.text, background),
              greaterThanOrEqualTo(4.5),
              reason: '$mode 主级文字在 $name 上未达 4.5:1',
            );
            if (colors.isDark && background == colors.segmentSelected) {
              // 既有 mist500×#343C46 实测 4.461:1，低于 4.5。次级文字不落在
              // 选中底上（选中段文字走 accentStrong），改值超出本票两处允许
              // 外观变化 → 登记偏差账本并交总控，此处锁定现值防漂移。
              expect(
                contrastRatio(colors.textSecondary, background),
                closeTo(4.461, .01),
                reason: '$mode 次级文字在 $name 上的实测值（偏差账本 AU-AP01-1）',
              );
              continue;
            }
            expect(
              contrastRatio(colors.textSecondary, background),
              greaterThanOrEqualTo(4.5),
              reason: '$mode 次级文字在 $name 上未达 4.5:1',
            );
          }
        }
      },
    );

    test('controlBorder 对全部相邻底色 ≥3:1 且为更轻的独立中性色', () {
      for (final colors in const [MileafColors.dark(), MileafColors.light()]) {
        final mode = colors.isDark ? '深色' : '浅色';
        // 相邻底色：输入与边界实际落点（R23.5 候选表）+ 分段轨道 +
        // accentSoft 合成底（统计专题选中格纹理的实际落点）。
        for (final (name, background) in [
          ('canvas', colors.canvas),
          ('surface', colors.surface),
          ('surfaceRaised', colors.surfaceRaised),
          ('segmentTrack', colors.segmentTrack),
          ('accentSoft合成底', Color.alphaBlend(colors.accentSoft, colors.canvas)),
        ]) {
          expect(
            contrastRatio(colors.controlBorder, background),
            greaterThanOrEqualTo(3),
            reason: '$mode controlBorder 在 $name 上未达 3:1（候选值实测被否决）',
          );
        }
        // 独立中性色：不与 textMuted 同值，且比它更轻。
        expect(colors.controlBorder, isNot(colors.textMuted));
        final lighter = colors.isDark
            ? luminance(colors.controlBorder) < luminance(colors.textMuted)
            : luminance(colors.controlBorder) > luminance(colors.textMuted);
        expect(lighter, isTrue, reason: '$mode controlBorder 应比 textMuted 更轻');
      }
    });
  });

  group('R24 形状、容器与间距', () {
    test('容器半径用既有 lg，弹层 28，输入 12', () {
      // R24：车况卡/模块卡/分组卡/地图容器半径 20（不新增 token）；
      // 弹层 28；输入框半径 12、高 52。
      expect(MileafRadius.lg, 20);
      expect(MileafRadius.sheet, 28);
      expect(MileafRadius.md, 12);
      expect(MileafSpace.inputMinHeight, 52);
    });

    test('胶囊与圆形形状常量就位', () {
      expect(MileafShape.capsule, isA<StadiumBorder>());
      expect(MileafShape.circle, isA<CircleBorder>());
    });

    test('发丝线宽为 0（一物理像素分隔线）', () {
      expect(MileafStroke.hairline, 0);
    });

    test('规范间距集合与弃用档位保留原值', () {
      expect([...MileafSpace.canonical]..sort(), [2, 4, 8, 12, 16, 20, 24, 32]);
      // 弃用标注不删除：原值保留，所属文件迁移时清零，AP14 全局归零。
      expect(MileafSpace.inline6, 6);
      expect(MileafSpace.inline10, 10);
      expect(MileafSpace.s18, 18);
      expect(MileafSpace.s40, 40);
      expect(MileafSpace.s56, 56);
    });
  });

  group('§4 动效参数集中声明（M01–M12）', () {
    test('时长常量与规格一致', () {
      // M01 按压覆盖层 120ms；M02 互斥选中 180ms；M05 弹层 280/220；
      // M06 折叠箭头 160ms、内容高度 200ms、内容透明度 120ms；
      // M08 快照替换 120ms；M09 指标切换淡入 120ms；
      // M10 大内容查看器 150/120ms；M11 状态条高度 200ms、透明度 160ms。
      expect(MileafDurations.press.inMilliseconds, 120);
      expect(MileafDurations.selection.inMilliseconds, 180);
      expect(MileafDurations.chevron.inMilliseconds, 160);
      expect(MileafDurations.sheetIn.inMilliseconds, 280);
      expect(MileafDurations.sheetOut.inMilliseconds, 220);
      expect(MileafDurations.value.inMilliseconds, 120);
      expect(MileafDurations.foldHeight.inMilliseconds, 200);
      expect(MileafDurations.foldOpacity.inMilliseconds, 120);
      expect(MileafDurations.metricFade.inMilliseconds, 120);
      expect(MileafDurations.viewerIn.inMilliseconds, 150);
      expect(MileafDurations.viewerOut.inMilliseconds, 120);
      expect(MileafDurations.statusHeight.inMilliseconds, 200);
      expect(MileafDurations.statusOpacity.inMilliseconds, 160);
    });

    test('曲线常量与规格一致', () {
      expect(MileafCurves.press, Curves.easeOut);
      expect(MileafCurves.selection, Curves.easeOutCubic);
      expect(MileafCurves.fold, Curves.easeOutCubic);
      expect(MileafCurves.fade, Curves.easeOut);
      expect(MileafCurves.sheet, Curves.easeOutCubic);
    });

    test('缩放、拉伸与收起阈值常量与规格一致', () {
      // M01 缩放 0.97（PD11 修订 ADR0012 R16 的 0.98）；M02 起步横向拉伸
      // 底栏 1.06（= 液态玻璃镜片拉伸）、分段 1.04；M03 滚动 0–16 收起；
      // M10 大内容查看器 0.96→1。
      expect(MileafMotion.pressScale, .97);
      expect(MileafMotion.navStretch, 1.06);
      expect(MileafMotion.segmentStretch, 1.04);
      expect(MileafMotion.collapseScroll, 16);
      expect(MileafMotion.viewerScale, .96);
    });

    testWidgets('MileafLayout.motion 调用合同不变：减少动效归零', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          theme: mileafTheme(Brightness.dark),
          home: Builder(
            builder: (context) => Text(
              '${MileafLayout.motion(context, const Duration(milliseconds: 280)).inMilliseconds}',
            ),
          ),
        ),
      );
      expect(find.text('280'), findsOneWidget);
      tester.binding.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        () => tester.binding.platformDispatcher
            .clearAccessibilityFeaturesTestValue(),
      );
      await tester.pump();
      expect(find.text('0'), findsOneWidget);
    });
  });

  group('R32 工程约束', () {
    testWidgets('主题按压无涟漪（splashFactory: NoSplash）', (tester) async {
      for (final brightness in Brightness.values) {
        final theme = mileafTheme(brightness);
        expect(
          theme.splashFactory,
          NoSplash.splashFactory,
          reason: '$brightness 按压反馈不得出现 Material 涟漪（PD11/M01）',
        );
      }
      expect(tester.takeException(), isNull);
    });
  });

  group('R32 自绘图标', () {
    test('九个新图标入枚举，24 网格 1.5 描边几何不变', () {
      expect(MileafIconName.values.length, 25);
      for (final name in [
        MileafIconName.calendar,
        MileafIconName.more,
        MileafIconName.expand,
        MileafIconName.chevronDown,
        MileafIconName.back,
        MileafIconName.plus,
        MileafIconName.minus,
        MileafIconName.moon,
        MileafIconName.offline,
      ]) {
        expect(name, isIn(MileafIconName.values));
      }
      expect(MileafIconMetrics.grid, 24);
      expect(MileafIconMetrics.stroke, 1.5);
    });

    testWidgets('25 个图标在浅深 24 尺寸下都可绘制', (tester) async {
      for (final brightness in Brightness.values) {
        await tester.pumpWidget(
          MaterialApp(
            theme: mileafTheme(brightness),
            home: Scaffold(
              body: Wrap(
                children: [
                  for (final name in MileafIconName.values)
                    MileafIcon(
                      name,
                      size: MileafIconMetrics.header,
                      semanticLabel: name.name,
                    ),
                ],
              ),
            ),
          ),
        );
        expect(tester.takeException(), isNull);
        expect(find.byType(MileafIcon), findsNWidgets(25));
      }
    });
  });
}
