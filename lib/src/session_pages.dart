import 'package:flutter/material.dart';

import 'session.dart';

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
      appBar: AppBar(title: const Text('登录行笺')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(session.site!.uri.toString()),
              const SizedBox(height: 24),
              TextFormField(
                controller: _password,
                obscureText: true,
                enableSuggestions: false,
                autocorrect: false,
                enabled: !session.loading,
                decoration: const InputDecoration(
                  labelText: '站点访问口令',
                  border: OutlineInputBorder(),
                ),
                onFieldSubmitted: (_) {
                  if (session.canLogin) _login();
                },
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: session.canLogin ? _login : null,
                child: Text(session.loading ? '正在登录…' : '登录'),
              ),
              if (session.message != null)
                Padding(
                  padding: const EdgeInsets.only(top: 16),
                  child: Semantics(
                    liveRegion: true,
                    child: Text(session.message!),
                  ),
                ),
              if (session.retryAfter != null) const Text('服务要求等待后再试；不会自动重试。'),
            ],
          ),
        ),
      ),
    );
  }
}

class VehiclePage extends StatelessWidget {
  const VehiclePage({super.key, required this.session});
  final SessionController session;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('站点车辆'),
      actions: [
        IconButton(
          onPressed: session.loading ? null : session.loadVehicles,
          icon: const Icon(Icons.refresh),
          tooltip: '刷新车辆',
        ),
      ],
    ),
    body: SafeArea(
      child: ListView(
        padding: const EdgeInsets.all(24),
        children: [
          if (session.loading) const Center(child: CircularProgressIndicator()),
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
            Card(
              child: ListTile(
                title: Text(vehicleName(vehicle)),
                subtitle: Text('车辆 ID ${vehicle.id}'),
              ),
            ),
        ],
      ),
    ),
  );
}
