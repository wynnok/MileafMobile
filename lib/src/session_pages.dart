import 'package:flutter/material.dart';


import 'design/brand_mark.dart';
import 'design/components/components.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'session.dart';
import 'setup_page.dart';
import 'connection_page.dart';

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
      appBar: mileafPageBar(context, title: const Text('登录行笺')),
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
                const SizedBox(height: MileafSpace.s24),
                Text(
                  session.site!.uri.toString(),
                  style: context.type.label.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                TextButton(
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
                  child: const Text('编辑服务地址'),
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
                FilledButton(
                  onPressed: session.canLogin ? _login : null,
                  child: Text(session.loading ? '正在登录…' : '登录'),
                ),
                TextButton(
                  onPressed: session.canLogin
                      ? () => Navigator.of(context).push<void>(
                          MaterialPageRoute(
                            builder: (_) => SetupPage(session: session),
                          ),
                        )
                      : null,
                  child: const Text('首次设置站点口令'),
                ),
                if (session.message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        session.message!,
                        style: context.type.body.copyWith(
                          color: context.colors.error,
                        ),
                      ),
                    ),
                  ),
                if (session.retryAfter != null) const Text('服务要求等待后再试；不会自动重试。'),
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
  Widget build(BuildContext context) => Scaffold(
    appBar: mileafPageBar(
      context,
      title: const Text('站点车辆'),
      actions: [
        IconButton(
          tooltip: '设置',
          icon: const Icon(Icons.settings),
          onPressed: onSettings,
        ),
        IconButton(
          onPressed: session.loading ? null : session.loadVehicles,
          icon: const Icon(Icons.refresh),
          tooltip: '刷新车辆',
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
              TextButton(
                onPressed: session.loading ? null : session.loadVehicles,
                child: const Text('重试车辆读取'),
              ),
            ],
            if (!session.loading &&
                session.message == null &&
                session.vehicles.isEmpty)
              const Text('此站点暂无车辆，请检查 TeslaMate 的车辆记录后刷新。'),
            for (final vehicle in session.vehicles)
              MileafDataRow(
                title: vehicleName(vehicle),
                meta: '车辆 ID ${vehicle.id}',
                topLine: true,
                bottomLine: true,
              ),
          ],
        ),
      ),
    ),
  );
}
