import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'src/api.dart';
import 'src/session.dart';
import 'src/session_pages.dart';
import 'src/workspace.dart';
import 'src/workspace_page.dart';

void main() => runApp(const MileafApp());

class MileafApp extends StatefulWidget {
  const MileafApp({
    super.key,
    this.client,
    this.trustStore,
    this.sessionStore,
    this.now,
    this.vehiclePreferences,
    this.calendar,
  });
  final http.Client? client;
  final HttpTrustStore? trustStore;
  final SessionStore? sessionStore;
  final DateTime Function()? now;
  final VehiclePreferenceStore? vehiclePreferences;
  final Future<CalendarContext> Function()? calendar;
  @override
  State<MileafApp> createState() => _MileafAppState();
}

class _MileafAppState extends State<MileafApp> with WidgetsBindingObserver {
  late final http.Client _client =
      widget.client ??
      IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 5));
  late final _api = MileafApi(_client, trustStore: widget.trustStore);
  late final session = SessionController(
    _api,
    widget.sessionStore ?? SecureSessionStore(),
    now: widget.now,
  );
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    session.restore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) session.validateExpiry();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.dispose();

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
    home: ListenableBuilder(
      listenable: session,
      builder: (context, _) {
        if (session.restoring) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (session.current != null) {
          return WorkspacePage(
            session: session,
            preferences: widget.vehiclePreferences,
            calendar: widget.calendar,
          );
        }
        if (session.site != null) return LoginPage(session: session);
        return ConnectionPage(api: _api, onConnected: session.useSite);
      },
    ),
  );
}

class ConnectionPage extends StatefulWidget {
  const ConnectionPage({super.key, required this.api, this.onConnected});
  final MileafApi api;
  final void Function(SiteAddress)? onConnected;
  @override
  State<ConnectionPage> createState() => _ConnectionPageState();
}

class _ConnectionPageState extends State<ConnectionPage> {
  final _address = TextEditingController();
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
                    enabled: !_loading && !_savingTrust,
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
                    onChanged: (_) => _loadTrust(),
                    onFieldSubmitted: (_) {
                      if (!_loading && !_loadingTrust) _check();
                    },
                  ),
                  const SizedBox(height: 12),
                  const Text('推荐 HTTPS 安全连接。请保留端口和反向代理路径前缀。'),
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
                  const SizedBox(height: 24),
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
