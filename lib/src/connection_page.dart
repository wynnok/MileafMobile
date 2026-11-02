import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import 'api.dart';
import 'design/brand_mark.dart';
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
      result = '服务正常 · 版本 $version';
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
    appBar: AppBar(title: const Text('行笺 Mileaf')),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.all(MileafLayout.pageInset(context)),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Align(
                    alignment: Alignment.centerLeft,
                    child: MileafWordmark(markSize: 32),
                  ),
                  const SizedBox(height: MileafSpace.s20),
                  Text('连接你的站点', style: context.type.title),
                  const SizedBox(height: MileafSpace.s8),
                  Text(
                    '输入自托管 Mileaf Server 的服务根地址，阅读 TeslaMate 记录。',
                    style: context.type.body.copyWith(
                      color: context.colors.textMuted,
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
                  const SizedBox(height: 12),
                  Text(
                    '推荐 HTTPS 安全连接。请保留端口和反向代理路径前缀。',
                    style: context.type.micro.copyWith(
                      color: context.colors.textMuted,
                    ),
                  ),
                  if (_site?.uri.scheme == 'http') ...[
                    const SizedBox(height: 12),
                    const Text(
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
                  FilledButton(
                    onPressed: _loading || _loadingTrust ? null : _check,
                    child: Text(_loading ? '正在检查…' : '检查连接'),
                  ),
                  if (_healthySite != null && widget.onConnected != null)
                    TextButton(
                      onPressed: () => widget.onConnected!(_healthySite!),
                      child: const Text('登录此站点'),
                    ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.only(top: MileafSpace.s8),
                      child: MileafProgressLine(),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Semantics(
                        liveRegion: true,
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
                ],
              ),
            ),
          ),
        ),
      ),
    ),
  );
}
