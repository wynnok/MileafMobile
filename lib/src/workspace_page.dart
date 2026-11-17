import 'package:flutter/material.dart';

import 'appearance.dart';
import 'reading_scope.dart';
import 'design/components/icon_button.dart';
import 'design/components/data_row.dart';
import 'design/components/sheet.dart';
import 'design/components/nav_bar.dart';
import 'design/components/top_bar.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'session.dart';
import 'charging_page.dart';
import 'charging_detail.dart';
import 'currency.dart';
import 'session_pages.dart';
import 'overview_page.dart';
import 'settings_page.dart';
import 'workspace.dart';
import 'map/map_consent.dart';
import 'map/map_platform.dart';
import 'drives_page.dart';
import 'drive_detail_page.dart';
import 'performance_trace.dart';
import 'statistics_page.dart';
import 'statistics_period.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    super.key,
    required this.session,
    this.preferences,
    this.mapConsent,
    this.mapPlatform,
    this.calendar,
    this.currencyPreferences,
    this.appearance,
  });
  final SessionController session;
  final MapConsentController? mapConsent;
  final MapPlatform? mapPlatform;
  final CurrencyPreferenceStore? currencyPreferences;
  final VehiclePreferenceStore? preferences;
  final Future<CalendarContext> Function()? calendar;
  final AppearanceController? appearance;
  @override
  State<WorkspacePage> createState() => _WorkspacePageState();
}

class _WorkspacePageState extends State<WorkspacePage> {
  late final workspace = VehicleWorkspace(
    widget.session,
    widget.preferences ?? PreferenceVehicleStore(),
    calendar: widget.calendar,
  );
  late final currency = CurrencySettings(
    widget.session.current!.site.uri.toString(),
    widget.currencyPreferences ?? PreferenceCurrencyStore(),
  );
  var chargingFilter = ChargingFilter();
  final pages = <int, Widget>{};
  int? readingVehicle;
  int tab = 0;
  int statisticsKind = 0;
  int statisticsEntry = 0;
  String? statisticsTopic;
  StatisticsSelection statisticsSelection = const StatisticsSelection();
  bool started = false;

  /// 根页滚动位置（每目的地一个，保留各自的阅读位置与外壳状态）。外壳自己
  /// 监听这个值并只重建自己（R26）。
  final chromeScrollByTab = <int, ValueNotifier<double>>{};
  @override
  void initState() {
    super.initState();
    currency.restore().catchError((_) {});
    widget.session.addListener(changed);
    changed();
  }

  void changed() {
    if (!started &&
        !widget.session.loading &&
        widget.session.vehicles.isNotEmpty) {
      started = true;
      workspace.initialize();
    }
  }

  @override
  void dispose() {
    widget.session.removeListener(changed);
    for (final notifier in chromeScrollByTab.values) {
      notifier.dispose();
    }
    workspace.dispose();
    currency.dispose();
    super.dispose();
  }

  ValueNotifier<double> chromeScroll(int tab) =>
      chromeScrollByTab.putIfAbsent(tab, () => ValueNotifier<double>(0));

  Future<void> openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => SettingsPage(
          session: widget.session,
          appearance: widget.appearance,
          currency: currency,
          mapConsent: widget.mapConsent,
          mapPlatform: widget.mapPlatform,
          onServiceInformation: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => MetaPage(workspace: workspace),
            ),
          ),
        ),
      ),
    );
    if (mounted) await workspace.foreground();
  }

  /// Vehicle switching lives here; the only refresh for the vehicle list is
  /// inside this sheet, so no second refresh competes with the page action.
  Future<void> openVehicleSheet() async {
    final id = await showMileafSheet<int>(
      context: context,
      title: '选择车辆',
      builder: (_) => _VehicleSheet(
        session: widget.session,
        selectedId: workspace.selectedId,
      ),
    );
    if (id != null && mounted && id != workspace.selectedId) {
      workspace.select(id);
    }
  }

  /// An explicit drill-down from the overview. The entry's target and period
  /// win over whatever the statistics entry retained; no other main entry's
  /// period follows this jump.
  void openStatistics({
    int kind = 0,
    String? topic,
    StatisticsSelection selection = const StatisticsSelection(),
  }) {
    setState(() {
      statisticsEntry++;
      statisticsKind = kind;
      statisticsTopic = topic;
      statisticsSelection = selection;
      chromeScroll(3).value = 0;
      tab = 3;
    });
  }

  void record(String kind, int id) {
    if (kind == 'drive') {
      final performanceTrial = PerformanceTrace.start(
        PerformancePoint.driveClick,
      );
      Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => DriveDetailPage(
            workspace: workspace,
            performanceTrial: performanceTrial,
            id: id,
            mapConsent: widget.mapConsent,
            mapPlatform: widget.mapPlatform,
            onReturnToList: () => setState(() => tab = 1),
          ),
        ),
      );
      return;
    }
    openChargingDetail(
      context,
      workspace,
      currency,
      id,
      mapConsent: widget.mapConsent,
      mapPlatform: widget.mapPlatform,
    );
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: workspace,
    builder: (context, _) {
      if (widget.session.vehicles.isEmpty) {
        return VehiclePage(session: widget.session, onSettings: openSettings);
      }
      final selected = workspace.selectedId;
      if (selected == null) {
        return Scaffold(
          body: Center(
            child: MediaQuery.disableAnimationsOf(context)
                ? const Text('正在加载车辆…')
                : const CircularProgressIndicator(),
          ),
        );
      }
      final vehicle = widget.session.vehicles
          .where((v) => v.id == selected)
          .firstOrNull;
      if (vehicle == null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            workspace.select(
              widget.session.vehicles.first.id,
              notice: '所选车辆已不可用，已重新选择',
            );
          }
        });
        return const Scaffold(body: Center(child: Text('正在恢复车辆选择')));
      }
      final modalCovered = !(ModalRoute.of(context)?.isCurrent ?? true);
      Widget topBar(String title) => MileafTopBar(
        title: title,
        vehicleName: vehicleName(vehicle),
        onVehicle: openVehicleSheet,
        onSettings: openSettings,
        forceSolid: modalCovered,
        scrollListenable: chromeScroll(tab),
      );
      if (readingVehicle != selected) {
        readingVehicle = selected;
        pages.clear();
        chargingFilter = ChargingFilter();
        statisticsKind = 0;
        statisticsTopic = null;
        statisticsSelection = const StatisticsSelection();
        for (final notifier in chromeScrollByTab.values) {
          notifier.dispose();
        }
        chromeScrollByTab.clear();
      }
      final page = switch (tab) {
        0 => OverviewPage(
          key: ValueKey('overview:$selected'),
          workspace: workspace,
          currency: currency,
          onStatistics: (kind, selection) => openStatistics(
            kind: kind == 'charging' ? 1 : 0,
            selection: selection,
          ),
          onInsight: (topic, selection) =>
              openStatistics(topic: topic, selection: selection),
          onRecord: record,
        ),
        1 => DrivesPage(
          key: ValueKey('drives:$selected'),
          workspace: workspace,
          onRecord: (id) => record('drive', id),
        ),
        2 => ChargingPage(
          key: ValueKey('charge:$selected'),
          workspace: workspace,
          currency: currency,
          filter: chargingFilter,
          onRecord: record,
        ),
        3 => StatisticsPage(
          onDrive: (id) => record('drive', id),
          initialKind: statisticsKind,
          initialTopic: statisticsTopic,
          initialSelection: statisticsSelection,
          currency: currency,
          key: ValueKey('statistics:$selected:$statisticsEntry'),
          workspace: workspace,
        ),
        _ => Center(child: Text('${['概览', '行程', '充电', '统计'][tab]}功能尚未交付')),
      };
      pages[tab] = page;
      final title = const ['概览', '行程', '充电', '统计'][tab];
      final keyboardOpen = MediaQuery.viewInsetsOf(context).bottom > 0;
      return Scaffold(
        extendBody: true,
        body: RootNavigationScope(
          child: Stack(
            fit: StackFit.expand,
            children: [
              NotificationListener<ScrollNotification>(
                onNotification: (notification) {
                  if (notification.depth != 0) return false;
                  // 只更新外壳的滚动值：外壳自己重建，页面与工作区不重建。
                  final notifier = chromeScroll(tab);
                  if (notifier.value != notification.metrics.pixels) {
                    notifier.value = notification.metrics.pixels;
                  }
                  return false;
                },
                child: IndexedStack(
                  index: tab,
                  children: [
                    for (var index = 0; index < 4; index++)
                      ReadingScope(
                        key: ValueKey('$selected:$index'),
                        active: index == tab,
                        child: TickerMode(
                          enabled: index == tab,
                          child: pages[index] ?? const SizedBox.shrink(),
                        ),
                      ),
                  ],
                ),
              ),
              Align(
                alignment: Alignment.topCenter,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    topBar(title),
                    MileafNoticeBanner(text: workspace.notice),
                  ],
                ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: keyboardOpen
            ? null
            : TickerMode(
                enabled: !modalCovered,
                child: MileafNavBar(
                  index: tab,
                  forceSolid: modalCovered,
                  onSelected: (index) {
                    if (index != tab) setState(() => tab = index);
                  },
                ),
              ),
      );
    },
  );
}

class _VehicleSheet extends StatelessWidget {
  const _VehicleSheet({required this.session, required this.selectedId});
  final SessionController session;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: session,
      builder: (context, _) => Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerRight,
            child: MileafIconButton(
              icon: MileafIconName.refresh,
              tooltip: '刷新车辆',
              onPressed: session.loading
                  ? null
                  : () {
                      Navigator.pop(context);
                      session.loadVehicles();
                    },
            ),
          ),
          if (session.loading) const MileafProgressLine(),
          for (final vehicle in session.vehicles)
            MileafDataRow(
              title: vehicleName(vehicle),
              meta: '车辆 ID ${vehicle.id}',
              selected: vehicle.id == selectedId,
              badge: vehicle.id == selectedId
                  ? MileafIcon(
                      MileafIconName.check,
                      size: MileafIconMetrics.nav,
                      color: context.colors.accentStrong,
                    )
                  : null,
              onTap: () => Navigator.pop(context, vehicle.id),
            ),
        ],
      ),
    );
  }
}
