import 'package:flutter/material.dart';

import 'api.dart';
import 'design/components/components.dart';
import 'design/components/icons.dart';
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
              // R24/MG05b：分组标题对齐卡内边距（页面边距 + 16）。
              const MileafGroupHeader(title: '当前连接', inset: MileafSpace.cardPad),
              const SizedBox(height: MileafSpace.s8),
              MileafGroupCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Padding(
                      padding: const EdgeInsets.all(MileafSpace.s16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.session.site!.uri.toString(),
                            style: context.type.body,
                          ),
                          const SizedBox(height: MileafSpace.s4),
                          Text(
                            '车辆与用车记录来自此站点。',
                            style: context.type.footnote.copyWith(
                              color: context.colors.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                    if (!_editing) ...[
                      MileafGroupRow(
                        title: '更换连接',
                        meta: '连接另一个 Mileaf 站点',
                        trailing: _chevron(context),
                        bottomLine: true,
                        enabled: !_busy,
                        onTap: _edit,
                      ),
                      MileafGroupRow(
                        title: '重新登录当前站点',
                        meta: '使用站点口令更新本机访问',
                        trailing: _chevron(context),
                        enabled: !_busy,
                        onTap: _edit,
                      ),
                    ] else
                      ..._editForm(context),
                  ],
                ),
              ),
              if (_editing && _message != null) ...[
                const SizedBox(height: MileafSpace.s8),
                _feedback(context),
              ],
              const SizedBox(height: MileafSpace.section),
              const MileafGroupHeader(title: '本机访问', inset: MileafSpace.cardPad),
              const SizedBox(height: MileafSpace.s8),
              MileafGroupCard(
                child: Padding(
                  padding: const EdgeInsets.all(MileafSpace.s16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // CP12 冻结文案：退出此设备说明逐字保留。
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          '退出后清除本机访问授权，保留站点地址以便重新连接。其他设备的登录状态不受影响。',
                          style: context.type.body.copyWith(
                            color: context.colors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: MileafSpace.s16),
                      MileafButton(
                        label: '退出此设备',
                        kind: MileafButtonKind.secondary,
                        expand: true,
                        onPressed: _busy ? null : _logout,
                      ),
                    ],
                  ),
                ),
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

  /// 编辑态替换「更换连接 / 重新登录当前站点」两个动作行；替换说明为
  /// CP12 冻结文案，只调整排版。
  List<Widget> _editForm(BuildContext context) => [
    Padding(
      padding: const EdgeInsets.all(MileafSpace.s16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              '验证新连接和车辆成功后才替换；失败时保留当前连接。',
              style: context.type.body.copyWith(
                color: context.colors.textSecondary,
              ),
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
                // CP12 冻结文案：HTTP 信任确认逐字保留。
                '此确切站点使用可信私网或 VPN；HTTP 会明文传输凭据',
                style: context.type.body,
              ),
            ),
          ],
          const SizedBox(height: MileafSpace.s16),
          // R27：主按钮胶囊；处理中保留文字并在尾部加活动指示器。
          MileafButton(
            label: '验证并替换连接',
            expand: true,
            loading: _busy,
            onPressed: _busy ? null : _replace,
          ),
          const SizedBox(height: MileafSpace.s4),
          Align(
            alignment: Alignment.centerLeft,
            child: MileafButton(
              label: '取消编辑',
              kind: MileafButtonKind.ghost,
              onPressed: _busy ? null : _cancelEdit,
            ),
          ),
        ],
      ),
    ),
  ];

  Widget _chevron(BuildContext context) => MileafIcon(
    MileafIconName.chevron,
    size: MileafIconMetrics.nav,
    color: context.colors.textFaint,
  );

  /// MG09 三要素：现状句（含原因）由横幅承载；下一步动作是本页
  /// 「验证并替换连接 / 退出此设备」既有按钮，不另设内嵌动作。
  /// 取色走受限四档 tone（MG02，页面不再直接指定 error 色）。
  Widget _feedback(BuildContext context) => InlineBanner(
    message: _message!,
    tone: BannerTone.error,
  );
}
