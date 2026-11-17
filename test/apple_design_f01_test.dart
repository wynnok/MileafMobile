import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mileaf/src/design/semantic.dart';
import 'package:mileaf/src/design/display_preferences.dart';
import 'package:mileaf/src/design/layout.dart';
import 'package:mileaf/src/design/theme.dart';
import 'package:mileaf/src/design/tokens.dart';
import 'package:mileaf/src/design/typography.dart';
import 'package:mileaf/src/design/components/navigation_material.dart';
import 'package:mileaf/src/design/components/nav_bar.dart';
import 'package:mileaf/src/design/components/button.dart';

void main() {
  test('R12 exposes the accepted Apple renewal type roles', () {
    expect(MileafType.displaySize, 40);
    expect(MileafType.metricLgSize, 32);
    expect(MileafType.pageTitleSize, 28);
    expect(MileafType.titleSize, 20);
    expect(MileafType.navigationTitleSize, 18);
    expect(MileafType.bodySize, 17);
    expect(MileafType.labelSize, 14);
    expect(MileafRadius.surface, 24);
    expect(MileafRadius.sheet, 28);
  });

  testWidgets('R13 resolves overview content to the ordinary surface palette', (
    tester,
  ) async {
    late MileafColors colors;
    late MileafTextStyles type;
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        home: Builder(
          builder: (context) {
            colors = context.colors;
            type = context.type;
            return const SizedBox();
          },
        ),
      ),
    );

    expect(colors.hero, colors.surface);
    expect(colors.heroText, colors.text);
    expect(colors.heroMuted, colors.textMuted);
    expect(type.navigationTitle.fontSize, MileafType.navigationTitleSize);
  });

  test(
    'R18 keeps iOS material solid until reduce transparency is known',
    () async {
      final controller = DisplayPreferencesController(
        platform: DisplayPreferencesPlatform.iOS,
        readReduceTransparency: () async => false,
      );
      addTearDown(controller.dispose);

      expect(controller.reduceTransparency, isNull);
      expect(controller.useSolidMaterial, isTrue);

      await controller.refresh();
      expect(controller.reduceTransparency, isFalse);
      expect(controller.useSolidMaterial, isFalse);

      controller.updateFromPlatform(true);
      expect(controller.reduceTransparency, isTrue);
      expect(controller.useSolidMaterial, isTrue);
    },
  );

  test('R18 treats Android reduce transparency as a known false default', () {
    final controller = DisplayPreferencesController(
      platform: DisplayPreferencesPlatform.android,
    );
    addTearDown(controller.dispose);

    expect(controller.reduceTransparency, isFalse);
    expect(controller.useSolidMaterial, isFalse);
  });

  test('R18 returns to the solid path when the iOS bridge fails', () async {
    final controller = DisplayPreferencesController(
      platform: DisplayPreferencesPlatform.iOS,
      readReduceTransparency: () async => throw StateError('bridge'),
    );
    addTearDown(controller.dispose);

    await controller.refresh();
    expect(controller.reduceTransparency, isNull);
    expect(controller.useSolidMaterial, isTrue);
  });

  testWidgets('R14 blurs only when transparency and contrast allow it', (
    tester,
  ) async {
    final controller = DisplayPreferencesController(
      platform: DisplayPreferencesPlatform.android,
    );
    addTearDown(controller.dispose);

    Future<void> pump({required bool highContrast}) => tester.pumpWidget(
      DisplayPreferencesScope(
        controller: controller,
        child: MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: MediaQuery(
            data: MediaQueryData(highContrast: highContrast),
            child: const NavigationMaterial(
              borderRadius: MileafRadius.surfaceAll,
              child: SizedBox(width: 240, height: 64),
            ),
          ),
        ),
      ),
    );

    await pump(highContrast: false);
    expect(find.byType(BackdropFilter), findsOneWidget);

    await pump(highContrast: true);
    expect(find.byType(BackdropFilter), findsNothing);
  });

  testWidgets('R18 consumes iOS channel notifications across lifecycles', (
    tester,
  ) async {
    const channel = MethodChannel('mileaf/display_preferences.test');
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      calls.add(call.method);
      return {'reduceTransparency': false};
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    final first = DisplayPreferencesController(
      platform: DisplayPreferencesPlatform.iOS,
      channel: channel,
    );
    final second = DisplayPreferencesController(
      platform: DisplayPreferencesPlatform.iOS,
      channel: channel,
    );
    await first.start();
    await second.start();
    expect(calls.where((m) => m == 'getDisplayPreferences'), hasLength(2));
    first.updateFromPlatform(true);
    second.updateFromPlatform(true);
    expect(first.useSolidMaterial, isTrue);
    expect(second.useSolidMaterial, isTrue);
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('displayPreferencesChanged', {
              'reduceTransparency': false,
            }),
          ),
          (_) {},
        );
    expect(second.useSolidMaterial, isFalse);
    await first.refresh();
    expect(calls.where((m) => m == 'getDisplayPreferences'), hasLength(3));
    first.dispose();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('displayPreferencesChanged', {
              'reduceTransparency': false,
            }),
          ),
          (_) {},
        );
    expect(second.useSolidMaterial, isFalse);
    second.dispose();
    await TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .handlePlatformMessage(
          channel.name,
          channel.codec.encodeMethodCall(
            const MethodCall('displayPreferencesChanged', {
              'reduceTransparency': true,
            }),
          ),
          (_) {},
        );
    expect(tester.takeException(), isNull);
  });

  testWidgets('R18 treats a missing iOS plugin as the solid path', (
    tester,
  ) async {
    const channel = MethodChannel('mileaf/display_preferences.missing');
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(channel, (
      call,
    ) async {
      throw MissingPluginException();
    });
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        channel,
        null,
      );
    });
    final controller = DisplayPreferencesController(
      platform: DisplayPreferencesPlatform.iOS,
      channel: channel,
    );
    addTearDown(controller.dispose);
    await controller.start();
    expect(controller.reduceTransparency, isNull);
    expect(controller.useSolidMaterial, isTrue);
  });

  testWidgets('R15 places one floating selection surface above the safe area', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(360, 800);
    tester.view.devicePixelRatio = 1;
    addTearDown(() {
      tester.view.resetPhysicalSize();
      tester.view.resetDevicePixelRatio();
    });
    final preferences = DisplayPreferencesController(
      platform: DisplayPreferencesPlatform.android,
    );
    addTearDown(preferences.dispose);

    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: preferences,
        child: MaterialApp(
          theme: mileafTheme(Brightness.light)
              .copyWith(platform: TargetPlatform.iOS),
          home: MediaQuery(
            data: const MediaQueryData(
              size: Size(360, 800),
              padding: EdgeInsets.only(bottom: 24),
              viewPadding: EdgeInsets.only(bottom: 24),
            ),
            child: Scaffold(
              bottomNavigationBar: MileafNavBar(index: 0, onSelected: (_) {}),
            ),
          ),
        ),
      ),
    );

    final material = tester.getRect(
      find.descendant(
        of: find.byType(MileafNavBar),
        matching: find.byType(NavigationMaterial),
      ),
    );
    final nav = tester.getRect(find.byType(MileafNavBar));
    // The navigation's animated material owns its full surface inset inside
    // the scaffold slot. Measure the child box against the inner content.
    expect(material.left, 16);
    expect(material.right, 344);
    expect(material.width, 328);
    expect(nav.bottom, 800);
    expect(material.bottom, nav.bottom - 24 - 8);
    expect(find.byKey(const ValueKey('nav-selection')), findsOneWidget);
  });

  testWidgets('R03 resolves 44pt on iOS and 48dp on Android', (tester) async {
    Future<double> resolve(TargetPlatform platform) async {
      late double value;
      await tester.pumpWidget(
        MaterialApp(
          key: ValueKey(platform),
          theme: mileafTheme(Brightness.light).copyWith(platform: platform),
          home: Builder(
            builder: (context) {
              value = MileafLayout.touchTarget(context);
              return const SizedBox();
            },
          ),
        ),
      );
      return value;
    }

    expect(await resolve(TargetPlatform.iOS), MileafSpace.touch);
    expect(await resolve(TargetPlatform.android), MileafSpace.touchAndroid);
  });

  testWidgets('M02 selection moves through a measurable middle frame', (
    tester,
  ) async {
    final preferences = DisplayPreferencesController(
      platform: DisplayPreferencesPlatform.android,
    );
    addTearDown(preferences.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: preferences,
        child: MaterialApp(
          theme: mileafTheme(Brightness.light)
              .copyWith(platform: TargetPlatform.iOS),
          home: const Scaffold(bottomNavigationBar: _NavHarness()),
        ),
      ),
    );
    final surface = find.byKey(const ValueKey('nav-selection-surface'));
    final start = tester.getCenter(surface).dx;
    await tester.tap(find.text('行程'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 90));
    final middle = tester.getCenter(surface).dx;
    await tester.pumpAndSettle();
    final end = tester.getCenter(surface).dx;
    expect(middle, greaterThan(start));
    expect(middle, lessThan(end));
  });

  testWidgets(
    'M03 top-bar tint reaches its end state and reduce motion is zero',
    (tester) async {
      final preferences = DisplayPreferencesController(
        platform: DisplayPreferencesPlatform.android,
      );
      addTearDown(preferences.dispose);
      Future<void> pump({required bool solid, bool reduce = false}) async {
        await tester.pumpWidget(
          DisplayPreferencesScope(
            controller: preferences,
            child: MaterialApp(
              theme: mileafTheme(Brightness.light),
              home: MediaQuery(
                data: MediaQueryData(
                  size: const Size(390, 844),
                  disableAnimations: reduce,
                ),
                child: NavigationMaterial(
                  forceSolid: solid,
                  child: const SizedBox(width: 390, height: 56),
                ),
              ),
            ),
          ),
        );
      }

      await pump(solid: true);
      await pump(solid: false);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(BackdropFilter), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 60));
      expect(find.byType(BackdropFilter), findsOneWidget);
      await pump(solid: false, reduce: true);
      expect(
        tester
            .widget<AnimatedContainer>(find.byType(AnimatedContainer))
            .duration,
        Duration.zero,
      );
    },
  );

  testWidgets('M02 supports reverse and three consecutive selections', (
    tester,
  ) async {
    final preferences = DisplayPreferencesController(
      platform: DisplayPreferencesPlatform.android,
    );
    addTearDown(preferences.dispose);
    await tester.pumpWidget(
      DisplayPreferencesScope(
        controller: preferences,
        child: MaterialApp(
          theme: mileafTheme(Brightness.light),
          home: const Scaffold(bottomNavigationBar: _NavHarness()),
        ),
      ),
    );
    final surface = find.byKey(const ValueKey('nav-selection-surface'));
    await tester.tap(find.text('行程'));
    await tester.pump();
    await tester.tap(find.text('统计'));
    await tester.pump(const Duration(milliseconds: 90));
    final mid = tester.getCenter(surface).dx;
    await tester.tap(find.text('概览'));
    await tester.pumpAndSettle();
    final end = tester.getCenter(surface).dx;
    expect(mid, greaterThan(end));
    expect(tester.takeException(), isNull);
  });

  testWidgets('M05 sheet durations collapse under reduce motion', (
    tester,
  ) async {
    double? duration;
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        home: MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: Builder(
            builder: (context) {
              duration = MileafLayout.motion(
                context,
                MileafDurations.sheetIn,
              ).inMicroseconds.toDouble();
              return const SizedBox();
            },
          ),
        ),
      ),
    );
    expect(duration, 0);
  });

  testWidgets('M06 ExpansionTile uses the shared 160ms role', (tester) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    Duration? resolved;
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        home: Builder(
          builder: (context) {
            resolved = MileafLayout.motion(context, MileafDurations.chevron);
            return const SizedBox();
          },
        ),
      ),
    );
    expect(resolved, Duration.zero);
    expect(MileafDurations.chevron, const Duration(milliseconds: 160));
  });

  testWidgets('M01 isolated button press uses the fixed 0.97 target', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: mileafTheme(Brightness.light),
        home: Scaffold(
          body: Center(
            child: MileafButton(label: '确认', onPressed: () {}),
          ),
        ),
      ),
    );
    final gesture = await tester.startGesture(
      tester.getCenter(find.text('确认')),
    );
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, .97);
    await gesture.up();
    await tester.pump();
    expect(tester.widget<AnimatedScale>(find.byType(AnimatedScale)).scale, 1);
  });
}

class _NavHarness extends StatefulWidget {
  const _NavHarness();

  @override
  State<_NavHarness> createState() => _NavHarnessState();
}

class _NavHarnessState extends State<_NavHarness> {
  var index = 0;

  @override
  Widget build(BuildContext context) => MileafNavBar(
    index: index,
    onSelected: (value) => setState(() => index = value),
  );
}
