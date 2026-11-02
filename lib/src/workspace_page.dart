import 'package:flutter/material.dart';

import 'appearance.dart';
import 'design/components/icon_button.dart';
import 'design/components/nav_bar.dart';
import 'design/components/top_bar.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'session.dart';
import 'charging_page.dart';
import 'charging_detail.dart';
import 'currency.dart';
import 'session_pages.dart';
import 'overview_page.dart';
import 'connection_management.dart';
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
  final chargingFilter = ChargingFilter();
  int tab = 0;
  int statisticsKind = 0;
  int statisticsEntry = 0;
  String? statisticsTopic;
  StatisticsSelection statisticsSelection = const StatisticsSelection();
  bool started = false;
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
    workspace.dispose();
    currency.dispose();
    super.dispose();
  }

  Future<void> openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ConnectionManagementPage(
          session: widget.session,
          appearance: widget.appearance,
          onCurrency: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => CurrencyPage(settings: currency),
            ),
          ),
          onServiceInformation: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) =>
                  MetaPage(workspace: workspace, mapConsent: widget.mapConsent),
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
    final id = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _VehicleSheet(
        session: widget.session,
        selectedId: workspace.selectedId,
      ),
    );
    if (id != null && mounted && id != workspace.selectedId) {
      workspace.select(id);
    }
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
        return VehiclePage(session: widget.session);
      }
      final selected = workspace.selectedId;
      if (selected == null) {
        return const Scaffold(body: Center(child: CircularProgressIndicator()));
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
      Widget topBar({bool onHero = false}) => MileafTopBar(
        vehicleName: vehicleName(vehicle),
        onVehicle: openVehicleSheet,
        onSettings: openSettings,
        onHero: onHero,
      );
      final page = switch (tab) {
        0 => OverviewPage(
          key: ValueKey('$selected:${workspace.revision}'),
          workspace: workspace,
          currency: currency,
          // The brand row rides the hero only while the hero is full bleed;
          // once it is a card the row stays on paper (Spec §6.4).
          topBar: topBar(onHero: !context.colors.heroAsCard),
          onStatistics: (kind, selection) => setState(() {
            statisticsTopic = null;
            statisticsKind = kind == 'charging' ? 1 : 0;
            statisticsSelection = selection;
            tab = 3;
          }),
          onInsight: (topic, selection) => setState(() {
            statisticsKind = 0;
            statisticsTopic = topic;
            statisticsSelection = selection;
            tab = 3;
          }),
          onRecord: record,
        ),
        1 => DrivesPage(
          key: ValueKey('drives:$selected'),
          workspace: workspace,
          topBar: topBar(),
          onRecord: (id) => record('drive', id),
        ),
        2 => ChargingPage(
          key: ValueKey('charge:$selected'),
          workspace: workspace,
          currency: currency,
          filter: chargingFilter,
          topBar: topBar(),
          onRecord: record,
        ),
        3 => StatisticsPage(
          onDrive: (id) => record('drive', id),
          initialKind: statisticsKind,
          initialTopic: statisticsTopic,
          initialSelection: statisticsSelection,
          currency: currency,
          topBar: topBar(),
          key: ValueKey('statistics:$selected:$statisticsEntry'),
          workspace: workspace,
        ),
        _ => Center(child: Text('${['概览', '行程', '充电', '统计'][tab]}功能尚未交付')),
      };
      return Scaffold(
        body: Column(
          children: [
            if (workspace.notice != null)
              _NoticeBanner(text: workspace.notice!),
            Expanded(child: page),
          ],
        ),
        bottomNavigationBar: MileafNavBar(
          index: tab,
          onSelected: (index) => setState(() {
            if (index == 3) {
              statisticsEntry++;
              statisticsKind = 0;
              statisticsTopic = null;
              statisticsSelection = const StatisticsSelection();
            }
            tab = index;
          }),
        ),
      );
    },
  );
}

class _NoticeBanner extends StatelessWidget {
  const _NoticeBanner({required this.text});
  final String text;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      width: double.infinity,
      color: colors.surface,
      padding: EdgeInsets.fromLTRB(
        MileafLayout.pageInset(context),
        MileafSpace.s12,
        MileafLayout.pageInset(context),
        MileafSpace.s12,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MileafIcon(
            MileafIconName.info,
            size: MileafIconMetrics.inline,
            color: colors.warning,
          ),
          const SizedBox(width: MileafSpace.s8),
          Expanded(
            child: Semantics(
              liveRegion: true,
              child: Text(
                text,
                style: context.type.body.copyWith(color: colors.textMuted),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _VehicleSheet extends StatelessWidget {
  const _VehicleSheet({required this.session, required this.selectedId});
  final SessionController session;
  final int? selectedId;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final type = context.type;
    return SafeArea(
      child: ListenableBuilder(
        listenable: session,
        builder: (context, _) => Padding(
          padding: EdgeInsets.fromLTRB(
            MileafLayout.pageInset(context),
            MileafSpace.s12,
            MileafLayout.pageInset(context),
            MileafSpace.s24,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 36,
                  height: 4,
                  decoration: BoxDecoration(
                    color: colors.lineStrong,
                    borderRadius: MileafRadius.fullAll,
                  ),
                ),
              ),
              const SizedBox(height: MileafSpace.s8),
              Row(
                children: [
                  Expanded(child: Text('选择车辆', style: type.title)),
                  MileafIconButton(
                    icon: MileafIconName.refresh,
                    tooltip: '刷新车辆',
                    color: session.loading ? null : colors.textMuted,
                    onPressed: session.loading
                        ? null
                        : () {
                            Navigator.pop(context);
                            session.loadVehicles();
                          },
                  ),
                ],
              ),
              if (session.loading)
                Padding(
                  padding: const EdgeInsets.only(bottom: MileafSpace.s8),
                  child: MileafProgressLine(),
                ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final vehicle in session.vehicles)
                      Semantics(
                        button: true,
                        selected: vehicle.id == selectedId,
                        label: vehicleName(vehicle),
                        child: InkWell(
                          onTap: () => Navigator.pop(context, vehicle.id),
                          highlightColor: colors.accentSoft,
                          child: ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: MileafSpace.rowMin,
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Text(
                                        vehicleName(vehicle),
                                        style: type.body.copyWith(
                                          color: vehicle.id == selectedId
                                              ? colors.accentStrong
                                              : colors.text,
                                          fontWeight: vehicle.id == selectedId
                                              ? MileafType.weightSemiBold
                                              : MileafType.weightRegular,
                                        ),
                                      ),
                                      const SizedBox(
                                        height: MileafSpace.inline2,
                                      ),
                                      Text(
                                        '车辆 ID ${vehicle.id}',
                                        style: type.micro,
                                      ),
                                    ],
                                  ),
                                ),
                                if (vehicle.id == selectedId)
                                  MileafIcon(
                                    MileafIconName.check,
                                    size: MileafIconMetrics.nav,
                                    color: colors.accent,
                                  ),
                              ],
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
