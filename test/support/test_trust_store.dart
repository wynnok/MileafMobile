import 'dart:io';

import 'package:mileaf/src/api.dart';

/// AP13 归拢（AP14 落地）：内存信任库测试替身从 widget_test.dart 迁入
/// test/support/，供多个测试文件复用；行为与原实现一致。

class MemoryTrustStore implements HttpTrustStore {
  final _sites = <String>{};
  @override
  Future<bool> isTrusted(SiteAddress site) async =>
      _sites.contains(site.uri.toString());
  @override
  Future<void> setTrusted(SiteAddress site, bool trusted) async {
    if (trusted) {
      _sites.add(site.uri.toString());
    } else {
      _sites.remove(site.uri.toString());
    }
  }
}

class UnavailableTrustStore extends MemoryTrustStore {
  @override
  Future<bool> isTrusted(SiteAddress site) async =>
      throw const FileSystemException('storage unavailable');
}
