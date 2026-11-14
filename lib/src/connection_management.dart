import 'package:flutter/material.dart';


import 'api.dart';
import 'design/components/components.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';
import 'session.dart';

/// Business shells reuse this entry point; route owns candidate-only state.
Future<void> openConnectionManagement(
  BuildContext context,
  SessionController session,
) => Navigator.of(context).push<void>(
  MaterialPageRoute(builder: (_) => ConnectionManagementPage(session: session)),
);

class ConnectionManagementPage extends StatefulWidget {
  const ConnectionManagementPage({super.key, required this.session});
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
  bool _editing = false;
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
      Navigator.of(context).popUntil((route) => route.isFirst);
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
      Navigator.of(context).popUntil((route) => route.isFirst);
      return;
    }
    setState(() {
      _busy = false;
      _message = failure;
    });
  }

  void _edit() {
    _password.clear();
    setState(() {
      _address.text = widget.session.site!.uri.toString();
      _trust = false;
      _message = null;
      _editing = true;
    });
  }

  void _cancelEdit() {
    FocusScope.of(context).unfocus();
    _password.clear();
    setState(() {
      _address.text = widget.session.site!.uri.toString();
      _trust = false;
      _message = null;
      _editing = false;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: mileafPageBar(context, title: const Text('站点连接')),
    body: SafeArea(
      child: MileafContent(
        child: SingleChildScrollView(
          padding: MileafLayout.pagePadding(context, top: MileafSpace.s12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('当前连接', style: context.type.label),
              const SizedBox(height: MileafSpace.s8),
              Text(
                widget.session.site!.uri.toString(),
                style: context.type.body,
              ),
              const SizedBox(height: MileafSpace.s12),
              Text(
                '车辆与用车记录来自此站点。',
                style: context.type.body.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
              const SizedBox(height: MileafSpace.section),
              if (!_editing) ...[
                MileafDataRow(
                  title: '更换连接',
                  meta: '连接另一个 Mileaf 站点',
                  showChevron: true,
                  topLine: true,
                  bottomLine: true,
                  enabled: !_busy,
                  onTap: _edit,
                ),
                MileafDataRow(
                  title: '重新登录当前站点',
                  meta: '使用站点口令更新本机访问',
                  showChevron: true,
                  bottomLine: true,
                  enabled: !_busy,
                  onTap: _edit,
                ),
              ] else ...[
                const SectionHeader(title: '编辑连接'),
                const SizedBox(height: MileafSpace.s8),
                Text(
                  '验证新连接和车辆成功后才替换；失败时保留当前连接。',
                  style: context.type.body.copyWith(
                    color: context.colors.textMuted,
                  ),
                ),
                const SizedBox(height: MileafSpace.s16),
                TextFormField(
                  controller: _address,
                  enabled: !_busy,
                  style: context.type.body,
                  keyboardType: TextInputType.url,
                  textInputAction: TextInputAction.next,
                  autocorrect: false,
                  decoration: const InputDecoration(labelText: '服务根地址'),
                  onChanged: (_) => setState(() => _trust = false),
                ),
                const SizedBox(height: MileafSpace.s16),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  style: context.type.body,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: const InputDecoration(labelText: '站点访问口令'),
                ),
                if (_address.text.trim().startsWith('http:')) ...[
                  const SizedBox(height: MileafSpace.s12),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                    value: _trust,
                    onChanged: _busy
                        ? null
                        : (value) => setState(() => _trust = value ?? false),
                    title: Text(
                      '此确切站点使用可信私网或 VPN；HTTP 会明文传输凭据',
                      style: context.type.body,
                    ),
                  ),
                ],
                const SizedBox(height: MileafSpace.s16),
                FilledButton(
                  onPressed: _busy ? null : _replace,
                  child: Text(_busy ? '正在验证…' : '验证并替换连接'),
                ),
                if (_message != null) ...[
                  const SizedBox(height: MileafSpace.s8),
                  _feedback(context),
                ],
                const SizedBox(height: MileafSpace.s4),
                TextButton(
                  onPressed: _busy ? null : _cancelEdit,
                  child: const Text('取消编辑'),
                ),
              ],
              const SizedBox(height: MileafSpace.s32),
              Text('本机访问', style: context.type.label),
              const SizedBox(height: MileafSpace.s8),
              Text(
                '退出后清除本机访问授权，保留站点地址以便重新连接。其他设备的登录状态不受影响。',
                style: context.type.body.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
              const SizedBox(height: MileafSpace.s16),
              OutlinedButton(
                onPressed: _busy ? null : _logout,
                child: const Text('退出此设备'),
              ),
              if (!_editing && _message != null) ...[
                const SizedBox(height: MileafSpace.s8),
                _feedback(context),
              ],
            ],
          ),
        ),
      ),
    ),
  );

  Widget _feedback(BuildContext context) => Semantics(
    liveRegion: true,
    child: Text(
      _message!,
      style: context.type.body.copyWith(color: context.colors.error),
    ),
  );
}
