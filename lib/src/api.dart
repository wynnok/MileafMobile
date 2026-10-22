import 'dart:convert';
import 'dart:async';

import 'package:http/http.dart' as http;

/// A site identity preserves the reverse-proxy prefix and explicit port.
class SiteAddress {
  SiteAddress._(this.uri);
  final Uri uri;
  factory SiteAddress.parse(String input) {
    final value = Uri.tryParse(input.trim());
    if (value == null ||
        value.scheme != 'https' ||
        value.host.isEmpty ||
        value.userInfo.isNotEmpty ||
        value.hasQuery ||
        value.hasFragment) {
      throw const FormatException('请输入有效的 HTTPS 服务根地址，不含账号、查询或片段');
    }
    var path = value.path.replaceAll(RegExp(r'/+$'), '');
    if (path.endsWith('/v1')) path = path.substring(0, path.length - 3);
    return SiteAddress._(value.replace(path: path));
  }
  Uri endpoint(String path) => uri.replace(path: '${uri.path}/v1/$path');
}

/// Sole HTTP entry point, shared by all site APIs.
class MileafApi {
  MileafApi(this.client);
  final http.Client client;
  Future<String> health(SiteAddress address) async {
    final aborted = Completer<void>();
    final request = http.AbortableRequest(
      'GET',
      address.endpoint('health'),
      abortTrigger: aborted.future,
    )..followRedirects = false;
    final response =
        await (() async {
          return http.Response.fromStream(await client.send(request));
        })().timeout(
          const Duration(seconds: 15),
          onTimeout: () {
            aborted.complete();
            throw TimeoutException('API deadline');
          },
        );
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
