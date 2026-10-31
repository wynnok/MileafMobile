import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

typedef MapConsentSnapshot = ({String? provider, bool granted});

abstract interface class MapConsentStore {
  Future<MapConsentSnapshot> read();
  Future<void> write(String provider, bool granted);
}

class MemoryMapConsentStore implements MapConsentStore {
  MemoryMapConsentStore({this.provider, this.granted = false});
  String? provider;
  bool granted;
  @override
  Future<MapConsentSnapshot> read() async =>
      (provider: provider, granted: granted);
  @override
  Future<void> write(String provider, bool granted) async {
    this.provider = provider;
    this.granted = granted;
  }
}

class SharedPreferencesMapConsentStore implements MapConsentStore {
  static const _providerKey = 'map.consent.v1.provider';
  static const _grantedKey = 'map.consent.v1.granted';
  @override
  Future<MapConsentSnapshot> read() async {
    final prefs = await SharedPreferences.getInstance();
    return (
      provider: prefs.getString(_providerKey),
      granted: prefs.getBool(_grantedKey) ?? false,
    );
  }

  @override
  Future<void> write(String provider, bool granted) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_providerKey, provider);
    await prefs.setBool(_grantedKey, granted);
  }
}

/// Consent is scoped to the actual provider. Changing provider (for example
/// Apple Maps -> AMap on iOS) must ask again instead of reusing an old grant.
class MapConsentController extends ChangeNotifier {
  MapConsentController({MapConsentStore? store})
    : _store = store ?? MemoryMapConsentStore();

  factory MapConsentController.persistent() =>
      MapConsentController(store: SharedPreferencesMapConsentStore());

  final MapConsentStore _store;
  String? _provider;
  bool _granted = false;
  bool _loaded = false;

  bool get granted => _granted;
  String? get provider => _provider;
  bool get loaded => _loaded;
  bool isGrantedFor(String provider) => _granted && _provider == provider;

  Future<void> load() async {
    if (_loaded) return;
    try {
      final snapshot = await _store.read();
      _provider = snapshot.provider;
      _granted = snapshot.granted;
    } catch (_) {
      _provider = null;
      _granted = false;
    }
    _loaded = true;
    notifyListeners();
  }

  Future<void> grant([String provider = '高德地图']) async {
    _provider = provider;
    _granted = true;
    _loaded = true;
    notifyListeners();
    try {
      await _store.write(provider, true);
    } catch (_) {}
  }

  Future<void> revoke([String? provider]) async {
    if (provider != null && _provider != provider) return;
    final previous = _provider;
    _granted = false;
    _loaded = true;
    notifyListeners();
    try {
      await _store.write(provider ?? previous ?? '', false);
    } catch (_) {}
  }
}
