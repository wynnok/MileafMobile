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
      address.endpoint(path),
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
    if (response.statusCode == 503) {
      throw const ApiFailure('服务可达，但数据库或上游暂不可用，请稍后重试');
    }
    if (response.statusCode != 200) {
      throw const ApiFailure('服务未返回健康结果，请核对服务根地址后重试');
    }
    final body = jsonDecode(response.body);
    if (body is! Map<String, dynamic> ||
        body['status'] != 'ok' ||
        body['version'] is! String) {
      throw const ApiFailure('服务返回格式不兼容，请核对 Mileaf Server 版本');
    }
    return body['version'] as String;
  }
}

class ApiFailure implements Exception {
  const ApiFailure(this.message);
  final String message;
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
