import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import 'src/api.dart';
import 'src/appearance.dart';
import 'src/design/theme.dart';
import 'src/performance_trace.dart';
import 'src/map/map_consent.dart';
import 'src/map/map_panel.dart';
import 'src/map/map_platform.dart';
import 'src/connection_page.dart';
export 'src/connection_page.dart';
import 'src/session.dart';
import 'src/session_pages.dart';
import 'src/workspace.dart';
import 'src/currency.dart';
import 'src/workspace_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  PerformanceTrace.mark(PerformancePoint.dartEntry);
  final mapConsent = MapConsentController.persistent();
  await mapConsent.load();
  final appearance = AppearanceController(PreferenceAppearanceStore());
  await appearance.restore();
  runApp(MileafApp(mapConsent: mapConsent, appearance: appearance));
}

class MileafApp extends StatefulWidget {
  const MileafApp({
    super.key,
    this.client,
    this.mapConsent,
    this.mapPlatform,
    this.trustStore,
    this.sessionStore,
    this.now,
    this.vehiclePreferences,
    this.calendar,
    this.currencyPreferences,
    this.appearance,
  });
  final http.Client? client;
  final MapConsentController? mapConsent;
  final MapPlatform? mapPlatform;
  final HttpTrustStore? trustStore;
  final SessionStore? sessionStore;
  final DateTime Function()? now;
  final VehiclePreferenceStore? vehiclePreferences;
  final CurrencyPreferenceStore? currencyPreferences;
  final Future<CalendarContext> Function()? calendar;
  final AppearanceController? appearance;
  @override
  State<MileafApp> createState() => _MileafAppState();
}

class _MileafAppState extends State<MileafApp> with WidgetsBindingObserver {
  late final http.Client _client =
      widget.client ??
      IOClient(HttpClient()..connectionTimeout = const Duration(seconds: 5));
  late final mapConsent = widget.mapConsent ?? MapConsentController();
  late final mapPlatform = widget.mapPlatform ?? defaultMapPlatform();
  late final appearance =
      widget.appearance ?? AppearanceController(PreferenceAppearanceStore());
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
    if (widget.appearance == null) appearance.restore();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      PerformanceTrace.beginResume();
      session.validateExpiry();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    session.dispose();
    if (widget.appearance == null) appearance.dispose();

    if (widget.client == null) _client.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ListenableBuilder(
    listenable: appearance,
    builder: (context, _) => MaterialApp(
      title: '行笺 Mileaf',
      debugShowCheckedModeBanner: false,
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [Locale('zh', 'CN')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      theme: mileafTheme(Brightness.light),
      darkTheme: mileafTheme(Brightness.dark),
      themeMode: appearance.themeMode,
      themeAnimationDuration: const Duration(milliseconds: 200),
      builder: (context, child) {
        final dark = switch (appearance.mode) {
          MileafAppearance.dark => true,
          MileafAppearance.light => false,
          MileafAppearance.system =>
            MediaQuery.platformBrightnessOf(context) == Brightness.dark,
        };
        return AnnotatedRegion<SystemUiOverlayStyle>(
          value: (dark
                  ? SystemUiOverlayStyle.light
                  : SystemUiOverlayStyle.dark)
              .copyWith(
                statusBarColor: Colors.transparent,
                systemNavigationBarColor: Colors.transparent,
              ),
          child: child ?? const SizedBox.shrink(),
        );
      },
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
              key: ObjectKey(session.current),
              session: session,
              mapConsent: mapConsent,
              mapPlatform: mapPlatform,
              preferences: widget.vehiclePreferences,
              calendar: widget.calendar,
              currencyPreferences: widget.currencyPreferences,
              appearance: appearance,
            );
          }
          if (session.site != null) return LoginPage(session: session);
          return ConnectionPage(api: _api, onConnected: session.useSite);
        },
      ),
    ),
  );
}
