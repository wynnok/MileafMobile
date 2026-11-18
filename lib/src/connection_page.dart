import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'api.dart';
import 'design/brand_mark.dart';
import 'design/components/components.dart';
import 'design/layout.dart';
import 'design/semantic.dart';
import 'design/tokens.dart';
import 'design/typography.dart';

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({
    super.key,
    required this.api,
    this.onConnected,
    this.initialAddress,
  });
  final String? initialAddress;
  final MileafApi api;
  final void Function(SiteAddress)? onConnected;
  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

/// P13：每页一个任务，标题常量同时供导航栏与正文 title2 使用（文案一字不差）。
const _pageTitle = '连接你的站点';

class _ConnectionPageState extends State<ConnectionPage> {
  late final _address = TextEditingController(text: widget.initialAddress);
  final _form = GlobalKey<FormState>();
  SiteAddress? _healthySite;
  bool _loading = false;
  bool _loadingTrust = false;
  bool _trusted = false;
  bool _savingTrust = false;

  Future<void> _loadTrust() async {
    _healthySite = null;
    final input = _address.text;
    final site = _site;
    setState(() {
      _trusted = false;
      _message = null;
      _loadingTrust = true;
    });
    bool trusted = false;
    String? failure;
    try {
      if (site?.uri.scheme == 'http') {
        trusted = await widget.api.trustStore.isTrusted(site!);
      }
    } on Exception {
      failure = '无法读取站点授权，请重新确认可信网络';
    }
    if (!mounted || input != _address.text) return;
    setState(() {
      _trusted = trusted;
      _loadingTrust = false;
      _message = failure;
    });
  }

  Future<void> _setTrust(bool value) async {
    final site = _site!;
    setState(() {
      _loadingTrust = true;
      _savingTrust = true;
      _message = null;
    });
    try {
      await widget.api.trustStore.setTrusted(site, value);
      if (mounted) {
        setState(() {
          _trusted = value;
        });
      }
    } on Exception {
      if (mounted) {
        setState(() {
          _trusted = false;
          _message = '无法保存站点授权，请重试';
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _loadingTrust = false;
          _savingTrust = false;
        });
      }
    }
  }

  SiteAddress? get _site {
    try {
      return SiteAddress.parse(_address.text);
    } on FormatException {
      return null;
    }
  }

  String? _message;
  @override
  void dispose() {
    _address.dispose();
    super.dispose();
  }

  Future<void> _check() async {
    if (!_form.currentState!.validate()) return;
    setState(() {
      _loading = true;
      _message = null;
    });
    String result;
    try {
      final version = await widget.api.health(SiteAddress.parse(_address.text));
      result = '服务正常，版本 $version';
      _healthySite = SiteAddress.parse(_address.text);
    } on ApiFailure catch (error) {
      result = error.message;
    } on TimeoutException {
      result = '请求超时，请检查网络后重试';
    } on HandshakeException {
      result = '证书校验失败，请检查服务证书；不会忽略证书错误';
    } on FormatException {
      result = '服务返回格式不兼容，请核对 Mileaf Server 版本';
    } on Exception {
      result = '服务不可达，请检查地址与网络后重试。若连接局域网站点，请在系统设置中检查行笺的局域网权限，允许后回到此处重试；也可改用仍可访问的 HTTPS 地址。';
    }
    if (!mounted) return;
    setState(() {
      _loading = false;
      _message = result;
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: mileafPageBar(context, title: const Text(_pageTitle)),
    body: SafeArea(
      child: MileafContent(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(MileafLayout.pageInset(context)),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Align(
                  alignment: Alignment.centerLeft,
                  child: MileafWordmark(markSize: 32),
                ),
                const SizedBox(height: MileafSpace.s16),
                // P13：任务标题 title2（R22）。
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(_pageTitle, style: context.type.title2),
                ),
                const SizedBox(height: MileafSpace.s8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '输入自托管 Mileaf Server 的服务根地址，阅读 TeslaMate 记录。',
                    style: context.type.body.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
                const SizedBox(height: MileafSpace.s24),
                TextFormField(
                  controller: _address,
                  enabled: !_loading && !_savingTrust,
                  keyboardType: TextInputType.url,
                  autocorrect: false,
                  decoration: const InputDecoration(
                    errorMaxLines: 4,
                    labelText: '服务根地址',
                    hintText: 'https://example.com/mileaf',
                  ),
                  validator: (value) {
                    try {
                      SiteAddress.parse(value ?? '');
                      return null;
                    } on FormatException catch (error) {
                      return error.message;
                    }
                  },
                  onChanged: (_) => _loadTrust(),
                  onFieldSubmitted: (_) {
                    if (!_loading && !_loadingTrust) _check();
                  },
                ),
                const SizedBox(height: MileafSpace.s12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    // 对照表标注需用户确认，本轮保留原文（CP12 邻接范围外）。
                    '推荐 HTTPS 安全连接。请保留端口和反向代理路径前缀。',
                    style: context.type.footnote.copyWith(
                      color: context.colors.textSecondary,
                    ),
                  ),
                ),
                if (_site?.uri.scheme == 'http') ...[
                  const SizedBox(height: MileafSpace.s12),
                  const Text(
                    // CP12 冻结文案：HTTP 信任确认逐字保留。
                    'HTTP 会明文传输口令、token 和车辆数据。仅在你信任的私网或 VPN 使用；App 无法验证 VPN 或网络是否安全。',
                  ),
                  CheckboxListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('我确认此站点使用可信网络'),
                    subtitle: Text(_site!.uri.toString()),
                    value: _trusted,
                    onChanged: _loading || _loadingTrust
                        ? null
                        : (value) => _setTrust(value ?? false),
                  ),
                ],
                const SizedBox(height: MileafSpace.s24),
                // R27：主按钮胶囊；处理中保留文字并在尾部加活动指示器。
                MileafButton(
                  label: '检查连接',
                  expand: true,
                  loading: _loading,
                  onPressed: _loading || _loadingTrust ? null : _check,
                ),
                if (_healthySite != null && widget.onConnected != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: MileafButton(
                      label: '登录此站点',
                      kind: MileafButtonKind.ghost,
                      onPressed: () => widget.onConnected!(_healthySite!),
                    ),
                  ),
                if (_message != null)
                  Padding(
                    padding: const EdgeInsets.only(top: MileafSpace.s16),
                    child: Semantics(
                      liveRegion: true,
                      child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          _message!,
                          style: context.type.body.copyWith(
                            color: _healthySite != null
                                ? context.colors.accentStrong
                                : context.colors.error,
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
    ),
  );
}
