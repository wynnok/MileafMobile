import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class MapKeyStore {
  Future<String?> read();
  Future<void> write(String? key);
}

class SecureMapKeyStore implements MapKeyStore {
  static const _record = 'mileaf.map-key.v1';
  final _storage = const FlutterSecureStorage(
    iOptions: IOSOptions(
      accessibility: KeychainAccessibility.unlocked_this_device,
    ),
  );
  @override
  Future<String?> read() => _storage.read(key: _record);
  @override
  Future<void> write(String? key) => key == null
      ? _storage.delete(key: _record)
      : _storage.write(key: _record, value: key);
}

/// A process keeps its first map key until restart. Clearing blocks all views
/// immediately, while retaining that snapshot for accurate restart guidance.
class MapKeyController extends ChangeNotifier {
  MapKeyController(this._store, {this.readProcessKey});
  final Future<String?> Function()? readProcessKey;
  bool _disposed = false;
  final MapKeyStore _store;
  String? _saved;
  String? _active;
  bool _initialized = false;
  bool loaded = false;
  bool readFailed = false;
  bool busy = false;

  String? get savedKey => _saved;
  bool get available => loaded && !readFailed && _saved != null;
  String? get effectiveKey =>
      available ? (_initialized ? _active : _saved) : null;
  bool get restartRequired => _initialized && _saved != _active;
  String get status {
    if (readFailed) return '地图配置读取失败';
    if (!loaded) return '正在读取地图配置';
    if (restartRequired) {
      return _saved == null ? '已清除 · 重新启动可结束地图 SDK' : '已保存 · 重新启动后生效';
    }
    return available ? '已保存' : '未配置 · 使用路线速写';
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  Future<void> restore() async {
    if (busy) return;
    busy = true;
    try {
      final value = await _store.read();
      if (readProcessKey != null) {
        _active = await readProcessKey!();
        _initialized = _active != null;
      }
      _saved = value == null || value.trim().isEmpty ? null : value.trim();
      readFailed = false;
    } catch (_) {
      readFailed = true;
    } finally {
      loaded = true;
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  Future<void> save(String value) async {
    final key = value.trim();
    if (!RegExp(r'^[a-zA-Z0-9]{32}$').hasMatch(key)) {
      throw const FormatException('请输入 32 位字母数字 Key，请检查复制内容');
    }
    await _persist(key);
  }

  Future<void> clear() => _persist(null);

  Future<void> _persist(String? key) async {
    if (busy || readFailed || !loaded) {
      throw StateError('map configuration unavailable');
    }
    busy = true;
    notifyListeners();
    try {
      await _store.write(key);
      _saved = key;
    } finally {
      busy = false;
      if (!_disposed) notifyListeners();
    }
  }

  /// Called only after privacy consent, immediately before native creation.
  String? keyForMap() {
    if (!available) return null;
    if (!_initialized) {
      _active = _saved;
      _initialized = true;
    }
    return _active;
  }
}

class MapKeyScope extends InheritedNotifier<MapKeyController> {
  const MapKeyScope({
    super.key,
    required MapKeyController controller,
    required super.child,
  }) : super(notifier: controller);
  static MapKeyController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<MapKeyScope>()?.notifier;
}

/// Reads installed application identity without initializing the map SDK.
class MapBinding {
  const MapBinding();
  static const channel = MethodChannel('mileaf/map_configuration');
  static Future<String?> readProcessKey() async {
    if (!Platform.isAndroid && !Platform.isIOS) return null;
    return channel.invokeMethod<String>('getProcessKey');
  }

  String get platformLabel => Platform.isIOS ? 'iOS' : 'Android';
  Future<Map<String, String>> read() async {
    final values = await channel.invokeMapMethod<String, String>('getBinding');
    if (values == null || values.isEmpty) {
      throw StateError('application identity unavailable');
    }
    return values;
  }
}
