import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Dark is the default; light and system are equal choices.
enum MileafAppearance {
  dark('深色'),
  light('浅色'),
  system('跟随系统');

  const MileafAppearance(this.label);
  final String label;

  ThemeMode get themeMode => switch (this) {
    MileafAppearance.dark => ThemeMode.dark,
    MileafAppearance.light => ThemeMode.light,
    MileafAppearance.system => ThemeMode.system,
  };
}

abstract interface class AppearancePreferenceStore {
  Future<String?> read();
  Future<void> write(String? value);
}

/// Device-level preference; appearance is not site business data.
class PreferenceAppearanceStore implements AppearancePreferenceStore {
  static const _key = 'appearance:mode';
  late final _store = SharedPreferencesAsync();
  @override
  Future<String?> read() => _store.getString(_key);
  @override
  Future<void> write(String? value) async {
    if (value == null) {
      await _store.remove(_key);
    } else {
      await _store.setString(_key, value);
    }
  }
}

class AppearanceController extends ChangeNotifier {
  AppearanceController(this.store);
  final AppearancePreferenceStore store;

  MileafAppearance _mode = MileafAppearance.dark;
  bool _restoring = false;
  bool _restored = false;
  bool _disposed = false;

  MileafAppearance get mode => _mode;
  bool get restored => _restored;
  ThemeMode get themeMode => _mode.themeMode;
  bool get isDark => _mode == MileafAppearance.dark;

  /// Reads the saved mode once; failures keep the dark default.
  Future<void> restore() async {
    if (_restoring || _restored) return;
    _restoring = true;
    try {
      final saved = await store.read();
      final parsed = MileafAppearance.values
          .where((mode) => mode.name == saved)
          .firstOrNull;
      if (parsed != null) _mode = parsed;
    } catch (_) {
      // Keep the design default rather than blocking the app on preferences.
    } finally {
      _restoring = false;
      _restored = true;
      if (!_disposed) notifyListeners();
    }
  }

  /// Optimistically applies, then persists. A failed write rolls back.
  Future<void> select(MileafAppearance value) async {
    if (_mode == value) return;
    final previous = _mode;
    _mode = value;
    notifyListeners();
    try {
      await store.write(value.name);
      _restored = true;
    } catch (error) {
      _mode = previous;
      _restored = true;
      if (!_disposed) notifyListeners();
      rethrow;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
