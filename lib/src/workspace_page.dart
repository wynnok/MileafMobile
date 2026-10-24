import 'package:flutter/material.dart';

import 'session.dart';
import 'session_pages.dart';
import 'overview_page.dart';
import 'connection_management.dart';
import 'workspace.dart';

class WorkspacePage extends StatefulWidget {
  const WorkspacePage({
    super.key,
    required this.session,
    this.preferences,
    this.calendar,
  });
  final SessionController session;
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
  int tab = 0;
  bool started = false;
  @override
  void initState() {
    super.initState();
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
    super.dispose();
  }

  Future<void> openSettings() async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => ConnectionManagementPage(
          session: widget.session,
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
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text('${kind == 'drive' ? '行程' : '充电'} #$id\n详情将在对应功能切片接入。'),
        ),
      ),
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
      return Scaffold(
        appBar: AppBar(
          title: TextButton(
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
            child: Text(
              vehicleName(vehicle),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
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
                        onRecord: record,
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
          onDestinationSelected: (index) => setState(() => tab = index),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.dashboard_outlined),
              label: '概览',
            ),
            NavigationDestination(
              icon: Icon(Icons.route_outlined),
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
