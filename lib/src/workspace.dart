import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest_all.dart' as database;
import 'package:timezone/timezone.dart' as tz;

import 'api.dart';
import 'session.dart';

/// Device time zone, re-read on foreground. Calendar boundaries use IANA rules.
class CalendarContext {
  CalendarContext(this.identifier, {this.fallback = false}) {
    if (!_initialized) {
      database.initializeTimeZones();
      _initialized = true;
    }
    location = tz.getLocation(identifier);
  }
  static bool _initialized = false;
  final String identifier;
  final bool fallback;
  late final tz.Location location;
  tz.TZDateTime local(DateTime value) => tz.TZDateTime.from(value, location);
  String day(DateTime value) {
    final d = local(value);
    return '${d.year}-${d.month}-${d.day}';
  }

  DateTime midnight(DateTime date, {int nextDays = 0}) => tz.TZDateTime(
    location,
    date.year,
    date.month,
    date.day + nextDays,
  ).toUtc();
  static Future<CalendarContext> device() async {
    try {
      return CalendarContext(
        (await FlutterTimezone.getLocalTimezone()).identifier,
      );
    } catch (_) {
      return CalendarContext('UTC', fallback: true);
    }
  }
}

abstract interface class VehiclePreferenceStore {
  Future<int?> read(String site);
  Future<void> write(String site, int id);
}

class PreferenceVehicleStore implements VehiclePreferenceStore {
  late final _store = SharedPreferencesAsync();
  @override
  Future<int?> read(String site) => _store.getInt('selected-vehicle:$site');
  @override
  Future<void> write(String site, int id) =>
      _store.setInt('selected-vehicle:$site', id);
}

class BusinessFailure extends ApiFailure {
  const BusinessFailure(super.message, this.status);
  final int status;
}

class CachedResult {
  CachedResult(
    this.body,
    this.etag,
    this.validUntil,
    this.checkedAt,
    this.maxAge,
  );
  final Map<String, dynamic> body;
  final String? etag;
  final DateTime validUntil, checkedAt;
  final int maxAge;
}

/// One in-memory authorization-bound GET cache. Each resource owns its UI state.
class BusinessCache {
  BusinessCache(this.session);
  final SessionController session;
  final _entries = <String, CachedResult>{};
  final _attempts = <String, Object>{};
  SiteSession? _owner;
  DateTime? _retryUntil;
  void clearSnapshots() {
    _entries.clear();
    _attempts.clear();
  }

  /// Remove affected snapshots and their in-flight validators together.
  void invalidateChargingCosts(int vehicle) {
    bool affected(String key) {
      final path = key.split('|')[2];
      return path.startsWith('charging-sessions/') ||
          path.startsWith('vehicles/$vehicle/charging-') ||
          path == 'vehicles/$vehicle/stats' ||
          path == 'vehicles/$vehicle/summary';
    }

    _entries.removeWhere((key, _) => affected(key));
    _attempts.removeWhere((key, _) => affected(key));
  }

  void clear() {
    clearSnapshots();
    _retryUntil = null;
    _owner = null;
  }

  String key(SiteSession s, String path, Map<String, String> query) {
    final names = query.keys.toList()..sort();
    return '${s.site.uri}|${s.generation}|$path|${Uri(queryParameters: {for (final name in names) name: query[name]!}).query}';
  }

  Future<http.Response> _request(
    SiteSession owner,
    String path, {
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
  }) async {
    try {
      return await session.request(owner, path, query: query, headers: headers);
    } on HandshakeException {
      throw const ApiFailure('证书校验失败，请检查服务证书；不会忽略证书错误');
    } on TimeoutException {
      throw const ApiFailure('请求超时，请检查网络后重试');
    } on SocketException {
      throw const ApiFailure('服务不可达，请检查网络、站点地址及局域网权限后重试');
    } on http.ClientException {
      throw const ApiFailure('连接中断，请检查网络后重试');
    }
  }

  CachedResult? peek(SiteSession s, String path, Map<String, String> query) =>
      identical(_owner, s) ? _entries[key(s, path, query)] : null;
  Future<CachedResult> get(
    SiteSession s,
    String path, {
    Map<String, String> query = const {},
    bool force = false,
  }) async {
    if (!session.isCurrent(s)) throw const ApiFailure('会话已变更');
    if (!identical(_owner, s)) {
      clear();
      _owner = s;
    }
    final identity = key(s, path, query);
    final old = _entries[identity];
    if (!force && old != null && old.validUntil.isAfter(session.now())) {
      return old;
    }
    if (_retryUntil?.isAfter(session.now()) ?? false) {
      throw const BusinessFailure('请求过于频繁，请等待服务指定的间隔后手动重试', 429);
    }
    final attempt = Object();
    _attempts[identity] = attempt;
    void ensureCurrent() {
      if (!session.isCurrent(s) || !identical(_attempts[identity], attempt)) {
        throw const ApiFailure('请求已被更新结果替代');
      }
    }

    var response = await _request(
      s,
      path,
      query: query,
      headers: {if (old?.etag != null) 'if-none-match': old!.etag!},
    );
    ensureCurrent();
    // Servers/proxies may return an unsolicited 304 after memory was discarded.
    if (response.statusCode == 304 && old == null) {
      response = await _request(s, path, query: query);
    }
    ensureCurrent();
    if (response.statusCode != 200 &&
        !(response.statusCode == 304 && old != null)) {
      if (response.statusCode == 429) {
        final header = response.headers['retry-after'];
        final seconds = int.tryParse(header ?? '');
        if (seconds != null && seconds >= 0) {
          _retryUntil = session.now().add(Duration(seconds: seconds));
        } else if (header != null) {
          try {
            _retryUntil = HttpDate.parse(header).toUtc();
          } on FormatException {
            _retryUntil = null;
          }
        } else {
          _retryUntil = null;
        }
      }
      throw BusinessFailure(
        responseErrorMessage(response) ??
            switch (response.statusCode) {
              404 => '车辆或记录已不可用，请刷新车辆',
              429 => '请求过于频繁，请稍后手动重试',
              503 => '服务暂不可用，请稍后重试',
              _ => '数据读取失败，请稍后重试',
            },
        response.statusCode,
      );
    }
    final Map<String, dynamic> body;
    if (response.statusCode == 304) {
      body = old!.body;
    } else {
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) throw const FormatException();
      body = decoded;
    }
    final seconds =
        int.tryParse(
          RegExp(r'(?:^|,)\s*max-age=(\d+)')
                  .firstMatch(response.headers['cache-control'] ?? '')
                  ?.group(1) ??
              '',
        ) ??
        (response.statusCode == 304 ? old!.maxAge : 0);
    final now = session.now();
    final result = CachedResult(
      body,
      response.headers['etag'] ??
          (response.statusCode == 304 ? old?.etag : null),
      now.add(Duration(seconds: seconds)),
      now,
      seconds,
    );
    if ((response.headers['cache-control'] ?? '').contains('no-store')) {
      _entries.remove(identity);
    } else {
      _entries[identity] = result;
    }
    return result;
  }
}

class VehicleWorkspace extends ChangeNotifier {
  VehicleWorkspace(
    this.session,
    this.preferences, {
    Future<CalendarContext> Function()? calendar,
  }) : readCalendar = calendar ?? CalendarContext.device,
       cache = BusinessCache(session) {
    _owner = session.current;
    session.addListener(_sessionChanged);
  }
  final SessionController session;
  final VehiclePreferenceStore preferences;
  final Future<CalendarContext> Function() readCalendar;
  final BusinessCache cache;
  final _costReaders = <Future<bool> Function()>{};
  void addCostReader(Future<bool> Function() reader) =>
      _costReaders.add(reader);
  void removeCostReader(Future<bool> Function() reader) =>
      _costReaders.remove(reader);

  /// Bumped whenever an entered fee invalidates charge-derived snapshots.
  /// Retained pages compare it on return: a hidden page never reads while
  /// hidden, but a page that has not consumed this revision must revalidate
  /// its real records and totals on its next visible frame. #25 shares it.
  int costRevision = 0;

  /// A fee change is data refresh, never a vehicle/session revision.
  Future<bool> refreshChargingCosts(SiteSession owner, int vehicle) async {
    if (_disposed || !session.isCurrent(owner) || selectedId != vehicle) {
      return false;
    }
    cache.invalidateChargingCosts(vehicle);
    costRevision++;
    final results = await Future.wait(
      _costReaders.toList().map((reader) async {
        try {
          return await reader();
        } catch (_) {
          return false;
        }
      }),
    );
    return results.every((result) => result);
  }

  CalendarContext? calendar;
  int? selectedId;
  String? notice;
  SiteSession? _owner;
  Future<void> _writes = Future.value();
  bool _disposed = false;
  String? _day;
  int revision = 0;
  void _notify() {
    if (!_disposed) notifyListeners();
  }

  void _sessionChanged() {
    if (!identical(_owner, session.current)) {
      _owner = session.current;
      selectedId = null;
      calendar = null;
      cache.clear();
      revision++;
    }
    _notify();
  }

  Future<void> initialize() async {
    final s = session.current;
    if (s == null || session.vehicles.isEmpty) return;
    final saved = await preferences
        .read(s.site.uri.toString())
        .catchError((_) => null);
    final clock = await readCalendar();
    if (!session.isCurrent(s) || _disposed) return;
    calendar = clock;
    _day = clock.day(session.now());
    select(
      session.vehicles.any((v) => v.id == saved)
          ? saved!
          : session.vehicles.first.id,
    );
  }

  void select(int id, {String? notice}) {
    if (!session.vehicles.any((v) => v.id == id)) return;
    selectedId = id;
    revision++;
    this.notice = notice;
    _notify();
    final site = session.current!.site.uri.toString();
    _writes = _writes.then((_) => preferences.write(site, id)).catchError((_) {
      if (!_disposed) {
        notice = '无法保存车辆偏好，下次启动可能恢复首辆车';
        _notify();
      }
    });
  }

  Future<bool> foreground() async {
    final s = session.current;
    if (s == null) return false;
    final clock = await readCalendar();
    if (!session.isCurrent(s) || _disposed) return false;
    final changed =
        calendar?.identifier != clock.identifier ||
        _day != clock.day(session.now());
    if (changed) {
      calendar = clock;
      _day = clock.day(session.now());
      cache.clearSnapshots();
      revision++;
      _notify();
    }
    return changed;
  }

  @override
  void dispose() {
    _disposed = true;
    session.removeListener(_sessionChanged);
    _costReaders.clear();
    cache.clear();
    super.dispose();
  }
}
