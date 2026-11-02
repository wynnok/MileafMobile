import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Following the system is the default; light and dark are explicit choices.
///
/// Declaration order is the display order in the appearance sheet:
/// system / light / dark, default first.
enum MileafAppearance {
  system('跟随系统'),
  light('浅色'),
  dark('深色');

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

  MileafAppearance _mode = MileafAppearance.system;
  bool _restoring = false;
  bool _restored = false;
  bool _disposed = false;

  MileafAppearance get mode => _mode;
  bool get restored => _restored;
  ThemeMode get themeMode => _mode.themeMode;

  /// Reads the saved mode once; a missing, unknown or unreadable value keeps
  /// the system default rather than forcing either brightness.
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
      // Keep the system default rather than blocking the app on preferences.
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
