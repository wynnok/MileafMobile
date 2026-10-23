import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:http/http.dart' as http;

import 'api.dart';
import 'auth_contract.g.dart';
export 'auth_contract.g.dart' show Vehicle;

abstract interface class SessionStore {
  Future<String?> read();
  Future<void> write(String record);
  Future<void> clear();
}

/// One Keychain/Keystore record binds the credential to its exact site identity.
class SecureSessionStore implements SessionStore {
  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  static const _key = 'mileaf.site-session.v1';
  @override
  Future<String?> read() => _storage.read(key: _key);
  @override
  Future<void> write(String record) => _storage.write(key: _key, value: record);
  @override
  Future<void> clear() => _storage.delete(key: _key);
}

class SiteSession {
  SiteSession(this.site, this.token, this.expiresAt, this.generation);
  final SiteAddress site;
  final String token;
  final DateTime expiresAt;
  final int generation;
}

class SessionController extends ChangeNotifier {
  SessionController(this.api, this.store, {DateTime Function()? now})
    : now = now ?? DateTime.now;
  final MileafApi api;
  final SessionStore store;
  final DateTime Function() now;
  SiteSession? current;
  SiteAddress? site;
  List<Vehicle> vehicles = [];
  bool restoring = true;
  bool loading = false;
  String? message;
  DateTime? retryAfter;
  int _generation = 0;
  Timer? _expiry;
  Timer? _retryTimer;
  bool _disposed = false;
  Future<void> _writes = Future.value();

  Future<T> _persist<T>(Future<T> Function() operation) {
    final result = _writes.then((_) => operation());
    _writes = result.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return result;
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  bool isCurrent(SiteSession session) =>
      identical(current, session) && session.generation == _generation;

  Future<void> restore() async {
    final generation = ++_generation;
    try {
      final raw = await store.read();
      if (raw != null && generation == _generation) {
        final record = object(jsonDecode(raw));
        site = SiteAddress.parse(field<String>(record['site']));
        if (!record.containsKey('token') && !record.containsKey('expires_at')) {
          return;
        }
        final expires = instant(record['expires_at']);
        final token = field<String>(record['token']);
        if (token.isEmpty || !expires.isAfter(now())) {
          await _persist(
            () => store.write(jsonEncode({'site': site!.uri.toString()})),
          );
          message = '会话已到期，请重新登录';
        } else {
          current = SiteSession(site!, token, expires, generation);
          _scheduleExpiry();
        }
      }
    } on Exception {
      message = '无法恢复安全会话，请重新登录；不会读取明文凭据';
    } finally {
      restoring = false;
      _notify();
    }
    if (current != null) await loadVehicles();
  }

  void useSite(SiteAddress value) {
    site = value;
    message = null;
    retryAfter = null;
    _notify();
  }

  bool get canLogin =>
      !loading && (retryAfter == null || !now().isBefore(retryAfter!));

  Future<void> login(String password) async {
    if (!canLogin || site == null) return;
    final address = site!;
    final generation = ++_generation;
    loading = true;
    message = null;
    retryAfter = null;
    _notify();
    try {
      final response = await api.request(
        address,
        'POST',
        'auth/login',
        headers: {'content-type': 'application/json'},
        body: jsonEncode(Credentials(password: password).toJson()),
      );
      if (generation != _generation) return;
      if (response.statusCode != 200) {
        throw _failure(response, login: true);
      }
      final result = LoginResponse.fromJson(object(jsonDecode(response.body)));
      if (result.token.isEmpty || !result.expiresAt.isAfter(now())) {
        throw const FormatException('Expired credential');
      }
      await _persist(
        () => store.write(
          jsonEncode({
            'site': address.uri.toString(),
            'token': result.token,
            'expires_at': result.expiresAt.toIso8601String(),
          }),
        ),
      );
      if (generation != _generation) return;
      current = SiteSession(
        address,
        result.token,
        result.expiresAt,
        generation,
      );
      vehicles = [];
      _scheduleExpiry();
    } on Exception catch (error) {
      if (generation == _generation) message = _describe(error);
    } finally {
      if (generation == _generation) {
        loading = false;
        _notify();
      }
    }
    if (current?.generation == generation) await loadVehicles();
  }

  /// Validate a candidate without granting it access to the active credential.
  /// Returns a visible error; only a fully validated, persisted candidate commits.
  Future<String?> replaceConnection(
    SiteAddress address,
    String password,
  ) async {
    final previous = current;
    final generation = _generation;
    if (retryAfter != null && now().isBefore(retryAfter!)) {
      return '请求过于频繁，请稍后手动重试';
    }
    if (previous == null) return '会话已变更，请重新登录';
    try {
      await api.health(address);
      final response = await api.request(
        address,
        'POST',
        'auth/login',
        headers: {'content-type': 'application/json'},
        body: jsonEncode(Credentials(password: password).toJson()),
      );
      if (response.statusCode != 200) throw _failure(response, login: true);
      final result = LoginResponse.fromJson(object(jsonDecode(response.body)));
      if (result.token.isEmpty || !result.expiresAt.isAfter(now())) {
        throw const FormatException('Expired credential');
      }
      final vehicleResponse = await api.request(
        address,
        'GET',
        'vehicles',
        headers: {'authorization': 'Bearer ${result.token}'},
      );
      if (vehicleResponse.statusCode != 200) throw _failure(vehicleResponse);
      final body = jsonDecode(vehicleResponse.body);
      if (body is! List) throw const FormatException('Expected array');
      final candidateVehicles = body
          .map((v) => Vehicle.fromJson(object(v)))
          .toList();
      if (!isCurrent(previous) || generation != _generation) {
        return '会话已变更，未替换连接';
      }
      await _persist(() async {
        if (!isCurrent(previous) || generation != _generation) {
          throw const ApiFailure('会话已变更，未替换连接');
        }
        await store.write(
          jsonEncode({
            'site': address.uri.toString(),
            'token': result.token,
            'expires_at': result.expiresAt.toIso8601String(),
          }),
        );
      });
      if (!isCurrent(previous) || generation != _generation) {
        return '会话已变更，未替换连接';
      }
      site = address;
      current = SiteSession(
        address,
        result.token,
        result.expiresAt,
        ++_generation,
      );
      vehicles = candidateVehicles;
      loading = false;
      message = null;
      retryAfter = null;
      _scheduleExpiry();
      _notify();
      return null;
    } on Exception catch (error) {
      return _describe(error);
    }
  }

  /// Local device access ends immediately, including outstanding response rights.
  /// No server logout/revoke endpoint exists.
  Future<String?> logout() async {
    ++_generation;
    _expiry?.cancel();
    _retryTimer?.cancel();
    current = null;
    vehicles = [];
    loading = false;
    message = '已退出此设备；不会撤销其他设备或服务端授权';
    retryAfter = null;
    final address = site;
    _notify();
    try {
      await _persist(
        () => address == null
            ? store.clear()
            : store.write(jsonEncode({'site': address.uri.toString()})),
      );
      return null;
    } on Exception {
      message = '本地访问已停止，但安全存储清理失败，请重试退出后再关闭应用';
      _notify();
      return message;
    }
  }

  Future<http.Response> request(SiteSession session, String path) async {
    if (!isCurrent(session)) throw const ApiFailure('会话已变更，请重试');
    if (!session.expiresAt.isAfter(now())) {
      await invalidate(session);
      throw const ApiFailure('会话已到期，请重新登录');
    }
    final response = await api.request(
      session.site,
      'GET',
      path,
      headers: {'authorization': 'Bearer ${session.token}'},
    );
    if (response.statusCode == 401 && isCurrent(session)) {
      await invalidate(session);
    }
    return response;
  }

  Future<void> loadVehicles() async {
    final session = current;
    if (session == null) return;
    loading = true;
    message = null;
    _notify();
    try {
      final response = await request(session, 'vehicles');
      if (!isCurrent(session)) return;
      if (response.statusCode != 200) throw _failure(response);
      final body = jsonDecode(response.body);
      if (body is! List) throw const FormatException('Expected array');
      final result = body.map((v) => Vehicle.fromJson(object(v))).toList();
      if (isCurrent(session)) vehicles = result;
    } on Exception catch (error) {
      if (isCurrent(session)) message = _describe(error);
    } finally {
      if (isCurrent(session)) {
        loading = false;
        _notify();
      }
    }
  }

  Future<void> invalidate(SiteSession session) async {
    if (!isCurrent(session)) return;
    final generation = ++_generation;
    _expiry?.cancel();
    current = null;
    vehicles = [];
    loading = false;
    message = '会话已失效，请重新登录';
    _notify();
    try {
      await _persist(
        () => store.write(jsonEncode({'site': site!.uri.toString()})),
      );
    } on Exception {
      if (generation == _generation) {
        message = '会话已失效，安全存储清理失败，请重试';
        _notify();
      }
    }
  }

  void validateExpiry() {
    final session = current;
    if (session != null && !session.expiresAt.isAfter(now())) {
      unawaited(invalidate(session));
    }
  }

  void _scheduleExpiry() {
    _expiry?.cancel();
    final delay = current!.expiresAt.difference(now());
    _expiry = Timer(delay, validateExpiry);
  }

  ApiFailure _failure(http.Response response, {bool login = false}) {
    if (response.statusCode == 429) {
      final header = response.headers['retry-after'];
      final seconds = int.tryParse(header ?? '');
      if (seconds != null && seconds >= 0) {
        retryAfter = now().add(Duration(seconds: seconds));
      } else if (header != null) {
        try {
          retryAfter = HttpDate.parse(header).toUtc();
        } on FormatException {
          retryAfter = null;
        }
      }
      _retryTimer?.cancel();
      if (retryAfter != null && retryAfter!.isAfter(now())) {
        _retryTimer = Timer(retryAfter!.difference(now()), _notify);
      }

      return const ApiFailure('请求过于频繁，请稍后手动重试');
    }
    if (response.statusCode == 401) {
      return ApiFailure(login ? '站点访问口令错误，请重试' : '会话已失效，请重新登录');
    }
    if (response.statusCode == 503) return const ApiFailure('服务暂不可用，请稍后重试');
    return const ApiFailure('请求失败，请检查服务后重试');
  }

  String _describe(Exception error) => switch (error) {
    ApiFailure e => e.message,
    FormatException _ => '服务返回格式不兼容，请核对 Mileaf Server 版本',
    TimeoutException _ => '请求超时，请检查网络后重试',
    HandshakeException _ => '证书校验失败，请检查服务证书；不会忽略证书错误',
    _ => '无法完成请求或安全保存，请检查网络与设备存储后重试',
  };
  @override
  void dispose() {
    _disposed = true;
    ++_generation;
    _expiry?.cancel();
    _retryTimer?.cancel();
    super.dispose();
  }
}

String vehicleName(Vehicle vehicle) {
  if (vehicle.name?.trim().isNotEmpty ?? false) return vehicle.name!.trim();
  final suffix = vehicle.vinSuffix.trim();
  final lastFour = suffix.length > 4
      ? suffix.substring(suffix.length - 4)
      : suffix;
  final parts = [
    if (vehicle.model?.trim().isNotEmpty ?? false) vehicle.model!.trim(),
    if (lastFour.isNotEmpty) '尾号 $lastFour',
  ];
  return parts.isEmpty ? '车辆 ${vehicle.id}' : parts.join(' · ');
}
