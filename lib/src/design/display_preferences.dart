import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

enum DisplayPreferencesPlatform { iOS, android, other }

typedef ReduceTransparencyReader = Future<bool> Function();

/// Read-only display preferences that Flutter does not expose through
/// MediaQuery. Motion and high contrast remain owned by MediaQuery.
class DisplayPreferencesController extends ChangeNotifier {
  DisplayPreferencesController({
    DisplayPreferencesPlatform? platform,
    ReduceTransparencyReader? readReduceTransparency,
    MethodChannel? channel,
  }) : platform = platform ?? _defaultPlatform(),
       _channel = channel ?? const MethodChannel(_channelName),
       _reader = readReduceTransparency {
    if (this.platform != DisplayPreferencesPlatform.iOS) {
      _reduceTransparency = false;
    }
  }

  static const _channelName = 'mileaf/display_preferences';

  final DisplayPreferencesPlatform platform;
  final MethodChannel _channel;
  final ReduceTransparencyReader? _reader;
  bool? _reduceTransparency;
  bool _started = false;

  bool? get reduceTransparency => _reduceTransparency;

  /// Unknown iOS state takes the stable solid path until the bridge replies.
  bool get useSolidMaterial => _reduceTransparency ?? true;

  Future<void> start() async {
    if (_started) return;
    _started = true;
    if (platform != DisplayPreferencesPlatform.iOS) return;
    _channel.setMethodCallHandler(_handlePlatformCall);
    await refresh();
  }

  Future<void> refresh() async {
    if (platform != DisplayPreferencesPlatform.iOS) return;
    try {
      final Object? raw = _reader != null
          ? await _reader()
          : await _channel.invokeMethod<Object?>('getDisplayPreferences');
      final value = switch (raw) {
        final bool value => value,
        final Map value when value['reduceTransparency'] is bool =>
          value['reduceTransparency'] as bool,
        _ => null,
      };
      _set(value);
    } on PlatformException {
      _set(null);
    } on MissingPluginException {
      _set(null);
    } catch (_) {
      _set(null);
    }
  }

  void updateFromPlatform(bool value) => _set(value);

  Future<void> _handlePlatformCall(MethodCall call) async {
    if (call.method != 'displayPreferencesChanged') return;
    final arguments = call.arguments;
    if (arguments is Map) {
      final value = arguments['reduceTransparency'];
      if (value is bool) updateFromPlatform(value);
    }
  }

  void _set(bool? value) {
    if (_reduceTransparency == value) return;
    _reduceTransparency = value;
    notifyListeners();
  }

  @override
  void dispose() {
    if (_started && platform == DisplayPreferencesPlatform.iOS) {
      _channel.setMethodCallHandler(null);
    }
    super.dispose();
  }

  static DisplayPreferencesPlatform _defaultPlatform() {
    if (kIsWeb) return DisplayPreferencesPlatform.other;
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => DisplayPreferencesPlatform.iOS,
      TargetPlatform.android => DisplayPreferencesPlatform.android,
      _ => DisplayPreferencesPlatform.other,
    };
  }
}

class DisplayPreferencesScope
    extends InheritedNotifier<DisplayPreferencesController> {
  const DisplayPreferencesScope({
    super.key,
    required DisplayPreferencesController controller,
    required super.child,
  }) : super(notifier: controller);

  static DisplayPreferencesController? maybeOf(BuildContext context) => context
      .dependOnInheritedWidgetOfExactType<DisplayPreferencesScope>()
      ?.notifier;
}
