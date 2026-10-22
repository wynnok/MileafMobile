import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'src/api.dart';

void main() => runApp(const MileafApp());

class MileafApp extends StatefulWidget {
  const MileafApp({super.key, this.client});
  final http.Client? client;
  @override
  State<MileafApp> createState() => _MileafAppState();
}

class _MileafAppState extends State<MileafApp> {
  late final http.Client _client =
      widget.client ??
      IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 5));
  @override
  void dispose() {
    if (widget.client == null) _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: '行笺 Mileaf',
    debugShowCheckedModeBanner: false,
    locale: const Locale('zh', 'CN'),
    supportedLocales: const [Locale('zh', 'CN')],
    localizationsDelegates: GlobalMaterialLocalizations.delegates,
    theme: ThemeData(
      colorSchemeSeed: const Color(0xFF426B54),
      useMaterial3: true,
    ),
    darkTheme: ThemeData(
      colorSchemeSeed: const Color(0xFF426B54),
      brightness: Brightness.dark,
      useMaterial3: true,
    ),
    home: ConnectionPage(api: MileafApi(_client)),
  );
}

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key, required this.api});
  final MileafApi api;
  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final _address = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _loading = false;
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
    } on ApiFailure catch (error) {
      result = error.message;
    } on TimeoutException {
      result = '请求超时，请检查网络后重试';
    } on HandshakeException {
      result = '证书校验失败，请检查服务证书；不会忽略证书错误';
    } on FormatException {
      result = '服务返回格式不兼容，请核对 Mileaf Server 版本';
    } on Exception {
      result = '服务不可达，请检查地址与网络后重试';
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
        padding: const EdgeInsets.all(24),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: Form(
              key: _form,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    '连接你的站点',
                    style: Theme.of(context).textTheme.headlineMedium,
                  ),
                  const SizedBox(height: 12),
                  const Text('输入自托管 Mileaf Server 的服务根地址，阅读 TeslaMate 记录。'),
                  const SizedBox(height: 24),
                  TextFormField(
                    controller: _address,
                    enabled: !_loading,
                    keyboardType: TextInputType.url,
                    autocorrect: false,
                    decoration: const InputDecoration(
                      errorMaxLines: 4,
                      labelText: '服务根地址',
                      hintText: 'https://example.com/mileaf',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      try {
                        SiteAddress.parse(value ?? '');
                        return null;
                      } on FormatException catch (error) {
                        return error.message;
                      }
                    },
                    onFieldSubmitted: (_) {
                      if (!_loading) _check();
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('当前使用 HTTPS 安全连接。请保留端口和反向代理路径前缀。'),
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _loading ? null : _check,
                    child: Text(_loading ? '正在检查…' : '检查连接'),
                  ),
                  if (_loading)
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: Center(child: CircularProgressIndicator()),
                    ),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(_message!),
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
