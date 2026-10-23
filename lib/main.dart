import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'src/api.dart';
import 'src/connection_page.dart';
export 'src/connection_page.dart';
import 'src/session.dart';
import 'src/session_pages.dart';

void main() => runApp(const MileafApp());

class MileafApp extends StatefulWidget {
  const MileafApp({
    super.key,
    this.client,
    this.trustStore,
    this.sessionStore,
    this.now,
  });
  final http.Client? client;
  final HttpTrustStore? trustStore;
  final SessionStore? sessionStore;
  final DateTime Function()? now;
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
        if (session.current != null) return VehiclePage(session: session);
        if (session.site != null) return LoginPage(session: session);
        return ConnectionPage(api: _api, onConnected: session.useSite);
      },
    ),
  );
}
