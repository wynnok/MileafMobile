import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// A site identity preserves the reverse-proxy prefix and explicit port.
class SiteAddress {
  SiteAddress._(this.uri);
  final Uri uri;
  factory SiteAddress.parse(String input) {
    final value = Uri.tryParse(input.trim());
    if (value == null ||
        !['https', 'http'].contains(value.scheme) ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty ||
        value.hasQuery ||
        value.hasFragment) {
      throw const FormatException('请输入有效的 HTTPS 或 HTTP 服务根地址，不含账号、查询或片段');
    }
    var path = value.path.replaceAll(RegExp(r'/+$'), '');
    if (path.endsWith('/v1')) path = path.substring(0, path.length - 3);
    return SiteAddress._(value.replace(path: path));
  }
  Uri endpoint(String path) => uri.replace(path: '${uri.path}/v1/$path');
}

/// Sole HTTP entry point, shared by all site APIs.
class MileafApi {
  MileafApi(this._client, {HttpTrustStore? trustStore})
    : trustStore = trustStore ?? PreferenceHttpTrustStore();
  final http.Client _client;
  final HttpTrustStore trustStore;

  /// Setup/login and authenticated APIs must inherit this same policy.
  Future<http.Response> request(
    SiteAddress address,
    String method,
    String path, {
    Map<String, String> headers = const {},
    String? body,
    Map<String, String> query = const {},
  }) async {
    if (path.isEmpty ||
        path.startsWith('/') ||
        path.split('/').any((segment) => segment == '.' || segment == '..') ||
        ['%', '?', '#', String.fromCharCode(92)].any(path.contains)) {
      throw const ApiFailure('请求路径无效');
    }
    if (address.uri.scheme == 'http') {
      bool trusted;
      try {
        trusted = await trustStore.isTrusted(address);
      } on Exception {
        throw const ApiFailure('无法读取站点授权，请检查设备存储后重试');
      }
      if (!trusted) {
        throw const ApiFailure('请先确认此站点使用可信网络；HTTP 会明文传输数据与凭据');
      }
    }
    final aborted = Completer<void>();
    final request = http.AbortableRequest(
      method,
      address
          .endpoint(path)
          .replace(queryParameters: query.isEmpty ? null : query),
      abortTrigger: aborted.future,
    )..followRedirects = false;
    request.headers.addAll(headers);
    if (body != null) request.body = body;
    final response =
        await (() async {
          return http.Response.fromStream(await _client.send(request));
        })().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            aborted.complete();
            throw TimeoutException('API deadline');
          },
        );
    if (response.statusCode >= 300 &&
        response.statusCode < 400 &&
        response.statusCode != 304) {
      throw const ApiFailure('服务要求跳转；不会自动跟随跳转，请填写实际服务地址后重试');
    }
    return response;
  }

  Future<String> health(SiteAddress address) async {
    final response = await request(address, 'GET', 'health');
    if (response.statusCode != 200) {
      throw ApiFailure(
        responseErrorMessage(response) ??
            (response.statusCode == 503
                ? '服务可达，但数据库或上游暂不可用，请稍后重试'
                : '服务未返回健康结果，请核对服务根地址后重试'),
      );
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> ||
        body['status'] != 'ok' ||
        body['version'] is! String) {
      throw const ApiFailure('服务器返回的数据格式不受支持，请确认 Mileaf Server 版本');
    }
    return body['version'] as String;
  }
}

class ApiFailure implements Exception {
  const ApiFailure(this.message);
  final String message;
}

/// Bounded known-code descriptions only; never surface a server message or body.
String? responseErrorMessage(http.Response response) {
  String? code;
  if (response.bodyBytes.length <= 8192) {
    try {
      final envelope = jsonDecode(response.body);
      if (envelope is Map && envelope['error'] is Map) {
        final candidate = (envelope['error'] as Map)['code'];
        if (candidate is String) code = candidate;
      }
    } on FormatException {
      // Proxy errors need not be JSON. Never display their body/message.
    }
  }
  return switch ((response.statusCode, code)) {
    (400 || 422, _) => '请求参数无效，请检查输入或日期范围，并核对服务版本后重试',
    (503, 'db_unavailable') => '数据库暂不可用，请检查站点数据库后重试',
    (503 || 504, 'upstream_timeout') => '上游服务超时，请稍后重试',
    (500, 'internal_error') => '服务内部错误，请检查站点服务后重试',
    _ => null,
  };
}

/// Non-secret connection preferences; never stores passwords or bearer tokens.
abstract interface class HttpTrustStore {
  Future<bool> isTrusted(SiteAddress site);
  Future<void> setTrusted(SiteAddress site, bool trusted);
}

class PreferenceHttpTrustStore implements HttpTrustStore {
  final _preferences = SharedPreferencesAsync();
  String _key(SiteAddress site) => 'http-trust:${site.uri}';
  @override
  Future<bool> isTrusted(SiteAddress site) async =>
      await _preferences.getBool(_key(site)) ?? false;
  @override
  Future<void> setTrusted(SiteAddress site, bool trusted) async {
    if (trusted) {
      await _preferences.setBool(_key(site), true);
    } else {
      await _preferences.remove(_key(site));
    }
  }
}
