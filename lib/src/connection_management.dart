import 'package:flutter/material.dart';

import 'api.dart';
import 'session.dart';

/// Business shells reuse this entry point; route owns candidate-only state.
Future<void> openConnectionManagement(
  BuildContext context,
  SessionController session,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(builder: (_) => ConnectionManagementPage(session: session)),
);

class ConnectionManagementPage extends StatefulWidget {
  const ConnectionManagementPage({
    super.key,
    required this.session,
    this.onServiceInformation,
    this.onCurrency,
  });
  final VoidCallback? onServiceInformation;
  final VoidCallback? onCurrency;
  final SessionController session;
  @override
  State<ConnectionManagementPage> createState() =>
      _ConnectionManagementPageState();
}

class _ConnectionManagementPageState extends State<ConnectionManagementPage> {
  late final _address = TextEditingController(
    text: widget.session.site!.uri.toString(),
  );
  final _password = TextEditingController();
  bool _busy = false;
  bool _trust = false;
  String? _message;
  @override
  void dispose() {
    _address.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _replace() async {
    final password = _password.text;
    _password.clear();
    if (password.isEmpty) {
      setState(() => _message = '请输入站点访问口令');
      return;
    }
    setState(() {
      _busy = true;
      _message = null;
    });
    String? failure;
    try {
      final address = SiteAddress.parse(_address.text);
      if (address.uri.scheme == 'http' && _trust) {
        await widget.session.api.trustStore.setTrusted(address, true);
      }
      failure = await widget.session.replaceConnection(address, password);
    } on FormatException catch (error) {
      failure = error.message;
    } on Exception {
      failure = '无法保存站点授权，请检查设备存储后重试';
    }
    if (!mounted) return;
    if (failure == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = false;
      _message = failure;
    });
  }

  Future<void> _logout() async {
    setState(() {
      _busy = true;
      _message = null;
    });
    final failure = await widget.session.logout();
    if (!mounted) return;
    if (failure == null) {
      Navigator.pop(context);
      return;
    }
    setState(() {
      _busy = false;
      _message = failure;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('连接与本地访问')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('当前服务：${widget.session.site!.uri}'),
            const Text('验证新连接和车辆成功后才替换；失败时保留当前连接。'),
            if (widget.onServiceInformation != null)
              TextButton(
                onPressed: widget.onServiceInformation,
                child: const Text('服务版本与兼容性'),
              ),
            if (widget.onCurrency != null)
              TextButton(
                onPressed: widget.onCurrency,
                child: const Text('站点币种'),
              ),
            const SizedBox(height: 24),
            TextFormField(
              controller: _address,
              enabled: !_busy,
              keyboardType: TextInputType.url,
              autocorrect: false,
              decoration: const InputDecoration(labelText: '服务根地址'),
              onChanged: (_) => setState(() => _trust = false),
            ),
            TextFormField(
              controller: _password,
              enabled: !_busy,
              obscureText: true,
              autocorrect: false,
              enableSuggestions: false,
              decoration: const InputDecoration(labelText: '站点访问口令'),
            ),
            if (_address.text.trim().startsWith('http:'))
              CheckboxListTile(
                value: _trust,
                onChanged: _busy
                    ? null
                    : (value) => setState(() => _trust = value ?? false),
                title: const Text('此确切站点使用可信私网或 VPN；HTTP 会明文传输凭据'),
              ),
            FilledButton(
              onPressed: _busy ? null : _replace,
              child: Text(_busy ? '正在验证…' : '验证并替换连接'),
            ),
            TextButton(
              onPressed: _busy
                  ? null
                  : () {
                      _password.clear();
                      setState(() {
                        _address.text = widget.session.site!.uri.toString();
                        _trust = false;
                        _message = '输入口令以重新登录当前站点';
                      });
                    },
              child: const Text('重新登录当前站点'),
            ),
            const SizedBox(height: 24),
            const Text('退出此设备仅清除本机访问；不会撤销其他设备或服务端 token。保留地址供重新连接。'),
            OutlinedButton(
              onPressed: _busy ? null : _logout,
              child: const Text('退出此设备'),
            ),
            if (_message != null)
              Semantics(liveRegion: true, child: Text(_message!)),
          ],
        ),
      ),
    ),
  );
}
