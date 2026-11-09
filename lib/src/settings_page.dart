import 'package:flutter/material.dart';

import 'appearance.dart';
import 'appearance_sheet.dart';
import 'connection_management.dart';
import 'currency.dart';
import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'map/map_consent.dart';
import 'map/map_key.dart';
import 'map/map_panel.dart' show defaultMapPlatform;
import 'map/map_platform.dart';
import 'map/map_privacy_page.dart';
import 'session.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({
    super.key,
    required this.session,
    required this.currency,
    required this.onServiceInformation,
    this.appearance,
    this.mapConsent,
    this.mapPlatform,
  });

  final SessionController session;
  final CurrencySettings currency;
  final VoidCallback onServiceInformation;
  final AppearanceController? appearance;
  final MapConsentController? mapConsent;
  final MapPlatform? mapPlatform;

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  late final SiteSession? _owner;
  bool _connectionOpen = false;

  @override
  void initState() {
    super.initState();
    _owner = widget.session.current;
    widget.session.addListener(_sessionChanged);
  }

  void _sessionChanged() {
    if (!_connectionOpen &&
        _owner != null &&
        !widget.session.isCurrent(_owner)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
      });
    }
  }

  Future<void> _openConnection() async {
    // The connection page owns logout completion, including a storage retry.
    _connectionOpen = true;
    await openConnectionManagement(context, widget.session);
    if (!mounted) return;
    _connectionOpen = false;
    _sessionChanged();
  }

  @override
  void dispose() {
    widget.session.removeListener(_sessionChanged);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('设置')),
    body: SafeArea(
      child: MileafContent(
        child: ListView(
          padding: MileafLayout.pagePadding(context, top: MileafSpace.s12),
          children: [
            Semantics(
              header: true,
              child: Text('使用偏好', style: context.type.label),
            ),
            const SizedBox(height: MileafSpace.s8),
            if (widget.mapConsent case final consent?)
              MileafDataRow(
                title: '地图',
                meta: MapKeyScope.maybeOf(context)?.status ?? '配置高德地图 Key',
                icon: MileafIconName.mapPin,
                showChevron: true,
                bottomLine: true,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => MapPrivacyPage(
                      consent: consent,
                      providerName: (widget.mapPlatform ?? defaultMapPlatform())
                          .providerName,
                    ),
                  ),
                ),
              ),
            if (widget.appearance case final appearance?)
              ListenableBuilder(
                listenable: appearance,
                builder: (context, _) => MileafDataRow(
                  title: '外观',
                  meta: appearance.mode.label,
                  icon: MileafIconName.settings,
                  showChevron: true,
                  onTap: () => showAppearanceSheet(context, appearance),
                ),
              ),
            const SizedBox(height: MileafSpace.section),
            Semantics(
              header: true,
              child: Text('当前站点', style: context.type.label),
            ),
            const SizedBox(height: MileafSpace.s8),
            MileafDataRow(
              title: '站点连接',
              meta: widget.currency.site,
              icon: MileafIconName.route,
              showChevron: true,
              bottomLine: true,
              onTap: _openConnection,
            ),
            ListenableBuilder(
              listenable: widget.currency,
              builder: (context, _) => MileafDataRow(
                title: '币种',
                meta: widget.currency.code ?? '未配置',
                icon: MileafIconName.wallet,
                showChevron: true,
                bottomLine: true,
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (_) => CurrencyPage(settings: widget.currency),
                  ),
                ),
              ),
            ),
            MileafDataRow(
              title: '服务信息',
              meta: '版本与兼容性',
              icon: MileafIconName.info,
              showChevron: true,
              onTap: widget.onServiceInformation,
            ),
          ],
        ),
      ),
    ),
  );
}
