import 'package:flutter/material.dart';

import 'appearance.dart';
import 'appearance_sheet.dart';
import 'connection_management.dart';
import 'currency.dart';
import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
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
    appBar: mileafPageBar(context, title: const Text('设置')),
    body: SafeArea(
      child: MileafContent(
        child: ListView(
          padding: MileafLayout.pagePadding(context, top: MileafSpace.s12),
          children: [
            // R24 两条起始线：分组标题与分组脚注对齐卡片内边距（页面 + 16）。
            const MileafGroupHeader(
              title: '使用偏好',
              inset: MileafSpace.cardPad,
            ),
            const SizedBox(height: MileafSpace.s8),
            MileafGroupCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (widget.mapConsent case final consent?)
                    MileafGroupRow(
                      title: '地图',
                      value: _stacked
                          ? null
                          : MapKeyScope.maybeOf(context)?.status ?? '未配置',
                      meta: _stacked
                          ? MapKeyScope.maybeOf(context)?.status ?? '未配置'
                          : null,
                      leading: MileafIconName.mapPin,
                      trailing: _chevron(context),
                      bottomLine: widget.appearance != null,
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) => MapPrivacyPage(
                            consent: consent,
                            providerName:
                                (widget.mapPlatform ?? defaultMapPlatform())
                                    .providerName,
                          ),
                        ),
                      ),
                    ),
                  if (widget.appearance case final appearance?)
                    ListenableBuilder(
                      listenable: appearance,
                      builder: (context, _) => MileafGroupRow(
                        title: '外观',
                        value: _stacked ? null : appearance.mode.label,
                        meta: _stacked ? appearance.mode.label : null,
                        leading: MileafIconName.settings,
                        trailing: _chevron(context),
                        onTap: () => showAppearanceSheet(context, appearance),
                      ),
                    ),
                ],
              ),
            ),
            if (widget.mapConsent != null)
              Padding(
                // R24 两条起始线：分组脚注对齐卡片内边距。
                padding: const EdgeInsets.only(
                  left: MileafSpace.cardPad,
                  top: MileafSpace.s8,
                ),
                child: Text(
                  '未配置地图时显示路线示意。',
                  style: context.type.footnote.copyWith(
                    color: context.colors.textSecondary,
                  ),
                ),
              ),
            const SizedBox(height: MileafSpace.section),
            const MileafGroupHeader(
              title: '当前站点',
              inset: MileafSpace.cardPad,
            ),
            const SizedBox(height: MileafSpace.s8),
            MileafGroupCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MileafGroupRow(
                    title: '站点连接',
                    // P12：行尾显示主机名，完整地址在站点连接页。
                    value: _stacked ? null : _host,
                    meta: _stacked ? _host : null,
                    leading: MileafIconName.route,
                    trailing: _chevron(context),
                    bottomLine: true,
                    onTap: _openConnection,
                  ),
                  ListenableBuilder(
                    listenable: widget.currency,
                    builder: (context, _) => MileafGroupRow(
                      title: '币种',
                      value: _stacked ? null : widget.currency.code ?? '未设置',
                      meta: _stacked ? widget.currency.code ?? '未设置' : null,
                      leading: MileafIconName.wallet,
                      trailing: _chevron(context),
                      bottomLine: true,
                      onTap: () => Navigator.of(context).push<void>(
                        MaterialPageRoute(
                          builder: (_) =>
                              CurrencyPage(settings: widget.currency),
                        ),
                      ),
                    ),
                  ),
                  MileafGroupRow(
                    title: '服务信息',
                    leading: MileafIconName.info,
                    trailing: _chevron(context),
                    onTap: widget.onServiceInformation,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  );

  /// P12 的设置行在 100% 字号下是单行 52（尾部当前值）；R11 要求大字重排，
  /// 200% 时当前值改到标题下的第二行，避免尾部值与标题抢同一行宽。
  bool get _stacked => MileafLayout.largeText(context);

  String get _host {
    final uri = Uri.tryParse(widget.currency.site);
    final host = uri?.host ?? '';
    return host.isEmpty ? widget.currency.site : host;
  }

  Widget _chevron(BuildContext context) => MileafIcon(
    MileafIconName.chevron,
    size: MileafIconMetrics.nav,
    color: context.colors.textFaint,
  );
}
