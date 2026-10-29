import 'package:flutter/material.dart';

import 'session.dart';
import 'charging_page.dart';
import 'charging_detail.dart';
import 'currency.dart';
import 'session_pages.dart';
import 'overview_page.dart';
import 'connection_management.dart';
import 'workspace.dart';
import 'map_candidate.dart';
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
    this.mapConfiguration,
    this.calendar,
    this.currencyPreferences,
  });
  final SessionController session;
  final MapConfiguration? mapConfiguration;
  final CurrencyPreferenceStore? currencyPreferences;
  final VehiclePreferenceStore? preferences;
  final Future<CalendarContext> Function()? calendar;
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
          onCurrency: () => Navigator.push(
            context,
            MaterialPageRoute<void>(
              builder: (_) => CurrencyPage(settings: currency),
            ),
          ),
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
            mapConfiguration: widget.mapConfiguration,
            onReturnToList: () => setState(() => tab = 1),
          ),
        ),
      );
      return;
    }
    openChargingDetail(context, workspace, currency, id);
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
      return Scaffold(
        appBar: AppBar(
          title: Row(
            children: [
              const Icon(Icons.spa_outlined, size: 21),
              const SizedBox(width: 7),
              Text(
                '行笺',
                style: Theme.of(context).textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.w700),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: TextButton(
                  onPressed: () async {
                    final id = await showModalBottomSheet<int>(
                      context: context,
                      builder: (context) => SafeArea(
                        child: ListView(
                          shrinkWrap: true,
                          children: [
                            for (final v in widget.session.vehicles)
                              ListTile(
                                title: Text(vehicleName(v)),
                                subtitle: Text('车辆 ID ${v.id}'),
                                selected: v.id == selected,
                                onTap: () => Navigator.pop(context, v.id),
                              ),
                          ],
                        ),
                      ),
                    );
                    if (id != null && mounted) workspace.select(id);
                  },
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          vehicleName(vehicle),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      const Icon(Icons.keyboard_arrow_down, size: 17),
                    ],
                  ),
                ),
              ),
            ],
          ),
          actions: [
            IconButton(
              onPressed: widget.session.loading
                  ? null
                  : widget.session.loadVehicles,
              icon: const Icon(Icons.refresh),
              tooltip: "刷新车辆",
            ),
            if (tab == 0)
              IconButton(
                onPressed: openSettings,
                icon: const Icon(Icons.settings_outlined),
                tooltip: '设置',
              ),
          ],
        ),
        body: SafeArea(
          child: Column(
            children: [
              if (workspace.notice != null) Text(workspace.notice!),
              Expanded(
                child: tab == 0
                    ? OverviewPage(
                        key: ValueKey('$selected:${workspace.revision}'),
                        workspace: workspace,
                        currency: currency,
                        onStatistics: (kind, selection) => setState(() {
                          statisticsKind = kind == 'charging' ? 1 : 0;
                          statisticsSelection = selection;
                          tab = 3;
                        }),
                        onRecord: record,
                      )
                    : tab == 1
                    ? DrivesPage(
                        key: ValueKey('drives:$selected'),
                        workspace: workspace,
                        onRecord: (id) => record('drive', id),
                      )
                    : tab == 2
                    ? ChargingPage(
                        key: ValueKey("charge:$selected"),
                        workspace: workspace,
                        currency: currency,
                        filter: chargingFilter,
                        onRecord: record,
                      )
                    : tab == 3
                    ? StatisticsPage(
                        onDrive: (id) => record('drive', id),
                        initialKind: statisticsKind,
                        initialSelection: statisticsSelection,
                        currency: currency,
                        key: ValueKey('statistics:$selected'),
                        workspace: workspace,
                      )
                    : Center(
                        child: Text('${['概览', '行程', '充电', '统计'][tab]}功能尚未交付'),
                      ),
              ),
            ],
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: tab,
          onDestinationSelected: (index) => setState(() {
            if (index == 3) {
              statisticsKind = 0;
              statisticsSelection = const StatisticsSelection();
            }
            tab = index;
          }),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), label: '概览'),
            NavigationDestination(
              icon: Icon(Icons.directions_car_outlined),
              label: '行程',
            ),
            NavigationDestination(icon: Icon(Icons.bolt_outlined), label: '充电'),
            NavigationDestination(
              icon: Icon(Icons.bar_chart_outlined),
              label: '统计',
            ),
          ],
        ),
      );
    },
  );
}
