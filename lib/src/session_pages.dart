import 'package:flutter/material.dart';

import 'design/brand_mark.dart';
import 'design/components/components.dart';
import 'design/icons.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'session.dart';
import 'setup_page.dart';
import 'connection_page.dart';

/// P13：任务标题常量同时供导航栏与正文 title2 使用。
const _loginTitle = '登录行笺';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key, required this.session});
  final SessionController session;
  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _password = TextEditingController();
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  void _login() {
    final value = _password.text;
    _password.clear();
    if (value.isNotEmpty) widget.session.login(value);
  }

  @override
  Widget build(BuildContext context) {
    final session = widget.session;
    return Scaffold(
      appBar: mileafPageBar(context, title: const Text(_loginTitle)),
      body: SafeArea(
        child: MileafContent(
          child: SingleChildScrollView(
            padding: EdgeInsets.all(MileafLayout.pageInset(context)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Align(
                  alignment: Alignment.centerLeft,
                  child: MileafWordmark(markSize: 32),
                ),
                const SizedBox(height: MileafSpace.s16),
                // P13：任务标题 title2。
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_loginTitle, style: context.type.title2),
                ),
                const SizedBox(height: MileafSpace.s8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    session.site!.uri.toString(),
                    style: context.type.subheadline.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: MileafSpace.s4),
                Align(
                  alignment: Alignment.centerLeft,
                  child: MileafButton(
                    label: '编辑服务地址',
                    kind: MileafButtonKind.ghost,
                    onPressed: session.loading
                        ? null
                        : () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (routeContext) => ConnectionPage(
                                api: session.api,
                                initialAddress: session.site!.uri.toString(),
                                onConnected: (address) {
                                  session.useSite(address);
                                  Navigator.of(routeContext).pop();
                                },
                              ),
                            ),
                          ),
                  ),
                ),
                const SizedBox(height: MileafSpace.s24),
                TextFormField(
                  controller: _password,
                  obscureText: true,
                  enableSuggestions: false,
                  autocorrect: false,
                  enabled: !session.loading,
                  decoration: const InputDecoration(labelText: '站点访问口令'),
                  onFieldSubmitted: (_) {
                    if (session.canLogin) _login();
                  },
                ),
                const SizedBox(height: MileafSpace.s24),
                // R27：主按钮胶囊；处理中保留文字并在尾部加活动指示器。
                MileafButton(
                  label: '登录',
                  expand: true,
                  loading: session.loading,
                  onPressed: session.canLogin ? _login : null,
                ),
                const SizedBox(height: MileafSpace.s8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: MileafButton(
                    label: '首次设置站点口令',
                    kind: MileafButtonKind.ghost,
                    onPressed: session.canLogin
                        ? () => Navigator.of(context).push<void>(
                            MaterialPageRoute(
                              builder: (_) => SetupPage(session: session),
                            ),
                          )
                        : null,
                  ),
                ),
                if (session.retryAfter != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '服务要求等待后再试；不会自动重试。',
                      style: context.type.footnote.copyWith(
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ),
                if (session.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: MileafSpace.s16),
                    child: Semantics(
                      liveRegion: true,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          session.message!,
                          style: context.type.body.copyWith(
                            color: context.colors.error,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class VehiclePage extends StatelessWidget {
  const VehiclePage({
    super.key,
    required this.session,
    required this.onSettings,
  });
  final SessionController session;
  final VoidCallback onSettings;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: mileafPageBar(
        context,
        title: const Text('站点车辆'),
        actions: [
          MileafIconButton(
            tooltip: '设置',
            icon: MileafIconName.settings,
            onPressed: onSettings,
          ),
          MileafIconButton(
            tooltip: '刷新车辆',
            icon: MileafIconName.refresh,
            onPressed: session.loading ? null : session.loadVehicles,
          ),
        ],
      ),
      body: SafeArea(
        child: MileafContent(
          child: ListView(
            padding: EdgeInsets.all(MileafLayout.pageInset(context)),
            children: [
              if (session.loading) const MileafProgressLine(),
              if (session.message != null) ...[
                Semantics(liveRegion: true, child: Text(session.message!)),
                Align(
                  alignment: Alignment.centerLeft,
                  child: MileafButton(
                    label: '重试车辆读取',
                    // CL14：重试与刷新是同一动作，同一 refresh 字形（不换图标）。
                    icon: MileafActionIcon.retry,
                    kind: MileafButtonKind.ghost,
                    onPressed: session.loading ? null : session.loadVehicles,
                  ),
                ),
              ],
              if (!session.loading &&
                  session.message == null &&
                  session.vehicles.isEmpty)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '此站点暂无车辆，请检查 TeslaMate 的车辆记录后刷新。',
                    style: context.type.body.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
              if (session.vehicles.isNotEmpty)
                MileafGroupCard(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (index, vehicle) in session.vehicles.indexed)
                        MileafGroupRow(
                          // CL12/CL13：车辆行身份图标 car，与车辆弹层同一字形；
                          // 设置/连接保持中性（映射表 #9 不迁移七彩索引色）。
                          leading: MileafIconName.car,
                          title: vehicleName(vehicle),
                          // 名称缺失时标题回退已携带区分信息，副文置空避免重复。
                          meta: (vehicle.name?.trim().isNotEmpty ?? false)
                              ? vehicleDistinction(vehicle)
                              : null,
                          bottomLine: index != session.vehicles.length - 1,
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
